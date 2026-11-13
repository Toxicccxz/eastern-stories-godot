# Roadmap

## Goal

A modern wuxia RPG built on ES2 (owner, 2026-10-23; DECISIONS「产品定位」; AGENTS.md "Mission"):
rules and movement on 2D maps, every map shown in a fixed-angle voxel view (owner, 2026-10-22). ES2's
world — regions, NPCs, items, skills, families, quests and their text — is the foundation; where its
rules, pacing or presentation would put a modern player off we change them through data knobs (one
game, no 经典模式: DECISIONS「取消经典模式」), and owner-approved new content fills its gaps. Every change is recorded in
[DECISIONS](../migration/DECISIONS.md). No release date is set; steady, playable progress matters
more than speed.

Progress is measured by playable content packages, not documents, commits or assertion counts.
What is built now, what waits for the owner's playtest and what is next is in [STATUS](STATUS.md).

## Region plan

Every region below is playable: its rooms, NPCs, shops, family, martial arts and quest targets.
The table is the coverage count and why the rest is not placed; rows 0–13 are ES2's regions,
14–18 the native ones (剧情总纲 §6).

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
| 14 | 关北 (native, 剧情总纲 §6) | the gate in 天驼关 valley's east wall | 25 native | 32 | — | — | — | Done in four packages (`build/plans/关北_计划.md`, DECISIONS「关北 A」–「关北 D」). |
| 15 | 番坊 (native, 剧情总纲 §6) | the south end of the path outside 忘情谷 (玉螺湖村) | 19 native | 23 | 3 铁盾会, 鬼笠馆, 日陀罗寺 | — | — | A–D done (`build/plans/番坊_计划.md`, DECISIONS「番坊 A」–「番坊 D」). |
| 16 | 逆灵宫 (native, 剧情总纲 §6) | the crack above 野羊山's mountain-road turn | 17 native | 17 | — | — | — | A–D done (`build/plans/逆灵宫_计划.md`, DECISIONS「逆灵宫 A」–「逆灵宫 D」). |
| 17 | 皇城 (native, 剧情总纲 §6) | the 铁门 north of 京师's 午门 | 21 native | 28 | — | — | — | 第九章 A–E done (`build/plans/第九章_计划.md`, DECISIONS「第九章 A」–「第九章 E」). |
| 18 | 岚城 (native, 剧情总纲 §6) | the upper way in the mirror of 天驼关's stone forest | 18 native | 10 | — | — | — | 第十章 A–C done (`build/plans/第十章_计划.md`, DECISIONS「第十章 A」–「第十章 C」). |
| | **Total** (ES2 rows) | | **536/551** | **239/286** | **9/9** | **33/36** special, **26/26** basic | **84/84** | |

How the columns count (`reference/es2/mudlib`, 2026-10-04):

* **Rooms**: room files of the region. **NPC types**: NPC files of the region, including the ones
  only code spawns; a family master under `daemon/class` counts where a room places it.
* **Families**: joinable ones — a master who takes apprentices stands in a room of the region.
* **Martial arts**: non-basic skills the region's NPCs use or teach; an art used in several
  regions shows in each row and once in the total. Basic skills (unarmed, sword, blade, parry,
  dodge, force, literate, magic, spells, staff, throwing, …) are counted apart. Totals recounted
  2026-10-17 from `common/skills.json` against the placed NPCs' `set_skill()`/`map_skill()`
  (basic 26 with 鬼门关's fork; axe, dagger, fork and hammer were defined in DECISIONS「审查收尾」).
* **Native rows**: rooms are the region's zones in `game/data/<region>/world.json`, NPC types the
  definitions in its `npcs.json`; map counts are in [STATUS](STATUS.md#已实现) only.
* **Quest targets**: distinct names in `quest/qlist*.c` that live in the region (84 names, 220
  live entries over 15 combat_exp tiers; 33 more are commented out); one counts once an NPC of that name is placed and can be
  fought, so 朱鸿雪 can give it. `tests/fixtures/quest_targets.json` is the list (the total counts
  县城官兵, obj/npc/garrison.c, placed in 绮云镇): a region package that places a target re-records
  it with `UPDATE_QUEST_TARGETS=1`.

Not planned (owner may revisit): `d/graveyard` (2 rooms, no way in); `d/wiz` (wizard
rooms); the two class masters no room places (月牙神教, 逍遥派; 日陀罗寺's and 鬼笠馆浪人's
stand in 番坊, DECISIONS「番坊 D」) and the arts only they or nobody use; `d/npc` (wizard-saved characters).

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
* **Presentation**: the voxel maps, characters and animation, audio, consistent Chinese UI.
* **Voxel maps** (owner, 2026-10-22): every map of every region has its voxel view, and a new map gets
  one in its own package (the counts are in STATUS's region table). Desktop frame rate is the bar
  (DECISIONS「手机端暂停」).

## After the grey box

Owner direction (2026-10-11): every region in the table is playable, so the work turns from breadth
to the player's experience; the steps below are the plan, not a fixed order — the owner approves each
package as it comes. **Owner decision:** the owner has no time to playtest package by package, so the
playtest acceptance that `AGENTS.md` requires for player-visible work is batched: packages ship with
the agent's windowed walkthrough as their live check and are accepted together at step 1, the
owner's one full playtest. The owner has deferred that playtest since (each later package was
approved ahead of it); it has not happened yet. What waits for it is listed in
[STATUS](STATUS.md#待试玩).

1. **Playtest preparation and the owner's first full playtest.** First the preparation package: the
   checklist grouped by the main story's route (per chapter and system: what to do, what should
   happen, what only the owner can judge — feel, pacing, wording — with fields for time taken,
   confusion and defects), dev launchers that start at chapter N with the story state and experience
   of that chapter, and a tagged build that stays fixed while the owner plays (a world revision bump
   breaks saves). Then the owner works through it once.
2. **Fixes and pacing from the playtest.** The defect list, 润色 2, and the decisions left for the
   playtest ([STATUS](STATUS.md#待决定)). The growth curve comes with it: a plan with simulated numbers
   for the time 请教 and 打坐 take, a repeatable source of experience after about 22,000, each
   chapter's 历练 and the player's 气 that does not grow (whole-project review「数值曲线与成长节奏」).
3. **The 游戏圣经 → [剧情总纲](../design/剧情总纲.md)** (done): the canon, the main story (prologue,
   ten chapters, finale), the twelve faction lines, the five new regions and the style guide.
   [WORLD_RELATIONS](WORLD_RELATIONS.md) is the frozen inventory of the ES2 layer.
4. **Quest and reputation systems, then the stories**, in the order 剧情总纲 §8 gives. The quest
   system, the main story from the prologue to the finale and the five native regions are done
   (STATUS). Next: the faction lines' first batch (`build/plans/势力线第一批_计划.md`, owner
   2026-11-09): 封山 A and B are done; 天邪 A／B, 逆灵宫 A／B／C, 东方神教 A／B and 虹台大会 A／B
   follow, then the later batches of 剧情总纲 §4.
5. **Characters and animation.** Character looks and portraits are done for everyone with a face
   (DECISIONS「人物外观」). Animation and effects come in seven packages (owner 2026-11-12), the first
   (DECISIONS「战斗肢体」) done; the rest (blade light and impact, specials and school colours,
   inner-power and spell states, …) wait for the owner's look at the first. Then audio (today only
   13 project-made battle sounds, no music).

Waiting for the owner, not scheduled: the rest of the 2026-10-19 presentation list (odds bands, a
spar record, a 江湖履历, 正邪 jobs).

## Later — release readiness

Systematic playtesting and balance, a formal player-save baseline, product IDs/signing, and
resolving [license/provenance](LICENSE_PROVENANCE.md) — the ES2 rights question must be settled
before any public distribution. The first release is desktop only (Steam); the mobile port
(Android / iOS, phone frame rate; draft PR #161) is **paused** and CI builds no mobile target
(owner 2026-11-04, DECISIONS「手机端暂停」). Steam Deck support stays in scope: pad, resolution
and window mode, the 16:10 screen. Large new expansions after the first release belong to a later
version.
