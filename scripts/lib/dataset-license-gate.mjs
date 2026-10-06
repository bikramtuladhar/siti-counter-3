/**
 * License gate for importing third-party dish data.
 *
 * A dataset is only importable when every license claim about it is known and permissive.
 * This module exists because "the README says CC-BY" is not sufficient evidence: the same
 * project can declare a different, more restrictive license in its machine-readable metadata,
 * and the more restrictive statement is the one that has to be honoured.
 *
 * Rules:
 *   1. Every supplied claim must resolve to an SPDX id. An unknown or absent license means
 *      all rights reserved, so it is refused rather than assumed open.
 *   2. The most restrictive claim wins. A permissive README and a non-commercial machine
 *      readable declaration together resolve to the non-commercial licence.
 *   3. Non-commercial, no-derivatives and unknown-share alike terms are refused outright,
 *      because Siti Counter is distributed commercially through the app stores and may
 *      adapt the data into its own packs.
 */

/**
 * SPDX ids cleared for import. All permit commercial use and derivative works, and all
 * carry an attribution obligation the importer satisfies in its output provenance.
 */
export const ALLOWED_SPDX = Object.freeze([
  'cc0-1.0',
  'pdm-1.0',
  'cc-by-4.0',
  'cc-by-3.0',
  'cc-by-sa-4.0',
  'cc-by-sa-3.0',
  'odbl-1.0',
  'mit-0',
  'bsd-3-clause',
  'apache-2.0',
]);

/**
 * Licensing terms that are refused no matter what else is claimed, with the reason.
 * Checked before {@link ALLOWED_SPDX} so a refusal always explains itself.
 */
const REFUSED_TERMS = Object.freeze({
  'nc': 'non-commercial use only; Siti Counter is sold through the app stores',
  'nd': 'no derivatives permitted; the importer reshapes rows into region packs',
  'unknown': 'licence not declared, which means all rights reserved',
});

/**
 * Splits an SPDX expression into individual licence ids.
 *
 * Handles the `AND`/`OR` forms these datasets actually use. An `OR` expression is treated
 * as the union of its options and accepted only when every option is allowed, so
 * "CC-BY-4.0 OR MIT" passes and "CC-BY-4.0 OR CC-BY-NC-4.0" does not. Refusing the whole
 * expression when one branch is open is deliberate: the importer cannot know which branch
 * the licensor meant to offer, and picking the permissive one would be a guess.
 *
 * @param {string} expression
 * @returns {string[]}
 */
export function parseSpdx(expression) {
  if (typeof expression !== 'string') return [];
  return expression
    .split(/\s+(?:AND|OR)\s+/i)
    .map((part) => part.trim().toLowerCase().replace(/\s+/g, '-'))
    .filter(Boolean);
}

/**
 * Classifies a single SPDX id.
 *
 * @param {string} spdx
 * @returns {{spdx: string, allowed: boolean, reason: string|null}}
 */
export function classifyLicense(spdx) {
  // Project licences are written in prose as often as in SPDX form: LICENCE.md says
  // "CC-BY 4.0" where the identifier is "CC-BY-4.0". Fold the separator so a genuinely open
  // licence is not refused over punctuation. Only whitespace is touched.
  const id = String(spdx || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-');

  if (!id) {
    return { spdx: id, allowed: false, reason: REFUSED_TERMS.unknown };
  }
  if (id === 'unknown' || id === 'unlicensed' || id === 'noassertion') {
    return { spdx: id, allowed: false, reason: REFUSED_TERMS.unknown };
  }

  // A suffix modifier is checked first so CC-BY-NC-4.0 is refused as non-commercial rather
  // than falling through and being reported as merely unrecognised.
  const parts = id.split('-');
  if (parts.includes('nc')) {
    return { spdx: id, allowed: false, reason: REFUSED_TERMS.nc };
  }
  if (parts.includes('nd')) {
    return { spdx: id, allowed: false, reason: REFUSED_TERMS.nd };
  }

  if (!ALLOWED_SPDX.includes(id)) {
    return {
      spdx: id,
      allowed: false,
      reason: `licence "${id}" is not on the reviewed allowlist; add it deliberately after checking its terms`,
    };
  }

  return { spdx: id, allowed: true, reason: null };
}

/**
 * Decides whether a dataset may be imported, given every license claim found about it.
 *
 * @param {object} params
 * @param {string} params.datasetId
 * @param {Record<string, string>} params.claims License ids keyed by the source they came
 *   from, e.g. `{ 'LICENCE.md': 'CC-BY 4.0', 'croissant metadata': 'cc-by-nc-sa-4.0' }`.
 * @param {boolean} [params.commercialUse=true] Whether the importer is for a product that
 *   is distributed commercially.
 * @returns {{allowed: boolean, resolved: string[], reasons: string[], warnings: string[]}}
 */
export function evaluateLicenses({ datasetId, claims, commercialUse = true }) {
  const entries = Object.entries(claims || {});
  const resolved = [];
  const reasons = [];
  const warnings = [];

  if (entries.length === 0) {
    return {
      allowed: false,
      resolved: [],
      reasons: [`${datasetId}: no licence claim found, so nothing establishes permission to use it`],
      warnings,
    };
  }

  for (const [source, expression] of entries) {
    const ids = parseSpdx(expression);

    if (ids.length === 0) {
      reasons.push(`${datasetId}: ${source} declares "${expression || '(empty)'}", which is not a usable licence`);
      continue;
    }

    for (const id of ids) {
      const verdict = classifyLicense(id);
      resolved.push(verdict.spdx);
      if (!verdict.allowed) {
        reasons.push(`${datasetId}: ${source} declares "${verdict.spdx}" — refused because it is ${verdict.reason}`);
      }
    }
  }

  // Distinct claims about the same dataset are a signal in their own right: they mean the
  // licensor published more than one statement and they should be reconciled by a human
  // before anything is imported.
  const distinct = [...new Set(resolved)];
  if (distinct.length > 1) {
    warnings.push(
      `${datasetId}: conflicting licence claims (${distinct.join(', ')}). ` +
        'The most restrictive was applied. These need to be reconciled upstream.',
    );
  }

  const allowed = reasons.length === 0 && distinct.length > 0;
  if (!allowed && reasons.length === 0) {
    reasons.push(`${datasetId}: licence could not be resolved`);
  }

  return { allowed, resolved: distinct, reasons, warnings };
}

/**
 * Columns that must never be copied out of a third-party dataset.
 *
 * Image columns are excluded because their licences vary per row and are tracked separately
 * by several of these projects, so a dataset-level licence does not cover them. The World
 * Wide Dishes terms additionally prohibit using its images for model training and warn that
 * some linked images are non-commercial.
 */
export const FORBIDDEN_COLUMN_PATTERNS = Object.freeze([
  /image/i,
  /photo/i,
  /picture/i,
  /avatar/i,
  /uploaded_/i,
]);

/**
 * Returns the input columns that are safe to carry forward.
 *
 * @param {string[]} columns
 * @returns {{kept: string[], dropped: string[]}}
 */
export function partitionSafeColumns(columns) {
  const kept = [];
  const dropped = [];
  for (const column of columns) {
    if (FORBIDDEN_COLUMN_PATTERNS.some((p) => p.test(column))) {
      dropped.push(column);
    } else {
      kept.push(column);
    }
  }
  return { kept, dropped };
}

/**
 * Thrown when a dataset is not cleared. Carries the reasons so a caller can print them
 * rather than the script inventing its own explanation.
 */
export class LicenseNotClearedError extends Error {
  constructor(datasetId, result) {
    super(`${datasetId} cannot be imported:\n  - ${result.reasons.join('\n  - ')}`);
    this.name = 'LicenseNotClearedError';
    this.datasetId = datasetId;
    this.reasons = result.reasons;
    this.warnings = result.warnings;
  }
}