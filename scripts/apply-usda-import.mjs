#!/usr/bin/env node
/**
 * One-shot patch: adds the USDA import hooks to both engines, then fills them.
 *
 * Kept as a script so the change is reviewable and repeatable; running it twice is a no-op.
 * The long-lived pieces are the generated blocks written by sync-usda-composition.mjs.
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const DART = resolve(ROOT, 'packages/kitchen_engine_dart/lib/nutrition_engine.dart');
const TS = resolve(ROOT, 'packages/kitchen_engine_ts/src/nutrition_engine.ts');

function editOnce(file, description, mutate) {
  const before = readFileSync(file, 'utf8');
  const after = mutate(before);
  if (before === after) {
    console.log(`skip  ${description} (already applied)`);
    return;
  }
  writeFileSync(file, after);
  console.log(`apply ${description}`);
}

const must = (haystack, needle, file) => {
  if (!haystack.includes(needle)) {
    throw new Error(`${file}: expected to find ${JSON.stringify(needle.slice(0, 60))}`);
  }
  return needle;
};

// --- Dart ---------------------------------------------------------------------------

editOnce(DART, 'Dart: CompositionSource.usda', (src) => {
  const anchor = must(src, 'enum CompositionSource { nfct, ifct }', DART);
  return src.replace(
    anchor,
    `/// Where a composition row's values came from.\nenum CompositionSource {\n  nfct,\n  ifct,\n\n  /// USDA FoodData Central, a US Government work and therefore public domain.\n  usda,\n}`,
  );
});

editOnce(DART, 'Dart: usdaTable placeholder', (src) => {
  const anchor = must(
    src,
    "FoodComposition(id: 'banana', nameEn: 'Banana', nameNe: 'केरा', foodGroup: 'fruits', kcal: 116, proteinG: 1.2, fiberG: 0.4, carbsG: 27.2, fatG: 0.3),\n",
    DART,
  );
  return src.replace(
    anchor,
    `${anchor}\n  ];\n\n  /// Rows below are machine-written. See scripts/sync-usda-composition.mjs.\n  static const List<FoodComposition> usdaTable = [\n    // BEGIN generated USDA composition\n    // END generated USDA composition\n`,
  );
});

editOnce(DART, 'Dart: compositionFor searches both tables', (src) => {
  const old = must(
    src,
    `  static FoodComposition? compositionFor(String id) {
    for (final c in compositionTable) {
      if (c.id == id) return c;
    }

    final normalized = normalizeIngredientId(id);
    for (final c in compositionTable) {
      if (c.id == normalized) return c;
    }

    final alias = ingredientAliases[normalized] ?? ingredientAliases[id];
    if (alias != null) {
      for (final c in compositionTable) {
        if (c.id == alias) return c;
      }
    }
    return null;
  }`,
    DART,
  );
  const next = `  static FoodComposition? compositionFor(String id) {
    // Curated rows first, then the USDA import: a hand-checked local value should win over a
    // generic one for the same id.
    for (final table in [compositionTable, usdaTable]) {
      for (final c in table) {
        if (c.id == id) return c;
      }
    }

    final normalized = normalizeIngredientId(id);
    for (final table in [compositionTable, usdaTable]) {
      for (final c in table) {
        if (c.id == normalized) return c;
      }
    }

    final alias = ingredientAliases[normalized] ?? ingredientAliases[id];
    if (alias != null) {
      for (final table in [compositionTable, usdaTable]) {
        for (final c in table) {
          if (c.id == alias) return c;
        }
      }
    }
    return null;
  }

  /// Every row available, curated first then imported.
  static List<FoodComposition> get allCompositions => [...compositionTable, ...usdaTable];`;
  return src.replace(old, next);
});

// --- TypeScript --------------------------------------------------------------------

editOnce(TS, 'TS: CompositionSource includes usda', (src) => {
  const anchor = must(src, "export type CompositionSource = 'nfct' | 'ifct'", TS);
  return src.replace(anchor, "export type CompositionSource = 'nfct' | 'ifct' | 'usda'");
});

editOnce(TS, 'TS: USDA_COMPOSITION_TABLE placeholder', (src) => {
  if (src.includes('USDA_COMPOSITION_TABLE')) return src;
  const start = must(src, 'const COMPOSITION_TABLE', TS);
  const end = src.indexOf('\n]\n', start) + 3;
  if (end < 3) throw new Error(`${TS}: could not find the end of COMPOSITION_TABLE`);
  return `${src.slice(0, end)}\n/**\n * Rows imported from USDA FoodData Central by scripts/import-usda-nutrients.mjs.\n * USDA is a US Government work and therefore public domain.\n */\nexport const USDA_COMPOSITION_TABLE: FoodComposition[] = [\n  // BEGIN generated USDA composition\n  // END generated USDA composition\n]\n${src.slice(end)}`;
});

editOnce(TS, 'TS: compositionFor searches both tables', (src) => {
  const old = must(
    src,
    `  static compositionFor(id: string): FoodComposition | undefined {
    const exact = COMPOSITION_TABLE.find((x) => x.id === id)
    if (exact) return exact

    const normalized = NutritionEngine.normalizeIngredientId(id)
    const bySeparator = COMPOSITION_TABLE.find((x) => x.id === normalized)
    if (bySeparator) return bySeparator

    const alias = NutritionEngine.ingredientAliases[normalized]
      ?? NutritionEngine.ingredientAliases[id]
    if (alias) return COMPOSITION_TABLE.find((x) => x.id === alias)
    return undefined
  }`,
    TS,
  );
  const next = `  /** Curated rows first, then the USDA import. */
  private static get allTables(): FoodComposition[][] {
    return [COMPOSITION_TABLE, USDA_COMPOSITION_TABLE]
  }

  static compositionFor(id: string): FoodComposition | undefined {
    for (const table of NutritionEngine.allTables) {
      const exact = table.find((x) => x.id === id)
      if (exact) return exact
    }

    const normalized = NutritionEngine.normalizeIngredientId(id)
    for (const table of NutritionEngine.allTables) {
      const bySeparator = table.find((x) => x.id === normalized)
      if (bySeparator) return bySeparator
    }

    const alias = NutritionEngine.ingredientAliases[normalized]
      ?? NutritionEngine.ingredientAliases[id]
    if (alias) {
      for (const table of NutritionEngine.allTables) {
        const byAlias = table.find((x) => x.id === alias)
        if (byAlias) return byAlias
      }
    }
    return undefined
  }

  /** Every row available, curated first then imported. */
  static get allCompositions(): FoodComposition[] {
    return [...COMPOSITION_TABLE, ...USDA_COMPOSITION_TABLE]
  }`;
  return src.replace(old, next);
});

console.log('\nfilling generated blocks');
execFileSync('node', [resolve(ROOT, 'scripts/sync-usda-composition.mjs')], {
  stdio: 'inherit',
});