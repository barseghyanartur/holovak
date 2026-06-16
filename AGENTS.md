# AGENTS.md — Holovak

**Repository**: https://github.com/barseghyanartur/holovak
**Maintainer**: Artur Barseghyan <artur.barseghyan@gmail.com>

---

## 1. Project mission

> A minimal macOS desktop application for trimming video files by specifying
> keep-segments (whitelisted time ranges). It delegates all video processing
> to `ffmpeg`, which must be installed separately (e.g. via Homebrew).

Key constraints that must never be violated:

- **No third-party Swift dependencies.** Only Apple frameworks (`SwiftUI`,
  `Foundation`, `AppKit`, `UniformTypeIdentifiers`).
- **No bundled ffmpeg.** The app discovers ffmpeg at known Homebrew paths and
  refuses gracefully if absent.
- **Swift 5 / macOS 13.1+.** Do not use APIs that require a higher deployment
  target without gating with `#available`.
- **No network access at runtime.**

---

## 2. Repository layout

```
HoloVak/
    HoloVakApp.swift          # @main entry point
    ContentView.swift         # Root SwiftUI view (drop zone + editor)
    SegmentRow.swift          # Per-segment row (timecode fields + delete)
    Segment.swift             # Value type: start/end timecodes + parsing
    FFmpegRunner.swift        # ffmpeg discovery, arg builder, Process runner
    HoloVakViewModel.swift    # ObservableObject: state + export orchestration
    Info.plist                # Injects $(MARKETING_VERSION) as AppVersion
    Assets.xcassets/          # App icon

HoloVakTests/
    HoloVakTests.swift        # Unit tests for Segment and FFmpegRunner

HoloVakUITests/
    HoloVakUITests.swift      # Basic launch + UI state assertions

HoloVak.xcodeproj/            # Xcode project; do not hand-edit project.pbxproj
Makefile                      # Full build/test/release pipeline
CHANGELOG.rst
README.rst
TESTING.md
```

---

## 3. Architecture

### 3.1 Data flow

```
User drops/opens file
  └─ ContentView → HoloVakViewModel.loadFile(_:)
       ├─ ffprobe → duration displayed in file header
       └─ segments list reset to one blank row

User edits segments
  └─ SegmentRow binds to $vm.segments[i]
       └─ Segment.isValid computed live (shows ✓ or ✗)

User taps Export (⌘↩)
  └─ HoloVakViewModel.export()
       ├─ FFmpegRunner.buildArguments(...)  — pure, testable
       └─ FFmpegRunner.run(...)             — Process + Pipe, streams log
            └─ exportState → .done(url) or .failed(msg)
```

### 3.2 Symbol map

| Symbol | Kind | Responsibility |
|---|---|---|
| `Segment` | `struct` | Timecode pair + `toSeconds` / `fromSeconds` / `isValid` |
| `FFmpegRunner` | `enum` (namespace) | `ffmpegPath()`, `outputPath()`, `buildArguments()`, `run()` |
| `FFmpegError` | `enum` | Typed errors surfaced in the UI |
| `HoloVakViewModel` | `@MainActor class` | All mutable state; orchestrates export |
| `ContentView` | `View` | Drop zone OR editor panel based on `vm.inputURL` |
| `SegmentRow` | `View` | One row: index, start field, arrow, end field, valid badge, delete |

### 3.3 ffmpeg invocation strategy

- **Single segment** → `-ss <start> -to <end>` (no filtergraph; faster seek)
- **Multiple segments** → `-filter_complex` with `trim`/`atrim` + `concat`
- Always re-encodes with `-c:v libx264 -crf 0 -preset ultrafast` (lossless
  quality H.264) because stream-copy is incompatible with filtergraph concat.

### 3.4 ffmpeg / ffprobe discovery

Checked in order:
1. `/opt/homebrew/bin/` (Apple Silicon Homebrew)
2. `/usr/local/bin/` (Intel Homebrew)
3. `/usr/bin/`

No `PATH` lookup — deterministic, sandbox-safe.

---

## 4. Build, test, and release

All common operations are wrapped in `make` targets. Run `make help` for the
full list.

| Command | What it does |
|---|---|
| `make build` | Compile Debug build (smoke-check) |
| `make test` | Run unit + UI tests |
| `make test-unit` | Run unit tests only (faster) |
| `make release` | Full release pipeline |
| `make bump V=0.2.0` | Update `MARKETING_VERSION` in the project file |
| `make clean` | Remove all generated artefacts under `Releases/` |
| `make open` | Open in Xcode |

**Deployment target**: `MACOSX_DEPLOYMENT_TARGET = 13.1` (macOS Ventura).
Any new API requiring 14+ must be wrapped in `if #available(macOS 14, *) {}`.

---

## 5. Key behaviours and invariants

1. `FFmpegRunner.buildArguments` is a **pure function** — no side effects,
   fully unit-testable without a real file or ffmpeg installed.
2. `Segment.isValid` is `false` when either timecode fails to parse or
   `end ≤ start`. The UI reflects this live with a ✓/✗ badge.
3. `HoloVakViewModel.canExport` requires `inputURL != nil` AND all segments
   valid AND `exportState != .running`. The Export button is disabled otherwise.
4. The output path is always `<input-stem>-edited.<ext>` in the same directory
   as the input. No user prompt — keep it simple.
5. Log output is streamed line-by-line from the ffmpeg process to `vm.log`
   and shown in a collapsible panel.

---

## 6. Coding conventions

- **Swift 5**, SwiftUI-first, AppKit only where SwiftUI is insufficient.
- No force-unwraps on values that can legitimately be absent. Use `guard let`.
- `@MainActor` on `HoloVakViewModel` — all UI updates happen on the main thread.
- `FFmpegRunner` methods that touch the filesystem or spawn processes are
  clearly separated from `buildArguments`, which is pure and tested.
- Comment style: `// TODO:` for known gaps, never silent omissions.
- `MARKETING_VERSION` in `project.pbxproj` is the single version source of
  truth; injected into `Info.plist` as `AppVersion`.

---

## 7. Forbidden

- Do not add any Swift Package Manager dependency or CocoaPods Podfile.
- Do not raise the deployment target above 13.1 without updating README and
  CHANGELOG.
- Do not bundle or download ffmpeg — the user must install it separately.
- Do not hand-edit `HoloVak.xcodeproj/project.pbxproj`; use Xcode or
  `xcodebuild` settings overrides.
- Do not add outbound network calls.
