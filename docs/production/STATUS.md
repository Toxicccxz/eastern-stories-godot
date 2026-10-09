# Status

_One page, overwritten as work progresses. History lives in git and PRs._

## Current work

**茅山 D** (`phase/maoshan-d`, region #6, plan approved 2026-10-08: A places the region (#81),
B 茅山派 (#82), C the player's 茅山道术 in a fight and its practice (#83), D zombies and 桃符纸):
驱尸 on a corpse raises the victim's zombie, which follows the player (onto other maps too),
lives on their 灵力 and is left out of a save; 桃符纸 (two in Snow's 城隍庙) take a 僵尸追魂符
with the selected NPC's name, and put on the zombie it goes after them while the player stands
by in the fight. With D, region #6 is done. The map controller's components live under
`game/runtime/world/map/` (#78); the player's spells outside a fight are `world_map_spells.gd`.

Next: the equipment weight dodge (A1, its own PR), then region #7 晚月庄 (`d/latemoon`).

## 待决定

两项等 owner 完整试玩后再定。规则（owner，2026-10-08）：PR 合并时 owner 没有回答的问题，按 PR 里的推荐
方案生效，在 [DECISIONS](../migration/DECISIONS.md) 里标「默认」，owner 随时可以否决；已批准的积压决定
也在那里（「积压问题的处理」）。

* **A2 经验节奏**（#62）：×3 经验下 combat_exp 150→1001 仍要 6–12 小时；目标是 1–2 小时接到第一个
  任务。试玩时同时核验 60 秒的任务限时在要走路的地图上是否来得及。茅山 A 加了四个 600–2500 exp 的
  对手（进香客、玄和、玄真、老道士）；它的 8 个任务目标离朱鸿雪最远（绮云镇→雪亭→山路→石阶→观内）。
* **A6 「进门一起上」是否扩大到所有房间**（#68）：ES2 同房间的凶徒全部出手；现在只有 6 个区域用
  `complete_set`（老松寨三间、水潭、野羊山转角、卧龙岗）。

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
  运功 (exert: 疗伤, 恢复气, 恢复神, 恢复精, 天邪神功's three; in a fight from the battle panel),
  杀气 and 定力; give, drop and put (the 功德箱 takes donations and gives them
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
* **卧龙岗 + 绮云镇**: south of Snow's 雪亭镇街道, all 43 rooms on four maps (the ridge and the town, and each upper floor on its own): 卧龙岗强盗 and their toll (walk straight past them; they attack
whoever stops in their reach), six shops (书局, 肉铺, 药店, 杂货铺,
  布庄, 兵器屋) with their keepers' greetings, 李师师's literate after a keepsake, the 飞贼's steal,
  the 家丁's 春风快意刀, 化缘和尚 and Snow's two 乞丐 in the 斋院, 茶工 and 县城官兵 walking,
  the 木雕门 and 木门; joining 振远镖局 (陈剑秋, cor 25; betrayal from 封山剑派 and back), learning
  from 陈剑秋 and 趟子手, practising 春风快意刀 with a blade; 朱鸿雪's quests (41 of the 84
  targets stand in the game so far), betting with the 宝官. Not yet: the ferry, 陈剑秋's letter
  (乔阴县城's 忘忧草).
* **水烟阁**: west of Snow's 青石官道 (sroad5), all 28 rooms on three maps: the road and the
  white stone stairs up the mountain past the two 水烟阁武士 and 半山亭 (the 司事 and the 天邪虎),
  the platform before the pavilion and the west path to 葬剑亭 (its monolith and 虹谷's stone
  tablet to look at); inside, the 正门 (its guards stop anyone with a weapon in hand going north),
  the 正厅 with 於兰天武, 萧辟尘 and 潘军禅 and its sign, the halls, kitchen, woodshed and servants'
  room; upstairs the four 红衣武士 (on duty: no spar) and the three elders in 聆啸厅. They fight
  with 天邪神掌, 六阴追魂剑法, 火蝠身法, powerup and 南危水's counterattack; 萧辟尘 wields his sword
  against an armed enemy and puts it away against bare hands. Joining 天邪派: 萧辟尘 after an oath,
  於兰天武 after his three blows (asked first; failing knocks the player out, a bad wound kills);
  learning from both (於兰天武 teaches only his apprentices), practising 天邪神掌, 六阴追魂剑法, 火蝠身法
  and 七宝天岚舞 (women, spi 20, costs sen); 天邪神功 is learnt with 杀气; the 正厅's sign makes the
  player a 武者; the player's 天邪神功: 提升战斗力, 压制杀气 and 天邪虎啸, and 杀气 that boils over.
* **青石村**: east of Snow's 山坳, all 39 rooms on three maps: the village (the work station's
  well, the quarry yard, the square's banyan, 沈记商行, the 土地庙), its 采石工 (a hammer or a
  rope), 工匠, the women (one draws her 菜刀 in a fight), the children (two wander, two peer at the
  cave door), 老公公 and 老婆婆 (attack one and the other comes to kill you), 村长 and his 玉佩
  story (he marks who asks; 接话 必有妖孽), 沈万年 (his list, the jade for the drunk's word, 蒙汗药
  for 10 taels); looking at the empty house's web brings a spider down (three a reset). North: the cave,
  the cliff road and 山路尽头; at 100000 combat_exp the cave east leads into the 迷阵, whose 路牌
  tell the way: wrong ways loop back, turn back or drop the player in 绝地 (push the stone with
  560 force, or 放弃 and wake in the Inn); 乾 south leads to the stone rooms behind, marked 八卦阵,
  and the stream gives that mark a 追风剑. The rope's 上吊 kills (asked first). 绝尘子 in the
  hall: joining 绝尘派 (spi 24, 100000 combat_exp; a family's member is attacked for asking, asked
  first), his fourteen skills, his 遁 and the 天将 he calls in a fight; his apprentices cast 遁
  (to Snow's 城隍庙), 困 and 召天将 (a 天将 on their side) from the battle panel.
* **茅山**: east of Snow's mountain road (its steps north), 25 of 27 rooms on three maps: the
  青石官道 and the white quartz stairs up between the pines (进香客, 玄真 sweeping) to the 山门;
  inside, the square, the hall with 林忌, 僵尸侍者 and 僵尸护法, the walkways round the courtyard
  (玄和), the guest rooms (老道士), the training hall (清虚, 明心), the rear hall behind its shut
  red door, the mossy path (random(kar) below 3 slips and knocks the player out) to the 藏经楼,
  where two of 清灵/清平/清玄/清风/清音/清云 stand guard (drawn at each reset) by its slab, and only
  茅山派 passes the invisible wall; its upper floor. The taoists call themselves 贫道; 老道士
  never spars, 僵尸侍者 and 僵尸护法 only with 茅山派; in a fight they cast 紫光, 白光, 青光 and
  召护法 (a 天将 or a 阴鬼卒 comes to their side). Joining 茅山派: 林忌 takes men only, answering
  two seconds after 拜师 (不便收女徒 for a woman; 慢著，一个一个来 to one who withdrew and asked
  again before it), as a 道士; he teaches his twelve skills, 僵尸侍者 and 僵尸护法 teach any
  member; 谷衣心法 (max_mana five times its level; 运功灵神诀 turns force into mana, 疗伤),
  天师正道 (杀气 100 at most), 天师剑法 (practised with a sword) and 茅山道术, whose 紫光, 白光,
  青光 and 召护法 the player casts from the battle panel (召护法 asked first in a spar). Practising
  茅山道术 costs 10 mana and 30 sen; a mind astray (random(sen) below 5) conjures a 观想虫 (or,
  with more 基本咒文, a 观想兽) that attacks at once and stays until it dies, blocking practice;
  killed by the player's own hand it teaches 基本咒文, killed by anyone else (the 天将 or 阴鬼卒
  of 召护法, asked first) it knocks the player out. A save leaves it out. 驱尸 (50 mana, 30 sen)
  raises a selected corpse as its victim's zombie, whose things fall where it lay: it follows the
  player from room to room and map to map, and each heal_up takes 10 灵力 and 1 精 from them
  (我...需...要...你...的...力...量...) until they are down to 10, when it falls apart into blood.
  On a 桃符纸 (two lie in Snow's 城隍庙) the player draws a 僵尸追魂符 with the selected NPC's
  name (20 mana, 40 sen and a drop of blood); put on the zombie, it goes after that one while the
  player stands by (its kill is theirs), then falls apart. Asked first: when the cost would knock
  the player out, and against their own master.
* **Across both**: each zone shows its ES2 room title and description (on arrival and via 观察);
  rooms reset on world time (killed NPCs come back, wanderers go home, gone floor items return);
  semi-automatic encounter combat with Flee and 投降, told in ES2's combat lines, death/corpse/loot, waking from
  unconsciousness and reincarnation at the Snow temple after death,
  inventory/equipment with stacks (give, drop or put part of one), eating/drinking, using drugs,
  recovery and conditions (蛇毒, 醉酒, 蒙汗药; a drug poured into a drink), the status card, toasts and panels, manual Save/Continue.
* Combat: weapons and bare hands draw ES2's verbs, mapped martial arts their moves (柳家拳,
  封山剑法, 天邪神掌, 六阴追魂剑法), dodges read the mapped dodge skill's lines (倒乱七星步法,
  火蝠身法); armor, weapon and NPC
  `apply/*` bonuses and internal power count: force_factor on every landed blow, and a bare-handed
  blow against stronger force is thrown back (std/force.c, told in the battle log).
* Placeholder visuals: flat-colour terrain tiles; characters and objects are still coloured boxes.
  No art or audio yet.

Coverage of ES2 content ([region plan](ROADMAP.md#region-plan)): 228/551 rooms, 107/286 NPC
types, 5/10 joinable families, 18/36 special and 13/25 basic martial arts, 50/84 quest targets.

## Known issues

Code:

* A failed attack chain ends the fight with 战斗出错，已中止。 (development builds log why); the
  cause still has to be fixed in the content or rule that tripped it.
* Beasts cannot be asked to spar (ES2's `fight` on a beast is a one-sided kill); attack them.
* 刘安禄's 刘老三/血手刘三 are not listed until his reveal is ported. The Inn's travellers stay in
  the Inn (its exits all lead to other maps; only the player's zombie follows them onto another map). Corpses never decay, so the
  corpses of NPCs that came back stay.
  NPCs never flee a losing fight (`wimpy`) and do not follow who flees (`pursuer`).
  The dog takes no bone (no
  chicken leg, no following); nothing can be put into a corpse.
* With the pacing knobs, 打坐 from max_force 0 to 50 takes about 2.4 hours of play at con 30
  (6.4 at ES2's pace); `tests/runtime/run_with_max_force.gd` gives a playtest 49. combat_exp 0 to
  1001 (朱鸿雪's quests) still takes some 6–12 hours with a family's skills: past about 150 few
  opponents are of the strength ES2 gives exp for. Conditions do not tick
  in a fight (owner) nor while the player lies unconscious.
* A zone that merges several rooms shows only its first room's text.
* 绮云镇: 牛腿 is a hammer only (food that is also a weapon is not supported), so it leaves no
  牛腿骨; 熟牛肉 is not in the game (nobody sells it in ES2); a carried 布袋 is not opened.
  朱鸿雪 and 化缘和尚 cannot be fought until their arts are ported (#7, #8).
* Persistence classes keep `OldPine*` / `oldpine_*` names (20 classes, some 130 files) and the session
  scene is still `scenes/world/oldpine/oldpine_world_session.tscn`, although they cover every map
  (the Session itself is `WorldSessionController` since the map-controller split); pre-B2 Old Pine
  regression suites drive combat through a test-only manual cadence
  (`historical_world_combat_fixture.gd`).
* The legacy technical fixture (`CombatSliceContentProfile` defaults, demo factory) keeps its own
  copy of the long sword's facts.
* Only Simplified Chinese exists. English and other languages without measure words will need
  their own count phrases and number words, and ES2's combat lines person and pronoun rules
  (你 punches / he punches); see [LOCALIZATION](LOCALIZATION.md). Log lines written before a
  language switch stay in the old language, and so does a dead zombie's name on its corpse
  (saved as shown) and the name labels made before the switch.
* Room labels and NPC names overlap in places (grey-box layout). An NPC that walks away from the
  player stays selected (its actions are refused, kill.c `present()`); one the player walks away
  from does not.

Platforms: Windows and Android release builds; iOS is an unsigned compile only. Real touch-device
qualification for Lake and Shared UI is deferred. The provisional app ID
`com.example.easternstoriesgodot` must be replaced before signing.

Licensing: no root project license; ES2 rights are unresolved
([LICENSE_PROVENANCE](LICENSE_PROVENANCE.md)). Settle before any public distribution.

## How to verify

See [BUILD](BUILD.md). Full gate: `python tools/ci/verify.py --godot <godot>` (~3 min locally; fails on a
`SCRIPT ERROR` line, or when `python tools/l10n/extract_pot.py` was not run after a text change). Single suites: `<godot> --headless --path game --script res://tests/run_suite.gd
-- <suite paths>`. The generated maps (all but Snow's Inn and streets): edit `tools/maps/layouts/<region>.json`, then
`python -m tools.maps.paint` (the tools tests fail on a hand-edited one). A longer soak: `ES_SOAK_HOURS=8` before the `world_soak_test` suite (8 hours
passed).
