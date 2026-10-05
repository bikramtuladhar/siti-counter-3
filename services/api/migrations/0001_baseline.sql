-- Siti Counter 3.0 - D1 baseline schema.
--
-- The Workers runtime currently serves reads from the in-memory sync store so the test
-- suite runs without a D1 shim. This migration is the durable backing for that store: the
-- `sync_entries` table is the source of truth once the store is switched to D1.

CREATE TABLE IF NOT EXISTS households (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'NPR',
  country TEXT NOT NULL DEFAULT 'Nepal',
  region_pack TEXT NOT NULL DEFAULT 'nepal-bagmati',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS members (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'member',
  allergies TEXT NOT NULL DEFAULT '[]',
  dietary_rules TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_members_household ON members(household_id);

CREATE TABLE IF NOT EXISTS recipes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  origin TEXT,
  cuisine TEXT,
  servings INTEGER NOT NULL DEFAULT 4,
  prep_time_minutes INTEGER,
  cook_time_minutes INTEGER,
  cooktop_guidance TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Delta-sync log. One row per entity, holding the latest version so the feed endpoint and
-- `POST /v1/sync` read the same state.
CREATE TABLE IF NOT EXISTS sync_entries (
  id TEXT PRIMARY KEY, -- UUIDv7
  household_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  payload TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  timestamp INTEGER NOT NULL, -- Unix epoch ms, server write time
  UNIQUE (household_id, entity_type, entity_id)
);

-- The display feed reads meal plans by (household, date) and grocery items by household.
CREATE INDEX IF NOT EXISTS idx_sync_entries_household_type
  ON sync_entries(household_id, entity_type, timestamp);

-- Monotonic per-household revision, so a client can cheaply detect "anything changed?"
-- without diffing the whole log. Drives the feed ETag.
CREATE TABLE IF NOT EXISTS household_revisions (
  household_id TEXT PRIMARY KEY,
  revision INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL,
  tier TEXT NOT NULL DEFAULT 'householdAnnual',
  status TEXT NOT NULL DEFAULT 'active',
  provider TEXT NOT NULL,
  transaction_id TEXT,
  currency TEXT NOT NULL DEFAULT 'NPR',
  amount INTEGER NOT NULL,
  is_gift INTEGER NOT NULL DEFAULT 0,
  purchaser_email TEXT,
  recipient_email TEXT,
  recipient_name TEXT,
  gift_message TEXT,
  gift_code TEXT,
  current_period_start INTEGER NOT NULL,
  current_period_end INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_household ON subscriptions(household_id);

CREATE TABLE IF NOT EXISTS entitlements (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL,
  tier TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  features TEXT NOT NULL DEFAULT '[]',
  offline_token TEXT,
  signature TEXT,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_entitlements_household ON entitlements(household_id);

CREATE TABLE IF NOT EXISTS gift_codes (
  code TEXT PRIMARY KEY, -- GIFT-SITI-XXXX-XXXX
  purchaser_household_id TEXT,
  purchaser_email TEXT,
  recipient_email TEXT,
  recipient_name TEXT,
  gift_message TEXT,
  subscription_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unredeemed',
  redeemed_by_household_id TEXT,
  redeemed_at INTEGER,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS market_commodity_prices (
  id TEXT PRIMARY KEY,
  market_code TEXT NOT NULL DEFAULT 'kalimati',
  market_name TEXT NOT NULL,
  commodity_id TEXT NOT NULL,
  commodity_name_en TEXT NOT NULL,
  commodity_name_ne TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'vegetables',
  unit TEXT NOT NULL DEFAULT 'kg',
  min_price INTEGER NOT NULL,
  max_price INTEGER NOT NULL,
  avg_price INTEGER NOT NULL,
  price_trend TEXT NOT NULL DEFAULT 'stable',
  date TEXT NOT NULL,
  nepali_date TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_market_prices_date ON market_commodity_prices(date, commodity_id);

CREATE TABLE IF NOT EXISTS price_observations (
  id TEXT PRIMARY KEY,
  market_name TEXT NOT NULL,
  market_type TEXT NOT NULL DEFAULT 'haat_bazaar',
  commodity_id TEXT NOT NULL,
  observed_price INTEGER NOT NULL,
  unit TEXT NOT NULL DEFAULT 'kg',
  reporter_household_id TEXT,
  verified INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_price_observations_commodity ON price_observations(commodity_id);

CREATE TABLE IF NOT EXISTS community_contributions (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  badge TEXT NOT NULL DEFAULT 'community',
  title TEXT NOT NULL,
  submitter_household_id TEXT NOT NULL,
  submitter_name TEXT NOT NULL,
  payload TEXT NOT NULL,
  moderation_scorecard TEXT,
  reviewer_id TEXT,
  reviewer_notes TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_community_status ON community_contributions(status, created_at);