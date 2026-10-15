---
name: CONTACT
description: A darkroom contact sheet for culling a shoot, set like an exhibition catalogue's checklist.
colors:
  bench: "#1A1917"
  film: "#0D0C0B"
  paper: "#EFEBE3"
  ink: "#2A2724"
  ink-muted: "#6B6760"
  rule: "rgba(239, 235, 227, 0.14)"
  wax: "#F3F0E6"
  safelight: "#D72B1E"
  edge-color: "#E69A3B"
  edge-mono: "#E8E3D9"
typography:
  wordmark:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "104px"
    fontWeight: 900
    lineHeight: 1
    fontVariation: "'wdth' 62, 'wght' 900"
  display:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "96px"
    fontWeight: 300
    lineHeight: 1
    fontFeature: "'tnum' 1"
    fontVariation: "'wdth' 100, 'wght' 300"
  headline:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "40px"
    fontWeight: 380
    lineHeight: 1.1
    fontVariation: "'wdth' 100, 'wght' 380"
  title:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 420
    lineHeight: 1.2
    fontVariation: "'wdth' 100, 'wght' 420"
  body:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.35
    fontVariation: "'wdth' 100, 'wght' 400"
  typed:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "36px"
    fontWeight: 650
    lineHeight: 1.1
    fontVariation: "'wdth' 87, 'wght' 650"
  label:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "0.08em"
    fontVariation: "'wdth' 87, 'wght' 700"
  button:
    fontFamily: "Archivo, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 760
    lineHeight: 1
    letterSpacing: "0.06em"
    fontVariation: "'wdth' 87, 'wght' 760"
  mono:
    fontFamily: "Geist Mono, ui-monospace, monospace"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.3
    fontFeature: "'tnum' 1"
rounded:
  none: "0px"
  film: "2px"
spacing:
  xs: "6px"
  sm: "10px"
  md: "14px"
  lg: "28px"
  xl: "56px"
components:
  button-block:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.film}"
    typography: "{typography.button}"
    rounded: "{rounded.none}"
    padding: "13px 22px"
  button-block-hover:
    backgroundColor: "transparent"
    textColor: "{colors.paper}"
    rounded: "{rounded.none}"
  button-block-small:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.film}"
    rounded: "{rounded.none}"
    padding: "5px 12px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.paper}"
    rounded: "{rounded.none}"
    padding: "5px 12px"
  button-outline-hover:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.film}"
    rounded: "{rounded.none}"
  catalogue-label:
    textColor: "{colors.paper}"
    typography: "{typography.label}"
  catalogue-index:
    textColor: "{colors.paper}"
    typography: "{typography.mono}"
  caption-block:
    backgroundColor: "{colors.film}"
    textColor: "{colors.paper}"
    rounded: "{rounded.none}"
    padding: "20px 24px 22px"
    width: "340px"
  banner:
    backgroundColor: "{colors.film}"
    textColor: "{colors.paper}"
    rounded: "{rounded.none}"
    padding: "16px 22px"
---

# Design System: CONTACT

## Overview

**Creative North Star: "The Exhibition Checklist"**

CONTACT is a darkroom bench read as a catalogue. Every shoot, roll and frame is an indexed entry (`[01]`, `R01`, frame `3`) set in grotesk on one-pixel hairlines, with a label/value caption block beside it, the way a Swiss exhibition checklist or the A24 index lists its works. The photographs and the film they sit on are the only pictures; everything else is type, rules and flat black and paper.

The world is black and white: bench black and film black for grounds, cream proof paper and paper-white ink, hairlines of paper at 14%. The one hue is safelight red, and it belongs to the grease pencil. Density is generous at the edges (56pt margins) and tight inside a caption (6pt row spacing), so the eye moves between big light numerals and small tracked caps without middle sizes competing. The mood is brutalist, bold and editorial, after Magnum contact sheets, Swiss catalogue layouts and the A24 index; it rejects the category default of a rounded dark photo app with a thumbnail sidebar, pill buttons and an accent colour.

Motion carries no decoration. Hovering a row dims its siblings instantly; the launch preview crossfades in 200ms; a fresh mark draws on stroke by stroke like a real pencil. The contact sheet is set catalogue-style (see Components ▸ Sheet).

**Key Characteristics:**
- Black and white grounds; red only in grease-pencil marks.
- The catalogue checklist: bracketed mono indexes, caps labels, label/value caption grids, one-pixel hairlines.
- Archivo in three registers plus Geist Mono for data; SF Pro only inside native controls.
- Every UI edge square; one primary action per screen as a paper block.
- Flat: depth comes from black-on-black value steps and hairlines, not shadows.

## Colors

A warm monochrome of blacks and cream paper, with one reserved red and two edge-print inks that belong to the film.

### Primary
- **Safelight Red** (`safelight`): the grease pencil, and nothing else. Select loops, hero stars and reject crosses on frames, the tally glyphs in the toolbar that count them, and the drawn mark in full screen. Drawn at 90% for the core stroke with a 35% offset ghost.

### Neutral
- **Bench Black** (`bench`): the window ground behind the sheet, the launch screen and the developing screen.
- **Film Black** (`film`): the strips themselves, the full-screen ground, the launch caption block, the banner, and the 72–78% scrims for drop and printing. A step darker than the bench, so black sits on black.
- **Proof Paper** (`paper`): the proof sheet ground, all primary ink on dark grounds, and the fill of the primary block button. Secondary text on dark is paper at 55–70%; a dimmed row drops to 32%.
- **Sheet Ink** (`ink`): type set on the paper sheet.
- **Muted Sheet Ink** (`ink-muted`): secondary type on paper (4.8:1 on paper; the earlier 50% ink failed at 2.9:1).
- **Hairline** (`rule`): one-pixel rules on bench and film. On paper the rule is ink at 22%; column-head rules strengthen to paper at 40%.
- **Wax White** (`wax`): the drawn wax-box mark in the lock-up and empty states.

### Tertiary (edge print only)
- **Colour-stock Orange** (`edge-color`) and **Mono-stock White** (`edge-mono`): edge printing on colour and B&W rolls, as real stock prints it. They live in the film rebate and nowhere else.

### Named Rules
**The Pencil Owns Red Rule.** Safelight red is drawn, never filled. No red buttons, fields, badges, alerts or progress; the printing state goes dark and says so in type.

**The Black on Black Rule.** Separation on dark grounds comes from the bench/film step and paper hairlines, not from greys or tints of a hue.

## Typography

**Display Font:** Archivo (variable; falls back to SF compressed/condensed/light per register)
**Label Font:** Archivo SemiCondensed (wdth 87)
**Data Font:** Geist Mono (falls back to system monospaced)

**Character:** One grotesk family stretched across three widths does all the speaking: compressed and black for the name, wide and light for the big catalogue numbers, semicondensed and bold for the caps that label them. Mono carries anything that counts.

### Hierarchy
- **Wordmark** (ExtraCondensed Black, wdth 62 / wght 900, 104pt on launch): the CONTACT name in the lock-up. Never used for any other word.
- **Display** (regular width, wght 300, 96–220pt, tabular): big numerals and states: the frame number in full screen (96), the roll label `R01` in roll headers (112), "Printing" (120), the developing percentage (220).
- **Headline** (regular width, wght 380, 40pt): shoot names in the launch index, empty-state titles. Names split on " - ": the part after steps back to 40% (the A24 two-tone title).
- **Title** (regular width, wght 400–430, 20–30pt): caption-block shoot name (24), catalogue roll shoot name (30), banner headline (20), drop prompt ("Drop to develop", 72 at wght 340).
- **Body** (regular width, wght 400, 13–14pt): the rare sentence: empty-state reasons (max 380pt wide), banner detail, "or drop a folder anywhere". Paper at 55–65%.
- **Label** (SemiCondensed bold, wght 700, 10–11pt, tracked 0.08em, uppercase): every caps label, column head and caption-grid key.
- **Button** (SemiCondensed, wght 760, 15pt large / 12pt small, uppercase, tracked ≈0.06em/0.04em): block button labels.
- **Mono** (Geist Mono 500, 11–14pt, tabular digits): bracketed indexes, counts, file names, folders, caption values, tally numbers.

### Named Rules
**The One Name Rule.** The ExtraCondensed Black cut sets "CONTACT" and nothing else.

**The Numbers Are Light Rule.** A big number is set wide and light (wght 300–420), never bold; weight goes to the small caps beside it.

**The Native Chrome Rule.** SF Pro appears only where macOS draws it: the title bar, the toolbar's toggles and back button, alerts and menus. Never in app-drawn content. No handwriting face anywhere; the drawn marks are the only handwriting.

## Layout

Screens are columns of checklist entries. The launch screen splits at 48% of the width (clamped 640–820pt): the index on the left, the previewed shoot's frame edge to edge on the right, which drops away below 1040pt wide. Dark screens use 56pt side margins, a 28pt top and 44–56pt bottom; each opens with a label row (label left, live count or state right) sitting 10pt above a hairline.

Index rows are full-width: a 56pt index column, the name, a right-aligned mono count, 16pt vertical padding, a hairline between each. Caption grids align labels on a fixed column (76pt, or 52pt in the 270pt full-screen caption column) with 14pt column gap and 6pt row gap.

The contact sheet is laid out in design units on a 1500-unit page (60-unit margins, 28-unit strip spacing) scaled to the window and zoomable 0.6–3×; strip geometry follows the film format (35mm, 120 6×6, 120 6×7).

## Elevation & Depth

Flat by default. Depth is the value step from bench (`bench`) to film (`film`), paper laid on black, and hairlines. Shadows appear only under things that float over the sheet while you work.

### Shadow Vocabulary
- **Loupe** (`0 10px 24px rgba(0,0,0,0.5)`): the circular loupe lens over the sheet.
- **Banner** (`0 8px 18px rgba(0,0,0,0.4)`): the post-print banner at the foot of the bench.

### Named Rules
**The Floats Only Rule.** Only a floating overlay casts a shadow; nothing resting on the bench or the sheet does. No glow.

## Shapes

Every UI edge is square: buttons, the banner, caption blocks, the drop frame (2pt paper stroke, inset 14pt), focus (a 1.5pt dashed paper rectangle, 5/4 dash, 4pt outset). The rounding that exists belongs to physical objects and is drawn at their scale: film strips at 2 units and sprocket holes at 1.5, the developing strip at 2pt, the loupe as a true circle. The proof paper itself is square.

## Components

### Buttons
- **Shape:** square (0px), stroked in paper (2pt large, 1.5pt small).
- **Primary (block):** a filled paper block, film-black caps label (SemiCondensed 760). Large 22×13pt padding on launch ("Choose Folder"); small 12×5pt in the toolbar ("Print Selects"). One per screen.
- **Hover / Press:** under the cursor the block inverts to an outline (transparent fill, paper label); pressed it fills at 80%. Disabled at 35% opacity. Instant, no transition.
- **Secondary (outline):** the same square drawn as a paper outline with a paper label; it fills under the cursor. Used for the way out of an empty state and "Reveal Selects" in the banner.
- **Tertiary:** plain caps labels ("Close" in the full-screen column, paper at 80%).

### Catalogue Label, Index and Hairline
- **Label:** Archivo SemiCondensed bold caps, tracked 0.08em, paper at 55% by default.
- **Index:** a bracketed mono number, `[01]`, `[R01]`, `[Esc]`, zero-padded, paper at 55%.
- **Hairline:** 1pt, `rule` on dark, ink at 22% on paper; a stronger rule (paper 40%, or 1.5 units of ink in Catalogue headers) marks a column head.

### Caption Block (signature)
The catalogue checklist entry. A bracketed index and title on one baseline, a hairline, then a caption grid: caps labels in a fixed column, mono values truncating in the middle. Appears as the launch preview's film block flush to the bottom-left corner (340pt wide), the full-screen frame column (frame number at display size, Roll/File/Edge/Date/Size, then the keys as an index), and the roll header on the sheet (Folder/Format/Frames/Stock or Camera as columns between rules).

### Index Row
Launch recents: `[01]` mono index, shoot name at headline size in two tones, mono frame count right. Hovering a row dims every other row to 32%; an offline drive shows the row at 35% with "Drive not connected" in caps.

### Banner
A square film block centred at the foot of the bench, 1pt paper-22% border, title-size headline and body detail, an optional outline button. Slides up from the bottom edge with a fade.

### Grease-Pencil Marks
Seeded hand-drawn strokes in safelight red: a wobbling, overshooting loop (select), a double loop with a star (hero), a cross (reject). Stable per frame; a fresh mark draws on stroke by stroke. Small glyph versions count marks in the toolbar tally beside mono numbers.

### Wax-Box Mark and Lock-up
The mark is a box drawn in wax pencil, path data in `Resources/Brand/wax-box.json`, in wax white with seeded grain above 60pt. The lock-up sets it beside "CONTACT" (gap 0.24× size, mark 0.82×0.96× size); the box never stands in for a letter. Alone at 92×108pt it heads the empty states.

### Edge Print
Per-camera edge printing in the film rebate, in the roll's ink (colour-stock orange or mono white): Ricoh in Doto, Leica in Host Grotesk with a hairline, lab film in Archivo with ■■ flanks and a barcode. These faces live on the film only.

### Sheet
Decided: the Catalogue style. Square cream proof paper on the bench; each roll is headed like a catalogue entry: `R01` at display size (112 units, wght 300), the shoot name right at title size with place · date beneath in mono when known, a 1.5-unit ink rule, then a row of label/value columns (Folder, Format, Frames, Stock for lab rolls or Camera for digital), closed by an ink-22% hairline. Strips, edge print and marks sit on the paper below. (Proof and Bench styles were tried and dropped.)

Treat none of these as the settled sheet. New sheet work must render correctly in all three until the decision is made.

### Navigation
None beyond native macOS chrome: the title bar carries the shoot name and a frames/rolls subtitle; the toolbar sits on a flat bench-black bar and carries the ‹ back button (one level up: full screen → sheet → index), the tally, two native toggles and the one block button. The window style is set once (transparent title bar, full-size content) and never switched, so heights hold across screens and in macOS full screen; the launch screen runs edge to edge beneath it. Values typed onto the sheet (Place, Stock) are inline fields in the roll header, underlined mono until clicked.

## Do's and Don'ts

### Do:
- **Do** index every shoot, roll and frame as a checklist entry: bracketed mono index, caps label, label/value caption on hairlines.
- **Do** keep one primary action per screen as a square paper block; make every other action a square outline or a plain caps label.
- **Do** set big numbers wide and light (wght 300–420) and put weight in the small tracked caps beside them.
- **Do** separate dark surfaces with the bench/film value step and paper hairlines at 14%.
- **Do** head a column with a label row that carries a column name or a live count, 10pt above its hairline.

### Don't:
- **Don't** use safelight red anywhere but drawn grease-pencil marks: no red buttons, fields, badges or alerts.
- **Don't** round UI edges, use pill buttons, glow, or decorative gradients; rounding belongs only to film, sprocket holes and the loupe.
- **Don't** set any word but "CONTACT" in the ExtraCondensed Black cut, or use a handwriting typeface.
- **Don't** use SF Pro in app-drawn content; it belongs to native controls only.
- **Don't** add a thumbnail sidebar, an accent colour, or shadows under anything that rests on the bench.
- **Don't** put a caps label above a headline only to introduce it; labels name columns or report state.
- **Don't** show a client's frames in any brand or review material; use the people-free demo shoot.
