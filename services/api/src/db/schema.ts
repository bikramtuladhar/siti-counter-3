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
