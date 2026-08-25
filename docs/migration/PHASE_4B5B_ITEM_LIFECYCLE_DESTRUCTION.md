# Phase 4B5B — Item Lifecycle / Destruction Core

## Scope and authoritative sources

Phase 4B5B adds the pure-domain transition that removes a live native item. It does not decide why destruction occurs and contains no scheduler, world, death, corpse, combat, callback-dispatch, or persistence-format behavior.

Authoritative LPC/runtime evidence re-read:

- `reference/es2/mudlib/adm/simul_efun/object.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/std/item.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/obj/bandage.c`
- `reference/es2/mudlib/doc/efuns/destruct`
- `reference/es2/mudlib/doc/applies/move_or_destruct`

The full mudlib was also searched again for active `destruct(`, `remove(`, `move_or_destruct`, `equipped`, and `unequip` uses. The relevant generic chain is simul-efun `destruct()` -> object `remove()` -> driver destruction. `feature/move.c::remove()` attempts equipment cleanup before destruction and removes the object's own encumbrance contribution. Driver `move_or_destruct` processing applies to contained objects; the only active gameplay escape override found is the special user-to-VOID path, not an ordinary-item path.

## Native liveness and object lifetime

`ItemInstance` remains an immutable identity/value object. Its ID is live in the represented native domain exactly while `InventoryState.is_registered(id)` is true. Logical destruction removes authoritative runtime registration; it does not mutate, invalidate, or forcibly free every stale `RefCounted` reference held by callers.

There is deliberately no LIVE/PENDING/DESTROYED enum or mutable lifecycle flag. A pending combined-stack destruction intent also does not change liveness: until an external runtime adapter fires it, the stack retains its old amount, weight, containment, and equipment possibilities.

## Lifecycle API and authorities

The stateless entry point is:

```gdscript
ItemLifecycleService.destroy_item(
    inventory: InventoryState,
    stacks: CombinedStackCollection,
    item_instance_id: StringName,
    child_disposition: ItemLifecycleResult.ChildDisposition = REQUIRE_LEAF,
    direct_owner: ItemLifecycleOwnerContext = null,
) -> ItemLifecycleResult
```

Authority remains separated:

- `InventoryState`: liveness/registration, direct parent, ancestry, own weight, and derived subtree/root weight;
- `EquipmentState`: primary/secondary hand references;
- `ArmorState`: worn-slot references and derived numeric aggregate;
- `CombinedStackCollection`: stack amount/definition association;
- `ItemLifecycleService`: ordered orchestration only.

`ItemLifecycleOwnerContext` contains a character ID and the explicitly scoped Equipment/Armor aggregates. A directly character-owned target requires a non-null context, a non-empty exact character ID match, and both aggregate references. `null` cannot mean "empty Equipment/Armor" because it could equally mean that the caller silently omitted an authority; callers represent genuinely empty hands/slots with explicit empty `EquipmentState` and `ArmorState` instances. Missing context returns `OWNER_CONTEXT_REQUIRED`, an empty ID or either missing aggregate returns `OWNER_CONTEXT_INCOMPLETE`, and a complete C2 context for a C1 item returns `OWNER_CONTEXT_MISMATCH`, all before detach/removal. WORLD-, ITEM-, and unparented targets do not inspect a supplied character context.

No public unrestricted `unregister_item()` API was added. Lifecycle uses the existing narrow internal leaf-removal seam, `InventoryState._remove_registered_leaf()`, after complete structural prevalidation.

## Child disposition and deterministic removal

`REQUIRE_LEAF` rejects a target with direct children using typed `NOT_LEAF`, before equipment mutation. It never orphans or silently recurses.

`DESTROY_SUBTREE` computes and validates the complete descendant set first. It then removes items in stable depth-first post-order using the already established exact-ID ordering of `InventoryState.direct_children()`. This native order is deterministic for tests and consumers; it is not claimed to reproduce an authored MudOS driver order.

For `A -> B -> D` and `A -> C`, the result order is `D, B, C, A`. Each successful leaf removal deletes its parent relation and own-weight registration. Because Inventory derives weights from the current graph, descendants and parent disappear without a second lifecycle weight cache or double subtraction.

## Equipment and Armor cleanup

Only a target directly parented by `CHARACTER(character_id)` receives equipment cleanup. The service checks stable instance identity and calls, in order:

1. `EquipmentState.unwield(instance_id)`;
2. `ArmorState.remove(instance_id)`.

It does not infer equip state from item definitions and does not inspect descendants recursively. Primary and secondary removal preserve existing no-promotion behavior. Removing Armor also removes its contribution from the derived Armor aggregate. If malformed native state references one instance in both hand and Armor state, both authorities are defensively cleaned in hand-then-Armor order and the result reports both facts; this does not make that shape valid gameplay.

LPC `feature/move.c::remove()` logs an unequip failure and continues destruction. Native continuation would leave an impossible live Equipment/Armor reference after Inventory removal. The documented safety substitution is therefore: an unexpected exact detach failure returns a typed failure and keeps structural liveness. Successful earlier cleanup is not rolled back and is reported honestly. Valid current aggregates make this path defensive rather than ordinary gameplay.

## Combined-stack behavior and Phase 4B3 integration

Every removed ID is checked for an exact stack association. If present, its `CombinedStackState` and definition association are removed together after Inventory leaf removal. Destruction does not call `set_amount(0)` or first mutate amount/weight to zero. Before any structural removal the service verifies every removal-set stack has a non-negative state with the exact ID and a valid definition. In the synchronous base aggregates, post-order makes each Inventory removal a guaranteed leaf, and `_remove_stack()` checks the same still-present state with no callback/await/intervening mutation. Thus the second cleanup cannot predictably fail after the first for a prevalidated aggregate; defensive failure outcomes still report any actual prior removals rather than falsely claiming atomicity.

`CombinedStackService.transfer_and_merge()` now delegates absorbed-sibling removal to `ItemLifecycleService` with `REQUIRE_LEAF`. Existing Phase 4B3 ordering remains:

1. move the incoming stack;
2. scan compatible direct character siblings;
3. reject `ABSORBED_STACK_HAS_CONTENTS` before detach/removal;
4. read each absorbed amount;
5. lifecycle-remove the sibling immediately;
6. commit that successfully removed sibling's positive quantity to the moved survivor before attempting the next candidate;
7. expose the same final total after all candidates.

The per-success quantity commit is the formal-audit correction for a native-only failure path: B can be removed successfully and C can then fail an injected exact detach. Deferring the only survivor update until after C would lose B's quantity. The corrected failure reports only completed absorbed IDs/amount, keeps C live, and leaves A holding its original amount plus B. Successful merges retain the same final amount, survivor identity, deterministic absorption order, and final weight as Phase 4B3/LPC. Zero totals still make only the final legacy `set_amount(0)` call, so no hidden intermediate destruction intent is created.

The moved stack remains the survivor. An absorbed hand-equipped sibling is unwielded without promotion or equipment transfer to the survivor. A malformed worn association can also be removed when the caller supplies the destination Armor context. Character absorption therefore requires one caller-bound destination `ItemLifecycleOwnerContext`; `CombinedStackService` does not accept unscoped destination state references or fabricate their character ID. Omission or an ID mismatch is a non-destructive lifecycle failure after the already-closed transfer step. Surviving stacks keep their existing one-to-one Inventory/stack associations, and Phase 4B5A capture/validation is used by tests to prove that completeness after removal.

For `set_amount(0)`, Phase 4B3 still emits only a one-second external intent and leaves old state visible. Phase 4B5B provides the ordinary destruction endpoint a future adapter can invoke when that intent fires; it adds no Timer, wall clock, pending state, or helper scheduler.

## Persistence interaction

Native save schema version 1 is unchanged. There are no destroyed-ID, pending-deletion, or lifecycle fields. A capture containing only currently registered live item values succeeds after destruction; passing a stale destroyed `ItemInstance` value still fails the existing `ITEM_INSTANCE_NOT_REGISTERED` validation.

`NativeItemDomainState` and save DTOs are not lifecycle dependencies. Application code may coordinate their runtime aggregates, but persistence is not the runtime ownership model.

## Deferred source behavior and Phase 4B5C dependencies

- Driver `move_or_destruct` handling for interactive user objects belongs to character/runtime lifecycle. Ordinary native Item descendants use explicit subtree destruction.
- `obj/bandage.c::remove()` calls the inherited remove first and then tests the equipped marker that the inherited path normally clears. Its condition cleanup is therefore apparently unreachable on the normal path. Conditions and generic authored remove callbacks remain deliberately deferred pending a narrow, proven policy need.
- Death orchestration, `owner_is_killed`, corpse creation/capacity/decay/scatter/animate, user/NPC handling, and world presentation belong to Phase 4B5C or later.
- Runtime execution of delayed combined-stack intents remains an application/runtime scheduling concern.

## Implemented result evidence

`ItemLifecycleResult` is immutable-by-interface and returns defensive copies for arrays and containment endpoints. It records the requested ID, child disposition, typed outcome, deterministic removed IDs, previous parent/root, and separate weapon/Armor detach facts. It contains no mutable domain aggregate references or generic dictionary payload.

## Formal implementation audit corrections

The formal audit found and fixed two production defects:

1. A character-bound context with one or both authority aggregates omitted was previously accepted, allowing direct destruction to skip a potentially authoritative hand/worn collection. Both are now mandatory and explicit empty aggregates represent empty state. Merge integration now accepts the bound context itself instead of relabeling unscoped destination aggregates with the resulting parent ID.
2. A later sibling lifecycle failure during a multi-stack merge could occur after an earlier sibling had been destroyed but before the survivor total was written, permanently losing the earlier quantity and over-reporting absorbed IDs. Each completed positive absorption is now committed before the next attempt, and partial results report only actual completed removals.

Audit regressions also prove: hand-success/Armor-failure partial evidence without rollback; invalid stack associations stop before either authority is removed; direct root-container hand/Armor cleanup before subtree post-order; branched `D,B,C,A` order; multiple stack descendants plus an outside survivor; sibling-only weight changes; and Phase 4B5A validation of surviving stack completeness.
