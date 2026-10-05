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
| 0 | 雪亭镇 (`d/snow`) | start | 37/38 | 20/27 | 1/1 封山剑派 | 6/9 | 0/15 | Leftovers only: 乞丐, the blade 旅客, five NPCs no room places; 柳淳风's spider-array, 安惜迩's celestrike and six-chaos-sword. |
| 1 | 老松岭 (`d/oldpine`) | 山路 (Snow) south | 41/41 | 10/13 | — | 1/1 | 0/5 | Remainder A done (keep and gate trap, caves, berserk, bury). B: conditions (金银花蛇's 蛇毒; 蛇药 cures it), combined items (蛇药, 黑衣人's 飞刀 and 化尸粉). 土匪老大 never comes in ES2 (fat_bandit.c's call never fires). |
| 2 | 野羊山 (`d/goathill`) | 山坳 north | 0/16 | 0/8 | — | 0/1 | 0/5 | Nothing new expected (bandits and leeches): a speed check. |
| 3 | 卧龙岗 + 绮云镇 (`u/cloud/dragonhill`, `u/cloud`) | Snow street south | 0/43 | 0/32 | 0/1 振远镖局 | 0/9 | 0/19 | Quest system (朱鸿雪 hands out `quest/qlist*` by combat_exp), 赌场 betting, 红娘庄 marriage, eleven vendors, the 江北渡口 ferry (crosses once #8 exists). |
| 4 | 水烟阁 (`d/waterfog`) | 青石官道 (Snow) west | 0/28 | 0/12 | 0/1 天邪派 | 2/7 | 0/1 | Joining by oath (swear), NPC exert, master-level specials (萧辟尘, 於兰天武, the elders); blade arts' second consumer, so family and teacher data are generalized here. |
| 5 | 青石村 (`d/green`) | 山坳 east | 0/39 | 0/18 | 0/1 绝尘派 | 0/5 | 0/1 | The player's spells (magic, spells, 法力; magic-array, tao-mystery), the 迷阵 maze, room verbs (push, search, hang, fillwater), staff arts. |
| 6 | 茅山 灵心观 (`d/temple`) | 山路 (Snow) east | 0/27 | 0/15 | 0/1 茅山派 | 1/2 | 0/8 | Spells' second consumer (necromancy, gouyee, zombie helpers); a master who takes three apprentices a day. |
| 7 | 晚月庄 (`d/latemoon`) | 绮云镇 west | 0/74 | 0/50 | 0/2 晚月庄, 东方神教 | 1/11 | 0/12 | Conditions' second consumer (rose_poison), a female-only family, doors in 27 rooms, room verbs (dancing, order, pray, pick). |
| 8 | 泓水南岸 + 山烟寺 (`u/cloud/sunhill`, `d/sanyen`) | ferry from 绮云镇; tunnel from 晚月庄 | 0/26 | 0/9 | 0/1 山烟寺 | 0/3 | 0/4 | The ferry crossing; the monks' family (buddhism, chanting, lotusforce, cloudstaff, essencemagic). |
| 9 | 乔阴县城 (`d/choyin`, `d/jail`) | 泓水南岸 east | 0/62 | 0/30 | 0/2 步玄派, 花紫会 | 1/10 | 0/7 | Recruiting gated by a mark (桃林) or by poverty (花紫会), stealing, music arts, the 县衙 (bribe, tie). |
| 10 | 天驼关 (`d/canyon`) | 青石官道 (Snow) southwest | 0/27 | 0/10 | — | 2/6 | 0/9 | Climb and search verbs, the army camp (soldiers of 40k–900k exp), the 竹林道 and 梦幻迷境 side areas. |
| 11 | 玉螺湖村 (`d/village`) | 天驼关 south | 0/26 | 0/9 | — | 5/9 | 0/0 | Boats (paddle) and diving to the lake bottom. |
| 12 | 京师 (`d/city`, `u/cp`) | 玉螺湖村 south | 0/55 | 0/27 | 振远镖局's head office | 5/18 | 0/0 | Doors in 16 rooms, seven shops, the second 振远镖局 master (陈天星). |
| 13 | 鬼门关 (`d/death`) | dying | 0/12 | 0/3 | — | — | — | The ghost realm instead of today's direct revival at the Snow temple (owner decision when we get there). |
| | **Total** | | **78/551** | **30/286** | **1/10** | **6/35** special, **6/25** basic | **0/87** | |

How the columns count (`reference/es2/mudlib`, 2026-10-04):

* **Rooms**: room files of the region. **NPC types**: NPC files of the region, including the ones
  only code spawns; a family master under `daemon/class` counts where a room places it.
* **Families**: joinable ones — a master who takes apprentices stands in a room of the region.
* **Martial arts**: non-basic skills the region's NPCs use or teach; an art used in several
  regions shows in each row and once in the total. Basic skills (unarmed, sword, blade, parry,
  dodge, force, literate, magic, spells, staff, throwing, …) are counted apart.
* **Quest targets**: distinct names in `quest/qlist*.c` that live in the region (87 names, 253
  entries over 15 combat_exp tiers). They count once the quest system exists (#3); before that a
  region's targets are just its NPCs and items.

Not planned (owner may revisit): `d/chuenyu` 黑松淳于 (37 rooms, 23 NPCs) — its only exit leads to
the village, but no room or code leads in; `d/graveyard` (2 rooms, no way in); `d/wiz` (wizard
rooms); the four class masters no room places (月牙神教, 日陀罗寺, 逍遥派, 鬼笠馆浪人) and the ten arts
only they or nobody use; `d/npc` (wizard-saved characters).

## Alongside the regions

* **Combined items** (`std/item/combined.c`): amounts that merge and split — 蛇药, Snow's 桃符纸 and
  the travellers' 飞刀. Built with the first region that needs one.
* **Pacing knobs**: data-configured multipliers (default = original) decided from owner playtests;
  first: exercise gain or kee recovery (owner chose this for max_force 0 → 50, 8–16 hours at ES2's
  pace).
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
