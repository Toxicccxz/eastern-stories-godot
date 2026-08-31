# Phase 10B3 — Formal Audit

## Result

Phase 10B3 formally closes. A validated `GameSaveSnapshot` reconstructs a
fresh, isolated Old Pine runtime candidate without replaying New Game
initialization, consuming restore-time gameplay RNG, duplicating authored
state, or mutating a current playable Session.

The audit used Phase 10B1 `8296497`, Phase 10B2 `7784611`, and the Phase 10B3
implementation commit `7701453` as its baseline. It did not implement the
Phase 10B4 save-eligibility, repository-driven live-load, or Session-swap
transaction.

## Findings and corrections

Three concrete correctness gaps were fixed.

1. Root snapshot validation accepted contradictory committed lifecycle facts.
   It now rejects `DEAD + exists=true` and `ACTIVE/UNCONSCIOUS + exists=false`
   for both Player and NPC records. Lifecycle remains committed save state and
   is never re-derived from gin/kee/sen thresholds.
2. NPC restore required a dead tombstone to retain the complete authored
   loadout. That rejected valid worlds after corpse contents had been looted
   or destroyed. Living NPCs still require the exact authored multiset; dead
   NPCs may reference only a valid surviving authored subset. Every referenced
   item still resolves, remains globally unique, and must match authored
   definition multiplicity.
3. Player corpse age validation compared the saved value to itself. The
   current runtime's Player death context authors age `20`; restore now proves
   that value explicitly. NPC corpse age continues to resolve from its NPC
   runtime facts.

No compatibility decision or new gameplay rule was introduced, so
`DECISIONS.md` is unchanged.

## Transaction and authority audit

`OldPineWorldRestoreService.build_candidate()` remains all-or-nothing. Root,
item, Character-derived-fact, NPC-ledger, corpse, RNG, map, physical-position,
and late body/view-stage failures return typed outcomes, expose no candidate,
free staging nodes, and leave an existing Session's Player, Inventory, map,
input, position, counts, and all three RNG streams unchanged.

`NativeItemStateSnapshot` remains the sole persisted item authority.
`WorldItemInstanceIndex` is freshly derived. The restored
`SessionItemIdAllocator` retains its scope/sequence contract, and no Godot
ObjectID became durable identity. The exact `EquipmentState` and `ArmorState`
objects produced by Phase 10B2 are injected into the Player and all five NPC
runtime aggregates; no Wield/Wear/Learn/combat/recovery replay occurs.

## NPC, Character, corpse, and position proof

The NPC ledger contains exactly the five authored spawn points. Repeated
group-level `spawn_id` is allowed; `spawn_point_id` and CharacterId are the
per-slot stable identities. Missing/duplicate points, wrong NPC definitions,
wrong CharacterIds, wrong maps, invalid live loadouts, and incomplete living
loadouts fail. Alive, unconscious, and dead tombstones restore independently.
An itemless dead fat-bandit tombstone remains in the five-slot ledger,
`exists=false`, with one hidden/collision-disabled authored body and does not
respawn.

Character reconstruction was checked field-by-field for attributes, primary
and internal resources, int64/legacy-negative progression values, raw skills
before mappings, present-versus-absent mapping state, typed conditions,
family, and apprenticeship. Fresh restores preserve semantic IDs but use new
Godot object identities and do not share mutable state.

NPC and Player corpses were independently exercised. Corpse item definition,
victim, committed death/absence, world containment, worn projections, nested
contents, decay domain, and exact physical position must agree. Corpse
contents remain exclusively in the item containment graph; a fresh keyed
`CorpseView` is presentation state only. Timer, overlap cache, selection, UI,
and offline decay are not restored. `FINAL` remains representable because the
existing lifecycle may retain that partial state when final destruction does
not complete; Phase 10B4 save eligibility must decide whether such an
in-progress state may be saved.

Physical validation requires finite coordinates, the saved map, exactly the
saved zone, no ambiguous overlap at touching boundaries, and no authored
static collision using the appropriate character or corpse footprint. Wrong,
outside, boundary-ambiguous, colliding, and invalid-corpse positions return
`INVALID_PHYSICAL_POSITION`; no marker fallback or teleport occurs.

## Bootstrap, staging, residents, and activation

NEW_GAME remains one Player, 12 bootstrap item objects, five NPCs, zero
corpses, Outdoor active, with its prior RNG order. RESTORE constructs neither
starting sword, NPC factory state/loadouts, nor default corpses. Combat, NPC
initialization, and WorldInteraction RNG seed/state are exact immediately
after staging with zero restore draws.

Both Outdoor and Cave are fresh. Player `WorldLocation.map_id` is the only
active-map authority; exactly one resident is attached. The other is detached,
`PROCESS_MODE_DISABLED`, and retains its authority. Cave-active restore was
verified with a detached Outdoor still holding five NPC records, one corpse,
13 items, and allocator sequence `1`.

Before activation, Session processing, Player input/camera, map Areas
(including corpse-created Areas), aggression observation, and combat cadence
are disabled. Activation preserves the exact 13-item/one-corpse/allocator-1
authority and all RNG snapshots before ordinary opportunities execute.

The previously observed second corpse was reconfirmed as post-activation
gameplay: restored state first reported 13 items, five NPCs, one fat-bandit
corpse, allocator `1`, Player at `(-300, 400)`, corpse at `(-200, 400)`, and
unchanged RNG. Normal aggression/combat then killed the Player, allocated
`dynamic.1`, and produced 14 items, two corpses, allocator `2`. It is not a
restore duplicate.

## Verification evidence

- Focused Phase 10B3 and required regressions: **4,196 assertions passed** in
  the normal supported Windows environment. A restricted-sandbox attempt
  reproduced only the eight known Phase 10B1 `user://` filesystem denials;
  no new product failure was hidden by them.
- Canonical complete suite: run exactly once after production fixes stabilized;
  **9,829 assertions passed**.
- Python tooling: **40 tests passed**.
- Repository/static checks: passed.
- Godot 4.7.2 development headless editor: passed project parse/class scan.
- Fresh release sanitizer and `--validate-only`: passed.
- Sanitized-project Godot 4.7.2 headless editor: passed all 314 production
  class scans with no project parse/script error.
- Live NEW_GAME: helper/session/capture healthy, non-stale advancing frames,
  one attached Outdoor resident, expected bootstrap, and frame-timed real
  Player movement from `(450, 300)` to `(538, 300)`.
- Live RESTORE: helper/session/capture healthy; non-stale advancing frames;
  exact initial item/NPC/corpse counts and positions; dead fat-bandit body
  hidden with collisions disabled; Outdoor attached and Cave detached;
  exact Player Equipment/Armor object injection; unchanged restore-time RNG;
  no duplicate defaults; ordinary post-activation death/corpse allocation
  remained usable.

The Steam self-contained Godot editor emitted host-environment warnings about
its CA store, Android/ADB, and isolated editor settings. They did not produce a
project parse, script, test, or runtime failure.

## Scope and remaining work

`reference/es2/` has zero modifications. No Save eligibility, repository-driven
live Load, current-Session swap, process-restart acceptance, menu/UI, or other
Phase 10B4 behavior was added. This audit proves candidate reconstruction in
the current process only.

Status: **Phase 10B3 — FORMALLY CLOSED**.

Next gate: **Phase 10B4 — SAFE TO BEGIN**.
