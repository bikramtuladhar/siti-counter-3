import { Hono } from 'hono';

export const legalRouter = new Hono();

const PRIVACY_SUMMARY = {
  policyVersion: '3.0.0',
  lastUpdated: '2026-10-05',
  regulations: [
    'Nepal Individual Privacy Act, 2075 (2018)',
    'EU General Data Protection Regulation (GDPR)',
  ],
  commitments: {
    audioProcessing: '100% on-device neural acoustic engine; zero audio leaves your phone',
    advertisingRankBias: 'Zero advertising or commercial ranking bias',
    childSafety: 'Children never shown calorie numbers or dietary restriction metrics',
    dataPortability: 'Full self-serve JSON export supported',
    rightToErasure: 'One-tap deletion of all household and sync state',
  },
  contact: {
    email: 'privacy@siticounter.app',
    jurisdiction: 'Kathmandu, Nepal',
  },
};

const TERMS_SUMMARY = {
  termsVersion: '3.0.0',
  lastUpdated: '2026-10-05',
  safetyDisclaimers: {
    notMedicalDevice: 'Siti Counter provides dietary estimates, not medical or allergy prescriptions',
    physicalSafety: 'Users remain solely responsible for physical pressure cooker safety and stove supervision',
    severeAllergies: 'Deterministic exclusion does not guarantee against cross-contact on physical packaging',
  },
  pricingModel: 'Purchasing Power Parity (PPP) with local gateways (Khalti, eSewa, Stripe)',
  governingLaw: 'Laws of Nepal (Kathmandu jurisdiction)',
};

legalRouter.get('/v1/legal/privacy', (c) => {
  return c.json(PRIVACY_SUMMARY);
});

legalRouter.get('/v1/legal/terms', (c) => {
  return c.json(TERMS_SUMMARY);
});
