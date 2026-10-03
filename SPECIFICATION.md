# Siti Counter 3.0 — Unified Product Specification

Oct 3, 2026 · @Bikram

## 1. Vision and principles

Siti Counter is a household cooking companion for every kind of home in the world, built around one food lifecycle and tailored to each region, household and family member. The whistle counter remains the signature feature; everything else leads into and out of the cooking session.

The app should help any household answer six questions: what should we cook, what do we need, where do we buy it, how do we prepare and cook it, what did we actually eat, and how do we plan better next time.

### Design principles

1. **One lifecycle, not many features.** Every feature sits somewhere on Discover → Plan → Shop → Prepare → Cook → Serve → Eat → Measure → Repeat.
2. **Region is a pack, not a default.** Nepal is the first Region Pack, built through the same system that later serves Mexico, Kenya or Japan. Nothing about one culture is hard-coded.
3. **Layered customization.** Global → Country → Region → Household → Member. Each layer overrides the one above.
4. **Never expose internal concepts.** Ask "How many people are eating?", not "Select quantity conversion unit".
5. **Infer first, confirm second.** The app guesses from what it already knows (plan, cooking session, usual portions) and asks for one tap of confirmation.
6. **Honest estimates.** Seasonality, nutrition, prices and AI output are labelled as estimates. Generated video or imagery is labelled as such.
7. **Offline and low-end first.** Core flows work without a connection, on inexpensive Android phones, in any script.
8. **Care over pressure.** Nutrition and consumption data support health without shaming, and children are never shown calorie counts.

### Out of scope

The app is not a medical device, a diet prescription service, a marketplace that ranks paid products, or a social network. Equipment and shopping links never read as advertising.

## 2. The household food lifecycle

The product is organised around one loop that every household repeats: Discover → Plan → Shop → Prepare → Cook → Serve → Eat → Measure, then back to planning.

Seasonality drives Discover, the Siti Counter anchors Cook, and consumption metrics close the loop by making the next plan and grocery list smarter.

## 3. Information architecture

The bottom navigation has five tabs — Home, Discover, Planner, Groceries, Kitchen — with household and region settings under Profile. Each tab maps to part of the lifecycle loop.

**Home** adapts to the household's current moment: what's cooking now, the next meal, what's fresh, and quick insights. Tabs and items a household doesn't need (for example, the Siti Counter in a home with no pressure cooker, or Party mode until first used) are hidden rather than shown empty.

## 4. Global customization model

Every setting resolves through five layers, and each layer may override the one above it. This lets a family in Kathmandu, a student in Lagos and a Nepali household in Sydney use the same app without seeing each other's defaults.

| Layer | Owns | Example |
| --- | --- | --- |
| Global | Recipe engine, nutrition engine, design system, safety rules | Yield factors, portion math |
| Country pack | Language, scripts, units, currency, calendars, dietary customs, festivals, allergen standard, nutrition guidelines | Nepal: Nepali/English, NPR, Bikram Sambat, Dashain/Tihar |
| Region pack | Local ingredients and names, climate zone, season system, altitude band, market types, typical prices | Bagmati: 1,400 m, six ritus, haat bazaar |
| Household | Equipment, fuel, meal rhythm, budget, shopping style, portion calibration | LPG cylinder, 5 L Prestige cooker, twice-daily dal bhat |
| Member | Diet, faith rules, allergies, age, nutrition profile, privacy | Grandmother: vegetarian, low sodium, Ekadashi fasting |

### Region Packs

A Region Pack is a downloadable, versioned content bundle. It keeps the app small, works offline and turns global expansion into a content effort rather than a rewrite.

Each pack contains: ingredients with local names, aliases and transliterations; seasonality by climate zone and local season system; altitude data; local units and conversions; recipes and cuisines; festivals and fasting calendars; market categories and stall types; default meal slots and portion vessels; nutrition reference data; and indicative prices where available.

Packs are labelled **Verified** (reviewed by the team or partner experts) or **Community** (contributed and moderated). Users can install more than one pack, which serves diaspora households who cook from home and from where they now live.

### Localization essentials

- **Language and script:** Devanagari, Arabic (right-to-left), CJK, Latin and others, with fonts that render on low-end devices.
- **Units:** metric and imperial, plus market units such as pau, dharni and mana (Nepal), seer and tola (South Asia), catty (Chinese markets), and bunches, heaps and pieces. US and metric cups are distinguished.
- **Numbers and currency:** lakh and crore grouping where expected; local currency throughout.
- **Calendars:** Gregorian plus Bikram Sambat, Hijri and lunar calendars for festivals and fasting.
- **Week and time:** configurable week start and 12/24-hour clock.

## 5. Onboarding and sign-in

Onboarding is the product's best marketing: in under three minutes a new household should see what the app will do for them, personalised to their region, before being asked to sign in. The flow is value first, account later.

### 5.1 Flow at a glance

1. **Welcome tour** — four swipeable screens showing what they get (skippable).
2. **Five questions** — region, language, cooktop, household, food rules.
3. **"Your kitchen is ready"** — a personalised preview built from their answers.
4. **Start using it** — as a guest, with sign-in offered when it adds value.

### 5.2 Welcome tour

Each screen pairs one promise with a short looping animation of the real UI, localised through the Region Pack (local dishes, language, currency). No feature lists; one benefit per screen.

| Screen | Promise | What it shows |
| --- | --- | --- |
| 1. Never miss a whistle | "Siti Counter listens so you don't have to." | A cooker whistling, the count ticking 1 → 3, the alarm |
| 2. Know what to cook | "Fresh, seasonal ideas for your family every day." | Seasonal Kitchen with local vegetables → a recipe → added to Thursday |
| 3. Shop without thinking | "Your plan becomes a market list in units your vendor uses." | Plan → grocery list → Market Mode, shared on WhatsApp |
| 4. See what your family eats | "Nutrition, spend and waste — counted for you." | One-tap portion log → a calm weekly summary |

The last screen carries trust signals in one line each: works offline, your data stays yours, free to start, and "Made in Nepal, for kitchens everywhere" (localised per pack). Buttons: **Set up my kitchen** (primary) and **I already have an account**.

### 5.3 Five questions

Shown as friendly cards with large tap targets and icons, one question per screen, with a visible progress bar (1 of 5).

1. **Where do you cook?** Use location (with a clear permission primer) or pick country and region. Selects the Region Pack, altitude and season system.
2. **What language?** Defaults from the pack; any installed language can be chosen.
3. **What do you cook on?** Gas · LPG cylinder · Induction · Electric · Infrared · Wood or charcoal · Kerosene · Microwave only. Then: which cookers and appliances do you have?
4. **Who eats at home?** Adults, children, elders, with optional names and ages.
5. **Any food rules in your home?** Vegetarian, halal, kosher, no beef, no pork, Jain, no onion or garlic, fasting days, allergies — for everyone or specific members.

Every question has **Skip** with a sensible default. Optional follow-ups appear later, in context: meal rhythm when the planner first opens, budget with the first grocery list, portion calibration after the first cooking session.

### 5.4 "Your kitchen is ready" preview

The moment that sells the product: a single screen built from their answers, before any sign-in.

- **Fresh near you:** three seasonal ingredients for their region and month.
- **Your first week:** an auto-planned week of five dinners that fits their food rules and household size.
- **Your list:** the grocery list for that week, in local units and currency, with an estimated cost.
- **Try the counter:** a 10-second demo where the phone listens for a whistle (or a simulated one).

Actions: **Use this plan** · **Change something** · **Explore on my own**. The Home screen then adapts: a household without a pressure cooker never sees a siti prompt; a vegetarian household never sees meat by default; Sydney sees spring produce in October.

### 5.5 Accounts and social login

The app is fully usable as a guest on one device. Sign-in is offered — never forced — at moments where it clearly helps: inviting family members, syncing to another phone, backing up history, using cloud AI, or after the first completed cooking session ("Save your kitchen so you never lose it").

Sign-in options are ordered per Region Pack, showing the three most common locally with "More options" for the rest:
- Continue with Google (Android / Global)
- Sign in with Apple (iOS worldwide)
- Phone number (SMS / WhatsApp OTP)
- Continue with Facebook
- Email magic link or passkey

### 5.6 Permission primers

Each system permission is asked only when first needed, preceded by a one-screen explanation of why: microphone ("to hear whistles — audio never leaves your phone"), location ("to show what's in season near you"), notifications ("to remind you when to start cooking"). Declining never blocks the app.

## 6. Discover

Discover is where households find food: recipes, seasonal ingredients, cuisines, festivals and dietary collections. Seasonality is ingredient-first and feeds recipes, planning and shopping rather than acting as a filter.

### 6.1 Seasonal Kitchen

The promise: "These are ingredients you are likely to find fresh in your local market now, and here is what you can make with them."
- Header: local season and region (*Sharad ritu · October · Bagmati*).
- Cards: photo, local name, availability level (Peak, In season, Available, Limited, Out of season), recipe count.
- Actions: **See recipes** and **Add to list**.
- Preservation calendar: suggest achar, gundruk, kimchi, passata, jams when produce is cheap and plentiful.

### 6.2 Countries and cuisines
Visual explorer: Region → Country → Regional cuisine → Recipes.

### 6.3 Collections & Search
Festivals (Dashain, Tihar, Eid, etc.), Taste of Home diaspora substitutions, dietary collections, pantry match, multilingual & transliterated search ("gobi", "cauliflower", "फूल गोभी").

## 7. Unified Recipe Detail

1. Hero photo, name, origin, cuisine, rating, difficulty, time, servings.
2. Why make this.
3. Servings selector: scales ingredients and per-member portions.
4. Diet and rule badges.
5. Seasonal availability badge.
6. Ingredients: You need / Optional with unit conversions.
7. What to buy: Recipe quantity -> purchasable market units.
8. Equipment list & alternatives.
9. Cooking on: Gas, Induction, Infrared, Electric, Wood/charcoal, Electric pressure cooker (adapts heat and timings).
10. Altitude note (e.g. "At 1,400 m: 6 siti instead of 5").
11. Video / step photos.
12. Steps with inline timers and siti targets.
13. Nutrition per portion (calories, macros, micronutrients).
14. Cost estimate per serving.
15. Similar & seasonal recipes.

## 8. Planner

- Meal rhythms: customizable slots (e.g., Morning Dal Bhat, Khaja, Evening Dal Bhat; Suhoor/Iftar during Ramadan).
- Views: Week, Month, Auto-plan (Quick, Healthy, Budget, Vegetarian, Pantry-first).
- Food rules and fasting: one base dish, many plates.
- Leftovers: "Eat first" tracking with use-by dates.
- Family voting: "What should we eat tonight?"
- Tiffin and lunchbox planner.
- Party mode: guest count, scaling, T-minus prep timeline, equipment conflict check.

## 9. Groceries, pantry and Market Mode

- Lists: This week, Monthly ration (bulk staples), Seasonal market list, Party list, Equipment list.
- Grocery intelligence: required amount -> purchasable units, surplus tracking.
- Pantry: automatic movement from Market Mode to pantry, climate-aware shelf life.
- Market Mode: high contrast, one-handed checklist grouped by stall type (vegetables, meat, spices, etc.).
- Sharing: WhatsApp, Viber, SMS in readable localized plain text. Live sync for household members.
- Budget mode: cost estimates per meal/week/month in local currency.

## 10. Kitchen

- Siti Counter: large whistle count, step instructions, heat guidance, manual fallback, audio alarms.
- Cooking signal engine: whistle detection (acoustic classifier), hissing valve, electric beeps, clicks.
- Cooktop and altitude adjustments: automatic simmer and pressure scaling based on elevation and heat source.
- Fuel & power: LPG cylinder remaining estimator, power-cut mode (gas/no-cook recipes).
- Multi-dish kitchen: parallel cooking lanes with burner and vessel conflict detection.
- Finish & serve: logs batch yield for nutrition and consumption tracking.

## 11. Consumption and nutrition metrics

- Model: batch -> portion -> leftovers/waste.
- Minimal-effort logging: "Dinner: Dal bhat — did everyone eat their usual?" -> One-tap Yes / Adjust.
- Portions in familiar household vessels (katori, plate, bowl, ladle, roti).
- Yield factors: accounts for raw-to-cooked expansion/shrinkage.
- Dashboard: Me, Family, Kitchen views. Gentle, non-shaming health metrics.
- Dietary profiles: Everyday, Baby/Toddler, Child, Pregnancy, Elderly, Fitness.

## 12. Household, members and roles

- Members: age, dietary rules, allergies, nutrition profile, privacy.
- Roles: Planner, Cook, Co-cook, Shopper, Member.
- Allergen safety: deterministic exclusion, cross-contact warnings, safe portioning, offline printable allergy cards, infant introduction tracker.
- Cooking together: task splitting by age and skill, live shared cooking session across phones, fair-share rotation.

## 13. AI assistant and voice

- Grounded actions: answers directly linked to app actions (Add to plan, Cook, Add to list).
- Three-tier offline-first routing:
  1. Deterministic kitchen engine
  2. On-device local models (Apple Foundation Models, Gemini Nano, Web AI)
  3. Gemini Online (with user consent and audit logging)
- Hands-free voice interface for kitchen use and low-literacy users.

## 14. Notifications

- Local-first scheduling from plan: prep reminders (soak rajma), cook-now alerts, whistle targets, leftovers expiry, LPG refill alerts. Role-targeted.

## 15. Design system and UX rules

- Light & Dark modes driven by W3C Design Tokens and Style Dictionary.
- Visual hierarchy: food photography first, clear typography, arm's length readability.
- Cultural sensitivity: localized names, units, and calendar representations.

## 16. Accessibility, offline, privacy and compliance

- Low-literacy icon & voice navigation mode.
- 100% offline core loop (whistle counting, recipes, planning, groceries, nutrition).
- Privacy compliance (GDPR, India DPDP, Nepal Privacy Act); on-device microphone processing (audio never uploaded).

## 17. Content strategy and community

- Verified core packs (100–300 recipes, seasonal ingredients, festival menus).
- Community contributions with moderation and verification badges.

## 18. Data architecture & Schema entities

Key domain entities:
- Localization: RegionPack, Locale, Country, Region, ClimateZone, SeasonSystem, Altitude, LocalUnit, UnitConversion, Calendar, Festival.
- Food knowledge: Ingredient, IngredientAlias, Allergen, IngredientAllergen, IngredientSeason, Substitute, YieldFactor, NutrientProfile, Cuisine, Recipe, RecipeStep, RecipeVideo, CooktopGuidance.
- Household: Household, Member, HouseholdRole, Availability, CookingCrew, CookTask, CookingRota, DietaryRule, MemberAllergy, AllergyOverride, AllergyCard, FastingCalendar, NutritionProfile, PortionUnit.
- Planning: MealRhythm, MealSlot, MealPlan, PlannedMeal, MealVote, LunchboxPlan, PartyPlan.
- Shopping: GroceryList, GroceryItem, PantryItem, MarketType, PriceObservation, Budget.
- Kitchen: Appliance, SignalProfile, CooktopProfile, FuelSource, CookingSession, CookingLane, Batch.
- Consumption: ConsumptionEntry, OutsideFood, LeftoverItem, ConsumptionSummary.
- Platform: Account, AuthIdentity, Invite, OnboardingState, Notification, AIRequest, SyncState.
- Commerce & Devices: Plan, Subscription, Entitlement, ShopPartner, DeviceLink, DisplaySession.

## 19. Benchmark user journeys

1. Seasonal dinner (Kathmandu family: Cauliflower -> Aloo Gobi -> Haat bazaar list -> Cooking -> Consumption).
2. Mixed-diet joint family (Ekadashi fasting grandmother, soft food toddler, protein tracker adult).
3. Diaspora student (Nepali in Sydney: dual region packs, spring produce, substitutes).
4. High-altitude household (La Paz at 3,600m).
5. Ramadan household (Suhoor/Iftar rhythms, 20-guest iftar party mode).

## 20. Backend services (Cloudflare Free Tier)

- Stack: Workers (Hono), D1 (SQLite + FTS5), Durable Objects (WebSocket Hibernation), Workers KV, R2, Queues, Workflows, Workers AI & AI Gateway.
- Edge API gateway routing to modular services: Identity, Household, Region Packs, Recipes & Search, Planner, Groceries & Prices, Kitchen Realtime, Sync, Consumption & Insights, AI Orchestrator, Notifications, Community.
- Stays strictly within free tier through on-device computation, delta-sync batching, local notifications, and static CDN asset caching.

## 21. API design

- REST `/v1/` endpoints with cursor pagination, ETag caching, idempotency keys.
- `POST /v1/sync` delta-sync protocol with UUIDv7, version tracking, and deterministic conflict resolution.
- WebSocket session channels for live cooking crew and co-cooking synchronization.

## 22. AI Architecture & Guardrails

- Deterministic safety post-check for all AI suggestions (allergens & fasting rules can never be bypassed).
- No medical or pediatric calorie advice.
- Strict data pseudonymization before cloud routing.

## 23. Mobile app design

- React Native + Expo (Hermes, New Architecture).
- Background whistle detection via Android Foreground Service and iOS Background Audio / Live Activities.
- Offline-first local SQLite with Drizzle ORM.

## 24. Development stack & Monorepo

- Monorepo: `pnpm` workspaces + `Turborepo`.
- Shared TypeScript engine: `packages/kitchen-engine`.
- Shared DB schema: `packages/db`.
- Shared API contracts: `packages/contracts` (Zod -> OpenAPI 3.1).
- Native audio module: Kotlin & Swift via Expo Modules with LiteRT / Core ML.

## 25. Responsive design system

- W3C Design Tokens -> Style Dictionary -> React Native, Web, APL, Swift/Kotlin constants.
- Storybook component library.

## 26. Monetization & Regional commerce

- Free core loop; low-cost annual household subscription (purchasing power parity: NPR 999, ₹499, $14.99).
- Regional shopping handoffs: deep links, Kalimati daily market prices, partner carts.

## 27. Prioritization roadmap

- **P0**: Core cooking loop, Nepal Bagmati pack, whistle counter, weekly planner, groceries & market mode, allergen safety, offline sync.
- **P1**: Consumption metrics, co-cooking crew, AI assistant & voice, smart displays, LPG tracker.
- **P2**: Premium subscription, market price boards, community contributions, recipe structuring.
- **P3**: Global expansion packs, partner cart APIs, multi-dish kitchen (>2 lanes).

## 28. MVP scope & timeline

- 24-week plan to open beta with 4 gates:
  - Week 4 Gate: Foundations & Whistle Detection Spike (>=97% accuracy).
  - Week 12 Gate: P0 Core Loop & Nepal Beta complete on Android & Web.
  - Week 16 Gate: Closed Beta (>=99.5% crash-free, >=40% weekly cooking rate).
  - Week 24 Gate: Open Beta launch.

## 29. Risks and open questions

- Whistle detection accuracy in noisy environments.
- iOS background listening limitations.
- Low-end Android 2 GB RAM performance.
- Region pack expert review & verification pipeline.
