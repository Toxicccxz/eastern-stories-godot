# Phase 10B2 — Formal Audit

## Audit identity and scope

- Branch: `phase/10b-native-save-load`.
- Formally closed Phase 10B1 baseline: `8296497`.
- Phase 10B2 implementation commit reviewed: `91c7d16`.
- The audit remained inside item composition, stable ID continuation, narrow Old Pine allocator
  wiring, tests, and migration records. It did not start Phase 10B3, add restore-mode Session
  construction, persist corpses, or create a PR.
- `reference/es2` remained read-only. No new LPC rescan was required because this audit verifies the
  native Phase 4/10 persistence and runtime-composition boundary rather than a new legacy rule.

## Findings and fixes

Two concrete correctness issues were found:

1. New Game scope generation combined wall-clock microseconds with process-local monotonic
   microseconds. The monotonic component restarts in each process, so equal or regressed wall-clock
   observations could not defensibly exclude scope reuse across independent processes. The narrow
   replacement is `SessionItemIdScopeFactory`: a pure typed `RefCounted` helper that consumes 128
   bits from Godot's platform cryptographic source and emits
   `oldpine-session-<32 lowercase hex digits>`. It uses no Node, ObjectID, or gameplay RNG. The exact
   scope remains ordinary persisted allocator data after creation.
2. Allocator restore treated every ID beginning with `<scope>.dynamic` but not
   `<scope>.dynamic.` as malformed. That incorrectly claimed authored IDs such as
   `<scope>.dynamic-sword`. Restore now reserves only the exact `<scope>.dynamic` namespace marker
   and the exact `<scope>.dynamic.<sequence>` grammar. Similar authored IDs and foreign scopes stay
   outside allocator interpretation.

The implementation already had the correct Phase 4 authority and composition shape. Tests were
expanded to prove nested corpse containment, own weights, strict unknown-definition failure,
all-or-nothing failure non-mutation, duplicate registration without overwrite, direct restored
Equipment/Armor identity, exact continuation examples, adversarial int64/string boundaries, rapid
scope generation, same allocator identity across resident maps, and the intentional unconscious
sequence gap. `DECISIONS.md` did not require a gameplay compatibility decision.

## Persistence authority and graph reconstruction

- `NativeItemStateSnapshot` schema v1 remains the only persisted item authority. It owns item
  records, direct containment, own weight, combined amounts, per-character Equipment, and
  per-character Armor. `GameSaveSnapshot` embeds this exact type; no second Inventory, Equipment,
  Armor, Combined, or containment schema exists.
- `WorldItemInstanceIndex` remains a derived runtime lookup and is absent from the save schema.
  Capture requires every live Inventory ID to resolve in the current index. Restore first creates a
  fresh Phase 4 domain aggregate, then derives a fresh index from exactly those restored IDs.
- Graph A -> snapshot -> graph B preserves semantic `ItemInstanceId` values, direct Character/World/
  Item containment, own weight, and combined amount. Inventory, stack collection, item snapshots,
  and index have fresh runtime identity.
- The `EquipmentState` and `ArmorState` returned by the composition result are the exact objects held
  by `NativeItemDomainState`; no second reconstruction or replay occurs. These are the objects a
  later Player/NPC restore path must inject.
- Missing index representation, unknown definitions, malformed snapshots, duplicate identities,
  and allocator failure expose no candidate aggregate. Failed capture/restore does not mutate the
  source graph.

## Definition and identity conclusions

`OldPineNativeItemDefinitionProjections` covers the complete currently playable validator/restorer
set: long sword, short sword, silver, leather, and corpse. Immutable weapon, armor, stack, and item
facts are resolved from these production projections rather than serialized per instance. Unknown
definition IDs fail through the existing Phase 4 typed validation result.

The session allocator stores only `{scope, next_dynamic_sequence}`. Dynamic IDs have the canonical
form `<scope>.dynamic.<nonnegative canonical int64>`. Restore rejects duplicate represented IDs,
empty/exact malformed namespace values, empty/nondecimal/negative/leading-zero/extra-delimiter
suffixes, and represented `INT64_MAX`. Foreign scopes and authored lookalikes do not affect the
continuation. The result is `max(saved continuation, represented sequence + 1)`; allocation checks
Inventory before commit, consumes no sequence on collision, never recycles, and fails at
`INT64_MAX` without wrapping.

Explicit audited cases passed:

- saved 5 plus represented 12 -> 13;
- saved 20 plus represented 12 -> 20;
- represented 0 -> 1;
- represented `INT64_MAX - 1` -> allocator at `INT64_MAX`, whose next allocation fails;
- represented `INT64_MAX` -> restore overflow failure;
- restore followed by five allocations -> exact noncolliding consecutive IDs.

## Session, lifecycle, and RNG conclusions

- One allocator is owned by `OldPineWorldSessionController`; Outdoor and Cave receive the exact
  same object. Resident-map handoff does not replace it.
- New Game still creates exactly twelve authored bootstrap items, the Player still starts with the
  long sword, five NPCs retain their loadouts, and authored bootstrap IDs consume no dynamic
  sequence.
- The old lifecycle wrapper advanced its local corpse sequence for every lifecycle opportunity.
  The native allocator intentionally preserves that ordering: an unconscious opportunity consumes
  one ID but creates no Inventory item, index entry, or corpse. The later death uses the next ID.
  Tests and live evidence record this gap rather than silently recycling it.
- A complete death still creates one corpse, keeps its direct contents/worn behavior, registers one
  interaction projection only after complete death, and remains lootable. Existing partial-death
  behavior remains unchanged. Corpse persistence itself is still deferred.
- Scope generation and allocation leave Combat, NPC-initialization, and WorldInteraction RNG
  seed/state unchanged. The cryptographic scope source is deliberately outside all three gameplay
  streams.

## Verification

- Phase 10B2 focused runner after audit fixes: **3,423 assertions passed**.
- Canonical complete historical suite, run exactly once after fixes: **9,604 assertions passed**.
- Python tooling: **40 tests passed**.
- Repository/static checks: passed.
- Godot **4.7.2** development headless editor validation: passed.
- Fresh release sanitizer and sanitized-project Godot 4.7.2 headless validation: passed. Gameplay
  tests were explicitly skipped in this second canonical-tool invocation because the complete suite
  had already run once separately.
- `git diff --check` and trailing-whitespace scan: passed.
- `reference/es2` modifications: **0**.
- `docs/migration/DECISIONS.md` modifications: **0**.

Live main-Session validation used Godot AI 3.2.4 with `helper_live=true`, `session_active=true`, and
`game_capture_ready=true`. Two later framebuffer captures were non-stale and advanced from frame
12,048 to 18,814. Initial runtime state had five NPCs, twelve Inventory/index IDs, sequence zero,
the equipped long sword, and exact allocator identity across Session/Outdoor/Cave. After a
test-only vitality setup, real mouse input selected the visible bandit and clicked Attack; real
cadence produced unconscious then death. Real mouse input selected the corpse, project movement
input entered loot range, and real UI clicks opened Loot and took the short sword. Final runtime
state had one registered `dynamic.1` corpse, continuation two, short sword direct under Player,
silver still direct under corpse, thirteen Inventory/index identities, and no current-run game
error. The test-only setup changed only victim vitality and initial physical proximity; it did not
invoke selection, attack, cadence, lifecycle, loot, or transfer methods.

## Deferred work and formal status

Phase 10B3 still owns NPC spawn ledgers, corpse save records, world location/position restoration,
restore-mode resident maps, and injection of the already-restored Equipment/Armor objects into fresh
Player/NPC runtimes. Phase 10B4 still owns save eligibility, complete Session capture, transactional
candidate swap, repository triggers, and packaged process-restart save/load proof.

All Phase 10B2 formal-close blockers passed. Phase 10B2 is **FORMALLY CLOSED** and Phase 10B3 is
safe to begin from this item-composition and stable-ID boundary.
