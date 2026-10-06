#!/usr/bin/env node
/**
 * Builds per-100 g composition rows for named ingredients from USDA FoodData Central.
 *
 * Why this exists: the app's nutrition composition table had 13 ingredients while the region
 * packs referenced 96, so most food scored as zero nutrients. Hand-typing values invites
 * transcription errors in data that ends up on a family nutrition dashboard, so the values are
 * extracted and written by this script instead.
 *
 * Why USDA: FoodData Central is a US Government work and therefore public domain, which is the
 * only candidate in docs/data/world-dish-datasets.json that clears
 * scripts/lib/dataset-license-gate.mjs. Everything else researched either declares no licence
 * or conflicts with itself about non-commercial use.
 *
 * Why the bulk CSV rather than the search API: the API needs a key, and the shared DEMO_KEY is
 * rate limited to far fewer requests than this list needs. The SR Legacy bulk download needs no
 * key and is a fixed release, so a re-run reproduces the same numbers rather than depending on
 * whatever the API happens to rank first today.
 *
 * The ingredient -> USDA description mapping below is explicit and reviewed. USDA describes food
 * generically and in Western preparation, so an automatic name match picks the wrong thing:
 * there is no entry for a Nepali citron, and "Dill weed" is not what any of our garden herbs
 * mean. Each row records the exact USDA description and fdc_id used, so a reviewer can check the
 * choice.
 *
 * Usage:
 *   node scripts/import-usda-nutrients.mjs --out <file.json> [--cache <sr.zip>]
 *                                            [--dry-run] [--only <id,id>]
 */

import {
  execFileSync,
} from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

/** Fixed SR Legacy release, so a re-run extracts identical numbers. */
const SR_ZIP_URL =
  'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip';

/**
 * Nutrient names to read, and the field each is written to.
 *
 * `required: false` means an absent row is recorded as zero rather than treated as an error.
 * Fibre is the only one: USDA publishes no fibre row for animal products because there is none,
 * so a missing row is a true zero for prawn, meat and ghee. Every other nutrient is required,
 * because a missing kcal or protein row means the entry is not what we think it is.
 */
const NUTRIENTS = [
  ['kcal', 'Energy', true],
  ['proteinG', 'Protein', true],
  ['fiberG', 'Fiber, total dietary', false],
  ['carbsG', 'Carbohydrate, by difference', true],
  ['fatG', 'Total lipid (fat)', true],
];

/**
 * Ingredients to import.
 *
 * `match` is the exact USDA SR Legacy description. It is matched case-insensitively and must
 * exist: a miss is an error rather than a fallback to the first search result, because the whole
 * point is that a human chose the entry.
 *
 * `foodGroup` is the app's own taxonomy; USDA does not use these groups.
 *
 * `note` records the judgement call, where one was needed, so it can be challenged later.
 */
const INGREDIENTS = [
  // Aromatics and spices: the highest-usage gaps by a wide margin.
  { id: 'garlic', foodGroup: 'vegetables', match: 'Garlic, raw' },
  { id: 'ginger', foodGroup: 'vegetables', match: 'Ginger root, raw' },
  { id: 'ghee', foodGroup: 'fats', match: 'Butter, Clarified butter (ghee)' },
  { id: 'tomato', foodGroup: 'vegetables', match: 'Tomatoes, red, ripe, raw, year round average' },
  { id: 'onion', foodGroup: 'vegetables', match: 'Onions, raw' },
  { id: 'turmeric', foodGroup: 'spices', match: 'Spices, turmeric, ground' },
  { id: 'green_chili', foodGroup: 'vegetables', match: 'Peppers, hot chili, green, raw' },
  { id: 'red_chili', foodGroup: 'spices', match: 'Spices, pepper, red or cayenne' },
  { id: 'fenugreek_seeds', foodGroup: 'spices', match: 'Spices, fenugreek seed' },
  { id: 'cardamom', foodGroup: 'spices', match: 'Spices, cardamom' },
  { id: 'cumin', foodGroup: 'spices', match: 'Spices, cumin seed' },
  { id: 'sesame', foodGroup: 'spices', match: 'Seeds, sesame seeds, whole, dried' },
  { id: 'coriander', foodGroup: 'spices', match: 'Spices, coriander seed' },

  // Vegetables.
  { id: 'pumpkin', foodGroup: 'vegetables', match: 'Pumpkin, raw' },
  { id: 'cabbage', foodGroup: 'vegetables', match: 'Cabbage, raw' },
  { id: 'green_peas', foodGroup: 'vegetables', match: 'Peas, green, raw' },
  { id: 'carrot', foodGroup: 'vegetables', match: 'Carrots, raw' },
  { id: 'okra', foodGroup: 'vegetables', match: 'Okra, raw' },
  { id: 'bottle_gourd', foodGroup: 'vegetables', match: 'Balsam-pear (bitter gourd), pods, raw', note: 'USDA carries only the bitter variety under balsam-pear' },
  { id: 'bitter_gourd', foodGroup: 'vegetables', match: 'Balsam-pear (bitter gourd), pods, raw' },
  { id: 'green_mustard', foodGroup: 'vegetables', match: 'Mustard greens, raw' },
  { id: 'bean_sprouts', foodGroup: 'vegetables', match: 'Soybeans, mature seeds, sprouted, raw' },

  // Fruits.
  { id: 'mango', foodGroup: 'fruits', match: 'Mangos, raw' },
  { id: 'litchi', foodGroup: 'fruits', match: 'Litchis, raw' },
  { id: 'pomegranate', foodGroup: 'fruits', match: 'Pomegranates, raw' },

  // Protein.
  { id: 'goat_meat', foodGroup: 'protein', match: 'Game meat, goat, raw', note: 'stand-in for buffalo meat, which USDA does not carry separately' },
  { id: 'pork_meat', foodGroup: 'protein', match: 'Pork, ground, 84% lean / 16% fat, raw' },
  { id: 'fish', foodGroup: 'protein', match: 'Fish, tilapia, raw', note: 'stand-in; the packs name several freshwater fish' },
  { id: 'prawn', foodGroup: 'protein', match: 'Crustaceans, shrimp, raw' },
  { id: 'tofu', foodGroup: 'protein', match: 'Tofu, raw, firm, prepared with calcium sulfate' },

  // Pulses.
  { id: 'soy_beans', foodGroup: 'pulses', match: 'Soybeans, mature seeds, raw' },
  { id: 'chickpea', foodGroup: 'pulses', match: 'Chickpeas (garbanzo beans, bengal gram), mature seeds, raw' },
  { id: 'kidney_beans', foodGroup: 'pulses', match: 'Beans, kidney, all types, mature seeds, raw' },
  { id: 'rajma', foodGroup: 'pulses', match: 'Beans, black, mature seeds, raw' },
  { id: 'gram_flour', foodGroup: 'pulses', match: 'Chickpeas (garbanzo beans, bengal gram), mature seeds, raw', note: 'same raw legume; USDA has no gram-flour entry, and besan is ~75% this milled' },

  // Staples and fats.
  { id: 'noodles', foodGroup: 'grains', match: 'Pasta, cooked, unenriched, without added salt', note: 'closest cooked wheat noodle USDA carries; the packs also carry egg noodles' },
  { id: 'buckwheat_flour', foodGroup: 'grains', match: 'Buckwheat flour, whole-groat' },
  { id: 'sunflower_oil', foodGroup: 'fats', match: 'Oil, sunflower, high oleic (70% and over)' },
  { id: 'vegetable_oil', foodGroup: 'fats', match: 'Oil, corn and canola' },
];

/** Minimal RFC 4180 CSV reader; the USDA files quote commas and embedded newlines. */
function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;

  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
      continue;
    }
    if (c === '"') inQuotes = true;
    else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else if (c !== '\r') {
      field += c;
    }
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  const [header, ...body] = rows.filter((r) => r.length > 1);
  if (!header) return [];
  return body.map((r) => Object.fromEntries(header.map((h, i) => [h, r[i] ?? ''])));
}

/** Downloads and unpacks the SR Legacy release unless already cached. */
function ensureSrData(cachePath) {
  const workDir = join(tmpdir(), 'usda-sr-legacy');
  const zipPath = cachePath || join(workDir, 'sr.zip');

  mkdirSync(workDir, { recursive: true });

  if (!existsSync(zipPath)) {
    console.log(`downloading SR Legacy release (~6 MB) to ${zipPath}`);
    execFileSync('curl', ['-sSL', '--max-time', '300', '-o', zipPath, SR_ZIP_URL], {
      stdio: 'inherit',
    });
  } else {
    console.log(`using cached ${zipPath}`);
  }

  const unpacked = join(workDir, 'unpacked');
  if (!existsSync(unpacked)) {
    execFileSync('unzip', ['-o', '-q', zipPath, '-d', unpacked], { stdio: 'inherit' });
  }

  const entries = readdirSync(unpacked).filter((e) => e !== '__MACOSX');
  const base = entries.length === 1 ? join(unpacked, entries[0]) : unpacked;

  return {
    food: join(base, 'food.csv'),
    nutrient: join(base, 'nutrient.csv'),
    foodNutrient: join(base, 'food_nutrient.csv'),
  };
}

function loadSr(paths) {
  console.log('reading SR Legacy tables');
  const foods = parseCsv(readFileSync(paths.food, 'utf8'));
  const nutrients = parseCsv(readFileSync(paths.nutrient, 'utf8'));
  const foodNutrients = parseCsv(readFileSync(paths.foodNutrient, 'utf8'));

  const nameById = new Map(nutrients.map((n) => [n.id, n.name]));

  // fdc_id -> { nutrientName: amount }
  const amountsByFood = new Map();
  for (const row of foodNutrients) {
    const name = nameById.get(row.nutrient_id);
    if (!name) continue;
    let bucket = amountsByFood.get(row.fdc_id);
    if (!bucket) {
      bucket = new Map();
      amountsByFood.set(row.fdc_id, bucket);
    }
    if (!bucket.has(name)) bucket.set(name, Number(row.amount));
  }

  const byDescription = new Map();
  for (const f of foods) {
    if (!byDescription.has(f.description)) byDescription.set(f.description, f);
  }

  return { foods, byDescription, amountsByFood };
}

function extractRow(entry, sr) {
  const food =
    sr.byDescription.get(entry.match) ||
    sr.byDescription.get(
      [...sr.byDescription.keys()].find(
        (d) => d.toLowerCase() === entry.match.toLowerCase(),
      ) || '',
    );

  if (!food) return { error: `no USDA entry described "${entry.match}"` };

  const amounts = sr.amountsByFood.get(food.fdc_id);
  if (!amounts) return { error: `"${entry.match}" has no nutrient rows` };

  const values = {};
  for (const [field, nutrientName, required] of NUTRIENTS) {
    const raw = amounts.get(nutrientName);
    if (raw === undefined || Number.isNaN(raw)) {
      if (required) return { error: `"${entry.match}" is missing ${nutrientName}` };
      values[field] = 0;
      continue;
    }
    // One decimal is more precision than the table claims, and no more.
    values[field] = Math.round(raw * 10) / 10;
  }

  return { food, values };
}

function run() {
  const args = process.argv.slice(2);
  const outIndex = args.indexOf('--out');
  const cacheIndex = args.indexOf('--cache');
  const onlyIndex = args.indexOf('--only');
  const dryRun = args.includes('--dry-run');

  const only = onlyIndex >= 0 ? args[onlyIndex + 1].split(',').map((s) => s.trim()) : null;
  const targets = only ? INGREDIENTS.filter((i) => only.includes(i.id)) : INGREDIENTS;

  if (targets.length === 0) {
    console.error('No ingredients selected.');
    process.exit(2);
  }

  const sr = loadSr(ensureSrData(cacheIndex >= 0 ? args[cacheIndex + 1] : undefined));

  const rows = [];
  const failures = [];

  for (const entry of targets) {
    const { food, values, error } = extractRow(entry, sr);
    if (error) {
      failures.push(`${entry.id}: ${error}`);
      console.error(`FAIL ${entry.id.padEnd(18)} ${error}`);
      continue;
    }
    rows.push({
      id: entry.id,
      nameEn: entry.match,
      foodGroup: entry.foodGroup,
      ...values,
      source: 'usda',
      usdaDescription: food.description,
      usdaFdcId: food.fdc_id,
      ...(entry.note ? { judgement: entry.note } : {}),
    });
    console.log(
      `ok   ${entry.id.padEnd(18)} ${String(food.fdc_id).padEnd(8)} ` +
        `kcal=${values.kcal} protein=${values.proteinG}`,
    );
  }

  console.log(`\n${rows.length} extracted, ${failures.length} failed`);
  if (failures.length > 0) console.error(failures.map((f) => `  - ${f}`).join('\n'));

  if (dryRun) {
    console.log('\n--dry-run: nothing written.');
    return;
  }

  if (outIndex < 0) {
    console.error('Missing --out <file.json>.');
    process.exit(2);
  }

  const payload = {
    schemaVersion: 1,
    source: {
      dataset: 'USDA FoodData Central',
      release: 'SR Legacy 2018-04',
      url: 'https://fdc.nal.usda.gov/',
      license: 'public domain (US Government work)',
      basis: 'values per 100 g as published, not adjusted for cooking',
    },
    count: rows.length,
    ingredients: rows,
  };

  writeFileSync(resolve(args[outIndex + 1]), `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`wrote ${args[outIndex + 1]}`);
  if (failures.length > 0) process.exit(1);
}

run();