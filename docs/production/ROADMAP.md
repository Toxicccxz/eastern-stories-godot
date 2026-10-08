# Roadmap

## Goal

A native 2D Godot RPG that carries ES2's content and rules — regions, NPCs, items, skills,
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
| 0 | 雪亭镇 (`d/snow`) | start | 37/38 | 22/27 | 1/1 封山剑派 | 8/9 | 15/15 | Leftovers only: five NPCs no room places (乞丐 stands in 绮云镇's 斋院), 桃符纸 (with the player's spells); 柳淳风's spider-array. 安惜迩's celestrike and six-chaos-sword came with 水烟阁 A. |
| 1 | 老松岭 (`d/oldpine`) | 山路 (Snow) south | 41/41 | 12/13 | — | 1/1 | 5/5 | Done: remainder A (keep and gate trap, caves, berserk, bury) and B (conditions on the heart beat, combined items, 金银花蛇, 黑衣人). 土匪老大 never comes in ES2 (fat_bandit.c's call never fires). |
| 2 | 野羊山 (`d/goathill`) | 山坳 north | 15/16 | 7/8 | — | 1/1 | 5/5 | Done: two maps, the second hand, hammers' bash_weapon (broken weapons), 伏蛟功. cavern1.c.c is a stray copy and 银色岩蛭 is placed by nothing (owner: as LPC). |
| 3 | 卧龙岗 + 绮云镇 (`u/cloud/dragonhill`, `u/cloud`) | Snow street south | 43/43 | 26/32 | 1/1 振远镖局 | 1/9 | 15/19 | 3A done: streets and shops, the ridge's toll, the thief's steal, 春风快意刀. 3B done: joining 振远镖局 (betrayal, 基本刀法, practice with a blade; the letter waits for #9). 3C done: 朱鸿雪's quests, killer_reward() for the player, 投降, the garrison's vendetta. 3D done: the 宝官's betting; no marriage (it needs a second player). Left: the 江北渡口 ferry crosses once #8 exists. |
| 4 | 水烟阁 (`d/waterfog`) | 青石官道 (Snow) west | 28/28 | 11/12 | 1/1 天邪派 | 7/7 | 0/0 | A done: three maps, the eighteen NPCs and their arts (celestrike, six-chaos-sword, pyrobat-steps), 萧辟尘's consider(), the 正门's weapon gate, look-only signs. B done: joining 天邪派 (萧辟尘's oath button, 於兰天武's three-blow test asked first, recruit.c's offer), both masters' teaching (his privs 0), stormdance, the 武者's join. C done: 天邪神功 for the player (powerup, powerfade and its faint, 天邪虎啸 pulling the room in), 杀气's berserk (never at one's master, a one-time warning) and look.c's glare. 小天邪虎 is placed by nothing (as LPC). |
| 5 | 青石村 (`d/green`) | 山坳 east | 39/39 | 14/18 | 1/1 绝尘派 | 4/5 | 1/1 | A done: three maps, the villagers and what create() draws, the 迷阵 as passages, exit rules on combat_exp and the master, room verbs (push, search, the web's spiders, hang), 放弃 in 绝地. B done: the 玉佩 and 蒙汗药 (pour, drunk and slumber_drug). C done: 绝尘派 (绝尘子 and his 遁 and 召天将 with a summoned soldier on his side, joining as a taoist, magic-array, tao-mystery, jingang-staff, juechen-force, 冥思 and 修行, 法力 and 灵力). D done: the player's spells (遁 to Snow's temple ending the fight, 困, 召天将 on the player's side; no_magic rooms; select_opponent() for an NPC with several enemies). Not placed, as LPC: kid5, 龙若法王 (does not compile), s.c, shen1.c. |
| 6 | 茅山 灵心观 (`d/temple`) | 山路 (Snow) east | 0/27 | 0/15 | 0/1 茅山派 | 1/2 | 0/8 | Spells' second consumer (necromancy, gouyee, zombie helpers); a master who takes three apprentices a day. |
| 7 | 晚月庄 (`d/latemoon`) | 绮云镇 west | 0/74 | 0/50 | 0/2 晚月庄, 东方神教 | 1/11 | 0/12 | Conditions' second consumer (rose_poison), a female-only family, doors in 27 rooms, room verbs (dancing, order, pray, pick). |
| 8 | 泓水南岸 + 山烟寺 (`u/cloud/sunhill`, `d/sanyen`) | ferry from 绮云镇; tunnel from 晚月庄 | 0/26 | 0/9 | 0/1 山烟寺 | 0/3 | 0/4 | The ferry crossing; the monks' family (buddhism, chanting, lotusforce, cloudstaff, essencemagic). |
| 9 | 乔阴县城 (`d/choyin`, `d/jail`) | 泓水南岸 east | 0/62 | 0/30 | 0/2 步玄派, 花紫会 | 1/10 | 0/6 | Recruiting gated by a mark (桃林) or by poverty (花紫会), stealing, music arts, the 县衙 (bribe, tie). |
| 10 | 天驼关 (`d/canyon`) | 青石官道 (Snow) southwest | 0/27 | 0/10 | — | 2/6 | 0/8 | Climb and search verbs, the army camp (soldiers of 40k–900k exp), the 竹林道 and 梦幻迷境 side areas. |
| 11 | 玉螺湖村 (`d/village`) | 天驼关 south | 0/26 | 0/9 | — | 5/9 | 0/0 | Boats (paddle) and diving to the lake bottom. |
| 12 | 京师 (`d/city`, `u/cp`) | 玉螺湖村 south | 0/55 | 0/27 | 振远镖局's head office | 5/18 | 0/0 | Doors in 16 rooms, seven shops, the second 振远镖局 master (陈天星). |
| 13 | 鬼门关 (`d/death`) | dying | 0/12 | 0/3 | — | — | — | The ghost realm instead of today's direct revival at the Snow temple (owner decision when we get there). |
| | **Total** | | **203/551** | **91/286** | **3/10** | **12/35** special, **10/25** basic | **42/84** | |

How the columns count (`reference/es2/mudlib`, 2026-10-04):

* **Rooms**: room files of the region. **NPC types**: NPC files of the region, including the ones
  only code spawns; a family master under `daemon/class` counts where a room places it.
* **Families**: joinable ones — a master who takes apprentices stands in a room of the region.
* **Martial arts**: non-basic skills the region's NPCs use or teach; an art used in several
  regions shows in each row and once in the total. Basic skills (unarmed, sword, blade, parry,
  dodge, force, literate, magic, spells, staff, throwing, …) are counted apart.
* **Quest targets**: distinct names in `quest/qlist*.c` that live in the region (84 names, 220
  live entries over 15 combat_exp tiers; 33 more are commented out); one counts once an NPC of that name is placed and can be
  fought, so 朱鸿雪 can give it. `tests/fixtures/quest_targets.json` is the list (the total counts
  县城官兵, obj/npc/garrison.c, placed in 绮云镇): a region package that places a target re-records
  it with `UPDATE_QUEST_TARGETS=1`.

Not planned (owner may revisit): `d/chuenyu` 黑松淳于 (37 rooms, 23 NPCs) — its only exit leads to
the village, but no room or code leads in; `d/graveyard` (2 rooms, no way in); `d/wiz` (wizard
rooms); the four class masters no room places (月牙神教, 日陀罗寺, 逍遥派, 鬼笠馆浪人) and the ten arts
only they or nobody use; `d/npc` (wizard-saved characters).

## Alongside the regions

* **Combined items** (`std/item/combined.c`): built with Old Pine B (蛇药, 飞刀, 化尸粉); Snow's
  桃符纸 waits for the player's spells.
* **Modern fixes** (2026-10-06, owner): ES2 behaviour that reads as a bug to today's players gets
  the reasonable behaviour as a recorded deviation (AGENTS.md); the first batch is done.
* **Pacing**: `common/pacing.json`'s knobs are tuned from owner playtests; the slow stretch is a
  new character's combat_exp from about 150 to 1001 (few opponents of the right strength).
* **Maps**: every map is `tools/maps/layouts/` data drawn by the painter (Snow's streets and Inn
  were the last hand-made ones); a region's new maps are drawn the same way.
* **Presentation**: art direction and assets, audio, animation, consistent Chinese UI.

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
