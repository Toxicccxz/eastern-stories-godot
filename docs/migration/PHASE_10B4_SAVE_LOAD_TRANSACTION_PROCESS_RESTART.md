# Phase 10B4 — Save/Load Transaction and Process Restart

## Scope and authority

Phase 10B4 composes the formally closed 10B1 repository, 10B2 item persistence, and 10B3 world
candidate restoration into a runtime Save/Load transaction. `OldPineGameRuntimeHost` now outlives the
replaceable `OldPineWorldSessionController`; it is deliberately not a menu or game shell.

`OldPineWorldSaveCapture` captures one complete `GameSaveSnapshot`: Player character/runtime facts,
exact world location and map-local position, all five NPC ledger entries, corpse records, the existing
`NativeItemStateSnapshot` v1, allocator continuation, and all three RNG streams. Equipment/Armor are
captured through the existing item composition, and `WorldItemInstanceIndex` remains derived rather than
serialized separately. Nodes, ObjectIDs, active-map duplication, Areas, Timers, UI, and selections are
not durable state. Capture validates both the root DTO and the complete 10B3 restore composition before
returning success.

Character Skill and Condition capture uses narrow typed projections. Temporary attribute modifiers are
not yet represented by a durable provider and therefore fail closed instead of being silently lost.

## Eligibility and stable scheduling

Save is allowed for stable idle ACTIVE state, fully committed UNCONSCIOUS state, coherent completed DEAD
state (`exists=false`), Outdoor or Cave activity, non-authoritative UI state, and pending combined-stack
destruction under the existing schema-v1 omission rule.

Save is blocked, with a typed subject/outcome, for:

- ordinary opponents or lethal markers;
- nonzero busy, leftover interrupt threshold, or guarding;
- pending aggression or running combat cadence;
- active or committed-partial map handoff;
- pending Cave exit request;
- incomplete death/lifecycle work;
- life/existence contradictions;
- unrepresented temporary attribute modifiers;
- staged/suspended/otherwise non-playable Session state.

The public Host queues Save and Load with `call_deferred()`. Capture therefore starts after the current
synchronous gameplay callback and never interleaves with inventory transfer, lifecycle/corpse mutation,
or portal execution. No thread, Timer, heartbeat, or transient-state clearing was introduced.

## Repository and transaction

`OldPineSessionLoadCoordinator` uses `GameSaveRepository` unchanged for canonical JSON, verified temp,
backup rotation, and typed load results. `BACKUP_AVAILABLE` remains evidence only; no backup/temp is
selected automatically.

Load builds fresh candidate B under the Host staging slot while current Session A remains active. It
validates fresh transient relationships, busy state, aggression, and lifecycle state before commit. At
commit A is narrowly suspended, B is activated and checked, then B is reparented through an explicit
Session reparent window. Only after B is a playable child of the Host does A queue for deletion. If
candidate construction or activation fails, B is discarded and A is resumed; A is never mutated in place.
Explicit startup Load builds B before exposing any default New Game Session and does not fall back to a
fresh game on failure.

Successful restore begins with empty opponents/lethal/last-opponent, clear busy/interrupt, guarding false,
empty aggression, stopped pre-activation cadence, fresh Area observations, and fresh UI selection/panels.
Restore consumes no gameplay RNG.

## Identity and QA boundary

CharacterId, ItemInstanceId, spawn/corpse IDs, and allocator scope are semantic and survive exactly.
Session, CharacterState, runtime aggregates, bodies, views, and Godot ObjectIDs are newly constructed.

The `_phase10b4_qa_bridge` autoload is under `game/tests/`. It can request Save, Load, or explicit
`--phase10b4-startup-load`, but calls the same Host/coordinator/repository API intended for future UI and
does not mutate gameplay. The release sanitizer removes this autoload together with tests and Godot AI;
the production Host and coordinator remain in the sanitized project.

## Verification

The focused Phase 10B4 runner covers eligibility boundaries, blocked-save non-mutation, complete live
capture, repository roundtrip, fresh semantic reconstruction, transactional replacement, failed-load
preservation, RNG non-consumption, and the relevant 10B1/10B2/10B3, Session, and lifecycle regressions.
The final focused implementation run passed 1014 assertions before final static/release validation.

Godot AI 3.2.4 and Godot 4.7.2 then proved two real process pairs with
`helper_live=true`, `session_active=true`, fresh captures (`stale_frame=false`), and advancing frames.

- Outdoor A used real movement from `(450,300)` to `(450,168)`, saved to the development canonical
  file, and terminated completely. Outdoor B started with explicit QA startup-load before any New Game,
  restored the same position, 12 IDs, allocator scope and three exact RNG states, but fresh Session,
  Player, and Character ObjectIDs. Real down movement then reached approximately `(450,256)`.
- Cave A used real right movement, mouse landmark selection, and the real Hold Vine button. Because the
  current bootstrap dodge is 5 and therefore cannot select the strict `draw >= 5` Passage branch, QA
  setup raised raw dodge to 100 before the real traversal; the traversal itself used the production world
  RNG and reached Cave `(0,120)`. A saved and terminated. Cave B restored Cave active with Outdoor
  detached/frozen, five retained NPC ledger entries, exact IDs and all three RNG states, and fresh runtime
  ObjectIDs. Real down movement crossed SouthExit and exposed the same Outdoor authority at Waterfall
  `(1200,780)`.
- A live busy-state probe returned typed `SAVE_BLOCKED/BUSY`, retained busy=2, and left allocator and
  Combat RNG unchanged. After ordinary busy advancement, a live stable Save and same-process
  transactional Load returned success, restored the pre-mutation position, created a fresh Session, and
  left exactly one Session child and no staged candidate.

The process scenarios intentionally had no corpse: authored-NPC death, partial loot, and armor continuity
remain exhaustively covered by the closed 10B3 graph tests and the focused restore regressions rather than
being fabricated through QA mutation. No in-memory snapshot or `reload_current_scene()` counted as
process-restart proof.

## Deferred to Phase 10C/10D

Main/Continue/Save menus, slot browsing, recovery choice UI, autosave, mobile lifecycle, cloud/platform
save, encryption, and anti-cheat remain deferred. Multiple slots and automatic backup selection are not
present. Phase 10B4 does not add any player-facing Save/Load UI.
