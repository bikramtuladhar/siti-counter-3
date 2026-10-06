# Error tracking and performance metrics

## What is set up

| Concern | Choice | Cost |
|---|---|---|
| Crashes and unhandled errors | Sentry Flutter SDK (`sentry_flutter`) | Free tier, metered |
| Performance units (traces) | Sentry, sampled at 20% | Draws from the same free quota |
| Frame timing and jank | Computed on-device (`lib/telemetry/frame_metrics.dart`) | Free, uncapped, no vendor |
| Step timing (cold start, screen loads) | Computed on-device (`StopwatchMetrics`) | Free, uncapped, no vendor |
| Crash-free sessions | Existing self-hosted `/v1/telemetry/session` | Already yours |

The frame metrics are the genuinely free signal. Flutter's engine already measures how long each
frame took to build and raster, so reading it costs nothing and ships nothing off the device.
Sentry forwards a *sample* of it for trend visibility; the number has to be computed somewhere
either way.

## Privacy: this is the part to read

Siti Counter stores who lives in the household, what each person is allergic to, what they ate,
and free-text recipe and meal notes. That is health data about identifiable people. A crash
report is not an appropriate place for any of it, and error trackers are exactly the place where
it leaks — through breadcrumbs, through a context attached to a caught error, through a
request body that happened to be on the stack.

So the position is:

- **`sendDefaultPii` is off.** The SDK attaches device identifiers automatically; we do not let it.
- **Every event is scrubbed before it is sent**, unconditionally, by
  `lib/telemetry/event_scrubber.dart` installed as `beforeSend` and `beforeBreadcrumb`.
- **Identity is removed entirely.** An anonymous crash-free count is useful; an identified one
  is a disclosure.
- **Request bodies, cookies and headers are dropped**, and query strings are stripped from URLs,
  because ids get smuggled in query strings.
- **A key holding a whole roster is dropped whole.** A list of household members where only the
  names are redacted is still a list of people.

Scrubbing is a code path with tests, not a configuration setting, because configuration-based
filtering only covers the fields someone thought of. `test/event_scrubber_test.dart` includes a
check that no known-sensitive value survives anywhere in a serialised event.

If you add a new feature that records something sensitive, add it to `piiKeyFragments` and add a
test. The fragment match is deliberately broad and substring-based, so `memberNameEn` and
`severeAllergensNe` are caught without enumerating every locale-specific variant.

## Enabling it

The DSN is never committed. It arrives at build time:

```bash
flutter build apk \
  --dart-define=SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0 \
  --dart-define=SENTRY_ENVIRONMENT=production \
  --dart-define=SENTRY_RELEASE=$(git rev-parse --short HEAD)
```

Without `SENTRY_DSN` the app installs the error hooks and the frame collector but sends nothing.
A contributor's machine and a local build are therefore silent by default, and a test run cannot
leak anything either.

## What "free" actually means

Stated plainly, because these tiers change:

- **Sentry's developer plan is free with a monthly quota** on errors and on performance units.
  Going over bills; it does not quietly degrade. Current figures are in Sentry's pricing page and
  should be checked before a release, not assumed.
- **The free tier is metered, not unlimited.** For an app this size the error volume should sit
  far below it, but a bad release that loops will burn quota quickly. `errorSampleRate` and
  `tracesSampleRate` exist to bound that; errors are sampled at 100% on purpose, because a
  suppressed crash is worse than a metered one.
- **Self-hosting is the only uncapped option** (Sentry, or the open-source GlitchTip, which is
  API-compatible). That trades quota risk for operational cost, which is not obviously a win for
  one app.
- **Truly unlimited and vendorless** is the on-device frame and step timing. If the quota ever
  becomes a problem, that is the signal that keeps working.

Alternatives considered and rejected:

- **Firebase Performance / Google Analytics** — free and capable, but sends a household's usage
  to Google, which is a materially worse privacy position for an app holding allergy data.
- **PostHog, Umami, Matomo** — good, privacy-respecting, generous free tiers, and PostHog's
  self-hosting is straightforward. Reasonable next step for *product* analytics; deliberately not
  added now, because error tracking with scrubbing is the need that is actually open.
- **Datadog / New Relic / Dynatrace** — real APM, paid tiers aimed well above this app's scale.

## Reading the numbers

```dart
final metrics = startFrameMetrics();
// later, e.g. on a diagnostics screen
metrics.toReport();
// {frames: 1204, slowFrames: 18, jankRatio: 0.0149,
//  medianFrameMs: 8.2, p95FrameMs: 31.4, worstFrameMs: 214.0}
```

`jankRatio` is the headline. Under about 1% is comfortable; sustained double digits means
something is rebuilding too much, and `p95FrameMs` against `medianFrameMs` says whether the cost
is a few heavy frames or everything being slow.

`StopwatchMetrics` keeps the **slowest** observation per step rather than an average, because a
single four-second cold start matters more than ten 200 ms ones and an average would hide it.