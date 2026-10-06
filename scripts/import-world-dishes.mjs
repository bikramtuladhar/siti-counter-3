#!/usr/bin/env node
/**
 * Imports dish-role and meal-time metadata from a third-party world dish dataset.
 *
 * The CSV is never vendored into this repository. Point the script at a copy you downloaded
 * yourself and that you are licensed to use; the license gate decides whether the import is
 * allowed to happen at all.
 *
 * Usage:
 *   node scripts/import-world-dishes.mjs --source <csv> --license "<spdx>[ --license <spdx>]"
 *                                       --out <file.json> [--dry-run] [--force]
 *
 * The gate is the point of this script. It is expected to refuse the datasets this was
 * originally written for, and it does so loudly rather than importing a contested claim.
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  evaluateLicenses,
  partitionSafeColumns,
  LicenseNotClearedError,
} from './lib/dataset-license-gate.mjs';

const SELF = fileURLToPath(import.meta.url);

function parseArgs(argv) {
  const out = { licenses: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--source':
        out.source = argv[++i];
        break;
      case '--out':
        out.out = argv[++i];
        break;
      case '--license':
        out.licenses.push({ source: out.licenses.length === 0 ? 'attested licence' : `attested licence #${out.licenses.length + 1}`, spdx: argv[++i] });
        break;
      case '--dry-run':
        out.dryRun = true;
        break;
      case '--force':
        out.force = true;
        break;
      default:
        throw new Error(`Unknown argument "${arg}". See the usage comment at the top of this file.`);
    }
  }
  return out;
}

/**
 * Parses the Python-style list literal these datasets use for multi-valued columns,
 * e.g. `"['lunch', 'dinner']"`.
 */
export function parseListCell(raw) {
  if (!raw) return [];
  const text = String(raw).trim();
  if (text === '' || text === 'nan') return [];
  if (!text.startsWith('[')) return [text];
  return text
    .replace(/^\[/, '')
    .replace(/\]$/, '')
    .split(',')
    .map((s) => s.trim().replace(/^['"]|['"]$/g, ''))
    .filter(Boolean);
}

/**
 * Maps the World Wide Dishes `type_of_dish` vocabulary onto our dish roles.
 *
 * The vocabulary distinguishes three main-course shapes that our model collapses into two
 * roles, so both main shapes map to `mainCourse` and a dish that is both a standalone meal
 * and eaten with sides maps to `both`.
 */
export function mapDishRoles(typeOfDish) {
  // The flags are accumulated across the whole cell, because no single value is ever both
  // a main and a side. A cell listing a side dish and a standalone main means the dish is
  // eaten both ways, which is our `both`.
  let hasMain = false;
  let hasSide = false;
  for (const raw of parseListCell(typeOfDish)) {
    const value = raw.toLowerCase();
    if (value.startsWith('main dish')) hasMain = true;
    if (value.startsWith('side dish')) hasSide = true;
  }

  if (hasMain && hasSide) return ['both'];
  if (hasMain) return ['mainCourse'];
  if (hasSide) return ['sideDish'];
  return [];
}

/**
 * Maps `time_of_day` onto our four meal times.
 *
 * The source vocabulary is breakfast / lunch / dinner / snack / anytime / other. Our model
 * has morning, midday, evening and night, where evening is the light snack slot. "anytime"
 * imposes no restriction, which we express by returning an empty list: our resolver treats an
 * empty list as every time.
 */
export function mapMealTimes(timeOfDay) {
  const times = new Set();
  for (const raw of parseListCell(timeOfDay)) {
    switch (raw.toLowerCase()) {
      case 'breakfast':
        times.add('morning');
        break;
      case 'lunch':
        times.add('midday');
        break;
      case 'dinner':
        times.add('night');
        break;
      case 'snack':
        times.add('evening');
        break;
      default:
        // 'anytime' and 'other' carry no scheduling information.
        break;
    }
  }
  return [...times];
}

/** Minimal RFC 4180 CSV reader: handles quoted fields and embedded newlines. */
export function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];

    if (inQuotes) {
      if (char === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === '"') {
      inQuotes = true;
    } else if (char === ',') {
      row.push(field);
      field = '';
    } else if (char === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else if (char !== '\r') {
      field += char;
    }
  }

  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  const [header, ...body] = rows.filter((r) => r.length > 1 || (r.length === 1 && r[0] !== ''));
  if (!header) return { columns: [], records: [] };
  return {
    columns: header,
    records: body.map((r) => Object.fromEntries(header.map((h, i) => [h, r[i] ?? '']))),
  };
}

/**
 * Collapses a set of roles into the single values our model uses.
 *
 * `mainCourse` and `sideDish` together mean `both`; anything else is left alone.
 *
 * @param {Iterable<string>} roles
 * @returns {string[]}
 */
export function collapseRoles(roles) {
  const set = new Set(roles);
  if (set.has('mainCourse') && set.has('sideDish')) return ['both'];
  return [...set].sort();
}

export function buildReference(records, columns, { datasetId }) {
  const { kept, dropped } = partitionSafeColumns(columns);
  const seen = new Map();

  for (const record of records) {
    const name = (record.english_name || record.local_name || '').trim();
    if (!name) continue;

    const roles = mapDishRoles(record.type_of_dish);
    const times = mapMealTimes(record.time_of_day);
    if (roles.length === 0 && times.length === 0) continue;

    const key = name.toLowerCase();
    if (!seen.has(key)) {
      seen.set(key, {
        name,
        countries: record.countries || '',
        regions: record.regions || '',
        dishRoles: new Set(),
        mealTimes: new Set(),
      });
    }
    const entry = seen.get(key);
    for (const role of roles) entry.dishRoles.add(role);
    for (const time of times) entry.mealTimes.add(time);
  }

  const dishes = [...seen.values()]
    .map((d) => ({
      name: d.name,
      countries: d.countries,
      regions: d.regions,
      // A dish recorded as a main in one place and a side in another is our `both`. The
      // union of two roles is not itself a role, so it has to be collapsed or the pack
      // would carry a value no resolver understands.
      dishRoles: collapseRoles(d.dishRoles),
      // Empty means every meal time, matching how our resolver reads an absent value.
      mealTimes: [...d.mealTimes].sort(),
    }))
    .sort((a, b) => a.name.localeCompare(b.name));

  return {
    schemaVersion: 1,
    datasetId,
    // A reference layer only. Roles already declared by a pack always win; this exists to
    // propose roles for dishes a pack has not classified.
    purpose: 'role-and-time reference',
    columnsDroppedAsUnlicensed: dropped,
    dishCount: dishes.length,
    dishes,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!args.source) {
    console.error('Missing --source <csv>. Download the dataset yourself; it is not vendored.');
    process.exit(2);
  }

  const verdict = evaluateLicenses({
    datasetId: args.source,
    claims: Object.fromEntries(args.licenses.map((l) => [l.source, l.spdx])),
  });

  for (const warning of verdict.warnings) {
    console.warn(`warning: ${warning}`);
  }

  if (!verdict.allowed) {
    const error = new LicenseNotClearedError(args.source, verdict);
    console.error(error.message);
    console.error(
      '\nNo data was imported. Clear the licence with the upstream project, then re-run with ' +
        'the licence they confirm in --license.',
    );
    process.exit(1);
  }

  const text = readFileSync(resolve(args.source), 'utf8');
  const { columns, records } = parseCsv(text);
  const reference = buildReference(records, columns, { datasetId: args.source });

  console.log(`records: ${records.length}`);
  console.log(`dishes with a role or time: ${reference.dishCount}`);
  console.log(`columns dropped as unlicensed: ${reference.columnsDroppedAsUnlicensed.join(', ')}`);

  if (args.dryRun) {
    console.log('\n--dry-run: nothing written.');
    return;
  }

  if (!args.out) {
    console.error('Missing --out <file.json>.');
    process.exit(2);
  }

  writeFileSync(resolve(args.out), `${JSON.stringify(reference, null, 2)}\n`);
  console.log(`\nwrote ${args.out}`);
}

// Run only when executed directly, so the test file can import these helpers.
if (process.argv[1] && resolve(process.argv[1]) === resolve(SELF)) {
  main();
}