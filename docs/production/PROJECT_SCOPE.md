# Project Scope Ledger

## Purpose and evidence boundary

Per-package disposition ledger for the [ROADMAP](ROADMAP.md); not a second roadmap or a complete
LPC inventory. Update a row when a package changes status; current state lives in [STATUS](STATUS.md). The "Groups" column refers to the earlier A–I
planning groups (A Lake, B martial progression, C exploration, D Snow/Old Pine template, E second
region, F content packages, G content closure, H quality, I release).

The project is a modern wuxia RPG built on ES2 (root `AGENTS.md` "Mission"; DECISIONS「产品定位」):
ES2's world, rules and text are the foundation; rules, pacing or presentation that would put a
modern player off are changed as recorded deviations, with ES2's value kept as the 经典模式 knob;
owner-approved new content may fill the world's gaps; every map gets a fixed-angle voxel view
(DECISIONS「固定俯视体素地图」). This ledger tracks ported ES2 scope, those changes and new content as
separate rows.

Rows are bounded capability/content packages with stable IDs. “Integrated” applies only to the
stated completed boundary; it never means the entire category, every NPC, or every player path is
finished. Core support, runtime composition, normal-player reachability and actual acceptance are
separate claims. Historical analysis identifies dependencies; current code and later integration/
owner decisions supersede its early capability snapshots. No old scan count is used as a current
remaining total. There is no computed completion percentage, schedule or promised finish month.

Player-visible packages merged since 2026-10-11 are accepted together at the owner's full
playtest (ROADMAP「After the grey box」); until then their acceptance is the agent's windowed
walkthrough. Content beyond ES2 enters only through an owner-approved plan and gets its own row.

## Status vocabulary and maintenance

| Status | Meaning |
|---|---|
| UNANALYZED / 未分析 | A candidate package exists in planning, but source contract/dependencies are not sufficiently established. |
| DECISION_PENDING / 待决定 | Evidence identifies a real scope/compatibility/acceptance choice awaiting the owner. |
| IMPLEMENTATION_PENDING / 待实现 | Identified planned work is absent; this label alone grants no implementation permission. |
| IMPLEMENTED_PENDING_ACCEPTANCE / 已实现待验收 | Implementation exists with specified acceptance still open; not an integrated product claim. Use only with actual implementation evidence. |
| ENGINEERING_ACCEPTED_PENDING_INTEGRATION / 工程验收完成待集成 | The owner-approved engineering scope is accepted; PR/merge/post-merge gates remain. Device or release qualifications stay explicit. |
| INTEGRATED / 已集成 | The stated bounded capability has integrated evidence; exclusions and qualification limits remain explicit. |
| EXCLUDED_BY_OWNER / 明确不迁移 | An explicit owner/project mandate excludes the stated subject. Cite that authority; temporary deferral is not exclusion. |

Each row's status applies to its named scope. Separate remaining packages rather than labelling
an entire category complete. Preserve IDs as scope is refined; add evidence/disposition at genuine
phase boundaries, not at every commit. Record source-backed behavior, approved Native substitutions
and unresolved interpretations distinctly. Retain useful historical tests while applying the
[development save policy](contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy).
Progress is a working content/capability loop, not a count of commits, assertions or migrated files.
Rows cite their owning content notes, decisions or reports; documentation alone does not establish runtime evidence.

## Regions, population and creatures

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| REG-001 — Snow core and Old Pine connection | [SNOW_CONTENT](../migration/SNOW_CONTENT.md), [Snow final](../migration/PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md), [NGE connection](../migration/PHASE_NEW_GAME_ENTRY_SNOW_OLDPINE_CONNECTION.md) | Inn, streets, core services and the ordinary inter-region journey | Rest of Snow is REG-004 | INTEGRATED | D | Keep existing route/state continuity. |
| REG-002 — Old Pine | [OLDPINE_CONTENT](../migration/OLDPINE_CONTENT.md), [river/cliff/pine record](../migration/PHASE_9B3B3_RIVER_CLIFF_PINE_ROUTE.md) | All 41 rooms on nine maps, laid out where the room texts put them (DECISIONS「老松林按原文方位排布」): pine, vine, waterfall, river, cliffs, Lake, tree, caves and keep | 土匪老大 never comes in ES2 (fat_bandit.c's call never fires) | INTEGRATED | A/C/D | Preserve the recorded topology and one-way constraints. |
| REG-003 — Lake production package | [Final Audit](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_FINAL_AUDIT.md) | Continuous route/five snakes/Fill; real mouse fifth target, manual Attack, Flee, death/corpse, two exact cold restores and complete local verification | Touch qualification waits for a mobile port (PLATFORM-001) | INTEGRATED | A | Owner-revised engineering scope accepted; controlled QA is not natural full-strength victory. |
| REG-004 — remaining Snow interiors/connections | [SNOW_CONTENT](../migration/SNOW_CONTENT.md), [ROADMAP row 0](ROADMAP.md#region-plan) | 37/38 rooms: south road, 书院, smithy, herbshop, post office, Hockshop storage, Inn upstairs, school inner rooms, weapon storage and secret storage; exits to 卧龙岗, 水烟阁 and 天驼关 | 药铺密室 (herbshop1.c) has no entrance anywhere in ES2 and is not placed; five NPC files no room places; 柳淳风's spider-array | INTEGRATED | D/E/F | Region done; the leftovers are recorded, not invented. |
| REG-005 — full Cave / Keep packages | [OLDPINE_CONTENT](../migration/OLDPINE_CONTENT.md), DECISIONS「Old Pine remainder A」「Old Pine remainder B」 | Keep and gate trap, caves and cliff2, berserk, burial and its rewards; conditions on the heart beat, combined items, 金银花蛇, 黑衣人 | — | INTEGRATED | C | Done with Old Pine remainder A and B. |
| REG-006 — the ES2 world beyond Snow and Old Pine | [ROADMAP region plan](ROADMAP.md#region-plan), the per-region `docs/migration/*_CONTENT.md` notes, `game/data/*/world.json` | Fifteen regions playable: 雪亭镇, 老松岭, 野羊山, 卧龙岗 + 绮云镇, 水烟阁, 青石村, 茅山, 晚月庄, 泓水南岸 + 山烟寺, 乔阴县城, 天驼关, 玉螺湖村, 京师, 黑松山 (way in repaired) and 鬼门关 (阴间); 536/551 rooms, nine joinable families | What each region leaves unplaced (ROADMAP "Not placed, and why"); not planned: `d/graveyard`, `d/wiz`, the four class masters no room places, `d/npc`; the owner's full playtest | INTEGRATED | E/F/G | Owner may revisit the not-planned list; repairs of ES2 ways in are recorded in DECISIONS. |
| REG-007 — new content beyond ES2 | Root `AGENTS.md` "Mission", DECISIONS「产品定位」, ROADMAP「After the grey box」 (游戏圣经, quest and reputation systems), [WORLD_RELATIONS](WORLD_RELATIONS.md) | None yet; WORLD_RELATIONS inventories the hooks | The owner's canon questionnaire and the world bible, then an owner-approved plan per region, family, NPC set or story line | DECISION_PENDING | F/G | New content needs an owner-approved plan, fits the bible and is marked as not ES2 in its data. |
| POP-001 — existing Old Pine production NPC slots | [Lake current-code analysis](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md#b-serpent-facts-identity-and-initialization) | Five human slots (three scouts, Tall, Fat), existing combat/death/Save scope | Now part of the per-spawn-point population (POP-003) | INTEGRATED | A/D | Preserve actual identity/lifecycle. |
| POP-002 — Beast / ordinary serpent foundation | [Beast final](../migration/PHASE_BEAST_FOUNDATION_SERPENT_FINAL_AUDIT.md) | Beast defaults/body/action/intrinsics and serpent runtime/persistence, used by every region's beasts | Beasts cannot be asked to spar (as ES2's `fight`) | INTEGRATED | A | Reuse source rules; QA wounded victory is not natural victory or balance proof. |
| POP-003 — region populations | [ROADMAP region plan](ROADMAP.md#region-plan), the per-region content notes, [Save contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md) | 239/286 NPC types placed, one NPC record per authored spawn point; talk, wander, inquiry, teaching, trade, recognition and room resets; NPC memory saved | NPC files no room places (per region); `wimpy` and `pursuer` not modelled (STATUS Known issues) | INTEGRATED | C/D/F | Unplaced files stay listed with their reason. |

## Martial arts, growth, items and economy

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| GROW-001 — shared skill/training foundations | [Skill Core](../migration/PHASE_3A_SKILL_CORE.md), [Cultivation](../migration/PHASE_3B1_CULTIVATION.md), [Practice/SelfLearning](../migration/PHASE_3B2_PRACTICE_SELFLEARN.md), [Learn](../migration/PHASE_3C1_LEARN_CORE.md), DECISIONS「连续修炼」「上限预览和拜师条件」 | Typed raw/learned/mapping/progression, learn/practice/cultivate with the 武学 page, continuous training and limit previews | axe, dagger, fork and hammer have no skill definition yet (ROADMAP column notes) | INTEGRATED | B/E/F | Reuse one authority. |
| GROW-002 — Liu/basic unarmed/Liuh-Ken | [first progression final](../migration/PHASE_SNOW_FIRST_PROGRESSION_FINAL_AUDIT.md), [Liuh final](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_FINAL_AUDIT.md) | Physical school/contact, apprenticeship/Learn, Liuh mapping/actions/feedback and persistence | 柳淳风's spider-array | INTEGRATED | B/D | Preserve existing bounded closures. |
| GROW-003 — internal power player loop | `game/core/internal_power/`, DECISIONS「Internal power in combat: enforce, exert, the force hit」, [Cultivation](../migration/PHASE_3B1_CULTIVATION.md) | Obtain → enable → cultivate → enforce/exert in combat → Save, for the basic force and each family's force (封山派内功, 天邪神功, 谷衣心法, 莲华心法 …) | Balance at the owner's playtest | INTEGRATED | B1 | One cultivation system. |
| GROW-004 — sword/defense and training entry | DECISIONS「Offense/defense routes A」「Offense/defense routes B」「The player's perform: 封山剑法's 封, 逐, 缺」 | sword/parry/dodge, 封山剑法 with 封/逐/缺, 倒乱七星步, practice and self-learn prerequisites | — | INTEGRATED | B2/B3 | Actual effects, not names/levels alone. |
| GROW-005 — Study and advanced/faction-specific abilities | The per-region content notes, [WORLD_RELATIONS](WORLD_RELATIONS.md) §5.2 | Literacy and books (魏无极, 李师师, study items); each joinable family's arts with the player's perform/exert/cast (天邪神功, 茅山道术, 绝尘派 spells, 八识神通, 步玄七诀 …) | earth-warp (broken in ES2); the ten arts only unplaced masters use | INTEGRATED | C/E/F | Trace acquisition/prerequisites and actual behavior per art. |
| ITEM-001 — inventory/equipment/death infrastructure | [item persistence](../migration/PHASE_4B5A_NATIVE_ITEM_SAVE_RESTORE.md), [corpse](../migration/PHASE_4B5C_DEATH_INVENTORY_CORPSE.md), [Save contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md) | Shared item IDs, containment, stacks/currency, equipment/armor, combined items, carried containers, corpse/loot and decay, persistence | Nothing can be put into a corpse; a carried 布袋 is not opened (STATUS Known issues) | INTEGRATED | A/C/F | Preserve current graph/identity/atomicity. |
| ECON-001 — livelihood and supply loop | [Core Hub final](../migration/PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md), [Hockshop final](../migration/PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_FINAL_AUDIT.md), DECISIONS「经验节奏」 | Work, money/Bank, Eat/Drink/Fill, Hockshop Value/Sell, vendors in every region, the 雪亭驿 bounty board | Economy balance at the owner's playtest | INTEGRATED | C/D/F | Keep the loot→money→supplies loop. |
| ECON-002 — further goods, treatment and reward uses | The per-region content notes | Region vendors and services, healing and poisons, rewards with in-game consumers | 熟牛肉 (nobody sells it in ES2) | INTEGRATED | C/D/F | Incomplete source offers are resolved as recorded deviations, not invented. |

## Events, world lifecycle and persistence

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| EVENT-001 — ES2 quests/inquiry/local mechanisms | [WORLD_RELATIONS](WORLD_RELATIONS.md) §5, `game/data/common/quests.json`, `game/data/common/journal.json` | 朱鸿雪's timed quests (84/84 targets placed), each region's story chains and room mechanisms, inquiry, the 任务 journal and 百科 | What WORLD_RELATIONS §5.4 lists as unported | INTEGRATED | C/D/F/G | Remaining ES2 items stay listed with their reason. |
| EVENT-002 — quest and reputation systems | ROADMAP「After the grey box」, [WORLD_RELATIONS](WORLD_RELATIONS.md) §6 | The menu's 声望 tab is a placeholder | Quest data (steps, conditions, triggers, rewards, exclusion), per-faction standing, dialogue variants; then the main story's first chapter (REG-007) | IMPLEMENTATION_PENDING | F/G | After the world bible; the main story comes through an owner-approved plan. |
| WORLD-001 — resident maps and death lifecycle | [resident maps](../migration/PHASE_9B3B1_OLDPINE_WORLD_SESSION_MAP_LIFETIME.md), DECISIONS「别的地图时间补算」「尸体腐烂」「鬼门关 A: 阴间 and the way back」, [Save contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md) | Every map resident; maps away from the player are caught up when the player returns; slots, tombstones and decaying corpses persist; death walks 阴间 and back | On the player's own map a wanderer moves only where the player is (ES2's heart beat) | INTEGRATED | A/E/F | Preserve scoped behavior. |
| WORLD-002 — conditions, treatment and update consumers | [Conditions](../migration/PHASE_2B_CONDITIONS.md), DECISIONS「Old Pine remainder B」 | Conditions on the heart beat, condition-producing attacks, poisons and drugs, treatment, saved state | Conditions do not tick in a fight (owner) nor while the player lies unconscious | INTEGRATED | C | End-to-end condition lifecycle. |
| WORLD-003 — time, population renewal and long-term resources | DECISIONS「NPCs talk and wander; rooms reset」「别的地图时间补算」「菜单窗口」 | Room resets on world time as `std/room.c`; NPCs made anew after death; away catch-up; world time held while the menu or interaction popup is open | Long-term balance at the owner's playtest | INTEGRATED | E/F/G | No server-reboot emulation. |
| SAVE-001 — current-contract continuation | [native contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md), [Shell](contracts/APPLICATION_SHELL_CONTRACT.md) | Current snapshot (SOURCE_ENTRY_OLDPINE_RELAYOUT_V1), exact identity/state/RNG, busy, NPC memory, temps, away time and corpse age; atomic writes and staged fail-closed restore; manual Continue/recovery | Lake five-alive and mixed death/corpse cold Continue verified in P2C; no cross-development compatibility guarantee | INTEGRATED | A/G/H | Reject unsupported contracts without silent migration or file deletion. |
| SAVE-002 — Lake cutoff implementation | [Final Audit](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_FINAL_AUDIT.md) | SOURCE_ENTRY_LAKE_V1 published the current save shape and old-contract refusal; each later world publication added one revision | — | INTEGRATED | A | Current Save validation remains strict; no upgrade feature. |

## Presentation, platforms, tooling and release boundaries

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| MODERN-001 — modern changes and 经典模式 knobs | Root `AGENTS.md` "Changing ES2", DECISIONS「产品定位」「Modern fixes」「响应性」「手感」「经验节奏」「进门一起上」「了结 / 放过」, `game/data/common/pacing.json` | Each change to ES2 is a recorded deviation; pacing/feel changes are data knobs keeping ES2's value | No one-switch 经典模式 setting yet (DECISIONS「产品定位」); older knob defaults are re-agreed package by package | INTEGRATED | F/H | Ported formulas are not edited in place. |
| UX-001 — current interaction foundations | [Shell](contracts/APPLICATION_SHELL_CONTRACT.md), [Mobile](contracts/MOBILE_APPLICATION_CONTRACT.md), DECISIONS「菜单窗口」「手柄」「说话和交互」 | Menu window with tabs, HUD card, interaction popup, speech bubbles, gamepad, 1280x720 base with window modes and 界面缩放, confirms before deadly choices, battle feedback | Final art/audio/animation, full accessibility | INTEGRATED | A/D/H | Reuse shared controls. |
| UX-002 — production presentation and usability | [ROADMAP](ROADMAP.md) | Functional presentation and the voxel maps so far (ART-001) | Characters and animation, audio, guidance/accessibility, the owner's full playtest and balance decisions | IMPLEMENTATION_PENDING | D/F/H | Presentation never owns hits/damage/RNG. |
| ART-001 — voxel view on every map | Root `AGENTS.md` "Maps and art", DECISIONS「固定俯视体素地图」「地图尺寸以体素视角为准」, [美术规划](../design/美术规划.md) | 雪亭镇, 老松岭, 野羊山, 卧龙岗 + 绮云镇 and 水烟阁 | The other regions in ROADMAP order, each widened for the view first | IMPLEMENTATION_PENDING | H | The 2D runtime stays authoritative; desktop frame rate is the bar. |
| UI-002 — Session shared gameplay UI | [Runtime report](../migration/PHASE_SHARED_GAMEPLAY_UI_RUNTIME.md), [Final Audit](../migration/PHASE_SHARED_GAMEPLAY_UI_FINAL_AUDIT.md) | One shared HUD and frame across every map; later grown into UX-001 | Actual-device qualification waits for a mobile port (PLATFORM-001) | INTEGRATED | Before B1 | The owner's touch decision stays PENDING / DEFERRED; synthetic checks remain required. |
| PLATFORM-001 — build and bounded demo evidence | [Build](BUILD.md), [10D final](../migration/PHASE_10D_FINAL_AUDIT.md), [Mobile](contracts/MOBILE_APPLICATION_CONTRACT.md), [Lake owner decision](../migration/DECISIONS.md#old-pine-lake--owner-revised-engineering-acceptance-scope) | Windows/Android/unsigned iOS build foundations and bounded historical packaged/device evidence; no Lake or Shared UI touch PASS | Touch, safe-area, Back/background/resume and performance qualification on real devices, for a mobile port | INTEGRATED | E/H/I | The first release is desktop only; a mobile port may follow after reviews (DECISIONS「首发只做桌面」; draft PR #161 shelved). CI keeps Android and iOS as build gates. Lake and Shared UI touch stay PENDING / DEFERRED until then. |
| TOOL-001 — migration and map tooling | [content data format](../migration/CONTENT_DATA_FORMAT.md), `tools/maps/`, [LOCALIZATION](LOCALIZATION.md) | Content importer with reviewed overrides; the map painter (`tools/maps/layouts/` → scenes); the POT extractor; Migration Tooling v1 retired | Extend a tool only for a consumer in the game | INTEGRATED | F | No LPC compiler or runtime. |
| RELEASE-001 — license and asset provenance | [license record](LICENSE_PROVENANCE.md) | Evidence recorded; unresolved ES2 discrepancy and no root project license, not clearance | Explicit rights/provenance dispositions for source and authored/third-party assets | DECISION_PENDING | Independent early workstream / I | Resolve before any public distribution. |
| RELEASE-002 — formal save support and release | [save policy](contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy), [roadmap](ROADMAP.md) | Development policy documented; no release | Owner-approved player-save baseline, product IDs/signing, desktop packages and release process | DECISION_PENDING | H/I | Desktop first; no retroactive promise for every development save. |
| BOUNDARY-001 — LPC/driver/server recreation | [owner project mandate](../../AGENTS.md#core-migration-rule) | Explicit architectural exclusion, not a deferred gameplay package | Relevant gameplay semantics are still analyzed and translated individually | EXCLUDED_BY_OWNER | All | No LPC interpreter, general FluffOS layer, Telnet/MUD client, wizard/euid/security or unrelated login/server daemon recreation. |
| BOUNDARY-002 — multiplayer-era gameplay semantics | Root `AGENTS.md` "Changing ES2", [roadmap](ROADMAP.md) | Single-player expression decided per package: lines about other players are fixed, mechanics that need a second player (红娘庄's marriage) are not ported | Each new package applies the same rule | INTEGRATED | E/F/G | Do not bulk-exclude meaningful mechanics or silently authorize multiplayer. |

## Closure discipline

Integrated rows preserve their bounded accepted history, including limitations. Unanalyzed or
decision-pending rows do not license guessed content. A future omitted target needs an explicit
owner decision before EXCLUDED_BY_OWNER; unknown/deferred is never equivalent to not migrating.
Implemented-but-unaccepted work must use the distinct pending-acceptance status when it actually
exists; no row is assigned that status merely to populate every label in this ledger.

Each owner-confirmed target needs evidence of implementation/acceptance or an explicit final
disposition before release. The owner's full playtest and its fixes, then formal save support and
the desktop release close the first version; new large expansions after that belong to a later
version. This ledger grants no implementation, PR, merge, release or tooling permission.
