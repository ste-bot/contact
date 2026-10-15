# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos (native SwiftUI app, macOS 14+, Command Line Tools build, no Xcode)

## Users

Steven, a photographer culling his own shoots: Ricoh GR II/IIIx/IV and Leica M10 digital files plus lab film scans, kept on an external archive drive. Personal tool today; it may be shared with other photographers later, so nothing should depend on Steven's own folder habits.

## Job

Cull a shoot before anything goes into Lightroom. Open a shoot folder, see every frame laid out as a darkroom contact sheet, mark frames (select, star, reject) with keys or clicks, then Print Selects: files move into `Selects/` and `reject/` with star ratings written for Lightroom. Before CONTACT there was no culling step at all; everything was imported and culled in Lightroom.

## Mechanism

The contact sheet is the interface. Folders become rolls (lab rolls by filename, digital folders split into 36-frame rolls), shown as film strips on proof paper with per-camera edge printing, and marked with drawn grease-pencil strokes. Nothing is deleted; printing can be undone.

## Constraints

- Inputs: DNG, JPEG, TIFF. Must cope with a messy exFAT archive: `:` in folder names, trailing spaces, repeated filenames (identity is the relative path).
- Marks are saved beside the shoot in `.contact.json`; the archive is never written to except by Print Selects.
- Keys: `S` select, `F` star, `X` reject, `⌫` clear, arrows to move, Space for the loupe, Return for full screen.
- Brand material uses the people-free demo shoot (`docs/Coastline - Sep 2026`), never a client's frames.

## Brand commitments

- Name: CONTACT. Mark: a box drawn in wax pencil, shared as path data in `Resources/Brand/wax-box.json`; the wordmark is typeset Archivo ExtraCondensed Black beside it, never with the box standing in for a letter.
- No handwriting typeface; the drawn marks are the only handwriting.
- Colour: black and white. Red belongs to the pencil marks only; no red buttons or fields.
- Direction: brutalist, bold, editorial (Magnum Contact Sheets, A24, Analogue, Swiss catalogue layouts). No glow, gradients-as-decoration or rounded softness.

## Decided

- The contact sheet uses the Catalogue style (roll headers as catalogue entries on proof paper), chosen after comparing Proof, Catalogue and Bench.
