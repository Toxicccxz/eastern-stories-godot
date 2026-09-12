# Productionization Roadmap

Each numbered item below is currently planned as an independent major integration milestone: one
major-phase branch and one final PR, unless a later explicit planning decision changes that boundary.
Internal analysis, implementation slices, and audit fixes remain on that milestone's branch.

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

10. **Snow Town Core Hub Restoration — S3C IMPLEMENTATION COMPLETE / AWAIT OWNER REVIEW**

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
    denomination access and Save boundaries require decisions before S4B (NOT AUTHORIZED).
    The separate owner-authorized [S3C Bank physical exchange](../migration/PHASE_SNOW_TOWN_CORE_HUB_BANK_PHYSICAL_EXCHANGE.md)
    now provides same-map mstreet1 ↔ Bank access and UI composition over S3B: real two-Work
    denomination access and Bank Save/cold Continue validated, awaiting owner review.
    This resolves sequencing K, not S4A A–J. No Vendor purchasing or Bank NPC/accounts is implemented.
    Subsequent proposed order is owner-reviewed physical commerce/Inn supplies, world-active recovery, school/weapon access, narrow teaching,
    then bounded smith/medicine support. These are review proposals, not approved slices or a
    mandate to port every room/NPC. Finance defects, timing/reset policy, broken authored chains
    and source-save cutoff require explicit decisions before affected implementation.
    No final PR, merge, Lake, full population or Phase5B4 is authorized by this analysis.
