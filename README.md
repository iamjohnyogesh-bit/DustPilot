# DustPilot — macOS Cleanup Studio

Pick a folder. DustPilot lists files that are likely clutter. You choose what to remove, and it goes to the macOS Trash. Nothing is deleted permanently, nothing is uploaded, nothing is pre-selected.

## What it finds
| Category | Rule |
|---|---|
| Caches | Any file inside a folder named Caches, Cache, Code Cache, GPUCache or DerivedData (at any depth below the folder you chose) |
| Logs | `.log` files |
| Temporary | `.tmp`, `.temp`, `.bak`, `.old`, `.swp` |
| Large files | 250 MB or more |
| Old files | 50 MB or more and not modified for 365 days |
| Duplicates | Identical content (same size, hash, then byte-for-byte check), 1 MB or more. The oldest copy is kept and not listed; the newer copies are |

Results are review candidates, not a claim that a file is safe to delete.

## Features
- Native folder picker, local scan only, cancellable (a new scan stops the old one)
- Filter by category, search by name or path, sort by size, name or date
- Nothing pre-selected. "Move to Trash" only acts on items that are both selected and visible, and a confirmation shows the exact count and size
- Trash moves run in the background; one failure does not stop the rest, failures are listed
- Export the visible list as a CSV report (formula-safe) before you clean
- Skips hidden files, symlinks and app packages. Stops at 100,000 entries and says so when results are partial

## Requirements
macOS 14+, Swift 5.9+ (Xcode 15+ or Command Line Tools).

## Run, test, build
```bash
swift run                 # run from source
scripts/test.sh           # unit tests
scripts/build.sh          # build/DustPilot.app (ad-hoc signed; right-click > Open the first time)
```

## Layout
- `Sources/DustPilotCore` — scanner, rules, filtering, selection, trashing, CSV (Foundation only, unit-tested)
- `Sources/DustPilot` — SwiftUI app (ReviewWindow, CleanerStore) (macOS only)
- `Tests/DustPilotCoreTests` — 15 tests

## Verification status
The core logic is built and its 15 tests pass on Linux (Swift 5.10.1). The SwiftUI app target and the real `FileManager.trashItem` call only compile on macOS and have **not** been built or run yet. CI (`.github/workflows/ci.yml`) builds and tests on macOS 14 on every push; check that first.

## Not included
Whole-disk scan, system-managed caches, automatic cleaning, a signed/notarized release, auto-update.

## License
MIT, see `LICENSE`.
