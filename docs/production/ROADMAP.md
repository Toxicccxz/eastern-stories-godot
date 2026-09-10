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

7. **Source-valid Beast Foundation + First Serpent Runtime Integration — BF1 complete; milestone in progress**

   Following the post-Phase10D planning checkpoint, the owner authorized this bounded source-semantic
   milestone on `phase/beast-foundation-serpent-runtime` from green main `5cf3f4e`.
   [Locked contract and BF1 evidence](../migration/PHASE_BEAST_FOUNDATION_SERPENT_ANALYSIS.md):
   Beast formulas/defaults, exact NPC RNG order and typed serpent definition pass 958 focused assertions
   and slice self-audit. Stop for owner review before BF2 live Combat projection, BF3 race-aware
   persistence/death, BF4 controlled QA runtime integration, or BF5 formal audit.
   These slices share one branch and eventual final PR; no PR/merge yet.
   Lake, five production serpent spawns, multi-serpent policy and old-save spawn upgrades are excluded.
   No large-scale creature framework, Phase5B4/poison, or additional beast content is authorized.
