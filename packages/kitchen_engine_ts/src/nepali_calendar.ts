/**
 * Nepali Localization & Calendar Engine
 * Implements Bikram Sambat (BS) date conversion, Six Ritus calculation,
 * Devanagari numeral mapping, and Lakh-Crore currency/number formatting.
 */

export interface BsDate {
  year: number;
  month: number; // 1 = Baisakh, 12 = Chaitra
  day: number;
}

export type RituName = 'basanta' | 'grishma' | 'barsha' | 'sharad' | 'hemanta' | 'shishir';

export interface RituInfo {
  id: RituName;
  nameEn: string;
  nameNe: string;
  bsMonths: number[];
  element: string;
}

export const NEPALI_MONTHS_NE = [
  'बैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज',
  'कात्तिक', 'मंसिर', 'पुस', 'माघ', 'फागुन', 'चैत'
];

export const NEPALI_MONTHS_EN = [
  'Baisakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra', 'Ashwin',
  'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'
];

export const NEPALI_DAYS_NE = [
  'आइतबार', 'सोमबार', 'मङ्गलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार'
];

export const NEPALI_DAYS_EN = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
];

export const DEVANAGARI_DIGITS = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];

/**
 * Standard Six Ritus (ऋतु) definitions
 */
export const SIX_RITUS: Record<RituName, RituInfo> = {
  basanta: { id: 'basanta', nameEn: 'Basanta (Spring)', nameNe: 'बसन्त', bsMonths: [12, 1], element: 'Air & Blossom' },
  grishma: { id: 'grishma', nameEn: 'Grishma (Summer)', nameNe: 'ग्रीष्म', bsMonths: [2, 3], element: 'Heat & Sun' },
  barsha: { id: 'barsha', nameEn: 'Barsha (Monsoon)', nameNe: 'वर्षा', bsMonths: [4, 5], element: 'Rain & Growth' },
  sharad: { id: 'sharad', nameEn: 'Sharad (Autumn)', nameNe: 'शरद', bsMonths: [6, 7], element: 'Harvest & Festivity' },
  hemanta: { id: 'hemanta', nameEn: 'Hemanta (Late Autumn/Pre-Winter)', nameNe: 'हेमन्त', bsMonths: [8, 9], element: 'Crisp Dew & Fermentation' },
  shishir: { id: 'shishir', nameEn: 'Shishir (Winter)', nameNe: 'शिशिर', bsMonths: [10, 11], element: 'Frost & Roots' }
};

/**
 * Calendar month days reference table for BS 2075 - 2085.
 * Format: 12 numbers per year representing days in [Baisakh, Jestha, ..., Chaitra]
 */
export const BS_CALENDAR_DATA: Record<number, number[]> = {
  2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2080: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2082: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
  2085: [31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30]
};

// Anchor Reference: 2080-01-01 BS = 2023-04-14 AD
const ANCHOR_BS: BsDate = { year: 2080, month: 1, day: 1 };
const ANCHOR_AD = new Date(Date.UTC(2023, 3, 14)); // month index 3 is April

/**
 * Converts Western digits string or number to Devanagari script (e.g. 1234 -> १२३४)
 */
export function toDevanagariDigits(num: number | string): string {
  const str = num.toString();
  return str.replace(/[0-9]/g, (digit) => DEVANAGARI_DIGITS[parseInt(digit, 10)]);
}

/**
 * Formats a number according to South Asian Lakh-Crore grouping
 * e.g. 100000 -> "1,00,000", 12500000 -> "1,25,00,000"
 */
export function formatLakhCrore(
  amount: number,
  options: { preferDevanagari?: boolean; includeCurrency?: boolean } = {}
): string {
  const { preferDevanagari = false, includeCurrency = false } = options;
  const isNegative = amount < 0;
  const absAmount = Math.abs(Math.round(amount));

  const str = absAmount.toString();
  let result = '';

  if (str.length <= 3) {
    result = str;
  } else {
    // Last three digits
    const lastThree = str.slice(-3);
    const remaining = str.slice(0, -3);

    // Group remaining into pairs from right to left
    const paired: string[] = [];
    let rem = remaining;
    while (rem.length > 2) {
      paired.unshift(rem.slice(-2));
      rem = rem.slice(0, -2);
    }
    if (rem.length > 0) {
      paired.unshift(rem);
    }

    result = `${paired.join(',')},${lastThree}`;
  }

  if (isNegative) {
    result = `-${result}`;
  }

  if (preferDevanagari) {
    result = toDevanagariDigits(result);
  }

  if (includeCurrency) {
    const symbol = preferDevanagari ? 'रू ' : 'NPR ';
    result = `${symbol}${result}`;
  }

  return result;
}

/**
 * Determines the active Ritu from a BS Month (1 to 12)
 */
export function getRituForBsMonth(bsMonth: number): RituInfo {
  if (bsMonth === 12 || bsMonth === 1) return SIX_RITUS.basanta;
  if (bsMonth === 2 || bsMonth === 3) return SIX_RITUS.grishma;
  if (bsMonth === 4 || bsMonth === 5) return SIX_RITUS.barsha;
  if (bsMonth === 6 || bsMonth === 7) return SIX_RITUS.sharad;
  if (bsMonth === 8 || bsMonth === 9) return SIX_RITUS.hemanta;
  return SIX_RITUS.shishir; // 10, 11
}

/**
 * Converts Gregorian AD Date to Bikram Sambat (BS) Date
 */
export function gregorianToBikramSambat(adDate: Date): BsDate {
  const targetUtc = Date.UTC(adDate.getFullYear(), adDate.getMonth(), adDate.getDate());
  let diffDays = Math.round((targetUtc - ANCHOR_AD.getTime()) / (1000 * 60 * 60 * 24));

  let currentYear = ANCHOR_BS.year;
  let currentMonth = ANCHOR_BS.month;
  let currentDay = ANCHOR_BS.day;

  if (diffDays >= 0) {
    while (diffDays > 0) {
      const yearDays = BS_CALENDAR_DATA[currentYear];
      if (!yearDays) {
        throw new Error(`BS year ${currentYear} out of supported range`);
      }
      const daysInMonth = yearDays[currentMonth - 1];
      const remainingInMonth = daysInMonth - currentDay;

      if (diffDays <= remainingInMonth) {
        currentDay += diffDays;
        diffDays = 0;
      } else {
        diffDays -= (remainingInMonth + 1);
        currentDay = 1;
        currentMonth++;
        if (currentMonth > 12) {
          currentMonth = 1;
          currentYear++;
        }
      }
    }
  } else {
    diffDays = Math.abs(diffDays);
    while (diffDays > 0) {
      if (currentDay > diffDays) {
        currentDay -= diffDays;
        diffDays = 0;
      } else {
        diffDays -= currentDay;
        currentMonth--;
        if (currentMonth < 1) {
          currentMonth = 12;
          currentYear--;
        }
        const yearDays = BS_CALENDAR_DATA[currentYear];
        if (!yearDays) {
          throw new Error(`BS year ${currentYear} out of supported range`);
        }
        currentDay = yearDays[currentMonth - 1];
      }
    }
  }

  return { year: currentYear, month: currentMonth, day: currentDay };
}

/**
 * Formats a BS Date into localized string
 */
export function formatBsDate(
  bs: BsDate,
  options: { locale?: 'ne' | 'en'; includeYear?: boolean } = {}
): string {
  const { locale = 'ne', includeYear = true } = options;
  const monthName = locale === 'ne'
    ? NEPALI_MONTHS_NE[bs.month - 1]
    : NEPALI_MONTHS_EN[bs.month - 1];

  const dayStr = locale === 'ne' ? toDevanagariDigits(bs.day) : bs.day.toString();
  const yearStr = locale === 'ne' ? toDevanagariDigits(bs.year) : bs.year.toString();

  if (includeYear) {
    return locale === 'ne'
      ? `${yearStr} ${monthName} ${dayStr}`
      : `${monthName} ${dayStr}, ${yearStr} BS`;
  }
  return `${monthName} ${dayStr}`;
}
