# Phase 10B3 — World Runtime Restore

## Scope and baseline

Phase 10B3 builds on the formally closed Phase 10B1 baseline `8296497` and
Phase 10B2 baseline `7784611`. It turns a validated `GameSaveSnapshot` into a
fresh, staged Old Pine runtime candidate. It does not implement save
eligibility, repository-driven live load, current-Session replacement,
process-restart proof, menus, or save UI; those remain Phase 10B4 or later.

This phase composes the already-migrated native authorities. It adds no new LPC
gameplay mechanic and does not change `reference/es2/`.

## Reconstruction boundary

`OldPineWorldRestoreService.build_candidate()` performs an all-or-nothing
construction under a caller-owned staging parent:

1. `GameSaveSnapshotValidator` validates the typed root snapshot.
2. `NativeItemPersistenceComposition` restores the existing Phase 4B5A item
   schema and the Phase 10B2 allocator/index composition.
3. fresh Player and five authored NPC runtime aggregates are reconstructed;
4. typed corpse records are cross-checked against the item graph;
5. all three RNG adapters restore their exact saved state;
6. the real Outdoor and Cave scenes are instantiated and bound;
7. exact saved positions are validated against current map geometry;
8. only the Player's saved map is attached, while the other resident remains
   detached and frozen.

Any failure frees the candidate and returns a typed path/outcome. It never
mutates a currently playable Session. Candidate swap/commit is deliberately
absent.

Representative implementation:

- `game/runtime/persistence/oldpine_world_restore_service.gd`
- `game/runtime/persistence/oldpine_world_restore_composition.gd`
- `game/runtime/persistence/oldpine_world_restore_preparation.gd`
- `game/runtime/persistence/oldpine_world_restore_result.gd`
- `game/runtime/world/oldpine_world_session_controller.gd`

## NPC spawn ledger and Character reconstruction

The Old Pine ledger is derived from all authored `NpcSpawnDefinition` records
and contains exactly one entry per spawn point: three ordinary bandits, one
tall bandit, and one fat bandit. `spawn_id` identifies the authored spawn
group and may therefore repeat; `spawn_point_id` and `CharacterId` are the
stable per-slot identities. Root validation was corrected accordingly.

Each entry strictly resolves spawn, point, NPC definition, derived body facts,
world location, position, and represented live-loadout ItemInstanceIds. A
living NPC must retain the complete authored loadout. A dead tombstone may
retain any valid authored subset because former items can already have been
looted or destroyed. Alive, unconscious, and dead lifecycle states are
restored as committed facts rather than re-derived from resources, and root
validation rejects both dead/present and non-dead/absent contradictions. A
dead NPC remains one of the five ledger entries with `exists_in_map == false`,
so absence cannot be misread as a fresh spawn request.

`CharacterStateSnapshotRestorer` creates fresh typed attributes, primary and
internal resources, recovery, progression, conditions, skills, family, and
apprenticeship state. Raw skills are created before mappings. The narrow
`CharacterSkillState._restore_mapping_presence()` seam preserves the observable
legacy distinction between absent and present-empty skill/learned mappings;
it exposes no generic persistence Dictionary.

The Player and each NPC receive the exact `EquipmentState` and `ArmorState`
objects produced by the Phase 10B2 item restore. Learn, Wield, Wear, condition
updates, recovery, combat, and NPC initialization are not replayed.

Representative implementation:

- `game/core/persistence/character_state_snapshot_restorer.gd`
- `game/core/skills/character_skill_state.gd`
- `game/data/oldpine/oldpine_spawn_definitions.gd`
- `game/runtime/persistence/oldpine_restored_npc_entry.gd`

## Corpse persistence

Every saved corpse is validated against:

- a live corpse `NativeItemRecord` with the same ItemInstanceId;
- the expected corpse ItemDefinitionId;
- world containment in the saved combat location;
- a saved dead/non-existent Player or NPC victim;
- exact victim identity, display, gender, age, body weight, and capacity facts
  (the current Player death context authors age `20`);
- typed worn projections whose armor definitions and item containment agree;
- a represented decay stage and finite valid map position.

Corpse contents and nested contents remain solely in
`NativeItemStateSnapshot` containment. Restore creates one fresh `CorpseState`
and, only after domain validation, one fresh `CombatSliceCorpseView`; it does
not persist or restore Timer, Area overlap, selection, UI, or offline decay.

Representative implementation:

- `game/runtime/persistence/oldpine_restored_corpse_entry.gd`
- `game/runtime/persistence/oldpine_world_restore_composition.gd`
- `game/runtime/world/oldpine_outdoor_controller.gd`

## Physical position validation

`OldPineMapPlacementValidator` accepts only finite map-local coordinates that:

- lie inside exactly one current authored zone shape;
- match the saved map/zone identity; and
- do not overlap an authored `StaticBody2D` collision shape using the current
  character or corpse footprint.

Unknown maps/zones, ambiguous/outdated zone placement, collision coordinates,
and invalid corpse positions fail with `INVALID_PHYSICAL_POSITION`. No marker
fallback or silent teleport exists.

## NEW_GAME and RESTORE Session modes

`OldPineWorldSessionController.BootstrapMode` is selected before the Session
enters `SceneTree`.

- `NEW_GAME` retains the existing initialization path: one Player, twelve
  bootstrap item objects, five authored NPCs, no corpse, Outdoor active, and
  the existing RNG ordering.
- `RESTORE` receives reconstructed Player/item/index/allocator/NPC/corpse/RNG
  authorities before scene binding and suppresses all default item, loadout,
  NPC, corpse, and random initialization.

Both real resident scenes are instantiated and bound to the same restored
authorities. The active map is derived only from Player `WorldLocation.map_id`;
exactly one resident is attached. The inactive resident remains detached with
`PROCESS_MODE_DISABLED` but retains its reconstructed Outdoor NPC ledger when
the Cave is active.

While a candidate is staged, Session/map processing, player control, camera,
and every authored or dynamically created `Area2D` monitoring/input surface
remain disabled. Staging is reapplied after corpse-view creation because that
binding creates a fresh runtime Area. The QA-only activation seam enables only
the active resident and then reconciles relationships; it is not the Phase
10B4 current-Session transaction.

## Second-corpse investigation

The live RESTORE QA fixture intentionally places the Player in the Pine
Entrance near the surviving tall bandit and restores the fat bandit as a dead
tombstone with one saved corpse.

Focused runtime evidence established this sequence:

- staged candidate: 13 Inventory items, 13 index entries, allocator sequence
  `1`, and exactly
  `<scope>.dynamic.0 -> fat_bandit CharacterId`;
- immediately after activation: the same 13/13/1 state, five NPC ledger
  entries, fat bandit `DEAD + exists=false`, tall bandit alive, no combat
  relationship, and exactly one corpse;
- after normal runtime opportunity: tall bandit and Player entered reciprocal
  combat;
- later: Player reached committed `DEAD + exists=false`; ordinary lifecycle
  allocated `<scope>.dynamic.1`, Inventory/index became 14, allocator became
  `2`, and the second corpse's victim was exactly `oldpine.player`.

Therefore the observed second corpse was normal post-activation
aggression/combat/death gameplay, not restore duplication or lifecycle replay.
No production correction was required.

## Verification

The focused runner covers Phase 10B3 plus relevant Phase 10B1/10B2,
Character/Skill/Condition, Phase 4 item/Inventory/Equipment/Armor/Combined,
death/corpse/lifecycle, NPC/loadout, resident-map/traversal, and RNG regressions.
It proves, among other boundaries:

- fresh Outdoor and Cave resident identity with exactly one active child;
- exact Player/NPC/corpse positions;
- five-slot alive/unconscious/dead ledger behavior without age reroll;
- exact Phase 10B2 Equipment/Armor object injection;
- corpse, nested contents, and worn projection reconstruction;
- strict position and corpse cross-reference failures;
- zero default item/NPC/loadout/corpse duplication;
- unchanged restored Combat, NPC-initialization, and WorldInteraction RNG
  snapshots before activation;
- Cave-active restore with a detached/frozen Outdoor retaining all five NPCs;
- unchanged NEW_GAME counts and dynamic allocator sequence.

The implementation-pass focused execution evaluated 4,077 assertions. The
formal audit supersedes that historical count; see
`PHASE_10B3_FORMAL_AUDIT.md` for the final focused and complete-suite evidence.

Godot 4.7.2 live validation used the real project and game helper. NEW_GAME
showed one attached Outdoor resident and accepted real movement input. RESTORE
showed a live, non-stale, advancing framebuffer; exact initial 13-item/five-NPC/
one-corpse state; the saved Outdoor and Player/corpse positions; a detached
Cave; and unchanged saved RNG states. After QA activation, normal aggression,
combat, death lifecycle, allocator continuation, and corpse creation remained
usable. This is runtime candidate proof only, not process-A/process-B proof.

## Deferred to Phase 10B4 or later

- save eligibility and combat/busy/guarding/transition blockers;
- repository-triggered live Save/Load;
- transactional replacement of the current Session;
- preserving the current Session on failed swap/commit;
- actual process-A/process-B restart acceptance;
- Continue/New Game/Save UI, slots, autosave, and mobile lifecycle behavior.

No `DECISIONS.md` entry is required: this phase makes no new LPC gameplay
substitution or compatibility choice.

The implementation pass ended **READY FOR FORMAL AUDIT**. Formal closure is
recorded separately in `PHASE_10B3_FORMAL_AUDIT.md`.
