# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**New-player combat** (between 4A and 4B), two PRs:

1. **Rules** (`phase/new-player-combat`): 切磋 (ES2 `fight`) with `npc.c` and per-NPC
   `accept_fight`, armed spars that wound, NPCs healing and coming to between fights, the killer
   taken from the last blow, a failed fight that ends instead of freezing, and the global
   `random(n<=0)=0` rule.
2. **Battle narration** (`phase/battle-narration`, stacked on 1): the battle panel in Chinese,
   and the log in ES2's words: action, dodge, parry, damage, status, riposte, winner and guard
   lines, seen from the player.

Then Package 4 goes on (see [ROADMAP](ROADMAP.md)): **4B** south road and shops (9 rooms) ·
**4C** Inn upstairs, school inner rooms, secret storage (10 rooms) · **4D** ask, ambient talk,
wandering, room reset · **4E** give, shops and services bound to their NPCs, teachers as data.
4A (importer + Snow's street NPCs) is merged; cost per NPC:
[SNOW_CONTENT](../migration/SNOW_CONTENT.md).

## Playable now

Main scene: `res://scenes/application/application_shell.tscn` (Menu → New Game / Continue).

* **Snow (雪亭镇)**: source-valid New Game in the Inn; square, core streets and temple (18 of 38 rooms as
  zones); Work income; physical coins/silver/gold and Bank exchange; Inn food/drink; Hockshop
  value/sell; apprenticeship with Liu and Learn of basic unarmed and Liuh-Ken (柳家拳); fifteen NPCs
  (8 types) to look at, fight or spar (切磋), with their ES2 gear and loot; NPCs heal between
  fights and come to after being knocked out; no fighting in the temple or the workplace
  (`no_fight`).
* **Old Pine (老松岭)**: forest (paths, clearing, bandit slope, bridge, pine maze, cliffside), the gorge
  below the bridge (waterfall pool, river, Lake with five serpents) reached by the vine or the cave,
  the pine top, the cliff niche between gorge and cliffside, minimal Passage Cave; five bandits
  (31 of 41 rooms).
* **Across both**: each zone shows its ES2 room title and description (on arrival and via 观察);
  semi-automatic encounter combat with Flee, told in ES2's combat lines, death/corpse/loot, waking from
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
* A failed attack chain ends the fight with 战斗出错，已中止。 (development builds log why); the
  cause still has to be fixed in the content or rule that tripped it.
* Beasts cannot be asked to spar (ES2's `fight` on a beast is a one-sided kill); attack them.
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
* Player text is mostly not localized (`tr()` only in the HUD chrome and the battle panel) and
  some panels still mix English and Chinese.
* The battle log has no 昏倒/死亡 line yet (`announce()`), nor force reflection lines.

Platforms: Windows and Android release builds; iOS is an unsigned compile only. Real touch-device
qualification for Lake and Shared UI is deferred. The provisional app ID
`com.example.easternstoriesgodot` must be replaced before signing.

Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)). Settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~10 min). Single
suites: `<godot> --headless --path game --script res://tests/run_suite.gd -- <suite paths>`.
