# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**野羊山** (`phase/goathill`), region plan #2: all its rooms north of Snow's crossroad. The
mountain road with three 土匪爪牙 and their 土匪首领 on its corner (they attack together), 黄霸 in
the small temple with a 大金槌 in each hand and 伏蛟功, the canyon down to the caverns and their
thirteen rock leeches. New: a second weapon in the other hand (its weapon_prop counts, the
player's too), hammers' and staffs' bash, crush and slam with weapond.c's bash_weapon (a
parried blow knocks the weapon away or breaks it: 断掉的), 伏蛟功.

Next: 卧龙岗 + 绮云镇 (region plan #3: the quest system).

## Playable now

Main scene: `res://scenes/application/application_shell.tscn` (Menu → New Game / Continue).

* **Snow (雪亭镇)**: source-valid New Game in the Inn; the Inn's upper floor, square, streets,
  temple, the south road to the closed exits toward 天驼关 and 水烟阁, the school (书院), the
  west-side shops, 淳风武馆 with its inner rooms and weapon storage, and the secret storage below
  (37 of 38 rooms; 药铺密室 has no entrance); items on the floor to pick up; Work income; physical coins/silver/gold and Bank exchange; Inn food/drink;
  herbshop (金疮药, 蛇药) and smithy (铁锤) bought from their keepers; Hockshop value/sell and its
  storage room; apprenticeship with 柳淳风 and learning basic unarmed, sword, parry, dodge and
  force, Liuh-Ken (柳家拳), 封山派内功 and literate from 柳淳风, 李火狮 (封山剑派 students) and 魏无极
  (after five taels of tuition), then 封山剑法 and 倒乱七星步法 at max_force 50; the character
  panel's 武学 page: skills, enabled skills and effective levels, enable/disable anywhere outside a
  fight, 打坐 (exercise), 练习 (practice), 自学, 研读 (the scavenger's 旧书), 加力 (enforce) and
  运功 (exert: 疗伤, 恢复气, 恢复神, 恢复精; in a fight from the battle panel); give, drop and put (the 功德箱 takes donations and gives them
  back); thirty-three NPCs (20 types) to look at, ask (打听), fight or spar (切磋) with their ES2
  gear and loot (the crazy dog on the west road attacks; a spar with 安惜迩 becomes his kill;
  柳绘心 refuses); in a fight 刘安禄, the farmer, 柳绘心, 柳淳风 and 安惜迩 talk and use their
  specials (「封」字诀, 安惜迩's spells and powerup), and the player uses 封山剑法's 「封」「逐」「缺」
  from the battle panel; dogs, the scavenger, the woodcutter and the crazy dog talk
  and wander next door while you are with them; the drunk drinks and begs for wine; the temple
  keeper and the waiter greet you; three travellers with 飞刀 wander from the square; NPCs heal
  between fights and come to after being knocked out; no fighting in the temple or the
  workplace (`no_fight`).
* **Old Pine (老松岭)**: all 41 rooms. Forest (paths, clearing, bandit slope, bridge, pine maze,
  cliffside), the keep (土匪喽罗, 土匪首领, 常老大 and the gate trap), the gorge below the bridge
  (waterfall pool, river, Lake with five serpents) reached by the vine, the cave or cliff2, the pine
  top with six butterflies, both cliff niches, the secret passage, the stone and the caves (bury the
  bones for 过招要旨, or fall to the waterfall); 疯老头子 on the east path, 狼狗 in the pine maze,
  金银花蛇 (蛇毒) on the stone, 黑衣人 (飞刀, 化尸粉) in the pine.
* **野羊山**: north of Snow's crossroad, all 15 rooms on two maps: the mountain road (土匪爪牙,
  土匪首领 and 黄霸 in the small temple) and the caverns below the canyon (岩蛭, 肥岩蛭, 大岩蛭,
  巨岩蛭).
* **Across both**: each zone shows its ES2 room title and description (on arrival and via 观察);
  rooms reset on world time (killed NPCs come back, wanderers go home, gone floor items return);
  semi-automatic encounter combat with Flee, told in ES2's combat lines, death/corpse/loot, waking from
  unconsciousness and reincarnation at the Snow temple after death,
  inventory/equipment with stacks (give, drop or put part of one), eating/drinking, using drugs,
  recovery and conditions (蛇毒), shared HUD and panels, manual Save/Continue.
* Combat: weapons and bare hands draw ES2's verbs, mapped martial arts their moves (柳家拳,
  封山剑法), dodges read the mapped dodge skill's lines (倒乱七星步法); armor, weapon and NPC
  `apply/*` bonuses and internal power count: force_factor on every landed blow, and a bare-handed
  blow against stronger force is thrown back (std/force.c, told in the battle log).
* Placeholder visuals: flat-colour terrain tiles; characters and objects are still coloured boxes.
  No art or audio yet.

Coverage of ES2 content ([region plan](ROADMAP.md#region-plan)): 93/551 rooms, 40/286 NPC
types, 1/10 joinable families, 7/35 special and 6/25 basic martial arts, 0/87 quest targets.

## Known issues

Code:

* A failed attack chain ends the fight with 战斗出错，已中止。 (development builds log why); the
  cause still has to be fixed in the content or rule that tripped it.
* Beasts cannot be asked to spar (ES2's `fight` on a beast is a one-sided kill); attack them.
* 刘安禄's 刘老三/血手刘三 are not listed until his reveal is ported. The Inn's travellers stay in
  the Inn (its exits all lead to other maps; NPCs do not cross maps yet). Corpses never decay, so the
  corpses of NPCs that came back stay. 桃符纸 (the temple) is not placed: it needs the player's
  spells. NPCs never flee a losing fight (`wimpy`) and do not follow who flees (`pursuer`).
  Wine makes nobody
  drunk yet (the drunk condition); the dog takes no bone (no
  chicken leg, no following); nothing can be put into a corpse.
* At ES2's pace, exercise takes about 8–16 hours of play from max_force 0 to 50 (owner: a data
  multiplier in the pacing knobs package); `tests/runtime/run_with_max_force.gd` gives a playtest
  49. max_force/4 reaches max kee only at the next Continue (ES2's login). Conditions do not tick
  in a fight (owner) nor while the player lies unconscious.
* A zone that merges several rooms shows only its first room's text.
* The Session is still `OldPineWorldSessionController` and persistence classes keep `oldpine_*`
  names although they now cover every map; pre-B2 Old Pine regression suites drive combat through
  a test-only manual cadence (`historical_world_combat_fixture.gd`).
* `oldpine_lake_production_test.gd` fails its three Fill checks when run on its own (also on main);
  it passes inside `run_tests.gd`.
* The legacy technical fixture (`CombatSliceContentProfile` defaults, demo factory) keeps its own
  copy of the long sword's facts.
* Only Simplified Chinese exists. English and other languages without measure words will need
  their own count phrases and number words, and ES2's combat lines person and pronoun rules
  (你 punches / he punches); see [LOCALIZATION](LOCALIZATION.md). Log lines written before a
  language switch stay in the old language.
* The HUD keeps an NPC selected after the player leaves its room (its actions are refused, kill.c
  `present()`); room labels and NPC names overlap in places (grey-box layout).
* The battle log has no 昏倒/死亡 line yet (`announce()`).

Platforms: Windows and Android release builds; iOS is an unsigned compile only. Real touch-device
qualification for Lake and Shared UI is deferred. The provisional app ID
`com.example.easternstoriesgodot` must be replaced before signing.

Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)). Settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~13 min; fails on a
`SCRIPT ERROR` line, or when `python tools/l10n/extract_pot.py` was not run after a text change). Single suites: `<godot> --headless --path game --script res://tests/run_suite.gd
-- <suite paths>`. A longer soak: `ES_SOAK_HOURS=8` before the `world_soak_test` suite (8 hours
passed).
