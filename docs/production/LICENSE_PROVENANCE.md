# License and Provenance Evidence

This file is an evidence ledger, not legal advice or a commercial-clearance opinion.

## Native Eastern Stories Godot code

- Root `LICENSE`: **absent** at the Phase 10A baseline.
- No repository file grants a license for the native project as a whole.
- Decision: do not create a root license without an explicit owner decision.
- Status: **UNRESOLVED**.

## Authoritative `reference/es2`

- `reference/es2/README` says: “Created by Raymond Xie, published under MIT license.”
- `reference/es2/LICENSE` is MIT text but names “Copyright (c) 2014-2016 The Wekan Team.”
- Those holder/attribution statements do not reconcile on the available evidence.
- The reference tree remains read-only and is outside the Godot export root.
- Status: **UNRESOLVED**. No ownership reconciliation or commercial-clearance claim is made.

## Godot AI addon

- Vendored locations: `game/addons/godot_ai/` and duplicate repository evidence at
  `game/godot-ai-LICENSE.txt`.
- Both local license texts are MIT License, “Copyright (c) 2025 Godot AI contributors.”
- `game/addons/godot_ai/plugin.cfg` currently identifies addon version **4.4.0**.
  The [official v4.4.0 release](https://github.com/hi-godot/godot-ai/releases/tag/v4.4.0)
  points to upstream commit `ec32c3cc40611100dc754ff43b7b07c725d0a21f`; this identifies
  the upstream release, not verified equality of the current local vendor tree.
- Current local-to-upstream source/manifest equivalence, release-manifest file count and
  ZIP SHA-256 have **not been independently verified**. The old 4.0.1
  hashes and 283-file comparison are historical only; see
  [vendor provenance](GODOT_AI_DEVELOPMENT.md#vendor-provenance).
- The retained 4.0.4 -> 4.2.3 update received a bounded independent dependency review in
  the [Snow Martial Final Audit](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_FINAL_AUDIT.md#godot-ai-and-project-configuration).
  It is not Liuh-Ken gameplay or part of P2R2. The later 4.2.3 -> 4.4.0 update had no
  independent review.
- The existing [release sanitizer](../../tools/build/prepare_release_project.py) removes the
  development addon, duplicate license file and helper/plugin activation from production output.
  Local MIT notices do not establish a license or commercial clearance for the project as a whole.

## Godot Engine/runtime

- CI downloads the official Godot 4.7.2 editor/templates from the `godotengine/godot-builds`
  release and verifies the official `SHA512-SUMS.txt` entry.
- Godot 4.7.2 `LICENSE.txt` is MIT and identifies “Copyright (c) 2014-present Godot Engine
  contributors” and “Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.”
- Exported platform artifacts contain the Godot runtime even though engine binaries/templates are not
  committed to this repository. A future distributable release must carry the required notice.

## Other current assets

Besides the fonts, portraits and baked pictures listed below, tracked image files under `game/`
outside `addons/` are two, both project-made:

- `game/icon.svg`, the Godot project icon;
- `game/scenes/world/common/placeholder_terrain.png`, the flat-colour placeholder atlas of the 2D
  terrain TileSet ([TERRAIN_TILES](../migration/TERRAIN_TILES.md)).

No audio, model or external art/audio pack is tracked. This inventory is not a guarantee about
future content.

## Fonts

The fonts below are bundled for the interface (界面重做, DECISIONS「界面样式」), each with its licence
beside it; the system's fonts fill in glyphs they lack (Godot's system fallback).

- `game/assets/fonts/LXGWWenKaiLite-Medium.ttf` — 霞鹜文楷 Lite Medium, from
  [lxgw/LxgwWenKai-Lite](https://github.com/lxgw/LxgwWenKai-Lite) release v1.530 (13,801,408
  bytes, SHA-256 `9282063131640c9558a102560cf6d6f8ecc4bb441e74f2bcff032ce4786238d0`). SIL Open
  Font License 1.1, `game/assets/fonts/OFL-LXGWWenKaiLite.txt` (reserved names 霞鹜 / LXGW; the
  font is used unmodified).
- `game/assets/fonts/ark-pixel-16px-proportional-zh_cn.otf` — 方舟像素 16 px proportional,
  Simplified Chinese, from [TakWolf/ark-pixel-font](https://github.com/TakWolf/ark-pixel-font)
  release 2026.09.01, `ark-pixel-font-16px-proportional-otf-v2026.09.01.zip` (font 347,964
  bytes, SHA-256 `2527059d7cbe7b53d7de271fc90a1aa6987f262c969713956e88c5a3ab5988c6`). SIL Open
  Font License 1.1, `game/assets/fonts/OFL-ArkPixel.txt`; used unmodified.
- `game/assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2` — 缝合像素 12 px
  proportional, Simplified Chinese, from [TakWolf/fusion-pixel-font](https://github.com/TakWolf/fusion-pixel-font)
  release 2026.10.25, `fusion-pixel-font-12px-proportional-otf.woff2-v2026.10.25.zip` (font
  701,520 bytes, SHA-256 `b67eb7aa592622e5bc1152b800d32404bb887a1e3a2e669b0c2a873d388590d6`). SIL Open Font License 1.1,
  `game/assets/fonts/OFL-FusionPixel.txt`; used unmodified for the pixel interface's text.
- `game/assets/fonts/ZhiMangXing-Regular.ttf` — 志莽行书 (Zhi Mang Xing), from the
  [google/fonts](https://github.com/google/fonts/tree/main/ofl/zhimangxing) repository, `ofl/zhimangxing`
  (4,063,532 bytes, SHA-256 `644e0cae9b40f0b10ab729a01bd32032e3973bac22be3dccae01bf6ae7fde969`). SIL Open Font License 1.1,
  `game/assets/fonts/OFL-ZhiMangXing.txt`; used unmodified for a place's name on the title.
- `game/assets/textures/title/logo_*.png`, `seal_zh_CN.png` — the title logo's ink masks, text
  rendered by `tools/ui/bake_title_logo.gd` from 志莽行书 and 霞鹜文楷 (project-made images of
  OFL-licensed glyphs).

## Character portraits (AI-generated)

`game/assets/portraits/*.png` are the people's 立绘 (DECISIONS「人物外观」): flat-colour pixel
pictures without outlines, 128×256 whole and 128×128 busts, **generated by Muse (muse.ai, an AI
image and design assistant)** from this project's prompts (ES2's descriptions of each person and the
project's flat-colour style sheet), chosen and directed by the owner, then cut out (true alpha),
colour-merged and cleared of the cut-out key's fringe on import; no external art pack or reference
image is included. They are AI-generated content
and must be disclosed as such on a store page (Steam's AI content disclosure). Each batch's date and
people are recorded in the `note` of each person's card in `game/data/<region>/appearances.json`.

## Voxel maps

`game/presentation/voxel/` builds original coloured box meshes and animations in GDScript;
`game/data/<region>/voxel/*.json` and the map layouts' furniture `look`s configure them. No
external pack files are included. Owner-provided visual references: Max Parata's
[ancient environment](https://maxparata.itch.io/voxel-ancient-environment),
[rocky mountains](https://maxparata.itch.io/rocky-mountains), and
[voxel interiors](https://maxparata.itch.io/voxelinterior). Imported art, when it comes, goes under
`game/assets/` with its source recorded here.

`game/assets/textures/atlas/` is the 地图 page's pictures: this project's own voxel maps and generated
voxel land rendered by `tools/maps/atlas/` (DECISIONS「总图」). No external material.

`game/assets/textures/loading/ink_ring.png` is the loading screen's animation (DECISIONS「加载画面」):
a placeholder this project generated with a small Python script, no external material. Art that
replaces it goes in the same folder, named in `game/data/common/loading_screen.json`, with its source
recorded here.
