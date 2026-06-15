# Testing — ClipCut

## Quick reference

| Command | What it runs |
|---|---|
| `make test` | Unit tests + UI tests |
| `make test-unit` | Unit tests only (faster, no UI launch) |

## Unit tests — `ClipCutTests`

Located in `ClipCutTests/ClipCutTests.swift`. Split into two classes:

### `SegmentTests`

Tests the `Segment` value type in isolation — no ffmpeg required.

| Test | What it checks |
|---|---|
| `testToSeconds_HHMMSS` | `01:02:03` → 3723 s |
| `testToSeconds_MMSS` | `02:07` → 127 s |
| `testToSeconds_seconds` | `42` → 42 s |
| `testToSeconds_invalid` | Non-numeric → `nil` |
| `testToSeconds_empty` | Empty string → `nil` |
| `testToSeconds_withWhitespace` | Leading/trailing spaces stripped |
| `testFromSeconds_zero` | 0 → `00:00:00` |
| `testFromSeconds_oneHour` | 3600 → `01:00:00` |
| `testFromSeconds_mixed` | 3723 → `01:02:03` |
| `testFromSeconds_roundtrip` | parse → format → original |
| `testIsValid_endAfterStart` | Valid segment passes |
| `testIsValid_endEqualStart_invalid` | Equal times → invalid |
| `testIsValid_endBeforeStart_invalid` | Reversed → invalid |
| `testIsValid_badTimecode_invalid` | Unparseable → invalid |

### `FFmpegRunnerTests`

Tests `FFmpegRunner` pure helpers. Tests that require ffmpeg skip gracefully
when ffmpeg is not installed (CI-safe).

| Test | What it checks |
|---|---|
| `testOutputPath_addsEditedSuffix` | `clip.mp4` → `clip-edited.mp4` |
| `testOutputPath_preservesDirectory` | Output stays in same directory |
| `testOutputPath_preservesExtension` | `.mov` stays `.mov` |
| `testBuildArguments_noSegments_throws` | Empty segments → `.noSegments` error |
| `testBuildArguments_invalidSegment_throws` | Bad segment → `.invalidSegment(0)` |
| `testBuildArguments_singleSegment_usesSSToo` | Single segment → `-ss`/`-to`, no filtergraph |
| `testBuildArguments_multiSegment_usesFilterComplex` | Multi-segment → `-filter_complex` |
| `testBuildArguments_outputIsLast` | Output path is the final argument |
| `testBuildArguments_containsCRF0` | `-crf 0` present (lossless quality) |

## UI tests — `ClipCutUITests`

| Test | What it checks |
|---|---|
| `testLaunch_showsDropZone` | "Drop a video file here" text visible on launch |
| `testLaunch_showsClipCutTitle` | "ClipCut" title visible |
| `testLaunch_showsBrowseButton` | Browse button visible |
| `testLaunchPerformance` | Launch time measurement |
