# Productionization Status

## Current milestone

**Source-valid New Game Entry — NGE5B IMPLEMENTATION COMPLETE / AWAIT OWNER REVIEW**
is the current owner-authorized milestone on `phase/source-valid-new-game-entry`, based on green main
`d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab`.
[NGE0 compatibility contract](../migration/PHASE_NEW_GAME_ENTRY_COMPATIBILITY_CONTRACT.md)
is owner-approved for gift B (no delayed reroll) and food/water B (fresh post-body fill).
Its historical legacy-native-save A is now SUPERSEDED by NGE5A1, as recorded in DECISIONS.
[NGE1 foundation](../migration/PHASE_NEW_GAME_ENTRY_PLAYER_INITIALIZATION.md) adds typed Player facts,
deterministic source birth and actual cloth composition, with legacy identity/death/save boundaries.
NGE1 is owner-approved. [NGE2 physical Inn](../migration/PHASE_NEW_GAME_ENTRY_SNOW_INN.md) adds the
neutral resident-map seam and QA-only source Player entry; 6,328 focused assertions and real desktop
Inn movement/collision plus canonical New Game regression PASS. Repository-content sanitizer PASS;
direct worktree sanitizer remains affected by ignored owner-local Godot AI update backups (untouched).
NGE2 is owner-approved. [NGE3 outdoor route](../migration/PHASE_NEW_GAME_ENTRY_SNOW_OUTDOOR_ROUTE.md)
adds one continuous Square/south/east corridor and shared Inn/Square handoff. Complete canonical
17,377 assertions and real desktop birth -> eroad3 -> Inn round trip PASS; identities and resources
preserved. NGE3 is owner-approved. [NGE4 unified source-entry connection](../migration/PHASE_NEW_GAME_ENTRY_SNOW_OLDPINE_CONNECTION.md)
connects eroad3 to the existing Old Pine North Approach using one production Session.
Source-entry has4 residents; default technical New Game remains2. Canonical17,500 assertions and
real Inn -> Clearing -> Inn route PASS, including NPC/Player/RNG continuity. NGE4 is owner-approved.
NGE5A pre-audit identified strength growth versus established body facts and correctly stopped.
[NGE5A0 body authority](../migration/PHASE_NEW_GAME_ENTRY_PLAYER_BODY_FACTS.md) implements the owner-approved
single Player body authority and stored-fact death/carry. Its historical v1 interpretation/guard
are removed by NGE5A1; independent body authority and schema2 exact continuation remain.
Focused260 / complete canonical17,553 assertions, headless editor and real desktop binding smoke PASS.
NGE5A0/NGE5A are approved. [Versioned continuation and NGE5A1 cleanup](../migration/PHASE_NEW_GAME_ENTRY_VERSIONED_SAVE_CONTINUE.md)
retain exact schema2 identity/body/world persistence and source four-map Save/Continue. Following
the new owner decision, old-save A is SUPERSEDED: root schema1 reading/writing, migration and
missing-field interpretation are removed. Schema2 SOURCE_ENTRY_V1 is the forward baseline;
LEGACY_OLDPINE_V1 only supports internal pre-cutover technical regression fixtures.
NGE5A1 focused326 / complete canonical17,747 assertions, Godot4.7.2 headless editor and real
source Save -> fresh-process Application Continue smoke PASS. NGE5A1 is owner-approved.
[NGE5B public cutover](../migration/PHASE_NEW_GAME_ENTRY_PUBLIC_CUTOVER.md) now routes the canonical
menu through minimal Chinese name + explicit gender setup to Snow Inn, using NGE1 source birth
and SOURCE_ENTRY/schema2 continuation. Public technical Old Pine/exp600/sword birth is retired;
explicit internal fixtures retain their historical coverage. Focused1636 / expanded UI6027 PASS;
real desktop New Game -> Square -> Save -> cold Continue -> Old Pine North Approach PASS.
Complete canonical18,192 PASS, zero failures/exit0; development/sanitized headless checks PASS.
Android packaged startup/keyboard/input/validation/Back/Cancel smoke PASS on OnePlus8T.
Chinese Android IME composition/full birth and iOS device qualification are not claimed.
NGE5B is implementation complete, not yet owner-reviewed or major-phase integrated.
No PR or merge exists for this milestone; no new remote CI/integration claim.
Do not start NGE6, further Snow content, shops/training, Lake, or Phase5B4 without owner review.

**Start-of-Game Source Rebaseline / S0 — COMPLETE / FULLY INTEGRATED ON MAIN** through
[PR #14](https://github.com/Toxicccxz/eastern-stories-godot/pull/14), merged at
`d9b9a7cde6553623cf06b76ff828fa4f8a13c0ab`.
Post-merge [workflow 34531552148](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34531552148)
passed Godot Verify, Windows Release Build, Android Release Build, and iOS Build Validation on that commit.
[S0 source rebaseline](../migration/PHASE_START_OF_GAME_SOURCE_REBASELINE.md) establishes Snow's inn
as the source fresh entry; its historical pre-review checkpoint remains unchanged. S0 was docs-only.

**Source-valid Beast Foundation + First Serpent Runtime Integration — COMPLETE / FULLY INTEGRATED ON MAIN**
through [PR #12](https://github.com/Toxicccxz/eastern-stories-godot/pull/12).
Final PR HEAD: `0ab0d68c44ba9844d477eed4c1ed0670707bf9a9`;
merge commit: `a7f0f6fa695a53335878570b80df354a97a48233`.
Post-merge [workflow 34515556524](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34515556524)
passed all four required jobs on that merge commit. Its branch was
`phase/beast-foundation-serpent-runtime`, based on green main `5cf3f4e`.
[BF1–BF4 source contract and evidence](../migration/PHASE_BEAST_FOUNDATION_SERPENT_ANALYSIS.md):
BF1–BF4 are owner-approved at `0ecf7f5`. [BF5 final audit](../migration/PHASE_BEAST_FOUNDATION_SERPENT_FINAL_AUDIT.md)
PASS: **implementation + formal local audit complete**, with no BF5 production/test corrections.
Complete canonical: **16,895 assertions**, zero failures; Python46; repository/static, development
and sanitized headless/startup PASS. Independent BF1/BF2/BF3/BF4:958/201/162/101 PASS.
Accepted source-fresh Run A (natural Player defeat) and deterministic QA-wounded Run B (real serpent
death/corpse/empty-loot/fresh movement) are reused because executable source is unchanged.
Run B is NOT natural-victory or balance acceptance. QA is excluded from production/sanitized output.
BF3 remains persistence composition capability, not normal-player serpent Save/Continue.
Normal bootstrap remains five human NPCs/twelve items; no production serpent or Lake.
Historical BF5 pre-PR checkpoint wording remains unchanged; integration is now complete as recorded above.
Subsequent Godot AI 4.0.4 main update and viewport CI stabilization are separate tooling changes:
[PR #13](https://github.com/Toxicccxz/eastern-stories-godot/pull/13) merged at `208597e`, with all four main
jobs PASS in [workflow 34525138568](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34525138568).
This resolved S0's CI blocker without changing its docs-only scope or reverting the plugin update.

Phase 10C1's shared application shell is **FULLY INTEGRATED** on `main` at
`3a1f993a4258ed246ce820c7a4dc8d2563994aaf` (PR #5). Phase 10C2 and its resident-map
contact stabilization are also fully integrated at
`ae381bf3f3e5f4a28a417295eea680d023cc428c` through PR #6 and PR #7; all four
post-merge jobs passed in
[workflow 33714114002](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/33714114002).
These build on the integrated Phase 10B native Save/Load and Phase 10A build/CI foundations.

Phase 10D is **COMPLETE / FULLY INTEGRATED ON MAIN** through
[PR #10](https://github.com/Toxicccxz/eastern-stories-godot/pull/10), merged at
`abad71a4630c11c889cc3d0132095af95163aaa1`. Post-merge main
[workflow 34280203676](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34280203676)
completed successfully: Godot Verify, Windows Release Build, Android Release Build and
iOS Build Validation all PASS on that exact merge commit. The release-validation branch
`phase/10d-post-redesign-release-validation` started from green main
`0a5f0b49b6797c2a1280ef4198c2060b3cc61e34`. The old
`phase/10d-technical-demo-release-gate` remains frozen historical evidence, not the new candidate.
Its Phase10D1 remains bounded historical physical Android PASS and Phase10D2 remains
historical exact-artifact packaging PASS, but old pre-redesign Phase10D3 was BLOCKED / NEVER PASSED:
normal-player acceptance exposed that the then-existing combat experience was not suitable enough to
continue release acceptance. That historical Phase 10D3 attempt never passed and remains frozen.
The owner approved the redesign, now integrated, before the fresh candidate/acceptance cycle.

Current Phase10D3: **POST-REDESIGN NORMAL-PLAYER ACCEPTANCE PASS**, as recorded in the
[acceptance closeout](../migration/PHASE_10D3_POST_REDESIGN_TECHNICAL_DEMO_ACCEPTANCE.md).
Immutable candidate source is `000d7b383f1d508aab56e9dcd90273d4a9dd5b85`.
Windows packaged critical journey and Android physical representative world traversal passed,
including natural Victory/loot and Save A -> unsaved B -> process death -> cold Continue A.
Post-redesign candidate refresh evidence is **SATISFIED**: clean Windows/Android
artifacts, hashes, manifests, sanitizer, signing facts and notices. Historical Phase10D2 remains
historical PASS. Cave/SouthExit is conditional/not advertised in the current fresh-player demo,
not an acceptance blocker. No repeated owner operation or rebuild was required for closeout.
No production gameplay changes were made; local owner project/plugin edits are excluded.

Combat Experience Redesign is **FULLY INTEGRATED ON MAIN** through PR #8, merge
`7372d9d2ca3d796236ad64c2c6ad817a2508cb91`; all four post-merge jobs passed in
[workflow 34186684857](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34186684857).
Independent tooling PR #9 subsequently integrated Godot AI 4.0.1 at `0a5f0b4`, with all four
jobs passing in [workflow 34187852614](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34187852614).
It does not change the gameplay milestone. Phase10D3 acceptance has passed in the new cycle.
The [Phase10D Final Audit](../migration/PHASE_10D_FINAL_AUDIT.md) passed on tracked source:
16,152 gameplay assertions, Python 46, repository/static, development/sanitized headless and
sanitizer validation. Candidate is frozen/accepted; production/test/build/CI delta is zero.
PR #10's four-job CI passed on `6817832f161edbe1005b2ce99819962ce61f0124` in
[workflow 34278725150](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34278725150),
followed by the merge and green post-merge main CI recorded above. The immutable tested candidate
source remains `000d7b383f1d508aab56e9dcd90273d4a9dd5b85`, not the merge commit.
Historical audit documents retain their truthful pre-PR checkpoint wording. This completes only
the **private/internal Technical Demo engineering gate**, not the game, public/store readiness,
legal clearance, permanent signing, iOS-device or broad Android qualification.

The completed [CXR0 analysis](../migration/PHASE_COMBAT_EXPERIENCE_REDESIGN_ANALYSIS.md)
established the source/current-system evidence. The
[CXR1 Active Semi-Auto V1 design](../migration/PHASE_COMBAT_ACTIVE_SEMI_AUTO_V1_DESIGN.md)
is now complete and locks automatic ordinary combat plus player-triggered tactical intervention,
with a dedicated encounter, frozen world, one-slot action queue, typed events, and replaceable
battle presentation. The typed, Node-free
[CXR2 CombatEncounter Core](../migration/PHASE_COMBAT_CXR2_ENCOUNTER_CORE.md) is complete: it adds
semantic triggers, exact authority bindings, open participant sides, directed hostility, explicit
targets, monotonic lifecycle/results, and typed structural events without integrating runtime
combat. The [CXR3 World/Encounter Lifecycle Foundation](../migration/PHASE_COMBAT_CXR3_WORLD_ENCOUNTER_LIFECYCLE.md)
is complete: the current Session owns one encounter coordinator and encounter-ID-owned world gate,
with exact live authority binding, transactional start/end, world/cadence/transition gating, and
fresh-input quarantine. The [CXR4 Active Semi-Auto Scheduler](../migration/PHASE_COMBAT_CXR4_ACTIVE_SEMI_AUTO_SCHEDULER.md)
is complete: the Session-owned encounter now advances deterministic ordinary opportunities through
the existing combat core while its resident world and legacy cadence remain frozen. Normal player
combat was not cut over by CXR4 itself. The
[CXR5 Tactical Actions + One-Slot Queue](../migration/PHASE_COMBAT_CXR5_PLAYER_TACTICAL_ACTIONS_QUEUE.md)
is complete: typed player requests, split validation, exact-authority execution at a deterministic
command boundary, busy-aware replacement/cancellation, and ordered events. Production action
registration was empty at CXR5; CXR9 adds the approved production Flee. The
[CXR6 Battle Presentation](../migration/PHASE_COMBAT_CXR6_BATTLE_PRESENTATION.md)
is implementation/desktop-runtime complete: Session-owned frozen-world overlay,
typed read projections and request/cancel adapter, honest empty Quick Actions,
ordered feedback/log, shared SafeArea/input/Pause, and restore-reparent support.
Affected physical mobile requalification was pending at CXR6; CXR10's bounded
physical result is recorded below. No telegraph producer,
Quick Slots, production tactical actions, target switching, or normal-combat cutover
was added in CXR6. The
[CXR7 Multi-Opponent Targeting + Modes](../migration/PHASE_COMBAT_CXR7_MULTI_OPPONENT_MODES.md)
is implementation/desktop-runtime complete: typed player target changes, stable invalid-target
fallback, separate accepted queue targets, collection-based controls and source-backed SPAR/LETHAL
establishment alongside SCRIPTED. CXR7 itself did not cut over normal Attack/aggression.
The [CXR8 Production Cutover / Resolution](../migration/PHASE_COMBAT_CXR8_RESOLUTION_CUTOVER.md)
is implementation/runtime complete with bounded physical Android evidence: normal Attack/aggression
now enter one Session-owned Encounter/Scheduler, complete opportunities feed existing lifecycle and
death/corpse authority, ordinary Loot and post-combat Save/Continue work, and the old canonical Timer
does not resume. Partial failure holds the frozen encounter; armed-friendly mortal SPAR remains an
explicit blocker, not silently clamped. Production tactics remain empty. Post-review completion
hardening preserves visible RESOLVING ownership on thaw/gate-release failure, without retrying
lifecycle or allowing FLED bypass. Latest full canonical validation: 15,760 assertions PASS;
desktop actual Attack -> natural Victory -> movement smoke PASS. Broader earlier multi-target/queued-action physical combinations remain
unqualified by this bounded pass. These are historical CXR8 limits; integration is recorded above.

[CXR9 Old Pine Playability](../migration/PHASE_COMBAT_CXR9_PLAYABILITY_BALANCE.md)
is **implementation COMPLETE**. Old Pine-only
New Game experience 600 and read-only result feedback remain. Production Flee uses
the existing busy-aware one-slot queue, typed command result and same-position
world return with included relationship cleanup, no RNG/cost/reward/teleport.
Real fresh Attack/aggression -> Flee -> movement/Save and physical Area exit/reentry
passed without QA stats/position/RNG. SPAR is explicitly unarmed-only, with the
owner-authorized zero-base unarmed random-term exception; mortal-state defense stays.
Telegraph is dormant/conditionally satisfied with no current producer, not fake content.
Final CXR9 368 and full canonical 16,132 assertions PASS; Godot 4.7.2 editor and
repository checks PASS. Owner config Python remains 45/46; tracked clean overlay 46/46,
all 120 original owner dirty files preserved. These were CXR9's results; its pending
Android gate was subsequently exercised by CXR10 below.

[CXR10 final audit](../migration/PHASE_COMBAT_CXR10_FINAL_AUDIT.md) is
**COMPLETE; MILESTONE FULLY INTEGRATED ON MAIN**. The whole milestone
and authority boundaries were reviewed; 20 focused runners passed 22,285 overlapping
assertions and the complete canonical suite passed 16,132, with 0 failures. Fresh
desktop New Game/aggression/Flee/rearm, natural Victory/loot and Save/Menu/Continue
passed. The exact `cc42b89` Android APK passed bounded physical OnePlus 8T / Android 14
touch entry/target/Flee, Back/log/Pause, Home/explicit Resume, landscape and natural
Victory/loot paths using native Vulkan/Forward Mobile. Broader multi-finger,
multi-opponent device combinations, tablets and iOS remain unqualified. Python is
46/46 on exact tracked source, 45/46 on the preserved owner configuration. Windows/
Android local builds, sanitizer and static checks passed. CXR10 changes only audit/
status documentation at the initial audit checkpoint. Subsequent PR review corrected disconnected
encounter topology and final-hit feedback; corrected canonical validation passed **16,152**
assertions, with desktop/Android terminal-feedback revalidation. PR #8 and post-merge four-job
CI then passed as recorded above. The historical audit evidence is not a new packaged-demo PASS.

Phase 10D1 remains conditional historical evidence for platform interaction only; it does not
qualify the future battle presentation. Repeat only affected device evidence if the redesign
materially changes mobile battle input, lifecycle, renderer, or SafeArea/layout. Phase 10D2
artifacts and hashes remain evidence for their exact source commit, not release candidates after
combat changes. This is not game completion or store readiness.

Completed local shell capabilities are Main Menu, explicit New Game/Continue, Pause/Resume and Save,
explicit backup/temp recovery, confirmed Return to Menu, and independent Settings with desktop
Windowed/Fullscreen. Shared keyboard/mouse/controller semantic navigation has desktop runtime proof;
this does not claim physical controller or mobile-device qualification. See the
[Application Shell contract](contracts/APPLICATION_SHELL_CONTRACT.md) and
[final integration audit](../migration/PHASE_10C1_FINAL_AUDIT.md).

The mobile shell provides shared responsive Shell/HUD/Inventory/Loot, SafeArea, sensor landscape,
eight-direction touch pad, Android Back, lifecycle freeze and explicit Resume. Save remains
manual-only: background triggers no Save. The [Mobile Application contract](contracts/MOBILE_APPLICATION_CONTRACT.md)
defines these extensions without replacing Shell/Host or native persistence authority.
Installed Android emulator evidence covers touch/Back, lifecycle, restart durability, Cave
roundtrip, simultaneous contacts and reverse landscape. Phase 10D1 separately provides bounded
physical ARM64/Vulkan/touch/multitouch evidence on the named Android devices; it is not broad
Android/tablet/store certification. iPhone/iPad simulator/device runtime remains unqualified.

Formally closed gameplay foundations include:

- typed character attributes/resources, recovery, conditions, and lifecycle thresholds;
- Skill Core, cultivation, Practice, Selflearn, Learn, and authored progression effects/policies;
- item identity, containment, stacks/currency, inventory transfer, equipment, and armor;
- native item save DTO/validation foundation, item destruction, death/corpse, loot, and legacy
  autoload import boundary;
- ordinary combat math, attack resolution, force policy, progression/busy completion,
  relationships, reciprocal attack composition, and the first playable combat slice;
- NPC/world/spawn typed foundations and authored Old Pine bandits/loadouts;
- one resident Old Pine Session with Outdoor/Cave map lifetime;
- Vine traversal, Passage Cave/SouthExit roundtrip, Waterfall, River, Cliff, and source-faithful
  one-way Pine route;
- typed native Save snapshots/JSON/repository, exact item and RNG continuation, fresh world/NPC/corpse
  reconstruction, restart-stable Save eligibility, transactional Session replacement, and fresh-process
  Outdoor/Cave restore proof.

The current canonical main scene is
`res://scenes/application/application_shell.tscn`. It owns one persistent Runtime Host, which alone
owns zero or one replaceable Old Pine Session. Cold start shows Menu, not hidden gameplay.

## Runtime contact invariant

Outdoor zone notifications must match the current character/zone collision shapes before
changing typed location. A reattached resident body can briefly have a previous transform
in PhysicsServer; its resulting Area notification and `overlaps_body()` cache are not
current-position authority. Revalidate actual shape contact, including body-edge overlap,
without delaying traversal, moving the player again, or changing Shell/Host ownership.

The reported mobile lifecycle stack was the full runner's final error aggregation, not
the assertion site: the earlier Vine test failed even with zero input and no Shell.
Logical-only test fixtures use existing typed location setters, not fabricated Area entry.
Mobile held-action clearing, echo quarantine, pause and manual-save behavior are unchanged.

## Incomplete work

- Combat Phase 5B4 and later full combat parity;
- Cave expansion, Keep, Lake/serpent, and the remaining ES2 world/content;
- broader physical Android/tablet qualification and iOS simulator/device qualification;
  portrait/split-screen gameplay is not qualified;
- final UI, art, animation, VFX, audio, balance, accessibility, and localization;
- permanent Android/iOS signing, store metadata, installer/package policy, Steam/Play/App Store/
  TestFlight upload, and final release gates.

The Phase 10A pipeline sends the same sanitized game project to Windows, Android, and iOS targets.
Windows and Android Release exports are locally proven. GitHub Actions workflow run `33350605585`
also proved `Godot Verify`, Windows Release, Android Release, and the unsigned iOS Xcode compile on
the same commit, with all three platform artifact uploads succeeding. The current mobile phase's
emulator evidence is separate from those historical build results; neither establishes broad
phone/tablet hardware usability or store readiness.

## Release and licensing boundary

Phase 10A Windows output is unsigned. Android uses a per-build ephemeral QA key and is not a Play
Store release. iOS is an unsigned Xcode compile validation and is not an IPA, App Store, or TestFlight
build. The provisional mobile identifier is `com.example.easternstoriesgodot`; it is not a domain-
ownership claim and must be replaced before store signing.

The repository has no root project license. See `LICENSE_PROVENANCE.md` for the unresolved ES2
evidence and verified third-party records.
