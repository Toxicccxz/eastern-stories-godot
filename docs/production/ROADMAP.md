# Roadmap

## Goal

A modern wuxia RPG built on ES2 (owner, 2026-10-23; DECISIONS「产品定位」; AGENTS.md "Mission"):
rules and movement on 2D maps, every map shown in a fixed-angle voxel view (owner, 2026-10-22). ES2's
world — regions, NPCs, items, skills, families, quests and their text — is the foundation; where its
rules, pacing or presentation would put a modern player off we change them, keeping ES2's value as the
经典模式 knob, and owner-approved new content fills its gaps. Every change is recorded in
[DECISIONS](../migration/DECISIONS.md). No release date is set; steady, playable progress matters
more than speed.

Progress is measured by playable content packages, not documents, commits or assertion counts.
What is built now, what waits for the owner's playtest and what is next is in [STATUS](STATUS.md).

## Region plan

Every region below is playable: its rooms, NPCs, shops, family, martial arts and quest targets.
The table is the coverage count and why the rest is not placed; its order is the order the voxel
view goes through the regions.

| # | Region (source) | Way in | Rooms | NPC types | Families | Martial arts | Quest targets | Not placed, and why |
|---|---|---|---|---|---|---|---|---|
| 0 | 雪亭镇 (`d/snow`) | start | 37/38 | 22/27 | 1/1 封山剑派 | 8/9 | 15/15 | 药铺密室 (no entrance); five NPCs no room places (乞丐 stands in 绮云镇's 斋院); 柳淳风's spider-array. |
| 1 | 老松岭 (`d/oldpine`) | 山路 (Snow) south | 41/41 | 12/13 | — | 1/1 | 5/5 | 土匪老大 never comes in ES2 (fat_bandit.c's call never fires). |
| 2 | 野羊山 (`d/goathill`) | 山坳 north | 15/16 | 7/8 | — | 1/1 | 5/5 | cavern1.c.c is a stray copy; 银色岩蛭 is placed by nothing (owner: as LPC). |
| 3 | 卧龙岗 + 绮云镇 (`u/cloud/dragonhill`, `u/cloud`) | Snow street south | 43/43 | 28/32 | 1/1 振远镖局 | 1/9 | 16/19 | No marriage (it needs a second player). |
| 4 | 水烟阁 (`d/waterfog`) | 青石官道 (Snow) west | 28/28 | 11/12 | 1/1 天邪派 | 7/7 | 0/0 | 小天邪虎 is placed by nothing (as LPC). |
| 5 | 青石村 (`d/green`) | 山坳 east | 39/39 | 14/18 | 1/1 绝尘派 | 4/5 | 1/1 | kid5, 龙若法王 (does not compile), s.c, shen1.c (as LPC). |
| 6 | 茅山 灵心观 (`d/temple`) | 山路 (Snow) east | 25/27 | 15/15 | 1/1 茅山派 | 3/3 | 8/8 | broom1/2 are copies nothing leads into; earth-warp is not offered. |
| 7 | 晚月庄 (`d/latemoon`) | 绮云镇 west | 74/74 | 36/50 | 1/1 晚月庄 | 11/11 | 12/12 | 东方神教 takes no apprentice (not a family to join). |
| 8 | 泓水南岸 + 山烟寺 (`u/cloud/sunhill`, `d/sanyen`) | ferry from 绮云镇; tunnel from 晚月庄 | 26/26 | 9/9 | 1/1 山烟寺 | 3/3 | 6/6 | — |
| 9 | 乔阴县城 (`d/choyin`, `d/jail`) | 泓水南岸 east | 61/62 | 29/30 | 2/2 步玄派, 花紫会 | 10/10 | 6/6 | 北冥大鹏, and the 石室 (no way in, as ES2). |
| 10 | 天驼关 (`d/canyon`) | 青石官道 (Snow) southwest | 25/27 | 10/10 | — | 6/6 | 8/8 | dream/tmp.c and evil/tmp.c (整修中). |
| 11 | 玉螺湖村 (`d/village`) | 天驼关 south | 26/26 | 8/9 | — | 9/9 | 0/0 | lordhouse3.c's shelf mechanism; flowergirl.c in the room directory is a stray copy. |
| 12 | 京师 (`d/city`, `u/cp`) | 玉螺湖村 south | 55/55 | 21/27 | 振远镖局's head office | 20/20 | 0/0 | The six NPC files placed by no room; the five outer gates stay shut (as ES2). |
| 12b | 黑松山 (`d/chuenyu`), repaired | 黄土大道's spur west (玉螺湖村) | 32/37 | 14/23 | — | 7/7 | 0/0 | The copy of 刘家 (ES2 cut it off; it lives in 玉螺湖村); npc/xiaojuan.c is a copy placed by no room. |
| 13 | 鬼门关 (`d/death`) | dying | 9/12 | 3/3 | — | — | — | block.c and jail.c (wizard rooms), spath1.c (no way in). |
| 14 | 关北 (native, 剧情总纲 §6) | the gate in 天驼关 valley's east wall | 25 native | 36 | — | — | — | Done in four packages (`build/plans/关北_计划.md`, DECISIONS「关北 A」–「关北 D」). |
| | **Total** | | **536/551** | **239/286** | **9/9** | **33/36** special, **22/26** basic | **84/84** | |

How the columns count (`reference/es2/mudlib`, 2026-10-04):

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
  the reasonable behaviour as a recorded deviation (AGENTS.md "Changing ES2").
* **Pacing**: `common/pacing.json`'s knobs are tuned from owner playtests and the A2 simulation
  (`tests/sim/`); A2 (DECISIONS「经验节奏」) fills a new character's 150 to 1001 with one-time 历练,
  落后补偿, the 雪亭驿 bounties and the 武馆's 木人.
* **Maps**: every map is `tools/maps/layouts/` data drawn by the painter to the scale standard
  (`tools/maps/standard.json`: streets, doors, facades and room classes in body widths); a town
  shows its streets and facades, and every enterable room is on its building's own map behind its
  door. New content is drawn the same way. Every map also gets its voxel view, dressed to the
  richness standard (AGENTS.md「Maps and art」); furniture is a blocked box with a `look` in the
  layout, decor is the map's `game/data/<region>/voxel/<map>.json`.
* **Presentation**: the voxel maps (below), characters and animation, audio, consistent Chinese UI.
* **Voxel maps** (owner, 2026-10-22): done for 雪亭镇, 老松岭, 野羊山, 卧龙岗 + 绮云镇, 水烟阁, 青石村,
  茅山 灵心观, 晚月庄, 泓水南岸 + 山烟寺, 乔阴县城 and 天驼关 (101 maps). Next, region by region in the table's order — 玉螺湖村 first — each widened for the voxel view
  first (DECISIONS「地图尺寸以体素视角为准」), every room dressed and lit; then 雪亭镇's facades in more
  detail. Desktop frame rate is the bar (DECISIONS「首发只做桌面」).

## After the grey box

Owner direction (2026-10-11). Every region in the table is playable, so the work turns from breadth
to the player's experience, in this order; the voxel rollout above runs alongside. **Owner
decision:** the owner has no time to playtest package by package, so the playtest acceptance that
`AGENTS.md` requires for player-visible work is batched: packages ship with the agent's windowed
walkthrough as their live check and are accepted together at step 1, the owner's one full playtest;
what it finds is fixed in step 2. What waits for it is listed in [STATUS](STATUS.md#待试玩).

1. **Playtest checklist and the owner's first full playtest.** Claude first walks every region
   windowed and fixes what that finds, then writes the checklist: per region and system, what to
   do, what should happen, and what only the owner can judge (feel, pacing, wording), with fields
   for time taken, confusion and defects; dev launchers reach late content without grinding. The
   owner works through it once.
2. **Fixes and pacing from the playtest.** The defect list, 润色 2, and the decision left for the
   playtest: A2's quest deadlines ([STATUS](STATUS.md#待决定)).
   **战斗决策层** comes before 现代基线三件 (owner 2026-10-31; the plan `build/plans/战斗决策层_计划.md`): 1A 数值 is done
   (DECISIONS「战斗数值」: the Elo-shaped hit curve, the defender's discount, the bounded experience defense, the 战前预判, the first two
   hours' enemies by tier); 1B 决策 is done (DECISIONS「战斗决策」: the round that waits for the player, the move chosen with 快 / 重 / 虚 /
   守 and their counters, the enemy's next move shown, the three stances, specials telegraphed and cooled down); 包 2 界面 and 包 3 演出
   are done (DECISIONS「战斗界面」「战斗演出」: the cards, the short lines, the move titles, floats, shakes, falls and the 胜 / 败 stamp);
   包 4 内容 is done (DECISIONS「战斗内容」: every school's moves tagged, the NPCs' fight styles and the specials' rest, 识招 and the
   见识录, the courage draw shown as 守势, the first two hours' fights measured again). The decision layer is complete; what is left is
   the owner's playtest (STATUS 待试玩).
   **现代基线三件** (owner 2026-10-28; `build/plans/现代基线_提示词.md`, order A → C → B): A is done (DECISIONS「存档位」「自动存档」
   「减轻死亡」: three manual slots and a rolling autosave written on a worker, a Load in play, death at 3% experience with the corpse
   waiting and a way back to the autosave); C is done (DECISIONS「数值用到才出现」: 法力, 灵力, 杀气 and 加力 appear when used, a line
   for every number, the keys and the pad read every hover); B is done (DECISIONS「总图」: the 地图 page, voxel land with real miniatures and
   roads worn into it, marks, 指路 along walked roads). Coach routes and fast travel stay for later: nothing in B needs them.
3. **The 游戏圣经 → [剧情总纲](../design/剧情总纲.md).** The canon (three creative baselines, the
   false tomb, timeline, politics, geography), the main story (prologue, ten chapters, finale), the
   twelve faction lines, the five new regions and the style guide are that one document; its §9
   holds the three questions the owner answers. [WORLD_RELATIONS](WORLD_RELATIONS.md) stays its
   inventory.
4. **Quest and reputation systems**, in the order 剧情总纲 §8 gives: quest data with steps,
   conditions, branches, mutual exclusion and rewards; map markers (on the 总图); a deed record that
   reputation, titles and the ending grow from; per-faction standing (the menu's 声望 tab is its
   placeholder). Done so far (DECISIONS「任务系统」): the quest data and ledger, the 任务 page's four
   columns, the marker on the current map (the 总图 reads the same route), the thinnest deed record,
   and 寻剑令's first half as the sample; then (DECISIONS「剧情演出」) the prologue's second half (the pass scene: the player stands,
   the camera follows the speakers) and chapter one 伪墓 on 老松岭, with the stage (NPCs and items by quest state), the keep's parley
   and the burial as mechanisms every later chapter reuses; chapter two 旧案 (绮云镇 + 水烟阁: the letter, the 镖单, the two
   inscriptions, 南危水, 潘军禅, the choice) on data alone; chapter three's entrance (主线 C: 刘安禄 spared or 黄霸 telling of the
   tribute, the cart and its escort under the crack at 野羊山's turn, the quest stopping at 「逆灵宫就在裂口上头」); then the new
   regions in chapter order (逆灵宫 first, from that crack; 皇城 and 岚城 last). 逆灵宫 (the plan `build/plans/逆灵宫_计划.md`, owner
   2026-10-29): A done (DECISIONS「逆灵宫 A」: the crack's top and the gate, the three ways up — under the oil-cloth, the escort beaten,
   黄霸's 黑冠 — the 道士 taking the crowned player for their own); B done (DECISIONS「逆灵宫 B」: the 前殿, 丹房 and 账房, the ledger and
   the 兵部 papers read, the dungeon with 霍铮, 石头 and the 关北 men behind iron doors that want a key, the chapter waiting at the
   后殿); C done (DECISIONS「逆灵宫 C」: the 唤首 scene with the headless shade, the 鬼卒, the keyed jailer, the one-or-the-other
   choice — the rescue home to the 土地庙 and 黄霸's yield, or the chase to the cliff and 玄冥子's 残卷 — the chapter done either way);
   D done (DECISIONS「逆灵宫 D」: the turn's bandits let the rescuer be under the parley, 刘安禄 back to the stockade, the 农妇 with
   her son, 黄霸 grown after the chase, 玄冥子's 六阴剑 hook) — the region is complete. 剧情总纲 §8 第 5 步 (the chapters in existing
   regions) has begun: chapter four 宝衣 on 晚月庄 is done (DECISIONS「第四章 宝衣」: 瑷伦's lashes for anyone, the 冰匣 danced open, the
   three-way end and the night after; the plan `build/plans/第四五章_计划.md`); chapter five 人证 on 乔阴 is done (DECISIONS「第五章 人证」:
   the drum opens the 衙门大门, 程不平 wants a witness, 陈显祖 the deserter escorted through 庾家's men or released, the trial either way
   and his letter to 槐阳王). 第 4 步 goes on in 关北 (the plan `build/plans/关北_计划.md`, owner 2026-10-30): A done (DECISIONS「关北 A」: the
   印鉴 chain read anew at 天驼关 — 严廷殷's letter, 赫造基's mould, the 后备兵 on the 印色, the mould compared with the 兵部 papers; the gate in
   the valley's east wall with its four ways past the soldiers; the 关外山道, 槐阳城's gate, street and the 王府's front, the 马市 with 卢卡, the
   塞外酒肆 with 老秦; the chapter waiting at the 王府's door); B done (DECISIONS「关北 B」: the 王府大门 knocked open with the letter, 程朔 and
   his hall, 南危水 home beside his brother on the 保密 ledger with the reunion scene, the choice 借兵／潜入 with 郭承 following); C done (DECISIONS「关北 C」:
   the camp, the steppe, the 工地 and the 古冢口; the raid with the 王府's riders fighting beside the player and every 枷 opened, or the night's sneak after
   等到天黑 with four freed and the watch down; `phase`, `until_phase`, `fights_beside_player`); D done (DECISIONS「关北 D」: the two roads'
   consequences at the gate, the hall, the camp and the steppe; 《马刀谱》 and 关北马刀; the seventh chapter's stub). 第 4 步's second region is
   done; next per §8: 第七章 番坊 (a new coast region — a plan first).
5. **Characters and animation** after the voxel maps: bodies, faces, clothing by family and class;
   then audio.

Waiting for the owner, not scheduled: the rest of the 2026-10-19 presentation list (odds bands, a
spar record, a 江湖履历, 正邪 jobs).

## Later — release readiness

Systematic playtesting and balance, a formal player-save baseline, product IDs/signing, and
resolving [license/provenance](LICENSE_PROVENANCE.md) — the ES2 rights question must be settled
before any public distribution. The first release is desktop only; a mobile port (touch, iOS
runtime, phone frame rate; draft PR #161) may follow (DECISIONS「首发只做桌面」). Large new
expansions after the first release belong to a later version.
