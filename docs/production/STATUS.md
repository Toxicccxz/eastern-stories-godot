# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**Snow milestone check** (`phase/snow-milestone-check`), after Package 4 (4A–4E merged): busy
wears off on the heart beat outside a fight (char.c), the QA bridge is opt-in, `verify.py`
fails on a `SCRIPT ERROR`; Snow's main path runs through the real shell as a suite
(`snow_main_path_test`) and hours of world time as a soak (`world_soak_test`); a windowed
walkthrough of all 37 rooms (every speaking NPC asked, every service used) fixed what it found.

Then **Package 5, localization foundation** (see [ROADMAP](ROADMAP.md)). Cost per NPC:
[SNOW_CONTENT](../migration/SNOW_CONTENT.md).

## Playable now

Main scene: `res://scenes/application/application_shell.tscn` (Menu → New Game / Continue).

* **Snow (雪亭镇)**: source-valid New Game in the Inn; the Inn's upper floor, square, streets,
  temple, the south road to the closed exits toward 天驼关 and 水烟阁, the school (书院), the
  west-side shops, 淳风武馆 with its inner rooms and weapon storage, and the secret storage below
  (37 of 38 rooms; 药铺密室 has no entrance); items on the floor to pick up; Work income; physical coins/silver/gold and Bank exchange; Inn food/drink;
  herbshop (金疮药) and smithy (铁锤) bought from their keepers; Hockshop value/sell and its
  storage room; apprenticeship with 柳淳风 and learning basic unarmed, Liuh-Ken (柳家拳) and literate
  from 柳淳风, 李火狮 (封山剑派 students) and 魏无极 (after five taels of tuition); give, drop and put
  (the 功德箱 takes donations and gives them back); thirty-two NPCs (19 types) to look at, ask
  (打听), fight or spar (切磋) — not 柳淳风 and 安惜迩 yet — with their ES2 gear and loot (the
  crazy dog on the west road attacks); dogs, the scavenger, the woodcutter and the crazy dog talk
  and wander next door while you are with them; the drunk drinks and begs for wine; the temple
  keeper and the waiter greet you; NPCs heal between fights and come to after being knocked
  out; no fighting in the temple or the workplace (`no_fight`).
* **Old Pine (老松岭)**: forest (paths, clearing, bandit slope, bridge, pine maze, cliffside), the gorge
  below the bridge (waterfall pool, river, Lake with five serpents) reached by the vine or the cave,
  the pine top, the cliff niche between gorge and cliffside, minimal Passage Cave; five bandits
  (31 of 41 rooms).
* **Across both**: each zone shows its ES2 room title and description (on arrival and via 观察);
  rooms reset on world time (killed NPCs come back, wanderers go home, gone floor items return);
  semi-automatic encounter combat with Flee, told in ES2's combat lines, death/corpse/loot, waking from
  unconsciousness and reincarnation at the Snow temple after death,
  inventory/equipment, eating/drinking and recovery, shared HUD and panels, manual Save/Continue.
* Placeholder visuals: flat-colour terrain tiles; characters and objects are still coloured boxes.
  No art or audio yet.

Rough coverage of ES2 content: about 7% (68/502 rooms, 23/240 NPC types, 3/70 player-obtainable
skills, 1/13 families, 0 quests).

## Known issues

Code:

* `apply/parry`, `apply/defense` and weapon-skill `apply/*` bonuses are not projected into combat.
* A failed attack chain ends the fight with 战斗出错，已中止。 (development builds log why); the
  cause still has to be fixed in the content or rule that tripped it.
* Beasts cannot be asked to spar (ES2's `fight` on a beast is a one-sided kill); attack them.
* 刘安禄's 刘老三/血手刘三 are not listed until his reveal is ported. The travellers stay in the Inn
  (its exits all lead to other maps; NPCs do not cross maps yet). Corpses never decay, so the
  corpses of NPCs that came back stay. 柳绘心 (the study) and 桃符纸 (the temple) are not placed:
  she needs 封山剑法/乱七星步, the seals combined items; 柳淳风 and 安惜迩 cannot be fought for the
  same reason. 金疮药 cannot be applied yet, and NPCs never flee a losing fight (`wimpy`) nor talk
  in one. Every weapon attacks with one "slash" action and humans punch; ES2's per-weapon verbs
  are not modelled yet. Wine makes nobody drunk yet (conditions); the dog takes no bone (no
  chicken leg, no following); nothing can be put into a corpse.
* Practice, self-learning, exercise (cultivation) and conditions exist in Core but have no runtime
  caller.
* Skill combat actions are still GDScript (`liuh_ken_definition.gd`). A zone that merges several
  rooms shows only its first room's text.
* The Session is still `OldPineWorldSessionController` and persistence classes keep `oldpine_*`
  names although they now cover every map; pre-B2 Old Pine regression suites drive combat through
  a test-only manual cadence (`historical_world_combat_fixture.gd`).
* `oldpine_lake_production_test.gd` fails its three Fill checks when run on its own (also on main);
  it passes inside `run_tests.gd`.
* The legacy technical fixture (`CombatSliceContentProfile` defaults, demo factory) keeps its own
  copy of the long sword's facts.
* Player text is mostly not localized (`tr()` in the HUD chrome, the battle panel and what 4E
  added) and some panels still mix English and Chinese (the inventory's Inspect/Remove/Wield and
  [WORN]): Package 5.
* The HUD keeps an NPC selected after the player leaves its room (its actions are refused, kill.c
  `present()`); room labels and NPC names overlap in places (grey-box layout).
* The battle log has no 昏倒/死亡 line yet (`announce()`), nor force reflection lines.

Platforms: Windows and Android release builds; iOS is an unsigned compile only. Real touch-device
qualification for Lake and Shared UI is deferred. The provisional app ID
`com.example.easternstoriesgodot` must be replaced before signing.

Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)). Settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~13 min; fails on a
`SCRIPT ERROR` line). Single suites: `<godot> --headless --path game --script res://tests/run_suite.gd
-- <suite paths>`. A longer soak: `ES_SOAK_HOURS=8` before the `world_soak_test` suite (8 hours
passed).
