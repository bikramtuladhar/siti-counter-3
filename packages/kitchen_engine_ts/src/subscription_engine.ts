import { createHmac } from 'node:crypto';

/**
 * Subscription Tier definition
 */
export type SubscriptionTier = 'free' | 'householdAnnual';

export const SUBSCRIPTION_FEATURES = {
  coreCookingLoop: 'core_cooking_loop',
  whistleCounter: 'whistle_counter',
  mealPlanner: 'meal_planner',
  groceryHaatBazaar: 'grocery_haat_bazaar',
  offlineSync: 'offline_sync',

  // Premium Features
  unlimitedAiAssistant: 'unlimited_ai_assistant',
  liveMarketPrices: 'live_market_prices',
  partyModeBhoj: 'party_mode_bhoj',
  familyCookbook: 'family_cookbook',
  multiDeviceHousehold: 'multi_device_household',
} as const;

export const FREE_TIER_FEATURES: string[] = [
  SUBSCRIPTION_FEATURES.coreCookingLoop,
  SUBSCRIPTION_FEATURES.whistleCounter,
  SUBSCRIPTION_FEATURES.mealPlanner,
  SUBSCRIPTION_FEATURES.groceryHaatBazaar,
  SUBSCRIPTION_FEATURES.offlineSync,
];

export const PREMIUM_FEATURES: string[] = [
  ...FREE_TIER_FEATURES,
  SUBSCRIPTION_FEATURES.unlimitedAiAssistant,
  SUBSCRIPTION_FEATURES.liveMarketPrices,
  SUBSCRIPTION_FEATURES.partyModeBhoj,
  SUBSCRIPTION_FEATURES.familyCookbook,
  SUBSCRIPTION_FEATURES.multiDeviceHousehold,
];

export interface PppPlanPrice {
  countryCode: string;
  currencyCode: string;
  currencySymbol: string;
  amount: number;
  formattedPriceEn: string;
  formattedPriceNe: string;
}

export const PPP_PRICING_CATALOG: Record<string, PppPlanPrice> = {
  NP: {
    countryCode: 'NP',
    currencyCode: 'NPR',
    currencySymbol: 'NPR',
    amount: 999.0,
    formattedPriceEn: 'NPR 999 / year',
    formattedPriceNe: 'रु ९९९ / वर्ष',
  },
  IN: {
    countryCode: 'IN',
    currencyCode: 'INR',
    currencySymbol: '₹',
    amount: 499.0,
    formattedPriceEn: '₹499 / year',
    formattedPriceNe: '₹४९९ / वर्ष',
  },
  US: {
    countryCode: 'US',
    currencyCode: 'USD',
    currencySymbol: '$',
    amount: 14.99,
    formattedPriceEn: '$14.99 / year',
    formattedPriceNe: '$१४.९९ / वर्ष',
  },
  GB: {
    countryCode: 'GB',
    currencyCode: 'GBP',
    currencySymbol: '£',
    amount: 12.99,
    formattedPriceEn: '£12.99 / year',
    formattedPriceNe: '£१२.९९ / वर्ष',
  },
  AU: {
    countryCode: 'AU',
    currencyCode: 'AUD',
    currencySymbol: 'A$',
    amount: 19.99,
    formattedPriceEn: 'A$19.99 / year',
    formattedPriceNe: 'A$१९.९९ / वर्ष',
  },
  EU: {
    countryCode: 'EU',
    currencyCode: 'EUR',
    currencySymbol: '€',
    amount: 13.99,
    formattedPriceEn: '€13.99 / year',
    formattedPriceNe: '€१३.९९ / वर्ष',
  },
};

export class PppPricingResolver {
  public static resolvePrice(countryOrCurrency: string): PppPlanPrice {
    const upper = countryOrCurrency.toUpperCase();
    if (PPP_PRICING_CATALOG[upper]) {
      return PPP_PRICING_CATALOG[upper];
    }
    for (const p of Object.values(PPP_PRICING_CATALOG)) {
      if (p.currencyCode === upper) {
        return p;
      }
    }
    return PPP_PRICING_CATALOG['US'];
  }
}

export interface SignedOfflineEntitlementProps {
  householdId: string;
  tier: SubscriptionTier;
  issuedAt: Date | string;
  expiresAt: Date | string;
  features: string[];
  issuer: string;
  signature: string;
}

export class SignedOfflineEntitlement {
  public readonly householdId: string;
  public readonly tier: SubscriptionTier;
  public readonly issuedAt: Date;
  public readonly expiresAt: Date;
  public readonly features: string[];
  public readonly issuer: string;
  public readonly signature: string;

  constructor(props: SignedOfflineEntitlementProps) {
    this.householdId = props.householdId;
    this.tier = props.tier;
    this.issuedAt = typeof props.issuedAt === 'string' ? new Date(props.issuedAt) : props.issuedAt;
    this.expiresAt = typeof props.expiresAt === 'string' ? new Date(props.expiresAt) : props.expiresAt;
    this.features = props.features;
    this.issuer = props.issuer;
    this.signature = props.signature;
  }

  public isValid(asOf?: Date): boolean {
    const now = asOf ?? new Date();
    return now.getTime() < this.expiresAt.getTime();
  }

  public hasFeature(featureName: string, asOf?: Date): boolean {
    if (!this.isValid(asOf)) return false;
    return this.features.includes(featureName);
  }

  public toJSON(): Record<string, unknown> {
    return {
      householdId: this.householdId,
      tier: this.tier,
      issuedAt: this.issuedAt.toISOString(),
      expiresAt: this.expiresAt.toISOString(),
      features: this.features,
      issuer: this.issuer,
      signature: this.signature,
    };
  }

  public static fromJSON(json: Record<string, unknown>): SignedOfflineEntitlement {
    return new SignedOfflineEntitlement({
      householdId: json.householdId as string,
      tier: json.tier as SubscriptionTier,
      issuedAt: json.issuedAt as string,
      expiresAt: json.expiresAt as string,
      features: json.features as string[],
      issuer: json.issuer as string,
      signature: json.signature as string,
    });
  }
}

export class OfflineEntitlementSigner {
  public static readonly defaultSecretKey = 'siti-counter-offline-token-secret-2026';

  public static issueToken(params: {
    householdId: string;
    tier: SubscriptionTier;
    validityDays?: number;
    issuanceDate?: Date;
    secretKey?: string;
  }): SignedOfflineEntitlement {
    const now = params.issuanceDate ?? new Date();
    const days = params.validityDays ?? 365;
    const expiresAt = new Date(now.getTime() + days * 24 * 3600 * 1000);
    const features = params.tier === 'householdAnnual' ? PREMIUM_FEATURES : FREE_TIER_FEATURES;
    const issuer = 'siti_counter_authority';
    const secret = params.secretKey ?? OfflineEntitlementSigner.defaultSecretKey;

    const payloadString = `${params.householdId}:${params.tier}:${now.getTime()}:${expiresAt.getTime()}:${features.join(',')}:${issuer}`;
    const hmac = createHmac('sha256', secret);
    hmac.update(payloadString);
    const signature = hmac.digest('hex');

    return new SignedOfflineEntitlement({
      householdId: params.householdId,
      tier: params.tier,
      issuedAt: now,
      expiresAt,
      features,
      issuer,
      signature,
    });
  }

  public static verifyToken(params: {
    token: SignedOfflineEntitlement;
    secretKey?: string;
    verificationDate?: Date;
  }): boolean {
    const now = params.verificationDate ?? new Date();
    if (now.getTime() > params.token.expiresAt.getTime()) {
      return false;
    }

    const secret = params.secretKey ?? OfflineEntitlementSigner.defaultSecretKey;
    const payloadString = `${params.token.householdId}:${params.token.tier}:${params.token.issuedAt.getTime()}:${params.token.expiresAt.getTime()}:${params.token.features.join(',')}:${params.token.issuer}`;
    const hmac = createHmac('sha256', secret);
    hmac.update(payloadString);
    const expectedSignature = hmac.digest('hex');

    return expectedSignature === params.token.signature;
  }
}
