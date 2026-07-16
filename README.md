# subtitle-glasses

Translate burned-in Finnish TV subtitles through Meta Ray-Ban glasses — Flutter + Claude vision API.

Watching a show in Finnish, you tap **Capture subtitle** on your phone whenever an interesting line appears on screen. The glasses take a photo, and when you stop the session, all captured frames go to Claude in one batch — it reads the Finnish subtitles, deduplicates consecutive frames, translates them (currently into Russian), and shows a two-column phrase table. The last 10 sessions are kept on the device.

## Hardware & accounts

- Meta Ray-Ban glasses (developer preview of Meta's [Wearables Device Access Toolkit](https://wearables.developer.meta.com/))
- iPhone (iOS 17+) with the Meta AI app, **Developer Mode enabled** (Meta AI → Settings → Developer Mode)
- An [Anthropic API key](https://console.anthropic.com) — entered in the app's Settings screen, stored in the Keychain, never in code

## Setup

```bash
flutter config --enable-swift-package-manager   # once per machine
flutter pub get
flutter run                                     # physical device only — no simulator
```

iOS signing: open `ios/Runner.xcworkspace` in Xcode and set your team under Signing & Capabilities.

Android (not yet tested): needs a GitHub PAT with `read:packages` scope for Meta's Maven registry — set `GITHUB_TOKEN` or add `github_token=...` to `android/local.properties`.

## How it works

```
lib/
  models/        SubtitlePair, SessionRecord (JSON-serializable)
  services/
    glasses_service.dart             registration, camera permission, stream session,
                                     photo capture stack; works around several plugin bugs
    claude_translation_service.dart  batches captured JPEGs into one Claude Messages API
                                     call (claude-sonnet-5, thinking disabled), parses the
                                     JSON table; chunks sessions >20 images
    session_history_service.dart     last 10 sessions via shared_preferences
    secure_storage_service.dart      API key in Keychain/Keystore
  screens/       watch (capture flow), results (phrase table), history, settings
```

Glasses access goes through [`meta_wearables_dat_flutter`](https://pub.dev/packages/meta_wearables_dat_flutter) (unofficial Flutter bridge over Meta's native DAT SDKs).

### Plugin quirks handled in `glasses_service.dart`

The bridge (v0.7.1) leaks native session state in several failure paths; the service layer compensates:

- a failed stream start leaves a half-created device session behind → always tear down before starting, retry once on `sessionAlreadyExists`
- an SDK-initiated stream stop (glasses folded, thermal, disconnect) leaves a stale texture id cached → same tear-down-first strategy; errors surface as snackbars
- the camera permission check throws whenever the glasses aren't actively connected → failed checks never downgrade a known grant; last known state is cached on disk
- registration/permission state can go stale after deep-link round-trips through Meta AI → re-read on every app-foreground transition

## Costs

A session of ~15 captures costs roughly $0.05–0.15 with Claude Sonnet 5 (intro pricing through Aug 2026). The model is a constant in `claude_translation_service.dart`.

## Roadmap ideas

- Merged, deduplicated vocab log across sessions
- Auto-capture on a timer
- Configurable target language (Russian is hardcoded)
- Android build verification
