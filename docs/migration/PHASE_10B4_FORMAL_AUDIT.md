# Phase 10B4 Formal Audit — Save/Load Transaction and Process Restart

## Result

The audit found and corrected four transaction/lifecycle defects plus one restored-map activation defect.
After those corrections, the production path preserves the complete currently playable Old Pine durable
authority across an operating-system process boundary. A blocked Save is non-mutating; a failed Load
retains the exact current Session A; and a successful Load exposes one fresh, playable Session B only after
candidate reconstruction, validation, activation, and host attachment succeed.

The authoritative implementation baseline audited was `054bdaa` on
`phase/10b-native-save-load`. Phase 10C UI and all other deferred save features remain out of scope.

## Capture and durability boundary

`OldPineWorldSaveCapture` was checked field-by-field against the Phase 10B durability matrix. It captures:

- Player `CharacterState`, runtime life/existence facts, exact `WorldLocationState`, and map-local position;
- all five authored NPC spawn-ledger records;
- durable corpse records and the existing `NativeItemStateSnapshot` v1;
- item allocator scope and next dynamic sequence;
- Combat, NPC-initialization, and WorldInteraction RNG seed/state.

It does not serialize `WorldItemInstanceIndex`, active-map Nodes, ObjectIDs, Areas, Timers, UI/selection,
combat relationships, busy/interruption, aggression, or cadence. The item index is freshly derived by the
closed Phase 10B2 composition. Active-map authority is derived from Player location. Temporary attribute
modifiers have no durable provenance in schema v1 and therefore block capture rather than being lost.

Relevant production paths:

- `game/runtime/persistence/oldpine_world_save_capture.gd`
- `game/core/persistence/game_save_value_types.gd`
- `game/core/persistence/game_save_snapshot_validator.gd`
- `game/runtime/persistence/oldpine_world_restore_composer.gd`

## Eligibility and scheduling

The audited matrix allows stable idle ACTIVE, fully committed UNCONSCIOUS, coherent DEAD with
`exists=false`, Outdoor, Cave, non-authoritative inventory/loot UI state, and schema-v1 pending combined
stack destruction. It blocks opponents, lethal markers, busy, residual interrupt threshold, guarding,
pending aggression, running cadence, active or committed-partial handoff, pending Cave exit, incomplete
lifecycle, life/existence contradiction, unrepresented modifiers, and staged/suspended/disabled Sessions.

Audit correction: a live corpse at `CorpseState.Stage.FINAL` still represents incomplete final destruction;
it now returns `INCOMPLETE_LIFECYCLE`. Audit correction: process-disabled Session or active-map objects are
not playable and now return `SESSION_NOT_READY`.

The Host accepts only one pending deferred request. `call_deferred()` establishes a stable boundary after
the current synchronous transfer, portal, lifecycle, corpse, or map-handoff callback. A second Save/Load
request cannot interleave with the queued request. No Timer, thread, or blocker-clearing workaround exists.

Relevant paths:

- `game/runtime/persistence/oldpine_save_eligibility.gd`
- `game/runtime/world/oldpine_game_runtime_host.gd`
- `game/tests/runtime/oldpine_save_load_transaction_test.gd`

## Repository and A/B transaction

Production Save and Load go through `GameSaveRepository`; there is no direct `FileAccess` bypass around
codec, verified temp, backup rotation, or canonical promotion. `BACKUP_AVAILABLE` remains evidence only.

Session A stays authoritative while B is decoded, composed, instantiated under `StagingSlot`, and checked.
At commit, A is narrowly suspended, B is activated, then B is attached to `SessionSlot` and verified before
A is queued for deletion. The final attachment is now a typed, overridable seam so the audit can inject a
real final-stage failure. Construction, activation, attachment, malformed JSON, unsupported schema, invalid
item/NPC/corpse data, and invalid physical position all preserve the exact A identity, sampled authority,
position, allocator state, and three RNG states. Exactly one playable Session and no staged candidate remain.

Audit correction: failed final activation/attachment now restores a previously running combat cadence when
A still has active relationships. The rollback retains relationships, input, RNG, allocator, and A identity.

Relevant paths:

- `game/core/persistence/game_save_repository.gd`
- `game/runtime/persistence/oldpine_session_load_coordinator.gd`
- `game/runtime/world/oldpine_game_runtime_host.gd`
- `game/runtime/world/oldpine_outdoor_controller.gd`

## Restore transients and resident maps

Candidate B begins with no opponents, lethal markers, last opponent, busy/interruption, guarding,
aggression, UI selection, or running pre-activation cadence. Areas are staged until activation. Restore
consumes zero gameplay RNG.

Audit correction: a restored Session activates only its saved map; its other resident map remains staged
and process-disabled. The first later handoff now unstages that destination and restores its Areas before it
becomes active. A restored Cave can therefore return through SouthExit to the same retained Outdoor
authority, with Outdoor process-enabled, Player input enabled, and Save eligibility immediately `ALLOWED`.
The completed SouthExit request gate is also cleared regardless of its typed handoff outcome, preventing a
successful committed transition from leaving a false pending flag on the detached Cave.

Relevant paths:

- `game/runtime/world/oldpine_world_session_controller.gd`
- `game/runtime/world/oldpine_resident_map_controller.gd`
- `game/runtime/world/oldpine_cave_passage_controller.gd`
- `game/tests/runtime/oldpine_vine_cross_map_traversal_test.gd`

## Real process proof

### Outdoor complex A/B

Process A used production movement, aggression/combat, corpse selection, Open Loot, and Take interactions.
The disclosed pre-route QA setup was Player base courage `1000`, Player raw dodge `1000`, and Fat Bandit
effective vitality `-1`. QA did not manufacture death, corpse creation, item transfer, or the tombstone.

Saved A authority:

- allocator scope: `oldpine-session-a5fcfb1c807e1e1a87d0416fabd8537e`;
- active map/position: `oldpine.outdoor`, `(-232.993209838867, 435.666290283203)`;
- 5 NPC ledger entries, 13 item records, next dynamic sequence `1`;
- Fat Bandit DEAD and absent from the map;
- corpse ID `oldpine-session-a5fcfb1c807e1e1a87d0416fabd8537e.dynamic.0`;
- corpse retained Fat Bandit short sword and silver; Player held the looted leather plus starting long sword;
- primary weapon remained the starting long sword; armor slots remained empty;
- Combat RNG state `313355908568208825`, next `675958` below one million;
- NPC RNG state `-3094408174960407623`, next `347048`;
- WorldInteraction RNG state `-7380718679721830283`, next `577801`.

Process A fully terminated. Fresh Process B startup-loaded the canonical development save before exposing a
New Game Session. It restored every semantic value above exactly, with fresh runtime identities: Session
`150961391488 -> 295648102667`, Player body `156179105958 -> 299322313218`, and corpse view
`198004705918 -> 303701166839`; CharacterState and Inventory objects also differed. B's first accounted
draw from each RNG stream matched the three expected values. Real UI interaction then took the remaining
silver: the corpse retained only the short sword and Player held leather, silver, and long sword, proving
continued play and no loot duplication.

An attempted Save during a separate real route was correctly blocked because source-faithful guarding
remained set; the audit did not clear or redesign that blocker. The final proof route avoided that state.

### Cave A/B

Process A used real right movement, vine mouse selection, and Hold Vine. The disclosed pre-route QA setup
was raw dodge `1000`; traversal and its WorldInteraction RNG draw remained production behavior. A reached
Cave `(0,120)`, saved, and fully terminated.

- allocator scope: `oldpine-session-73e35d46c2d48ccccc04a87276acc30d`;
- 5 NPC ledger entries, 12 items, no corpses, next dynamic sequence `0`;
- Combat RNG state `5163423644818919878`, next `602547`;
- NPC RNG state `5676402569457890953`, next `699163`;
- WorldInteraction RNG state `2739115849069892948`, next `285877`;
- Session identity changed `150961391488 -> 290010958082` and Cave Player body changed
  `152873994187 -> 290380056776`; CharacterState and Inventory objects also differed.

Process B restored Cave active with one active-map child while Outdoor was detached and process-disabled;
the retained Outdoor still contained the exact five NPC records. Real `move_down` crossed SouthExit into
that same Outdoor authority. After the audit correction, Outdoor was the sole child in
`PROCESS_MODE_INHERIT`, Cave was detached, `cave_pending=false`, Player control was live, and eligibility
was `ALLOWED`. The landing began at the authored Waterfall spawn `(1200,780)`; the held movement continued
to `(1200,838.6669921875)`. A fresh game capture reported `stale_frame=false` with advancing frames.

## QA and release boundary

`_phase10b4_qa_bridge` only invokes production Host Save/Load/startup-load APIs and is located under tests.
The release sanitizer removes tests, the QA autoload, Godot AI, local remote-debug arguments, and any
temporary `qa_startup_load` configuration. It retains the production Host, capture, eligibility,
coordinator, repository, and world runtime.

## Audit fixes and added adversarial coverage

1. Block live FINAL corpses and disabled runtime owners from Save.
2. Restore A's running combat cadence after activation or final attachment rollback.
3. Add an injectable final host-attachment failure boundary and preservation assertions.
4. Clear a completed deferred Cave exit gate.
5. Unstage a restored inactive resident map on its first later handoff.
6. Add malformed/unsupported/invalid snapshot failures, request reentry, exact A-preservation, restored-Cave
   SouthExit, and deterministic process-mode/eligibility assertions.

No Main Menu, Save/Continue UI, autosave, backup recovery UI, mobile lifecycle, cloud save, or Phase 10C
code was introduced.

## Validation record

- Focused Phase 10B4 plus required 10B1/10B2/10B3, item, relationship, lifecycle, resident-map, and RNG
  regressions: **1091 assertions passed**.
- Canonical complete Godot suite: **9951 assertions passed**. The real-file repository portion used its
  intended writable `user://` test directory; a restricted-sandbox attempt was rejected as environment
  evidence rather than treated as a product failure.
- Python tooling: **40 tests passed**.
- Repository/static checks: PASS.
- Godot **4.7.2 stable Steam** development headless editor load: PASS (exit 0; local certificate/Android
  tooling warnings were unrelated to project parsing).
- Fresh release sanitizer and validate-only: PASS.
- Sanitized-project headless editor and 120-frame main-scene smoke: PASS. Production Host, capture,
  eligibility, coordinator, and repository remained; QA/tests/Godot AI/remote-debug/startup-load did not.
- `git diff --check` and trailing-whitespace scan: PASS.
- `reference/es2` was not modified.

## Closure

All formal-close gates passed. **Phase 10B4 is FORMALLY CLOSED.** Phase 10B is ready for its final
major-phase audit/integration gate; Phase 10C remains deferred.
