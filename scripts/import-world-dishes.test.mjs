import { describe, it } from 'node:test';
import assert from 'node:assert';

import {
  evaluateLicenses,
  classifyLicense,
  parseSpdx,
  partitionSafeColumns,
  LicenseNotClearedError,
} from './lib/dataset-license-gate.mjs';

import {
  parseListCell,
  parseCsv,
  mapDishRoles,
  mapMealTimes,
  buildReference,
} from './import-world-dishes.mjs';

describe('license gate — individual licences', () => {
  it('accepts permissive licences on the allowlist', () => {
    for (const id of ['CC-BY-4.0', 'cc-by-sa-4.0', 'CC0-1.0', 'ODbL-1.0', 'pdm-1.0']) {
      assert.strictEqual(classifyLicense(id).allowed, true, `${id} should be allowed`);
    }
  });

  it('refuses non-commercial licences and says why', () => {
    const verdict = classifyLicense('cc-by-nc-sa-4.0');
    assert.strictEqual(verdict.allowed, false);
    assert.match(verdict.reason, /non-commercial/);
  });

  it('refuses no-derivatives', () => {
    assert.strictEqual(classifyLicense('cc-by-nd-4.0').allowed, false);
  });

  it('refuses a licence that has not been reviewed', () => {
    const verdict = classifyLicense('cc-by-nc-nd-4.0');
    assert.strictEqual(verdict.allowed, false);
  });

  it('treats a missing licence as all rights reserved', () => {
    for (const id of ['', null, undefined, 'unlicensed', 'noassertion']) {
      assert.strictEqual(classifyLicense(id).allowed, false, `${id} should be refused`);
      assert.match(classifyLicense(id).reason, /not declared/);
    }
  });

  it('accepts the prose form licences are often written in', () => {
    // LICENCE.md says "CC-BY 4.0" where SPDX says "CC-BY-4.0". Punctuation must not be the
    // reason a genuinely open licence is refused.
    assert.strictEqual(classifyLicense('CC-BY 4.0').allowed, true);
    assert.strictEqual(classifyLicense('CC BY 4.0').allowed, true);
    assert.strictEqual(classifyLicense('CC-BY-NC-SA 4.0').allowed, false);
  });

  it('is case insensitive', () => {
    assert.strictEqual(classifyLicense('CC-BY-4.0').allowed, true);
    assert.strictEqual(classifyLicense('Cc-By-Nc-4.0').allowed, false);
  });
});

describe('license gate — expressions', () => {
  it('splits AND/OR expressions', () => {
    assert.deepStrictEqual(parseSpdx('CC-BY-4.0 OR MIT'), ['cc-by-4.0', 'mit']);
    assert.deepStrictEqual(parseSpdx('CC0-1.0 AND CC-BY-4.0'), ['cc0-1.0', 'cc-by-4.0']);
    assert.deepStrictEqual(parseSpdx(''), []);
  });

  it('accepts an expression when every branch is open', () => {
    const result = evaluateLicenses({
      datasetId: 'demo',
      claims: { 'LICENCE.md': 'CC-BY-4.0 OR MIT-0' },
    });
    assert.strictEqual(result.allowed, true);
  });

  it('refuses an expression that offers a choice including a closed branch', () => {
    // Picking the open branch would be a guess about what the licensor intended.
    const result = evaluateLicenses({
      datasetId: 'demo',
      claims: { 'LICENCE.md': 'CC-BY-4.0 OR CC-BY-NC-4.0' },
    });
    assert.strictEqual(result.allowed, false);
  });
});

describe('license gate — conflicting claims', () => {
  it('applies the most restrictive claim when sources disagree', () => {
    // The real situation: World Wide Dishes says CC-BY-4.0 in LICENCE.md and
    // cc-by-nc-sa-4.0 in its Croissant metadata.
    const result = evaluateLicenses({
      datasetId: 'oxai/world-wide-dishes',
      claims: {
        'LICENCE.md': 'CC-BY 4.0',
        'croissant metadata': 'cc-by-nc-sa-4.0',
      },
    });

    assert.strictEqual(result.allowed, false);
    assert.match(result.reasons.join('\n'), /non-commercial/);
    assert.strictEqual(result.warnings.length, 1);
    assert.match(result.warnings[0], /conflicting licence claims/);
  });

  it('allows when two sources agree', () => {
    const result = evaluateLicenses({
      datasetId: 'demo',
      claims: { 'LICENCE.md': 'CC-BY-4.0', metadata: 'cc-by-4.0' },
    });
    assert.strictEqual(result.allowed, true);
    assert.strictEqual(result.warnings.length, 0);
  });

  it('refuses a dataset with no licence claim at all', () => {
    // The real situation: worldcuisines/food-kb publishes no licence.
    const result = evaluateLicenses({ datasetId: 'worldcuisines/food-kb', claims: {} });
    assert.strictEqual(result.allowed, false);
    assert.match(result.reasons[0], /no licence claim/);
  });

  it('carries reasons on the error so callers can print them', () => {
    const result = evaluateLicenses({ datasetId: 'demo', claims: { a: 'CC-BY-NC-4.0' } });
    const error = new LicenseNotClearedError('demo', result);
    assert.match(error.message, /demo cannot be imported/);
    assert.strictEqual(error.reasons.length, 1);
  });
});

describe('column safety', () => {
  it('drops image columns and keeps text', () => {
    const { kept, dropped } = partitionSafeColumns([
      'id',
      'local_name',
      'english_name',
      'countries',
      'public_cc_image_url',
      'uploaded_image_url',
      'dish_photo',
    ]);

    assert.deepStrictEqual(kept, ['id', 'local_name', 'english_name', 'countries']);
    assert.deepStrictEqual(dropped, ['public_cc_image_url', 'uploaded_image_url', 'dish_photo']);
  });
});

describe('CSV parsing', () => {
  it('handles quoted fields, commas and embedded newlines', () => {
    const { columns, records } = parseCsv('a,b\n"x, y","line1\nline2"\n');
    assert.deepStrictEqual(columns, ['a', 'b']);
    assert.deepStrictEqual(records, [{ a: 'x, y', b: 'line1\nline2' }]);
  });

  it('parses the list literal used for multi-valued cells', () => {
    assert.deepStrictEqual(parseListCell("['lunch', 'dinner']"), ['lunch', 'dinner']);
    assert.deepStrictEqual(parseListCell('nan'), []);
    assert.deepStrictEqual(parseListCell(''), []);
    assert.deepStrictEqual(parseListCell('single'), ['single']);
  });
});

describe('vocabulary mapping', () => {
  it('maps the main-dish shapes onto mainCourse', () => {
    assert.deepStrictEqual(mapDishRoles("['Main dish - stand alone (e.g. one pot meal)']"), [
      'mainCourse',
    ]);
    assert.deepStrictEqual(mapDishRoles("['Main dish - eaten with sides']"), ['mainCourse']);
  });

  it('maps a side dish onto sideDish', () => {
    assert.deepStrictEqual(mapDishRoles("['Side dish']"), ['sideDish']);
  });

  it('maps a dish that is both onto both', () => {
    assert.deepStrictEqual(
      mapDishRoles("['Side dish', 'Main dish - stand alone (e.g. one pot meal)']"),
      ['both'],
    );
  });

  it('ignores shapes with no role equivalent', () => {
    assert.deepStrictEqual(mapDishRoles("['Dessert', 'Starter']"), []);
  });

  it('maps the four dayparts onto our meal times', () => {
    assert.deepStrictEqual(mapMealTimes("['breakfast']"), ['morning']);
    assert.deepStrictEqual(mapMealTimes("['lunch']"), ['midday']);
    assert.deepStrictEqual(mapMealTimes("['dinner']"), ['night']);
    assert.deepStrictEqual(mapMealTimes("['snack']"), ['evening']);
  });

  it('expresses anytime as no restriction', () => {
    // An empty list is what our resolver reads as every meal time.
    assert.deepStrictEqual(mapMealTimes("['anytime']"), []);
    assert.deepStrictEqual(mapMealTimes("['lunch', 'anytime']"), ['midday']);
  });
});

describe('reference building', () => {
  const columns = [
    'id',
    'local_name',
    'english_name',
    'countries',
    'regions',
    'time_of_day',
    'type_of_dish',
    'public_cc_image_url',
  ];

  it('merges duplicate dish names and unions their roles', () => {
    const records = [
      {
        english_name: 'Daal',
        countries: 'Nepal',
        regions: 'Bagmati',
        type_of_dish: "['Main dish - eaten with sides']",
        time_of_day: "['lunch']",
        public_cc_image_url: 'https://example.com/a.jpg',
      },
      {
        english_name: 'Daal',
        countries: 'India',
        regions: 'Delhi',
        type_of_dish: "['Side dish']",
        time_of_day: "['dinner']",
        public_cc_image_url: 'https://example.com/b.jpg',
      },
    ];

    const ref = buildReference(records, columns, { datasetId: 'demo' });

    assert.strictEqual(ref.dishCount, 1);
    const [dish] = ref.dishes;
    assert.deepStrictEqual(dish.dishRoles, ['both']);
    assert.deepStrictEqual(dish.mealTimes, ['midday', 'night']);
  });

  it('never carries an image URL through', () => {
    const records = [
      {
        english_name: 'Daal',
        countries: 'Nepal',
        regions: '',
        type_of_dish: "['Main dish - eaten with sides']",
        time_of_day: "['lunch']",
        public_cc_image_url: 'https://example.com/a.jpg',
      },
    ];

    const ref = buildReference(records, columns, { datasetId: 'demo' });
    const serialised = JSON.stringify(ref);

    assert.ok(!serialised.includes('example.com'), 'no image URL should survive');
    // The dropped-column names are recorded deliberately, but no dish may carry image data.
    for (const dish of ref.dishes) {
      assert.ok(
        !Object.keys(dish).some((k) => /image|photo|picture/i.test(k)),
        `dish ${dish.name} must not carry an image field`,
      );
    }
  });

  it('skips rows with no scheduling information', () => {
    const records = [
      { english_name: 'Mystery', type_of_dish: "['Dessert']", time_of_day: "['anytime']" },
    ];
    const ref = buildReference(records, columns, { datasetId: 'demo' });
    assert.strictEqual(ref.dishCount, 0);
  });

  it('falls back to the local name when there is no English name', () => {
    const records = [
      {
        english_name: '',
        local_name: 'Tli Tli',
        type_of_dish: "['Main dish - stand alone (e.g. one pot meal)']",
        time_of_day: "['lunch']",
      },
    ];
    const ref = buildReference(records, columns, { datasetId: 'demo' });
    assert.strictEqual(ref.dishes[0].name, 'Tli Tli');
  });
});