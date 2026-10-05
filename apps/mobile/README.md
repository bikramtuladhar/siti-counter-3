# Siti Counter — Mobile App

Flutter client for iOS and Android.

---

## Identifiers

These three differ on purpose; do not assume one from the others.

| What | Value |
| :--- | :--- |
| Dart package name | `siti_counter` (`pubspec.yaml`) |
| iOS bundle identifier | `com.siticounter.sitiCounter` (`ios/Runner.xcodeproj/project.pbxproj`) |
| Android application ID | `com.siticounter.siti_counter` (`android/app/build.gradle.kts`) |

Android uses an underscore because Java/Kotlin package segments must be valid identifiers;
iOS has no such constraint. Commands differ as a result:

```bash
# iOS
xcrun simctl launch booted com.siticounter.sitiCounter

# Android — note the underscore
adb shell monkey -p com.siticounter.siti_counter -c android.intent.category.LAUNCHER 1
```

If you change either id after first release you get a **new store listing**. Change both
together if you change one.

---

## Signing certificates & OAuth client setup

Google Sign-In on Android authenticates the app by its **signing certificate fingerprint**.
The fingerprint you register must be the one that signs the build you are distributing.

### Where the fingerprint comes from

| Distribution | Which certificate | Where to find the fingerprint |
| :--- | :--- | :--- |
| Google Play | **Play App Signing key** (Google re-signs your upload) | Play Console → **Protected with Play** → **Play Store protection** → **Manage Play app signing** → *App signing key certificate* → SHA-1 |
| Google Play | *Upload key* (your own) | Play Console → **Protected with Play** → **App integrity** → *Upload key certificate* — useful for internal testing tracks |
| Local APK / sideloaded build | Whatever key you signed with | `keytool` below |

Register **both** the Play App Signing SHA-1 and your upload-key SHA-1 in the Google Cloud
Console. Play signs the delivered APK with the Play key, so the Play fingerprint is the one
that must be registered for production; the upload key covers local and internal builds.

### Getting a fingerprint with `keytool`

```bash
# macOS JDK path; openjdk@21 is keg-only so it must be set explicitly
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"

keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android
```

On Windows use `"%JAVA_HOME%\bin\keytool"` instead.

### This machine's debug keystore

Regenerated if deleted, so treat it as local-only and never ship it:

| | |
| :--- | :--- |
| Keystore | `~/.android/debug.keystore` |
| Alias | `androiddebugkey` |
| Password | `android` |
| SHA-1 | `FE:D3:08:94:B2:06:72:EB:CE:88:22:BE:DD:39:D6:9A:97:AE:7D:B4` |
| SHA-256 | `DD:F9:D2:E5:1A:B1:D3:23:00:78:5C:C7:06:40:6D:6F:BA:3E:46:CD:BB:E0:43:5B:1D:5B:C7:47:83:D0:B4:9B` |

Valid until 23 Jun 2056.

### Release signing is not configured yet

`android/app/build.gradle.kts` still signs release builds with the **debug** key:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Before shipping, generate an upload key and wire it up:

```bash
keytool -genkey -v \
  -keystore ~/keys/siti-counter-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Keep the keystore and its passwords out of git. Put the credentials in
`android/key.properties` (gitignored) and reference them from `build.gradle.kts`. Losing the
upload key means you cannot update the listing without a Play support request.

For iOS, the equivalent is a distribution certificate plus provisioning profile; the
`CODE_SIGN_IDENTITY` in `project.pbxproj` handles team selection once a team is set in Xcode.

---

## Social sign-in

### Google

Google uses **two** client ids and they are not interchangeable:

| Role | What it does | Value |
| :--- | :--- | :--- |
| **server / Web client id** | Becomes the `aud` claim of the returned ID token, so this is what the API verifies | `228915460049-54cpjsd261jreom9cji2ql9v0jbolger.apps.googleusercontent.com` |
| **Android client id** | Identifies this app to Google | Set per build via `--dart-define=GOOGLE_ANDROID_CLIENT_ID=...`; optional, Google can infer it from the package name + registered fingerprint |

Other identifiers:

| | |
| :--- | :--- |
| Package name (Android) | `com.siticounter.siti_counter` |
| Bundle id (iOS client) | `com.siticounter.sitiCounter` |

`SocialProviderRegistry` calls `GoogleSignIn.instance.initialize(clientId:, serverClientId:)`
once per provider instance. **Skipping that call is what produces**
`GoogleSignInExceptionCode.clientConfigurationError: serverClientId must be provided on
Android` — the SDK has no default for it. The server client id is committed and defaulted; an
OAuth client id is not a secret, since it is embedded in the shipped binary either way.

The server client id must stay identical to `GOOGLE_CLIENT_ID` in
`services/api/wrangler.jsonc`, because the API checks the token's audience against it. If they
disagree, tokens fail as `INVALID_ID_TOKEN`, which reads like a bad token rather than a config
mismatch.

Registered SHA-1 fingerprints must include this machine's debug key
(`FE:D3:08:94:B2:06:72:EB:CE:88:22:BE:DD:39:D6:9A:97:AE:7D:B4`) **and** the Play App Signing
key, since Play re-signs release builds.

Sign-in needs the Play Services app, so it works on the emulator only if that image includes
Google Play services. A device with no Google account signed in will reach Google's
`PreAddAccountActivity` and stop there — that is the expected state, not a bug.

### All providers

Client ids are supplied as `--dart-define` values so a build can target a different
environment:

```bash
flutter run \
  --dart-define=GOOGLE_CLIENT_ID=228915460049-54cpjsd261jreom9cji2ql9v0jbolger.apps.googleusercontent.com \
  --dart-define=APPLE_CLIENT_ID=com.siticounter.sitiCounter \
  --dart-define=FACEBOOK_APP_ID=1234567890
```

Omitting a define falls back to the committed default; Facebook has no default, so its button
stays hidden until configured.

A provider's button is only shown when its id is resolved, and Apple additionally requires
iOS/macOS. With nothing configured the sign-in sheet reports that social sign-in is
unavailable rather than showing buttons that cannot work.

The API verifies every token and rejects anything it cannot verify
(`services/api/src/auth/social_verifier.ts`):

- **Google** — RS256 signature against Google's JWKS, audience must equal the client id
  above.
- **Apple** — ES256 signature against Apple's JWKS, audience must equal the bundle id
  (`com.siticounter.sitiCounter`, *not* `com.siticounter.app`). Requires the *Sign in with
  Apple* capability on the iOS target.
- **Facebook** — opaque access token validated server-side via Graph `debug_token`. The
  7.x SDK reads its App id from `AndroidManifest.xml` / `Info.plist`, so the `--dart-define`
  must match that value.

Matching server-side values live in `services/api/wrangler.jsonc` (`vars`) and, for the
Facebook app secret, `wrangler secret put FACEBOOK_APP_SECRET`. A provider with no
configuration answers `503 NOT_CONFIGURED`.

Sign-in is optional throughout: the guest path is always offered, and cooking never requires
an account.

---

## Local development

### Prerequisites

```bash
flutter --version          # 3.47.6 / Dart 3.13.5
xcodebuild -version        # Xcode 27.0
export JAVA_HOME=/opt/homebrew/opt/openjdk@21   # Android builds only
```

`openjdk@21` is keg-only, so `JAVA_HOME` must be set explicitly or Gradle cannot start. Add
it to `~/.zshrc` to avoid repeating it.

### Run the API

```bash
pnpm --filter @siti-counter/api dev     # http://127.0.0.1:8787
node scripts/seed-demo.mjs              # optional demo household
```

The seed pushes real data through `POST /v1/sync` and verifies the display feed, including
that an unchanged ETag returns 304.

### Point the app at the local API

```bash
# iOS simulator reaches the host loopback directly
flutter run --dart-define=DEVICE_ID=demo-seed-device

# Android emulator reaches the host at 10.0.2.2; the default already handles this
```

`defaultApiBaseUrl()` resolves `http://127.0.0.1:8787` on iOS and `http://10.0.2.2:8787` on
Android. Override for a physical device:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8787
```

`DEVICE_ID` must match the one used by the seed script, otherwise the app creates a different
guest household and the widgets appear empty.

Cleartext HTTP is enabled in the **debug** manifest only, for the local worker. The main
manifest stays TLS-only.

### Builds

```bash
flutter build apk --debug
flutter build ios --simulator --debug -d <simulator-udid>
```

`flutter build ios --simulator` without `-d` fails on Flutter 3.47.6: the generic
multi-architecture destination trips a `lipo` incompatibility with Xcode 27. Building against
a specific simulator works.

---

## Tests

```bash
flutter test                      # widget + unit
flutter analyze                   # should report 0 errors, 0 warnings
```

Tests use `sqflite_common_ffi`. Note that each test needs its **own** database file:
`inMemoryDatabasePath` is a single shared database under the ffi factory, so tests leak state
into each other and concurrent opens can deadlock. See `test/household_settings_test.dart`
for the pattern.

Real SQLite I/O never completes inside `testWidgets`' fake-async zone, so widget tests drive
interfaces (`HouseholdSettings`) rather than the SQLite implementations. The repositories are
covered by data-layer tests instead.
