# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**Package 4 — content importer + Snow complete**, in five playable PRs (see [ROADMAP](ROADMAP.md)):

1. **4A — importer + people in Snow's streets** (`phase/content-importer`):
   `tools/migration/content_importer.py` generates rooms, items, NPCs, spawns and vendors from the
   LPC plus per-region override files; Snow and Old Pine data regenerate unchanged. Fifteen Snow
   NPCs stand in the Inn, the east road, the temple, the north street and the school: travellers,
   dogs, the temple keeper, the drunk, the scavenger, 刘安禄, the trainees and 李火狮.
   Cost per NPC: [SNOW_CONTENT](../migration/SNOW_CONTENT.md).
2. **4B** south road and shops (9 rooms) · **4C** Inn upstairs, school inner rooms, secret storage
   (10 rooms) · **4D** ask, ambient talk, wandering, room reset · **4E** give, shops and services
   bound to their NPCs, teachers as data.

## Playable now

Main scene: `res://scenes/application/application_shell.tscn` (Menu → New Game / Continue).

* **Snow (雪亭镇)**: source-valid New Game in the Inn; square, core streets and temple (18 of 38 rooms as
  zones); Work income; physical coins/silver/gold and Bank exchange; Inn food/drink; Hockshop
  value/sell; apprenticeship with Liu and Learn of basic unarmed and Liuh-Ken (柳家拳); fifteen NPCs
  (8 types) to look at and fight, with their ES2 gear and loot; no fighting in the temple or the
  workplace (`no_fight`).
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

Rough coverage of ES2 content: about 5% (49/502 rooms, 12/240 NPC types, 2/70 player-obtainable
skills, 1/13 families, 0 quests).

## Known issues

Code:

* `busy` is only decremented inside encounters; busy left at encounter exit can stall recovery and
  Save eligibility.
* `apply/parry`, `apply/defense` and weapon-skill `apply/*` bonuses are not projected into combat.
* `random(n<=0)` is handled by per-site exceptions; needs the global MudOS rule (returns 0). The
  16 call sites are combat/learn code; do it with the next package that touches them.
* A failed attack chain holds the encounter in RESOLVING for good (fail closed); Flee is refused
  and the fight cannot end. Content that trips it (4A's dog claw) must be fixed at the cause.
* Snow NPCs do not talk, wander, greet or trade yet (4D/4E); a killed NPC never returns (no room
  reset yet, 4D). Every weapon attacks with one "slash" action and humans punch; ES2's per-weapon
  verbs are not modelled yet.
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
* A script error inside a helper a suite calls skips that helper's remaining checks, and the suite
  still reports PASS; only the log's `SCRIPT ERROR` line shows it.
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
