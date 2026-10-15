# CONTACT — spec

A personal macOS app for culling a shoot on a darkroom-style contact sheet, before anything goes into Lightroom.

Name: **CONTACT** (menu bar, Dock, icon: **Contact**). Earlier working names: Darkroom, Proof Positive.

## Job

Culling tool first. The sheet *is* the interface; the output is a `Selects/` folder you import into Lightroom. Today there is no culling step at all — everything gets imported into LR and culled there. This app replaces that.

Out of scope for v1: exporting the sheet as an image, client proofing, ingesting cards, reorganising the archive (separate project), RAF/NEF.

## Input

- Formats: **DNG, JPEG, TIFF** (Ricoh GR II/IIIx/IV, Leica M10, lab film scans).
- You open a **shoot folder** (e.g. `/Volumes/Archive 1/Cancun - Mar 2024`) by File ▸ Open, drag onto the window/Dock icon, or from the recent-shoots list on launch.
- The app walks all subfolders. Skipped: `Web*`, `Export*`, `IG*`, `CaptureOne`, hidden files, `._*` AppleDouble junk, Capture One session files. `Selects/` and `reject/` at the shoot root are read back as committed state (below), not as new rolls.
- Must cope with the Archive 1 mess: exFAT, `:` in folder names, trailing spaces, filenames that repeat across folders (identity is the relative path, never the filename).

## Rolls

Every subfolder with images becomes its own roll(s):

- **Lab roll folder** (no DNGs; filenames match a lab pattern) → exactly one roll. Frame numbers are parsed from the filename:
  - Frontier `000035020001.jpg` (8-digit roll + 4-digit frame)
  - Noritsu/EZ Controller `240928000032150001.tif` (18 digits, last 4 = frame)
  - Digital Link `R1-00012-0012.TIF` / `R1-00012-012A.TIF`
  - Canadian Film Lab `SC220622001151-01.jpg`
  - NCL `3854_000004.jpg`
  - plain `000001.JPG`
- **Digital folder** → split into **36-frame rolls** by capture time. Frame number = position in the roll (1–36). Roll number shown as `R01`, `R02`…
- **Ricoh RAW+JPEG pairs** are one frame — matched by basename in the same folder, or in a JPEG folder (`JPEG`, `JPEGs`, `Ricoh JPEG(s)`, `Camera JPEG(s)`) next to the raws. The camera JPEG is displayed; both files move together. Unpaired files are frames on their own.

### Format (from the roll's median aspect ratio)

| Aspect | Strip | Frames per strip |
|---|---|---|
| ≈1:1 | 120, no sprockets | 4 |
| ≈1.2–1.3 (6x7) | 120, no sprockets | 3 |
| ≈1.5 (35mm, digital, 6x9) | 35mm with sprockets | 6 |

### Sheet styling

- Cream paper, black strips, slight skew (< 0.5° on screen). Fixed page layout — the page scales to the window; pinch / ⌘+ / ⌘− zoom.
- Roll header, set like a catalogue entry: `R01` large, the shoot name on the right with `<Month YYYY>` beneath (from EXIF), then ruled columns: Folder (the shoot folder when the roll sits at its root), Location (typed inline, once per shoot; clicking selects the current text, Esc cancels), Format, Frames, and Stock (lab rolls, typed inline) or Camera (digital).
- Edge printing: `R01`, frame numbers `12 ▶` and `12A` in a condensed face.
  - Digital: camera model + ISO from EXIF (`RICOH GR IV · ISO 800`).
  - Film: `FILM · SAFETY FILM`, where `FILM` is an editable per-roll stock name.
- Verticals sit **sideways** in landscape frames (as on real film); upright in the loupe and full-screen view. View ▸ Upright Verticals toggles it on the sheet.
- B&W styling (white edge print instead of orange) when every frame in the roll is monochrome (detected from pixels — lab B&W scans are RGB files).

## Marking

Four states: **★ hero**, **◯ select**, unmarked (= out), **✕ reject**. Drawn in safelight red as hand-made grease-pencil strokes.

| Input | Action |
|---|---|
| Hover | the frame under the cursor takes the focus ring; the marking keys act on it |
| Click | puts the focus ring on a frame; never marks |
| Arrow keys | move the focus ring (←/→ frame, ↑/↓ strip) |
| `S` / `F` / `X` | toggle ◯ select / ★ star / ✕ reject on the focused frame |
| `Delete` | clear |
| Hold `Space` | loupe — circular magnifier under the cursor, upright |
| `Return`, double-click or ⌘-click | full-screen view; arrows step, same marking keys, `Esc` or ‹ returns to the sheet |

**Reprint** (View ▸ Reprint Circled): the sheet re-lays only ◯/★ frames on fresh strips, keeping the original roll/frame numbers in the edge printing — for a second pass that narrows selects to heroes.

## Persistence

Marks, per-roll stock names and location live in a hidden `.contact.json` (older folders: `.proofpositive.json`, still read) at the shoot root, so reopening the folder (from any Mac) restores them. Thumbnails are cached in `~/Library/Caches/ProofPositive`, keyed by path + size + modification date.

## Print Selects (commit)

Nothing moves while marking. One explicit action, **Print Selects** (⌘P):

- ◯/★ frames move to `Shoot/Selects/<original subpath>/`, ✕ frames to `Shoot/reject/<original subpath>/`, unmarked frames stay (or return) to `Shoot/<original subpath>/`. Mirroring the subpath means lab files named `000001.JPG` never collide.
- Star ratings are written into the files in `Selects/` (★ = 5, ◯ = 3) via exiftool, which Lightroom reads on import. Files leaving `Selects/` have the rating cleared. Originals that never enter `Selects/` are never written to.
- Nothing is ever deleted.
- Shows a summary: `28 selects · 4 heroes · 61 rejects`.
- **Undo Print** moves everything back to how it was before the last print. Your marks stay.
- Reopening a printed shoot shows every frame in its original roll and position, with marks restored. Re-printing after changing marks moves only what changed.

Then in Lightroom: import `Shoot/Selects` (Add, include subfolders) and filter by 5★ for heroes.

## Build

- Native SwiftUI + ImageIO, macOS 14+, non-sandboxed, ad-hoc signed, built locally.
- Swift Package (`swift build`) + `scripts/build-app.sh`, which wraps the binary into `build/Contact.app`. Full Xcode isn't required.
- `swift run ProofChecks` runs the core-logic checks (lab filename parsing, scanning, pairing, commit/undo against a temp folder).
- Lab deliveries live in folders like `Export TIFF 16Base` — those are scans, not your exports, so they're read; a `NoResize` duplicate of the same roll is skipped.

Designed for shoots up to ~3,000 frames.
