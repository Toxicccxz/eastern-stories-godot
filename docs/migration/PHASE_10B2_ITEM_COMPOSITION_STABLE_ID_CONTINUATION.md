# Phase 10B2 — Item Composition and Stable ID Continuation

## Scope and baseline

Phase 10B2 builds on the formally closed Phase 10B1 baseline `8296497` and the persistence boundary
selected by `PHASE_10B_NATIVE_SAVE_LOAD_ANALYSIS.md`. It composes the existing Phase 4B5A
`NativeItemStateSnapshot` authority with the live Old Pine item aggregates and introduces one
session-owned dynamic item-ID allocator. It does not add a second Inventory schema.

Character save/load, NPC spawn restore, Corpse restore, restore-mode Session construction, save
eligibility, candidate Session swapping, process-restart proof, and save UI remain deferred.

## Session item-ID allocator

`SessionItemIdAllocator` is a typed `RefCounted` value authority with durable state:

- `scope: StringName`;
- `next_dynamic_sequence: int`.

Dynamic IDs use the stable form `<scope>.dynamic.<canonical nonnegative int64>`. The `.dynamic`
namespace is reserved: malformed same-scope values reject instead of being mistaken for authored
IDs. Bootstrap Player/NPC item IDs remain deterministic authored IDs beneath the same scope and do
not consume the dynamic sequence.

New Game creates an opaque scope from wall-clock plus monotonic microseconds. This is neither a
Godot `ObjectID` nor a draw from Combat, NPC-initialization, or WorldInteraction RNG. Save/load keeps
the exact scope; no new scope is generated during allocator restore.

Restore rejects an empty/negative allocator snapshot, duplicate represented IDs, malformed
same-scope dynamic IDs, and a represented `INT64_MAX` sequence. Its continuation is the greater of
the saved continuation and one past every represented same-scope dynamic sequence, so a stale save
advances and a future saved value never decreases. Allocation checks the authoritative
`InventoryState` before incrementing. Collision and `INT64_MAX` return typed failures without
consuming or wrapping the sequence.

## Native item capture composition

`NativeItemPersistenceComposition.capture()` takes:

- the authoritative `InventoryState`;
- `CombinedStackCollection`;
- the session-local `WorldItemInstanceIndex` projection;
- typed per-character Equipment and Armor sources;
- explicit `NativeItemDefinitionProjections`.

It resolves exactly the Inventory's registered semantic IDs through the runtime index, then calls
the existing `NativeItemStateCapture.capture()`. Phase 4B5A remains responsible for schema v1,
containment, weight, combined amount, hand, open armor-slot, and cross-reference validation.
Missing runtime index representation uses the existing Phase 4 validation taxonomy. There is no
new persistence Dictionary, component graph, movement replay, or equip/wear replay.

## Native item restore composition

`NativeItemPersistenceComposition.restore()` performs this ordered construction:

1. restore the existing `NativeItemStateSnapshot` through `NativeItemStateRestorer`;
2. retain that fresh `NativeItemDomainState` as the reconstructed aggregate;
3. derive one fresh `WorldItemInstanceIndex` from the restored live item IDs;
4. restore and validate the allocator against those exact IDs;
5. expose the aggregate, index, and allocator only when all steps succeed.

Semantic `ItemInstanceId` values remain exact while all runtime `ItemInstance` snapshots,
Inventory, stack collection, and index are fresh objects. The `EquipmentState` and `ArmorState`
objects exposed by `NativeItemDomainState` are the exact objects created by the Phase 4 restorer;
the composition layer does not reconstruct a second pair. They are therefore the objects a later
Player/NPC restore path must inject.

## Old Pine production content projections

`OldPineNativeItemDefinitionProjections.create()` supplies every definition currently needed by
the playable Old Pine graph and Phase 4 validator/restorer:

- long sword — `es2:d/oldpine/obj/long_sword`;
- short sword — `es2:d/oldpine/obj/short_sword`;
- silver combined currency — `es2:obj/money/silver`;
- leather cloth armor — `es2:d/oldpine/obj/leather`;
- corpse — `es2:obj/corpse`.

Weapon, Armor, and Combined projections reuse the existing authored Old Pine loadout/content
definitions. Corpse identity remains traced to `reference/es2/mudlib/obj/corpse.c`. No catalog or
repository singleton was introduced.

## Runtime integration

`OldPineWorldSessionController` now owns one allocator and injects that exact object into both
resident maps. Player and NPC bootstrap IDs and counts are unchanged. `OldPineOutdoorController`
uses the allocator at the former ObjectID-plus-local-sequence corpse seam. It still consumes one
sequence at each lifecycle opportunity, including an unconscious opportunity, preserving the old
wrapper's sequence-advance ordering. Corpse creation, Inventory mutation, interaction-index
registration, view creation, loadouts, and gameplay RNG ordering are otherwise unchanged.

The standalone combat demo keeps its encounter-local ID seam because it is outside the Old Pine
session-owned continuation boundary.

## Verification

Deterministic tests cover:

- graph A -> schema-v1 snapshot -> independent graph B;
- exact semantic IDs with fresh runtime object identities;
- exact derived index/Inventory membership;
- exact injectable Equipment/Armor object identity;
- restored multi-allocation continuation without collision;
- stale/future continuation, duplicate IDs, reserved-prefix malformed IDs, and int64 overflow;
- collision without sequence consumption;
- zero change to all three gameplay RNG streams;
- complete playable production projections;
- the existing Phase 10B1 and Phase 4B5A boundaries;
- Inventory, Equipment, Armor, Combined, NPC/loadout, death/corpse, and resident-map regressions;
- New Game's twelve initial item objects, starting long sword, five NPCs, loadouts, and corpse loop.

Godot 4.7.2 live validation launched the real main Session with a live game helper. Runtime
inspection confirmed `OldPineWorldSession -> ActiveMapSlot -> OldPineOutdoor`, five NPCs, exactly
twelve Inventory/index item identities, the equipped starting long sword, a shared Session/Outdoor
allocator, sequence zero before dynamic use, and a generated `<scope>.dynamic.0` ID without changing
Inventory membership. The player Inventory UI showed the equipped long sword. Current-run game logs
contained no project error.

## Deferred work

Phase 10B3 remains responsible for NPC spawn ledgers, Corpse records, WorldLocation/physical
position reconstruction, restore-mode resident maps, and binding restored equipment/armor into
fresh Player/NPC runtimes. Phase 10B4 remains responsible for capture eligibility, complete Session
composition, transactional candidate swap, repository triggers, and process-restart validation.

Status: **READY FOR FORMAL AUDIT**. This phase is not formally closed by this implementation pass.
