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

## 🏗️ Architecture & Platform Stack

Based on our architectural decisions, the platforms are separated to leverage the best tool for each surface:

| Platform | Technology | Why Chosen |
| :--- | :--- | :--- |
| **Mobile App (iOS & Android)** | **Flutter (Dart 3)** | Superior native ARM performance on 2 GB Android devices; rock-solid 60 fps audio gauge animations; LiteRT/CoreML audio integration; reactive SQLite via **Drift**. |
| **Web & Tablet Display (PWA)** | **Vue 3 + Vite (TypeScript)** | Instant initial load, minimal bundle size, responsive recipe browsing, desktop weekly planner grid, and high-performance kitchen stand dashboard. |
| **Backend API & Realtime** | **Cloudflare Workers (Hono + TypeScript)** | Global low-latency edge deployment; serverless SQLite with **D1**; live cooking crew presence via **Durable Objects WebSockets**; 100% free-tier compliant. |
| **Shared Design Tokens** | **W3C Tokens + Style Dictionary** | Single JSON source of truth compiled to Dart theme constants (Flutter) and CSS/Tailwind variables (Vue 3). |
| **Shared Content** | **Region Packs (JSON)** | Downloadable, versioned content bundles (Nepal Bagmati pack) consumed by both Flutter and Vue. |

### Monorepo Structure

```
siti_counter_3/
├── apps/
│   ├── mobile/              # Flutter App (iOS & Android)
│   └── web/                 # Vue 3 + Vite Web App & PWA
├── services/
│   ├── api/                 # Cloudflare Workers API Gateway (Hono + D1 + Drizzle)
│   └── realtime/            # Durable Objects WebSocket server for live cooking crew
├── packages/
│   ├── kitchen_engine_dart/ # Pure Dart domain engine for mobile (scaling, units, altitude, rules)
│   ├── kitchen_engine_ts/   # Pure TS domain engine for Vue web & Cloudflare Workers
│   ├── tokens/              # Design tokens -> Style Dictionary (Dart classes & CSS variables)
│   └── region-packs/        # Versioned Region Packs (Nepal Bagmati launch pack)
├── scripts/
│   ├── create_issues.py     # GitHub issues and milestones provisioner
│   └── create-github-issues.sh
├── README.md
└── SPECIFICATION.md         # Full unified product specification
```

---

## 🗺️ Roadmap & Milestones

1. **[M1: Foundations & Architecture Spikes (Weeks 1–4)](https://github.com/bikramtuladhar/siti-counter-3/milestone/1)**
   - Monorepo setup (Flutter mobile, Vue web, Cloudflare Workers).
   - Whistle detection audio classifier spike (LiteRT/Core ML, ≥97% accuracy across 30+ recordings).
   - Core kitchen engines (Dart for mobile, TS for web/Workers).
   - Cloudflare D1 schema & `/v1/sync` delta-sync prototype.
2. **[M2: P0 Core Cooking Loop & Nepal Beta (Weeks 5–12)](https://github.com/bikramtuladhar/siti-counter-3/milestone/2)**
   - Nepal Region Pack (Bagmati): ~150 verified recipes, ~60 seasonal ingredients, ritus, festivals.
   - Onboarding (Tour, 5 questions, "Your kitchen is ready" preview, guest mode).
   - Discover & Seasonal Kitchen.
   - Unified Recipe Detail (servings scaling, cooktop selector, altitude notes, market shopping list).
   - Siti Counter with Android foreground service & iOS Live Activity fallback.
   - Weekly Planner & Meal Rhythms (Dal bhat / khaja slots, auto-plan).
   - Groceries & Market Mode (haat bazaar checklist, WhatsApp/SMS sharing).
   - Deterministic Allergen & Dietary Safety System.
3. **[M3: P1 Household Intelligence & Collaboration (Weeks 13–18)](https://github.com/bikramtuladhar/siti-counter-3/milestone/3)**
   - Consumption & Nutrition Logging (one-tap meal confirmation, yield factor nutrition).
   - Live Co-Cooking Crew (Durable Objects WebSockets, task splitting, presence, shared alarm).
   - Grounded AI Assistant (on-device first -> Gemini Online with consent).
   - LPG cylinder tracking & power-cut mode.
4. **[M4: P2 Commerce, Content Depth & Launch (Weeks 19–24)](https://github.com/bikramtuladhar/siti-counter-3/milestone/4)**
   - Premium household subscription (in-app purchase, Khalti/eSewa/Stripe, entitlements).
   - Regional shopping integrations (Kalimati market daily price boards, deep links).
   - Community recipe & price contributions with moderation pipeline.
5. **[M5: P3 Global Expansion & Ecosystem (Post-Launch)](https://github.com/bikramtuladhar/siti-counter-3/milestone/5)**
   - Additional Region Packs (India, Australia/Diaspora, High-altitude Andes).
   - Alexa skill (APL) & Nest Hub cast receiver.
   - Multi-dish cooking lanes (>2 cookers) with conflict detection.

---

## 🛠️ Tech Stack Quick Links
- **Mobile**: Flutter 3.x, Riverpod, Drift (SQLite), LiteRT (TFLite)
- **Web**: Vue 3, Vite, Pinia, TailwindCSS
- **Backend**: Cloudflare Workers, Hono, D1 (SQLite), Durable Objects, Wrangler
- **Tokens**: W3C Design Tokens, Style Dictionary

---

## 📄 License & Attribution
Spec authored by @Bikram · October 2026.
See [SPECIFICATION.md](./SPECIFICATION.md) for full product details.
