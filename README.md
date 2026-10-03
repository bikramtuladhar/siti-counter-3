# Siti Counter 3.0

> A household cooking companion for every kind of home in the world, built around one food lifecycle and tailored to each region, household, and family member.

---

## 🍳 Overview

Siti Counter 3.0 accompanies a household across the full food lifecycle:
**Discover → Plan → Shop → Prepare → Cook → Serve → Eat → Measure → Repeat**

- **Signature Feature**: Acoustic pressure cooker whistle detection (`siti` counter) with background listening and multi-cooker support.
- **Region-Ready Architecture**: Region Packs (Nepal Bagmati launch pack) provide local ingredients, ritus/seasons, Bikram Sambat calendar, haat bazaar units (pau, dharni, mana), and verified recipes.
- **Offline & Low-End First**: Built to run reliably on 2 GB Android phones, fully functional without an internet connection.
- **Zero-Cost Cloud Infrastructure**: Built to launch on Cloudflare's free tier (Workers, D1 SQLite, Durable Objects WebSockets, R2, KV).
- **Safety First**: Deterministic allergen filtering and dietary rule enforcement that no AI or manual override can accidentally bypass.

---

## 🏗️ Repository Architecture

This repository is organized as a TypeScript-first monorepo using **pnpm** and **Turborepo**:

```
siti_counter_3/
├── apps/
│   ├── mobile/              # React Native + Expo (iOS & Android)
│   ├── web/                 # Expo Router web & PWA
│   ├── alexa/               # Alexa Skill on Cloudflare Workers with APL
│   └── cast/                # Google Cast web receiver for Nest Hub & displays
├── packages/
│   ├── kitchen-engine/      # Pure TS domain engine: scaling, units, altitude, nutrition, auto-plan
│   ├── db/                  # Drizzle ORM schema for SQLite (expo-sqlite & Cloudflare D1)
│   ├── contracts/           # Zod schemas -> OpenAPI 3.1 & typed API client
│   ├── tokens/              # W3C Design Tokens -> Style Dictionary (React Native, CSS, APL, Swift/Kotlin)
│   ├── ui/                  # Shared component library (React Native Web)
│   └── region-packs/        # Versioned Region Packs (Nepal/Bagmati launch pack)
├── services/
│   ├── gateway/             # Cloudflare Workers API Gateway & Auth
│   ├── sync/                # Delta-sync service (/v1/sync)
│   ├── realtime/            # Durable Objects WebSocket server for live cooking crew
│   └── ai-orchestrator/     # AI routing (deterministic -> on-device -> Gemini online)
├── native/
│   ├── expo-whistle-detector/ # Kotlin & Swift audio classification native module (LiteRT / Core ML)
│   └── expo-foreground-cooker/ # Android foreground service & iOS Live Activities
├── scripts/
│   └── create-github-issues.sh # Automated GitHub issues & milestones setup
└── SPECIFICATION.md         # Full unified product specification
```

---

## 🗺️ Roadmap & Milestones

1. **M1: Foundations & Architecture Spike (Weeks 1–4, Gate 1)**
   - Monorepo, CI/CD, and Style Dictionary token pipeline.
   - Whistle detection audio classifier spike (LiteRT/Core ML, ≥97% accuracy across 30+ recordings).
   - Core `kitchen-engine` (metric + market units, altitude calculations, yield factors).
   - Cloudflare D1 schema & `/v1/sync` delta-sync prototype.
2. **M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12, Gate 2)**
   - Nepal Region Pack (Bagmati): ~150 verified recipes, ~60 seasonal ingredients, ritus, festivals.
   - Onboarding (Tour, 5 questions, "Your kitchen is ready" preview, guest mode).
   - Discover & Seasonal Kitchen.
   - Unified Recipe Detail (servings scaling, cooktop selector, altitude notes, market shopping list).
   - Siti Counter with Android foreground service & iOS Live Activity fallback.
   - Weekly Planner & Meal Rhythms (Dal bhat / khaja slots, auto-plan).
   - Groceries & Market Mode (haat bazaar checklist, WhatsApp/SMS sharing).
   - Deterministic Allergen & Dietary Safety System.
3. **M3: P1 Household Intelligence & Collaboration (Weeks 13–18)**
   - Consumption & Nutrition Logging (one-tap meal confirmation, yield factor nutrition).
   - Live Co-Cooking Crew (Durable Objects WebSockets, task splitting, presence, shared alarm).
   - Grounded AI Assistant (on-device first -> Gemini Online with consent).
   - LPG cylinder tracking & power-cut mode.
4. **M4: P2 Commerce, Content Depth & Launch (Weeks 19–24, Launch Gate)**
   - Premium household subscription (in-app purchase, Khalti/eSewa/Stripe, entitlements).
   - Regional shopping integrations (Kalimati market daily price boards, deep links).
   - Community recipe & price contributions with moderation pipeline.
5. **M5: P3 Global Expansion & Smart Displays (Post-Launch)**
   - Additional Region Packs (India, Australia/Diaspora, High-altitude Andes).
   - Alexa skill (APL) & Nest Hub cast receiver.
   - Multi-dish cooking lanes (>2 cookers) with conflict detection.

---

## 🛠️ Quickstart

### Prerequisites
- Node.js 20+
- pnpm 9+
- GitHub CLI (`gh`) for tracking issues and repository integration

```bash
# Install dependencies
pnpm install

# Run test suite across all packages
pnpm test

# Launch mobile development server
pnpm --filter mobile start
```

---

## 📄 License & Attribution
Spec authored by @Bikram · October 2026.
See [SPECIFICATION.md](./SPECIFICATION.md) for full product details.
