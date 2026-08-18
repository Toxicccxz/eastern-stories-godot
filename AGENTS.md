# AGENTS.md

## Mission

Rebuild classic Eastern Stories / ES2 as a **native Godot RPG**.

This is not a graphical shell around a MUD client. Preserve the original game's meaningful mechanics, rules, data, progression, NPCs, skills, factions, items, quests, and world content while rebuilding maps, movement, scene transitions, interaction, and presentation as a real RPG.

## Authoritative Source

* `reference/es2/` contains the original ES2 LPC mudlib and is the authoritative behavioral reference for legacy mechanics.
* Treat legacy source as read-only unless the user explicitly asks to change it.
* Read the relevant LPC source and inherited behavior before porting a mechanic.
* Preserve gameplay semantics, formulas, conditions, state transitions, and meaningful content.
* When behavior is ambiguous, prefer the original LPC implementation over assumptions.
* Keep legacy source paths or IDs as migration metadata when useful for traceability.
* Do **not** use external ports or reimplementations, including Flutter/Dart versions, as implementation sources unless the user explicitly asks.

## Core Migration Rule

**Translate game semantics, not the LPC runtime.**

Classify legacy code before porting:

1. **Data/content** → JSON or Godot Resources.
2. **Game rules** → typed GDScript systems/domain objects.
3. **MudOS/FluffOS infrastructure** → replace with Godot-native behavior or omit.

Do not build:

* an LPC interpreter;
* a general FluffOS compatibility layer;
* Telnet/socket infrastructure;
* wizard/euid/security systems;
* login/server daemons unrelated to actual game mechanics.

Examples:

* `call_out()` → Godot timer/event behavior.
* `heart_beat()` → explicit system ticks/events, not an emulated MUD heartbeat.
* `environment()` → the appropriate new location, inventory, ownership, or scene relation.
* LPC inheritance/mixins → understand the behavior; do not mechanically reproduce the old inheritance tree.

## Technology

* Godot 4.x.
* Modern typed GDScript.
* Prefer Godot-native APIs.
* Prefer composition over deep inheritance.
* Use pure domain classes/`RefCounted` for game logic when possible.
* Use `Resource` for authored reusable definitions when editor integration adds value.
* Use `Node` only when scene-tree lifecycle, signals, timers, physics, rendering, or editor integration are needed.
* Avoid broad global state. Use Autoload only for genuinely global lifecycle services.
* Do not add third-party dependencies without a concrete need.

## Architectural Boundary

### Game Core owns authoritative rules/state

Examples:

* player/character state and progression;
* combat, damage, skills, martial arts;
* inner power/cultivation;
* conditions/status effects;
* inventory/equipment;
* NPC definitions and persistent state;
* factions/families/apprenticeship;
* quests/world flags;
* economy/drops;
* save-state data.

Game Core must not depend on sprite positions, TileMap coordinates, camera state, animations, or presentation timing.

### World Runtime owns physical RPG embodiment

Examples:

* maps/scenes;
* continuous movement;
* collision/navigation;
* NPC instances/spawn points;
* interactable objects;
* zones;
* portals;
* scene/map transitions.

### Presentation owns visual/audio feedback

Examples:

* UI/dialogue;
* animations;
* VFX/audio;
* camera effects;
* floating combat text.

Presentation reacts to game results. It is not authoritative game state.

## World Model

Do **not** port the original flat `room_id -> exit -> room_id` graph as the physical RPG world.

Use:

`World -> Region -> Map/Scene -> Zone/Interior/Portal -> Physical Position`

Definitions:

* **Region**: broad world grouping.
* **Map/Scene**: a continuously traversable RPG space such as a town, countryside, dungeon, palace grounds, or large building.
* **Zone**: a logical area inside a continuous map.
* **Interior**: indoor space; small interiors may stay in the parent scene, substantial interiors may be separate scenes.
* **Portal**: transition between separate maps/scenes with a named target spawn.
* **Spawn point**: named entry or NPC placement position.

Prefer a semi-open / hub-based world. Do not default to one giant seamless scene or one scene per legacy MUD room.

## Legacy Room Conversion

Legacy rooms are **topology/content references**, not automatic Godot scenes.

When converting them:

* cluster adjacent MUD rooms into one RPG map when they represent one continuous place;
* convert meaningful subdivisions into zones when the player walks between them continuously;
* create portals only for real map/scene transitions;
* preserve meaningful doors, locks, hazards, quest gates, and scripted transitions;
* keep legacy room IDs as traceability metadata where useful;
* do not turn every legacy exit into a loading transition.

Typical example:

* several street rooms + town square → one town scene with multiple zones;
* town → large inn → portal to an inn scene;
* rooms inside a small inn → usually one continuous interior scene.

## Movement

Physical walking is Godot-native.

* Use `CharacterBody2D` or the appropriate Godot movement model.
* Use collision/navigation for physical traversal.
* Do not route normal walking through the original MUD directional-command system.
* Game Core decides whether entry/action is allowed because of combat, locks, quests, status, etc.
* World Runtime performs the actual movement or transition.

**Godot owns how the character moves.
Game Core owns whether game rules allow the action.**

## Location State

Do not use one `current_room_id` as the complete physical position.

Prefer state such as:

* current region ID;
* current map ID;
* current zone ID when relevant;
* physical position or named spawn;
* legacy room metadata only when needed for migrated content.

Quest/event conditions should support map, zone, proximity, interaction, and portal-entry concepts instead of relying only on legacy room IDs.

## NPCs

Separate NPC identity/state from physical placement.

Prefer:

* `NpcDefinition` for authored identity/gameplay configuration;
* runtime NPC state for mutable persistent state;
* spawn definitions/scene markers for physical placement.

Do not model NPC location only as an LPC-style object environment.

## Data-Driven Content

Prefer data definitions over one script per content object.

Good data candidates:

* regions/maps/zones and legacy room metadata;
* NPC base definitions;
* items/weapons/armor;
* skills/moves;
* factions/families;
* quests;
* shops/drops;
* status effects;
* spawn definitions.

Avoid large ID-based `if`/`match` chains when behavior can be declared as data.

Use scripts for genuinely procedural or rule-driven behavior.

## Porting Legacy Systems

For combat, skills, progression, conditions, equipment, apprenticeship, quests, NPC rules, and similar systems:

1. inspect the relevant LPC source and its dependencies;
2. identify the actual gameplay rules apart from text output/runtime calls;
3. decide what is data versus executable rule logic;
4. implement the rules as testable typed GDScript;
5. expose structured outcomes/events to the RPG presentation layer;
6. connect visuals only after the rule is working.

Do not silently redesign original mechanics.

For combat in particular, do not derive outcomes from animation collisions unless the user explicitly changes the design to action combat.

**The game rule decides what happened.
The presentation layer decides how it looks.**

## Working Discipline

* Think before coding.
* Make focused changes only.
* Do not refactor unrelated code.
* Do not add speculative features.
* Do not migrate adjacent legacy systems merely because they are nearby.
* Prefer the simplest implementation that preserves the rule and leaves a clean expansion path.
* Do not duplicate an existing system before understanding it.
* When an RPG interaction requires redesign, preserve the original gameplay intent and make the architectural change explicit.

## Testing and Verification

Rule-heavy code should be testable without loading full visual maps whenever practical.

For migrated mechanics:

* test formulas and state transitions;
* inject/seed randomness when deterministic verification helps;
* validate data IDs/references;
* test map transitions separately from movement animation;
* inspect Godot parse/editor errors after changing scripts/resources.

When Godot is available on `PATH`, use an appropriate headless load check, for example:

`godot --headless --path game --editor --quit`

If the repository adopts a dedicated test framework, use its established command.

For visual or interaction changes, run the relevant scene/project and verify behavior; a clean parse alone is not proof.

## Preferred Repository Shape

```text
/
├── AGENTS.md
├── reference/
│   └── es2/              # original LPC; reference only
├── docs/
│   ├── ARCHITECTURE.md
│   └── migration/
└── game/                 # Godot project root
    ├── core/
    ├── data/
    ├── world/
    ├── characters/
    ├── scenes/
    ├── ui/
    ├── presentation/
    └── tests/
```

Do not put the LPC mudlib under the Godot `res://` tree without a specific reason.

As the project grows, move detailed stable architecture into `docs/` and keep this root file focused.

## Completion Report

After coding, report concisely:

* files changed;
* behavior implemented/changed;
* original LPC sources consulted for migrated mechanics;
* tests/checks run and results;
* intentionally deferred work.
