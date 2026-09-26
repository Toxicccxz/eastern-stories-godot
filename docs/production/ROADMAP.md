# Productionization Roadmap

## Final objective and completion definition

**Owner direction recorded 2026-09-26; planning approval is not implementation authorization.**
This is the project's sole main roadmap. The [scope ledger](PROJECT_SCOPE.md) tracks dispositions
and evidence; [STATUS](STATUS.md) records the current checkpoint. Neither is a competing roadmap.

Rebuild the confirmed meaningful ES2 mechanics and content as an accessible, interactive,
progression-capable Native Godot RPG with reliable Save/Continue. The finish is larger than the
Snow/Old Pine demo and smaller than reproducing every LPC file or MudOS/FluffOS service.
Completion requires:

- explicit disposition of every item in the owner-confirmed target scope;
- a coherent normal-start → early → middle → intended late-content gameplay chain;
- reliable saves within the supported contract;
- verified presentation, usability, stability and target-platform behavior;
- qualified candidate artifacts, release readiness and the agreed release process.

There is no assumed universal main-story ending, final boss, multiplayer mode, invented faction
or new mechanic. Unverified late content remains to be source-analyzed and owner-scoped. G closes
functional/content scope; H closes quality and candidate readiness; I delivers 1.0 and its bounded
stabilization. Later expansions must not indefinitely move that original finish line.

## Current position

Integrated main `01f7b18253a1936bce4a1fb11a507a356769c409` includes PR #23 documentation closeout;
[post-merge workflow 36212949685](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36212949685)
passed all four required jobs on that SHA. It is the Lake branch's start, not Lake acceptance.
Existing integrated capabilities include the bounded Snow/Old Pine journey, source New Game,
economy/supplies, Liu apprenticeship/basic unarmed/Liuh-Ken, Combat/Flee/death, native persistence,
Shell/Mobile foundations, Beast foundations and Migration Tooling v1. Their limits and evidence
are in [STATUS](STATUS.md) and the [historical records](#historical-milestone-records) below.
Core capability is not production interaction; controlled QA is not a normal-player route;
definitions are not complete content. In particular, Beast QA does not publish Lake or five snakes.

Current branch: `phase/oldpine-lake-serpent-production`. [Lake P1](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md)
was delivered at `688647ab15b7d0a3c1c4a1b79f4a2a935e521012`; [P2A foundations](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2A_FOUNDATIONS.md) are implemented; [P2B](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2B_RUNTIME.md) now publishes the Lake composition (targeted validation complete; awaiting owner review).
Its [owner amendment](../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md#owner-policy-amendment--2026-09-26)
replaces old-world compatibility with **DEVELOPMENT SAVE CUTOFF / CURRENT WORLD ONLY**.
M/W are owner-locked; P2A implements current-contract Save rejection and transactional complete-set
admission. P2B publishes Lake geometry/five serpent slots/Fill and SOURCE_ENTRY_LAKE_V1 current Save. Closed milestones remain closed absent a specific regression.

The [development save policy](contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy)
permits new-game requirements for genuine incompatibility, not arbitrary per-commit invalidation.
Current-state integrity, atomic/staged failure protection, zero restore RNG, explicit errors and
protection of existing files remain mandatory. No historical world or migration feature is required
solely for old test saves. Code may still read some older versions; this document does not remove it.

## Forward roadmap

A–I are **planning groups**, not fixed branches or one giant PR per group. Each explicitly planned
major integration milestone follows one phase branch → internal slices/fixes → one final PR.
The owner has approved this direction and hierarchy, not detailed contracts for unexamined content.

| Group | Purpose / order principle | Exit condition |
|---|---|---|
| [A](#a--lake-production) | Production Lake; current persistence boundary before publication | Entry, selection, Combat/Flee/reentry, death/corpse and current Save/Continue work together. |
| [B](#b--early-martial-arts-and-progression) | Internal power → source-dependent offense/defense → Practice/SelfLearning entry | Meaningful early choices connect Learn, mapping, training, equipment, combat effects and durability. |
| [C](#c--exploration-and-world-behavior) | Conditions/treatment and concrete encounter consumers; recheck Cave/Keep order | State effects, useful items, encounters, mechanisms and exploration rewards run and persist. |
| [D](#d--snow--old-pine-regional-template) | Complete the regional player loops and a reusable presentation example | Normal players complete the main regional loops without developer narration. |
| [E](#e--second-region-and-second-faction) | Select by verified topology/prerequisites and actual behavioral differences | A second region/faction reuses authorities with bounded extensions; scale measured. |
| [F](#f--full-scope-content-packages) | Migrate playable packages with their dependencies and rewards | Target content enters normal play in coherent batches, not just definition files. |
| [G](#g--functional-and-content-closure) | Resolve scope omissions, dead ends, ambiguity and deferred targets | CONTENT COMPLETE ALPHA. |
| [H](#h--presentation-usability-and-stability-closure) | Finish assets/consistency, systematic playtesting, performance/devices | BETA / release-candidate conditions satisfied. |
| [I](#i--release-and-post-release-stabilization) | Qualify real artifacts and execute authorized platform release | 1.0 delivered; predefined stabilization complete. |

### A — Lake production

Connect existing Beast and ordinary Combat capabilities to a real reachable production area.
The recommended slice sequence is:

1. **P2A: current-version save boundary and complete-set combat admission foundations.**
   Define the explicit incompatible-development-save cutoff and current catalog validation.
   Implemented pre-freeze collection of actually eligible enemies, transactional relations, fifth-target
   handling and rollback using the existing coordinator/scheduler. Foundation/tests may be ready
   without exposing an incomplete Lake world; preserve current reliability while staging the work.
2. **P2B: publish Lake geometry, five production serpents, Fill and complete Save/Continue together.**
   One current production world, ten complete spawn records, no legacy five-slot world or old Lake
   barrier retained for compatibility. The support marker changes only at the real contract boundary;
   no root/item schema bump by habit and no automatic/manual save-upgrade path.
3. **P2C: applicable real-runtime, full-process restart and Continue acceptance.** Then stop for
   separately authorized Final Audit and final integration; do not treat a fresh graph as cold restart.

Finish covers ordinary entry/target selection/Combat/Flee, physical reentry, death/corpse and current
Save/Continue. Do not require a source-birth novice to naturally kill five full-strength serpents.
No poison, swimming, rebalance, invented drops or generic Combat framework. M/W are locked by the
[P2A decision](../migration/DECISIONS.md#old-pine-lake--owner-locked-p2a-foundations); this roadmap
does not authorize P2C or subsequent work.

Local validation follows the owner-authorized scope rule in root AGENTS.md: affected tests and
representative live evidence per slice; one broad discovery run when justified; final canonical
`verify.py` at phase closure without duplicating its successful unchanged stages. The final PR and
exact-merge main four-job gates remain mandatory.

### B — Early martial arts and progression

Recommended near-term dependencies after A, subject to each milestone's source analysis:

| Candidate milestone | Goal / dependencies | Bounded finish |
|---|---|---|
| B1 — internal power | `force` / `fonxanforce`, Enable/Disable, `exercise`, necessary resources and real combat consumption; reuse existing Skill/Cultivation/force policies | Obtain, map, cultivate, consume and persist internal power through ordinary interaction. |
| B2 — offense and defense routes | Place `sword` / `parry` / `dodge`, `fonxansword`, `chaos-steps` according to actual learning/equipment/resource prerequisites | Relevant skill actions/defenses and equipment actually affect combat, with durable progression. Split into more than one milestone if dependencies warrant it. |
| B3 — practice and usable controls | Reuse existing Practice/SelfLearning; respect each skill's real level/policy requirements. Add minimal skill viewing/mapping/practice access when the number of usable skills needs it | Learning, mapping, training, equipment and combat form meaningful choices; no placeholder level/name-only completion. |

Existing [Skill Core](../migration/PHASE_3A_SKILL_CORE.md),
[Cultivation](../migration/PHASE_3B1_CULTIVATION.md) and
[Practice/SelfLearning](../migration/PHASE_3B2_PRACTICE_SELFLEARN.md) are domain foundations,
not evidence these complete player routes already exist. Recheck current implementations and
authored prerequisites before defining B1/B2/B3 scope; do not duplicate those systems or assume
every named art belongs in one milestone. Study and real textbooks also need their own consumers.

### C — Exploration and world behavior

Advance actual consumers: complete condition/treatment/supply lifecycles; the minimal
condition-producing attack seam required by venomsnake; literacy/Study/real teaching items;
Cave encounters, routes, burial, reward uses and exits; Keep gates, reinforcements, mechanisms,
combat and world state. These are source-analysis work packages, not a claim that their exact
contracts or order are already settled. Recheck Cave vs Keep dependencies at that time.

Reuse existing maps and cross-scene foundations incrementally. Lake's pre-freeze collection does
not imply dynamic Keep reinforcements. A local mechanism need not become a generic quest engine.
Do not issue a textbook reward without a usable Study path. Preserve Core/Runtime separation:
an existing `snake_poison` domain handler alone does not establish an attack producer, update
cadence, treatment, presentation or saved world lifecycle. Exit when these behaviors and useful
exploration rewards run and persist through the supported contract.

### D — Snow / Old Pine regional template

Build source-backed service/goods/population/teaching packages, meaningful interiors/doors/secret
routes, real inquiry/item-exchange/recognition conditions and local events, necessary quest/log
interaction, and correct connections for later regions. Analyze formal quests separately from
local mechanisms. Descriptions, empty implementations and ambiguous source behavior do not
automatically become invented services.

Start a reusable production presentation example here: a town section, wilderness, human/Beast
characters, battle feedback and principal UI. Verify scale, collision, prompts, text and mobile
operation; develop assets alongside later regions, rather than deferring all art to H.
Keep Tree/spy/maniac/wolf and other unfinished packages in [PROJECT_SCOPE](PROJECT_SCOPE.md)
until their actual dependencies are addressed; future work does not reopen old closed audits.
Finish when a normal player can complete the principal livelihood, growth, exploration,
battle/retreat, reward and persistence loops without verbal developer guidance.

### E — Second region and second faction

Select a region/faction by verified source connections, progression conditions and dependency
analysis, with a real difference in teaching, abilities, weapons or quest behavior. Directory names
and unverified difficulty impressions are not a selection method. No destination is fixed yet.
According to concrete consumers, introduce bounded perform/exert, casting, different internal
resources, special weapon follow-up actions or faction rules. Do not prebuild all of them.

Measure cross-region travel/return, saved world state, memory, loading and data scale. Do not retain
every future map/NPC permanently without measurement; do not replace the world architecture merely
because the future is large. Finish by delivering a second region/faction through shared Character,
Combat, inventory and persistence authorities plus justified extensions, never a second copy of them.

### F — Full-scope content packages

Deliver coherent packages: entry/conditions → map → population/behavior → interaction/combat/
quest/mechanism → rewards and uses → leaving/return/current Save. Plan regions, factions, arts,
textbooks, items and growth together so maps have play, skills have acquisition and rewards have use.
Batch ordinary content whose behavior is already verified; separately track genuinely new procedures.

Use actual needs to settle cross-region quests, time, world flags, population renewal and long-term
resource sustainability. Neither mechanically port server reset nor impose early INITIAL_ONLY on
all future regions forever. Review multiplayer-era rules individually for single-player expression
or explicit exclusion; do not turn the project into a multiplayer game by default.
Tool growth needs repeated work and demonstrated benefit. Migration Tooling P3 is optional, not
a compulsory mainline prerequisite; no LPC compiler or automatic gameplay generator. Finish when
target packages enter normal player routes, not when their definitions have merely been recorded.

### G — Functional and content closure

Review scope/dependency omissions, normal-start through intended late play, resource dead ends,
softlocks, duplicate rewards, impossible prerequisites, cross-region events/quests and current Save.
Resolve source defects, ambiguities and long-deferred in-scope items through evidence, an explicit
owner-approved Native alternative, or explicit exclusion. Unknown targets cannot remain indefinitely
while claiming complete migration. Exit **CONTENT COMPLETE ALPHA**: the main target capabilities
and content exist and can be used; no whole target faction, large region or primary gameplay chain
is absent. The scope ledger records dispositions rather than a guessed completion percentage.

### H — Presentation, usability and stability closure

Complete and unify maps, characters, animation, UI, text, sound/music, guidance, feedback and
accessibility, building on D and the regional asset work. Conduct systematic player testing and
explicitly decided pacing/balance adjustments; distinguish defects, interaction problems and rule
changes. Animation never gains hit/damage/RNG authority from Game Core.

Verify long sessions, map transitions, Save/Continue, performance and actual target devices.
Before external long-term testing, separately establish the formal player-save support baseline;
do not retroactively promise all development saves. Exit **BETA / release-candidate conditions met**.
Successful CI builds are not device runtime proof or blanket iOS/Android qualification.

### I — Release and post-release stabilization

For the actual chosen targets, finish product identifiers, signing, candidate packages, release
materials, license evidence, asset provenance and distribution eligibility. The
[license/provenance work](LICENSE_PROVENANCE.md) can advance as an independent early workstream;
it is not Lake scope, existing clearance, or work to postpone until all development is done.
Validate the actual candidate artifacts, not just the editor project. Execute releases only with
their own authorization. Exit **1.0 delivered and predefined stabilization complete**. New regions
or large expansions then belong to later versions, not a constantly extended original finish line.

## Execution, validation and authorization

1. Owner decides scope, advancement, gameplay tradeoffs and merges. ChatGPT supplies review and
   instructions; Codex executes the authorized scope. Existing authorization persists; do not ask
   again for the same approved action. Readiness and roadmap position do not authorize the next slice.
2. One explicitly planned major integration milestone has one branch and one final PR. Internal
   analysis, implementation, validation and audit fixes stay together. A–I are not fixed branch names.
3. Detail the current major phase. State goals/dependencies for the next two or three candidate
   milestones; keep farther work at scope, ordering principles and exit criteria until analyzed.
4. Match verification to risk: automate formulas, state, serialization and composition; obtain real
   runtime evidence for applicable UI, movement, collision, map transitions and lifecycle contracts.
   Test setup must be disclosed; callbacks/teleports are not physical-input proof. Fresh graph is
   not full process restart. No unrelated manual typing or exhaustive per-draw narrative by habit;
   investigate new issues with bounded evidence without weakening explicit acceptance requirements.
5. Batch equivalent verified content; a normal new NPC does not reopen the entire Combat audit.
   No concrete regression means no reopened closed phase. Deferred content is new scope, not proof
   that the old bounded closure was wrong. Technical/input failures are not automatically balance defects.
6. Integration gates remain: required local validation and Final Audit; final PR exact-HEAD
   **Godot Verify / Windows Release Build / Android Release Build / iOS Build Validation** success;
   explicit owner authorization for ordinary merge; the same four jobs on the exact merge SHA;
   next major phase from the then-green main. Follow [repository policy](REPOSITORY_POLICY.md)
   and root AGENTS, including narrow CI stabilization. This planning update changes no CI or gate.
7. Measure progress by usable capability/content-package closure. Commit counts, assertion counts,
   migrated-file counts and old corpus scans are evidence of work, not game completion. No invented
   deadline, finish month or precise remaining percentage. Apply the
   [development save policy](contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy)
   without relaxing current-contract reliability or deleting real files.

## Historical milestone records

The numbered records below retain their original bodies, numbering and links. Their completed
milestones remain closed; earlier pending statements are historical checkpoints superseded by their
later closures. New forward planning above is not retroactive implementation or acceptance evidence.
Each explicitly planned integration milestone still uses one branch and one final PR; internal
analysis, implementation slices and audit corrections remain on that branch.

1. **Phase 10A — Cross-Platform Repository / Build / CI Foundation — Complete**

   Pin Godot 4.7.2, verify the repository, sanitize one production project, and prove Windows,
   Android, and unsigned iOS build pipelines through CI artifacts.

2. **Phase 10B — Native Save / Load Integration — Complete**

   Connect the existing typed persistence foundations to the playable application/session.

3. **Phase 10C1 — Cross-Platform Game Shell — Complete**

   Shared application menu, New Game/Continue, Pause/Save, explicit recovery, Return to Menu, settings,
   and focus/input boundaries are fully integrated at `3a1f993a4258ed246ce820c7a4dc8d2563994aaf`
   through PR #5, with all four post-merge main CI jobs green.

4. **Phase 10C2 — Mobile Input / Layout / Lifecycle Adaptation — Complete / Fully Integrated**

   Shared responsive/safe-area presentation and sensor landscape, touch pad/Android Back,
   lifecycle freeze/explicit Resume and manual-save-only durability have passed A/B/C and
   the [final major-phase audit](../migration/PHASE_10C2_FINAL_AUDIT.md). PR #6 and resident-map
   contact stabilization PR #7 are integrated at
   `ae381bf3f3e5f4a28a417295eea680d023cc428c`, with all four post-merge jobs green in
   [workflow 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002).
   The [mobile contract](contracts/MOBILE_APPLICATION_CONTRACT.md) records consumer boundaries and
   remaining qualification gaps.

5. **Phase 10D — Technical Demo Release Gate — COMPLETE / FULLY INTEGRATED**

   Phase10D1 retains bounded historical physical Android PASS; Phase10D2 retains historical
   exact-artifact packaging PASS. Old pre-redesign Phase10D3
   historically was **BLOCKED / SUSPENDED** and never passed because normal-player acceptance exposed an
   unsuitable combat experience. Phase10D Final Audit had not started at that historical checkpoint.
   Existing physical evidence
   is conditionally reusable only for unchanged platform interaction paths; existing artifacts and
   hashes remain exact-source historical evidence, not post-redesign release candidates.

   Fresh acceptance used `phase/10d-post-redesign-release-validation` from green main
   `0a5f0b49b6797c2a1280ef4198c2060b3cc61e34`. The historical Phase10D branch stays frozen;
   no old artifact becomes a post-redesign candidate. Current
   [Phase10D3 acceptance](../migration/PHASE_10D3_POST_REDESIGN_TECHNICAL_DEMO_ACCEPTANCE.md)
   is **POST-REDESIGN NORMAL-PLAYER ACCEPTANCE PASS** for immutable source
   `000d7b383f1d508aab56e9dcd90273d4a9dd5b85`. Post-redesign candidate refresh is satisfied
   on this branch; no separate 10D2 repeat is required. Windows critical journey and Android
   physical representative world traversal suffice; Cave/SouthExit remains conditional/not
   advertised for this fresh-player demo. The [Final Audit](../migration/PHASE_10D_FINAL_AUDIT.md)
   passed: 16,152 canonical assertions, Python 46, static/headless/sanitizer checks; candidate
   drift and production/test/build/CI deltas zero. Candidate remains frozen/accepted.
   [PR #10](https://github.com/Toxicccxz/eastern-stories-godot/pull/10) merged at
   `abad71a4630c11c889cc3d0132095af95163aaa1` after four green PR jobs on
   `6817832f161edbe1005b2ce99819962ce61f0124` in
   [workflow 34278725150](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34278725150).
   Post-merge main [workflow 34280203676](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34280203676)
   also completed successfully on the merge commit: Godot Verify, Windows Release Build,
   Android Release Build and iOS Build Validation all PASS. Integrated main and immutable
   accepted candidate source are distinct identities; the merge is not a newly tested candidate.
   Historical audit checkpoint wording is intentionally unchanged. This completes only the
   private/internal Technical Demo engineering gate, not public/store/legal clearance, permanent
   signing, iOS-device or broad Android certification, or the finished game.

6. **Combat Experience Redesign — FULLY INTEGRATED ON MAIN**

   PR #8 merged at `7372d9d2ca3d796236ad64c2c6ad817a2508cb91`, with all four post-merge jobs
   PASS in [workflow 34186684857](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34186684857).
   Independent tooling PR #9 then updated Godot AI 4.0.1 at `0a5f0b4`; its four-job main
   [workflow 34187852614](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34187852614)
   passed without changing the gameplay milestone.

   The [CXR0 analysis](../migration/PHASE_COMBAT_EXPERIENCE_REDESIGN_ANALYSIS.md) is complete.
   The [CXR1 Active Semi-Auto V1 design](../migration/PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md)
   is complete and selects ES2 Active Semi-Auto: ordinary combat/defense are automatic, while the
   player triggers tactical actions, target changes, and flee. The typed, Node-free
   [CXR2 CombatEncounter Core](../migration/PHASE_COMBAT_CXR2_ENCOUNTER_CORE.md) is complete. The
   [CXR3 World/Encounter Lifecycle Foundation](../migration/PHASE_COMBAT_CXR3_WORLD_ENCOUNTER_LIFECYCLE.md)
   is complete with one Session-owned coordinator, exact live authority binding, and an explicit
   encounter-owned frozen-world gate. The
   [CXR4 Active Semi-Auto Scheduler](../migration/PHASE_COMBAT_CXR4_ACTIVE_SEMI_AUTO_SCHEDULER.md)
   is complete with deterministic logical time, stable participant opportunities, exact-authority
   ordinary combat, typed events, and world-frozen/application-pause separation. Normal production
   combat was not cut over by CXR4 itself. The
   [CXR5 Tactical Actions + One-Slot Queue](../migration/PHASE_COMBAT_CXR5_PLAYER_TACTICAL_ACTIONS_QUEUE.md)
   is complete with typed requests, one busy-aware slot, split validation, exact-authority policies,
   and deterministic tactical/ordinary ordering. The
   [CXR6 Battle Presentation](../migration/PHASE_COMBAT_CXR6_BATTLE_PRESENTATION.md)
   is implementation/desktop-runtime complete with typed projections/intents, honest empty
   production Quick Actions, ordered feedback/log and shared input/layout/lifecycle boundaries.
   Affected physical mobile requalification was pending at that slice; see CXR10's
   bounded qualification below. No production technique, fake telegraph,
   Quick Slots or target switching was introduced in CXR6. The
   [CXR7 Multi-Opponent Targeting + Modes](../migration/PHASE_COMBAT_CXR7_MULTI_OPPONENT_MODES.md)
   is implementation/desktop-runtime complete, preserving queued targets and supporting controlled
   SPAR/LETHAL/SCRIPTED establishment. The
   [CXR8 Production Cutover / Resolution](../migration/PHASE_COMBAT_CXR8_RESOLUTION_CUTOVER.md)
   is implementation/runtime complete: normal combat uses the new scheduler and existing lifecycle,
   corpse/loot and native Save authority. Bounded physical Android entry/Back/lifecycle checks pass;
   this does not qualify every earlier queued/multi-target device combination. Armed-friendly mortal
   SPAR is explicitly blocked pending a compatibility decision.
   [CXR9 playability](../migration/PHASE_COMBAT_CXR9_PLAYABILITY_BALANCE.md) is
   implementation COMPLETE: source-backed New Game experience 600/result feedback,
   real queued Flee with same-position return, physical aggression re-arm, and
   unarmed-only SPAR with an explicit zero-base compatibility choice. Telegraph is
   dormant (no qualifying producer). Final 368 focused / 16,132 canonical assertions
   PASS. The subsequent [CXR10 final audit](../migration/PHASE_COMBAT_CXR10_FINAL_AUDIT.md)
   is **COMPLETE; MILESTONE FULLY INTEGRATED**: its initial 16,132 canonical
   assertions and 20 focused runners pass, fresh desktop paths pass, and the exact
   gameplay APK passes bounded OnePlus 8T / Android 14 touch/Flee/Back/Home/Resume/
   landscape/natural Victory/loot qualification. This does not qualify broader
   mobile combinations or iOS. Subsequent PR review fixes for disconnected encounter topology
   and final-hit feedback passed 16,152 canonical assertions and desktop/Android revalidation.
   Final PR CI, explicitly authorized merge and post-merge main CI all passed.

   | Slice | Status | Goal |
   |---|---|---|
   | CXR0 | Complete | Combat redesign analysis. |
   | CXR1 | Active Semi-Auto V1 Design Complete | Locked encounter, scheduling, queue, event, presentation, Save and lifecycle contracts. |
   | CXR2 | Complete | Typed CombatEncounter core without BattleScene ownership. |
   | CXR3 | Complete | Session-owned encounter lifecycle and frozen-world transition foundation. |
   | CXR4 | Active Semi-Auto Scheduler Complete | Encounter-local deterministic ordinary combat without ATB. |
   | CXR5 | Complete | Tactical requests, split validation, one-slot queue and ordered execution. |
   | CXR6 | Complete; bounded physical paths qualified by CXR10 | Session-owned Battle presentation, empty production actions at CXR6, feedback/log and typed input. No telegraph without a semantic producer. |
   | CXR7 | Complete; ordinary target touch qualified by CXR10, broader physical multi-opponent combinations deferred | Typed multi-opponent targeting, stable fallback, accepted queue snapshots, source-backed encounter modes. |
   | CXR8 | Implementation/runtime complete; bounded Android PASS | Production cutover, per-opportunity lifecycle barrier, death/corpse/loot/Save integration; explicit armed-SPAR blocker. |
   | CXR9 | Implementation COMPLETE | Starter/result stabilization; real Flee/queue/world/Save; unarmed SPAR; dormant telegraph. Physical changed paths qualified by CXR10. |
   | CXR10 | COMPLETE / FULLY INTEGRATED | Local/full/desktop/physical Android gates, PR review corrections, PR CI, authorized merge and post-main CI PASS. |

   CXR10 has reached green `main`. The owner authorized a fresh Technical Demo release-validation
   branch/candidate and recreated Phase10D3 before the Phase10D Final Audit. Retain the old branch
   as historical evidence. Acceptance does not authorize new gameplay or the Final Audit itself.

7. **Source-valid Beast Foundation + First Serpent Runtime Integration — COMPLETE / FULLY INTEGRATED ON MAIN**

   Following the post-Phase10D planning checkpoint, the owner authorized this bounded source-semantic
   milestone on `phase/beast-foundation-serpent-runtime` from green main `5cf3f4e`.
   [Locked contract and BF1–BF4 evidence](../migration/PHASE_BEAST_FOUNDATION_SERPENT_ANALYSIS.md):
   BF1–BF4 are owner-approved at `0ecf7f5`. [BF5 final audit](../migration/PHASE_BEAST_FOUNDATION_SERPENT_FINAL_AUDIT.md)
   is PASS: **implementation + formal local audit complete**. No BF5 production/test correction.
   Complete canonical16,895 assertions, Python46, repository/static, development/sanitized headless
   and sanitized startup PASS; independent BF1/BF2/BF3/BF4:958/201/162/101 PASS.
   Accepted source-fresh Run A and deterministic QA-wounded Run B are retained without rerunning
   unchanged production. They prove source-derived defeat and controlled death/corpse/loot/control
   return respectively, not balance or natural-victory acceptance. No schema or production spawn changes.
   Lowest-boundary serpent persistence capability is not normal-player serpent Save/Continue.
   [PR #12](https://github.com/Toxicccxz/eastern-stories-godot/pull/12) final PR HEAD
   `0ab0d68c44ba9844d477eed4c1ed0670707bf9a9` merged at
   `a7f0f6fa695a53335878570b80df354a97a48233`; post-merge
   [workflow 34515556524](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34515556524)
   passed all four required jobs. Historical BF5 pre-PR evidence remains unchanged.
   Lake, five production serpent spawns, multi-serpent policy and old-save spawn upgrades are excluded.
   No large-scale creature framework, Phase5B4/poison, or additional beast content is authorized.

8. **Start-of-Game Source Rebaseline — COMPLETE / FULLY INTEGRATED ON MAIN**

   [S0](../migration/PHASE_START_OF_GAME_SOURCE_REBASELINE.md) passed owner review and integrated through
   [PR #14](https://github.com/Toxicccxz/eastern-stories-godot/pull/14) at
   `d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab`.
   Post-main [workflow 34531552148](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34531552148)
   passed all four required jobs. Source ES2 begins at Snow's inn: age14, eight attributes30,
   effective combat_exp0, cloth and no weapon. Historical S0 pre-review wording remains as evidence.

9. **Source-valid New Game Entry — COMPLETE / FULLY INTEGRATED ON MAIN**

   [PR #15](https://github.com/Toxicccxz/eastern-stories-godot/pull/15), final HEAD
   `56ae4ba9bf20b2d7d81b7b9fb5ea5854b23662e2`, merged at
   `047f29083e881156abbdad6ed480bffc1350dfa8`. Post-main
   [workflow 34631309438](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34631309438)
   passed all four required jobs on that merge commit. Branch `phase/source-valid-new-game-entry`
   and its worktree are retained. Below are historical slice checkpoints; later NGE slices supersede
   earlier technical-entry and compatibility wording.
   [NGE0 contract](../migration/PHASE_NEW_GAME_ENTRY_COMPATIBILITY_CONTRACT.md) has owner-approved
   gift B / food-water B / old-save A, recorded in DECISIONS.
   [NGE1 initialization](../migration/PHASE_NEW_GAME_ENTRY_PLAYER_INITIALIZATION.md) implements the
   typed birth/cloth foundation and legacy fixtures without changing current New Game or schema1.
   NGE1 is owner-approved. [NGE2 Inn foundation](../migration/PHASE_NEW_GAME_ENTRY_SNOW_INN.md)
   supplies the neutral resident-map seam, same-authority source Player binding and physical Inn;
   focused regressions and desktop keyboard/collision proof pass. Population/services and remaining
   non-route exits remain deferred; canonical New Game is still Old Pine.
   NGE2 is owner-approved. [NGE3 corridor/handoff](../migration/PHASE_NEW_GAME_ENTRY_SNOW_OUTDOOR_ROUTE.md)
   adds one continuous five-zone outdoor route and shared Inn/Square residency/physical handoff.
   Canonical17,377 and real desktop round trip PASS. NGE3 is owner-approved.
   [NGE4 connection](../migration/PHASE_NEW_GAME_ENTRY_SNOW_OLDPINE_CONNECTION.md) reuses North Approach,
   with one source-capable production Session and real cross-region round trip; canonical17,500 PASS.
   Source-entry has4 resident maps; technical New Game retains2 and its closed north boundary.
   NGE4 is owner-approved. NGE5A pre-audit stopped on the existing strength/body persistence gap.
   [NGE5A0 body facts](../migration/PHASE_NEW_GAME_ENTRY_PLAYER_BODY_FACTS.md) establishes one Player body
   authority, source-correct live-body/death semantics, v1 missing-weight/saved-capacity interpretation,
   and fail-closed lossy v1 capture. Owner-approved exact native body continuation is in DECISIONS.
   Focused260 / canonical17,553 assertions and real desktop binding smoke PASS; NGE5A0 owner-approved.
   [NGE5A versioned continuation](../migration/PHASE_NEW_GAME_ENTRY_VERSIONED_SAVE_CONTINUE.md) implements
   strict v1/v2, explicit two/four-map revision and exact source identity/body/item continuation.
   Focused399 / canonical17,820 assertions, real Snow/Old Pine Save and cold Continue PASS.
   NGE5A is approved. Owner-authorized NGE5A1 removes pre-cutover schema1 compatibility and its
   migration tests while retaining schema2 source continuation and temporary technical-v2 saves.
   Old-save A is SUPERSEDED in DECISIONS; no automatic file deletion or migration is introduced.
   NGE5A1 focused326 / canonical17,747 assertions, Godot4.7.2 headless editor and real source
   Save -> fresh-process Application Continue smoke PASS. NGE5A1 is owner-approved.
   [NGE5B public cutover](../migration/PHASE_NEW_GAME_ENTRY_PUBLIC_CUTOVER.md) implements explicit
   name/gender setup, direct source Snow Inn birth and public SOURCE_ENTRY/schema2 continuation.
   Technical graphs remain internal fixtures only. Focused1636 / expanded UI6027 PASS; real desktop
   public birth/Save/cold Continue/Old Pine reachability PASS. Complete canonical18,192 PASS,
   zero failures/exit0; Android packaged startup/input/validation/Back/Cancel smoke PASS.
   Full Chinese mobile IME/birth and iOS device qualification are not claimed. NGE5B is OWNER APPROVED.
   [NGE6 final audit](../migration/PHASE_NEW_GAME_ENTRY_FINAL_AUDIT.md) corrects public technical-save
   reachability and exact Snow street-join restoration; focused/runtime/sanitizer evidence passes.
   The unique final PR and post-main four-job gates completed successfully as linked above.
   Public New Game now begins in Snow Inn with source birth and exact schema2 continuation.
   This is not full Snow, supply economy, or combat-victory acceptance. Historical phase documents
   keep their original pre-PR checkpoints; they are not new implementation authorization.

10. **Snow Town Core Hub Restoration — FULLY INTEGRATED ON MAIN**

    New major-phase branch `phase/snow-town-core-hub`, based on exact green main
    `047f29083e881156abbdad6ed480bffc1350dfa8`.
    [S1 source rebaseline / dependency analysis](../migration/PHASE_SNOW_TOWN_CORE_HUB_REBASELINE.md)
    is owner-approved/closed. It covers the entire Snow source population/topology/item set,
    actual fresh-player paths, commerce/recovery/teaching dependencies and save-content risks.
    [S2 work income/minimal access](../migration/PHASE_SNOW_TOWN_CORE_HUB_WORK_INCOME.md) is implemented
    and locally validated; S1 and S2 are OWNER APPROVED / CLOSED. No NPC population or commerce is added.
    [S3A currency exchange/payment source contract](../migration/PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_CONTRACT.md)
    is OWNER APPROVED / CLOSED; A–H choices are locked in DECISIONS before production changes.
    [S3B currency/payment core](../migration/PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_IMPLEMENTATION.md)
    implements canonical coin/silver/gold, exact affordability/ordered payment and Bank conversion,
    approved lifecycle substitutions and same-schema cold continuation. S3B is OWNER APPROVED / CLOSED.
    [S4A Inn Vendor/consumables analysis](../migration/PHASE_SNOW_TOWN_CORE_HUB_INN_VENDOR_CONSUMABLES_CONTRACT.md)
    is OWNER APPROVED / CLOSED (analysis only); paid-goods failure, consumable/weapon dependencies,
    denomination access and Save boundaries are recorded as historical decision preparation.
    The separate owner-authorized [S3C Bank physical exchange](../migration/PHASE_SNOW_TOWN_CORE_HUB_BANK_PHYSICAL_EXCHANGE.md)
    now provides same-map mstreet1 ↔ Bank access and UI composition over S3B: real two-Work
    denomination access and Bank Save/cold Continue validated; S3C is OWNER APPROVED / CLOSED.
    This resolves sequencing K. Owner then approved A–J/H1 in DECISIONS before
    [S4B waiter/dumpling](../migration/PHASE_SNOW_TOWN_CORE_HUB_WAITER_DUMPLING.md): staged contact,
    one unlimited source offer, ordered S3B payment/delivery, typed food and shared direct-held use.
    Partial-food continuation and strict embedded item1→2 compatibility pass without changing root
    schema2/SOURCE_ENTRY_V1. Focused489 / canonical18,834 and actual desktop purchase/controlled
    consumption/cold Continue PASS. S4B is OWNER APPROVED / CLOSED; no Bank NPC/accounts, full waiter NPC,
    wine/dagger/chicken/cake or hunger/recovery scheduler is implemented.
    [S5A Player recovery/metabolism analysis](../migration/PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md)
    is OWNER APPROVED / CLOSED. Owner-approved A–M precede
    [S5B cadence](../migration/PHASE_SNOW_TOWN_CORE_HUB_PLAYER_RECOVERY_CADENCE.md): source Player only,
    one transient Session clock/private RNG, Native2s pulses and source6–15-pulse opportunities.
    Pause/combat/conditions/non-ACTIVE/staging freeze; no offline catch-up or cadence Save fields.
    Existing recovery/Work/food formulas remain unchanged. Focused184, natural desktop economy/Eat,
    Pause/Resume and exact cold Continue PASS. S5B is OWNER APPROVED / CLOSED at `add93fcf`.
    [S6A water/drink analysis](../migration/PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md)
    is OWNER APPROVED / CLOSED at `945a8bde`. Owner A–M decisions are implemented in
    [S6B fresh water supply](../migration/PHASE_SNOW_TOWN_CORE_HUB_FRESH_WATER_SUPPLY_LOOP.md):
    source-entry nonpositive dodge→existing Waterfall/zero RNG; canonical red-wine wineskin20;
    same-ID Fill→water15; direct-held noncombat Drink+30 without clamp; strict embedded item3
    continuation, with legal old item1/2 support and unchanged root2/SOURCE_ENTRY_V1.
    Natural desktop supply/Pause Save/cold Continue PASS. Alcohol, Riverbank Fill, Green access,
    condition cadence and further content remain deferred. S6B is OWNER APPROVED / CLOSED at
    `add8d32107277fef7cc57a4a121c64b6b9b5c027`; its evidence is unchanged.
    [S7A north street/core services rebaseline](../migration/PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_CORE_SERVICES_REBASELINE.md)
    is OWNER APPROVED / CLOSED at `04c77650ea72d48cae1173a422a78c3c0188abd5`.
    [S7B physical spine](../migration/PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_PHYSICAL_SPINE.md)
    implements owner-selected A–L: three distinct zones in the same outdoor resident, static
    closed service frontages and external boundaries, with old/new Save continuation.
    Focused188 / canonical19,410 / Python46 and real desktop route/cold Continue PASS.
    Existing supply/eligible recovery meet the approved bounded finish line; loot monetization,
    fast medicine, postal mail, school/smith gameplay and southwest streets remain deferred.
    S1–S7B are OWNER APPROVED / CLOSED. The separately authorized
    [Final Snow Audit](../migration/PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md) is PASS — PR READY:
    fresh canonical19,410 / focused1,666 / Python46, real economy/water/north journeys and
    exact cold Continue pass. The approved bounded implementation is complete.
    [PR #16](https://github.com/Toxicccxz/eastern-stories-godot/pull/16) merged at
    `112f3208937c9f5a480b9f27588af811599937ac`. Post-main
    [workflow 34807091663](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34807091663)
    passed all four required jobs on that exact commit. This closes the bounded Core Hub, not
    all38 Snow rooms or deferred services/NPC population. Historical slice evidence remains intact.

11. **Snow Hockshop / Loot Monetization — COMPLETE / FULLY INTEGRATED ON MAIN**

    [PR #17](https://github.com/Toxicccxz/eastern-stories-godot/pull/17), final audited HEAD
    `c37645dfffd3584ae80072a70d15634947f8ae5d`, merged at
    `eb45d5dbde07a2d6f324d152f0a0082e05eaf518`. Post-main
    [workflow 34874035416](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34874035416)
    passed Godot Verify, Windows Release Build, Android Release Build and iOS Build Validation on
    that exact merge commit. The phase branch `phase/snow-hockshop-loot-monetization` is retained.
    [H1 source contract](../migration/PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md),
    [H2 typed core](../migration/PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CORE.md),
    [H3 physical runtime](../migration/PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_RUNTIME.md) and the
    [Final Hockshop Audit](../migration/PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_FINAL_AUDIT.md)
    are OWNER APPROVED / CLOSED; PR CI, merge and post-main CI are complete.
    The bounded front room provides Value/Sell with exact ItemInstanceId selection, physical
    silver/coin payout, source-ordered capacity loss and scoped failed-clone cleanup. A local
    transient two-sided door, unchanged Save/Continue and real loot→sale→supplies journeys complete
    the loot monetization loop. Historical phase reports retain their original checkpoint evidence.
    Pawn, ticket/retrieve/custody, Hockshop2, auction, merchant NPC/stock, generic merchant/door
    engines, other Snow services (Herbshop/Postoffice/School/Smithy), Green/Goathill and full Snow
    parity remain deferred. Mobile CI builds do not establish physical-device qualification.

12. **Snow First Progression Loop / 淳风武馆 — FULLY INTEGRATED / CLOSED**

    [PR #19](https://github.com/Toxicccxz/eastern-stories-godot/pull/19) merged by standard merge
    commit `cd07808cb76147d0b8c0dad9b82d078b49fefe64`. Accepted post-main
    [run 34985105844](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34985105844)
    passed Godot Verify, Windows Release Build, Android Release Build and iOS Build Validation
    on that exact merge SHA. This is prior integration evidence, not a new tooling CI run.

    The [complete milestone Final Audit](../migration/PHASE_SNOW_FIRST_PROGRESSION_FINAL_AUDIT.md)
    covers base `88be5c0e` through pre-audit `6379af74`: Type A12 / Type B10 / Type C0,
    HIGH blockers0, Snow outdoor16 plus Inn=17. The single docs-only audit commit becomes the
    frozen audited head after exact-commit local verification/push; PR #19 subsequently integrated it.
    Earlier slice authorization checkpoints remain historical.

    [P1 source/dependency analysis](../migration/PHASE_SNOW_FIRST_PROGRESSION_SOURCE_ANALYSIS.md)
    is OWNER APPROVED / CLOSED. Authorized [P2](../migration/PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md)
    implements the three-zone school, transient two-sided gate, Liu teaching contact,
    first apprenticeship, basic unarmed Learn and compatible root2 persistence on the same branch.
    [ZE1's narrow zero-EXP defense fix](../migration/PHASE_SNOW_FIRST_PROGRESSION_COMBAT_ZERO_EXP_FIX.md)
    passes focused combat1,466 / Snow247 / canonical20,261 / Python46 locally.
    The [fresh evidence-only rerun](../migration/PHASE_SNOW_FIRST_PROGRESSION_RUNTIME.md#fresh-live-acceptance-2026-09-15-utc)
    on ZE1 `315d3863a5b72fbbb3f84006440d7b9e796bf512` passed one New Game→apprentice→raw3→
    nine production encounters with real Flee/natural recovery→E2→physical return→Learn raw4→
    real Save→complete process termination→cold Continue. Entire encoded state and all three
    persisted RNG streams matched; one cold resident/correct camera/closed gate, no active encounter.
    The lengthy recovery route is evidence of completion, not a balance qualification.
    Only authorized docs record this result; no gameplay/EXP/RNG workaround or schema change.
    The historical pre-PR checkpoint is superseded by the completed integration above.
    Final Audit passed with disclosed non-blocking risks. Snow P3 remains unauthorized.

13. **Migration Tooling v1 — COMPLETE / FULLY INTEGRATED ON MAIN**

    The following P1/P2/P2F summary records historical delivery/audit checkpoints. The final closeout
    at the end of this item supersedes their earlier BLOCKED / awaiting-review / authorization statements.

    [P1 analysis](../migration/MIGRATION_TOOLING_V1_P1_ANALYSIS.md) is OWNER APPROVED / CLOSED at
    `0e5ff6a5cbc8d4091102e280c66868ba8763b4bb`. Owner-locked D1–D9 are in
    [DECISIONS](../migration/DECISIONS.md#migration-tooling-v1-p2--owner-locked-extraction-boundary).
    P2 on `phase/migration-tooling-v1` is bounded to static direct-ROOM extraction, provenance
    and explicit findings using Python standard-library tooling.
    [Implementation/local verification](../migration/MIGRATION_TOOLING_V1_P2_STATIC_ROOM_EXTRACTOR.md)
    is OWNER APPROVED / CLOSED. First Final Audit was BLOCKED, with owner-confirmed HIGH2 / MEDIUM3.
    Approved/closed [P2F1 fixes](../migration/MIGRATION_TOOLING_V1_P2F1_AUDIT_BLOCKER_FIXES.md) resolved those five.
    Re-Final Audit was BLOCKED on HIGH1 nested manual metadata overwrite and MEDIUM1 MONEY/COMBINED_ITEM
    admission. [P2F2](../migration/MIGRATION_TOOLING_V1_P2F2_RE_AUDIT_BLOCKER_FIXES.md) is OWNER APPROVED / CLOSED.
    Owner review found one additional MEDIUM D2 gap in standard weapon/armor symbol/literal admission exclusions.
    [P2F3](../migration/MIGRATION_TOOLING_V1_P2F3_WEAPON_ARMOR_ADMISSION_FIXES.md) is OWNER APPROVED / CLOSED.
    Owner's globals D2 sweep found BULLETIN_BOARD/CHARACTER/EQUIP/POWDER still missing.
    [P2F4](../migration/MIGRATION_TOOLING_V1_P2F4_STANDARD_OBJECT_ADMISSION_FIXES.md) is OWNER APPROVED / CLOSED.
    Final Re-Audit after P2F4 was BLOCKED by FR-01 HIGH comment-prefixed directive recognition.
    [P2F5](../migration/MIGRATION_TOOLING_V1_P2F5_COMMENT_PREFIXED_DIRECTIVE_FIXES.md) is OWNER APPROVED / CLOSED; FR-01 closed.
    Final Re-Audit after P2F5 was BLOCKED by FR5-01 MEDIUM false quarantine of closed multiline directive comments.
    [P2F6](../migration/MIGRATION_TOOLING_V1_P2F6_MULTILINE_DIRECTIVE_COMMENT_FIXES.md) is OWNER APPROVED / CLOSED; FR5-01 closed.
    Final Re-Audit after P2F6 was BLOCKED by raw #echo semantics: FR6-01 HIGH hazard bypass and FR6-02 blocking MEDIUM false quarantine.
    Authorized [P2F7](../migration/MIGRATION_TOOLING_V1_P2F7_RAW_ECHO_DIRECTIVE_FIXES.md) fixes raw echo boundaries and payload handling;
    LOCAL focused18/migration136/full Python182/static and byte-identical version1.0.7 corpus runs pass.
    Exit1 retains13 quarantined source objects; facts2,804/findings4,457; no object delta. P2F7 is OWNER APPROVED / CLOSED.
    Final Re-Audit after P2F7 was BLOCKED on FR7-01 HIGH resolved-include semantic hazards.
    [P2F8](../migration/MIGRATION_TOOLING_V1_P2F8_RESOLVED_INCLUDE_SEMANTIC_HAZARDS.md) implements recursive
    structural hazard summaries; LOCAL focused25/migration161/full Python207/static pass and version1.0.8
    corpus double-run is byte-identical, with no object delta. P2F8 is CLOSED.
    Final Re-Audit after P2F8 was BLOCKED on FR8-01 HIGH macro-alias semantic hazards.
    [P2F9](../migration/MIGRATION_TOOLING_V1_P2F9_MACRO_ALIAS_SEMANTIC_HAZARDS.md) adds bounded macro summaries
    and structural-use checks; LOCAL focused27/prior96/migration188/full Python234/static pass,
    210 external CLI cases pass, and version1.0.9 corpus A/B is byte-identical with no object delta.
    P2F9 is CLOSED. Final Re-Audit after P2F9 was BLOCKED on FR9-01 HIGH signature/body macro hazards.
    [P2F10](../migration/MIGRATION_TOOLING_V1_P2F10_MACRO_STRUCTURAL_BOUNDARY_BODY_HAZARDS.md) adds bounded
    effect classification across full signatures and bodies; LOCAL focused54/prior123/migration242/
    full Python288/static pass. Version1.0.10 A/B is byte-identical: supported485, OUT_OF_SCOPE1,838,
    QUARANTINED13, facts2,736/findings4,296; 14 affected candidates are listed in the fix report.
    P2F10 is CLOSED. Final Re-Audit after P2F10 was BLOCKED on FR10-01 blocking MEDIUM / D9:
    legal create-tail directives were falsely quarantined.
    [P2F11](../migration/MIGRATION_TOOLING_V1_P2F11_CREATE_BODY_DIRECTIVE_SEGMENTATION.md) adds two-phase
    directive segmentation/reliability checks; LOCAL focused38/prior177/migration280/full Python326/static
    and 204 external CLI cases pass. Version1.0.11 A/B is byte-identical with no object/fact delta;
    all 14 ANSI exclusions remain. P2F11 is CLOSED. Final Re-Audit after P2F11 Rerun was BLOCKED on
    FR11-01 / blocking MEDIUM / D9: macro-supplied delimiter imbalance was falsely quarantined before
    macro analysis. ARCHIVE-01 is CLOSED and historical audit bytes remain preserved.
    [P2F12](../migration/MIGRATION_TOOLING_V1_P2F12_PRE_PAIR_MACRO_DELIMITER_UNCERTAINTY.md) implements
    a lazy actual-use pairing-uncertainty gate after authored pairing fails, preserving the normal path.
    P2F12 is CLOSED. Final Re-Audit after P2F12 was BLOCKED on FR12-01 / blocking MEDIUM / D9:
    raw include delimiters and standalone header fragments were falsely quarantined.
    [P2F13](../migration/MIGRATION_TOOLING_V1_P2F13_INCLUDE_FRAGMENT_PAIRING_CLASSIFICATION.md) adds lazy
    resolved-fragment pairing refusal and separates header lexical corruption from structural incompleteness.
    P2F13 is CLOSED. Final Re-Audit after P2F13 was BLOCKED on FR13-01 / blocking MEDIUM / D9:
    preprocessor-supplied inherit terminators were falsely quarantined before declaration-boundary analysis.
    [P2F14](../migration/MIGRATION_TOOLING_V1_P2F14_PREPROCESSOR_INHERIT_DECLARATION_BOUNDARY.md) adds
    declaration-scoped conservative refusal before fact emission, preserving true unterminated-inherit detection.
    P2F14 is CLOSED. Final Re-Audit after P2F14 was BLOCKED on FR14-01 / blocking MEDIUM / D9:
    apparent declaration/function boundaries discarded actual preprocessing-sensitive pending-inherit uses.
    [P2F15](../migration/MIGRATION_TOOLING_V1_P2F15_PREPROCESSOR_SENSITIVE_PENDING_INHERIT_BOUNDARY.md)
    preserves that boundary evidence before uncertainty analysis; true authored boundary errors remain detected.
    P2F15 is CLOSED. Final Re-Audit after P2F15 was BLOCKED on FR15-01 / blocking MEDIUM / D9:
    actual empty macro uses at create tails were falsely quarantined as unfinished runtime statements.
    [P2F16](../migration/MIGRATION_TOOLING_V1_P2F16_PREPROCESSOR_SENSITIVE_CREATE_TAIL_COMPLETION.md)
    adds bounded tail-specific macro classification while retaining genuine unfinished-runtime quarantine.
    P2F16 is CLOSED. Final Re-Audit after P2F16 was BLOCKED on FR16-01 / HIGH / mapping fact-safety:
    literal exit facts survived inside preprocessing-uncertain mappings.
    [P2F17](../migration/MIGRATION_TOOLING_V1_P2F17_PREPROCESSOR_UNCERTAIN_EXIT_MAPPING_FACT_SAFETY.md)
    stages exit candidates and suppresses unreliable exit sequences while preserving independent facts.
    P2F17 is CLOSED. Final Re-Audit after P2F17 was BLOCKED on FR17-01 / HIGH / D3-D6:
    nested exit setters could leave another setter's literal exit facts in the create sequence.
    [P2F18](../migration/MIGRATION_TOOLING_V1_P2F18_NESTED_CREATE_EXIT_SEQUENCE_UNCERTAINTY.md)
    propagates skipped create-region exit uncertainty while preserving reliable flat exits and unrelated facts.
    P2F18 is CLOSED. Final Re-Audit after P2F18 was BLOCKED on FR18-01 / HIGH / D3-D6:
    whole-exits calls hidden inside setter values bypassed create exit-sequence refusal.
    [P2F19](../migration/MIGRATION_TOOLING_V1_P2F19_CREATE_SCOPE_EXIT_MUTATION_FINALIZER_BACKSTOP.md)
    adds exact flat-setter registration and an exhaustive authored create-call finalizer backstop.
    P2F19 is CLOSED. Final Re-Audit after P2F19 was BLOCKED on FR19-01 / HIGH / D3-D6:
    grouped property keys bypassed the shared create exit-mutation classifier.
    [P2F20](../migration/MIGRATION_TOOLING_V1_P2F20_CONSERVATIVE_EXIT_MUTATION_KEY_CLASSIFICATION.md)
    classifies redundantly grouped static text keys and conservatively refuses unknown current-object mutation keys.
    P2F20 is CLOSED. Final Re-Audit after P2F20 was BLOCKED on FR20-01 / blocking MEDIUM / D9:
    chained function-macro results lost separate authored invocation lists and falsely quarantined create tails.
    [P2F21](../migration/MIGRATION_TOOLING_V1_P2F21_CHAINED_CREATE_TAIL_MACRO_CONTINUATIONS.md)
    preserves bounded callable continuation metadata without macro expansion or argument substitution.
    P2F21 is CLOSED. Initial Final Re-Audit after P2F21 was preflight-blocked operationally by a dirty
    game/project.godot; no semantic blocker was assigned. The semantic rerun was BLOCKED on
    FR21-01 / blocking MEDIUM / D9: an actual macro use of the authored inherit keyword was falsely quarantined.
    [P2F22](../migration/MIGRATION_TOOLING_V1_P2F22_MACRO_SHADOWED_INHERIT_KEYWORD_SAFETY.md)
    refuses such macro uses before inheritance parsing while preserving uninvoked function-macro controls.
    P2F22 is CLOSED. Final Re-Audit after P2F22 was BLOCKED on FR22-01 / HIGH / D2-D3:
    a preprocessing-only prefix hid an authored top-level inherit and allowed an unsafe fact subset.
    [P2F23](../migration/MIGRATION_TOOLING_V1_P2F23_PREPROCESSOR_SENSITIVE_INHERIT_PREFIX_SAFETY.md)
    adds a pre-admission full-object refusal gate without expansion or hidden declaration recovery.
    P2F23 is CLOSED. Final Re-Audit after P2F23 was BLOCKED on FR23-01 / HIGH / D2-D3:
    preprocessing-sensitive function adjacency hid set overrides or duplicate create structure and leaked facts.
    [P2F24](../migration/MIGRATION_TOOLING_V1_P2F24_CRITICAL_FUNCTION_STRUCTURE_PREPROCESSING_CONSOLIDATION.md)
    addresses FR23-01 across root and resolved dependency authored structure before any fact allocation.
    Attempt 1 stopped on a hidden header setter; Attempt 2 shares one bounded scanner across reached units,
    preserves root include provenance, and passes both independent consolidation sweeps and complete local gates.
    P2F24 is CLOSED. Final Re-Audit after P2F24 was BLOCKED on FR24-01 / HIGH / D2-D3:
    directives could split inheritance evidence or pollute a direct inherit expression before exclusion.
    [P2F25](../migration/MIGRATION_TOOLING_V1_P2F25_DIRECTIVE_SENSITIVE_INHERIT_STRUCTURE_PREFLIGHT.md)
    moves shared root/dependency inheritance safety ahead of raw structural segmentation and refuses directive-sensitive declarations before fact allocation.
    P2F25 is CLOSED. Final Re-Audit after P2F25 was BLOCKED on FR25-01 / HIGH / D2-D3.
    [P2F26](../migration/MIGRATION_TOOLING_V1_P2F26_MACRO_SUPPLIED_CRITICAL_FUNCTION_IDENTITY_PREFLIGHT.md)
    extends the pre-segmentation gate to macro-supplied critical function identities. Attempt 1 stopped
    before commit on helper/EMPTY over-refusal; Attempt 2 stopped on macro-supplied declaration-prefix
    regression. Neither adds a semantic blocker number. Attempt 3 uses bounded declaration-prefix
    and function-name slot classification, preserving helper controls and critical structural refusal.
    P2F26 is CLOSED. Final Re-Audit after P2F26 was BLOCKED on FR26-01 / HIGH / D2-D3.
    [P2F27](../migration/MIGRATION_TOOLING_V1_P2F27_DIRECTIVE_TRANSPARENT_FUNCTION_MACRO_INVOCATION_PREFLIGHT.md)
    Attempt 1 stopped before commit because increased macro-call precision widened a frozen conservative helper case.
    Attempt 2 deliberately tightens static-room-v1: a directive-separated possible function-macro invocation
    in an unresolved top-level declaration header forces full-object refusal, with intentional D2/D3 false-negative bias.
    Direct-adjacent invocation retains the P2F26 classifier; no terminal recovery across directives.
    P2F27 is CLOSED. Final Re-Audit after P2F27 was BLOCKED on FR27-01 / HIGH / D2-D3.
    [P2F28](../migration/MIGRATION_TOOLING_V1_P2F28_UNSUPPORTED_DECLARATION_PREFIX_PREPROCESSING_REFUSAL.md)
    treats unsupported pre-name declaration-prefix syntax as unresolved structure; participating
    preprocessing-sensitive function structure forces full-object refusal. No array/pointer grammar is added.
    P2F28 is CLOSED. Final Re-Audit after P2F28 was BLOCKED: FR28-01 / HIGH / D2-D3.
    [P2F29](../migration/MIGRATION_TOOLING_V1_P2F29_UNRESOLVED_DECLARATION_HEADER_REFUSAL.md)
    Attempt 1 stopped before commit because macro SET/CREATE summaries still prematurely resolved an unresolved declaration header.
    Attempt 2 makes DECLARATION_HEADER_UNRESOLVED absorbing with respect to macro semantic roles.
    Only direct authored name(signature){body} evidence or a hard top-level boundary may resolve/reset that header state.
    No LPC type whitelist or declaration grammar was added. Preprocessing-sensitive unresolved declarations force full-object refusal.
    P2F29 is OWNER APPROVED / CLOSED for FR28-01; its historical migration491/full Python537 and 8,504 CLI passed.
    The completed Final Re-Audit after P2F29 was BLOCKED: FR29-01 / blocking MEDIUM / D2, D6.
    [P2F30](../migration/MIGRATION_TOOLING_V1_P2F30_REACHED_HEADER_EOF_UNRESOLVED_DECLARATION_REFUSAL.md)
    preserves unresolved preprocessing-sensitive reached-header EOF state at the shared early gate, before inheritance metadata or facts.
    P2F30 is OWNER APPROVED / CLOSED for FR29-01. Its historical focused53/migration502/full Python548, retained8,504 + new514 = 9,018 CLI,
    31-version compatibility, output security and deterministic corpus A/B pass; supported485 and all semantic projections remain unchanged.
    The completed Final Re-Audit after P2F30 was BLOCKED: FR30-01 / blocking MEDIUM / D2, D6.
    [P2F31](../migration/MIGRATION_TOOLING_V1_P2F31_INVOKED_INHERIT_MACRO_DECLARATION_PREFLIGHT.md)
    routes actual invoked inherit macros through shared declaration preflight; uninvoked function macros retain ordinary inheritance handling.
    P2F31 is OWNER APPROVED / CLOSED for FR30-01. Its historical focused11/combined84/migration513/full Python559, retained9,018 + new1,080 = 10,098 CLI pass.
    32-version compatibility, output security and corpus A/B pass; supported485, genuine quarantines13, ANSI exclusions14; no corpus semantic delta except version.
    The completed Final Re-Audit after P2F31 was BLOCKED: FR31-01 / blocking MEDIUM / D2, D6.
    [P2F32](../migration/MIGRATION_TOOLING_V1_P2F32_PREPROCESSING_SENSITIVE_INHERIT_KEYWORD_RECOVERY.md)
    preserves active preprocessing-sensitive declaration state before ordinary inherit keyword recovery, including reached-header EOF.
    P2F32 is OWNER APPROVED / CLOSED for FR31-01. Its historical focused12/combined96/migration525/full Python571, retained10,098 + new940 = 11,038 CLI pass.
    33-version compatibility, output security and corpus A/B pass; supported485, genuine quarantines13, ANSI exclusions14; only extractor_version changes in the corpus.
    The completed Final Re-Audit after P2F32 was BLOCKED: FR32-01 / blocking MEDIUM / D2, D6.
    [P2F33](../migration/MIGRATION_TOOLING_V1_P2F33_PENDING_PREPROCESSING_DECLARATION_EOF_REFUSAL.md)
    tracks pending preprocessing declaration evidence independently of name state and refuses reached EOF before inheritance/fact allocation.
    P2F33 is OWNER APPROVED / CLOSED for FR32-01. Its historical focused15/combined111/migration540/full Python586 and 12,370 CLI passed.
    The completed Final Re-Audit after P2F33 was BLOCKED on FR33-01: actual macro uses after AFTER_NAME missed pending declaration evidence.
    [P2F34](../migration/MIGRATION_TOOLING_V1_P2F34_STATE_INDEPENDENT_PREPROCESSING_DECLARATION_WITNESS.md)
    records actual macro/invocation participation before name-state routing; the retained candidate is unchanged on resume.
    Fresh pre-commit focused18/combined129/migration558/full Python604 and retained12,370 + new1,264 = 13,634 structural CLI pass.
    Separate AR-01 controls: 20 CLI PASS final-safety oracle, not early-refusal precision. Prior Attempt 1 remains a historical BLOCKED stop.
    35-version compatibility, output security, 9,587 provenance/IDs and corpus A/B pass; supported485, quarantines13, ANSI exclusions14;
    only extractor_version changes versus exact P2F33. P2F34 is OWNER APPROVED / CLOSED; FR33-01 is CLOSED at implementation level.
    This was implementation repair 40; the subsequent Final Re-Audit passed Gate A but stopped Gate B on FR34-01 false quarantine.

    Owner-frozen final blocking threshold: unsafe admission/facts/exits; false quarantine; integrity/provenance/ID/manifest/summary failures;
    output/security/schema/version/atomic-write failures; or dangerous unexplained real-corpus semantic regression.
    Safe conservative synthetic cases ending candidate=false, OUT_OF_SCOPE, facts=[], no new exits or false quarantine, truthful provenance,
    and no dangerous corpus delta are not independently blocking merely for later refusal or retained non-consumed structural metadata.
    AR-01 (OPEN literal declaration prefix + directive, late include refusal) is ACCEPTED / NON-BLOCKING. Existing FR29-FR33 early-refusal
    oracles remain mandatory. Other safe residuals do not automatically authorize a repair; genuine safety blockers require an owner stop.
    DECISIONS.md remains unchanged.

    [P2F35](../migration/MIGRATION_TOOLING_V1_P2F35_DIRECTIVE_SEPARATED_PAIRING_UNCERTAINTY.md) repairs FR34-01 (blocking MEDIUM / D9 / safety class C),
    semantic blocker41, by recognizing possible function-macro argument ownership across only consecutive directives after root pairing fails.
    Gate A remains historically PASS; frozen13,634 structural regression and accepted AR-01 final-safety20 pass. No declaration-state redesign.
    Fresh pre-commit focused10/combined139/migration568/full Python614; pairing984+primary4 CLI;36-version/security/33-position schema checks pass.
    Corpus A/B:2336/485 supported/13 genuine quarantines, facts2736/findings4296; only version delta versus exact P2F34;9587 provenance and14 ANSI pass.
    All immutable post-commit gates must pass before normal push; this remains implementation repair, not milestone Final Re-Audit certification.
    Systematic Quarantine-Path Audit / Gate B remains BLOCKED / INCOMPLETE pending owner review and later authorization.
    ARCHIVE-01 remains CLOSED. All31 owner-local historical evidence files remain byte-identical, untracked and unstaged.
    P2F35 is now OWNER APPROVED / CLOSED; its subsequent Final Re-Audit was BLOCKED by FR35-01 HIGH output-protection bypass.

    [P2F36](../migration/MIGRATION_TOOLING_V1_P2F36_FAIL_CLOSED_GIT_OUTPUT_PROTECTION.md) implements FR35-01 (semantic blocker42 / D7-D9 / safety class E):
    failed Git probes inspect ancestor .git markers without following indirection; ambiguous/failed inspection returns exit2 before scan/write.
    Healthy tracked/ls-files protection remains intact; marker-free non-Git external output remains allowed. No Git safety/config bypass.
    Resume corrected only six version-test registration sites; Attempt 1 remains frozen as a non-semantic acceptance gap. Fresh pre-commit focused18/combined157/migration586/full Python632 pass;39 independent output cases+2 real CLI,37 canonical versions/33 pollution positions pass.
    FR34 primary4/pairing984, Gate A13,634 and AR-01 final-safety20 pass; corpus A/B2336/485/13Q/facts2736/findings4296,9587 provenance and14 ANSI pass.
    Only extractor_version changes versus exact P2F35; parser bytes otherwise unchanged. All33 owner-local evidence files remain untracked/unstaged/byte-identical; ARCHIVE-01 CLOSED.
    All immutable post-commit gates must pass before normal push. Gate B remains BLOCKED / INCOMPLETE; this is implementation repair, not Final Re-Audit certification.
    At the P2F36 delivery gate, further slices/integration remained unauthorized; the owner subsequently authorized the P2F37 resume below.

    P2F36 is now OWNER APPROVED / CLOSED. Its Final Re-Audit stopped on FR36-01 diagnostic-output exit classification (blocker43, Class E, D9).
    [P2F37](../migration/MIGRATION_TOOLING_V1_P2F37_STABLE_FATAL_EXIT2_DIAGNOSTIC_BOUNDARY.md) implementation is delivered: FR36-01 is repaired at implementation level.
    Attempt1 remains a frozen historical stop; this resume preserves its fatal reporter and adds only a local argparse diagnostic transport override.
    Healthy argparse semantics remain; broken diagnostic write/flush reaches the fatal-safe sink, preserving real process exit2 and empty stdout without target mutation.
    Fresh pre-commit focused24/combined181/migration610/full Python656 pass; FR36 independent24, FR35 matrix39+real2, FR34 primary4/pairing984 pass.
    Gate A remains PASS/FROZEN with13634 fresh CLI; AR-01 remains accepted with20 final-safety passes.38 versions/6 invalid classes/33 pollution positions pass.
    Corpus A/B and exact P2F36 projection differ only by extractor_version1.0.37;13Q/14ANSI/9587 provenance pass. All35 owner-local reports remain byte-identical; ARCHIVE-01 CLOSED.
    At the P2F37 delivery checkpoint, Gate B was BLOCKED / INCOMPLETE pending owner-authorized continuation;
    PR/merge authorization and remote CI were still pending. The final closeout below supersedes that checkpoint.

    Final bounded certification PASS — OWNER APPROVED / CLOSED: Gate A PASS / FROZEN;
    Gate B (Systematic Quarantine-Path Audit) PASS; 43 / 43 historical semantic blockers CLOSED;
    new A–F blockers 0; AR-01 ACCEPTED / NON-BLOCKING conservative residual; ARCHIVE-01 CLOSED.
    Certified phase head `ae2bc306e3060d2ddc700c1da5c75832612e0de5` was merged through
    [PR #20](https://github.com/Toxicccxz/eastern-stories-godot/pull/20) by normal merge commit
    `ea23ef666a347753fe52e261279e8a005ae0bafc`, retaining the complete 43-commit phase history.
    [Pre-merge CI 36058469131](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36058469131)
    on the certified head and
    [post-merge CI 36062042977](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36062042977)
    on the exact merge commit both passed Godot Verify, Android Release Build, Windows Release Build
    and iOS Build Validation. The implementation/audit loop is closed; no P2F38 or additional Final Re-Audit is planned.

    NPC extraction, item extraction, Bank/Hockshop/ClassGuild extraction profiles, Native importer/generator
    and mass content generation remain deferred. No Migration Tooling P3 is automatically authorized or
    designated as the next project milestone. Snow Martial Progression II also requires separate owner authorization.


14. **Snow Martial Progression II — COMPLETE / MERGED / POST-MERGE VERIFIED.**

    [Final Audit](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_FINAL_AUDIT.md) PASS on
    `c026bd1793e34c1f65829aee5f21d9999ec291aa`: 13 commits / 110 files from main,
    blocking HIGH=0 / MEDIUM=0. P1/P2, P2R1, P2R2 and automated acceptance are
    OWNER APPROVED / CLOSED. Test-only EXP6/basic4 prerequisites remain distinct
    from natural EXP capability; Learn to liuh5, Enable, four-action Combat and exact
    public Save/fresh-graph Continue pass. Natural time-to-EXP6 pacing/usability is
    NON-BLOCKING FOR ENGINEERING INTEGRATION and deferred to human playtesting.
    Godot AI 4.0.4→4.2.3 is accepted as a separate, bounded dependency update.
    Recorded Final Audit gates PASS: story110 / focused2,055 / canonical21,055 assertions, 0 failures;
    Python3.12 656 tests; static, official Godot4.7.2 headless/editor, actual sanitizer,
    sanitized import and phase/current doc checks. These are historical acceptance results,
    not new gameplay verification in this docs closeout.

    [PR #22](https://github.com/Toxicccxz/eastern-stories-godot/pull/22) integrated certified
    phase head `04b83b3e8a49af3d617caab40c12a78e2d9a8233` by normal merge commit
    `1194b8d5fa0a1d3b0a1ee1f58b1c56c3d7f663bf`, preserving the phase history.
    [Post-merge main workflow 36174253078](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36174253078)
    passed on that exact merge SHA: Godot Verify, Android Release Build, Windows Release Build
    and iOS Build Validation all **success**. The phase is closed absent a concrete regression;
    no additional Final Re-Audit is planned. Lake/serpent and other future gameplay phases,
    Phase5B4 and Migration Tooling P3 remain deferred and require separate owner authorization.

    **Historical checkpoints below:** earlier live requirements and pending repair
    approval wording are superseded by the owner decision above.

    [P2R2 generalized names](../migration/PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md) is implemented/locally verified: 2,303 focused / 20,945 canonical assertions; 656 Python tests; all static/editor/sanitizer/diff/link gates PASS. This bounded Type B adjustment adds configurable Unicode names and preserves exact identity and birth/combat/Liuh/Save contracts. Starting HEAD `3cf9c67e4514e9131f1492a36454ebc625376608` and the Godot AI update are owner-accepted; two desktop viewport entries are restored by separate owner authorization. Await owner review before any live acceptance. No PR, merge, Final Audit or P3.

    [P1 source analysis](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_SOURCE_ANALYSIS.md) is approved at
    `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd`. [D-SMP2-01 through 08](../migration/DECISIONS.md#snow-martial-progression-ii--owner-locked-p2-boundary)
    lock the minimal Liuh-Ken slice on `phase/snow-martial-progression-liuh-ken`:
    existing Liu Learn/Enable/Disable, four actions through existing Combat, authored feedback,
    natural EXP >=6 / unarmed >=4 / liuh >=5 and exact full-process Save/Continue.
    [P2 implementation/local gates](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_RUNTIME.md) PASS: 20,544 gameplay assertions and 656 Python tests. Implementation is OWNER APPROVED / FROZEN at `81d0cb63da15f9e384392de98cbaa3fd21475a51`. Owner classified [Attempt1](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_BLOCKER.md) as INCONCLUSIVE / OPERATIONAL-CONTROL FAILURE. [Attempt2](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_ATTEMPT2_BLOCKED.md) reached natural EXP1/raw3 and verified real pause, then stopped on a QA input-script compile failure before Flee (0 completed encounters); owner classification is INCONCLUSIVE / OPERATIONAL INPUT SCRIPT FAILURE. [Attempt3](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_ATTEMPT3_BLOCKED.md) is ACCEPTANCE TOOLING TRANSPORT BLOCKED before Player creation: existing mouse/Escape passed, Chinese name input returned `Unknown key: 林`; no temporary input script, Player or encounter. Those historical attempts establish no product/pacing defect.
    [Changed-path acceptance](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_CHANGED_PATH_LIVE_ACCEPTANCE.md) used the owner-authorized existing fixture, verified exact source birth, and performed real travel/apprenticeship/Learn to raw3. First combat reached EXP1 but early pause/Flee was not completed (0 successful encounters). BLK-SMP2-01 stopped source-cloth death handling at INVALID_ITEM_FACTS / DEATH_INVENTORY_BLOCKED / LIFECYCLE_FAILED. Owner review identified missing aligned cloth armor facts; independent base-to-P2 comparison confirms a pre-existing source-entry / Player-death integration defect, not a Liuh regression. [P2R1](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md) repairs only that projection and adds source Player death/corpse regressions. P2R1 is OWNER APPROVED / CLOSED; approved executable/test freeze is `798842879ebea52b33e7e2136f606a3741659590`. [Post-P2R1 preflight](../migration/PHASE_SNOW_MARTIAL_PROGRESSION_II_POST_P2R1_LIVE_ACCEPTANCE.md) stopped before bootstrap because installed input_sequence cannot express the required atomic Escape/mouse events. No new Player or encounter; tooling capability gap, not a product/P2R1 regression. Live acceptance remains OPEN / BLOCKED; await owner review.
    No PR, merge, automatic Final Audit or P3. Other arts, force/exercise, practice/study,
    perform/exert, school expansion, general hooks/Phase5B4, Lake/serpent and Migration Tooling P3/Native generation remain deferred.
