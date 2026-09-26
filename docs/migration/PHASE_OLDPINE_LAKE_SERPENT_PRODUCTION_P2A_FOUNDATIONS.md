# Old Pine Lake + Production Serpents — P2A foundations

## Disposition and identities

**P2A — IMPLEMENTED / LOCALLY VERIFIED / AWAIT OWNER REVIEW.** This is the bounded P2A slice, not a Final Audit.
Owner authorized implementation, local validation, self-review, commits and normal push on the
existing `phase/oldpine-lake-serpent-production` branch. No PR, merge or remote workflow dispatch.

- Starting local and freshly fetched remote HEAD: `49d0d406048f76c7ea1181d0a829cde5bde7b6fb`; clean index/worktree.
- P1: `688647ab15b7d0a3c1c4a1b79f4a2a935e521012`.
- Phase base/main: `01f7b18253a1936bce4a1fb11a507a356769c409`.
- Main's [workflow 36212949685](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/36212949685)
  is historical baseline evidence, not this P2A commit's CI. Fresh phase PR search returned none.
- The final implementation commit is the commit introducing this report; its exact SHA is reported
  in the delivery response rather than a self-referential hash embedded inside the commit.

## Locked boundary and source authority

[DECISIONS](DECISIONS.md#old-pine-lake--owner-locked-p2a-foundations) records the owner-approved
M complete-set pre-freeze admission and W bounded shore Fill. R follows the
[long-term development policy](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy):
CURRENT WORLD ONLY. W is a contract here; its placement/UI is P2B. P1's old dual-world R proposal
remains historical and is superseded by its owner amendment.

Sources consulted for these boundaries:

- [lake.c](../../reference/es2/mudlib/d/oldpine/lake.c): five ordinary serpents, north route, water resource.
- [serpent.c](../../reference/es2/mudlib/d/oldpine/npc/serpent.c): aggressive Beast, unchanged body/combat data.
- [attack.c](../../reference/es2/mudlib/feature/attack.c): `MAX_OPPONENT` random selection is not encounter capacity.
- [combatd.c](../../reference/es2/mudlib/adm/daemons/combatd.c): aggression rechecks existence, living,
  shared location and no-fight before establishing hostility.

Existing native factory, Beast content, lifecycle, selection, Flee and resource formulas remain
unchanged. No source file, plugin, dependency, CI gate, migration tool or Lake scene was changed.

## Persistence implementation and call path

`WorldContentRevision.CURRENT_PUBLIC = SOURCE_ENTRY_V1`. Root schema **2**, embedded item schema **3**
remain unchanged. `SOURCE_ENTRY_LAKE_V1` is a reserved string only: no published enum, New Game writer,
spawn catalog or restore branch accepts it. Current New Game/Save/Continue still means five humans.

Public Host → SourceEntrySaveRepository → GameSaveJsonCodec(public-only) checks the content contract
before decoding nested entity payloads. Both public reads and writes then reuse
OldPineWorldRestoreComposition.prepare: the same current authored catalog, stable point/group/definition/
Character identities, body, item/loadout, lifecycle, corpse, allocator and RNG validation used by capture
and staged restore. There is no caller-supplied catalog and no migration or slot filling.
Preparation creates isolated domain values only; it does not publish Nodes, call fresh NPC initialization,
write files or draw gameplay RNG. Existing staged candidate validation still owns physical placement and
Session swap/rollback. Public inspection now performs this bounded content validation too.

| Input | Typed result / behavior |
|---|---|
| Recognized non-public LEGACY_OLDPINE_V1, or reserved Lake marker | INCOMPATIBLE_DEVELOPMENT_CONTRACT before nested entity composition |
| Unknown content marker | UNKNOWN_WORLD_REVISION |
| Current contract with missing/extra/wrong ledger or invalid body/lifecycle | Existing corruption/validation outcomes; never labelled an old version |
| Unsupported root/item schema | Existing UNSUPPORTED_GAME_SCHEMA / UNSUPPORTED_ITEM_SCHEMA |
| Read/write/atomic replacement failure | Existing separate I/O/transaction outcomes |

ApplicationProductResultMapper and ApplicationMessageCatalog map incompatible development content to
**“此存档来自不兼容的开发版本，请开始新游戏。”** Ordinary corruption and unknown versions keep distinct
keys/outcomes. Canonical incompatibility is not masked by BACKUP_AVAILABLE. A separately validated
current backup remains visible as an explicit recovery choice in the Shell result; it is never loaded automatically. Explicit backup/temp reads
use the same public support and current-content validation; no automatic fallback, promotion or file
modification. Technical fixtures retain explicit use of the base repository; this is not a second public world.

### Actual future cutover

P2B must publish the marker together with Lake geometry, its five authored spawn points, deterministic
fresh order, body binding, strict ten-slot ledger and physical placement validation. The present
OldPineSpawnDefinitions.all_spawns / restore-composition authority remains the production catalog;
P2A adds no permissive arbitrary catalog parameter. Existing source-birth/supply checks using
SOURCE_ENTRY_V1 express capabilities and must be deliberately reviewed at that atomic cutover.
P2A neither proves ten-slot Lake restore nor promises to keep the five-slot world afterward.

## Complete-set production seam

Future Lake dispatch calls CombatEncounterCoordinator.start_complete_production(cause, requested_target).
The coordinator asks its active Outdoor map to collect; callers cannot submit `eligible=true` or an
arbitrary participant array. Existing automatic and manual ordinary pair dispatch still calls
start_production and is unchanged. No current player route publishes the new Lake group entry.

Outdoor collection synchronously reads all owned current NPCs, exact body/runtime/map membership,
existence, availability, ACTIVE state, combat-location and authored aggression policy. Actual contact
uses current CollisionShape2D transforms, not cached overlap lists, deferred Area order or a wait window.
Manual requested targets retain existing availability/location constraints without a new distance rule;
other genuinely aggressive contacts are included. Zero eligible automatic contacts produces no encounter.
Missing/counterfeit authority refuses the whole set rather than silently dropping the problematic binding.

Player is first; enemies sort by explicit **String(CharacterId) lexical comparison**, not StringName's
allocation-sensitive default ordering. That order determines participants, default target and scheduler
opportunities. Manual target selection remains explicit. Duplicate collection does not duplicate entities.

Before mutation, the coordinator verifies every Character/relationship/busy/armor binding, current
locations, independent authorities, no self/third-party/enemy-enemy relationships and the open world gate.
It snapshots every opponent and lethal list, establishes only Player↔enemy relationships, then calls the
existing typed start() exactly once. On any intermediate relationship/start/freeze failure all changed
lists are restored, including their order. No success receipt, active encounter, scheduler or owned freeze
survives a refused start. Existing unrelated relationships and foreign freeze ownership are not erased.
No collection/establishment RNG is consumed.

The resulting encounter uses the existing scheduler, executor/resolver, target requests, tactical queue,
resolution and WorldSimulationGate. Fifth-target execution is tested, not inferred from array capacity.
Flee reconciles every included relationship and returns before any ordinary opportunity. The new seam
records consumed contacts after successful entry; thaw/Pause alone does not rearm them. Current separated
shapes or a validated exit clear that record. Full five-snake Area wiring/reentry remains P2B/P2C evidence.

## Automated validation

New `oldpine_p2a_foundations_test.gd` is registered in the canonical runner and the existing-style
`run_oldpine_p2a_tests.gd` focused runner. All synthetic NPC placement, resource/lifecycle preconditions,
CountingRandom and fault injection live under tests only; the sanitizer excludes them.

- Foundations: **235 assertions, 0 failures** on the final executable code.
- Full focused gate: **3,234 assertions, 0 failures**.
- Affected S4B food/cold-process regression: **488 assertions, 0 failures**.
- Python: **656 tests PASS** in the canonical verification command.
- Canonical gameplay: **21,294 assertions, 0 failures**.
- Repository/static checks, development headless editor, actual release sanitizer and sanitized-project
  headless editor: **PASS**, canonical command exit **0**, no skipped stage.
- Final commands: `python tools/ci/verify.py --godot <official-4.7.2-console>` and
  `Godot --headless --path game --script res://tests/run_oldpine_p2a_tests.gd`; affected cold-process
  regression uses `res://tests/run_snow_dumpling_tests.gd`. All use the existing pinned toolchain.
- Documentation: **7 changed Markdown files / 391 relative links / 45 anchors PASS**. Protected-path
  zero-diff and `git diff --check` PASS; final staged scope reviewed before commit.

New coverage includes public roundtrip and unmodified current marker/five-slot catalog; recognized/unknown
content across canonical/backup/temp with unchanged bytes; missing/extra/duplicate/wrong-definition/body/
lifecycle rejection; current dead slot plus separate corpse; fresh-graph restoration and exact stored RNG;
0/1/4/5 aggressive contacts; stable ordering under container reversal; manual inclusion; fifth target and
six actual opportunities; busy; all-party Flee and no later attack/RNG; absent/unavailable/dead/different-
location/non-contact exclusions; fourth-relationship partial failure with ordered rollback; third-party
conflicts; fake fifth body; foreign freeze owner; late freeze refusal; fifth death/stale-target refusal and
retargeting; remaining hostility; five independent corpses and final completion.

Focused regressions include current versioned Save, strict world restore, Beast human-save exclusion and
source-derived combat integration, Liuh progression/acceptance, ordinary Outdoor, tactical/Flee and staged
Save/Load transactions. Canonical coverage retains the existing corpse-removal/tombstone, allocator, all
three RNG, atomic failure and old-Session preservation tests. Fresh graph is not a cold-process claim.

## Actual runtime smoke and evidence limits

Official Godot **4.7.2**; retained Godot AI **4.2.3**. First launched canonical ApplicationShell:
main menu, current save inspection, `helper_live=true`, `session_active=true`, non-stale framebuffer
(frame 3871). No Save/Load/Continue or owner-file write was performed in this smoke.

For the directly affected Outdoor pair/freeze/Flee seam, launched the real production
`res://scenes/world/oldpine/oldpine_world_session.tscn`. This is the existing technical-bootstrap scene,
not a public source-born Player or a fake test map. No QA entity/stat injection was used in live play.
Real action input moved from (450,300) toward Bandit03 and physical aggression opened exactly two cards.
Real framebuffer click at (111,515) pressed/released **Flee / Disengage**. Retained visible feedback was
Queued: Accepted → Execution Started: Accepted → Resolved: Disengaged → Escaped.

Successful clean run `r302020-3`: read-only authoritative observation returned
`[active_encounter=false, completion_success=true, terminal_kind=3/FLED, world_gate_open=true,
Player_life=0/ACTIVE, opponents=[]]`. Real upward input then moved to approximately
(574.66687,538.33289), with no encounter and the original five NPCs. Framebuffers 4276 and 9026 were
both `stale_frame=false`; helper/session/capture remained live and the clean run had no gameplay errors.
Movement and click were real input; game_eval merely read the resulting state and consumed no RNG.

Operational disclosures: initial editor launch used mismatched 6007/6107 debugger endpoints; a CLI
`--debug-server` matching the project's existing argument resolved this without a tracked settings change.
An earlier smoke reached Escaped but an observer typo (`result` instead of `terminal_result`) caused a
QA-only debugger break. That run was stopped, its stale post-break image was not accepted, and the whole
short route was repeated cleanly. Initial development tests also exposed a bad test accessor (removed)
and StringName ordering (fixed to explicit text order); final results exclude those failed attempts.
The editor removed two explicit viewport defaults when saving; they were restored to exact baseline.

The first complete verification run did not pass: two S4B cold-process assertions selected partial/full
food instances using allocation-sensitive StringName ordering, despite complete snapshot equality;
a new explicit-backup UI assertion also ran with the earlier mapper cached during that long run.
The cold-process test now selects the same stable textual instance IDs in writer and reader, preserving
every identity/value assertion and production food behavior. The mapper retains validated explicit
recovery sources on the unsupported-version path. Focused checks and the final complete run use these fixes.

This is representative current pair smoke, not Lake five-target UX, Lake water/geometry, public Lake
Save/Continue, full process restart, natural progression, balance or a novice-five-serpent victory claim.

## Bounded self-review and remaining gates

Reviewed final production diff against the owning boundaries: one combat authority; World-owned collection;
all-list rollback; no startup RNG; no caller catalog; strict public support before publication; no premature
revision/scene changes; current pair and public source contract preserved. Tests and production are separate.
The reserved marker deliberately refuses even structurally plausible five-human JSON.

Remaining work is the authorized slice boundary, not a claim that Lake is complete: P2B dispatch/physical
contact wiring, complete Lake geometry/catalog/Fill and atomic marker publication; P2C actual five-target
interaction, physical reentry and cold-process Continue. No dynamic joining, second scheduler, migration UI,
poison, balance changes, Cave/Keep, other roadmap work or Migration Tooling P3 is included.

Production changes are confined to the existing coordinator/Outdoor, save codec/result/revision/repositories,
and Shell result mapping/message catalog. Tests add one suite/runner plus registrations and typed-result
mapping expectations, plus the affected cold-process test identity ordering correction. Documentation changes are this report, DECISIONS, minimal current STATUS/ROADMAP/
PROJECT_SCOPE/Save-contract updates and an appended historical P1 link.

LAKE PRODUCTION PUBLICATION — NOT STARTED.
P2B / P2C / FINAL AUDIT / PR / MERGE — NOT AUTHORIZED.
