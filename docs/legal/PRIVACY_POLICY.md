# Privacy Policy — Siti Counter 3.0

*Last Updated: October 5, 2026*

Siti Counter 3.0 is built on a fundamental principle: **Your kitchen data belongs to your household.** This policy sets out how we handle data in accordance with Nepal's **Individual Privacy Act, 2075 (2018)**, the **EU General Data Protection Regulation (GDPR)**, and global privacy standards.

---

## 1. Core Principles

1. **Acoustic Whistle Processing Never Leaves Your Device**: All audio captured during active cooking sessions is processed in real time entirely on your device (using on-device neural acoustic classifiers). Audio samples are discarded immediately after frame feature extraction. **Audio is never recorded, never stored on disk, and never transmitted over the network.**
2. **Zero Advertising Rank Bias**: We never sell user attention or rank ingredients, grocery stores, or equipment based on advertising payments.
3. **No Pediatric Calorie Counters**: To protect children's healthy relationship with food, family members registered as children are never shown calorie or dietary deficit numbers.
4. **Data Portability & Erasure**: You can export all household data or erase your entire household history in one tap at any time.

---

## 2. Information We Collect

### A. Local-First Data (Stored on Your Phone)
The following information is stored locally on your device in an encrypted SQLite database:
- Household setup (cooktops, pressure cooker models, fuel type).
- Family member preferences (allergens, fasting days, dietary rules).
- Meal plans, grocery lists, and pantry inventory.
- Cooking session history (whistles recorded, durations, timers).

### B. Optional Cloud Sync Data (Delta-Sync Protocol)
If you choose to sync your household across multiple devices or invite cooking crew members:
- **Anonymized Household UUIDv7**: A randomly generated identifier not linked to your real identity.
- **Delta Mutations**: Encrypted record mutations (e.g. grocery checklist state changes, meal plan slot updates) sent in compressed batches under 30KB.
- **Authentication**: Optional email magic links or Google sign-in credentials managed via secure tokens.

### C. Anonymized Telemetry (Opt-Out Enabled)
To ensure system stability (meeting our >=99.5% crash-free launch gate):
- App version, operating system, and hardware architecture.
- Session duration and fatal crash call stacks (devoid of personal identifiers or user notes).

---

## 3. Compliance with Nepal Individual Privacy Act, 2075 (2018)

In compliance with Chapter 2 & Chapter 3 of Nepal's Individual Privacy Act, 2075:
- **Notice & Consent (Section 4 & 5)**: Explicit, informed consent is collected before any network synchronization or optional notification scheduling occurs.
- **Protection of Biometric and Acoustic Privacy**: The app strictly prohibits cloud upload of voice or ambient audio. Microphone access is requested only for the acoustic cooking session.
- **Prohibition on Unauthorized Transfer (Section 12)**: Data is never shared or transferred to third-party commercial brokers or advertisers.

---

## 4. Compliance with EU GDPR & Global Data Protection Rights

Under GDPR Articles 12–23:
- **Right to Access (Article 15)**: View all your stored data within the app settings.
- **Right to Rectification (Article 16)**: Edit any meal log, portion calibration, or member allergy at any time.
- **Right to Erasure / "To Be Forgotten" (Article 17)**: Trigger permanent deletion of your cloud sync state and local storage via `Settings -> Privacy -> Erase All Data`.
- **Right to Data Portability (Article 20)**: Download your entire meal planning and cooking logs in standard JSON or CSV format.
- **Privacy by Design (Article 25)**: Offline-first architecture by default.

---

## 5. Contact & Data Protection Officer

For privacy inquiries, audit requests, or data deletion support:
- Email: `privacy@siticounter.app`
- Data Controller: Siti Counter Engineering Team, Kathmandu, Nepal.
