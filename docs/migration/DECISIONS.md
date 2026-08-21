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
