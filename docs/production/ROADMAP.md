# Roadmap

## Goal

A native Godot RPG — rules and movement on 2D maps, every map shown in a fixed-angle voxel view
(owner, 2026-10-22) — that carries ES2's content and rules — regions, NPCs, items, skills,
families, quests — with modern maps, movement and UI, reliable Save/Continue, and a coherent
start → early → middle → late play chain. Faithful to the LPC where it matters; deliberate
single-player adaptations are owner decisions recorded in
[DECISIONS](../migration/DECISIONS.md). No release date is set; steady, playable progress matters
more than speed.

Progress is measured by playable content packages, not documents, commits or assertion counts.
[PROJECT_SCOPE](PROJECT_SCOPE.md) tracks per-package dispositions.

## Region plan

Work goes region by region. A region is done when its rooms, NPCs, shops, family, martial arts and
quest targets are playable. A system is built when a region first needs it and generalized when
its second consumer arrives. The order follows ES2's exits out of Snow (雪亭镇) and the strength of
each region's NPCs; families close to Snow come early because ES2's new players join one there.
Re-estimate the schedule after each region.

| # | Region (source) | Way in | Rooms | NPC types | Families | Martial arts | Quest targets | Build first |
|---|---|---|---|---|---|---|---|---|
| 0 | 雪亭镇 (`d/snow`) | start | 37/38 | 22/27 | 1/1 封山剑派 | 8/9 | 15/15 | Leftovers only: five NPCs no room places (乞丐 stands in 绮云镇's 斋院); 柳淳风's spider-array. The temple's two 桃符纸 came with 茅山 D. 安惜迩's celestrike and six-chaos-sword came with 水烟阁 A. |
| 1 | 老松岭 (`d/oldpine`) | 山路 (Snow) south | 41/41 | 12/13 | — | 1/1 | 5/5 | Done: remainder A (keep and gate trap, caves, berserk, bury) and B (conditions on the heart beat, combined items, 金银花蛇, 黑衣人). 土匪老大 never comes in ES2 (fat_bandit.c's call never fires). |
| 2 | 野羊山 (`d/goathill`) | 山坳 north | 15/16 | 7/8 | — | 1/1 | 5/5 | Done: two maps, the second hand, hammers' bash_weapon (broken weapons), 伏蛟功. cavern1.c.c is a stray copy and 银色岩蛭 is placed by nothing (owner: as LPC). |
| 3 | 卧龙岗 + 绮云镇 (`u/cloud/dragonhill`, `u/cloud`) | Snow street south | 43/43 | 28/32 | 1/1 振远镖局 | 1/9 | 16/19 | 3A done: streets and shops, the ridge's toll, the thief's steal, 春风快意刀. 3B done: joining 振远镖局 (betrayal, 基本刀法, practice with a blade; the letter waits for #9). 3C done: 朱鸿雪's quests, killer_reward() for the player, 投降, the garrison's vendetta. 3D done: the 宝官's betting; no marriage (it needs a second player). The 江北渡口 ferry crosses with #8 (山烟寺 A); 化缘和尚 can be fought and the 护寺武僧 (u/cloud/npc/monk_guard.c) stand in 山烟寺's yard. |
| 4 | 水烟阁 (`d/waterfog`) | 青石官道 (Snow) west | 28/28 | 11/12 | 1/1 天邪派 | 7/7 | 0/0 | A done: three maps, the eighteen NPCs and their arts (celestrike, six-chaos-sword, pyrobat-steps), 萧辟尘's consider(), the 正门's weapon gate, look-only signs. B done: joining 天邪派 (萧辟尘's oath button, 於兰天武's three-blow test asked first, recruit.c's offer), both masters' teaching (his privs 0), stormdance, the 武者's join. C done: 天邪神功 for the player (powerup, powerfade and its faint, 天邪虎啸 pulling the room in), 杀气's berserk (never at one's master, a one-time warning) and look.c's glare. 小天邪虎 is placed by nothing (as LPC). |
| 5 | 青石村 (`d/green`) | 山坳 east | 39/39 | 14/18 | 1/1 绝尘派 | 4/5 | 1/1 | A done: three maps, the villagers and what create() draws, the 迷阵 as passages, exit rules on combat_exp and the master, room verbs (push, search, the web's spiders, hang), 放弃 in 绝地. B done: the 玉佩 and 蒙汗药 (pour, drunk and slumber_drug). C done: 绝尘派 (绝尘子 and his 遁 and 召天将 with a summoned soldier on his side, joining as a taoist, magic-array, tao-mystery, jingang-staff, juechen-force, 冥思 and 修行, 法力 and 灵力). D done: the player's spells (遁 to Snow's temple ending the fight, 困, 召天将 on the player's side; no_magic rooms; select_opponent() for an NPC with several enemies). Not placed, as LPC: kid5, 龙若法王 (does not compile), s.c, shen1.c. |
| 6 | 茅山 灵心观 (`d/temple`) | 山路 (Snow) east | 25/27 | 15/15 | 1/1 茅山派 | 3/3 | 8/8 | A done: three maps (the climb, the grounds, the 经楼's upper floor), the fifteen kinds with their gear, the guards drawn at each reset, the moss, the invisible wall, 召护法 and its 阴鬼卒. B done: joining 茅山派 (林忌 takes men only, answering two seconds later; his three-a-day count never ran out in ES2), the two 弟子's teaching, 谷衣心法 and its 灵神诀, 天师正道, 天师剑法. C done: practising 茅山道术 and its 观想虫/观想兽 (killed by the player's hand for 基本咒文, by anyone else knocking the player out), 召护法 asked first in a spar and against one's own 观想虫, 攻击 at an NPC lying unconscious. D done: 驱尸 (the zombie follows the player across maps and lives on their 灵力), 桃符纸 and 僵尸追魂符 (the zombie goes after the one named while the player stands by). broom1/2 are copies nothing leads into; earth-warp is not offered (astral_vision came with 鬼门关 B as 阴阳眼). |
| 7 | 晚月庄 (`d/latemoon`) | 绮云镇 west | 74/74 | 36/50 | 1/1 晚月庄 | 11/11 | 12/12 | A done: five maps (the halls, the two secret rooms one way in, the 湘园, the tower's upper floor, the paths and the bamboo grove; sroad1.c repaired), the 37 kinds with their arts (柔虹指, 寒雪鞭法, 雪影剑法 and 心法, 意寒功's iceshock and 意寒睨), rose_poison, the dances in the two 密室, rigidity, no_drop. 东方神教 takes no apprentice (not a family to join). B done: the women's quarters' greetings by gender and class (the kick, the powder, the doors, 凤凰, 区冥), a man asked before the changing room and the bath, the bath, the pistils, 缀芳阁's ponder, the closet's skirts, 雨梅's tea cup. C done: the secrets (筱薇's 竹蜻蜓 for 芳绫's secret and the 玛瑙手镯's pray to Snow's temple, 莫欣芳's 舞曲谱 from the 密室's bed with 音律 and 「春宫怨」, the 丝罗巾's 基本行动, the 杀手令牌 for 无名老妇's force or 寒雪鞭法, the 火摺 and 芙云's 密函). D done: 晚月庄 the family (蓝止萍's two-second answer, women only, class dancer; 瑷伦's three lashes for commoners of 100000, 晚月庄第一代弟子; 安妮儿 refuses; the members teach; the player's 柔虹指, 寒雪鞭法, 意寒功 and 意寒睨). Region complete. |
| 8 | 泓水南岸 + 山烟寺 (`u/cloud/sunhill`, `d/sanyen`) | ferry from 绮云镇; tunnel from 晚月庄 | 26/26 | 9/9 | 1/1 山烟寺 | 3/3 | 6/6 | Plan (owner): A the region, B 山烟寺 the family and the player's arts, C 八识神通's 神通. A done: two maps (日照山, the temple), the ford and the boatman's boat (Q1), the tunnel from 晚月庄, front_yard.c repaired (Q2), the monks with 流云杖法 and 莲华心法, accept_fight by class, the steamer, random_move in a fight. B done: 剃度 (asked first, a 法名), 玄智's two-second answer (monks only), his twelve skills, the player's 大乘佛法, 诵经, 流云杖法, 莲华心法 with 疗伤他人 on the selected NPC, 八识神通 learnt and enabled. C done: 空识 and 游识 on the 武学 page, 心识 on the HUD, 游识 to an NPC the player has met (Q3; saved), a refused 拜师 ends (默认). |
| 9 | 乔阴县城 (`d/choyin`, `d/jail`) | 泓水南岸 east | 61/62 | 29/30 | 2/2 步玄派, 花紫会 | 10/10 | 6/6 | Plan (owner): A the maps and the people, B the town's secrets and 姑射山, C 步玄派, D 花紫会, stealing and the 县衙. A done: fourteen maps (every room but the doorless 石室; the rooms only verbs reach drawn, their ways in B and C), the people with 步玄七诀 (玄羽乱舞), 小步玄剑, 步玄心法, 油流麻香手 (broken bones), 短歌刀法, 秋风步; vendors, the well, the hotel guards' and 红衣武士's accept_kill() (owner: as meant), the crone's deaf line (owner), the 采药老者 (山药蛋, pills, his ghost story), 风泉剑灵 and its chant; the 北门's north stays shut (owner, as ES2). B done: the stone lion's lift, the 护草神兽 and the player's 忘忧草 (smelt to 振远镖局, 陈剑秋's letter; 陈天星 waits for #12), the 树王坟's hole (Q2), unseen ghosts (Q3: perception, no corpse; 咒剑王禅's hit_ob()), the 武官's chest and 白杨经, the vines, the cranes fought (beast.c's default action), the 缚仙绳, the 云幡, the 丹炉's 仙丹, the 寒谷's orchid, the hermit's books, the 荷包. C done: 骆云舟 takes one the 桃林 let out (marks 书生 and 桃林), the 桃林 deep in the peach woods (its 字条, the way it names a step nearer and any other three further, 放弃), his thirteen skills (乐器 added), the player's 步玄七诀, 小步玄剑, 步玄心法 and 玄羽乱舞 on the battle panel (perform move.hasten), 风泉剑灵's chant waits while the player is away and is saved (owner, option A). D done: 陆得财 takes only one with less than a silver on them (look, can_afford(100)) as a beggar and teaches his eleven skills; the player's 油流麻香手 and 伏蛟功 (practised by water; the basic force's exerts); the player's steal (what is worn or wielded, or 随手摸一样; asked first from the clearly stronger; caught, a fight to the death and a mark as a thief, forgotten a reset, halved at death, 惯窃 above ten); the 县衙 repaired (Q1): eight 巡捕 with drawn names patrol the main street, catch a thief seven times in ten and lead them to the 大堂, 程不平's boards by formula, ten gold bribes them free. Region done but for 北冥大鹏 and the 石室 (no way in, as ES2). |
| 10 | 天驼关 (`d/canyon`) | 青石官道 (Snow) southwest | 25/27 | 10/10 | — | 6/6 | 8/8 | Plan (owner): A the pass, the camp and the people, B the 印鉴 chain (the swear a button, Q3), C the 竹林道 (repaired, Q1: canyon2.c gets its west exit; the two 整修中 rooms are not placed). A done: three maps (the clifftop, the pass with the camp, the 兵器库), the chain climbed both ways, the ten kinds with their arts (all ported before), 大队长's toll adding up (Q2) and his story, 李信 throwing out the unlisted, the 将军营帐 for the listed. B done: 赫造基's secret, the oath at the smooth wall into the 兵器库, the 后备兵's fake and real 印鉴, 严廷殷's 古剑. C done: the 黄石穿林路 off canyon2's repaired west exit, the mirror, the 竹林道, the great yellow stone (force, max_force, 加力) and its gap into the stone room, the bookcase's 书匣 and the 悟疾风劲竹书 (parry to 50); a carried container's 取出. Region done but for dream/tmp.c and evil/tmp.c (整修中). |
| 11 | 玉螺湖村 (`d/village`) | 天驼关 south | 26/26 | 8/9 | — | 9/9 | 0/0 | Plan (owner): A the village, the lake and the people; B the 瓜地 (the pick, the 瓜农's catch, 还瓜钱 that pays: modern fixes). B done: the pick by kar, the 瓜农 coming over to the death (asked first when stronger), the way held while he stands, 还瓜钱 on the HUD and the battle panel; region done. A done: three maps (the village, the boat on the lake's middle, the ice cave), the lake no walk, the boat out and back, the dive repaired (Q1: asked first) into the ice cave (放弃), the grass's way west for five seconds, the six 白鳞冰龙 all at once, the 西瓜 that feeds and quenches thirst, lordhouse3.c repaired to load (its shelf mechanism unported); flowergirl.c in the room directory is a stray copy. |
| 12 | 京师 (`d/city`, `u/cp`) | 玉螺湖村 south | 55/55 | 21/27 | 振远镖局's head office | 20/20 | 0/0 | Plan (owner): A the city, its shops and people; B 尚书府 and the secrets (Q1 (b) the 出城令牌 as ES2, Q2 (a) the 地下密室's stairs from below; M1–M4 默认). A done: two maps (the city inside its walls with the 北驿道, the 太白酒楼's upper floor), the 18 守城兵 turning everyone back at the five shut gates, seven vendors and the bank, the 店小二's stairs (marks/酒楼 for ten taels), 陈天星 taking 陈剑秋's letter (asked first) and the player, the 行人's draws, 桃X仙's get/wear/wield all, 密宗大手印 and 铁布衫. Correction: the real doors are four, all in 尚书府 (create_door() for a missing exit errors elsewhere). B done: 尚书府 (the 门房's three taels of gold, the 护院's drawn names and skills, 庾子建, 庾清尘, the 花匠, the 丫鬟, four doors, 小无相功), the 院墙 (爬上去, 跳进去 to the 废屋), the altar's button and the 地下密室 (opened from below, Q2 (a)), 废园's flash and find and the 守城兵 taking the 出城令牌 (the gates stay shut). Region done; the six NPC files placed by no room stay unplaced. |
| 12b | 黑松山 (`d/chuenyu`), repaired | 黄土大道's spur west (玉螺湖村) | 32/37 | 14/23 | — | 7/7 | 0/0 | Plan (owner): A the road, the mountain and the castle; B the 地牢, 淳于怀太 and 小娟, 刘老农's thanks and revenge (Q2 (a): once; F1–F4: 娟儿 beside, follows every way, attacking her asked first, only the player leads her). A done: two maps (the road, the paddies, the mountain and the castle; 淳于's upper floor), the spur west off the 黄土大道 (ES2 had no way in), the gate's killing air below 2000 combat_exp, the 夹道's arrows (world hazards), the vine walls climbed into the gardens, the bridge's chain, the 紫衣家丁's look (random(per)), the 护院, the killer dogs, 烤山猪肉 food and a hammer (牛腿 too). The copy of 刘家 is not placed (Q1 (a): ES2 cut it off; it lives in 玉螺湖村). B done: the main hall's rope (asked first) into the 地牢 (nine rooms as passages, M3), 淳于怀太, the 狱卒 and rats, the slab out to the east clifftop, 小娟 crying for help and following the player every way (saved on any map), attacking her asked first; 刘老农's thanks with her beside (銮鱼衡冰, 过招要旨; both leave for good) or his revenge once (悲愤欲绝 until his room resets, M7). Region done; npc/xiaojuan.c is a copy placed by no room. |
| 13 | 鬼门关 (`d/death`) | dying | 9/12 | 3/3 | — | — | — | Plan (owner): A 阴间 and the way back, B 阴阳眼 and the 孤魂野鬼's 布条. A done: one map walked south to north (奈何桥 with its four 阴鬼牙将, 鬼门关, 酆都城门 with no way back, the 鬼门大道 and its two houses, the long road that turns on itself until the fifth try, its end a wall of fog: Q3); a dead player is a ghost and, past the death card, stands before the white gargoyle, whose five lines bring them back to the Snow temple (he holds still while talking: Q2); the black gargoyle does the same, the little shop's double answers 回家; a ghost sees ghosts, cannot eat, may Save (Continue at 鬼门关) and dies again without a corpse. block.c and jail.c (wizard rooms) and spath1.c (no way in) are not placed. B done: 茅山道术's 阴阳眼 (30 mana, 5 sen, as many seconds as 基本咒文) lets the living see ghosts, so 乔阴's 孤魂野鬼 is fought for its 布条 (基本咒文 to 40). |
| | **Total** | | **536/551** | **239/286** | **9/9** | **33/36** special, **22/26** basic | **84/84** | |

How the columns count (`reference/es2/mudlib`, 2026-10-04). The maps a package names are the ones
it built; since 地图重构 every building is a map of its own.

* **Rooms**: room files of the region. **NPC types**: NPC files of the region, including the ones
  only code spawns; a family master under `daemon/class` counts where a room places it.
* **Families**: joinable ones — a master who takes apprentices stands in a room of the region.
* **Martial arts**: non-basic skills the region's NPCs use or teach; an art used in several
  regions shows in each row and once in the total. Basic skills (unarmed, sword, blade, parry,
  dodge, force, literate, magic, spells, staff, throwing, …) are counted apart. Totals recounted
  2026-10-17 from `common/skills.json` against the placed NPCs' `set_skill()`/`map_skill()`
  (basic now 26 with 鬼门关's fork; axe, dagger, fork and hammer have no skill definition yet,
  though NPCs carry their levels).
* **Quest targets**: distinct names in `quest/qlist*.c` that live in the region (84 names, 220
  live entries over 15 combat_exp tiers; 33 more are commented out); one counts once an NPC of that name is placed and can be
  fought, so 朱鸿雪 can give it. `tests/fixtures/quest_targets.json` is the list (the total counts
  县城官兵, obj/npc/garrison.c, placed in 绮云镇): a region package that places a target re-records
  it with `UPDATE_QUEST_TARGETS=1`.

Not planned (owner may revisit): `d/graveyard` (2 rooms, no way in); `d/wiz` (wizard
rooms); the four class masters no room places (月牙神教, 日陀罗寺, 逍遥派, 鬼笠馆浪人) and the ten arts
only they or nobody use; `d/npc` (wizard-saved characters).

## Alongside the regions

* **Combined items** (`std/item/combined.c`): built with Old Pine B (蛇药, 飞刀, 化尸粉); a room's
  floor holds them since 茅山 D (Snow's 桃符纸).
* **Modern fixes** (2026-10-06, owner): ES2 behaviour that reads as a bug to today's players gets
  the reasonable behaviour as a recorded deviation (AGENTS.md); the first batch is done.
* **Pacing**: `common/pacing.json`'s knobs are tuned from owner playtests; the slow stretch is a
  new character's combat_exp from about 150 to 1001 (few opponents of the right strength).
* **Maps**: every map is `tools/maps/layouts/` data drawn by the painter to the scale standard
  (`tools/maps/standard.json`: streets, doors, facades and room classes in body widths); a town
  shows its streets and facades, and every enterable room is on its building's own map behind its
  door. New content is drawn the same way. Every map also gets its voxel view, dressed to the
  richness standard (AGENTS.md「Maps and art」); furniture is a blocked box with a `look` in the
  layout, decor is the map's `game/data/<region>/voxel/<map>.json`.
* **Presentation**: the voxel maps (below), characters and animation, audio, consistent Chinese UI.
* **Voxel maps** (owner, 2026-10-22): 雪亭镇's inn (both floors) and street are done. Next, region by
  region in the table's order: Snow's shops and rooms, then each region's maps, every room dressed
  and lit; per region a mobile frame-rate check (Android export) before moving on.

## After the grey box

Owner direction (2026-10-11). Once every region in the table is playable, the work turns from
breadth to the player's experience, in this order. Each step is one or a few packages. **Owner
decision:** the owner has no time to playtest package by package until then, so the playtest
acceptance that `AGENTS.md` requires for player-visible work is batched: packages of the remaining
regions and of steps 1–2 ship with the agent's windowed walkthrough as their live check and are
accepted together at step 3, the owner's one full playtest; what it finds is fixed in step 4.

1. **Responsiveness and playability pass (现代化修正 III).** Audit every reaction the player waits
   for because ES2 bound it to a heart beat or `call_out()` — a master answering 拜师 two seconds
   later, the toll's two seconds, the thief's three, the drunk's thirst, waking, dissolving a
   corpse, berserk on the next tick, NPC healing ticks. Rule: a reaction to something the player
   just did is immediate (or a staged beat under half a second); world simulation keeps its ticks
   but shows what it does; deliberately dramatic sequences (三招, 三鞭) keep their pacing and show
   progress. Each change is a data knob whose ES2 value is recorded (`pacing.json`,
   [DECISIONS](../migration/DECISIONS.md)). Same pass: scene-transition fades, movement feel,
   interaction prompts, camera, a battle-round knob. Owner, 2026-10-15: A = the waits (reaction
   beat, 三招/三鞭 told 0.7 s a blow, 继续 for told sequences, waits on the card), B = the feel (fades,
   battle presentation and a 慢/标准/快 battle-speed setting, movement, prompts and speech
   bubbles, camera).
2. **UI overhaul** (owner, 2026-10-15: before step 1; A = the menu window and its tabs, B = gamepad,
   C = the 任务 journal and the 百科). One menu window with tabs (角色, 武学, 背包, 任务, 声望, 系统) replaces the
   separate panels; the HUD keeps only what play needs; gamepad support (input map, focus
   navigation, LB/RB tab switching, A/B confirm/cancel, button glyphs in prompts) alongside mouse
   and touch. The 任务 tab starts as a journal of 朱鸿雪's task and the story chains' progress;
   声望 is a placeholder until step 6.
3. **Playtest checklist and the owner's first full playtest.** Claude first walks every region
   windowed and fixes what that finds, then writes the checklist: per region and system, what to
   do, what should happen, and what only the owner can judge (feel, pacing, wording), with fields
   for time taken, confusion and defects; dev launchers reach late content without grinding. The
   owner works through it once.
4. **Fixes and pacing from the playtest.** The defect list, 润色 2, and the pending decisions
   A2 (exp pacing, quest deadlines) and A6 (all-attack-at-once) from
   [STATUS](STATUS.md#待决定).
5. **The 游戏圣经.** First a one-page canon questionnaire for the owner (the dozen choices that
   fix the story: the emperor and 水烟阁, what 东方神教 wants, who betrayed 南危水, whether the
   prophecy is real, what 岚城 is …), then the bible: timeline, politics and geography, each
   faction's origin, values, taboos, hierarchy and its own reading of the key events, key
   characters and their secrets, rules of conduct that become reputation axes, open mysteries as
   quest hooks, and a style guide. [WORLD_RELATIONS](WORLD_RELATIONS.md) is its inventory.
6. **Quest and reputation systems.** Quest data with steps, conditions, triggers, rewards and
   mutual exclusion; the journal; per-faction standing with a deed table; dialogue variants by
   standing, deed, family and gender; a reputation page. Then the main story's first chapter and
   the first faction lines, in the sandbox with the player's own character.
7. **Voxel maps and characters**, in parallel from step 2: the voxel rollout above for every
   map; then characters (bodies, faces, clothing by family and class) and animation.

## Later — release readiness

Systematic playtesting and balance, device qualification (touch, iOS runtime), formal player-save
baseline, product IDs/signing, and resolving [license/provenance](LICENSE_PROVENANCE.md) — the ES2
rights question must be settled before any public distribution.

## History

Phases 1–10, combat redesign, Snow/Old Pine packages, Migration Tooling v1, Lake and Shared UI are
recorded in git history, PRs #1–#25 and the historical `PHASE_*` / `MIGRATION_TOOLING_V1_*` files
under `docs/migration/`. The workflow reset, data-driven content, the generic map runtime, Snow
complete, localization and the combat packages (death, new-player combat, offense/defense routes,
internal power, combat talk and specials) are PRs #26–#51.
