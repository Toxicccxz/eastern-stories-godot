# Project Scope Ledger

## Purpose and evidence boundary

This is the lightweight disposition ledger accompanying the sole main
[ROADMAP](ROADMAP.md#forward-roadmap), not a second master roadmap or a complete LPC inventory.
Initial planning checkpoint: 2026-09-26, Lake P1 HEAD
`688647ab15b7d0a3c1c4a1b79f4a2a935e521012`, integrated main
`01f7b18253a1936bce4a1fb11a507a356769c409`. P2A adds bounded foundations; [P2B evidence](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2B_RUNTIME.md) records the Lake publication. [P2C acceptance](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2C_ACCEPTANCE.md) adds desktop input, real death/corpse and two cold-restore checkpoints; actual touch qualification remains pending.
See [STATUS](STATUS.md) for integration evidence and exact historical qualifications.

Rows are bounded capability/content packages with stable IDs. “Integrated” applies only to the
stated completed boundary; it never means the entire category, every NPC, or every player path is
finished. Core support, runtime composition, normal-player reachability and actual acceptance are
separate claims. Historical analysis identifies dependencies; current code and later integration/
owner decisions supersede its early capability snapshots. No old scan count is used as a current
remaining total. There is no computed completion percentage, schedule or promised finish month.

The owner-approved A–I direction is not a complete final content whitelist or implementation
authorization. Unexamined regions, factions, quests, arts and late-content goals require source
analysis and an owner disposition. Before G can close, expand these package rows enough to account
for the confirmed target scope; no target ambiguity may hide behind an aggregate row forever.

## Status vocabulary and maintenance

| Status | Meaning |
|---|---|
| UNANALYZED / 未分析 | A candidate package exists in planning, but source contract/dependencies are not sufficiently established. |
| DECISION_PENDING / 待决定 | Evidence identifies a real scope/compatibility/acceptance choice awaiting the owner. |
| IMPLEMENTATION_PENDING / 待实现 | Identified planned work is absent; this label alone grants no implementation permission. |
| IMPLEMENTED_PENDING_ACCEPTANCE / 已实现待验收 | Implementation exists with specified acceptance still open; not an integrated product claim. Use only with actual implementation evidence. |
| INTEGRATED / 已集成 | The stated bounded capability has integrated evidence; exclusions and qualification limits remain explicit. |
| EXCLUDED_BY_OWNER / 明确不迁移 | An explicit owner/project mandate excludes the stated subject. Cite that authority; temporary deferral is not exclusion. |

Each row's status applies to its named scope. Separate remaining packages rather than labelling
an entire category complete. Preserve IDs as scope is refined; add evidence/disposition at genuine
phase boundaries, not at every commit. Record source-backed behavior, approved Native substitutions
and unresolved interpretations distinctly. Retain useful historical tests while applying the
[development save policy](contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy).
Progress is a working content/capability loop, not a count of commits, assertions or migrated files.
No row below asserts a new runtime acceptance result from this docs-only task.

## Regions, population and creatures

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| REG-001 — Snow core and Old Pine connection | [Snow final](../migration/PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md), [NGE connection](../migration/PHASE_NEW_GAME_ENTRY_SNOW_OLDPINE_CONNECTION.md) | Integrated Inn/core streets and ordinary inter-region journey; bounded services listed separately | Further streets/interiors/population are not implied | INTEGRATED | D | Keep existing route/state continuity; remaining Snow content belongs to REG-004/POP-003. |
| REG-002 — represented Old Pine route | [river/cliff/pine record](../migration/PHASE_9B3B3_RIVER_CLIFF_PINE_ROUTE.md), [resident maps](../migration/PHASE_9B3B1_OLDPINE_WORLD_SESSION_MAP_LIFETIME.md) | Outdoor/Pine, Vine/Waterfall/River/cliff route and minimal Passage Cave; later Save/Shell integrate the runtime | Lake, full Cave/Keep, Tree and other deferred routes are not covered | INTEGRATED | A/C/D | Preserve existing topology/one-way constraints; no claim of complete Old Pine. |
| REG-003 — Lake production package | [P2C acceptance](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2C_ACCEPTANCE.md) | Continuous route/five snakes/Fill; real mouse fifth target, manual complete-set Attack, Flee, death/corpse and two exact cold restores | Representative touch qualification; owner review / Final Audit / integration | IMPLEMENTED_PENDING_ACCEPTANCE | A | SOURCE_ENTRY_LAKE_V1 on phase branch. Controlled QA evidence is not natural full-strength victory. |
| REG-004 — remaining Snow interiors/connections | [Snow rebaseline](../migration/PHASE_SNOW_TOWN_CORE_HUB_REBASELINE.md), [north spine](../migration/PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_CORE_SERVICES_REBASELINE.md) | Historical inventory/behavior analysis; some visible closed frontages/connections, not functioning new services | Recheck actual interiors, doors, secrets and neighboring region prerequisites; differentiate empty/ambiguous source | IMPLEMENTATION_PENDING | D/E/F | Deliver justified playable connections/services, or obtain explicit disposition; do not invent behavior from descriptions. |
| REG-005 — full Cave / Keep packages | [Old Pine 9A](../migration/PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md) | Minimal Cave traversal only, not full encounter/maze/reward/gate content | Current source analysis of encounters, burial/rewards, exits, Keep gates/reinforcement/mechanisms; order TBD | UNANALYZED | C | Incremental packages with entry, useful rewards, exit, return and Save; Lake admission is not dynamic reinforcement support. |
| REG-006 — second region/faction and broader world | [architecture](../migration/ES2_ARCHITECTURE_ANALYSIS.md), [group E](ROADMAP.md#e--second-region-and-second-faction) | No second-region/faction completion inferred from source directories | Source topology, progression, distinct rules, residency/scale measurements and owner target selection | UNANALYZED | E/F/G | Select by evidence; shared authorities; every chosen region reaches a complete playable package. No invented destination/ending. |
| POP-001 — existing Old Pine production NPC slots | [Lake current-code analysis](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md#b-serpent-facts-identity-and-initialization) | Five human slots (three scouts, Tall, Fat), existing combat/death/Save scope | Does not cover five serpents or all source NPCs | INTEGRATED | A/D | Preserve actual identity/lifecycle while adding separately authorized current catalog content. |
| POP-002 — Beast / ordinary serpent foundation | [Beast final](../migration/PHASE_BEAST_FOUNDATION_SERPENT_FINAL_AUDIT.md) | Beast defaults/body/action/intrinsics and bounded controlled serpent runtime/persistence composition | Production Lake slots and normal-player serpent Save/Continue are REG-003, not already qualified | INTEGRATED | A | Reuse source rules; QA wounded victory is not natural victory or balance proof. |
| POP-003 — Snow population and deferred Old Pine actors | [Snow analysis](../migration/PHASE_SNOW_TOWN_CORE_HUB_REBASELINE.md), [9A dependencies](../migration/PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md) | Scoped waiter/Liu contacts and analyzed source examples, not full NPC parity | Real services/inquiry/trade/recognition; Tree/spy/maniac/wolf dependencies, including source anomalies and special behavior, need current recheck | UNANALYZED | C/D/F | Keep named deferred packages visible; each gets source/Native disposition without reopening the earlier bounded audits. |

## Martial arts, growth, items and economy

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| GROW-001 — shared skill/training foundations | [Skill Core](../migration/PHASE_3A_SKILL_CORE.md), [Cultivation](../migration/PHASE_3B1_CULTIVATION.md), [Practice/SelfLearning](../migration/PHASE_3B2_PRACTICE_SELFLEARN.md), [Learn](../migration/PHASE_3C1_LEARN_CORE.md) | Typed raw/learned/mapping/progression, cultivation and bounded training policies exist in integrated Core | Complete policy coverage and ordinary UI/acquisition/combat consumers are not implied by Core or skill metadata | INTEGRATED | B/E/F | Reuse one authority; analyze missing consumers before extending. Historical skill scans are not current migration completion counts. |
| GROW-002 — Liu/basic unarmed/Liuh-Ken | [first progression final](../migration/PHASE_SNOW_FIRST_PROGRESSION_FINAL_AUDIT.md), [Liuh final](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_FINAL_AUDIT.md) | Physical school/contact, scoped apprenticeship/Learn, Liuh mapping/actions/feedback and approved persistence acceptance; source-cloth/name repairs closed | Not full Liu teaching/population; natural time-to-EXP6 usability remains unqualified, test-only prerequisites labelled | INTEGRATED | B/D | Preserve existing bounded closures; the Snow acceptance exemption does not automatically apply elsewhere. |
| GROW-003 — internal power player loop | [Cultivation](../migration/PHASE_3B1_CULTIVATION.md), [first progression source](../migration/PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md) | Reusable domain force/cultivation foundation, not a complete public force route | Reanalyze force/fonxanforce acquisition, mapping, exercise, resources, battle consumption and Save | IMPLEMENTATION_PENDING | B1 | Actual obtain→enable→cultivate→combat→persist loop; no second cultivation system. |
| GROW-004 — sword/defense and training entry | [first progression source](../migration/PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md), [Practice](../migration/PHASE_3B2_PRACTICE_SELFLEARN.md) | General skill/equipment/Combat primitives and selected policies | Verify sword/parry/dodge, fonxansword, chaos-steps and exact practice/selflearn prerequisites; minimal UI as needed | UNANALYZED | B2/B3 | Scope distinct milestones by dependencies; actual effects, not names/levels alone. |
| GROW-005 — Study and advanced/faction-specific abilities | [architecture skill analysis](../migration/ES2_ARCHITECTURE_ANALYSIS.md#7-skills-martial-arts-progression-and-inner-power), [9A](../migration/PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md) | No blanket production qualification for Study, perform/exert, casting or special weapon follow-ups | Literacy/real books/reward uses; concrete faction/resource/action consumers | UNANALYZED | C/E/F | Trace acquisition/prerequisites and actual behavior; do not prebuild every special action. |
| ITEM-001 — inventory/equipment/death infrastructure | [item persistence](../migration/PHASE_4B5A_NATIVE_ITEM_SAVE_RESTORE.md), [corpse](../migration/PHASE_4B5C_DEATH_INVENTORY_CORPSE.md), [Save contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md) | Shared item IDs, containment, stacks/currency, equipment/armor, corpse/loot and persistence foundations with production consumers | Not every source item, death hook, container or reward use | INTEGRATED | A/C/F | Preserve current graph/identity/atomicity; content consumers tracked separately. |
| ECON-001 — livelihood and supply loop | [Core Hub final](../migration/PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md), [Hockshop final](../migration/PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_FINAL_AUDIT.md) | Work, physical money/Bank, bounded Inn goods, Eat/Waterfall Fill/Drink and Hockshop Value/Sell | No complete merchant population/catalog, pawn/redeem, all medicines/services or regional economy | INTEGRATED | C/D/F | Keep ordinary loot→money→supplies loop; deferred goods/services require actual source/use analysis. |
| ECON-002 — further goods, treatment and reward uses | [Inn contract](../migration/PHASE_SNOW_TOWN_CORE_HUB_INN_VENDOR_CONSUMABLES_CONTRACT.md), [Snow source](../migration/PHASE_SNOW_TOWN_CORE_HUB_REBASELINE.md) | Dependencies and scoped omissions recorded; not all deferred products implemented | Treatment/conditions, literacy/Study, meaningful equipment and service behaviors | UNANALYZED | C/D/F | Rewards have usable consumers; incomplete source offers are resolved rather than invented. |

## Events, world lifecycle and persistence

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| EVENT-001 — quests/inquiry/local mechanisms | [architecture event analysis](../migration/ES2_ARCHITECTURE_ANALYSIS.md#10-quests-scripted-events-and-special-roomnpc-logic), [9A](../migration/PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md) | Existing bounded doors/traversals/teaching are specific consumers, not a complete quest framework | Source conditions, exchanges, recognitions, local events and formal quest distinctions; useful log/UI | UNANALYZED | C/D/F/G | Implement actual packages; no speculative main quest, ending or generic quest engine. |
| WORLD-001 — represented resident-map/death lifecycle | [resident maps](../migration/PHASE_9B3B1_OLDPINE_WORLD_SESSION_MAP_LIFETIME.md), [Save contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md) | Existing maps retain in-memory state while detached; represented slots/tombstones/corpses persist through current Save | Not a universal world-time, all-region residency, respawn or off-screen simulation policy | INTEGRATED | A/E/F | Preserve scoped behavior; future scaling/renewal requires measured, source-backed decisions. |
| WORLD-002 — conditions, treatment and update consumers | [Conditions](../migration/PHASE_2B_CONDITIONS.md), [recovery cadence](../migration/PHASE_SNOW_TOWN_CORE_HUB_PLAYER_RECOVERY_CADENCE.md) | Typed conditions/representative effects; current eligible recovery cadence deliberately freezes under conditions | Condition-producing attacks, update/lifecycle integration, treatment, supplies and full persistence path | IMPLEMENTATION_PENDING | C | End-to-end condition lifecycle; venomsnake is separate from ordinary serpent/Lake. |
| WORLD-003 — time, population renewal and long-term resources | [architecture lifecycle analysis](../migration/ES2_ARCHITECTURE_ANALYSIS.md#5-npc-behavior-and-lifecycle), [group F](ROADMAP.md#f--full-scope-content-packages) | Scoped initial-only and current cadence rules; no general long-term world policy inferred | Real cross-region event/time/resource consumers; owner-approved single-player reset/renewal meaning | DECISION_PENDING | E/F/G | Sustainable source-backed loops; neither server reset emulation nor permanent global INITIAL_ONLY by default. |
| SAVE-001 — current-contract continuation | [native contract](contracts/NATIVE_SAVE_LOAD_CONTRACT.md), [Shell](contracts/APPLICATION_SHELL_CONTRACT.md) | Current supported snapshot, exact identity/state/RNG, atomic writes and staged fail-closed Session restore; manual Continue/recovery | Lake five-alive and mixed death/corpse cold Continue verified in P2C; no cross-development compatibility guarantee | INTEGRATED | A/G/H | Preserve current reliability; reject genuinely unsupported contracts without silent migration or file deletion. |
| SAVE-002 — Lake cutoff implementation | [P2C acceptance](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2C_ACCEPTANCE.md) | Public SOURCE_ENTRY_LAKE_V1, ten-slot ledger, old-contract refusal; two real cross-process full-state/RNG equalities | Owner review / Final Audit / integration; Lake touch qualification remains pending | IMPLEMENTED_PENDING_ACCEPTANCE | A | No old/new product-world split or upgrade feature; unchanged executable/test baseline. |

## Presentation, platforms, tooling and release boundaries

| ID / package | Source or analysis evidence | Accurate completed boundary | Remaining dependencies | Status | Groups | Finish / owner disposition |
|---|---|---|---|---|---|---|
| UX-001 — current interaction foundations | [Shell](contracts/APPLICATION_SHELL_CONTRACT.md), [Mobile](contracts/MOBILE_APPLICATION_CONTRACT.md), [Combat final](../migration/PHASE_COMBAT_CXR10_FINAL_AUDIT.md) | Shared menus/input/safe area/pause/mobile lifecycle and battle feedback with bounded recorded runtime evidence | Not final art/audio/animation, full accessibility, all target/device combinations or regional guidance | INTEGRATED | A/D/H | Reuse shared controls; verify affected paths, not blanket runtime claims from builds. |
| UX-002 — production presentation and usability | [group D](ROADMAP.md#d--snow--old-pine-regional-template), [group H](ROADMAP.md#h--presentation-usability-and-stability-closure) | Existing functional presentation; no complete final asset set claimed | Regional sample, ongoing assets, consistent feedback/guidance/accessibility, systematic player tests, explicit balance decisions | IMPLEMENTATION_PENDING | D/F/H | Normal-player readability and BETA quality; presentation never owns hits/damage/RNG. |
| PLATFORM-001 — build and bounded demo evidence | [Build](BUILD.md), [10D final](../migration/PHASE_10D_FINAL_AUDIT.md), [Mobile](contracts/MOBILE_APPLICATION_CONTRACT.md) | Windows/Android/unsigned iOS build foundations and bounded historical packaged/device evidence | Broad Android/tablet and iOS runtime/performance qualification; future exact candidate artifacts | INTEGRATED | E/H/I | Integrated infrastructure is not final platform qualification; test actual affected targets and artifacts. |
| TOOL-001 — migration tooling | [integrated status](STATUS.md) | Migration Tooling v1 bounded static-room extraction integrated | NPC/item extraction or Native generation only if real repetition justifies later scope | INTEGRATED | F | P3 is optional and unauthorized; no LPC compiler/gameplay generator prerequisite. |
| RELEASE-001 — license and asset provenance | [license record](LICENSE_PROVENANCE.md), [README](../../README.md) | Evidence recorded; unresolved ES2 discrepancy and no root project license, not clearance | Explicit rights/provenance dispositions for source and authored/third-party assets | DECISION_PENDING | Independent early workstream / I | Resolve before distribution authorization; not Lake/plugin certification work and not postponed to the end. |
| RELEASE-002 — formal save support and release | [save policy](contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy), [group I](ROADMAP.md#i--release-and-post-release-stabilization) | Development policy documented; private demo is not formal 1.0 | Owner-approved long-term test/release save baseline, product IDs/signing, packages, store/release process and bounded stabilization | DECISION_PENDING | H/I | Actual qualified 1.0 delivery; no retroactive promise for every development save or arbitrary released-progress loss. |
| BOUNDARY-001 — LPC/driver/server recreation | [owner project mandate](../../AGENTS.md#core-migration-rule) | Explicit architectural exclusion, not a deferred gameplay package | Relevant gameplay semantics are still analyzed and translated individually | EXCLUDED_BY_OWNER | All | No LPC interpreter, general FluffOS layer, Telnet/MUD client, wizard/euid/security or unrelated login/server daemon recreation. |
| BOUNDARY-002 — multiplayer-era gameplay semantics | [architecture](../migration/ES2_ARCHITECTURE_ANALYSIS.md), [group F](ROADMAP.md#f--full-scope-content-packages) | No multiplayer product promise | Item-by-item source-backed single-player expression or explicit owner exclusion | DECISION_PENDING | E/F/G | Do not bulk-exclude meaningful mechanics or silently authorize multiplayer. |

## Closure discipline

Integrated rows preserve their bounded accepted history, including limitations. Unanalyzed or
decision-pending rows do not license guessed content. A future omitted target needs an explicit
owner decision before EXCLUDED_BY_OWNER; unknown/deferred is never equivalent to not migrating.
Implemented-but-unaccepted work must use the distinct pending-acceptance status when it actually
exists; no row is assigned that status merely to populate every label in this initial ledger.

By G, each owner-confirmed target must have evidence of implementation/acceptance or an explicit
final disposition. H then closes presentation/usability/stability and formal save support for
long-term external testing; I closes the actual release and predefined stabilization. New large
expansions after that belong to a later version. This ledger grants no implementation, Final Audit,
PR, merge, release, migration-tooling expansion or plugin work.
