import { test } from 'node:test';
import assert from 'node:assert';
import {
  gregorianToBikramSambat,
  formatBsDate,
  getRituForBsMonth,
  formatLakhCrore,
  toDevanagariDigits
} from './nepali_calendar.js';

test('gregorianToBikramSambat converts anchor date correctly', () => {
  // 2023-04-14 is Baisakh 1, 2080 BS
  const bs = gregorianToBikramSambat(new Date('2023-04-14T00:00:00Z'));
  assert.strictEqual(bs.year, 2080);
  assert.strictEqual(bs.month, 1);
  assert.strictEqual(bs.day, 1);
});

test('gregorianToBikramSambat converts Dashain 2080 date', () => {
  // 2023-10-24 is approximately Kartik 7, 2080 BS (Vijaya Dashami 2080)
  const bs = gregorianToBikramSambat(new Date('2023-10-24T00:00:00Z'));
  assert.strictEqual(bs.year, 2080);
  assert.strictEqual(bs.month, 7);
  assert.strictEqual(bs.day, 7);
});

test('formatBsDate formats date in Nepali and English', () => {
  const bs = { year: 2081, month: 6, day: 15 };
  const formattedNe = formatBsDate(bs, { locale: 'ne' });
  const formattedEn = formatBsDate(bs, { locale: 'en' });

  assert.strictEqual(formattedNe, '२०८१ असोज १५');
  assert.strictEqual(formattedEn, 'Ashwin 15, 2081 BS');
});

test('getRituForBsMonth maps 12 BS months to six ritus', () => {
  assert.strictEqual(getRituForBsMonth(1).id, 'basanta');
  assert.strictEqual(getRituForBsMonth(2).id, 'grishma');
  assert.strictEqual(getRituForBsMonth(4).id, 'barsha');
  assert.strictEqual(getRituForBsMonth(7).id, 'sharad');
  assert.strictEqual(getRituForBsMonth(8).id, 'hemanta');
  assert.strictEqual(getRituForBsMonth(10).id, 'shishir');
  assert.strictEqual(getRituForBsMonth(12).id, 'basanta');
});

test('formatLakhCrore correctly groups South Asian numerals', () => {
  assert.strictEqual(formatLakhCrore(100), '100');
  assert.strictEqual(formatLakhCrore(1000), '1,000');
  assert.strictEqual(formatLakhCrore(100000), '1,00,000');
  assert.strictEqual(formatLakhCrore(1250000), '12,50,000');
  assert.strictEqual(formatLakhCrore(10000000), '1,00,00,000');

  // Devanagari digits with currency
  assert.strictEqual(
    formatLakhCrore(150000, { preferDevanagari: true, includeCurrency: true }),
    'रू १,५०,०००'
  );
  assert.strictEqual(
    formatLakhCrore(150000, { preferDevanagari: false, includeCurrency: true }),
    'NPR 1,50,000'
  );
});

test('toDevanagariDigits maps all digits 0-9', () => {
  assert.strictEqual(toDevanagariDigits('0123456789'), '०१२३४५६७८९');
  assert.strictEqual(toDevanagariDigits(2081), '२०८१');
});
