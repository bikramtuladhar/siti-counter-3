#!/usr/bin/env node
/**
 * Writes the USDA composition rows into the engine tables in both languages.
 *
 * The values themselves come from data/nutrition/usda-composition.json, which
 * scripts/import-usda-nutrients.mjs produces from the USDA bulk release. This step only
 * formats them into the `const` tables the Dart and TypeScript engines declare, because a const
 * list cannot be loaded from JSON at compile time.
 *
 * Both engines are written from one source so they cannot drift. They already had: the Dart
 * engine's id-matching fix was never applied to the TypeScript side until it was caught, and
 * neither had a test covering the table at all. A region pack feeding a household's nutrition
 * numbers is not somewhere to let two copies of the same data disagree.
 *
 * Usage:
 *   node scripts/sync-usda-composition.mjs [--check]
 *
 * `--check` verifies both files are already in sync and exits non-zero if not, so CI can catch a
 * regenerated JSON file that was never applied.
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DATA_FILE = resolve(ROOT, 'data/nutrition/usda-composition.json');

const DART = resolve(ROOT, 'packages/kitchen_engine_dart/lib/nutrition_engine.dart');
const TS = resolve(ROOT, 'packages/kitchen_engine_ts/src/nutrition_engine.ts');

const BEGIN = 'BEGIN generated USDA composition';
const END = 'END generated USDA composition';

/** Double-quoted Dart/TS string escaping. */
const q = (value) => JSON.stringify(String(value));

function loadRows() {
  const data = JSON.parse(readFileSync(DATA_FILE, 'utf8'));
  if (!Array.isArray(data.ingredients) || data.ingredients.length === 0) {
    throw new Error(`${DATA_FILE} has no ingredients`);
  }
  return [...data.ingredients].sort((a, b) => a.id.localeCompare(b.id));
}

function dartBlock(rows) {
  const lines = rows.map((r) => {
    const tail = `source: CompositionSource.usda`;
    return (
      `    FoodComposition(id: ${q(r.id)}, nameEn: ${q(r.nameEn)}, ` +
      `nameNe: ${q(r.id)}, foodGroup: ${q(r.foodGroup)}, ` +
      `kcal: ${r.kcal}, proteinG: ${r.proteinG}, fiberG: ${r.fiberG}, ` +
      `carbsG: ${r.carbsG}, fatG: ${r.fatG}, ${tail}),`
    );
  });
  return [
    `    // ${BEGIN}`,
    '    // Generated from data/nutrition/usda-composition.json by',
    '    // scripts/sync-usda-composition.mjs. USDA FoodData Central, public domain.',
    '    // Edit the JSON, not this file.',
    ...lines,
    `    // ${END}`,
  ].join('\n');
}

function tsBlock(rows) {
  const lines = rows.map(
    (r) =>
      `  { id: ${q(r.id)}, nameEn: ${q(r.nameEn)}, nameNe: ${q(r.id)}, ` +
      `foodGroup: ${q(r.foodGroup)}, kcal: ${r.kcal}, proteinG: ${r.proteinG}, ` +
      `fiberG: ${r.fiberG}, carbsG: ${r.carbsG}, fatG: ${r.fatG}, source: 'usda' },`,
  );
  return [
    `  // ${BEGIN}`,
    '  // Generated from data/nutrition/usda-composition.json by',
    '  // scripts/sync-usda-composition.mjs. USDA FoodData Central, public domain.',
    '  // Edit the JSON, not this file.',
    ...lines,
    `  // ${END}`,
  ].join('\n');
}

function replaceBlock(source, block, anchor, indentNote) {
  const beginIdx = source.indexOf(`// ${BEGIN}`);
  const endIdx = source.indexOf(`// ${END}`);
  if (beginIdx === -1 || endIdx === -1) {
    throw new Error(
      `markers not found in ${anchor}. Add "// ${BEGIN}" and "// ${END}" around the ` +
        `generated region, with the region inside ${indentNote}`,
    );
  }
  // Drop all whitespace before the begin marker, then re-add exactly one newline. Trimming only
  // spaces left the previous run's newline behind, so the file grew a blank line every time and
  // --check failed straight after a successful write.
  const before = source.slice(0, beginIdx).replace(/\s*$/, '');
  const after = source.slice(endIdx + `// ${END}`.length);
  return `${before}\n${block}${after}`;
}

function main() {
  const check = process.argv.includes('--check');
  const rows = loadRows();

  const dartSrc = readFileSync(DART, 'utf8');
  const tsSrc = readFileSync(TS, 'utf8');

  const nextDart = replaceBlock(
    dartSrc,
    dartBlock(rows),
    DART,
    'the compositionTable list',
  );
  const nextTs = replaceBlock(
    tsSrc,
    tsBlock(rows),
    TS,
    'the COMPOSITION_TABLE array',
  );

  if (check) {
    const problems = [];
    if (nextDart !== dartSrc) problems.push(`${DART} is out of sync`);
    if (nextTs !== tsSrc) problems.push(`${TS} is out of sync`);
    if (problems.length > 0) {
      console.error(
        `${problems.join('\n')}\nRun: node scripts/sync-usda-composition.mjs`,
      );
      process.exit(1);
    }
    console.log(`both engines are in sync with ${rows.length} USDA rows`);
    return;
  }

  writeFileSync(DART, nextDart);
  writeFileSync(TS, nextTs);
  console.log(`wrote ${rows.length} USDA rows into both engines`);
}

main();