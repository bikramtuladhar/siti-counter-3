function computeHmacSha256Hex(keyStr: string, messageStr: string): string {
  const K = new Uint32Array([
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ]);

  function rotr(n: number, b: number): number {
    return (n >>> b) | (n << (32 - b));
  }

  function sha256(data: Uint8Array): Uint8Array {
    const bitLen = data.length * 8;
    const rem = (data.length + 9) % 64;
    const padZeros = rem === 0 ? 0 : 64 - rem;
    const totalLen = data.length + 1 + padZeros + 8;
    const padded = new Uint8Array(totalLen);
    padded.set(data, 0);
    padded[data.length] = 0x80;

    const view = new DataView(padded.buffer);
    view.setUint32(totalLen - 8, Math.floor(bitLen / 0x100000000), false);
    view.setUint32(totalLen - 4, bitLen >>> 0, false);

    let h0 = 0x6a09e667;
    let h1 = 0xbb67ae85;
    let h2 = 0x3c6ef372;
    let h3 = 0xa54ff53a;
    let h4 = 0x510e527f;
    let h5 = 0x9b05688c;
    let h6 = 0x1f83d9ab;
    let h7 = 0x5be0cd19;

    const W = new Uint32Array(64);

    for (let i = 0; i < totalLen; i += 64) {
      for (let t = 0; t < 16; t++) {
        W[t] = view.getUint32(i + t * 4, false);
      }
      for (let t = 16; t < 64; t++) {
        const s0 = rotr(W[t - 15], 7) ^ rotr(W[t - 15], 18) ^ (W[t - 15] >>> 3);
        const s1 = rotr(W[t - 2], 17) ^ rotr(W[t - 2], 19) ^ (W[t - 2] >>> 10);
        W[t] = (W[t - 16] + s0 + W[t - 7] + s1) | 0;
      }

      let a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (let t = 0; t < 64; t++) {
        const S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        const ch = (e & f) ^ (~e & g);
        const temp1 = (h + S1 + ch + K[t] + W[t]) | 0;
        const S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        const maj = (a & b) ^ (a & c) ^ (b & c);
        const temp2 = (S0 + maj) | 0;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) | 0;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) | 0;
      }

      h0 = (h0 + a) | 0;
      h1 = (h1 + b) | 0;
      h2 = (h2 + c) | 0;
      h3 = (h3 + d) | 0;
      h4 = (h4 + e) | 0;
      h5 = (h5 + f) | 0;
      h6 = (h6 + g) | 0;
      h7 = (h7 + h) | 0;
    }

    const out = new Uint8Array(32);
    const outView = new DataView(out.buffer);
    outView.setUint32(0, h0 >>> 0, false);
    outView.setUint32(4, h1 >>> 0, false);
    outView.setUint32(8, h2 >>> 0, false);
    outView.setUint32(12, h3 >>> 0, false);
    outView.setUint32(16, h4 >>> 0, false);
    outView.setUint32(20, h5 >>> 0, false);
    outView.setUint32(24, h6 >>> 0, false);
    outView.setUint32(28, h7 >>> 0, false);
    return out;
  }

  const encoder = new TextEncoder();
  let keyBytes: Uint8Array<ArrayBufferLike> = encoder.encode(keyStr);
  const msgBytes = encoder.encode(messageStr);

  if (keyBytes.length > 64) {
    keyBytes = sha256(keyBytes);
  }

  const paddedKey = new Uint8Array(64);
  paddedKey.set(keyBytes, 0);

  const kIpad = new Uint8Array(64);
  const kOpad = new Uint8Array(64);
  for (let i = 0; i < 64; i++) {
    kIpad[i] = paddedKey[i] ^ 0x36;
    kOpad[i] = paddedKey[i] ^ 0x5c;
  }

  const innerData = new Uint8Array(64 + msgBytes.length);
  innerData.set(kIpad, 0);
  innerData.set(msgBytes, 64);
  const innerHash = sha256(innerData);

  const outerData = new Uint8Array(64 + 32);
  outerData.set(kOpad, 0);
  outerData.set(innerHash, 64);
  const outerHash = sha256(outerData);

  return Array.from(outerHash)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

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
    const signature = computeHmacSha256Hex(secret, payloadString);

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
    const expectedSignature = computeHmacSha256Hex(secret, payloadString);

    return expectedSignature === params.token.signature;
  }
}
