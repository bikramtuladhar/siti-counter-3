/**
 * Siti Counter 3 - OCR & Label Parser Engine (TypeScript)
 * Section 22.1: On-device receipt OCR for pantry auto-fill and packaged food allergen scanning.
 */

import { AllergenCatalog } from './allergen_engine.js';

export interface ParsedReceiptItem {
  rawLine: string;
  name: string;
  matchedIngredientId?: string;
  quantityGrams?: number;
  unit?: string;
  price?: number;
  confidence: number;
}

export interface ParsedReceipt {
  merchantName?: string;
  receiptDate?: string;
  items: ParsedReceiptItem[];
  totalAmount?: number;
  currency: string;
  rawText: string;
}

export type AllergenWarningType = 'contains' | 'may_contain';

export interface MemberAllergenAlert {
  memberId: string;
  memberName: string;
  allergen: string;
  severity: 'severe' | 'moderate' | 'mild';
  warningType: AllergenWarningType;
  matchedSnippet: string;
  alertEn: string;
  alertNe: string;
}

export interface LabelHighlightSpan {
  start: number;
  end: number;
  matchedText: string;
  allergen: string;
  warningType: AllergenWarningType;
}

export interface LabelScanResult {
  rawText: string;
  detectedAllergens: string[];
  facilityWarnings: string[];
  memberAlerts: MemberAllergenAlert[];
  isSafeForHousehold: boolean;
  highlightSpans: LabelHighlightSpan[];
}

export interface HouseholdMemberAllergyInput {
  memberId: string;
  memberName: string;
  allergen: string;
  severity: 'severe' | 'moderate' | 'mild';
}

// Canonical ingredient mapping rules for supermarket receipts in Nepal & Diaspora
const INGREDIENT_KEYWORDS: Array<{ id: string; patterns: RegExp[]; defaultGrams: number }> = [
  { id: 'potato', patterns: [/potato/i, /aloo/i, /alu/i, /आलु/], defaultGrams: 1000 },
  { id: 'tomato', patterns: [/tomato/i, /golbheda/i, /गोलभेडा/], defaultGrams: 500 },
  { id: 'onion', patterns: [/onion/i, /pyaj/i, /प्यार्ज/], defaultGrams: 1000 },
  { id: 'cauliflower', patterns: [/cauliflower/i, /gobi/i, /kauli/i, /काउली/], defaultGrams: 800 },
  { id: 'cabbage', patterns: [/cabbage/i, /banda/i, /बन्दा/], defaultGrams: 700 },
  { id: 'mustard_greens', patterns: [/mustard\s*green/i, /rayo/i, /रायो/], defaultGrams: 400 },
  { id: 'spinach', patterns: [/spinach/i, /palungo/i, /पालुङ्गो/], defaultGrams: 300 },
  { id: 'ginger', patterns: [/ginger/i, /aduwa/i, /अदुवा/], defaultGrams: 200 },
  { id: 'garlic', patterns: [/garlic/i, /lasun/i, /लसुन/], defaultGrams: 200 },
  { id: 'cilantro', patterns: [/coriander/i, /dhaniya/i, /धनिया/], defaultGrams: 150 },
  { id: 'rice', patterns: [/basmati/i, /rice/i, /chamal/i, /चामल/], defaultGrams: 5000 },
  { id: 'lentils_yellow', patterns: [/yellow\s*lentil/i, /moong/i, /मुङ्ग/], defaultGrams: 1000 },
  { id: 'lentils_black', patterns: [/black\s*lentil/i, /maas/i, /मास/], defaultGrams: 1000 },
  { id: 'mustard_oil', patterns: [/mustard\s*oil/i, /tori.*tel/i, /तोरीको\s*तेल/], defaultGrams: 1000 },
  { id: 'sunflower_oil', patterns: [/sunflower\s*oil/i, /सूर्यमुखी/], defaultGrams: 1000 },
  { id: 'flour_wheat', patterns: [/wheat\s*flour/i, /atta/i, /आटा/], defaultGrams: 2000 },
  { id: 'salt', patterns: [/salt/i, /noon/i, /नुन/], defaultGrams: 1000 },
];

// Allergen synonym dictionary for food label OCR parsing
const ALLERGEN_KEYWORD_MAP: Record<string, RegExp[]> = {
  [AllergenCatalog.gluten]: [
    /gluten/i,
    /wheat/i,
    /barley/i,
    /rye/i,
    /oats/i,
    /spelt/i,
    /maida/i,
    /sooji/i,
    /semolina/i,
    /गहुँ/i,
    /मैदा/i,
    /सूजी/i,
    /जौ/i,
  ],
  [AllergenCatalog.milk]: [
    /milk/i,
    /dairy/i,
    /whey/i,
    /casein/i,
    /butter/i,
    /ghee/i,
    /cheese/i,
    /paneer/i,
    /curd/i,
    /dahi/i,
    /chhurpi/i,
    /lactose/i,
    /दूध/i,
    /घ्यु/i,
    /पनीर/i,
    /दही/i,
  ],
  [AllergenCatalog.peanuts]: [/peanut/i, /groundnut/i, /बदाम/i],
  [AllergenCatalog.nuts]: [
    /tree\s*nut/i,
    /almond/i,
    /cashew/i,
    /walnut/i,
    /pistachio/i,
    /hazelnut/i,
    /काजु/i,
    /हाडे\s*बदाम/i,
    /ओखर/i,
    /पिस्ता/i,
  ],
  [AllergenCatalog.soy]: [/soy/i, /soya/i, /soybean/i, /tofu/i, /भटमास/i],
  [AllergenCatalog.eggs]: [/egg/i, /albumin/i, /अण्डा/i],
  [AllergenCatalog.fish]: [/fish/i, /माछा/i],
  [AllergenCatalog.crustaceans]: [/crustacean/i, /shrimp/i, /prawn/i, /crab/i, /lobster/i, /झिङ्गे\s*माछा/i],
  [AllergenCatalog.mustard]: [/mustard/i, /सरस्यूँ/i, /तोरी/i],
  [AllergenCatalog.mustardOil]: [/mustard\s*oil/i, /तोरीको\s*तेल/i],
  [AllergenCatalog.sesame]: [/sesame/i, /til/i, /तिल/i],
  [AllergenCatalog.buckwheat]: [/buckwheat/i, /fapar/i, /फापर/i],
  [AllergenCatalog.fenugreek]: [/fenugreek/i, /methi/i, /मेथी/i],
  [AllergenCatalog.sulphites]: [/sulphite/i, /sulfite/i, /sulphur\s*dioxide/i],
  [AllergenCatalog.celery]: [/celery/i],
};

export class OcrReceiptParser {
  /**
   * Parses raw OCR text lines from grocery receipts (Bhatbhateni, BigMart, Salesberry, Kirana).
   */
  static parseReceipt(rawText: string): ParsedReceipt {
    const lines = rawText
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length > 0);

    let merchantName: string | undefined;
    let receiptDate: string | undefined;
    let totalAmount: number | undefined;
    const items: ParsedReceiptItem[] = [];

    // 1. Detect Merchant Name
    const merchantPatterns = [
      { name: 'Bhatbhateni Supermarket', regex: /bhatbhateni|bbsm/i },
      { name: 'BigMart Online', regex: /big\s*mart/i },
      { name: 'SalesBerry Department Store', regex: /salesberry/i },
      { name: 'Namaste Supermarket', regex: /namaste\s*supermarket/i },
      { name: 'Haat Bazaar Bill', regex: /haat\s*bazaar|कृषि\s*बजार/i },
    ];

    for (const line of lines.slice(0, 6)) {
      for (const m of merchantPatterns) {
        if (m.regex.test(line)) {
          merchantName = m.name;
          break;
        }
      }
      if (merchantName) break;
    }

    // 2. Detect Date
    const dateRegex = /(\d{4}[-/.]\d{1,2}[-/.]\d{1,2})|(\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})/;
    for (const line of lines) {
      const match = line.match(dateRegex);
      if (match) {
        receiptDate = match[0];
        break;
      }
    }

    // 3. Detect Items and Prices
    // Example receipt lines:
    // "POTATO RED 1.5 KG      Rs 97.50"
    // "BBSM Mustard Oil 1L     320.00"
    // "Tomato Local 500g       45.00"
    // "Aloo Jyoti 2kg @ 50     100.00"
    const priceRegex = /(?:rs\.?|npr|रु\.?)?\s*([0-9०-९]+(?:[.,][0-9०-९]{2}))\b/i;
    const qtyRegex = /([0-9०-९]+(?:\.[0-9०-९]+)?)\s*(kg|g|gm|ltr|l|ml|packet|pkt|pcs|pc|के\.?जी\.?|माना|पाउ|धार्नी)/i;

    const toAsciiDigits = (str: string) => {
      const devanagariMap: Record<string, string> = {
        '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
        '५': '5', '६': '6', '७': '7', '८': '8', '९': '9',
      };
      return str.replace(/[०-९]/g, (d) => devanagariMap[d] ?? d);
    };

    for (const line of lines) {
      // Ignore header/footer lines
      if (
        /subtotal|total|cash|change|vat|tax|invoice|phone|pan\s*no|thank\s*you|जम्मा|कुल|रसिद|मिति|धन्यवाद/i.test(
          line
        )
      ) {
        const totalMatch = line.match(
          /(?:total|net\s*amt|grand\s*total|जम्मा|कुल)\D*([0-9०-९]+(?:\.[0-9०-९]{2})?)/i
        );
        if (totalMatch) {
          totalAmount = parseFloat(toAsciiDigits(totalMatch[1]));
        }
        continue;
      }

      // Check for price on this line
      const priceMatch = line.match(priceRegex);
      let price: number | undefined;
      if (priceMatch) {
        price = parseFloat(toAsciiDigits(priceMatch[1]).replace(',', ''));
      }

      // Check for quantity on this line
      const qtyMatch = line.match(qtyRegex);
      let quantityGrams: number | undefined;
      let unit: string | undefined;

      if (qtyMatch) {
        const val = parseFloat(toAsciiDigits(qtyMatch[1]));
        unit = qtyMatch[2].toLowerCase();
        if (unit === 'kg' || unit.includes('के')) quantityGrams = val * 1000;
        else if (unit === 'g' || unit === 'gm') quantityGrams = val;
        else if (unit === 'l' || unit === 'ltr') quantityGrams = val * 1000;
        else if (unit === 'ml') quantityGrams = val;
        else if (unit === 'पाउ') quantityGrams = val * 250;
        else if (unit === 'धार्नी') quantityGrams = val * 2500;
        else if (unit === 'माना') quantityGrams = val * 500;
        else quantityGrams = val * 1000;
      }

      // Match canonical ingredient
      let matchedIngredientId: string | undefined;
      for (const ing of INGREDIENT_KEYWORDS) {
        if (ing.patterns.some((p) => p.test(line))) {
          matchedIngredientId = ing.id;
          if (!quantityGrams) {
            quantityGrams = ing.defaultGrams;
          }
          break;
        }
      }

      // Only add line if an ingredient or price was detected
      if (matchedIngredientId || (price && price > 0 && line.length > 5)) {
        // Strip price text to get a clean item name
        const cleanName = line
          .replace(priceRegex, '')
          .replace(/[0-9]+(?:\.[0-9]+)?\s*(?:kg|g|gm|l|ltr|ml|pkt|pcs)\b/gi, '')
          .replace(/[@#*]/g, '')
          .trim();

        items.push({
          rawLine: line,
          name: cleanName.length > 0 ? cleanName : (matchedIngredientId ?? 'Grocery Item'),
          matchedIngredientId,
          quantityGrams,
          unit: unit ?? 'g',
          price,
          confidence: matchedIngredientId ? 0.95 : 0.7,
        });
      }
    }

    if (!totalAmount && items.length > 0) {
      totalAmount = items.reduce((acc, curr) => acc + (curr.price ?? 0), 0);
    }

    return {
      merchantName,
      receiptDate,
      items,
      totalAmount,
      currency: 'NPR',
      rawText,
    };
  }
}

export class FoodLabelScanner {
  /**
   * Scans packaged food ingredient text and allergy warnings, cross-checking
   * with household member allergy profiles.
   */
  static scanLabel(
    rawText: string,
    householdMembers: HouseholdMemberAllergyInput[] = []
  ): LabelScanResult {
    const textLower = rawText.toLowerCase();
    const detectedAllergens = new Set<string>();
    const facilityWarnings = new Set<string>();
    const highlightSpans: LabelHighlightSpan[] = [];

    // Split text into explicit "Contains" vs "May contain / Facility" sections
    const mayContainMatch = textLower.search(
      /may\s+contain|facility|traces\s+of|processed\s+on\s+shared|अवशेष\s+हुन\s+सक्छ/i
    );

    const containsSection = mayContainMatch !== -1 ? textLower.substring(0, mayContainMatch) : textLower;
    const mayContainSection = mayContainMatch !== -1 ? textLower.substring(mayContainMatch) : '';

    for (const [allergen, patterns] of Object.entries(ALLERGEN_KEYWORD_MAP)) {
      for (const pattern of patterns) {
        // Check in contains section
        const containsMatch = containsSection.match(pattern);
        if (containsMatch && containsMatch.index !== undefined) {
          detectedAllergens.add(allergen);
          highlightSpans.push({
            start: containsMatch.index,
            end: containsMatch.index + containsMatch[0].length,
            matchedText: containsMatch[0],
            allergen,
            warningType: 'contains',
          });
          break;
        }

        // Check in may contain section
        if (mayContainSection.length > 0) {
          const mayMatch = mayContainSection.match(pattern);
          if (mayMatch && mayMatch.index !== undefined) {
            facilityWarnings.add(allergen);
            const globalIndex = mayContainMatch + mayMatch.index;
            highlightSpans.push({
              start: globalIndex,
              end: globalIndex + mayMatch[0].length,
              matchedText: mayMatch[0],
              allergen,
              warningType: 'may_contain',
            });
            break;
          }
        }
      }
    }

    // Cross-check against household members
    const memberAlerts: MemberAllergenAlert[] = [];
    let isSafeForHousehold = true;

    for (const member of householdMembers) {
      const isContains = detectedAllergens.has(member.allergen);
      const isMayContain = facilityWarnings.has(member.allergen);

      if (isContains || isMayContain) {
        const warningType: AllergenWarningType = isContains ? 'contains' : 'may_contain';

        if (member.severity === 'severe' || isContains) {
          isSafeForHousehold = false;
        }

        const allergenNameEn = member.allergen.replace('_', ' ');
        const snippet = isContains ? `Contains ${allergenNameEn}` : `May contain ${allergenNameEn}`;

        const alertEn = isContains
          ? `DANGER: Contains ${allergenNameEn}! ${member.memberName} has ${member.severity} allergy.`
          : `CAUTION: Traces of ${allergenNameEn} possible. ${member.memberName} has ${member.severity} allergy.`;

        const alertNe = isContains
          ? `खतरा: यसमा ${allergenNameEn} समावेश छ! ${member.memberName} लाई कडा एलर्जी छ।`
          : `सावधानी: यसमा ${allergenNameEn} को अवशेष हुन सक्छ। ${member.memberName} लाई एलर्जी छ।`;

        memberAlerts.push({
          memberId: member.memberId,
          memberName: member.memberName,
          allergen: member.allergen,
          severity: member.severity,
          warningType,
          matchedSnippet: snippet,
          alertEn,
          alertNe,
        });
      }
    }

    return {
      rawText,
      detectedAllergens: Array.from(detectedAllergens),
      facilityWarnings: Array.from(facilityWarnings),
      memberAlerts,
      isSafeForHousehold,
      highlightSpans,
    };
  }
}
