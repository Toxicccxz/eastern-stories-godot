# Phase 10B Final Audit

## Outcome

Phase 10B's four formally closed slices remain internally consistent:

- 10B1 typed save codec/repository: `8296497`;
- 10B2 item composition and stable ID continuation: `7784611`;
- 10B3 world runtime restore: `7f90dc5`;
- 10B4 transactional Save/Load and process restart: `6e43e59`.

The final audit found no cross-slice production defect and made no gameplay or persistence-code change.
Phase 10B is ready for its one final PR into `main`; Phase 10C has not started.

## Closed architecture

`GameSaveSnapshot` is the sole root save authority. Its embedded
`NativeItemStateSnapshot` v1 remains the sole item-persistence authority; no parallel Inventory schema
was introduced. `WorldItemInstanceIndex` is rebuilt from restored Inventory rather than serialized.

Restore creates a fresh candidate graph. The Equipment and Armor objects produced by native item restore
are the exact objects injected into restored Player/NPC runtimes. Player `WorldLocation` is the only saved
active-map authority. Semantic character, item, NPC, corpse, and allocator identities survive Load while
Node/Object identities are intentionally fresh. The session allocator's durable scope and next sequence
are the only continuation authority for future dynamic item IDs.

Combat relationships, lethal markers, busy/interrupt state, guarding, aggression opportunities, cadence,
Area membership, UI state, and other runtime scheduling facts are reconstructed fresh and are not save
schema fields. Restore consumes zero gameplay RNG and restores the exact three stream states instead.

## Durability and transaction contract

Save is all-or-nothing and is permitted only at the restart-stable boundary recorded in
`docs/production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md`. Stable ACTIVE, fully committed UNCONSCIOUS, and
coherent completed DEAD characters are durable. Incomplete lifecycle work, a live FINAL corpse, runtime
combat/busy/guard state, pending aggression/cadence/transition work, disabled or staged owners, and
unrepresented temporary attribute modifiers block Save rather than being silently discarded.

Load is an A/B transaction. The candidate Session B is decoded, validated, composed, staged, activated,
attached, and checked before Session A is destroyed. Every audited failure boundary preserves and resumes
A. Success exposes exactly one playable B.

## Process-boundary evidence

The Phase 10B4 formal audit remains applicable because this final gate changed no production runtime code.
It records both required fresh-process proofs:

- Outdoor A/B preserved an authored NPC tombstone, partially looted corpse, remaining corpse contents,
  non-default Player position, allocator continuation, all three RNG continuations, and semantic IDs while
  proving fresh runtime identities and continued real looting in process B.
- Cave A/B saved after real Vine traversal, restarted directly into the Cave with Outdoor detached/frozen,
  retained Outdoor authority, then completed a real SouthExit handoff to an unstaged playable Outdoor with
  Save eligibility ALLOWED.

The complete numeric evidence and disclosed QA setup remain in
`docs/migration/PHASE_10B4_FORMAL_AUDIT.md`; they are not duplicated here.

## Main-diff and release boundary

The architectural diff from `main` contains only Phase 10B persistence/runtime integration, its tests,
sanitizer support, migration records, and durable production documentation. No Phase 10C menu, Save UI,
mobile lifecycle, or unrelated gameplay work was found. `reference/es2` is unchanged.

The development project retains the test-only Phase 10B4 QA bridge. The release sanitizer removes that
bridge, all tests, Godot AI, local remote-debug arguments, and temporary startup-load settings while
retaining the production Host, codec, repository, allocator/item composition, capture, eligibility,
restore, transaction coordinator, and world integration.

## Final validation

- Canonical complete Godot suite, run once after the final documentation stabilized: **9,951 assertions
  passed**.
- Python tooling: **40 tests passed**.
- Repository/static checks: PASS.
- Godot **4.7.2 stable Steam** development-project headless editor validation: PASS (exit 0; no parse or
  script errors).
- Fresh release sanitizer and validate-only: PASS.
- Sanitized-project Godot 4.7.2 headless editor validation and 120-frame production-main-scene smoke:
  PASS (both exit 0; no parse or script errors).
- Sanitized boundary scan: production Save/Load authorities retained; QA bridge, tests, Godot AI,
  remote-debug text, and temporary startup-load settings absent.
- `git diff --check` and trailing-whitespace scan: PASS.
- `reference/es2` modifications: **0**.

No production code changed during this final gate, so the previously recorded Outdoor and Cave
fresh-process evidence was not invalidated or needlessly rerun.

## Explicit deferrals

- Phase 10C1: Main Menu, Continue/Save presentation, corruption/backup recovery choice, pause/settings,
  and startup product policy.
- Phase 10C2: touch controls, responsive/safe-area UI, Android Back behavior, and mobile lifecycle/autosave
  policy.
- Phase 10D or later: permanent identity/signing, store/device/package gates, cloud synchronization,
  encryption, migrations beyond the closed schema, and release policy.

These are presentation, platform, or future schema/product decisions; none is silently required by the
closed native persistence core.
