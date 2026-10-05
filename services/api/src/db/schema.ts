import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core'

export const households = sqliteTable('households', {
  id: text('id').primaryKey(), // UUIDv7
  name: text('name').notNull(),
  currency: text('currency').notNull().default('NPR'),
  country: text('country').notNull().default('Nepal'),
  regionPack: text('region_pack').notNull().default('nepal-bagmati'),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull()
})

export const members = sqliteTable('members', {
  id: text('id').primaryKey(), // UUIDv7
  householdId: text('household_id')
    .notNull()
    .references(() => households.id, { onDelete: 'cascade' }),
  name: text('name').notNull(),
  role: text('role', { enum: ['planner', 'cook', 'co-cook', 'shopper', 'member'] })
    .notNull()
    .default('member'),
  allergies: text('allergies', { mode: 'json' }).$type<string[]>().default([]),
  dietaryRules: text('dietary_rules', { mode: 'json' }).$type<string[]>().default([]),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull()
})

export const recipes = sqliteTable('recipes', {
  id: text('id').primaryKey(),
  title: text('title').notNull(),
  origin: text('origin'),
  cuisine: text('cuisine'),
  servings: integer('servings').notNull().default(4),
  prepTimeMinutes: integer('prep_time_minutes'),
  cookTimeMinutes: integer('cook_time_minutes'),
  cooktopGuidance: text('cooktop_guidance', { mode: 'json' }).$type<Record<string, unknown>>(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull()
})

export const syncEntries = sqliteTable('sync_entries', {
  id: text('id').primaryKey(), // UUIDv7
  householdId: text('household_id').notNull(),
  entityType: text('entity_type', {
    enum: ['household', 'member', 'recipe', 'meal_plan', 'grocery_item', 'batch', 'consumption']
  }).notNull(),
  entityId: text('entity_id').notNull(),
  version: integer('version').notNull().default(1),
  payload: text('payload', { mode: 'json' }).$type<Record<string, unknown>>().notNull(),
  deleted: integer('deleted', { mode: 'boolean' }).notNull().default(false),
  timestamp: integer('timestamp').notNull() // Unix epoch ms
})

export const subscriptions = sqliteTable('subscriptions', {
  id: text('id').primaryKey(),
  householdId: text('household_id').notNull(),
  tier: text('tier', { enum: ['free', 'householdAnnual'] }).notNull().default('householdAnnual'),
  status: text('status', { enum: ['active', 'past_due', 'cancelled', 'expired'] }).notNull().default('active'),
  provider: text('provider', { enum: ['khalti', 'esewa', 'stripe', 'in_app', 'gift'] }).notNull(),
  transactionId: text('transaction_id'),
  currency: text('currency').notNull().default('NPR'),
  amount: integer('amount').notNull(),
  isGift: integer('is_gift', { mode: 'boolean' }).notNull().default(false),
  purchaserEmail: text('purchaser_email'),
  recipientEmail: text('recipient_email'),
  recipientName: text('recipient_name'),
  giftMessage: text('gift_message'),
  giftCode: text('gift_code'),
  currentPeriodStart: integer('current_period_start', { mode: 'timestamp' }).notNull(),
  currentPeriodEnd: integer('current_period_end', { mode: 'timestamp' }).notNull(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull()
})

export const entitlements = sqliteTable('entitlements', {
  id: text('id').primaryKey(),
  householdId: text('household_id').notNull(),
  tier: text('tier', { enum: ['free', 'householdAnnual'] }).notNull().default('free'),
  status: text('status', { enum: ['active', 'expired'] }).notNull().default('active'),
  features: text('features', { mode: 'json' }).$type<string[]>().default([]),
  offlineToken: text('offline_token'),
  signature: text('signature'),
  expiresAt: integer('expires_at', { mode: 'timestamp' }).notNull(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull()
})

export const giftCodes = sqliteTable('gift_codes', {
  code: text('code').primaryKey(), // GIFT-SITI-XXXX-XXXX
  purchaserHouseholdId: text('purchaser_household_id'),
  purchaserEmail: text('purchaser_email'),
  recipientEmail: text('recipient_email'),
  recipientName: text('recipient_name'),
  giftMessage: text('gift_message'),
  subscriptionId: text('subscription_id').notNull(),
  status: text('status', { enum: ['unredeemed', 'redeemed', 'expired'] }).notNull().default('unredeemed'),
  redeemedByHouseholdId: text('redeemed_by_household_id'),
  redeemedAt: integer('redeemed_at', { mode: 'timestamp' }),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  expiresAt: integer('expires_at', { mode: 'timestamp' }).notNull()
})

export const marketCommodityPrices = sqliteTable('market_commodity_prices', {
  id: text('id').primaryKey(),
  marketCode: text('market_code').notNull().default('kalimati'),
  marketName: text('market_name').notNull().default('Kalimati Wholesale Market'),
  commodityId: text('commodity_id').notNull(),
  commodityNameEn: text('commodity_name_en').notNull(),
  commodityNameNe: text('commodity_name_ne').notNull(),
  category: text('category').notNull().default('vegetables'),
  unit: text('unit').notNull().default('kg'),
  minPrice: integer('min_price').notNull(),
  maxPrice: integer('max_price').notNull(),
  avgPrice: integer('avg_price').notNull(),
  priceTrend: text('price_trend', { enum: ['rising', 'stable', 'falling'] }).notNull().default('stable'),
  date: text('date').notNull(),
  nepaliDate: text('nepali_date'),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull()
})

export const priceObservations = sqliteTable('price_observations', {
  id: text('id').primaryKey(),
  marketName: text('market_name').notNull(),
  marketType: text('market_type', { enum: ['haat_bazaar', 'supermarket', 'local_kirana', 'wholesale'] }).notNull(),
  commodityId: text('commodity_id').notNull(),
  observedPrice: integer('observed_price').notNull(),
  unit: text('unit').notNull().default('kg'),
  reporterHouseholdId: text('reporter_household_id'),
  verified: integer('verified', { mode: 'boolean' }).notNull().default(false),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull()
})

export const communityContributions = sqliteTable('community_contributions', {
  id: text('id').primaryKey(),
  type: text('type', { enum: ['recipe', 'ingredient_alias', 'price_observation'] }).notNull(),
  status: text('status', { enum: ['pending', 'screening', 'auto_approved', 'flagged', 'verified', 'rejected'] }).notNull().default('pending'),
  badge: text('badge', { enum: ['community', 'verified'] }).notNull().default('community'),
  title: text('title').notNull(),
  submitterHouseholdId: text('submitter_household_id').notNull(),
  submitterName: text('submitter_name').notNull(),
  payload: text('payload', { mode: 'json' }).$type<Record<string, unknown>>().notNull(),
  moderationScorecard: text('moderation_scorecard', { mode: 'json' }).$type<Record<string, unknown>>(),
  reviewerId: text('reviewer_id'),
  reviewerNotes: text('reviewer_notes'),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull()
})


