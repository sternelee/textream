# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and run

- Open project in Xcode:
  ```bash
  open Textream/Textream.xcodeproj
  ```
- List schemes/targets:
  ```bash
  xcodebuild -project Textream/Textream.xcodeproj -list
  ```
- Build macOS app from CLI:
  ```bash
  xcodebuild -project Textream/Textream.xcodeproj -scheme Textream -configuration Debug build
  ```
- Build iOS app from CLI:
  ```bash
  xcodebuild -project Textream/Textream.xcodeproj -scheme TextreamiOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
  ```
- Create release macOS universal app + DMG:
  ```bash
  ./Textream/build.sh
  ```

## Tests and validation

- No dedicated XCTest target exists now. `xcodebuild -list` shows only app targets: `Textream`, `TextreamiOS`.
- Main validation path is building both schemes successfully.
- If you need narrow validation, build single scheme you touched:
  ```bash
  xcodebuild -project Textream/Textream.xcodeproj -scheme Textream build
  xcodebuild -project Textream/Textream.xcodeproj -scheme TextreamiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
  ```

## Release automation

- GitHub Actions release pipeline lives in `.github/workflows/release.yml`.
- Releases trigger on pushed `v*` tags.
- CI updates marketing version in `Textream/Textream.xcodeproj/project.pbxproj`, runs `./Textream/build.sh`, and uploads DMGs.

## Architecture

### Product split

Repo contains 2 app shells in single Xcode project:
- `Textream` — macOS app
- `TextreamiOS` — iOS app

They share teleprompter domain logic under `Textream/Textream/Core/`.

### Big picture flow

Core product loop: user edits script → app segments text into words → speech recognition advances highlighted position → teleprompter renders current progress in overlay/reader UI → optional remote/director clients receive mirrored state over network.

### macOS app structure

- `Textream/Textream/TextreamApp.swift`
  - App entry point.
  - Configures app lifecycle, URL/file open handling, update check, browser server, director server.
  - App can launch as accessory app for URL-driven external control.
- `Textream/Textream/ContentView.swift`
  - Main macOS editor and control surface.
  - Talks to singleton `TextreamService.shared`.
- `Textream/Textream/TextreamService.swift`
  - Central macOS orchestration layer.
  - Owns page state, overlay presentation, external display mirroring, browser server, director server, file open/save, reading progress.
  - If macOS behavior spans multiple surfaces, start here.
- `Textream/Textream/NotchOverlayController.swift`
  - Manages notch/floating/fullscreen teleprompter presentation.
- `Textream/Textream/ExternalDisplayController.swift`
  - Mirrors teleprompter output to Sidecar/external displays.
- `Textream/Textream/SpeechRecognizer.swift`
  - On-device speech recognition engine feeding progress/highlighting.
- `Textream/Textream/MarqueeTextView.swift`
  - Word-flow teleprompter rendering and highlight behavior.

### iOS app structure

- `Textream/TextreamiOS/TextreamiOSApp.swift`
  - iOS app entry point.
  - Holds single `IOSTeleprompterModel` instance at app root.
- `Textream/TextreamiOS/IOSHomeView.swift`
  - Main iOS editing/navigation shell.
- `Textream/TextreamiOS/IOSTeleprompterModel.swift`
  - Main iOS state/model object using `@Observable`.
  - Owns document, reading session, word tracker, audio monitor, document library, persisted reader preferences.
- `Textream/TextreamiOS/IOSReaderView.swift`
  - Full-screen reader experience.
- `Textream/TextreamiOS/IOSWordTrackingRecognizer.swift`
  - iOS speech-tracking side.

### Shared core

Shared logic under `Textream/Textream/Core/` is intended to keep iOS/macOS behavior aligned:

- `TeleprompterCore.swift`
  - Shared data models such as `TeleprompterMode`, `ScriptDocument`, `ReadingSessionState`.
  - `ScriptDocument` owns pagination/bookmark/read-progress semantics independent from UI.
- `TextSegmentation.swift`
  - Shared word/token splitting, including CJK-aware segmentation and annotation-word handling.
- `SpeechProgressMatcher.swift`
  - Shared fuzzy matcher converting recognized speech into character progress.
- `ScriptDocumentStore.swift`
  - `.textream` persistence layer.
  - Reads both structured `ScriptDocument` JSON and legacy `[String]` page-array format.
  - Writes legacy page-array format for backward compatibility unless caller explicitly uses structured save.

### Persistence model

- `.textream` files are JSON-based.
- Current compatibility rule matters: loader accepts both structured document format and legacy page arrays; legacy writes remain intentional for macOS compatibility.
- iOS model persists drafts and reader settings aggressively via property observers.
- macOS service tracks reading progress separately and restores/clears it around overlay lifecycle.

### Remote control and networking

Two separate network surfaces exist on macOS:

- `Textream/Textream/BrowserServer.swift`
  - Serves built-in browser/remote teleprompter UI over HTTP + WebSocket.
  - Broadcasts teleprompter state such as words, highlighted char count, audio levels, active/done state.
- `Textream/Textream/DirectorServer.swift`
  - Director Mode protocol for external controller clients.
  - Accepts commands like `setText`, `updateText`, `stop` over WebSocket.
  - Broadcasts reading state at ~10 Hz.
  - Has explicit connection cap and auth token handling; preserve those security controls.

If change touches remote protocol, check README Director Mode section and server implementation together.

### URL-driven control

- App supports `textream://` URL handling through `TextreamService`.
- `TextreamApp.swift` changes app activation policy when launched from URL events.
- When editing deep-link behavior, verify both normal app launch and external/accessory launch paths.

## Repo-specific notes

- README build path assumes working from repo root: `open Textream/Textream.xcodeproj`.
- Ignore generated `build/` artifacts when searching code; repo often contains local Xcode build outputs.
- No Cursor rules, `.cursorrules`, or `.github/copilot-instructions.md` were present during initialization.
