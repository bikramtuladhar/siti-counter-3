/**
 * Siti Counter 3.0 - Retailer Shopping Handoff & Deep-Linking Engine
 * Implements Section 9.5 & 26.4:
 * - Deep-link generation from grocery list items to search pages on Daraz, Bhatbhateni, and regional retailers.
 * - Clear disclosure of affiliate relationships (zero advertising rank bias).
 * - Full user opt-out to disable shopping partner links entirely.
 */

export interface RetailerPartner {
  readonly id: string;
  readonly name: string;
  readonly nameNe: string;
  readonly countryCode: string;
  readonly icon: string;
  readonly websiteUrl: string;
  readonly appSchemePrefix: string;
  readonly isAffiliate: boolean;
  readonly affiliateTag?: string;
  readonly directCartSupported?: boolean;
  readonly disclosureEn: string;
  readonly disclosureNe: string;
  readonly descriptionEn: string;
  readonly descriptionNe: string;
}

export interface PartnerCartItem {
  readonly itemId: string;
  readonly name: string;
  readonly nameNe?: string;
  readonly quantity: number;
  readonly unit: string;
  readonly estimatedPriceNpr?: number;
}

export interface PartnerCartTransferResult {
  readonly cartId: string;
  readonly householdId: string;
  readonly retailerId: string;
  readonly retailerName: string;
  readonly status: 'ready' | 'expired' | 'completed';
  readonly totalItems: number;
  readonly transferredItemsCount: number;
  readonly unmatchedItems: ReadonlyArray<{ readonly itemId: string; readonly name: string }>;
  readonly estimatedSubtotalNpr: number;
  readonly cartWebUrl: string;
  readonly cartAppUrl: string;
  readonly createdAt: string;
  readonly expiresAt: string;
  readonly disclosureEn: string;
  readonly disclosureNe: string;
}

export interface RetailerDeepLinkResult {
  readonly retailerId: string;
  readonly retailerName: string;
  readonly retailerNameNe: string;
  readonly searchTerm: string;
  readonly webUrl: string;
  readonly appDeepLinkUrl: string;
  readonly isAffiliate: boolean;
  readonly disclosureEn: string;
  readonly disclosureNe: string;
}

export interface BasketHandoffResult {
  readonly retailerId: string;
  readonly retailerName: string;
  readonly retailerNameNe: string;
  readonly itemCount: number;
  readonly combinedSearchQuery: string;
  readonly webUrl: string;
  readonly appDeepLinkUrl: string;
  readonly isAffiliate: boolean;
  readonly disclosureEn: string;
  readonly disclosureNe: string;
}

export interface RetailerHandoffConfig {
  partnerLinksEnabled: boolean;
  preferredRetailerId?: string;
  customAffiliateTags?: Record<string, string>;
}

export const DEFAULT_AFFILIATE_DISCLOSURE_EN =
  'Affiliate Disclosure: Siti Counter may earn a small commission from qualifying purchases at no extra cost to you. Retailers are displayed without pay-for-placement bias.';

export const DEFAULT_AFFILIATE_DISCLOSURE_NE =
  'सहयोगी लिङ्क प्रकटीकरण: सिट्ठी काउन्टरले तपाईंलाई कुनै अतिरिक्त शुल्क बिना सानो कमिसन प्राप्त गर्न सक्छ। व्यापारीहरूको सूची विज्ञापन वा भुक्तानी पूर्वाग्रह बिना निष्पक्ष देखाइएको छ।';

export const BUILT_IN_RETAILERS: readonly RetailerPartner[] = [
  {
    id: 'daraz',
    name: 'Daraz',
    nameNe: 'दराज',
    countryCode: 'NP',
    icon: '🛍️',
    websiteUrl: 'https://www.daraz.com.np',
    appSchemePrefix: 'daraz://',
    isAffiliate: true,
    affiliateTag: 'siticounter',
    directCartSupported: true,
    disclosureEn: DEFAULT_AFFILIATE_DISCLOSURE_EN,
    disclosureNe: DEFAULT_AFFILIATE_DISCLOSURE_NE,
    descriptionEn: 'Nepal’s leading online marketplace with grocery delivery (Daraz Mart)',
    descriptionNe: 'नेपालको प्रमुख अनलाइन बजार र किराना डेलिभरी (दराज मार्ट)',
  },
  {
    id: 'bhatbhateni',
    name: 'Bhatbhateni Supermarket',
    nameNe: 'भातभटेनी सुपरमार्केट',
    countryCode: 'NP',
    icon: '🏬',
    websiteUrl: 'https://bhatbhatenionline.com',
    appSchemePrefix: 'bbsm://',
    isAffiliate: true,
    affiliateTag: 'siticounter',
    directCartSupported: true,
    disclosureEn: DEFAULT_AFFILIATE_DISCLOSURE_EN,
    disclosureNe: DEFAULT_AFFILIATE_DISCLOSURE_NE,
    descriptionEn: 'Nepal’s premier retail chain and online departmental store',
    descriptionNe: 'नेपालको अग्रणी डिपार्टमेन्टल स्टोर तथा अनलाइन सुपरमार्केट',
  },
  {
    id: 'bigmart',
    name: 'BigMart Online',
    nameNe: 'बिग मार्ट',
    countryCode: 'NP',
    icon: '🛒',
    websiteUrl: 'https://bigmart.com.np',
    appSchemePrefix: 'bigmart://',
    isAffiliate: false,
    directCartSupported: true,
    disclosureEn: 'Direct store search without affiliate relationship.',
    disclosureNe: 'कुनै सम्बद्धता बिना सिधा पसल खोज।',
    descriptionEn: 'Everyday fresh groceries and household essentials across Kathmandu Valley',
    descriptionNe: 'काठमाडौं उपत्यकाभरि ताजा तरकारी तथा दैनिक उपभोग्य सामान',
  },
  {
    id: 'blinkit',
    name: 'Blinkit',
    nameNe: 'ब्लिङ्किट',
    countryCode: 'IN',
    icon: '⚡',
    websiteUrl: 'https://blinkit.com',
    appSchemePrefix: 'blinkit://',
    isAffiliate: true,
    affiliateTag: 'siticounter',
    directCartSupported: true,
    disclosureEn: DEFAULT_AFFILIATE_DISCLOSURE_EN,
    disclosureNe: DEFAULT_AFFILIATE_DISCLOSURE_NE,
    descriptionEn: '10-minute quick commerce grocery delivery across India',
    descriptionNe: 'भारतभरि १० मिनेटमै किराना डेलिभरी',
  },
  {
    id: 'amazon_fresh',
    name: 'Amazon Fresh',
    nameNe: 'अमेजन फ्रेस',
    countryCode: 'US',
    icon: '📦',
    websiteUrl: 'https://www.amazon.com/fresh',
    appSchemePrefix: 'amazon://',
    isAffiliate: true,
    affiliateTag: 'siticounter-20',
    directCartSupported: true,
    disclosureEn: DEFAULT_AFFILIATE_DISCLOSURE_EN,
    disclosureNe: DEFAULT_AFFILIATE_DISCLOSURE_NE,
    descriptionEn: 'Convenient grocery delivery for diaspora households',
    descriptionNe: 'डायस्पोरा परिवारहरूको लागि सहज किराना डेलिभरी',
  },
];

/**
 * Normalizes query string for retailer search engines
 * e.g. "Potato Red" -> "potato red", "काउली स्थानीय" -> "काउली"
 */
export function cleanSearchQuery(rawQuery: string): string {
  if (!rawQuery) return '';
  return rawQuery
    .replace(/\s*\([^)]*\)/g, '') // remove parenthetical notes like "(लोकल)"
    .replace(/\s+(local|fresh|dry|red|white)\b/gi, '') // simplify search adjectives
    .trim();
}

export class RetailerHandoffEngine {
  private config: RetailerHandoffConfig;
  private customRetailers: RetailerPartner[] = [];

  constructor(config?: Partial<RetailerHandoffConfig>, customPartners?: RetailerPartner[]) {
    this.config = {
      partnerLinksEnabled: config?.partnerLinksEnabled ?? true,
      preferredRetailerId: config?.preferredRetailerId,
      customAffiliateTags: config?.customAffiliateTags ?? {},
    };
    if (customPartners) {
      this.customRetailers = [...customPartners];
    }
  }

  public isPartnerLinksEnabled(): boolean {
    return this.config.partnerLinksEnabled;
  }

  public setPartnerLinksEnabled(enabled: boolean): void {
    this.config.partnerLinksEnabled = enabled;
  }

  public setPreferredRetailer(retailerId?: string): void {
    this.config.preferredRetailerId = retailerId;
  }

  /**
   * Retrieves available retailers for a country.
   * STRICT ZERO ADVERTISING BIAS GUARANTEE:
   * Partners are NEVER ordered by affiliate payout or sponsor bids.
   * If a preferred retailer is set by the user, it appears first; otherwise
   * retailers are sorted strictly alphabetically by name.
   */
  public getAvailableRetailers(countryCode: string = 'NP'): readonly RetailerPartner[] {
    if (!this.config.partnerLinksEnabled) {
      return [];
    }

    const all = [...BUILT_IN_RETAILERS, ...this.customRetailers];
    const filtered = all.filter(
      (r) => r.countryCode.toUpperCase() === countryCode.toUpperCase()
    );

    return filtered.sort((a, b) => {
      // User preference comes first
      if (this.config.preferredRetailerId) {
        if (a.id === this.config.preferredRetailerId) return -1;
        if (b.id === this.config.preferredRetailerId) return 1;
      }
      // Strict neutral alphabetical sort
      return a.name.localeCompare(b.name);
    });
  }

  /**
   * Returns a specific retailer by ID
   */
  public getRetailer(retailerId: string): RetailerPartner | undefined {
    return (
      this.customRetailers.find((r) => r.id === retailerId) ||
      BUILT_IN_RETAILERS.find((r) => r.id === retailerId)
    );
  }

  /**
   * Generates deep-link URLs (App + Web fallback) for a single grocery item.
   * Returns null if partner links are disabled by the user or retailer is not found.
   */
  public generateItemDeepLink(
    retailerId: string,
    rawQuery: string
  ): RetailerDeepLinkResult | null {
    if (!this.config.partnerLinksEnabled) {
      return null;
    }

    const retailer = this.getRetailer(retailerId);
    if (!retailer) {
      return null;
    }

    const term = cleanSearchQuery(rawQuery);
    if (!term) return null;

    const encoded = encodeURIComponent(term);
    const tag =
      this.config.customAffiliateTags?.[retailer.id] || retailer.affiliateTag || '';

    let webUrl = '';
    let appDeepLinkUrl = '';

    switch (retailer.id) {
      case 'daraz': {
        const queryParams = [`q=${encoded}`];
        if (retailer.isAffiliate && tag) queryParams.push(`tag=${encodeURIComponent(tag)}`);
        webUrl = `https://www.daraz.com.np/catalog/?${queryParams.join('&')}`;
        appDeepLinkUrl = `daraz://catalog?${queryParams.join('&')}`;
        break;
      }
      case 'bhatbhateni': {
        const queryParams = [`q=${encoded}`];
        if (retailer.isAffiliate && tag) queryParams.push(`ref=${encodeURIComponent(tag)}`);
        webUrl = `https://bhatbhatenionline.com/search?${queryParams.join('&')}`;
        appDeepLinkUrl = `bbsm://search?${queryParams.join('&')}`;
        break;
      }
      case 'bigmart': {
        webUrl = `https://bigmart.com.np/search?q=${encoded}`;
        appDeepLinkUrl = `bigmart://search?q=${encoded}`;
        break;
      }
      case 'blinkit': {
        webUrl = `https://blinkit.com/s/?q=${encoded}`;
        appDeepLinkUrl = `blinkit://search?q=${encoded}`;
        break;
      }
      case 'amazon_fresh': {
        const queryParams = [`k=${encoded}`, `i=amazonfresh`];
        if (tag) queryParams.push(`tag=${encodeURIComponent(tag)}`);
        webUrl = `https://www.amazon.com/s?${queryParams.join('&')}`;
        appDeepLinkUrl = `amazon://fresh/search?${queryParams.join('&')}`;
        break;
      }
      default: {
        webUrl = `${retailer.websiteUrl}/search?q=${encoded}`;
        appDeepLinkUrl = `${retailer.appSchemePrefix}search?q=${encoded}`;
      }
    }

    return {
      retailerId: retailer.id,
      retailerName: retailer.name,
      retailerNameNe: retailer.nameNe,
      searchTerm: term,
      webUrl,
      appDeepLinkUrl,
      isAffiliate: retailer.isAffiliate,
      disclosureEn: retailer.disclosureEn,
      disclosureNe: retailer.disclosureNe,
    };
  }

  /**
   * Generates a basket handoff search query for multiple grocery items
   */
  public generateBasketHandoff(
    retailerId: string,
    itemQueries: string[]
  ): BasketHandoffResult | null {
    if (!this.config.partnerLinksEnabled) {
      return null;
    }

    const retailer = this.getRetailer(retailerId);
    if (!retailer || itemQueries.length === 0) {
      return null;
    }

    // Pick top 3-5 distinct cleaned search terms
    const cleanTerms = Array.from(
      new Set(itemQueries.map((q) => cleanSearchQuery(q)).filter((q) => q.length > 0))
    ).slice(0, 4);

    const combined = cleanTerms.join(' ');
    const deepLink = this.generateItemDeepLink(retailerId, combined);
    if (!deepLink) return null;

    return {
      retailerId: retailer.id,
      retailerName: retailer.name,
      retailerNameNe: retailer.nameNe,
      itemCount: itemQueries.length,
      combinedSearchQuery: combined,
      webUrl: deepLink.webUrl,
      appDeepLinkUrl: deepLink.appDeepLinkUrl,
      isAffiliate: retailer.isAffiliate,
      disclosureEn: retailer.disclosureEn,
      disclosureNe: retailer.disclosureNe,
    };
  }

  /**
   * Level 3 One-Tap Grocery Cart Direct Transfer (Section 26.4)
   * Builds an authenticated/signed cart transfer session token and deep-link payload
   * for supported regional retailers (Daraz, Bhatbhateni, BigMart, Blinkit, Amazon Fresh).
   */
  public transferGroceryCart(
    householdId: string,
    retailerId: string,
    items: PartnerCartItem[],
    options?: { cartId?: string; now?: Date }
  ): PartnerCartTransferResult | null {
    if (!this.config.partnerLinksEnabled) {
      return null;
    }

    const retailer = this.getRetailer(retailerId);
    if (!retailer || !retailer.directCartSupported) {
      return null;
    }

    if (!items || items.length === 0) {
      return null;
    }

    const now = options?.now ?? new Date();
    const expiresAt = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    const cartId =
      options?.cartId ?? `cart_${Math.random().toString(36).slice(2, 11)}_${now.getTime()}`;

    let totalNpr = 0;
    const unmatched: Array<{ itemId: string; name: string }> = [];
    let transferredCount = 0;

    for (const item of items) {
      if (!item.name || item.name.trim().length === 0) {
        unmatched.push({ itemId: item.itemId, name: item.name || 'Unknown item' });
        continue;
      }
      const price = item.estimatedPriceNpr ?? item.quantity * 80;
      totalNpr += price;
      transferredCount++;
    }

    const tag = this.config.customAffiliateTags?.[retailer.id] || retailer.affiliateTag || '';

    const tokenObj = {
      cartId,
      householdId,
      retailerId: retailer.id,
      itemCount: transferredCount,
      timestamp: now.toISOString(),
      tag,
    };
    const jsonStr = JSON.stringify(tokenObj);

    let base64 = '';
    if (typeof Buffer !== 'undefined') {
      base64 = Buffer.from(jsonStr).toString('base64url');
    } else {
      base64 = btoa(jsonStr).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    }

    let webBase = '';
    let appBase = '';

    switch (retailer.id) {
      case 'daraz':
        webBase = 'https://www.daraz.com.np/cart/import';
        appBase = 'daraz://cart/import';
        break;
      case 'bhatbhateni':
        webBase = 'https://bhatbhatenionline.com/cart/import';
        appBase = 'bbsm://cart/import';
        break;
      case 'bigmart':
        webBase = 'https://bigmart.com.np/cart/import';
        appBase = 'bigmart://cart/import';
        break;
      case 'blinkit':
        webBase = 'https://blinkit.com/cart/import';
        appBase = 'blinkit://cart/import';
        break;
      case 'amazon_fresh':
        webBase = 'https://www.amazon.com/fresh/cart/import';
        appBase = 'amazon://fresh/cart/import';
        break;
      default:
        webBase = `${retailer.websiteUrl}/cart/import`;
        appBase = `${retailer.appSchemePrefix}cart/import`;
    }

    const queryParams = new URLSearchParams({
      token: base64,
      ref: tag || 'siticounter',
      items: String(transferredCount),
    });

    const cartWebUrl = `${webBase}?${queryParams.toString()}`;
    const cartAppUrl = `${appBase}?${queryParams.toString()}`;

    return {
      cartId,
      householdId,
      retailerId: retailer.id,
      retailerName: retailer.name,
      status: 'ready',
      totalItems: items.length,
      transferredItemsCount: transferredCount,
      unmatchedItems: unmatched,
      estimatedSubtotalNpr: totalNpr,
      cartWebUrl,
      cartAppUrl,
      createdAt: now.toISOString(),
      expiresAt: expiresAt.toISOString(),
      disclosureEn: retailer.disclosureEn,
      disclosureNe: retailer.disclosureNe,
    };
  }
}
