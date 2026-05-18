# AGENTS.md

Agent instructions for the Textream repository. See `CLAUDE.md` for a full architecture overview.

## Build commands

All `xcodebuild` commands run from the repo root; the project is at `Textream/Textream.xcodeproj`.

```bash
# macOS debug build
xcodebuild -project Textream/Textream.xcodeproj -scheme Textream -configuration Debug build

# iOS simulator build
xcodebuild -project Textream/Textream.xcodeproj -scheme TextreamiOS -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests (SpeechProgressMatcher tests only)
xcodebuild -project Textream/Textream.xcodeproj -scheme TextreamTests test \
  -destination 'platform=macOS'

# Release universal macOS DMG (arm64 + x86_64, output: Textream/build/release/Textream.dmg)
cd Textream && ./build.sh
```

Build artifacts land in `Textream/build/` which is gitignored. `DerivedData/` is also gitignored.

## Project layout

```
Textream/
├── Textream.xcodeproj
├── Textream/           # macOS app sources
│   └── Core/           # Shared logic (iOS + macOS)
├── TextreamiOS/        # iOS app sources
└── TextreamTests/      # XCTest target (SpeechProgressMatcherTests only)
```

Three targets exist: `Textream`, `TextreamiOS`, `TextreamTests`.  
CLAUDE.md incorrectly states no XCTest target exists — `TextreamTests` is real and buildable.

## Shared core (`Textream/Textream/Core/`)

- `TeleprompterCore.swift` — data models (`TeleprompterMode`, `ScriptDocument`, `ReadingSessionState`)
- `TextSegmentation.swift` — word/token splitting, CJK-aware
- `SpeechProgressMatcher.swift` — fuzzy speech-to-char-offset matching (has unit tests)
- `ScriptDocumentStore.swift` — `.textream` JSON persistence; loads both structured and legacy page-array format; **always writes legacy format** for backward compatibility

## Key conventions

- **No SwiftPM, no CocoaPods** — pure Xcode project, no external dependencies.
- **macOS 15+ required** (Sequoia); Xcode 16+ required to build.
- **`.textream` files** are JSON. Loader is backward-compatible with both legacy `[String]` page arrays and the newer `ScriptDocument` structure. Do not change the write path to structured format without updating macOS compatibility.
- **Director Mode** has a connection cap and auth token — preserve those security controls when editing `DirectorServer.swift`.
- **Remote/Director ports**: Browser remote = 7373 (HTTP), Director = 7575 (HTTP) / 7576 (WebSocket = HTTP+1).
- AI features (`AIScriptService.swift`, `AIGenerateView.swift`, `AIPolishView.swift`, `AIScenario.swift`) exist in both targets — not mentioned in CLAUDE.md or README but present in source.
- Practice/phonetic-tooltip features (`PracticeService`, `PhoneticTooltipService`, `SentenceLoopView`) are present in both targets.

## Release process

Releases trigger on `v*` tags pushed to `main`. CI (`.github/workflows/release.yml`):
1. Updates `MARKETING_VERSION` in `project.pbxproj` via `sed`.
2. Builds two DMGs: `Textream.dmg` (macOS 26 Tahoe) and `Textream-macos15.dmg` (macOS 15).
3. Publishes GitHub Release and updates Homebrew cask tap.

**Do not manually edit `MARKETING_VERSION` in `project.pbxproj`** — CI owns it.

## iOS device install script

`Textream/build-ios.sh` contains a hardcoded device ID/UDID and bundle ID specific to one developer's device. It is not a general-purpose script — do not rely on it in CI or agent workflows.
