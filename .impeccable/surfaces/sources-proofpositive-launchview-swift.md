---
version: 1
slug: "sources-proofpositive-launchview-swift"
primary_target: "Sources/ProofPositive/LaunchView.swift"
related_targets: ["Sources/ProofPositive/ShootView.swift","Sources/ProofPositive/SheetViews.swift","Sources/ProofPositive/LoupeAndFullscreen.swift"]
---

# CONTACT app shell — surface brief

Scope: the whole app shell — launch screen, sheet bench and toolbar, full-screen viewer, developing screen, banners, empty and drop states. Mode: Operate (the visitor culls a shoot; native macOS controls stay native).

Audience and job: a photographer culling his own shoots before Lightroom (PRODUCT.md). Constraint: black and white; red belongs to the pencil marks only. The sheet: Steven compared Proof, Catalogue and Bench and chose Catalogue; it is the only style.

## Direction contract

THESIS: CONTACT reads like an exhibition catalogue's checklist: every shoot, roll and frame is an indexed entry — [01], R01 · 017 — set in grotesk on hairline rules, with label/value caption blocks. It refuses the category default: a rounded dark photo app with a thumbnail sidebar, pill buttons and an accent colour.

OWN-WORLD: bench black and film black grounds, paper-white ink, paper hairlines at 14%, no hue but the red pencil. Archivo in three registers — ExtraCondensed Black for the name only, regular-width light (wght 300–450) for big catalogue titles and numerals, SemiCondensed bold caps (+tracking) for labels — and Geist Mono for indexes and counts. Every edge square; the one action a paper block.

STORY: open the app and read your shoots as a numbered catalogue with the hovered shoot's best frame filling the right half; choose one; work the sheet; print; the bench reports what moved.

FIRST VIEWPORT: launch at 1400×950. Left column (48%): label row "INDEX — 0N SHOOTS" on a hairline; the CONTACT lock-up at 112pt; the CHOOSE FOLDER block with "or drop a folder anywhere"; then Recent as catalogue rows — [01] mono index, shoot name in 30pt light Archivo, frame count right — full-width hairlines between. Right half: the previewed shoot's frame edge to edge, a label/value caption block bottom-left ([01] / Shoot / Frames / Starred / Selects / Rejects).

FORM: user-pinned, so no concept-seed roll. Pinning words, in order: "think more abstract ... bauhaus design or leica cameras, like a late 80s or 90s influence"; "i want something brutalist feeling and bold ... again using the magnum contact sheet as a reference point"; then, with the seven reference images (Swiss catalogue spreads, Aurora Design Week, Rue Paris, the A24 index, a Fuji contact sheet with dot stickers): "i want us to get inspired by the layout, typography and overall design language and for us to then reflect it in the app". Signature move: the catalogue checklist — bracketed indexes and label/value caption grids on hairlines, repeated on launch rows, the full-screen caption, roll headers. Motion: none decorative; hover dims siblings instantly, the preview crossfades 200ms.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
