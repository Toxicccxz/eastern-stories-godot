# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**Package 3 — generic map runtime**, in playable PRs (see [ROADMAP](ROADMAP.md)):

1. **World data** (PR #29): rooms, regions, maps, zones and portals are JSON; the player reads each
   room's ES2 text on arrival and with Look (观察); the HUD fits 480×320.
2. **Generic map controller + Snow** (PR #30): one `WorldMapController`; Snow's bank, work, waiter,
   pawn shop, teacher and doors are data-configured services/doors; the HUD asks the map what is
   here instead of casting to Snow map types.
3. **Old Pine on the generic controller** (PR #31): Old Pine's outdoor map and
   cave use `WorldMapController`; NPCs spawn from spawns.json onto one generic body scene; landmarks
   (climb/descend/vine), water sources and the Lake's complete-set entry are data; one combat round
   per second on every map (`pacing.json`); saves, combat and the HUD go through every resident map.
4. **Terrain on `TileMapLayer`** (PR #32): Snow and Old Pine are painted with one 16 px placeholder
   TileSet ([TERRAIN_TILES](../migration/TERRAIN_TILES.md)). Swapping art means replacing the TileSet.
5. **Old Pine by height level** (`phase/oldpine-elevation-maps`): forest, gorge, tree top and cliff
   niche are separate maps; climbing, the vine and the cave are scene transitions; the forest follows
   the ES2 exits (the bandit slope is north of the clearing); Old Pine collides through its tiles.
6. Snow collision on its tiles (3B6, next).

## Playable now

Main scene: `res://scenes/application/application_shell.tscn` (Menu → New Game / Continue).

* **Snow (雪亭镇)**: source-valid New Game in the Inn; square, core streets and temple (18 of 38 rooms as
  zones); Work income; physical coins/silver/gold and Bank exchange; Inn food/drink; Hockshop
  value/sell; apprenticeship with Liu and Learn of basic unarmed and Liuh-Ken (柳家拳).
* **Old Pine (老松岭)**: forest (paths, clearing, bandit slope, bridge, pine maze, cliffside), the gorge
  below the bridge (waterfall pool, river, Lake with five serpents) reached by the vine or the cave,
  the pine top, the cliff niche between gorge and cliffside, minimal Passage Cave; five bandits
  (31 of 41 rooms).
* **Across both**: each zone shows its ES2 room title and description (on arrival and via 观察);
  semi-automatic encounter combat with Flee, death/corpse/loot, waking from
  unconsciousness and reincarnation at the Snow temple after death,
  inventory/equipment, eating/drinking and recovery, shared HUD and panels, manual Save/Continue.
* Placeholder visuals: flat-colour terrain tiles; characters and objects are still coloured boxes.
  No art or audio yet.

Rough coverage of ES2 content: about 5% (49/502 rooms, 4/240 NPC types, 2/70 player-obtainable
skills, 1/13 families, 0 quests).

## Known issues

Code:

* `busy` is only decremented inside encounters; busy left at encounter exit can stall recovery and
  Save eligibility.
* `apply/parry`, `apply/defense` and weapon-skill `apply/*` bonuses are not projected into combat.
* `random(n<=0)` is handled by per-site exceptions; needs the global MudOS rule (returns 0).
* Practice, self-learning, exercise (cultivation) and conditions exist in Core but have no runtime
  caller.
* The `_phase10b4_qa_bridge` autoload is active in every dev run; F7 overwrites the dev save.
* Skills and the teacher are still hard-coded GDScript. A zone that merges several rooms shows
  only its first room's text.
* The Session is still `OldPineWorldSessionController` and persistence classes keep `oldpine_*`
  names although they now cover every map; pre-B2 Old Pine regression suites drive combat through
  a test-only manual cadence (`historical_world_combat_fixture.gd`).
* `oldpine_lake_production_test.gd` fails its three Fill checks when run on its own (also on main);
  it passes inside `run_tests.gd`.
* The legacy technical fixture (`CombatSliceContentProfile` defaults, demo factory) keeps its own
  copy of the long sword's facts.
* Player text is mostly not localized (`tr()` only in the HUD chrome) and some panels still mix
  English and Chinese.

Platforms: Windows and Android release builds; iOS is an unsigned compile only. Real touch-device
qualification for Lake and Shared UI is deferred. The provisional app ID
`com.example.easternstoriesgodot` must be replaced before signing.

Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)). Settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~10 min). Single
suites: `<godot> --headless --path game --script res://tests/run_suite.gd -- <suite paths>`.
