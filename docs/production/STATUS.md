# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**Package 1 — Workflow reset** on `phase/workflow-reset` (from green main `d627daa`, PR #25).
Slim rules/docs, one-page STATUS, single-suite test runner. Next: **Package 2 — data-driven
content** (see [ROADMAP](ROADMAP.md)).

## Playable now

Main scene: `res://scenes/application/application_shell.tscn` (Menu → New Game / Continue).

* **Snow (雪亭镇)**: source-valid New Game in the Inn; square and core streets (17 of 38 rooms as
  zones); Work income; physical coins/silver/gold and Bank exchange; Inn food/drink; Hockshop
  value/sell; apprenticeship with Liu and Learn of basic unarmed and Liuh-Ken (柳家拳).
* **Old Pine (老松岭)**: outdoor route, Vine/Waterfall/River/Cliff/Pine traversal, minimal Passage
  Cave, Lake with five serpents; five bandits (29 of 41 rooms).
* **Across both**: semi-automatic encounter combat with Flee, death/corpse/loot,
  inventory/equipment, eating/drinking and recovery, shared HUD and panels, manual Save/Continue.
* Grey-box visuals (ColorRect/Polygon2D placeholders), no art or audio yet.

Rough coverage of ES2 content: about 5% (46/502 rooms, 4/240 NPC types, 2/70 player-obtainable
skills, 1/13 families, 0 quests).

## Known issues

Code:

* Combat cadence comes from an unset `OpportunityTimer.wait_time` (implicit 1.0 s) and only the Old
  Pine outdoor controller supplies an interval; other maps return 0.
* `busy` is only decremented inside encounters; busy left at encounter exit can stall recovery and
  Save eligibility.
* `apply/parry`, `apply/defense` and weapon-skill `apply/*` bonuses are not projected into combat.
* `random(n<=0)` is handled by per-site exceptions; needs the global MudOS rule (returns 0).
* Practice, self-learning, exercise (cultivation) and conditions exist in Core but have no runtime
  caller.
* `oldpine_world_definitions.gd` references `oldpine_keep.tscn`, which does not exist.
* The `_phase10b4_qa_bridge` autoload is active in every dev run; F7 overwrites the dev save.
* Content is hard-coded in GDScript; runtime has many `oldpine_*` / `snow_*` specific classes.
* Player text is not localized (`tr()` unused), mixes English/Chinese and shows legacy room IDs.
* On the smallest supported viewport (480×320) the exploration HUD overflows the safe area when all
  five context buttons are shown (panel 342 px tall vs 288 px content). Whether they are shown when
  `mobile_presentation_test.gd` checks depends on physics timing, so "HUD action panel safe" fails
  intermittently (seen locally; CI has not hit it yet).

Platforms: Windows and Android release builds; iOS is an unsigned compile only. Real touch-device
qualification for Lake and Shared UI is deferred. The provisional app ID
`com.example.easternstoriesgodot` must be replaced before signing.

Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)). Settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~10 min). Single
suites: `<godot> --headless --path game --script res://tests/run_suite.gd -- <suite paths>`.
