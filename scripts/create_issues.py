#!/usr/bin/env python3
import json
import subprocess
import sys

REPO = "bikramtuladhar/siti-counter-3"

def run_cmd(args, check=True):
    res = subprocess.run(args, capture_output=True, text=True)
    if check and res.returncode != 0:
        print(f"Error running {' '.join(args)}:\n{res.stderr}", file=sys.stderr)
        raise RuntimeError(res.stderr)
    return res.stdout.strip()

print(f"==========================================================")
print(f"Siti Counter 3.0 — Python Issue & Milestone Provisioner")
print(f"Target Repo: {REPO}")
print(f"==========================================================")

# 1. Fetch existing issues
print("\n>>> Fetching existing issues...")
try:
    raw_issues = run_cmd(["gh", "issue", "list", "--repo", REPO, "--state", "all", "--limit", "200", "--json", "title"])
    existing_issues = {item["title"] for item in json.loads(raw_issues)}
except Exception as e:
    print(f"Warning: could not fetch issues: {e}")
    existing_issues = set()

print(f"Found {len(existing_issues)} existing issues in repository.")

# 2. Milestones
MILESTONES = {
    "M1: Foundations & Architecture Spikes (Weeks 1–4)": "Monorepo, whistle audio spike (≥97% accuracy), engine math, and Cloudflare sync skeleton.",
    "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)": "Nepal Bagmati pack, onboarding, seasonal kitchen, recipe detail, siti counter, planner, market mode, allergen safety.",
    "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)": "Consumption metrics, live co-cooking crew (Durable Objects), grounded AI assistant, LPG tracker.",
    "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)": "Subscriptions, regional shopping (Kalimati prices, Daraz/Bhatbhateni), community moderation, closed beta.",
    "M5: P3 Global Expansion & Ecosystem (Post-Launch)": "India & diaspora packs, smart displays (Alexa/Cast), multi-dish lanes (>2 cookers)."
}

print("\n>>> Ensuring milestones exist...")
try:
    raw_ms = run_cmd(["gh", "api", f"repos/{REPO}/milestones", "--jq", ".[].title"])
    existing_milestones = set(raw_ms.splitlines())
except Exception:
    existing_milestones = set()

for m_title, m_desc in MILESTONES.items():
    if m_title not in existing_milestones:
        print(f"Creating milestone: {m_title}")
        run_cmd(["gh", "api", f"repos/{REPO}/milestones", "-f", f"title={m_title}", "-f", f"description={m_desc}"], check=False)
    else:
        print(f"Milestone already exists: {m_title}")

# 3. Issues definition
ISSUES = [
    # M1
    {
        "title": "[Foundations] Initialize TypeScript monorepo with pnpm workspaces and Turborepo",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,area:infra,area:backend",
        "body": """### Overview
Set up the core monorepo architecture outlined in Section 24 of the spec using `pnpm` workspaces and `Turborepo`.

### Structure to Scaffold
- `apps/mobile` (React Native + Expo)
- `apps/web` (Expo Router / react-native-web)
- `packages/kitchen-engine` (Pure TypeScript, no I/O)
- `packages/db` (Drizzle ORM schema for SQLite & D1)
- `packages/contracts` (Zod schemas -> OpenAPI 3.1)
- `packages/tokens` (W3C Design Tokens & Style Dictionary)
- `packages/ui` (Shared React Native Web components)
- `services/gateway` (Cloudflare Worker with Hono)

### Acceptance Criteria
- [ ] `pnpm install` succeeds cleanly with strict TypeScript configurations.
- [ ] `pnpm test` executes Vitest across all workspace packages.
- [ ] Shared tsconfig and ESLint configurations applied uniformly."""
    },
    {
        "title": "[Spike] Whistle detection acoustic classifier spike & accuracy benchmark (≥97%)",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,area:audio,gate:week4",
        "body": """### Overview
Execute the Week 4 Foundation Gate spike for the Siti Counter whistle detection engine (Section 10, 22.4, 28.3).

### Tasks
- [ ] Collect test dataset of 30+ audio recordings from various cooker brands (Hawkins, Prestige) across noisy kitchen conditions (exhaust fans, running taps, TV).
- [ ] Train/benchmark an audio classifier (LiteRT on Android, Core ML on iOS) using spectral peaks and acoustic signatures of steam whistle venting.
- [ ] Build a test harness measuring precision, recall, and false positive rates.
- [ ] Measure battery impact (<5% per hour listening).

### Gate 1 Criteria
- [ ] Count accuracy achieves ≥97% across the 30+ test recording benchmark.
- [ ] Manual correction controls (+1 / -1) verified."""
    },
    {
        "title": "[Spike] iOS background listening & Live Activities feasibility test",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,area:mobile,area:audio,gate:week4",
        "body": """### Overview
Evaluate iOS background audio lifecycle and Live Activity constraints (Section 23.3, 29.1).

### Tasks
- [ ] Implement native Swift Expo Module for continuous background audio session recording.
- [ ] Implement iOS Live Activity & Dynamic Island widget showing active siti count and step timer.
- [ ] Test system suspension behaviors under screen lock, incoming calls, and multitasking.
- [ ] Implement graceful fallback to countdown timer with user alert if audio capture is interrupted."""
    },
    {
        "title": "[Spike] Low-end Android (2GB RAM) React Native / Hermes performance benchmark",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,area:mobile,gate:week4",
        "body": """### Overview
Verify that the React Native app performs smoothly on entry-level Android devices (e.g. 2 GB RAM, Android 8.0+) as specified in Section 23.1 and Gate 1.

### Tasks
- [ ] Build minimal APK with Hermes engine and new architecture enabled.
- [ ] Test on real 2 GB Android device or emulator configured with restricted memory and CPU.
- [ ] Verify cold start time is under 2.5s.
- [ ] Verify core memory footprint remains under 120 MB during active listening."""
    },
    {
        "title": "[Engine] Implement core kitchen-engine: metric & local market unit conversion (pau, dharni, mana)",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,p0,area:engine",
        "body": """### Overview
Build the pure TypeScript `packages/kitchen-engine` unit conversion subsystem (Section 4, 18).

### Scope
- Conversion between canonical metric units (g, ml) and local South Asian market units:
  - 1 pau = 250 g
  - 1 dharni = 2.5 kg (or 10 pau)
  - 1 mana ≈ 568 ml (volume) / local grain equivalent
  - Seer, tola, bunches, heaps, pieces.
- Distinction between US cups (240ml) and Metric cups (250ml).
- Conversion functions from recipe cooking units (e.g. "1 tbsp oil") to purchasable market package units.

### Acceptance Criteria
- [ ] 100% unit test coverage in Vitest.
- [ ] Zero runtime dependencies, usable in Node, browser, React Native, and Cloudflare Workers."""
    },
    {
        "title": "[Engine] Implement altitude compensation algorithms for boiling point & pressure timings",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,p0,area:engine",
        "body": """### Overview
Implement elevation-aware cooking adjustment algorithms in `packages/kitchen-engine` (Section 7, 10.4).

### Scope
- Calculation of water boiling point at altitude (e.g. Kathmandu at 1,400m ≈ 95°C; La Paz at 3,600m < 90°C).
- Recipe adjustment calculation: pressure whistle scaling (e.g. "At 1,400m: 6 siti instead of 5"), simmer duration, and soaking multipliers.
- Human-readable explanation generation for recipe detail view."""
    },
    {
        "title": "[Tokens] Set up W3C Design Tokens & Style Dictionary multi-platform build pipeline",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,area:design",
        "body": """### Overview
Set up the design token repository in `packages/tokens` (Section 25).

### Tasks
- [ ] Define tokens in W3C Design Tokens JSON: colors (light & dark mode, terracotta primary, warm white), typography, fluid spacing, elevation, radius.
- [ ] Configure Style Dictionary to generate:
  - TypeScript theme objects for React Native.
  - CSS variables for web.
  - Swift & Kotlin token constants.
  - Alexa Presentation Language (APL) styles.
- [ ] Add distance profile tokens: near (phone), arm's length (counter), across the room (smart display)."""
    },
    {
        "title": "[Backend] Scaffold Cloudflare Workers gateway, D1 SQLite schema, and /v1/sync skeleton",
        "milestone": "M1: Foundations & Architecture Spikes (Weeks 1–4)",
        "labels": "foundations,p0,area:backend,gate:week4",
        "body": """### Overview
Build the Cloudflare Workers free-tier backend skeleton (Section 20, 21).

### Scope
- Hono gateway running on Cloudflare Workers.
- D1 SQLite database with Drizzle ORM schema: households, members, recipes, sync changes.
- Implementation of `POST /v1/sync` delta-sync endpoint with UUIDv7, version tracking, and batch updates.
- Staging and production deployment scripts using Wrangler."""
    },

    # M2
    {
        "title": "[Region Pack] Build Nepal (Bagmati) launch pack schema & initial verified dataset",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:content,region-pack",
        "body": """### Overview
Author the Nepal (Bagmati Province) Region Pack as the launch pack (Section 4, 17, 28.1).

### Content Deliverables
- ~150 verified everyday recipes (Dal Bhat, Tarkari, Achar, Khaja items, Sel Roti, Gundruk).
- ~60 seasonal ingredients with Nepali (Devanagari) names, English transliterations, and aliases.
- Elevation band data (Kathmandu 1,400m default).
- Seasonality calendar mapping six ritus (Basanta, Grishma, Barsha, Sharad, Hemanta, Shishir).
- Bikram Sambat festival dates (Dashain, Tihar, Ekadashi, Teej, Chhath).
- Bundle packaged as versioned static JSON assets for CDN edge distribution."""
    },
    {
        "title": "[Localization] Implement Bikram Sambat calendar, 6 ritus season system, and Devanagari typography",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:engine,area:ui",
        "body": """### Overview
Implement Nepali localization essentials across engine and UI (Section 4.1).

### Tasks
- [ ] Bikram Sambat (BS) date conversion algorithms and lunar calendar mapper.
- [ ] Six ritus season indicator widget.
- [ ] Devanagari font rendering optimization for low-end Android devices.
- [ ] Number formatting supporting Lakh and Crore grouping (e.g. 1,00,000) and NPR currency."""
    },
    {
        "title": "[Onboarding] Build 4-screen welcome tour, 5-question setup wizard, and instant kitchen preview",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,ux",
        "body": """### Overview
Implement the 3-minute frictionless onboarding flow specified in Section 5.

### Steps
1. Welcome Tour: 4 swipeable promise screens with animated UI previews.
2. 5 Setup Questions:
   - Where do you cook? (Region / Altitude)
   - What language?
   - What do you cook on? (Gas, LPG, Induction, etc.)
   - Who eats at home? (Adults, children, elders)
   - Food rules / allergies?
3. \"Your kitchen is ready\" Preview screen:
   - Fresh near you (3 seasonal items).
   - Auto-planned 5-dinner first week.
   - Initial market grocery list with local currency cost estimate.
   - 10-second whistle demo counter.
4. Guest mode landing without mandatory registration."""
    },
    {
        "title": "[Auth] Guest-first mode with Google Sign-in & email magic link with data merge",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:backend,area:mobile",
        "body": """### Overview
Implement account identity management supporting seamless guest usage and upgrade (Section 5.5, 20.1).

### Tasks
- [ ] Anonymous local guest profile stored in SQLite on device.
- [ ] Google Sign-In and Email Magic Link auth on Cloudflare Workers.
- [ ] Non-destructive guest data merge into newly authenticated account on sign-in.
- [ ] Secure token storage using Android Keystore / iOS Keychain with 15-minute access tokens and rotating refresh tokens."""
    },
    {
        "title": "[Discover] Seasonal Kitchen screen with availability indicators & preservation recommendations",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,area:engine",
        "body": """### Overview
Build the Discover tab & Seasonal Kitchen experience (Section 6.1).

### Features
- Header showing current season and region (e.g., *Sharad ritu · October · Bagmati*).
- Ingredient cards with photo, Devanagari name, English name, recipe count, and availability badge (Peak, In Season, Available, Limited, Out of Season).
- Actions: \"See recipes\" and \"Add to list\".
- Preservation suggestions (e.g. seasonal reminders for Achar, Gundruk, dried vegetables during peak harvest)."""
    },
    {
        "title": "[Recipe Detail] Unified Recipe Detail screen with dynamic servings scaling & cooktop selector",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,area:engine",
        "body": """### Overview
Build the core Unified Recipe Detail screen (Section 7).

### Features
- Hero image, origin, rating, prep/cook time, difficulty.
- Human-centric servings selector (\"How many people are eating?\") dynamically scaling ingredient amounts and per-member portions.
- Cooktop selector (Gas, Induction, Electric, Infrared) adapting heat instructions and whistle counts.
- Altitude advisory note (e.g., \"At 1,400 m: 6 siti instead of 5\").
- Titled step list with inline timers and target siti counts.
- Nutrition per portion and cost estimates."""
    },
    {
        "title": "[Recipe Detail] Recipe-to-market purchase quantity converter with surplus tracking",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:engine",
        "body": """### Overview
Implement the \"What to buy\" algorithm that converts recipe portions into realistic purchasable quantities (Section 7, 9.2).

### Logic
- Map ingredient amounts (e.g. 750g tomato) to vendor units (1 kg or 4 pau).
- Track pantry status (Already have / Need to buy).
- Compute expected surplus (e.g., \"250g leftover tomato -> suggests tomato achar\").
- Feed purchasable amounts directly to the grocery list generator."""
    },
    {
        "title": "[Kitchen] Siti Counter active session UI with high-contrast count, step guide, and audio alarms",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,area:audio",
        "body": """### Overview
Build the signature Siti Counter active cooking screen in the Kitchen tab (Section 10.1, 15.2).

### Features
- Oversized whistle counter readable from 2 meters away (e.g., \"3 / 4 siti\").
- Manual tap fallback (+1 / -1) for noisy environments.
- Active step card with cooktop heat guidance (e.g., \"Medium flame\").
- Distinct, loud audio alarm and device vibration when target count is reached.
- Screen awake lock during cooking session."""
    },
    {
        "title": "[Kitchen] Android foreground service & iOS audio background listening integration",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,area:audio",
        "body": """### Overview
Integrate native background audio capture with the React Native app (Section 23.3).

### Tasks
- [ ] Android foreground service with persistent notification displaying live whistle count and quick action buttons (Stop, +1, -1).
- [ ] iOS background audio session management with Live Activities & Dynamic Island integration.
- [ ] Microphone foreground-service permissions with privacy primer (\"Audio never leaves your phone\")."""
    },
    {
        "title": "[Safety] Deterministic allergen & dietary rule filtering engine with zero-miss test suite",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:engine,area:safety,gate:week12",
        "body": """### Overview
Build the deterministic safety engine for allergen detection and dietary rule enforcement (Section 12.5, 22.3).

### Features
- Common allergen catalog (EU 14 allergens + regional allergens like buckwheat, mustard oil).
- Ingredient-to-allergen mapping with hidden sources (e.g. hing often containing wheat/gluten, ghee containing dairy).
- Deterministic filter: severe allergens completely hidden or highlighted with unmistakable warnings; auto-plan strictly forbids conflicting recipes.
- Safe substitution suggestions (e.g. sunflower seed butter for peanut butter).

### Gate 2 Criteria
- [ ] Comprehensive test suite with zero false negatives on severe allergens."""
    },
    {
        "title": "[Planner] Weekly meal planner with custom meal rhythms (dal bhat / khaja slots)",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,area:engine",
        "body": """### Overview
Build the weekly meal planner supporting regional household meal rhythms (Section 8.1, 8.2).

### Features
- Configurable meal rhythm slots (Nepal default: Morning Dal Bhat, Afternoon Khaja, Evening Dal Bhat).
- Weekly grid view with drag-and-drop recipe slotting.
- Badges for seasonal ingredients, diet fit, and leftover utilization.
- Offline storage in local SQLite."""
    },
    {
        "title": "[Planner] Rule-based auto-plan generator (quick, budget, seasonal, dietary fit)",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:engine",
        "body": """### Overview
Implement deterministic auto-plan constraint solver in `packages/kitchen-engine` (Section 8.2).

### Criteria
- Inputs: household member constraints, allergies, installed region pack, pantry items, selected goal (Quick, Budget, Seasonal, High Protein, Vegetarian).
- Constraints: satisfy 100% of member allergies, minimize ingredient waste across the week, prioritize peak seasonal produce.
- Output: 7-day schedule with planned recipes and combined grocery requirements."""
    },
    {
        "title": "[Groceries] Grocery list generation from meal plan with stall grouping (haat bazaar / wet market)",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile,area:engine",
        "body": """### Overview
Implement automated grocery list generation from the weekly meal plan (Section 9.1, 9.4).

### Features
- Automatically aggregate ingredients across all planned meals for the week.
- Subtract available pantry quantities.
- Group items by market stalls: Vegetables, Fruit, Meat/Fish, Spices, Grains/Staples.
- Express quantities in vendor units (pau, kg, mana, bunches)."""
    },
    {
        "title": "[Groceries] High-contrast Market Mode checklist & localized WhatsApp/SMS text list export",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:mobile",
        "body": """### Overview
Build the Market Mode shopping interface and text sharing exporter (Section 9.4, 9.5).

### Features
- Minimalist, high-contrast, one-handed checklist with large tap targets.
- Checking items off automatically moves them to the household pantry.
- One-tap text generator exporting the grocery list formatted cleanly for WhatsApp, Viber, or SMS in Nepali and English."""
    },
    {
        "title": "[Sync] Offline-first delta sync engine with client-side outbox and UUIDv7 conflict resolution",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,area:backend,area:mobile",
        "body": """### Overview
Build the offline-first synchronization engine connecting mobile SQLite and Cloudflare D1 (Section 21.3).

### Features
- Client outbox queue for offline mutations.
- Batch `POST /v1/sync` request triggered on app open, close, and post-cooking.
- UUIDv7 client-generated IDs, record versioning, and deterministic last-write-wins (except safety/allergies which prompt conflict resolution).
- Low bandwidth optimization (gzip/brotli, payload <30KB)."""
    },
    {
        "title": "[P0 Gate] End-to-end integration of Benchmark Journey 19.1 (Kathmandu Seasonal Dinner) 100% offline",
        "milestone": "M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)",
        "labels": "p0,gate:week12",
        "body": """### Overview
Validate Week 12 Core Build Gate by verifying Benchmark User Journey 19.1 in complete airplane mode (Section 19.1, 28.3).

### Test Flow
1. Home screen displays seasonal Bagmati produce (cauliflower, spinach, radish).
2. User taps cauliflower -> selects Aloo Gobi -> adds to Thursday dinner.
3. Grocery list generates with 1 kg cauliflower, 1 kg potato, 2 pau tomato.
4. User checks off items in Market Mode at haat bazaar -> items move to pantry.
5. Thursday cooking alert fires -> Siti Counter runs whistle detection with audio alarms.
6. Meal finishes -> logs batch yield.
7. 100% executed offline on a low-end Android phone."""
    },

    # M3
    {
        "title": "[Consumption] One-tap meal logging (\"Did everyone eat their usual?\") and familiar vessel portion adjuster",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:mobile,area:engine",
        "body": """### Overview
Implement minimal-effort meal consumption tracking (Section 11.1, 11.2).

### Features
- Post-meal notification: \"Did everyone eat their usual dinner?\" -> One-tap \"Yes\" / \"Adjust\".
- Adjust view with calibrated household vessels: katori, bowl, plate, ladle, roti, piece.
- Household calibration tool: set typical vessel volume (e.g. \"our katori ≈ 150 ml\").
- Quick-add for snacks and outside food."""
    },
    {
        "title": "[Nutrition] Yield-factor based nutrition engine & calm non-shaming family dashboard",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:engine,area:ui",
        "body": """### Overview
Calculate nutrition from cooked batches using yield factors and present a calm family dashboard (Section 11.1, 11.4).

### Features
- Raw-to-cooked yield factor calculations (e.g. rice tripling weight, spinach shrinking).
- Regional food composition tables (Nepal Food Composition Table, IFCT).
- Member nutrition profiles (Everyday, Pregnancy, Elderly, Child food groups without calorie numbers).
- Non-shaming UI: progress bars for protein, fiber, seasonal share, zero red alert shaming."""
    },
    {
        "title": "[Waste] Leftover tracking (\"Eat first\") and recurring food waste analytics",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:engine,area:mobile",
        "body": """### Overview
Implement leftover management and household waste intelligence (Section 8.4, 11.3).

### Features
- Automatic creation of \"Eat first\" leftover entries when cooked yield exceeds consumed portions.
- Expiration reminders based on climate and refrigeration status.
- Waste insights: \"Dal is often left over on Mondays; try 4 servings instead of 6\"."""
    },
    {
        "title": "[Co-Cooking] Realtime cooking crew synchronization via Cloudflare Durable Objects WebSockets",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:backend,area:realtime",
        "body": """### Overview
Build the live co-cooking realtime synchronization server using Cloudflare Durable Objects (Section 12.6, 20.2).

### Features
- One Durable Object per active cooking session with WebSocket Hibernation.
- Synchronized broadcast of step completions, timers, and whistle counts across all crew phones.
- Shared alarm broadcast when target whistle count is reached.
- Presence tracking for lead cook and co-cooks."""
    },
    {
        "title": "[Co-Cooking] Multi-member task splitting (prep, cook, clean-up) & fair-share cooking rota",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:mobile,area:engine",
        "body": """### Overview
Implement task splitting and cooking crew invitations (Section 12.6).

### Features
- Break recipes into parallel tasks: wash/chop, grind masala, watch cooker, roll rotis, clean-up.
- Task assignment based on age appropriateness, skill, and preference.
- Lead cook invitation prompt: \"Invite Sita & Rohan to help with dal?\".
- Fair-share summary highlighting teamwork without guilt."""
    },
    {
        "title": "[AI] Offline-first 3-tier AI assistant routing (deterministic -> on-device -> Gemini online)",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:ai,area:backend",
        "body": """### Overview
Implement the grounded, privacy-preserving AI assistant architecture (Section 13, 22.2).

### Routing
1. Deterministic kitchen engine answers what it can (timers, pantry recipes, conversions).
2. On-device models (Apple Foundation Models, Gemini Nano).
3. Cloud Gemini API via Cloudflare AI Gateway with explicit user consent.

### Guardrails
- Automatic pseudonymization of user names and personal health data.
- Strict deterministic post-check: suggested recipes MUST pass allergen & dietary filters before display.
- Every response ends with executable action buttons (Add to plan, Cook, Add to list)."""
    },
    {
        "title": "[Voice] Hands-free kitchen voice control for timer, steps, and whistle count",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:audio,area:ai",
        "body": """### Overview
Implement hands-free voice commands for wet-hand cooking environments (Section 13.3).

### Commands
- \"How many siti left?\"
- \"Next step\"
- \"Set timer for 5 minutes\"
- \"Add salt to grocery list\"
- Multilingual voice support (Nepali, Hindi, English)."""
    },
    {
        "title": "[Signal Engine] Expand acoustic classification to hissing spring-valves, electric beeps, and clicks",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:audio",
        "body": """### Overview
Expand the cooking signal engine beyond pressure cookers (Section 10.2).

### Supported Signals
- European spring-valve pressure cookers (continuous hiss).
- Electric pressure cookers (target completion beeps).
- Rice cookers (mechanical switch clicks).
- Boiling kettle whistles."""
    },
    {
        "title": "[Safety] Printable offline allergy cards and infant allergen introduction tracker",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:safety,area:mobile",
        "body": """### Overview
Deliver advanced allergy protection features (Section 12.5).

### Features
- Generate offline, bilingual emergency allergy cards (Nepali/English, etc.) with emergency contacts for restaurants and travel.
- Baby & Toddler allergen introduction tracker recording first exposure, portion size, and reaction notes with pediatric disclaimers."""
    },
    {
        "title": "[Hardware] Smart display integration: Alexa Skill (APL) and Google Cast web receiver",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:displays",
        "body": """### Overview
Build smart display kitchen experiences (Section 24.2).

### Implementations
- TypeScript Alexa Skill hosted on Cloudflare Workers with Alexa Presentation Language (APL) rendering today's menu, step-by-step cooking, and timers on Echo Show.
- Google Cast web receiver app for casting live cooking sessions and siti count to Nest Hub."""
    },
    {
        "title": "[Kitchen] LPG cylinder depletion estimator and power-cut offline mode",
        "milestone": "M3: P1 Household Intelligence & Collaboration (Weeks 13–18)",
        "labels": "p1,area:engine,area:mobile",
        "body": """### Overview
Implement fuel management and outage resiliency tools (Section 10.5).

### Features
- Estimate remaining LPG cylinder weight/days based on logged cooking sessions and flame intensity.
- Refill reminder alert when cylinder is predicted to deplete in 4 days.
- Power-cut mode: one-tap filter for gas-only or no-cook recipes."""
    },

    # M4
    {
        "title": "[Monetization] In-app subscription integration (App Store & Google Play) with purchasing-power parity",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:commerce",
        "body": """### Overview
Integrate mobile in-app purchases for the annual household subscription (Section 26.1, 26.2).

### Pricing & Tiers
- Free tier: 100% core loop, whistle counter, recipes, planner, market mode, offline sync.
- Premium annual household plan: unlimited AI, live market prices, party mode, family cookbook.
- Purchasing-power parity pricing (indicative: NPR 999 in Nepal, ₹499 in India, USD 14.99 in US).
- Signed offline entitlement tokens."""
    },
    {
        "title": "[Monetization] Web checkout with regional wallets (Khalti, eSewa, Stripe) & entitlements service",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:commerce,area:backend",
        "body": """### Overview
Implement web payment flows for Nepal and regional markets (Section 26.3).

### Integrations
- Web checkout supporting Khalti, eSewa, and Stripe.
- Cloudflare Worker entitlements service updating household subscription status in D1.
- Family gifting: allow diaspora members abroad to purchase subscriptions for family in Nepal."""
    },
    {
        "title": "[Shopping] Regional market price board ingestion (Kalimati wholesale market API / scraping)",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:backend,area:commerce",
        "body": """### Overview
Automate daily wholesale market price ingestion for Nepal (Section 26.4, 26.5).

### Tasks
- Scheduled Cloudflare Worker cron job fetching daily price tables from Kalimati wholesale market.
- Store daily commodity prices in D1 and cache static snapshots.
- Display normalized price indicators on ingredient cards and grocery lists."""
    },
    {
        "title": "[Shopping] Deep-linking and affiliate handoff to regional retailers (Bhatbhateni, Daraz)",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:commerce,area:mobile",
        "body": """### Overview
Build retailer shopping handoffs (Section 9.5, 26.4).

### Tasks
- Deep-link generation from grocery list items to search pages on Daraz and Bhatbhateni.
- Clear disclosure of affiliate relationships; no advertising rank bias.
- User option to disable shopping partner links entirely."""
    },
    {
        "title": "[Community] Community recipe & price contribution workflow with moderation queue in Cloudflare Workflows",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:community,area:backend",
        "body": """### Overview
Enable community contributions for recipes and ingredient sightings (Section 17, 20.2).

### Tasks
- In-app contribution forms for recipes, local ingredient names, and market price reports.
- Automated moderation pipeline using Cloudflare Workflows and Workers AI screening.
- Human review queue for \"Verified\" vs \"Community\" badge assignment."""
    },
    {
        "title": "[OCR] On-device receipt & packaging label parser for pantry auto-fill and allergen checking",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:ai,area:mobile",
        "body": """### Overview
Implement camera-based receipt and food label scanning (Section 22.1).

### Tasks
- On-device OCR parsing grocery receipts to update pantry stock and spend logs.
- Packaged food label scanner highlighting member allergens in ingredients lists (\"Contains gluten\")."""
    },
    {
        "title": "[Planning] Party Mode planner with T-minus prep timeline and equipment conflict detection",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,area:engine,area:mobile",
        "body": """### Overview
Build the dedicated Party Mode hosting module (Section 8.7).

### Flow
- Guest count and dietary rules gathering.
- Scaled menu builder (drinks, appetizers, mains, sides, desserts).
- T-minus preparation timeline (e.g. marinate at 3:00, curry at 5:00, rice at 6:00, serve at 7:00).
- Equipment conflict detection (e.g. flags if two dishes need the 5L pressure cooker simultaneously).
- Combined party grocery list and co-host task delegation."""
    },
    {
        "title": "[Launch Gate] Closed beta monitoring, performance hardening (crash-free ≥99.5%, CF free tier <70%)",
        "milestone": "M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)",
        "labels": "p2,gate:week24",
        "body": """### Overview
Final preparation and verification for the Open Beta launch gate (Section 28.3).

### Verification Gates
- Crash-free user sessions ≥ 99.5%.
- Cloudflare free-tier utilization below 70% with automated alert thresholds.
- Privacy policy and terms compliant with Nepal Privacy Act and GDPR.
- Active weekly cooking rate ≥ 40% among closed beta households."""
    },

    # M5
    {
        "title": "[Region Pack] Expand Region Pack framework: India, Australia/Diaspora, and High-Altitude Andes",
        "milestone": "M5: P3 Global Expansion & Ecosystem (Post-Launch)",
        "labels": "p3,region-pack,area:content",
        "body": """### Overview
Scale global content packs following the launch of the Nepal pack (Section 4, 19.3, 19.4).

### New Packs
- India pack (regional languages, IFCT nutrition, mandis, festivals).
- Australia / Diaspora pack (Taste of Home substitutions, inverted Southern Hemisphere seasons).
- Andean high-altitude pack (La Paz 3,600m altitude calibrations, local tubers)."""
    },
    {
        "title": "[Displays] Native widgets (iOS/Android), Apple Watch & Wear OS companion apps",
        "milestone": "M5: P3 Global Expansion & Ecosystem (Post-Launch)",
        "labels": "p3,area:displays,area:mobile",
        "body": """### Overview
Build companion extensions across wearable and glanceable surfaces (Section 23.4).

### Features
- Home screen widgets: today's meals, active siti count, grocery checklist.
- Apple Watch & Wear OS companion apps: live whistle count, haptic alarm on target, step completion toggle."""
    },
    {
        "title": "[Kitchen] Multi-dish kitchen: parallel cooking lanes (>2 dishes) with burner/vessel conflict warnings",
        "milestone": "M5: P3 Global Expansion & Ecosystem (Post-Launch)",
        "labels": "p3,area:engine,area:mobile",
        "body": """### Overview
Expand Kitchen screen to support simultaneous multi-dish cooking lanes (Section 10.6).

### Features
- Parallel lanes (e.g. Dal 2/3 siti · Rice 08:30 · Sabzi 04:10 · Chapati waiting).
- Burner and vessel conflict detection.
- Audio disambiguation prompt when a whistle could belong to more than one cooker."""
    },
    {
        "title": "[Commerce] Partner Cart direct API integration for one-tap grocery checkout",
        "milestone": "M5: P3 Global Expansion & Ecosystem (Post-Launch)",
        "labels": "p3,area:commerce",
        "body": """### Overview
Implement Level 3 partner cart checkout integrations (Section 26.4).

### Scope
- Direct API integration with regional delivery partners.
- Transfer entire grocery list into merchant cart in one tap."""
    }
]

print(f"\n>>> Provisioning {len(ISSUES)} issues...")
created_count = 0
skipped_count = 0

for idx, issue in enumerate(ISSUES, 1):
    title = issue["title"]
    milestone = issue["milestone"]
    labels = issue["labels"]
    body = issue["body"]

    if title in existing_issues:
        print(f"[{idx}/{len(ISSUES)}] Skipping existing: {title}")
        skipped_count += 1
        continue

    print(f"[{idx}/{len(ISSUES)}] Creating: {title}")
    res = subprocess.run([
        "gh", "issue", "create",
        "--repo", REPO,
        "--title", title,
        "--milestone", milestone,
        "--label", labels,
        "--body", body
    ], capture_output=True, text=True)

    if res.returncode == 0:
        url = res.stdout.strip()
        print(f"  ✓ Created: {url}")
        created_count += 1
    else:
        print(f"  X Error: {res.stderr.strip()}", file=sys.stderr)

print("\n==========================================================")
print(f"Provisioning Summary: {created_count} created, {skipped_count} skipped.")
print("==========================================================")
