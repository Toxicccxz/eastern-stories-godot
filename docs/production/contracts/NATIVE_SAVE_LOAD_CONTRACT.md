# Native Save / Load Contract

This document defines the stable contract consumed by work after Phase 10B. It is not a history of the
implementation.

## Authority and identity

- `GameSaveSnapshot` is the only root native-save authority.
- Its `NativeItemStateSnapshot` v1 member is the only item-persistence authority. Inventory, stacks,
  Equipment, and Armor are composed through that existing format; no second Inventory save model exists.
- `WorldItemInstanceIndex` is derived from restored Inventory and is never serialized as authority.
- Semantic character, item, NPC, corpse, spawn, and world identities persist across Load. Runtime Godot
  object identities are fresh.
- Dynamic item identity uses the session allocator's durable `{scope, next_dynamic_sequence}`. Restore
  never decreases the sequence and advances beyond represented same-scope IDs; ObjectID and gameplay RNG
  are not identity sources.
- An authored NPC tombstone suppresses respawn. A living NPC record and its tombstone may not coexist.

## Durable world boundary

- Player location is the sole saved active-map authority and includes region, map, zone, combat-location,
  and physical position. Restore rejects unknown or contradictory placement instead of guessing or
  clamping it.
- Stable ACTIVE, fully committed UNCONSCIOUS, and coherent completed DEAD character states are durable.
- Save is rejected while any restart-unsafe transition is present: incomplete lifecycle work, a live
  FINAL corpse, opponents or lethal intent, busy/interrupt or guarding state, pending aggression or combat
  cadence, an active/partial map handoff or Cave exit, staged/disabled runtime owners, or temporary
  attribute modifiers without durable provenance.
- Transient combat, cadence, Area membership, UI, and presentation state are rebuilt fresh after Load;
  they are not serialized.

## Repository and transaction guarantees

- The runtime uses one fixed slot named `default-v1.json`. Release storage is
  `user://save-data/release/default-v1.json`; development and isolated tests use separate profiles.
- Save encodes and validates a temporary file before replacing the canonical file. The previous canonical
  file is rotated to `.bak`; failed replacement attempts rollback when possible.
- Load never silently selects `.bak` or `.tmp`. A valid recovery candidate is reported as
  `BACKUP_AVAILABLE`; the future product layer decides how to present recovery.
- A running Load is an A/B transaction. Candidate B is independently decoded, validated, composed,
  staged, activated, attached, and verified before Session A is destroyed. Failure preserves and resumes
  A. Success exposes exactly one playable B.
- Startup Load is explicit. Failure is reported and is not disguised as a successful New Game.
- Restore consumes zero gameplay RNG. The combat, NPC-initialization, and world-interaction streams resume
  from their exact saved seed/state pairs.

## Current product boundary

The production Runtime Host exposes typed Save/Load requests and owns the replaceable Old Pine Session.
Phase 10B does not define Main Menu, Continue/Save UI, recovery-choice UI, autosave, mobile lifecycle,
cloud synchronization, encryption, store signing, or schema migration beyond the currently supported
versions. Those remain explicit Phase 10C/10D-or-later responsibilities.
