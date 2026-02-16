# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GovAgent is a voice-first Flutter app for navigating Malaysian government portals. Users speak to a Gemini-powered AI agent that controls a browser on a separate backend via WebSocket. The Flutter client handles voice I/O and displays a live screenshot stream of the browser.

- Package name: `gov_agent`
- Dart SDK: >=3.11.0, Flutter 3.41.0+
- State management: Riverpod (`Notifier`/`NotifierProvider`)
- AI: Gemini Live API via `firebase_ai` (`LiveSession`)
- Audio capture: `record` (PCM 16-bit 16kHz mono)
- Audio playback: `flutter_soloud` (PCM 24kHz)
- Backend comms: `web_socket_channel` (JSON over WebSocket)

## Prerequisites

Before running the app you need:

1. **Flutter 3.41.0+** — verify with `flutter --version`
2. **Firebase project** — create one at [Firebase Console](https://console.firebase.google.com), enable the Gemini API under Firebase AI Logic
3. **Firebase config files** — these are NOT checked in (gitignored):
   - Android: download `google-services.json` → place in `android/app/`
   - iOS: download `GoogleService-Info.plist` → place in `ios/Runner/`
4. **Backend server** running (separate repo) — or the app will fall back to voice-only mode

## Common Commands

```bash
# Install dependencies (run after clone or pubspec changes)
flutter pub get

# Run the app (default device)
flutter run

# Run with custom backend URL and Gemini model
flutter run --dart-define=BACKEND_URL=ws://192.168.1.100:8080/ws \
            --dart-define=GEMINI_MODEL=gemini-2.0-flash-live-001

# Run on specific platforms
flutter run -d macos
flutter run -d chrome
flutter run -d ios

# Static analysis
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build
flutter build apk
flutter build ios
flutter build macos
flutter build web
```

## Architecture

### Entry Point & App Shell

- `lib/main.dart` — `WidgetsFlutterBinding`, Firebase init, wraps app in `ProviderScope`
- `lib/app.dart` — `MaterialApp` with dark theme, routes to `HomeScreen`

### Folder Structure

```
lib/
  config/         # App-wide constants and theming
  models/         # Plain data classes (no logic)
  services/       # Stateful wrappers around SDKs/connections (no Flutter/UI deps)
  providers/      # Riverpod notifiers that glue services → UI state
  screens/        # Full-page widgets (HomeScreen, SessionScreen)
  widgets/        # Reusable UI components
```

### Data Flow

```
User speaks → AudioCaptureService (PCM 16kHz) → GeminiLiveService (firebase_ai LiveSession)
                                                       ↓
                                                 Gemini responds:
                                                 ├─ Audio chunks → AudioPlaybackService → speaker
                                                 ├─ Tool calls → BackendWebSocketService → backend
                                                 │                  ↓ tool results → back to Gemini
                                                 │                  ↓ screenshots → BrowserStreamProvider → UI
                                                 └─ Transcription → TranscriptProvider → UI
```

### Key Files

| File | Purpose |
|------|---------|
| `services/gemini_live_service.dart` | Wraps `firebase_ai` `LiveSession`. Connects, streams audio, parses tool calls. Uses `receive()` async stream. |
| `services/audio_capture_service.dart` | Mic → PCM stream via `record` package. |
| `services/audio_playback_service.dart` | Plays PCM from Gemini via `flutter_soloud`. Wraps raw PCM in a WAV header on the fly. |
| `services/backend_websocket_service.dart` | JSON WebSocket to backend. Sends tool calls, receives screenshots (base64 JPEG) and tool results. |
| `providers/gemini_session_provider.dart` | The orchestrator. Wires all services together, manages session lifecycle (idle → connecting → active → error). |
| `screens/session_screen.dart` | Core UI: browser viewer, mic button, status overlay, transcript sheet. |

### Models

- `SessionState` — enum: `idle`, `connecting`, `active`, `error`
- `ToolCall` — parsed Gemini function call with `requiresConfirmation` flag (true for `submit_form`)
- `BrowserFrame` — screenshot `Uint8List` + action label
- `TranscriptEntry` — speaker enum + text + timestamp

## Configuration

Runtime config is injected via `--dart-define` and read in `lib/config/app_config.dart`:

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKEND_URL` | `ws://localhost:8080/ws` | WebSocket URL of the browser automation backend |
| `GEMINI_MODEL` | `gemini-2.0-flash-live-001` | Gemini model ID for the live session |

## Why firebase_ai?

We need the **Gemini Live API** — the bidirectional streaming API where you send real-time audio and get real-time audio + tool calls back over a persistent WebSocket. This is not the normal Gemini chat/generate API.

**Options considered:**

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| `firebase_ai` (current) | First-party Flutter SDK. Handles the WebSocket protocol, audio framing, tool call parsing, auth via Firebase. One `connect()` call and you get a `LiveSession`. | Still in "Preview" — API may break on minor upgrades. Requires Firebase project setup. | **Chosen.** Fastest path for a hackathon. The SDK does the hard protocol work for us. |
| Raw `web_socket_channel` to Gemini API | No Firebase dependency. Full control over the wire protocol. | You have to implement the entire Gemini Live WebSocket protocol yourself: session setup messages, audio chunking format, tool call parsing, reconnection logic. Weeks of work for what `firebase_ai` gives you in one call. | Fallback only if `firebase_ai` breaks. |
| `google_generative_ai` (Dart SDK) | Official Google package. | Does NOT support the Live/streaming bidirectional API. Only supports request-response chat. Can't do real-time voice. | Not viable. |
| Proxy through our backend | Could use any server-side Gemini SDK. | Adds a network hop for audio (latency killer for voice). Backend team would need to handle audio streaming. Defeats the point of a client-side voice loop. | Bad for real-time voice. |

**Bottom line:** `firebase_ai` is the only Flutter package that supports Gemini Live out of the box. The Preview risk is real, but for a hackathon with a Feb 28 deadline it's the right tradeoff. If the SDK breaks, the fallback is reimplementing the WebSocket protocol manually using `web_socket_channel` (the plumbing in `gemini_live_service.dart` is isolated enough to swap).

## Gotchas & Known Issues

### Firebase
- `Firebase.initializeApp()` in `main.dart` is wrapped in a try-catch. If Firebase isn't configured, the app runs in UI-only mode (`firebaseInitialized = false`). `GeminiLiveService.connect()` checks this flag and throws a descriptive error instead of crashing.
- **Android build requires the Google Services Gradle plugin** (`com.google.gms.google-services`) in both `android/settings.gradle.kts` (declaration) and `android/app/build.gradle.kts` (application). Without it, the Gradle build fails even if `google-services.json` exists.
- **`android/app/google-services.json` must exist** for the Android build to pass. A dummy placeholder is checked in for development. Replace it with the real file from Firebase Console when you set up a Firebase project. The `package_name` inside it must match the `applicationId` in `build.gradle.kts` (`com.example.gov_agent`).
- `firebase_ai` `LiveSession` is still in Preview. The API surface may change across minor versions. If you upgrade `firebase_ai`, re-check `gemini_live_service.dart` — specifically `receive()`, `sendAudioRealtime()`, and the `LiveServerContent`/`LiveServerToolCall` message types.

### Audio
- `flutter_soloud` requires native compilation — it won't work in `flutter test` or on web. Tests that touch `AudioPlaybackService` need mocking.
- `record` package needs a real device or simulator with mic access. Emulators without mic support will throw.
- **`record_linux` version mismatch** — `record 5.x` can pull in an old `record_linux` that's incompatible with `record_platform_interface`. Dart compiles all platform implementations even when targeting Android, so this breaks the build. Fixed via `dependency_overrides: record_linux: ^1.3.0` in `pubspec.yaml`. If you upgrade `record`, check that all federated platform packages resolve to compatible versions (`flutter pub deps | grep record`).
- Android `minSdk` is set to 24 (required by `record`). Don't lower it.

### Platform Permissions
- Android: `RECORD_AUDIO` and `INTERNET` are declared in `AndroidManifest.xml`. Runtime permission is handled by `permission_handler` in `PermissionService`.
- iOS: `NSMicrophoneUsageDescription` is set in `Info.plist`. If the string is missing, iOS will kill the app on mic access.

### Riverpod
- All providers use the manual `Notifier`/`NotifierProvider` pattern (no code generation). `riverpod_generator` and `build_runner` are in dev_dependencies for future use but nothing currently requires `build_runner`.
- `GeminiSessionNotifier` holds mutable service instances. It uses `ref.onDispose` for cleanup. Don't read it outside of widgets or other providers without understanding the lifecycle.

### Backend WebSocket Protocol
- The backend is optional. If it's not running, the app logs "Backend not available. Voice-only mode." and continues.
- Expected message format from backend:
  ```json
  {"type": "screenshot", "data": "<base64 JPEG>", "action": "Filling IC number..."}
  {"type": "tool_result", "id": "<tool_call_id>", "name": "<fn_name>", "result": {...}}
  ```
- Tool calls sent to backend:
  ```json
  {"type": "tool_call", "id": "<id>", "name": "fill_field", "args": {"selector": "...", "value": "..."}}
  ```

### Gemini Tool Declarations
Five tools are declared in `gemini_live_service.dart`: `open_page`, `fill_field`, `click_element`, `submit_form`, `read_page`. Only `submit_form` triggers a user confirmation dialog. If you add new tools, update both the `_tools` list and the backend's handler.

## What's Not Built Yet

These are known gaps — not bugs, just things that haven't been implemented:

- **Onboarding/tutorial** — no first-run experience
- **Auth UI** — `firebase_auth` is a dependency but there's no login screen or user account flow
- **Session history** — conversations aren't persisted; closing the session loses everything
- **Reconnection** — if Gemini disconnects (network drop, 10-min session timeout), the app just shows error state with no way to recover other than going back and starting a new session
- **Settings screen** — no way to change backend URL or voice preference from within the app
- **Offline handling** — no detection or messaging for when the phone loses internet
- **Accessibility** — no semantic labels, screen reader support, or high-contrast mode

## Testing Notes

- `flutter test` runs widget tests only. The current smoke test verifies the home screen renders with ProviderScope.
- Services that depend on native plugins (`record`, `flutter_soloud`, `firebase_ai`) cannot be tested in unit tests without mocking. Use platform channels mocking or integration tests on a real device.
- For integration testing with the backend, run: `flutter run --dart-define=BACKEND_URL=ws://<backend-ip>:8080/ws`
