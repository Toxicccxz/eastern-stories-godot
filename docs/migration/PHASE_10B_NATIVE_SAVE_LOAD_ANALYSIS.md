# Phase 10B — Native Save / Load Integration Analysis

## 1. Scope / formally closed baseline

This document defines the native process-boundary save boundary for the currently playable Old Pine
session. It is an analysis artifact only: no persistence implementation, gameplay behavior, scene,
UI, or authored content is added here.

The closed baseline is Phase 9B3 (resident Outdoor/Cave session and all currently playable traversal)
plus Phase 10A (Godot 4.7.2 build, sanitizer, and Windows/Android/iOS validation foundation). The
design preserves the closed Character, Skill, Condition, Item, Inventory, Equipment, Armor, Combined
Stack, Combat, Corpse, NPC, and World semantics.

The required product boundary is a real process boundary:

```text
process A -> mutate authoritative gameplay -> save -> process A exits
process B -> fresh executable start -> load -> equivalent authoritative gameplay
```

Scene reload, resident-map detach/reattach, an Autoload retaining object references, and in-memory
snapshot duplication do not satisfy that boundary. This phase record lives under `docs/migration/`
in accordance with the repository-wide documentation placement policy. It composes already migrated
native authorities and platform storage instead of migrating another LPC mechanic.

## 2. Existing Phase 4 native persistence foundation

Phase 4B5A already provides a typed, all-or-nothing item-domain snapshot and restorer. Its schema is
independently versioned as `NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION == 1` and preserves:

- every live `ItemInstanceId` and its `ItemDefinitionId`;
- exact current item own weight and nullable direct parent;
- combined-stack amount without merging on restore;
- per-character primary/secondary weapon instance references;
- per-character open-string armor slots and armor instance references.

`NativeItemStateValidator` validates definition resolution, duplicate identities, parent existence,
containment cycles, stack/definition agreement, direct-character ownership for equipped items,
hand conflicts, armor slot/definition agreement, and cross-character equipment conflicts before
`NativeItemStateRestorer` creates a fresh aggregate. Restore registers items first, reconstructs the
trusted containment graph second, then stacks, Equipment, and Armor. It does not replay gameplay
transfer/wield/wear operations or capacity checks.

Phase 4B5A intentionally stores exact current own weight even when an authored definition also has a
canonical weight. That is the one important exception to the general rule that immutable authored
item facts are resolved from definitions. Phase 4B5A also intentionally omits a pending zero-amount
combined-stack destruction intent; that existing decision remains authoritative.

Phase 4B5D is a one-way, validated legacy autoload importer. It is not a native save format and is
not on the normal Phase 10B read/write path. Native persistence continues to preserve the complete
represented inventory, not LPC's autoload-only subset.

## 3. Current Session/runtime ownership map

```text
OldPineWorldSessionController (session authority owner)
├── WorldPlayerRuntimeState
│   ├── CharacterState
│   ├── CombatRelationshipState
│   ├── ActionBusyState
│   ├── ArmorState
│   └── WorldLocationState
├── InventoryState / CombinedStackCollection / WorldItemInstanceIndex
├── Combat RNG / NPC-initialization RNG / WorldInteraction RNG
├── session item-ID scope
└── two resident map controllers
    ├── OldPineOutdoorController (normally attached)
    │   ├── five NpcRuntimeState objects and their bodies
    │   ├── CorpseState collection and CorpseView nodes
    │   ├── Opportunity Timer, aggression observations, HUD, Areas, camera
    │   └── map-local physical positions
    └── OldPineCavePassageController (normally detached)
        └── a distinct body bound to the same player authority
```

Exactly one resident map is a child of `ActiveMapSlot`; the other is detached and frozen but not
freed. Both share the same player, inventory, item index, ID scope, and three RNG objects. The active
map is currently duplicated in `_active_map_id` and `player.world_location().map_id`; the durable
save must keep only the latter and derive the former.

Normal `_ready()` calls `initialize_session()`. That path immediately creates new authorities, a
starting long sword, the three authored spawn groups (five NPCs), eleven NPC loadout item instances,
and all three randomized streams. Outdoor initialization then binds authored bodies and starts with
zero corpses. Restore must not run this path.

## 4. Durable-state classification matrix

The classifications are: **A** durable authority, **B** durable identity, **C** derived,
**D** reconstructed presentation, **E** ephemeral runtime, and **F** unresolved policy. This design
has no unresolved policy required to begin implementation; narrow implementation proofs are listed
in section 30.

| Runtime fact | Class | v1 rule |
| --- | --- | --- |
| Player CharacterId | B | Preserve exact stable string ID. |
| Character base attributes | A | Preserve eight base values, `force_factor`, and `bellicosity`. |
| Temporary attribute modifiers | C | Rebuild from represented providers; v1 capture rejects a nonzero unowned modifier. |
| gin/kee/sen current/effective/maximum | A | Preserve all nine integers exactly. |
| force/max_force, mana/max_mana, atman/max_atman | A | Preserve all six unrestricted integers. |
| food / water | A | Preserve exact integers. |
| gender | A | Preserve the open `StringName` value. |
| progression (combat experience, potential, spent) | A | Preserve exact integers. No current score field exists. |
| skills / learned progress / mappings | A | Preserve stable IDs and mutable per-character facts only. |
| conditions and typed payloads | A | Preserve stable ID plus exact typed payload. |
| family / apprenticeship | A | Preserve family ID/generation and master ID/name/betrayer count. |
| committed life status | A | Preserve independently of resource thresholds. |
| maximum encumbrance stored by Player/NPC runtime | A | Preserve the setup-time value; do not recalculate and silently change it. |
| NPC age and body weight | A | Preserve exact stored runtime facts; NPC randomized age must not reroll. |
| busy value / interrupt threshold | E | Not serialized; any nonzero busy state blocks save. |
| ordinary opponents | E | Not serialized; any opponent blocks save. |
| lethal markers | E | Not serialized; any marker blocks save. |
| guarding | E | Not serialized; `true` blocks save. |
| last opponent | E | Not serialized and does not by itself block an otherwise stable save. |
| Inventory graph / exact own weights | A | Embed Phase 4B5A item schema v1. |
| ItemInstanceId | B | Preserve exact value; runtime object identity is new. |
| Combined stacks | A | Reuse exact amount records; never merge during load. |
| Equipment | A | Reuse exact hand instance references. |
| Armor | A | Reuse exact open-slot instance references. |
| WorldItemInstanceIndex | C | Rebuild from restored live item records; do not save a second authority. |
| carried/aggregate encumbrance | C | Recalculate through restored Inventory containment and own weights. |
| session item-ID scope and next dynamic sequence | A | Preserve allocator continuation and validate against all restored IDs. |
| Player WorldLocation | A | Preserve region/map/zone/combat-location IDs. |
| Player physical position | A | Preserve exact map-local `x`, `y` scalars. |
| active map | C | Derive solely from Player WorldLocation map ID. |
| NPC CharacterId | B | Preserve exact spawn-slot-derived ID. |
| NPC spawn ID / spawn-point ID / definition ID | B | Preserve and resolve against current authored content. |
| NPC CharacterState | A | Same character boundary as Player. |
| NPC Inventory | A | Shared Phase 4B5A graph with NPC CharacterId endpoints. |
| NPC Equipment/Armor | A | Shared Phase 4B5A references. |
| NPC loadout item references | B | Preserve live loadout instance IDs needed by current death orchestration. |
| NPC life/existence/combat-available facts | A | Preserve explicit runtime values and validate coherence. |
| NPC WorldLocation | A | Preserve stable IDs. |
| NPC physical position | A | Preserve exact map-local coordinates, including an inactive resident map. |
| NPC aggression overlap/pending queue | E | Re-observe after activation; pending aggression blocks save. |
| CorpseState | A | Preserve all represented corpse-domain facts. |
| Corpse item contents | A | Already represented by ITEM(corpse ID) containment. |
| Corpse WorldLocation / physical position | A | Preserve stable IDs and exact map-local coordinates. |
| CorpseView | D | Recreate and bind to CorpseState after restore. |
| HUD selection / open panel / logs | E | Clear; future UI reads restored authority. |
| Camera | D | Fresh scene camera; enable only on active map. |
| opportunity/decay Timer state | E | Never serialize a Timer or fractional frame progress. |
| Area overlap caches | E | Re-observe only after restore activation. |
| Combat RNG | A | Preserve exact generator seed and state losslessly. |
| NPC initialization RNG | A | Preserve exact seed/state even though current draws are bootstrap-only. |
| WorldInteraction RNG | A | Preserve exact seed/state for Vine continuation. |
| pending map handoff | E | Never serialize; any active or committed-partial handoff blocks save. |
| pending incomplete death | E | Never serialize/replay; blocks save. |
| pending stack destruction intent | E | Omit per closed schema-v1 decision; visible represented state remains saveable. |

## 5. Player state boundary

`PlayerRuntimeSnapshot` must contain the stable CharacterId, a typed
`CharacterStateSnapshot`, committed `CharacterRuntimeLifeStatus`, `exists_in_world`,
`combat_available`, exact stored maximum encumbrance, `WorldLocationSnapshot`, and
`MapPositionSnapshot`.

`CharacterStateSnapshot` contains:

- gender;
- eight base attributes, force factor, and bellicosity;
- three primary resource tracks;
- three internal-resource pairs plus food/water;
- progression;
- skills, conditions, family, and apprenticeship.

Equipment is deliberately not duplicated inside this snapshot; the reconstructed Equipment object
for the Player CharacterId comes from the embedded item snapshot and is injected into the restored
CharacterState. Armor is similarly supplied to `WorldPlayerRuntimeState` by the item restore.

The current Player runtime has no age, mud age, age modifier, body-weight field, score, quest state,
or economy total beyond represented items. Death presentation currently uses age 20 and derives
human body weight at death time; those are current runtime rules, not hidden Player save fields.

Committed life status is durable because the runtime intentionally separates it from threshold
evidence. Load validates rather than derives it: stable ACTIVE may not already require an outer
lifecycle transition; UNCONSCIOUS must be a coherent committed state; DEAD must have
`exists_in_world == false`. A corrupt contradiction is a typed load failure.

## 6. Skill/condition/resource boundary

Skills save sorted records for every raw-level entry, every learned-progress entry, and every
enabled use-skill mapping. The lazy-map presence distinction in `CharacterSkillState` is observable
in the closed skill semantics, so the two mapping-presence booleans also survive. Restore creates raw
and learned entries before mappings and validates that a mapped target has the required raw entry.
Immutable Skill definitions and authored effects are not copied into the save. The current project
does not yet have a complete production SkillDefinition catalog: `CharacterSkillState` deliberately
accepts stable open skill IDs. v1 therefore validates nonempty IDs, uniqueness, and mapping
cross-references, preserves an unrecognized unmapped skill as inert character progress, and does not
invent a definition. Once a complete catalog exists, a later schema/migration policy may tighten
that boundary without discarding v1 data silently.

Conditions save sorted records shaped as either:

- duration: `{condition_id, payload_kind: "duration", remaining}`; or
- poison: `{condition_id, payload_kind: "poison", damage, remaining, legacy_message}`.

Only these typed payload shapes currently exist. No generic payload Dictionary or callback name is
accepted. Condition IDs are also open in `CharacterConditionState`; v1 preserves any nonempty ID
whose payload is one of the represented typed shapes. A known ID with an incompatible payload is a
strict failure. The current effect registry may intentionally have no handler for a preserved
condition; persistence preserves state and does not pretend to implement the deferred effect.

Primary and internal resource values are durable authority. Recovery and condition opportunities
are explicit runtime operations, not continuous wall-clock processes. Load starts fresh runtime
cadence boundaries without applying a tick and without consuming food/water or advancing a
condition. No offline recovery, damage, condition decrement, corpse decay, or age progression is
synthesized.

Temporary attribute modifier fields model legacy `tmp_dbase` projections and currently have no
durable provider/provenance in the playable session. They are excluded from v1. To prevent silent
state loss, capture must reject any nonzero modifier until a represented Equipment/Condition/other
provider can deterministically reconstruct it.

## 7. Item/Inventory/Equipment/Armor reuse

The root save directly composes one `NativeItemStateSnapshot` schema-v1 value. It does not create a
second inventory DTO. Capture obtains every live ID from `InventoryState.registered_item_ids()`,
resolves its immutable identity through `WorldItemInstanceIndex`, and fails if either side is
missing or contradictory. Character Equipment/Armor sources include Player and every saved NPC.

Load first uses the existing validator/restorer with a production
`NativeItemDefinitionProjections` assembled from current Old Pine immutable item content plus the
known corpse definition. Item display text, weapon damage, armor numeric modifiers, currency value,
and authored aliases/source metadata are not serialized. Exact own weight remains serialized because
schema v1 already defines it as mutable represented authority.

After restore, the exact per-character Equipment/Armor objects returned by the item domain restore
are injected into Player/NPC runtime composition. Missing per-character records are not replaced
silently. Combined stacks retain saved identities and amounts; load performs no automatic merge.

## 8. Item ID scope collision strategy

Current initial item IDs are deterministic inside a session prefix generated from a runtime object
ID, while corpse IDs use an Outdoor object ID plus a local sequence. Runtime object IDs are not
durable and may repeat in another process, so neither generator is safe after load by itself.

Phase 10B v1 introduces one session-owned allocator boundary with a durable opaque scope string and
a durable `next_dynamic_sequence`. New Game creates a fresh scope and starts the sequence once;
Load restores both without using a new Node instance ID. Authored Player/NPC loadout IDs continue to
be deterministic under the scope, while all post-bootstrap dynamic item/corpse IDs use the central
monotonic sequence. Before exposing the candidate, the allocator validates that every generated or
restored ID is unique and advances past any already used sequence value. Allocation additionally
checks `InventoryState` before committing, so malformed save data cannot create a duplicate.

This is preferable to parsing arbitrary ID suffixes as the sole authority. Existing IDs survive
unchanged; only the continuation state is centralized. Scope and sequence are ordinary stable
values, not Godot object IDs or RNG output.

## 9. NPC durable state

Each current authored spawn point gets exactly one `NpcSpawnStateSnapshot`, whether its NPC is alive
or dead. It contains spawn ID, spawn-point ID, NPC definition ID, CharacterId, explicit existence
and life status, combat availability, CharacterState snapshot, exact age/body weight/maximum
encumbrance, WorldLocation, physical position, and the live loadout instance-ID references needed by
current death-item facts.

`NpcDefinition` is resolved by ID and never serialized by value. Active NPCs must resolve all live
loadout references to saved item records. Dead NPCs retain their explicit spawn tombstone even when
their old items have been looted or destroyed; absence from a map dictionary is therefore never
interpreted as “spawn fresh.” NPC attributes/resources/skills and randomized age are reconstructed
from the save, not by `NpcCharacterStateFactory`.

All five current NPCs belong to the Outdoor resident map; Cave has none. v1 rejects an NPC record
whose authored spawn ID, spawn-point ID, definition ID, CharacterId, map, or quantity position does
not agree with current `OldPineSpawnDefinitions`.

## 10. Spawn/default initialization problem

The smallest safe bootstrap split is explicit `NEW_GAME` versus `RESTORE` mode selected before the
Session enters the SceneTree:

- `NEW_GAME` retains the current `_ready() -> initialize_session()` path and its exact draw/order,
  one Player, one starting long sword, five NPCs, eleven NPC loadout instances, zero corpses,
  starting clearing position, and active Outdoor map.
- `RESTORE` instantiates the same authored resident scenes but suppresses `_initialize_authorities()`,
  `_initialize_player()`, all `NpcCharacterStateFactory` calls, default item/loadout creation, RNG
  randomization, and ordinary activation. A restore coordinator injects already reconstructed
  authorities before binding bodies/views.

The mode is configuration, not a saved gameplay field. It must be set on the freshly instantiated
Session before `add_child()` can trigger `_ready()`. A Load must never “create defaults then overwrite
or delete them.” Regression tests must continue proving the unchanged New Game counts, identities,
locations, and RNG draw order.

There are no current authored free-standing world item spawns: production registration consists of
the Player sword, NPC loadouts, and runtime-created corpses. The current live index begins with 12
items (Player sword plus eleven NPC loadout objects). Future movable static world spawns will require
their own explicit spawn-slot/tombstone records before they may enter this schema; absence alone
would otherwise respawn a taken item.

## 11. Corpse/loot durable state

Each live, completed corpse has a `CorpseSnapshot` containing:

- stable corpse ItemInstanceId and victim CharacterId;
- victim display name, gender, and age snapshot;
- exact decay stage and maximum contents encumbrance;
- sorted open armor-slot to item-instance projections from `CorpseState`;
- WorldLocation IDs and exact map-local position.

Corpse liveness, own weight, world parent, and direct/nested contents remain in the item snapshot.
The corpse snapshot must cross-validate its item record, corpse definition, WORLD parent, victim ID,
worn item direct containment, and physical location. `CorpseView` and loot-range overlap arrays are
fresh presentation. The view is recreated only after the corpse and item graph are valid, positioned,
then wired exactly once.

Current Outdoor runtime retains initial decay intent evidence only in a lifecycle result and does
not schedule corpse decay. Therefore v1 persists the current `decay_stage`, not a Timer, call-out,
elapsed duration, or discarded intent. No decay occurs while the process is closed.

A dead NPC spawn record and its corpse are separate facts. The spawn tombstone prevents NPC
respawn; the corpse may independently be live, looted, empty, or eventually absent. A partial corpse
created by an incomplete death is not saveable.

## 12. WorldLocation + physical position

`WorldLocationSnapshot` stores region ID, map ID, zone ID, and combat-location ID separately; v1
never assumes zone and combat-location IDs are equal. IDs resolve through current Region/Map/Zone
definitions and must agree with authored containment.

Player, living/unconscious NPCs, and live corpses also store an exact map-local position:

```json
{"x": 1200.0, "y": 780.0}
```

Godot `Vector2` is encoded only at the codec boundary as two finite JSON numeric scalars. No
`"Vector2(...)"`, NodePath, Node, or transform object is accepted. JSON double precision is enough
to round-trip current Godot float coordinates. NaN and infinities are rejected.

Coordinates are gameplay authority because continuous River/Pine geography cannot be recovered from
a zone ID or a named spawn without observable teleportation. v1 uses a strict position policy: the
current map and zone must exist, the coordinate must lie in exactly the saved zone, and the relevant
body/corpse footprint must be placeable without authored collision. Missing maps/zones, out-of-bounds
coordinates, zone disagreement, or collision after a content update produce a typed
`INVALID_PHYSICAL_POSITION` load failure. There is no silent marker fallback in v1.

Current maps do not expose such a query yet. A future narrow map placement validator must inspect
authored zone/collision geometry while the candidate is disabled. This is a required Phase 10B3
implementation seam, not permission to trust arbitrary coordinates.

## 13. Resident maps / active map

The v1 session supports exactly the two current residents: `oldpine.outdoor` and `oldpine.cave`.
The authored `oldpine.keep` definition is not a resident/playable Session map and is not accepted as
the saved Player map.

Active map is derived from Player WorldLocation after validation. Both resident scenes are freshly
instantiated and bound to shared restored authorities. Only the saved active map is attached to
`ActiveMapSlot`, with exactly one controllable body and camera. The other map is detached, frozen,
and retains restored map-local NPC/corpse state. A Cave save therefore restores Outdoor state without
simulating it, then attaches only Cave; the inverse applies to Outdoor.

Map-local authority is the NPC spawn records, corpse records, and physical positions, not the map
Node. Same-map portal/zone history, previous landing marker, and last handoff result are not durable.

## 14. Presentation/Node state exclusions

The format must never serialize Node, Node2D, CharacterBody2D, Camera2D, Area2D, Timer,
CollisionShape2D, Signal, Callable, NodePath, ObjectID, WeakRef, SceneTree state, velocity, current
animation, HUD logs/selection/panels, corpse-view overlap arrays, or input state.

Fresh scenes provide physical bodies, cameras, Areas, collision, HUD, and timers. Stable CharacterId
or ItemInstanceId binds each fresh body/view to reconstructed domain authority. UI panels start
closed, selection/logs start empty, velocity starts zero, and only the saved active map camera is
enabled.

## 15. Combat relationship policy analysis

LPC `feature/attack.c` stores `enemy` and `killer` as `static` fields; LPC object save does not
persist them. `obj/user.c::net_dead()` also removes ordinary enemies before reconnect. Native
relationships are nevertheless gameplay-authoritative while active, so simply omitting them while
allowing arbitrary saves would create a combat-escape exploit.

v1 therefore persists neither ordinary opponents nor lethal markers and blocks Save if any saved
Player/NPC relationship has an opponent or lethal target. A valid loaded session creates fresh empty
relationships. Because capture only succeeds from an empty relationship graph, no relationship
cross-reference or post-load opponent availability mutation is required and no dangling CharacterId
can exist. `last_opponent_id` is selection memory only and is cleared.

**Save while fighting is blocked.** This is a native save-safety policy, not an emulation of LPC
`quit`, whose non-autoload item dropping and object destruction are not the native product model.

## 16. Busy/guarding/transient policy analysis

LPC `feature/action.c` stores integer/function busy and interrupt handlers as `static`; function
actions are intentionally outside the native typed state. v1 does not persist busy. Any
`ActionBusyState.busy_value != 0` or nonzero leftover interrupt threshold blocks Save, preventing a
save/load from skipping an ordered action.

Guarding is not durable. `guarding == true` blocks Save. Pending aggression, a nonempty aggression
queue, an active same/cross-map transition, a partial lifecycle, and a pending Cave exit request also
block Save. These are ordered orchestration facts, not restartable transactions.

After restore, relationship, busy, guarding, last-opponent, aggression queue, selected target, and
Area overlap caches are empty. Areas remain disabled during reconstruction. Once the candidate is
committed and playable, normal physics may observe current physical overlaps and request authored
aggression; it must not attack or consume RNG during restore itself.

## 17. Timer/offline-time policy

Opportunity Timer running state, `time_left`, suspended cadence remainder, frame phase, and any
future presentation timer are ephemeral. Save is already blocked while combat/busy/transition work
is active, so a successful v1 save has no combat cadence to resume. Loaded cadence starts stopped.

Save timestamp is metadata only. Wall-clock time between processes is ignored. Resources,
conditions, NPCs, corpses, and the inactive resident map are frozen exactly as captured. No LPC
heartbeat, call-out, offline recovery, starvation, condition update, age update, or corpse decay is
emulated.

## 18. RNG persistence analysis for all three streams

The three streams remain independent and each current Godot adapter owns one
`RandomNumberGenerator`. Current adapters expose seed configuration/draws but no state snapshot seam;
implementation must add a narrow typed seed/state capture and restore API without exposing the
generator object.

| Stream | Current use | v1 choice | Why fresh stream/draw count is rejected |
| --- | --- | --- | --- |
| Combat RNG | opponent choice and attack resolution | exact seed + exact internal state | Fresh RNG changes future combat; replaying draw count is slower and couples restore to every historical draw. |
| NPC initialization RNG | randomized age/attributes during authored spawn | exact seed + exact state | Existing NPCs must not reroll; preserving state keeps future post-load spawns deterministic. |
| WorldInteraction RNG | Vine branch | exact seed + exact internal state | Fresh RNG changes the next authored traversal result. |

Restore constructs a fresh adapter, assigns the saved seed, then assigns saved state, and performs
zero draws. Each record includes a stable adapter/algorithm identifier and rejects an incompatible
future adapter rather than approximating continuation.

Godot RNG seed/state are 64-bit integers. JSON numbers are not used for them. They are canonical
signed decimal strings parsed with explicit syntax and int64 range checks. For consistency and full
GDScript-int fidelity, all arbitrary gameplay integer authorities (attributes/resources/progression,
weights, stack amounts, sequence counters) use canonical decimal strings at the JSON boundary;
small schema versions and enum tags may remain bounded JSON integers. Stable gameplay IDs are
already strings.

## 19. Root save schema proposal

The root authority is one typed `GameSaveSnapshot`, not a Dictionary database or a Session Node:

```text
GameSaveSnapshot (game schema v1)
├── metadata
│   ├── format_id = "eastern-stories-native-save"
│   ├── saved_at_utc (RFC 3339 text; metadata only)
│   ├── build_commit (optional diagnostic text)
│   └── storage_profile / slot_id
├── session_kind = "oldpine"
├── item_id_allocator { scope, next_dynamic_sequence }
├── player : PlayerRuntimeSnapshot
├── npc_spawn_states[] : NpcSpawnStateSnapshot
├── corpses[] : CorpseSnapshot
├── items : NativeItemStateSnapshot (independent item schema v1)
└── rng
    ├── combat : RandomStreamSnapshot
    ├── npc_initialization : RandomStreamSnapshot
    └── world_interaction : RandomStreamSnapshot
```

Character, skill, condition, position, location, spawn, corpse, allocator, and RNG records are typed
sub-snapshots. JSON Dictionaries exist only inside the codec. Arrays use stable ID ordering. Active
map, item index, aggregate weight, runtime content projections, bodies, and views are derived or
reconstructed and do not appear as duplicate authority.

The top-level game schema version is independent of item schema version. A build commit is evidence,
not a compatibility gate. Compatibility is established by schema version plus strict resolution of
every saved item, NPC, spawn, region, map, zone, armor/weapon reference, and known condition payload
against current production definitions. Open skill/condition IDs follow the structural preservation
rules in section 6 because no complete immutable catalog currently exists.

## 20. Save format proposal

Use UTF-8 JSON with a hand-written typed codec. JSON is inspectable, cross-platform, easy to fixture,
and supports explicit schema evolution and useful field-level errors. It is preferable here to
ConfigFile (weak nested typed schema), Resource (`res://`/script-object coupling and unsafe arbitrary
resource loading), or binary Variant encoding (opaque diagnostics and temptation to deserialize
objects).

The decoder accepts only expected scalar fields and arrays, rejects unknown object-bearing data,
validates exact types/ranges, and constructs known typed snapshots. It never calls `str_to_var()` on
untrusted object text, loads a script path from save data, or instantiates an arbitrary resource.
Stable array order is a diagnostic/testing property, not gameplay behavior.

## 21. Storage/atomic-write strategy

Production storage uses one explicit release profile:

```text
user://save-data/release/default-v1.json
```

Development QA uses a separate profile:

```text
user://save-data/development/default-v1.json
```

The repository creates the exact parent directory with `DirAccess` and uses synchronous
`FileAccess`; the current world is small and does not justify threads or a database. One operation
gate rejects overlapping Save/Load requests.

The replace protocol is:

1. capture and validate a complete typed snapshot;
2. encode to UTF-8 in memory;
3. write a same-directory `default-v1.json.tmp`, flush, close;
4. reopen/decode/validate the temp file;
5. remove only the known stale `.bak` path;
6. rename current canonical to `default-v1.json.bak` if it exists;
7. rename temp to canonical;
8. if the final rename fails, attempt to restore the backup and return typed failure;
9. keep one backup after success.

This avoids overwriting the only valid bytes in place. Godot does not expose a portable directory
`fsync`, so documentation and tests must not overclaim database-grade crash atomicity. If a crash
leaves only a valid backup/temp, Load reports a typed recovery-available result; it does not silently
choose an older save. Failure to create the directory, open/write/flush/close, verify, rotate, or
rename never reports success.

v1 reads at most **16 MiB** before decoding; the current two-map state is orders of magnitude
smaller, so synchronous capture/JSON/I/O is appropriate. Oversized input is a typed failure. New
Game does not implicitly delete or overwrite the existing slot. A future explicit delete operation
may remove only the fixed canonical/temp/backup paths after user intent is supplied by Phase 10C1.

## 22. Load validation/error taxonomy

Validation is layered and stops before live authority mutation:

1. operation/path and file-size safety;
2. missing canonical file / I/O failure / invalid UTF-8;
3. malformed JSON and root shape;
4. format ID and supported game schema;
5. required field, scalar type, decimal syntax/range, finite coordinate;
6. duplicate stable IDs and cross-record identity agreement;
7. current content resolution (items, NPCs, spawns, world IDs, and known condition payloads), plus
   structural validation of open skill/condition IDs;
8. Character resource and runtime life/existence invariants;
9. complete Phase 4B5A item validation;
10. item/NPC/corpse/spawn/loadout cross-references;
11. map/zone/combat-location and position validation;
12. candidate reconstruction and final activation invariants.

Typed outcomes include at least `NO_SAVE`, `READ_FAILED`, `INVALID_UTF8`, `MALFORMED_JSON`,
`UNSUPPORTED_GAME_SCHEMA`, `MISSING_FIELD`, `INVALID_FIELD_TYPE`, `INTEGER_OUT_OF_RANGE`,
`UNKNOWN_CONTENT_ID`, `DUPLICATE_ID`, `INVALID_CHARACTER_STATE`, `INVALID_ITEM_STATE`,
`INVALID_WORLD_LOCATION`, `INVALID_PHYSICAL_POSITION`, `INCONSISTENT_SPAWN_STATE`,
`RECONSTRUCTION_FAILED`, `ACTIVATION_FAILED`, and `BACKUP_AVAILABLE`. Diagnostics identify a stable
field path/subject ID but never crash or partially claim success. v1 performs no silent content
substitution or general migration.

Save and Load layers return typed results and diagnostics only. They do not open a HUD panel, print a
popup, or decide user-facing recovery text; Phase 10C1 owns that presentation.

## 23. Restore transaction model

Load constructs a fresh candidate Session. It never mutates the current playable Session in place.
A coordinator that outlives the current Session owns the synchronous operation and a hidden,
process-disabled staging slot. The candidate is instantiated in RESTORE mode, receives freshly
reconstructed aggregates, and is validated while presentation, input, Areas, aggression, and cadence
remain disabled.

On any decode, validation, definition, item, character, map, position, or candidate-construction
failure, the candidate is freed and the current Session is untouched. Only a completely valid
candidate reaches the commit step. The old Session is retained until the new Session has attached
its one active map and passed activation invariants; a final attachment failure re-enables the old
Session and returns failure. No result may contain a hidden partial success.

This is smaller and safer than undoing default spawns, signals, corpses, Areas, and shared aggregate
mutations inside the current Session. It also gives a direct process-B bootstrap path.

## 24. Exact restore order

```text
canonical save bytes
  -> bounded UTF-8 read
  -> JSON parse (Dictionary/Array boundary only)
  -> root format + game-schema validation
  -> scalar/int64/finite-position decoding
  -> stable-ID and current-content reference validation
  -> typed immutable GameSaveSnapshot
  -> Phase 4B5A item snapshot full validation
  -> instantiate OldPine Session in RESTORE mode, process/input/Areas disabled
  -> create item definition projections from current content
  -> restore fresh ItemInstances + Inventory parent graph
  -> restore CombinedStack state
  -> restore per-character Equipment then Armor references
  -> derive fresh WorldItemInstanceIndex from live restored items
  -> restore CharacterState values (raw skills before mappings; typed conditions)
  -> inject restored Equipment/Armor and construct Player runtime
  -> construct all five authored spawn records as restored NPC runtimes or dead tombstones
     (no NpcCharacterStateFactory, no item/loadout creation, no RNG draws)
  -> restore CorpseState records and cross-check corpse containment/worn projections
  -> restore allocator scope/next sequence
  -> create three fresh RNG adapters; assign saved seed/state; draw zero times
  -> instantiate/configure both resident map scenes against shared restored authorities
  -> bind fresh Player/NPC bodies and create fresh corpse views exactly once
  -> apply saved WorldLocation and map-local coordinates
  -> validate body/corpse placement against disabled authored geometry
  -> derive active map from Player map ID; keep the other resident detached/frozen
  -> reconcile derived weights/content projections and verify empty combat/busy/aggression facts
  -> attach exactly one active map, enable its collision/Areas/camera/control, cadence stopped
  -> atomically expose candidate as current playable Session
  -> free previous Session only after successful commit
```

Neither map/view construction nor validation consumes any gameplay RNG. Post-activation Area
observations are normal new runtime opportunities, not part of restore.

## 25. Save eligibility matrix

All “allowed” rows additionally require valid character/item/world invariants, no relationship,
busy, guarding, aggression, transition, or incomplete-lifecycle blocker, and a stable end-of-event
capture opportunity.

| Situation | Result | Exact reason |
| --- | --- | --- |
| ACTIVE, idle, stable frame | SAVE ALLOWED | Normal capture boundary. |
| ACTIVE, fighting | SAVE BLOCKED | Opponents/lethal relations are intentionally not persisted. |
| ACTIVE, busy or leftover interrupt threshold | SAVE BLOCKED | Ordered action cannot be safely restarted or skipped. |
| UNCONSCIOUS | SAVE ALLOWED conditionally | Allowed only after lifecycle commit and with no remaining relationship/busy/partial blocker. |
| DEAD | SAVE ALLOWED conditionally | Allowed only after `DEATH_COMPLETE`, coherent `exists=false`, and complete corpse/item mutation. No auto-revival on load. |
| map handoff active (`_transitioning`) | SAVE BLOCKED | Source/destination ownership is unstable. |
| map handoff committed-partial | SAVE BLOCKED | No serialized handoff continuation exists. |
| same-map portal/vine method executing | SAVE BLOCKED/deferred | Save request executes only after the synchronous action returns a stable frame. |
| Cave exit request pending | SAVE BLOCKED | Deferred handoff has not committed. |
| death inventory/lifecycle incomplete | SAVE BLOCKED | Existing partial mutations cannot be replayed from the beginning. |
| pending authored aggression | SAVE BLOCKED | Restore must not serialize/replay an Area observation queue. |
| pending combined-stack destruction | SAVE ALLOWED | Existing schema-v1 decision saves visible represented amount and omits intent. |
| inventory UI open | SAVE ALLOWED | UI is not authority and reopens closed after load. |
| loot UI open | SAVE ALLOWED | Corpse/item authority is captured; selection/range/panel are cleared. |
| Cave active | SAVE ALLOWED | Active map derives from saved Player location. |
| Outdoor active | SAVE ALLOWED | Same. |

The current save request should be queued to an end-of-gameplay-event/stable-frame boundary; no
external thread can interleave capture with a synchronous transfer, portal call, or lifecycle call.

## 26. Cross-platform/user:// design

`game/project.godot` names the application `Eastern-Stories-Godot` and does not configure a custom
user directory. Godot therefore resolves `user://` to the platform-managed application-data
location on Windows, Android, and iOS. No repository, `res://`, Documents, or absolute Windows path
is used.

The sanitizer preserves the project name but removes Godot AI, tests, and the 6107 remote-debug
argument. Editor/development and sanitized release can therefore share the same underlying Godot
application namespace on one machine. The explicit `development` versus `release` storage profile
subdirectory prevents a developer save from being mistaken for packaged-build proof. The profile is
chosen by composition, not by arbitrary save-file input. The repository accepts only the fixed
default filename under its configured root and rejects path traversal.

Android/iOS app reinstall, provisional package identity, signing, cloud backup, and mobile lifecycle
autosave are outside this phase. A technical APK reinstall may erase or make application data
inaccessible; Phase 10B does not claim store-grade retention.

The JSON schema is platform-neutral and may move between supported platforms when its schema,
content references, and RNG adapter identifier match. Saved platform is therefore not required
metadata. A Godot/RNG implementation change that makes the recorded adapter identifier incompatible
fails clearly instead of producing a different random continuation.

## 27. QA/live process-restart validation design

Before Save UI exists, a development-only QA bridge under the stripped `res://tests/` boundary may
invoke the same typed Save/Load coordinator used by future UI. It may expose an explicit QA key or
command-line action, but it must not mutate gameplay state directly. The sanitizer already removes
`game/tests/` and development-only project references.

The acceptance path still uses the actual main project and real player input:

1. Process A starts the real `oldpine_world_session.tscn` with live helper evidence.
2. Real input moves across continuous geography, kills/loots/wields/wears, changes resources, and
   reaches Outdoor or Cave. No controller callback or direct position assignment substitutes for
   those gameplay actions.
3. The QA trigger requests Save only; typed success and canonical file existence are observed.
4. Process A exits completely and its OS process is confirmed gone.
5. Process B starts fresh and invokes Load before exposing a default playable Session.
6. Runtime tree, non-stale frames, authority probes, and player input prove map/position,
   Player/NPC/resource/skill/item/equipment/armor/corpse state and the next RNG outcomes.
7. Godot object IDs must differ while saved Character/Item IDs remain exact.

At least one process pair must save Outdoor with a dead NPC/corpse/loot mutation, and one must save
Cave to prove inactive Outdoor restoration. Direct coordinator tests remain useful lower-level
evidence, but are not the final process-boundary claim. A sanitized packaged executable process-pair
smoke should be added when a non-development trigger exists; final shipping/menu UX and platform
device evidence remain Phase 10C/10D.

## 28. Clean test storage strategy

Codec/repository constructors receive a typed storage profile/root rather than hardcoding the real
release path. Automated tests use only an exact isolated directory such as:

```text
user://save-data/tests/<suite-run-id>/
```

Every test creates a unique child, writes only fixed filenames inside it, and removes only that
resolved child after verifying it remains under the test root. Tests never enumerate then delete an
unvalidated broad user directory and never touch development/release default slots. Repository unit
tests cover temp/backup/rename failure through a narrow file-operation adapter; process tests use a
dedicated QA profile and clean it explicitly.

CI uses the same injected test profile in its isolated runner account. No checked-in fixture writes
to `user://`; malformed JSON fixtures may remain read-only under `res://tests/fixtures/`.

## 29. Source/new-game regression risks

Highest-risk coupling points are:

- automatic `_ready()` bootstrap consuming RNG and creating defaults before restore injection;
- Equipment/Armor object identity being split from the CharacterState that consumes it;
- dead NPCs remaining in the Outdoor `_all_npcs` ledger while being non-existent in gameplay;
- CorpseState, item containment, index metadata, view, and physical position having separate owners;
- runtime object IDs embedded in current session/corpse ID strings;
- inactive Outdoor being detached, so no physics/Area scheduling may be assumed;
- post-commit map handoff and death failures preserving real partial mutations;
- `WorldItemInstanceIndex` retaining identity metadata independently of Inventory liveness;
- character temporary modifiers lacking durable provenance;
- map geometry currently lacking a typed saved-position validation seam;
- restore accidentally consuming one of three independent RNG streams;
- editor and release sharing a Godot user-data namespace without profile separation.

New Game regression proof must retain one Player sword, five NPCs, eleven NPC loadout instances,
zero corpses, current starting location/active Outdoor, current authored equipment, and the exact
current RNG consumption order.

## 30. Unresolved decisions

No gameplay-policy decision remains unresolved for v1. The following are implementation proofs, not
license to choose different behavior:

- confirm the exact cross-platform `DirAccess` rename/replace behavior and exercise every rollback
  branch; the backup protocol above remains the required observable policy;
- add and test the narrow map placement validator required by the strict no-fallback position policy;
- add narrow read-only snapshot/restore seams for private Skill mappings, Condition payloads,
  Corpse worn/stage data, and RNG state without exposing generic Dictionaries;
- record the combat-save policy in `DECISIONS.md` when it becomes implemented behavior. This
  analysis alone does not alter the historical decision log.

There is no requirement for a general schema migration framework in v1. Unsupported schema/content
is a strict, diagnosable failure while the current Session remains playable.

## 31. Recommended Phase 10B implementation slices

All slices remain on `phase/10b-native-save-load` and culminate in one final Phase 10B PR.

1. **10B1 — Typed root/character snapshots, JSON codec, result taxonomy, and file repository.**
   Include canonical int64 strings, storage profiles, temp/backup protocol, corrupt-file tests, and
   narrow RNG state DTO seams. No Session integration.
2. **10B2 — Item composition and stable-ID continuation.** Reuse Phase 4B5A capture/restore,
   production definition projections, derived WorldItemInstanceIndex, per-character Equipment/Armor
   injection, and central session item allocator. Prove identity/collision behavior across independent
   object graphs.
3. **10B3 — NPC spawn ledger, Corpse, WorldLocation/position, and restore-mode resident maps.** Add
   strict content/cross-reference/placement validation, suppress default creation, bind fresh bodies
   and views, and prove inactive map freeze with zero RNG draws.
4. **10B4 — Save eligibility, candidate Session transaction/swap, QA bridge, and process restart.**
   Compose capture/load at stable runtime boundaries, preserve current Session on failure, prove
   Outdoor and Cave process-A/process-B scenarios, and run focused plus complete formal validation.
5. **Formal audit corrections** remain on the same branch. No separate subphase PR is created.

## 32. Formal Phase 10B future close criteria

Phase 10B implementation may close only when:

- typed capture/codec/repository/load failures are deterministic and fully tested;
- schema-v1 item state is reused rather than duplicated;
- stable Player/NPC/Item/spawn/corpse identity survives a new process;
- all three RNG streams continue from exact saved state with zero restore draws;
- New Game behavior and counts remain unchanged;
- default spawn/item/corpse duplication is impossible;
- dead authored spawns do not respawn;
- Player/NPC/corpse locations and exact valid positions survive;
- failed/corrupt/unsupported loads leave the current Session unchanged;
- active/inactive resident map ownership and freeze behavior are correct;
- every save blocker in section 25 is enforced by typed evidence;
- Nodes, UI, timers, Areas, object IDs, and Callables are absent from save data;
- automated tests use isolated storage and do not touch a developer slot;
- actual process A/process B runtime evidence proves the product boundary;
- complete Godot tests, headless editor/sanitized-project validation, static checks, and required
  Phase 10B formal audit pass before the single final PR is opened.

## 33. Explicit Phase 10C1/C2/10D deferrals

- **10C1:** Game Shell, Main Menu, Continue/New Game/Save UI, slot presentation, pause/menu UX,
  user-facing corruption/backup recovery choice, and final desktop input flow.
- **10C2:** mobile controls, responsive/safe-area UI, Android Back behavior, orientation policy,
  foreground/background lifecycle and any mobile autosave decision.
- **10D/release:** permanent Android/iOS identifiers and signing, store packaging, device retention
  claims, packaged cross-platform release acceptance, cloud/Steam/iCloud/Play save, encryption,
  anti-cheat, telemetry, and production backup/support UX.

Phase 10B remains one fixed local default slot and typed persistence API. It does not pre-implement
those product surfaces.

## Evidence inspected

Repository/production policy and architecture:

- `AGENTS.md`
- `README.md`
- `docs/production/STATUS.md`
- `docs/production/ROADMAP.md`
- `docs/production/BUILD.md`
- `docs/production/REPOSITORY_POLICY.md`
- `docs/production/GODOT_AI_DEVELOPMENT.md`
- `docs/migration/ES2_ARCHITECTURE_ANALYSIS.md`
- `docs/migration/DECISIONS.md`

Closed persistence/lifecycle/session documentation:

- `docs/migration/PHASE_4B5A_NATIVE_ITEM_SAVE_RESTORE.md`
- `docs/migration/PHASE_4B5B_ITEM_LIFECYCLE_DESTRUCTION.md`
- `docs/migration/PHASE_4B5C_DEATH_INVENTORY_CORPSE.md`
- `docs/migration/PHASE_4B5D_LEGACY_AUTOLOAD_IMPORT.md`
- `docs/migration/PHASE_6B3_OUTER_LIFECYCLE_DEATH_CORPSE.md`
- `docs/migration/PHASE_9B3B1_OLDPINE_WORLD_SESSION_MAP_LIFETIME.md`
- `docs/migration/PHASE_9B3B2_VINE_WORLD_RNG_CROSS_MAP_TRAVERSAL.md`
- `docs/migration/PHASE_9B3B3_RIVER_CLIFF_PINE_ROUTE.md`

Representative production sources directly inspected:

- character/runtime: `character_state.gd`, base/resource/internal/recovery/progression state,
  `character_skill_state.gd`, `skill_loadout.gd`, condition payload/state files, family and
  apprenticeship state, `world_player_runtime_state.gd`, `npc_runtime_state.gd`;
- items: `native_item_state_snapshot.gd`, capture/validator/restorer, `inventory_state.gd`,
  `world_item_instance_index.gd`, existing definition projections, Equipment/Armor/Combined records;
- world/session: `oldpine_world_session_controller.gd`, both resident map controllers,
  `world_character_body_2d.gd`, `map_character_runtime_state.gd`, `world_location_state.gd`, Old Pine
  world/spawn/NPC/item definitions and the Session scene;
- lifecycle: `combat_slice_lifecycle_adapter.gd`, death adapter/result, `death_inventory_service.gd`,
  `corpse_state.gd`, decay service/intent, corpse view, and relevant runtime tests;
- RNG: all three random-source interfaces and Godot adapters;
- build/storage context: `game/project.godot` and the Phase 10A release sanitizer documentation/code.

Authoritative LPC sources directly rechecked:

- `reference/es2/mudlib/feature/save.c`
- `reference/es2/mudlib/feature/autoload.c`
- `reference/es2/mudlib/feature/dbase.c`
- `reference/es2/mudlib/feature/action.c`
- `reference/es2/mudlib/feature/attack.c`
- `reference/es2/mudlib/std/item/combined.c`
- `reference/es2/mudlib/std/money.c`
- `reference/es2/mudlib/obj/money/silver.c`
- `reference/es2/mudlib/obj/user.c`
- `reference/es2/mudlib/cmds/usr/quit.c`
- `reference/es2/mudlib/std/char.c`

Existing runtime tests were read where they prove resident lifetime, default counts, corpse/loot
identity and position, partial-transition behavior, RNG isolation, and New Game reset. No live run or
full 8,719-assertion suite was needed for this analysis-only document because the initialization,
ordering, and ownership claims above are directly established by production code and already-closed
tests.
