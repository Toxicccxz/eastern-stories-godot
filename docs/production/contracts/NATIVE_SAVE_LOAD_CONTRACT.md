# Native Save / Load Contract

This document defines the persistence guarantees consumed by later work and the owner's development
save-support policy. Reliability within the supported contract is distinct from compatibility between
development versions. Historical phase reports remain evidence for their own implemented boundaries.

## Development save policy

**OWNER APPROVED — 2026-09-26.** Development saves are mechanism-verification material; the project
currently has no formal player progression that must survive every development change. This is a
long-lived operational policy, not a gameplay substitution or authorization to implement the next slice.

1. **No development-version backward-compatibility promise.** A real incompatibility in world content,
   data structure or rule contract may require New Game. Do not build migration features merely to
   retain historical test progress. Nor does this require invalidating otherwise compatible saves.
2. **Current-contract Save/Continue remains strict.** Save and restore legal Player, NPC, item, corpse
   and world state; preserve semantic identity and correct death/removal records. Retain complete
   state consistency, atomic file replacement, staged candidate Session publication and rollback,
   zero gameplay RNG consumption on restore, no fresh initialization of saved entities, existing
   Save eligibility and fail-closed validation. Dropping historical compatibility cannot excuse
   partial restore, missing entities, revived enemies or weakened current regression coverage.
3. **Keep lightweight format/content identification.** Identifiers establish the currently supported
   contract; they do not promise multiple product worlds. Change the relevant identifier only for
   an actual incompatibility. Git commits are not automatic save cutoffs; documentation or compatible
   changes do not require a new game. A content change does not automatically require both root and
   embedded item schema changes. Determine which boundary changed and document the supported set.
4. **Reject incompatible files explicitly.** Future affected implementation must use the existing
   typed error/presentation path to explain: “此存档来自不兼容的开发版本，请开始新游戏。” Do not
   silently add missing NPCs, reroll attributes, replace worlds, resurrect enemies, fall back to
   New Game or label failed loading successful. Explicit backup/temp recovery must satisfy the same
   version and integrity contract; it is not a compatibility bypass.
5. **Invalid does not mean deleted.** Do not automatically delete, migrate, rewrite or promote old
   files. Keep existing New Game/overwrite confirmation, explicit manual Save and backup handling.
   An owner's later real Save may replace a file through that normal confirmed flow; this policy
   update performs no file operation on saves or backups.
6. **No historical product-world obligation.** Do not retain old NPC catalogs, closed-map boundaries,
   feature switches or historical runtime branches solely for obsolete test saves. Future authorized
   work may minimally remove/simplify affected compatibility paths. This is not a repository-wide
   cleanup instruction and does not remove any code by documenting it.
7. **Preserve useful tests, not obsolete promises.** Historical fixtures still testing formulas,
   identity, transactions and failure protection remain valuable. An obsolete requirement that an
   unsupported old save must load is no longer a product obligation. Replace affected success
   expectations with honest incompatible-save rejection where appropriate, retaining current-state
   roundtrip, corruption, rollback and RNG regressions. Do not delete valid coverage wholesale.
8. **Set formal player-save support separately.** Before external long-term testing or formal release,
   the owner must establish a supported player-save baseline and evolution policy. This neither
   promises compatibility with all development history nor permits arbitrary loss of released progress.

### Policy versus implementation snapshot

P2B publishes root schema2, item schema3 and current public **SOURCE_ENTRY_LAKE_V1**,
with ten authored NPC slots: the existing five humans plus five independent INITIAL_ONLY serpents.
`WorldContentRevision.CURRENT_PUBLIC` defines public support. Lake geometry, placement validation,
physical body binding and full current capture/restore are published together. Source birth,
Snow supplies/recovery, native item definitions and Vine behavior retain their source-entry rules.

Recognized unsupported content (including SOURCE_ENTRY_V1 and LEGACY_OLDPINE_V1) uses
`INCOMPATIBLE_DEVELOPMENT_CONTRACT` and the explicit Chinese New Game message; unknown content
uses `UNKNOWN_WORLD_REVISION`; current corruption remains a validation failure. I/O and unsupported
schemas retain separate typed outcomes. The public repository checks support before nested decode
and validates the complete current production ledger before Save or accepting canonical/backup/temp.
Unsupported primary content cannot be masked by backup content. Recovery remains explicit, with no
automatic load/promotion/rewrite, default entity repair or automatic New Game.

Current restoration preserves living/wounded/dead slots, corpses, inventories, allocator and all
three RNG streams without rerunning fresh NPC factories. Physical placement includes Lake's solid
water/perimeter and the shared half-open River/Lake seam. No combat Save was added. Internal LEGACY
regression fixtures use the base repository and current catalog explicitly; they are not a retained
five-human product world. Historical schema readers do not grant old public-world compatibility.
See [P2B evidence](../../migration/PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2B_RUNTIME.md).
Formal cold Continue acceptance remains P2C; ordinary Continue is not its substitute.

This policy does not rewrite the historical NGE/S6B approvals in DECISIONS. The
[project roadmap](../ROADMAP.md) and [scope ledger](../PROJECT_SCOPE.md) distinguish current facts,
planned content and future authorization.

## Authority and identity

The following version-specific details are the current implementation snapshot described above.

- `GameSaveSnapshot` is the only root native-save authority.
- Its `NativeItemStateSnapshot` v3 member is the only item-persistence authority. Inventory, stacks,
  Equipment, Armor and typed food/liquid records compose through this format; no second Inventory
  save model exists. Embedded v1 has no food/liquid; v2 includes food but no liquid; v3 requires both
  arrays. Each version has a strict key set. Legal v1/v2 decode into v3 without granting/refilling
  consumables; definition validation rejects a food/liquid item missing its required state. Liquid
  records contain only stable item ID, typed content and remaining (empty0 is live). Root schema2 /
  SOURCE_ENTRY_LAKE_V1 is the current public content marker; the root format is unchanged. See
  [S6B](../../migration/PHASE_SNOW_TOWN_CORE_HUB_FRESH_WATER_SUPPLY_LOOP.md).
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
  `BACKUP_AVAILABLE`; the Application Shell presents explicit recovery choices through the Host.
- A running Load is an A/B transaction. Candidate B is independently decoded, validated, composed,
  staged, activated, attached, and verified before Session A is destroyed. Failure preserves and resumes
  A. Success exposes exactly one playable B.
- Startup Load is explicit. Failure is reported and is not disguised as a successful New Game.
- Restore consumes zero gameplay RNG. The combat, NPC-initialization, and world-interaction streams resume
  from their exact saved seed/state pairs.

## Current product boundary

The production Runtime Host exposes typed Save/Load requests and owns the replaceable Session.
The integrated [Application Shell](APPLICATION_SHELL_CONTRACT.md) supplies explicit New Game,
Continue, Pause-menu Save and recovery choices; the [Mobile contract](MOBILE_APPLICATION_CONTRACT.md)
adds lifecycle/input behavior without autosave. There is no implied cloud synchronization, encryption,
store-signing or historical-save migration commitment. These current product consumers extend the
original Phase 10B foundation; the current implementation changes are bounded by the P2A report above.
