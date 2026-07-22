# subtitle-glasses

Translate burned-in Finnish TV subtitles through Meta Ray-Ban glasses — Flutter, with a choice of Claude or Gemini (Vertex AI) as the translation backend.

Watching a show in Finnish, you tap **Capture subtitle** on your phone whenever an interesting line appears on screen. The glasses take a photo, and when you stop the session, all captured frames go to the chosen model in one batch — it reads the Finnish subtitles, deduplicates consecutive frames, translates them (currently into Russian), and shows a two-column phrase table. The last 10 sessions are kept on the device, each tagged with which model produced it and how long the translation took.

Ships to testers via TestFlight — every push to `main` builds, signs, and uploads automatically (see [CI/CD](#cicd)).

## Hardware & accounts

- Meta Ray-Ban glasses (developer preview of Meta's [Wearables Device Access Toolkit](https://wearables.developer.meta.com/))
- iPhone (iOS 17+) with the Meta AI app, **Developer Mode enabled** (Meta AI → Settings → Developer Mode)
- API credentials for whichever backend(s) you want to run locally — see [Configuration](#configuration)

## Setup

```bash
flutter config --enable-swift-package-manager   # once per machine
flutter pub get
cp .env.example .env                            # fill in real values, see below
flutter run --dart-define-from-file=.env        # physical device only — no simulator
```

iOS signing (local dev): open `ios/Runner.xcworkspace` in Xcode and set your team under Signing & Capabilities. Release-configuration signing (used by CI) is manual and lives in `ios/Flutter/Release.xcconfig` — don't let Xcode's automatic-signing UI touch it.

Android (not yet tested): needs a GitHub PAT with `read:packages` scope for Meta's Maven registry — set `GITHUB_TOKEN` or add `github_token=...` to `android/local.properties`.

## Configuration

API credentials are baked in at build time via `--dart-define`, not entered by users — every TestFlight install shares the app's own keys, so testers don't need their own Anthropic or Google accounts. `.env.example` documents the three variables (`ANTHROPIC_API_KEY`, `GOOGLE_BACKEND_URL`, `GOOGLE_BACKEND_API_KEY`); copy it to `.env` (gitignored) for local runs. CI reads the same names from GitHub repo secrets.

You only need the key(s) for whichever backend(s) you're testing — a translator whose credentials are missing throws a clear "not configured" error instead of failing silently.

## How it works

```
lib/
  models/        SubtitlePair, SessionRecord (JSON-serializable; records provider + elapsed time)
  services/
    glasses_service.dart               registration, camera permission, stream session,
                                       photo capture stack; works around several plugin bugs
    subtitle_translator.dart           shared interface both backends implement
    claude_translation_service.dart    batches captured JPEGs into one Claude Messages API
                                       call (claude-sonnet-5, thinking disabled)
    google_translation_service.dart    calls the project's own Cloud Function (below)
    translation_settings_service.dart  persists which backend the user picked
    session_history_service.dart       last 10 sessions via shared_preferences
  screens/       watch (capture flow), results (phrase table), history, settings

backend/
  google_function/  Cloud Function (Python) fronting Vertex AI Gemini — see below
```

Glasses access goes through [`meta_wearables_dat_flutter`](https://pub.dev/packages/meta_wearables_dat_flutter) (unofficial Flutter bridge over Meta's native DAT SDKs).

### Plugin quirks handled in `glasses_service.dart`

The bridge (v0.7.1) leaks native session state in several failure paths; the service layer compensates:

- a failed stream start leaves a half-created device session behind → always tear down before starting, retry once on `sessionAlreadyExists`
- an SDK-initiated stream stop (glasses folded, thermal, disconnect) leaves a stale texture id cached → same tear-down-first strategy; errors surface as snackbars
- the camera permission check throws whenever the glasses aren't actively connected → failed checks never downgrade a known grant; last known state is cached on disk
- registration/permission state can go stale after deep-link round-trips through Meta AI → re-read on every app-foreground transition
- camera permission is tied to registration (unpairing, or Meta AI's "Allow once" expiring, must drop the cached grant — otherwise the next connect skips the grant step and the camera silently fails)

### Google backend (`backend/google_function`)

A small, dedicated Cloud Function — not shared with any other project — that authenticates the app with a static `x-api-key` header and calls Gemini through Vertex AI server-side, so no Google credentials ever ship in the app binary. Currently on **`gemini-3.6-flash`** (see below for how we got there).

```
POST /   { "images": ["<base64 jpeg>", ...] }  ->  { "pairs": [{"finnish": "...", "russian": "..."}] }
```

Deploy (from `backend/google_function`, or the equivalent Cloud Console UI flow — inline editor, entry point `translate`):

```bash
gcloud functions deploy subtitle-translator \
  --gen2 --runtime=python312 --region=europe-north1 \
  --source=backend/google_function --entry-point=translate \
  --trigger-http --allow-unauthenticated \
  --memory=512Mi --timeout=120s \
  --set-env-vars=GCP_PROJECT=YOUR_PROJECT_ID,BACKEND_API_KEY=$(openssl rand -hex 24)
```

`--allow-unauthenticated` is correct here: it means no *Google* IAM login is required — the function's own API-key check is the real gate. The deploying service account needs the **Vertex AI User** role (renamed "Agent Platform User" in the Cloud Console UI, same underlying role) on the project. The Vertex region is hardcoded in `main.py` (`VERTEX_LOCATION`), not an env var — an earlier version read it from the environment and the Console-configured value silently drifted from the code's fallback default, wasting a test cycle; region is really an infrastructure decision, not per-deploy config.

**Model history, and why it matters for future changes:**
- Started on `gemini-2.5-flash` — fast (3–13s), but noticeably worse OCR accuracy than Claude on angled, glare-affected glasses photos.
- Tried `gemini-2.5-pro` for better accuracy — it **rejects `thinking_budget=0`** (only Flash-tier models could fully disable thinking at the time), so it always reasoned at its default depth: consistently ~21–23s per call. That extra time bought no measurable accuracy gain, ruling out "more reasoning" as the fix.
- Landed on Gemini 3-generation (`gemini-3-flash-preview`, then GA `gemini-3.6-flash`): **meaningfully better OCR**, at ~13s. The likely cause isn't reasoning at all — token counts in the logs show Gemini 3 spends roughly **4x more tokens per image** (~1100 vs ~270), pointing to higher default image resolution/detail as the real driver, not "smarter" thinking.
- `gemini-3.6-flash` replaced the `thinking_budget` (0–N) knob with a `thinking_level` enum (`minimal`/`low`/`medium`/`high`) and **errors if both are sent in the same request** — `_SUPPORTS_THINKING_BUDGET_ZERO` in `main.py` is an explicit allowlist for exactly this reason, not a substring match on "flash".

The Vertex client is built once per container and reused across warm invocations rather than reconstructed per request.

### Timing & logging

Every translation call is timed client-side (`Stopwatch` in `watch_screen.dart`) and logged via `dart:developer.log` (filter Xcode/`flutter run` console output for `subtitle_glasses.translation`). The duration and provider are also saved onto the `SessionRecord`, so History and Results show e.g. *"Google · 4.3s"* — handy for comparing backends without leaving the app. Server-side, the Cloud Function logs model-call duration and token counts per request to Cloud Logging.

There's no centralized/remote logging system beyond this, deliberately — see [Roadmap](#roadmap-ideas).

## CI/CD

`.github/workflows/testflight.yml` runs on every push to `main`: `flutter analyze` + `flutter test`, then a signed release archive uploaded straight to TestFlight. Build numbers are the GitHub Actions run number, so they always increase. Required repo secrets: `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_P8` (App Store Connect API), `DIST_CERT_P12_B64` + `DIST_CERT_PASSWORD` (distribution signing), `PROVISIONING_PROFILE_B64`, plus the three API credentials from [Configuration](#configuration).

Distribution is internal-only (TestFlight internal testers) — Meta's DAT SDK is developer-preview and its terms don't permit public distribution yet.

## Costs

Rough per-session (~15 captures) costs:
- **Claude Sonnet 5**: $0.05–0.15 (intro pricing through Aug 2026)
- **Gemini 3.6 Flash via Vertex AI**: ~$0.01–0.03, based on observed token usage in the logs (~1100 input tokens/image at ~$1.50/M, ~200 output tokens at ~$7.50/M) plus negligible Cloud Function cost at this volume — still cheap despite Gemini 3's higher per-image token cost than 2.5 Flash

Since credentials are shared across all testers, set a spend cap on both the Anthropic Console and GCP billing — a leaked build-time key is bounded by that cap, not by how many people install the app.

## Roadmap ideas

- Merged, deduplicated vocab log across sessions
- Auto-capture on a timer
- Configurable target language (Russian is hardcoded)
- Android build verification
- Remote crash/error reporting (Sentry or similar) if the tester pool grows beyond people who can hand you a console log directly
- Retry `VERTEX_LOCATION = "europe-west4"` now that `gemini-3.6-flash` is GA (the preview-tier model 404'd there; GA models are more likely to have broader regional rollout) — would remove the transatlantic-routing latency risk of `global` without another model swap
- Cloud Function cold-start mitigation (min instances) if Google-path latency is still a concern day-to-day
