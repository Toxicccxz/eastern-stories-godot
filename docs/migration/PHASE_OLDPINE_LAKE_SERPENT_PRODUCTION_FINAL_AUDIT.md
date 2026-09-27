# Old Pine Lake + Production Serpents — Final Audit

Date: 2026-09-26. Branch: `phase/oldpine-lake-serpent-production`.

## Verdict and owner scope

**FINAL AUDIT — PASS / READY FOR OWNER PR AUTHORIZATION.**
Material correctness, safety-boundary or scope blockers found: **0**.
**LAKE ENGINEERING ACCEPTANCE — COMPLETE UNDER OWNER-REVISED SCOPE.**

The owner accepted the existing P2C desktop, two cross-process restores, representative
combat death/corpse and complete local verification evidence. The
[new acceptance decision](DECISIONS.md#old-pine-lake--owner-revised-engineering-acceptance-scope)
classifies **TOUCH DEVICE QUALIFICATION — PENDING / DEFERRED — NON-BLOCKING FOR LAKE
ENGINEERING INTEGRATION**. This is not touch PASS, all-platform certification, a blanket
future exemption or permission to hide an actual input defect. No such defect was identified
in this bounded review; device behavior itself remains unverified.

The [existing PLATFORM-001 row](../production/PROJECT_SCOPE.md#presentation-platforms-tooling-and-release-boundaries)
retains Lake touch movement, horizontal scrolling, fifth-target selection, Flee and applicable
safe-area/focus/Pause/Back/background/resume. Then-target devices must be qualified before
verified Lake touch claims or external long-term testing/formal release of related mobile
versions. Later device checks need not reopen the entire Lake milestone or create a new
test platform/prerequisite phase. No further device search, emulator or plugin work occurred.

## Frozen identities and full increment

| Identity | SHA |
|---|---|
| Integrated main / merge base | `01f7b18253a1936bce4a1fb11a507a356769c409` |
| Audited pre-document HEAD / origin phase | `6db58093318c168b8aff2e5df076dcec3997a69d` |
| Executable and tests with complete local PASS | `ef8b7d601983c80d817bf28a93e554f2472a49a6` |

Fresh fetch matched these identities; starting worktree/index were clean. The initial fetch
was denied writing `.git/FETCH_HEAD` by the sandbox; the authorized elevated fetch succeeded.
The five milestone commits are P1 `688647a`, owner roadmap/save policy `49d0d40`, P2A
`1fcb179`, P2B `ef8b7d6`, P2C documentation `6db5809`. The entire baseline-to-audited-HEAD
increment is **68 paths, 2900 insertions / 134 deletions**, grouped below, not merely P2C docs.

| Group | Reviewed change and boundary |
|---|---|
| 19 production files: 3 core persistence, 2 application, 9 runtime, 3 data, 1 UI, 1 scene | Public contract rejection/current marker; complete-set admission; Lake geometry, five slots, Fill and source-entry consumers |
| 39 test/runner/UID files | Two added canonical suites, focused runner, catalog/marker/count expectations, cold-process stable test identity, affected restore/BF4 regression corrections |
| 9 documents + root AGENTS | P1–P2C evidence, M/W/R, owner project roadmap/scope and development Save policy, scoped validation discipline |

No milestone delta under `reference/`, `tools/` (including Migration Tooling), `.github/`
or `game/addons/`. No plugin/dependency upgrade, generated Save, runtime evidence artifact,
production test fixture or CI gate change is in the increment. Synthetic bodies, failure
injection and deterministic draws remain under `game/tests/`; production imports do not
refer to those helpers. Existing technical bootstrap remains an explicit regression surface,
not a preserved five-human public product world.

Post-P2B changes through the audited HEAD are the known four P2C documentation files only.
`git diff --quiet ef8b7d6 HEAD -- game tools .github reference` and the worktree comparison
passed. Exact Git tree identities at both commits:

| Tree | Object ID |
|---|---|
| game (includes tests and retained plugin) | `f829e7e1205af483d4b52079c5d155b08905aedb` |
| tools | `b849a375ff7b8eb628187ad527a37131768e93a6` |
| .github | `91ad324e4701c779e3a9548fbac2f970314df6d3` |
| reference | `88970f0589db4e0956a00a4824dc9d1dcafa5620` |

## Reviewed architectural and functional boundaries

Read applicable root/docs AGENTS, [P1 and owner amendment](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md#owner-policy-amendment--2026-09-26),
[P2A](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2A_FOUNDATIONS.md),
[P2B](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2B_RUNTIME.md),
[P2C](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2C_ACCEPTANCE.md), M/W/R and the
[current Save contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md).
Rechecked authoritative [lake.c](../../reference/es2/mudlib/d/oldpine/lake.c),
[serpent.c](../../reference/es2/mudlib/d/oldpine/npc/serpent.c) and
[riverbank1.c](../../reference/es2/mudlib/d/oldpine/riverbank1.c) against the changed composition;
reused P1's inherited Beast/combat/liquid analysis rather than re-auditing unrelated ES2/Core.

### Production population, physical contact and combat

- `OldPineSpawnDefinitions.lake_serpent_spawn` declares exactly five INITIAL_ONLY stable
  points `.1`–`.5`. Outdoor appends their existing Beast factory initialization after the
  five humans, binds each to its authored marker/body and restores ten saved entries without
  rerunning the factory. The serpent definition/formulas/loadout remain unchanged.
- `oldpine_outdoor.tscn` opens the north Riverbank connection in the same Outdoor scene,
  extends the camera, and adds solid water/perimeter plus shore Fill. Runtime zone ownership
  and placement validation share the half-open River/Lake seam; no new portal or room engine.
- `collect_complete_combat_entry` reads current owned bodies, exact collision-shape contact,
  existence, aggression policy and authoritative availability/location. It orders IDs by
  explicit lexical text. Same-zone membership alone does not include distant snakes; manual
  Attack retains its requested-target policy and includes the other eligible contacts.
- `start_complete_production` revalidates independent bindings, identities, locations and
  relationship topology before mutation. It snapshots every opponent/lethal list, establishes
  only Player/enemy relations and calls the existing start/scheduler. Relationship or late
  freeze failure restores all lists; foreign gate ownership is not released. Successful entry
  alone consumes contacts. Separation rearms; Pause/thaw alone does not. The added test
  coverage includes fourth-relation failure, late freeze refusal, counterfeit fifth binding,
  order permutation, fifth target/death and remaining-hostility completion.
- Automatic/manual dispatch switches to that entry only in Lake; the non-Lake pair path
  remains. Existing target UI, tactical Flee queue, scheduler/resolver, lifecycle and corpse
  authorities are reused. No mid-encounter joining, dynamic reinforcements, extra scheduler,
  balance/RNG intervention or claim that all group-combat designs are finished.
- `fill_water_available` adds bounded Lake shore permission to the existing Waterfall/UI/service
  path. Held item, lifecycle/busy/combat, distance and placement remain authoritative. No poison,
  swimming, general water engine, invented loot or new martial art.

### Current Save, restore and failure protection

- `CURRENT_PUBLIC` and New Game publish `SOURCE_ENTRY_LAKE_V1`; root2/item3 stay unchanged.
  Item projections, Snow supplies/maps/recovery, food/liquid UI and Vine consumers follow
  the same current marker. Recognized old strings are metadata/rejection cases, not alternate
  closed-Lake catalogs or migration support.
- Public repository reads invoke the codec's current-public gate before nested entity decode.
  Recognized old content, unknown marker, unsupported schema, current corruption and I/O have
  distinct typed outcomes. Canonical contract refusal is not masked by a valid backup; the
  owner may explicitly choose a separately valid current backup. Both backup/temp route
  through the same public `_read_snapshot` validation; no automatic fallback/promotion.
- `SourceEntrySaveRepository._validated_current` reuses restore preparation for reads and
  writes. `_restore_npc_ledger` rejects missing, extra, duplicate, wrong point/group/definition/
  Character identities and invalid body/location/lifecycle/loadout. Exact equipment/armor
  aggregates and corpse-victim/item/world references are preserved. Physical placement still
  validates the staged actual maps and rejects pool/perimeter positions, rather than relocating.
- Preparation restores durable objects and all three RNG states, without fresh NPC draws.
  The existing allocator/item authority, atomic temporary-file verification/replacement and
  staged candidate publication/rollback remain. Dropping obsolete public-save compatibility
  has not removed current corruption, identity, transaction or tombstone-without-corpse checks.
  No silent default repair or respawn path was added.

## Reused execution evidence and authenticity

This audit **did not launch gameplay, rerun verify.py/run_tests.gd, repeat the 16 regressions,
or replay mouse/Fill/combat/cold restores**. Execution evidence below is from P2B/P2C on the
unchanged executable, accepted by the owner; the fresh work here was code/document review and
reading/comparing retained files. No normal Save was copied, changed or deleted.

| Evidence | Scope and qualification |
|---|---|
| P2B runtime | Real physical Lake route/return, contact counts 1–5, fifth-target Tab/Enter, Flee/reentry and Fill; keyboard was not mouse/touch proof |
| P2C desktop | Native mouse scroll/click changed authoritative target to serpent5 with UI feedback; real body selection/Attack admitted six participants; normal Flee |
| P2C checkpoint A | Actual Pause Save, old game PID58720 exited, new PID37304 public Continue, new Session/Character; all five snakes alive |
| P2C checkpoint B | Old game PID37304 exited, new PID55500 public Continue; actual snake1 combat death, retained corpse, four survivors; physical leave/return did not revive it |
| Full local verification | `python tools/ci/verify.py --godot build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe`, exit0, **543.8597017s**, exact `ef8b7d601983c80d817bf28a93e554f2472a49a6` |

The retained `build/p2c-verify-result.json` and full log are accessible and agree with P2C:
all five Python/static/development-editor/canonical-gameplay/sanitized-project stages passed.
No skip flags, missing stage, failed assertion or script error was found. P2B's earlier 18
assertion failures plus script error are not called a pass: corresponding committed changes
update catalog/zone/marker/camera expectations, select the human loadout adversary by identity,
and adjust the BF4 test courage expectation to the added initialization draws. Canonical
registration remains, and the subsequent complete P2C run covers those corrections.

Existing local A/B save and pre/post runtime projections were reread, not regenerated:

| Checkpoint | Saved bytes / SHA-256 | Existing saved vs pre-exit vs restored runtime |
|---|---|---|
| A | 37586 / `1bc189ba5dfff085ca04d6e4e8ae84231747094f3889ad89c53eafbce44669e7` | Complete parsed documents equal; pre/post runtime bytes equal; ten NPC records, zero corpses |
| B | 38816 / `276bdf43880db7b0d7cd8aba90d9c97f93d25f0a8f66e19be0b8ff992ab77988` | Complete parsed documents equal; pre/post runtime bytes equal; ten NPC records, one corpse |

These are P2C's already captured pure running-state projections, including original metadata,
all body/resources, stable IDs, equipment/container/item/world graphs, allocator, location and
Combat/NPC/World RNG. No important field was filtered. Re-reading them independently checks the
recorded equality; it is **not a new process-restart execution**. The prior P2C process/input
observations and owner acceptance establish actual termination/public Continue, not JSON alone.

QA remains disclosed: inherited P2B vitality100000/supplies; before the independent death path,
Player EXP250000/raw unarmed100 and production snake1 positive kee1/1 (maximum1800), no RNG
seed choice or redraw. Combat then produced the death through normal input. This is not natural
growth or a novice/full-strength five-snake victory. Automated negative-health lifecycle setup
is separately labelled unit/integration evidence and is not substituted for that live kill.
P2C health/framebuffer evidence is reused, not claimed freshly observed in this audit.

## Current documentation and checks performed here

Only this new audit plus DECISIONS, STATUS, ROADMAP and PROJECT_SCOPE change. The original
P1/P2A/P2B/P2C reports remain byte-identical to audited HEAD; their then-pending wording is
historical, not rewritten as PASS. The older Save-contract implementation snapshot's reference
to P2C is resolved by the linked later evidence/current status, without reopening its policy.
No roadmap restructuring or automatic authorization of internal-power/other future work.

New checks (all PASS):

- `python -X utf8 tools/ci/repository_checks.py --repository .`: exit0, 1.79s.
- Existing ignored Markdown checker, with its explicit report target changed in memory to this
  audit: five changed documents, 335 relative link/anchor occurrences, no errors. No tracked
  tool was added or modified.
- `git diff --check`, exact five-document scope and clean starting index.
- P1/P2A/P2B/P2C unchanged against `6db5809`; executable/tests/protected paths unchanged
  against `ef8b7d6`. Merge base still equals the integrated baseline above.
- Fresh all-state phase-branch PR search returned none. No remote workflow was requested.

## Integration and stop

No repair was required. No new production/test/tool/plugin/source/CI changes. No new live
evidence or complete-suite run was invented. The only deferred acceptance evidence is the
bounded actual touch-device qualification recorded above; unrelated historical systems were
not reopened. Final Audit PASS is not a claim of merge or all-platform release readiness.

**LAKE ENGINEERING ACCEPTANCE — COMPLETE UNDER OWNER-REVISED SCOPE**

**FINAL AUDIT — PASS / READY FOR OWNER PR AUTHORIZATION**

**TOUCH DEVICE QUALIFICATION — PENDING / DEFERRED**

**PR / MERGE / NEXT MILESTONE — NOT AUTHORIZED**

The phase remains unmerged. Its future exact-head PR and exact-merge main four-job gates are
still required; no Lake remote CI result is claimed. Stop for owner review; no PR creation,
merge, next milestone, Phase5B4 or Migration Tooling P3.
