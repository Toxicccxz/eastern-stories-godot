# Migration Decisions

## Condition update order

**Decision:** A single native condition update uses a snapshot of active condition IDs sorted by stable ID string in ascending order.

**Reason:** `feature/condition.c` obtains `keys(conditions)` from an LPC mapping and iterates that array backwards. The mudlib does not define mapping key order as gameplay data, yet multiple conditions can mutate the same resource and therefore need a deterministic native order. Stable ID order is independent of insertion order, hash layout, and save/restore behavior.

**Compatibility impact:** Multiple simultaneous conditions may resolve in a different order from a particular MudOS/FluffOS process. Individual condition formulas, flag aggregation, snapshot behavior, and post-update removal semantics remain unchanged. Source: `reference/es2/mudlib/feature/condition.c`.

## Cultivation percentage division by zero

**Decision:** If a Phase 3B1 health-percentage check reaches a primary resource whose maximum is zero, return a typed `LEGACY_ZERO_MAXIMUM_*_DIVISOR` failure at that exact validation position, without mutation.

**Reason:** `exercise.c`, `meditate.c`, and `respirate.c` calculate `current * 100 / maximum` without guarding zero. The LPC command therefore aborts with a driver division error rather than producing a gameplay failure string. A pure domain transition must not crash the application, and treating zero as merely “below 70%” would hide the source defect and alter validation evidence.

**Compatibility impact:** The native call returns a diagnosable failure instead of throwing a MudOS/FluffOS runtime error. It preserves validation order and the absence of mutation. No positive minimum is imposed on internal-resource current or maximum values. Sources: `reference/es2/mudlib/cmds/std/exercise.c`, `meditate.c`, `respirate.c`.

## Self-learning with non-positive intelligence

**Decision:** Phase 3B2 rejects `selflearn` with a typed `LEGACY_NON_POSITIVE_INTELLIGENCE` failure when base `int` is zero or negative, without mutation.

**Reason:** `selflearn.c` computes `300 / int` without a zero guard. Zero aborts immediately. Negative intelligence produces a negative gin cost and later passes it to `receive_damage()`, which raises an error for negative damage; the LPC path may already have modified potential/skill progress before that error. A native domain transition must not crash or leave a partially applied transaction.

**Compatibility impact:** Normal positive-intelligence behavior is unchanged. Invalid legacy states receive a deterministic typed failure instead of a driver error or partial mutation. This is not a new gameplay minimum for valid characters. Sources: `reference/es2/mudlib/cmds/std/selflearn.c`, `feature/damage.c`.

## Learn legacy runtime errors preserve completed mutations

**Decision:** Phase 3C1 converts division-by-zero, invalid `random()` input, and negative `receive_damage()` points into typed `LearnResult` legacy errors at the exact LPC execution position. Unlike the earlier Selflearn substitution, Learn does not roll back mutations already completed before that point.

**Reason:** `learn.c` has observable mutation-sensitive errors: the raw-zero entry is later than the two intelligence divisions; `learned_points` increments before `random()`; an NPC teacher with a negative gin cost can reach `improve_skill()` and `skill_improved()` before the final negative gin damage errors. Crashing the Godot application is unacceptable, while validating everything before mutation would also change behavior.

**Compatibility impact:** Ordinary Learn behavior is unchanged. Invalid legacy states return a diagnosable result instead of a driver exception, but retain only the raw skill, teacher sen, potential, learned progress, level, or authored effect mutations which LPC had already performed. No minimum intelligence or silent clamp is introduced. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/damage.c`, `feature/skill.c`.

## Learn teacher identity keeps one narrow legacy name field

**Decision:** Native relationships use a stable `TeacherId` (`StringName`) as primary identity, while `ApprenticeshipState` also retains `legacy_master_name` solely for the F_MASTER direct-apprentice predicate.

**Reason:** `learn.c::is_appr_of()` compares master ID plus generation, whereas `feature/apprentice.c::is_apprentice_of()` compares master ID plus persisted master display name and is called by `std/char/master.c::prevent_learn()`. Replacing both with one modern predicate would silently erase a real source discrepancy.

**Compatibility impact:** New content does not use display names as identity, but migrated saves can reproduce the second legacy comparison. The two predicates remain intentionally separate. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/apprentice.c`, `std/char/master.c`.

## Learn runtime facts and randomness are explicit projections

**Decision:** Inventory-based spouse discovery, `present()`/`living()`/`userp()` checks, and `random()` are replaced by typed `TeachingContext` facts plus a deterministic roll supplied by the caller.

**Reason:** These operations belong to LPC inventory/world/runtime infrastructure. The gameplay semantics needed by Learn are only whether this teacher is the spouse, available, a character, awake, and player-style for sen payment, plus a roll satisfying the MudOS range contract.

**Compatibility impact:** Learn retains the original validation order, strict thresholds, player/NPC sen distinction, and random upper-bound formula. The caller is responsible for producing world/relationship facts and a roll `0 <= roll < upper`; Phase 3C1 does not implement their runtime sources. Source: `reference/es2/mudlib/cmds/std/learn.c`.

## Missing Learn policies are explicit

**Decision:** A teacher with no `prevent_learn()` policy has `NO_ADDITIONAL_POLICY` and continues. If relationship fallback requires recognition, a teacher with no recognition policy returns `RECOGNITION_POLICY_ABSENT`; an authored recognition policy whose known dependency is not migrated returns `RECOGNITION_DEPENDENCY_UNAVAILABLE`. An unimplemented authored `valid_learn()` similarly returns `SKILL_LEARN_DEPENDENCY_UNAVAILABLE`.

**Reason:** The mudlib dynamically calls methods which many objects do not define, and does not document the deployed driver's missing-lfun behavior. Prevention is a negative veto and can have an explicit no-veto default; recognition is a positive authorization and cannot be manufactured. Treating every unknown skill hook as the permissive `std/skill.c` default would also erase known authored overrides.

**Compatibility impact:** Teachers and skills whose rules are understood receive explicit policies. “No authored method,” “authored allow,” “authored reject,” and “known dependency unavailable” remain distinguishable. Driver-dependent or not-yet-migrated paths stop with a typed result instead of crashing, silently allowing, or masquerading as a normal authored rejection. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `std/char/master.c`, `std/skill.c`, and the representative teacher/skill daemons listed in `PHASE_3C1_LEARN_CORE.md`.

## Hand-slot state has one native authority

**Decision:** `EquipmentState` exclusively owns the native primary and secondary weapon slots. `EquippedWeaponRef` uses a stable runtime instance ID plus an immutable scalar definition snapshot; the migration does not reproduce the LPC combination of character `query_temp()` object references and a separate mutable item-side `equipped` marker.

**Reason:** The duplicated LPC representation is tied to object environments and dbase/runtime APIs. Recreating both halves would add a compatibility layer and permit divergence without adding gameplay meaning. Stable identity and one authoritative typed state preserve all confirmed slot selection, duplicate, wield-order, and unwield behavior.

**Compatibility impact:** Phase 4A1 transition outcomes match `feature/equip.c`, including secondary-only and two-handed quirks. Later Inventory must enforce cross-owner instance identity and translate move/transfer into an explicit unwield transition; it must not introduce a second authoritative equipped flag. Sources: `reference/es2/mudlib/feature/equip.c`, `cmds/std/wield.c`, `cmds/std/unwield.c`, `feature/move.c`, `std/item.c`.

## Native item persistence preserves the complete represented domain state

**Decision:** Native item schema version 1 snapshots every represented live `ItemInstance`, its exact `InventoryState` own weight and direct parent, `CombinedStackState.amount`, and per-character Equipment/Armor instance references. Restore validates the complete snapshot and reconstructs fresh aggregates all-or-nothing. It does not reproduce LPC's autoload-only inventory loss or replay gameplay transfer/wield/wear operations.

**Reason:** Legacy `F_SAVE` serializes user fields but not ordinary inventory objects. `feature/autoload.c` separately recreates only selected direct inventory objects, and generic hand/armor slot state is not restored. The native domains already own stable instance identity, recursive containment, stack amount, and equipment references; discarding them would make native saves incomplete and would reproduce a runtime limitation rather than gameplay semantics.

**Compatibility impact:** Native saves retain ordinary and nested items plus generic hand/armor state that LPC logout did not retain. Immutable weapon, armor, and stack facts are rebuilt from current definition projections, while saved current own weight is preserved exactly. Legacy autoload is handled by the separate Phase 4B5D one-way importer. Sources: `reference/es2/mudlib/feature/autoload.c`, `feature/save.c`, `obj/user.c`, `cmds/usr/quit.c`, `std/money.c`, `obj/bandage.c`.

## Schema v1 omits pending combined-stack destruction intents

**Decision:** Native item schema version 1 does not persist a pending one-second combined-stack destruction intent. It snapshots only the amount and own weight observable at capture time and restores the stack as an ordinary live instance without synthesizing a new intent.

**Reason:** `std/item/combined.c::set_amount(0)` leaves the old amount and weight observable and schedules destruction through a non-durable `call_out`. Legacy money autoload therefore saves the old visible amount during that window, and the pending callout does not survive reload. Runtime scheduling is deliberately outside Phase 4B5A.

**Compatibility impact:** A pending positive stack can survive reload with its old positive amount and weight; a raw-zero stack restores with amount zero and its exact saved own weight, without automatically scheduling destruction. A future durable scheduler policy would require a new explicit schema decision. Sources: `reference/es2/mudlib/std/item/combined.c`, `std/money.c`, `feature/autoload.c`.

## Legacy autoload import builds validated data instead of replaying login

**Decision:** Phase 4B5D translates legacy autoload strings in original order into an immutable schema-v1 snapshot candidate and typed evidence, then stops. It does not execute `new()`, `move()`, or `autoload()`, does not replay capacity/merge/callback failures, and does not mutate live aggregates. Source-proven bandage wear is represented in candidate Armor data after direct placement; unsupported entries leave the batch explicitly incomplete.

**Reason:** Executing LPC paths would require a compatibility runtime and could leave partial live mutations before a later failure. Phase 4B5A already defines trusted structural reconstruction as the native persistence boundary. A pure importer can preserve traceable data and sequential authored semantics while allowing application policy to reject or inspect incomplete migrations before explicitly restoring anything.

**Compatibility impact:** Imported direct items can reconstruct even where legacy `move(user)` capacity would have failed, and supported entries remain inspectable without reproducing a prior callback abort. No live state changes until a caller separately accepts the candidate and invokes native restore. Sources: `reference/es2/mudlib/feature/autoload.c`, `obj/bandage.c`, `std/item/combined.c`.

## Legacy zero-money import keeps clone state plus a transient intent

**Decision:** Importing a source-produced money parameter `"0"` creates a candidate stack with amount `1` and one unit of the concrete currency's base weight, then emits a typed one-second destruction intent outside schema v1. The importer does not start a timer.

**Reason:** Each concrete money clone executes `set_amount(1)` in `create()`. Its later `autoload("0")` calls `set_amount(0)`, which schedules destruction but does not assign zero or update weight. Saving raw zero in the candidate would invent a state the executable restore path never exposed.

**Compatibility impact:** If an application accepts this unusual candidate but does not later execute the external intent, the one-unit stack remains live. Schema v1 itself is unchanged and still does not durably persist pending destruction. Sources: `reference/es2/mudlib/std/money.c`, `std/item/combined.c`, `obj/money/coin.c`, `gold.c`, `silver.c`, `thousand-cash.c`.

## Item destruction stops on an unexpected native equipment-detach failure

**Decision:** Phase 4B5B prevalidates structure, then attempts exact hand cleanup followed by exact Armor cleanup. If a referenced instance unexpectedly cannot be removed from one of those native authorities, lifecycle returns a typed failure and does not remove the item's Inventory/stack registration. Any earlier successful hand cleanup is not rolled back and is reported in the result.

**Reason:** `feature/move.c::remove()` logs an `unequip()` failure and continues to driver destruction. Reproducing that continuation in the native split-authority model would remove the item while leaving an impossible authoritative Equipment/Armor reference. Current typed transitions normally succeed whenever their identity predicate was true, so this is an invariant-defense path rather than a new gameplay rejection.

**Compatibility impact:** Structurally valid current states preserve LPC's ordinary cleanup-then-destruction behavior. A corrupted or future custom aggregate that reports an item equipped but refuses exact detach keeps the item live instead of reproducing a dangling-reference defect. The result honestly exposes any cleanup already completed; no invented rollback occurs. A composed multi-sibling stack merge commits each successfully destroyed sibling's positive quantity before attempting the next lifecycle transition, so a later injected detach failure cannot erase an earlier sibling's quantity; normal successful final totals and survivor identity are unchanged. Direct-character lifecycle context must contain both authoritative aggregates—explicit empty states mean empty, while `null` means the authority was omitted and is rejected. Sources: `reference/es2/mudlib/feature/move.c`, `feature/equip.c`, `std/item/combined.c`.

## Death and corpse inventory ordering uses stable instance IDs

**Decision:** Phase 4B5C snapshots a victim's direct item IDs in ascending stable-ID order, evaluates `owner_is_killed` policies in that order, and processes survivors in descending snapshot order to preserve `chard.c`'s reverse loop. Corpse final scatter uses ascending direct-child order.

**Reason:** `adm/daemons/chard.c` snapshots `all_inventory(victim)`, invokes hooks over that array, then walks survivors backwards; `obj/corpse.c` walks its `all_inventory()` array forwards. The mudlib does not define object-chain allocation order as authored gameplay data, but policy destruction and ignored transfer failures make order observably affect partial results. `InventoryState.direct_children()` already supplies deterministic stable-ID snapshots, so the death domain must state how legacy forward/reverse traversal maps to that native order.

**Compatibility impact:** A particular MudOS process may have evaluated or moved items in a different object-chain order. Direct-only membership, policy-before-transfer ordering, reverse survivor concept, per-item partial mutations, final forward scatter concept, and all item formulas remain unchanged. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `obj/corpse.c`.

## Incomplete synchronous death hooks cannot restart the whole death flow

**Decision:** A death-item hook that requires unavailable native runtime work, or a destruction failure after observable cleanup, returns a typed incomplete result with `DO_NOT_RESTART_FROM_BEGINNING`. Phase 4B5C deliberately provides no generic continuation token or scheduler.

**Reason:** `owner_is_killed()` runs synchronously over one direct-inventory snapshot before survivor movement. By the time a native boundary is encountered, a normal death may already have created/placed a corpse and earlier policies may already have destroyed items or detached equipment. Re-running the complete operation would duplicate or reorder those mutations.

**Compatibility impact:** Future NPC/runtime orchestration must continue from the recorded boundary using current authoritative aggregates; it must not call the whole Phase 4B5C process again. This preserves the LPC ordering without introducing callback dispatch or a runtime workflow engine. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `daemon/class/scholar/windspring.c`, `feature/move.c`.
