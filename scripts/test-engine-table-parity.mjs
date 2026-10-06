#!/usr/bin/env node
/**
 * Checks the Dart and TypeScript engine tables contain the same rows.
 *
 * The two engines drifted once already: the Dart engine's ingredient-id fix was never mirrored
 * to TypeScript until it was caught, and neither language had a test covering the table at all.
 * Both tables feed the same household nutrition numbers, so a difference here is a real defect
 * rather than a cosmetic one.
 */

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import assert from 'node:assert';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const DART = resolve(ROOT, 'packages/kitchen_engine_dart/lib/nutrition_engine.dart');
const TS = resolve(ROOT, 'packages/kitchen_engine_ts/src/nutrition_engine.ts');

function dartRows() {
  const src = readFileSync(DART, 'utf8');
  const re =
    /FoodComposition\(id: ['"]([^'"]+)['"], nameEn: ['"]([^'"]*)['"], nameNe: ['"][^'"]*['"], foodGroup: ['"]([^'"]+)['"], kcal: ([-\d.]+), proteinG: ([-\d.]+), fiberG: ([-\d.]+), carbsG: ([-\d.]+), fatG: ([-\d.]+)/g;
  const rows = new Map();
  for (const m of src.matchAll(re)) {
    rows.set(m[1], {
      foodGroup: m[3],
      kcal: Number(m[4]),
      proteinG: Number(m[5]),
      fiberG: Number(m[6]),
      carbsG: Number(m[7]),
      fatG: Number(m[8]),
    });
  }
  return rows;
}

function tsRows() {
  const src = readFileSync(TS, 'utf8');
  // Two shapes appear: the curated rows use a `c(...)` helper, the generated USDA block writes
  // object literals. They are matched separately rather than as one alternation, which matched
  // only the first of each.
  const patterns = [
    /c\(['"]([^'"]+)['"], ['"][^'"]*['"], ['"][^'"]*['"], ['"]([^'"]+)['"], ([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)/g,
    /\{ id: ['"]([^'"]+)['"], nameEn: ['"][^'"]*['"], nameNe: ['"][^'"]*['"], foodGroup: ['"]([^'"]+)['"], kcal: ([-\d.]+), proteinG: ([-\d.]+), fiberG: ([-\d.]+), carbsG: ([-\d.]+), fatG: ([-\d.]+)/g,
  ];

  const rows = new Map();
  for (const re of patterns) {
    for (const m of src.matchAll(re)) {
      rows.set(m[1], {
        foodGroup: m[2],
        kcal: Number(m[3]),
        proteinG: Number(m[4]),
        fiberG: Number(m[5]),
        carbsG: Number(m[6]),
        fatG: Number(m[7]),
      });
    }
  }
  return rows;
}

describe('engine composition table parity', () => {
  const dart = dartRows();
  const ts = tsRows();

  it('both tables are non-trivial', () => {
    assert.ok(dart.size > 20, `Dart table only had ${dart.size} rows`);
    assert.ok(ts.size > 20, `TypeScript table only had ${ts.size} rows`);
  });

  it('the same ids exist in both', () => {
    const onlyDart = [...dart.keys()].filter((id) => !ts.has(id));
    const onlyTs = [...ts.keys()].filter((id) => !dart.has(id));
    assert.deepStrictEqual(onlyDart, [], `only in Dart: ${onlyDart.join(', ')}`);
    assert.deepStrictEqual(onlyTs, [], `only in TypeScript: ${onlyTs.join(', ')}`);
  });

  it('the same ids carry the same values', () => {
    const mismatched = [];
    for (const [id, d] of dart) {
      const t = ts.get(id);
      if (!t) continue;
      for (const field of ['foodGroup', 'kcal', 'proteinG', 'fiberG', 'carbsG', 'fatG']) {
        if (d[field] !== t[field]) {
          mismatched.push(`${id}.${field}: dart=${d[field]} ts=${t[field]}`);
        }
      }
    }
    assert.deepStrictEqual(mismatched, [], mismatched.join('\n'));
  });
});
