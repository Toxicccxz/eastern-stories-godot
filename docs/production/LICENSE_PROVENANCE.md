# License and Provenance Evidence

This file is an evidence ledger, not legal advice or a commercial-clearance opinion.

## Native Eastern Stories Godot code

- Root `LICENSE`: **absent** at the Phase 10A baseline.
- No repository file grants a license for the native project as a whole.
- Decision: do not create a root license without an explicit owner decision.
- Status: **UNRESOLVED**.

## Authoritative `reference/es2`

The facts on file (no conclusion about what they permit is drawn here):

- `reference/es2` is a 2016 packaging, **ES2 WebMUD** (a web front end around the mudlib).
  `reference/es2/README` ends with “Created by Raymond Xie, published under MIT license.”, and
  `reference/es2/LICENSE` is MIT text naming “Copyright (c) 2014-2016 The Wekan Team.” Both belong to
  that packaging; neither names the mudlib's authors.
- The mudlib's own notice, `reference/es2/mudlib/doc/help/about` (lines 9–12), says the game part —
  all LPC code under the mudlib, the game's help files and the data they produce — belongs to its
  authors (where the author cannot be told, jointly to the game's developers), and may not be
  reproduced outside the game without the author's consent or, where the author is unknown, the
  admin's. `reference/es2/mudlib/README` thanks the original author Annihilator (06/15/95) and points
  to a FluffOS fork by floatinghotpot.
- So the MIT statements and the mudlib's notice point in opposite directions: the packaging says MIT,
  the content's own 1995-era notice restricts reproduction. Whether the original authors ever
  released the mudlib under MIT, and what it would cover, is **not verified**.
- What the game uses: room descriptions, NPC lines, martial-arts move text, item text and the
  world itself are ported from the mudlib into `game/data/` and ship with the game; a review in
  2026-11 measured about 40 % of the long text in `game/data/` as ES2's own words.
- The reference tree is read-only and outside the Godot export root; the GitHub repository that
  holds it is public.
- Status: **UNRESOLVED**. This must be settled before any public distribution of the game (the owner's
  call; see STATUS 待决定).

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
outside `addons/` are two:

- `game/icon.svg`, the project icon: Godot's default new-project icon (the Godot logo), **not**
  project-made — a placeholder to replace with the game's own icon before release (the Godot logo
  is published by the Godot project under CC BY 4.0);
- `game/scenes/world/common/placeholder_terrain.png` (project-made), the flat-colour placeholder atlas of the 2D
  terrain TileSet ([TERRAIN_TILES](../migration/TERRAIN_TILES.md)).

No model or external art/audio pack is tracked; the only audio is the project-made set below.
This inventory is not a guarantee about future content.

## Audio (project-made)

- `game/assets/audio/battle/` — thirteen short sounds for the fight (DECISIONS「战斗拍数 C」「战斗演出 B」「战斗演出 C」):
  `clapper.wav`, `whoosh.wav`, `thud.wav`, `crack.wav`, `clang.wav`, `drum.wav`, `seal.wav`, the
  stage's `brick_wood.wav`, `brick_stone.wav`, `gong.wav`, `scrape.wav`, and the weapons' layers
  `slice.wav`, `thock.wav`.
- Origin: synthesized by [tools/audio/synth_battle_sounds.py](../../tools/audio/synth_battle_sounds.py)
  from sines and filtered noise with the Python standard library alone, a fixed seed per file; no
  recording, sample pack or outside material went into them. Rerunning the script reproduces them
  byte for byte. Project-made: no outside licence applies.

## Fonts

The fonts below are bundled for the interface (界面重做, DECISIONS「界面样式」), each with its licence
beside it; the system's fonts fill in glyphs they lack (Godot's system fallback).

- `game/assets/fonts/LXGWWenKaiLite-Medium.ttf` — 霞鹜文楷 Lite Medium, from
  [lxgw/LxgwWenKai-Lite](https://github.com/lxgw/LxgwWenKai-Lite) release v1.530 (13,801,408
  bytes, SHA-256 `9282063131640c9558a102560cf6d6f8ecc4bb441e74f2bcff032ce4786238d0`). SIL Open
  Font License 1.1, `game/assets/fonts/OFL-LXGWWenKaiLite.txt` (reserved names 霞鹜 / LXGW; the
  font is used unmodified).
- `game/assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2` — 缝合像素 12 px
  proportional, Simplified Chinese, from [TakWolf/fusion-pixel-font](https://github.com/TakWolf/fusion-pixel-font)
  release 2026.10.25, `fusion-pixel-font-12px-proportional-otf.woff2-v2026.10.25.zip` (font
  701,520 bytes, SHA-256 `b67eb7aa592622e5bc1152b800d32404bb887a1e3a2e669b0c2a873d388590d6`). SIL Open Font License 1.1,
  `game/assets/fonts/OFL-FusionPixel.txt`; used unmodified for the pixel interface's text.
- `game/assets/fonts/fusion-pixel-12px-proportional-zh_tw.otf.woff2` — 缝合像素 12 px
  proportional, Traditional Chinese in Taiwan's standard glyph forms, from the same release and
  archive (font 707,536 bytes, SHA-256 `f533986a872978ebe94f7d6fbf8f2ddac0d300b8b726b7cec45458b0da343472`).
  SIL Open Font License 1.1, the same `OFL-FusionPixel.txt` (the archive's OFL.txt is identical);
  used unmodified for the interface's text in 繁體中文.
- `game/assets/fonts/fusion-pixel-12px-proportional-ko.otf.woff2` — 缝合像素 12 px
  proportional, Korean (its Hangul from Galmuri, all 11,172 syllables; proportional curly
  quotes; Han characters in Korean forms), from the same release and archive (font 698,044
  bytes, SHA-256 `4dadf6770d9a0bbe4e78dbd7aeb0a5d5c763f495f21e190faec61ba1aefdb544`). SIL Open
  Font License 1.1, the same `OFL-FusionPixel.txt`; used unmodified for the interface's text in
  한국어.
- `game/assets/fonts/fusion-pixel-12px-proportional-ja.otf.woff2` — 缝合像素 12 px
  proportional, Japanese glyph forms (all 6,355 kanji of JIS X 0208, kana, proportional curly
  quotes), from the same release and archive (font 703,028 bytes, SHA-256
  `089801509cc8eefeb811af9142de5a1aa3a9eab3768e319f1ef163fa8045110f`). SIL Open Font License 1.1,
  the same `OFL-FusionPixel.txt`; used unmodified for the interface's text in 日本語.
- `game/assets/fonts/ZhiMangXing-Regular.ttf` — 志莽行书 (Zhi Mang Xing), from the
  [google/fonts](https://github.com/google/fonts/tree/main/ofl/zhimangxing) repository, `ofl/zhimangxing`
  (4,063,532 bytes, SHA-256 `644e0cae9b40f0b10ab729a01bd32032e3973bac22be3dccae01bf6ae7fde969`). SIL Open Font License 1.1,
  `game/assets/fonts/OFL-ZhiMangXing.txt`; used unmodified for a place's name on the title.
- `game/assets/fonts/Cinzel-VariableFont_wght.ttf` — Cinzel (variable weight 400–900), from the
  [google/fonts](https://github.com/google/fonts/tree/main/ofl/cinzel) repository, `ofl/cinzel/Cinzel[wght].ttf`
  (125,468 bytes, SHA-256 `f4d83d34d1f6c741193e4acf4b3dff9531e5a67b6aa65228d00a7db72a4e0f34`). SIL Open Font
  License 1.1, `game/assets/fonts/OFL-Cinzel.txt`; used unmodified for the title's Latin lettering
  (the English title's mask at weight 700, the line EASTERN STORIES under the Chinese title).
- `game/assets/textures/title/logo_*.png`, `seal_zh_CN.png` — the title's lettering masks, text
  rendered by `tools/ui/bake_title_logo.gd` (project-made images of glyphs): 东方故事 from
  云峰飞云体 (Yunfeng Feiyun, 云峰字库's second free-for-commercial-use face; the foundry's release
  note on ZCOOL, <https://www.zcool.com.cn/work/ZNjA3NjgyODQ=.html>: free commercial use with no
  limit of scope within the law, no modifying or reselling the font; file `云峰飞云体.ttf`,
  7,928,516 bytes, SHA-256 `26118f4c0af4ebe5aa71ee2d68284983031f0798693ba3829285685e641a1a5f`,
  fetched from the [jaywcjlove/free-font](https://github.com/jaywcjlove/free-font) collection —
  **the font file is not shipped or modified, only the four characters' image**; confirm the
  foundry's terms again before release), EASTERN STORIES from Cinzel and 侠 from 霞鹜文楷 (both
  OFL).
- `game/assets/textures/title/logo_ko.png` — the Korean title's lettering mask, 동방이야기 rendered
  by the same tool from 추사 사랑체 Bold (ChusaLoveBold, made and opened by 예산군 Yesan County
  under 공공누리 제1유형 (KOGL Type 1: commercial use and derivative works allowed, source must be
  credited); listed on [눈누](https://noonnu.cc/font_page/883), file `ChusaLoveBold.woff2` from
  `cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2205@1.0/`, 2,230,852 bytes, SHA-256
  `f9b9bc5143b40f62f731c059c6753efe271947dbbdbacb024db178377cf44cac`) — **the font file is not
  shipped, only the five syllables' image**. A release must carry the credit, e.g. in its
  credits: 「본 저작물은 '예산군'에서 공공누리 제1유형으로 개방한 '추사사랑체'를 이용하였으며,
  해당 저작물은 '예산군 www.yesan.go.kr'에서 무료로 다운받으실 수 있습니다.」
- `game/assets/textures/title/logo_ja.png` — the Japanese title's lettering mask, 東方物語 rendered
  by the same tool from 衡山毛筆フォント行書 (Kouzan Brush Font Gyousho, brushed and made by the
  calligrapher 青柳衡山 Aoyagi Kouzan, published by 武蔵システム Musashi System,
  <https://opentype.jp/kouzangyousho.htm>: free, commercial use allowed without restriction,
  free to use in logos; file `KouzanGyousho.zip` → TrueType font, 5,640,044 bytes, SHA-256
  `6b063cc0f9591ea2e71c97f06c8e663d04a0b0ac4bbe6c0e4c3b49a13215db99`) — **the font file is not
  shipped, only the four characters' image**.
- `game/assets/textures/title/logo_ru.png` — the Russian title's lettering mask, Восточные /
  истории rendered by the same tool from Mister Brush (by GGBotNet, <https://ggbot.net/fonts>,
  <https://ggbot.itch.io/mister-brush-font>; SIL Open Font License 1.1 with Reserved Font Name
  "Mister Brush", which allows commercial use and images made with the font; file
  `MisterBrush.ttf` with its `License.txt` from GGBotNet's DaFont listing `mister_brush`,
  746,240 bytes, SHA-256 `3650adbc132ae1af15e08d75ea9f33873cc8dc4c121c99b09f72bc0e18f36da0`) —
  **the font file is not shipped, only the two lines' image**. The two other fonts on the
  owner's shortlist, used only for samples and not in the game: Comforter Brush (Robert
  Leuschke) and Monomakh (Aleksandr Andreev and Nikita Simmons), both SIL OFL 1.1 from
  [Google Fonts](https://github.com/google/fonts) (`ofl/comforterbrush`, `ofl/monomakh`).

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

The loading animation (DECISIONS「加载画面」) is drawn in code from `game/data/common/loading_screen.json`
(voxel cubes, no picture). A picture sheet that replaces it goes in `game/assets/textures/loading/`,
named in that file, with its source recorded here.
