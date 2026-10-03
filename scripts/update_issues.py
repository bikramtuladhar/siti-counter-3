#!/usr/bin/env python3
import subprocess
import sys

REPO = "bikramtuladhar/siti-counter-3"

UPDATES = {
    3: {
        "title": "[Spike] iOS background listening & Live Activities feasibility test (Flutter / Swift)",
        "body": """### Overview
Evaluate iOS background audio lifecycle and Live Activity constraints with Flutter and native Swift (Section 23.3, 29.1).

### Tasks
- [ ] Implement native Swift Flutter plugin / MethodChannel for continuous background audio session recording (`AVAudioSession`).
- [ ] Implement iOS Live Activity & Dynamic Island widget using ActivityKit showing active siti count and step timer.
- [ ] Test system suspension behaviors under screen lock, incoming calls, and multitasking.
- [ ] Implement graceful fallback to countdown timer with user alert if audio capture is interrupted."""
    },
    5: {
        "title": "[Engine] Implement core kitchen-engine: metric & local market unit conversion (pau, dharni, mana)",
        "body": """### Overview
Build the pure domain unit conversion subsystem in Dart for Flutter (`packages/kitchen_engine_dart`) and TypeScript for Vue 3 / Cloudflare Workers (`packages/kitchen_engine_ts`) (Section 4, 18).

### Scope
- Conversion between canonical metric units (g, ml) and local South Asian market units:
  - 1 pau = 250 g
  - 1 dharni = 2.5 kg (or 10 pau)
  - 1 mana ≈ 568 ml (volume) / local grain equivalent
  - Seer, tola, bunches, heaps, pieces.
- Distinction between US cups (240ml) and Metric cups (250ml).
- Conversion functions from recipe cooking units (e.g. "1 tbsp oil") to purchasable market package units.

### Acceptance Criteria
- [ ] 100% unit test coverage in `dart test` (Dart engine) and Vitest (TypeScript engine).
- [ ] Zero runtime dependencies, usable offline on device and at the Cloudflare edge."""
    },
    6: {
        "title": "[Engine] Implement altitude compensation algorithms for boiling point & pressure timings",
        "body": """### Overview
Implement elevation-aware cooking adjustment algorithms in the core domain kitchen engine (Section 7, 10.4).

### Scope
- Calculation of water boiling point at altitude (e.g. Kathmandu at 1,400m ≈ 95°C; La Paz at 3,600m < 90°C).
- Recipe adjustment calculation: pressure whistle scaling (e.g. "At 1,400m: 6 siti instead of 5"), simmer duration, and soaking multipliers.
- Human-readable explanation generation for recipe detail view (both Flutter mobile and Vue 3 web).
- Implemented in `packages/kitchen_engine_dart` (Flutter) and `packages/kitchen_engine_ts` (Vue / Workers)."""
    },
    7: {
        "title": "[Tokens] Set up W3C Design Tokens & Style Dictionary multi-platform build pipeline",
        "body": """### Overview
Set up the design token repository in `packages/tokens` to drive Flutter mobile, Vue 3 web, and smart displays (Section 25).

### Tasks
- [ ] Define tokens in W3C Design Tokens JSON: colors (light & dark mode, terracotta primary, warm white), typography, fluid spacing, elevation, radius.
- [ ] Configure Style Dictionary to generate:
  - Dart theme classes and constants for Flutter (`apps/mobile`).
  - CSS variables and Tailwind theme extensions for Vue 3 (`apps/web`).
  - Alexa Presentation Language (APL) styles and Swift/Kotlin constants.
- [ ] Add distance profile tokens: near (phone), arm's length (counter), across the room (smart display)."""
    },
    12: {
        "title": "[Auth] Guest-first mode with Google Sign-in & email magic link with data merge",
        "body": """### Overview
Implement account identity management supporting seamless guest usage and upgrade (Section 5.5, 20.1).

### Tasks
- [ ] Anonymous local guest profile stored in SQLite on device (Drift in Flutter, D1 on server).
- [ ] Google Sign-In and Email Magic Link auth on Cloudflare Workers.
- [ ] Non-destructive guest data merge into newly authenticated account on sign-in.
- [ ] Secure token storage using Flutter Secure Storage (Android Keystore / iOS Keychain) with 15-minute access tokens and rotating refresh tokens."""
    },
    16: {
        "title": "[Kitchen] Siti Counter active session UI with high-contrast count, step guide, and audio alarms",
        "body": """### Overview
Build the signature Siti Counter active cooking screen in Flutter (`apps/mobile`) and Vue 3 (`apps/web`) (Section 10.1, 15.2).

### Features
- Custom Flutter canvas animated whistle counter readable from 2 meters away (e.g., "3 / 4 siti").
- Manual tap fallback (+1 / -1) for noisy environments.
- Active step card with cooktop heat guidance (e.g., "Medium flame").
- Distinct, loud audio alarm and device vibration when target count is reached.
- Screen wake lock during cooking session (`wakelock_plus` in Flutter).
- Synchronized display in Vue 3 web kitchen mode."""
    },
    17: {
        "title": "[Kitchen] Android foreground service & iOS audio background listening integration (Flutter)",
        "body": """### Overview
Integrate native background audio capture with the Flutter mobile app (Section 23.3).

### Tasks
- [ ] Android foreground service (`flutter_foreground_task`) with persistent notification displaying live whistle count and quick action buttons (Stop, +1, -1).
- [ ] iOS background audio session management with Live Activities & Dynamic Island integration via native Swift ActivityKit MethodChannel.
- [ ] Microphone foreground-service permissions with privacy primer ("Audio never leaves your phone")."""
    },
    20: {
        "title": "[Planner] Rule-based auto-plan generator (quick, budget, seasonal, dietary fit)",
        "body": """### Overview
Implement deterministic auto-plan constraint solver in the core kitchen engine (Section 8.2).

### Criteria
- Inputs: household member constraints, allergies, installed region pack, pantry items, selected goal (Quick, Budget, Seasonal, High Protein, Vegetarian).
- Constraints: satisfy 100% of member allergies, minimize ingredient waste across the week, prioritize peak seasonal produce.
- Output: 7-day schedule with planned recipes and combined grocery requirements.
- Evaluated 100% on-device in Flutter (`kitchen_engine_dart`) and in Vue 3 / Cloudflare Workers (`kitchen_engine_ts`)."""
    },
    23: {
        "title": "[Sync] Offline-first delta sync engine with client-side outbox and UUIDv7 conflict resolution",
        "body": """### Overview
Build the offline-first synchronization engine connecting Flutter local SQLite (Drift) and Cloudflare D1 (Section 21.3).

### Features
- Client outbox queue in Drift SQLite for offline mutations.
- Batch `POST /v1/sync` request triggered on app open, close, and post-cooking.
- UUIDv7 client-generated IDs, record versioning, and deterministic last-write-wins (except safety/allergies which prompt conflict resolution).
- Low bandwidth optimization (gzip/brotli, payload <30KB)."""
    },
    24: {
        "title": "[P0 Gate] End-to-end integration of Benchmark Journey 19.1 (Kathmandu Seasonal Dinner) 100% offline",
        "body": """### Overview
Validate Week 12 Core Build Gate by verifying Benchmark User Journey 19.1 in complete airplane mode on Flutter and Vue (Section 19.1, 28.3).

### Test Flow
1. Home screen displays seasonal Bagmati produce (cauliflower, spinach, radish).
2. User taps cauliflower -> selects Aloo Gobi -> adds to Thursday dinner.
3. Grocery list generates with 1 kg cauliflower, 1 kg potato, 2 pau tomato.
4. User checks off items in Market Mode at haat bazaar -> items move to pantry.
5. Thursday cooking alert fires -> Siti Counter runs whistle detection with audio alarms.
6. Meal finishes -> logs batch yield.
7. 100% executed offline on a 2 GB Android device running the Flutter release build."""
    }
}

print(f"Updating {len(UPDATES)} issues in {REPO}...")
for num, data in UPDATES.items():
    title = data["title"]
    body = data["body"]
    print(f"Updating #{num}: {title}...")
    res = subprocess.run([
        "gh", "issue", "edit", str(num),
        "--repo", REPO,
        "--title", title,
        "--body", body
    ], capture_output=True, text=True)

    if res.returncode == 0:
        print(f"  ✓ Updated #{num}")
    else:
        print(f"  X Error updating #{num}: {res.stderr.strip()}", file=sys.stderr)

print("\nDone!")
