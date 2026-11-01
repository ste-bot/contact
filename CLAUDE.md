# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

CONTACT is a personal macOS app (SwiftUI + ImageIO, macOS 14+) for culling a photo shoot on a darkroom-style contact sheet before Lightroom. The product spec is in `SPEC.md`, product constraints in `PRODUCT.md`, and the visual system in `DESIGN.md`. Read the relevant one before changing behaviour or UI.

## Commands

The build needs only the Command Line Tools: no Xcode, XCTest or Swift Testing. Ignore the `xcrun: error: unable to lookup item 'PlatformPath'` lines in build output; they're noise.

```bash
swift build                                      # debug build
swift run ProofPositive "<shoot folder>"         # run the app directly, opening a shoot
./scripts/build-app.sh                           # release → build/Contact.app (fonts, brand mark, icon, ad-hoc signed)
./scripts/install-app.sh                         # build + replace /Applications/Contact.app
swift run ProofChecks                            # headless core checks against a temp folder; exits non-zero on failure
swift run ProofChecks --scan "<shoot folder>"    # read-only: how a real shoot lays out into rolls
```

There's no single-test runner. `ProofChecks` (`Sources/ProofChecks/main.swift`) is one script of `check(...)` calls in sections, and new core checks go there. Ratings checks need exiftool at `/usr/local/bin/exiftool`.

### UI self-check

The app can drive itself and snapshot its own window without Screen Recording permission (`Sources/ProofPositive/SelfCheck.swift` documents every step):

```bash
PROOF_SELFCHECK=/tmp/out PROOF_STEPS="wait:2;mark:3:select;snap:marked;quit" .build/debug/ProofPositive "<shoot>"
```

With no folder argument it starts at the launch index. The bare debug binary keeps its own `UserDefaults` domain (`ProofPositive`), separate from the installed app's `com.stevenchen.contact`, so tests can rewrite recents without touching real ones. `/tmp` paths come back as `/tmp/...`, not `/private/tmp/...`, because the scanner resolves symlinks. Use `docs/Coastline - Sep 2026` (the people-free demo shoot) for test data and brand material, never client frames.

## Architecture

Three targets in `Package.swift`:

- **ProofCore**: all logic, no UI, so `ProofChecks` can check it headless.
  - `ShootScanner` walks a shoot folder into `Shoot` → `Roll`s → `Frame`s. Lab rolls come from filename patterns (`LabNaming`); digital folders are split into 36-frame rolls by capture time; RAW+JPEG pairs become one frame. It also builds the cheap `ShootSummary` for the launch screen.
  - A frame's identity is its **path relative to the shoot root**, never its filename. `Selects/` and `reject/` at the root are read back as committed state and mapped to their original subpaths, so a printed shoot reopens with every frame in its original roll.
  - `ShootDocument` is the hidden `.contact.json` at the shoot root (legacy `.proofpositive.json` is still read). It holds working `marks`, `printed` (what disk reflects), `previousPrinted` (for Undo Print), stocks and location. `reconcile(with:)` rebuilds marks from disk if the file is lost.
  - `Printer` plans and runs the commit: it moves files between `<sub>/`, `Selects/<sub>/` and `reject/<sub>/` and writes ratings via exiftool (★ = 5, ◯ = 3). It plans from the difference between the target and `printed`, so a re-print moves only what changed and Undo is just a plan back to `previousPrinted`. Nothing is ever deleted.
  - `ShootLocation` resolves where a recent shoot is now. A bookmark follows a folder renamed or moved on the same drive, and it tells *drive not connected* (`/Volumes/<name>` missing) apart from *moved or renamed*.
- **ProofPositive**: the SwiftUI app (the executable keeps its old name; the product is Contact).
  - `AppModel.shared` is the app-wide state: the open `ShootModel`, the loading progress and the recents (paths plus bookmarks in `UserDefaults`, rechecked when the app activates or a drive mounts). Opening a missing recent goes to `locate(_:)`.
  - `ShootModel` is per-shoot state: marks, focus, reprint, zoom, the loupe and full screen. It saves the document and runs print/undo.
  - `RootView` (in `LaunchView.swift`) switches between the launch index, `DevelopingView` (scan progress) and `ShootView` (the sheet). `SheetViews`/`SheetZoom` lay rolls out as flattened `SheetRow`s in a lazy stack; zoom is a native `NSScrollView` magnification.
  - `Theme` and `Catalogue` hold the design tokens and recurring pieces (`CatalogueLabel`, `CatalogueIndex`, `Hairline`, `CaptionGrid`). Reuse them rather than styling ad hoc.
- **ProofChecks**: the headless check executable described above.

## Constraints worth knowing

- The archive is never written to except by Print Selects. Marks live only in `.contact.json`.
- It has to cope with exFAT mess: `:` in folder names, trailing spaces, repeated filenames.
- Design rules from `PRODUCT.md`/`DESIGN.md`: black and white only, with red reserved for the grease-pencil marks (no red UI). No handwriting typeface. No glow, decorative gradients or rounded softness. The wordmark is typeset Archivo beside the wax-box mark (`Resources/Brand/wax-box.json`). Clicking a frame never marks it; only keys mark.
