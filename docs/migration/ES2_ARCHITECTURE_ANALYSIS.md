# ES2 Architecture Analysis for the Godot Migration

## Purpose and evidence boundary

This document is the first formal architecture analysis for migrating Eastern Stories / ES2 from LPC to a native Godot RPG. It describes gameplay semantics found in the original mudlib; it is not a proposal to reproduce the LPC object model or the MudOS/FluffOS runtime.

The authoritative source examined was `reference/es2/mudlib/`. Unless a path starts with `reference/`, all LPC paths in this document are relative to that directory. Conclusions below come from directory-wide file, inheritance, and reference searches plus direct reading of the representative files listed in [Source coverage](#source-coverage). The authored world is too large (more than one thousand files under `d/`) for every content object to have been read line by line in this pass. Claims about specific behavior therefore cite files read directly; aggregate observations are identified as structural scans.

## Executive summary

ES2 is organized as an object-oriented LPC mudlib with four overlapping layers:

1. MudOS/FluffOS supplies the object lifecycle, inheritance, driver callbacks, command parser hooks, containment model, timers, serialization, security identities, and networking.
2. Small `feature/` mixins supply reusable behavior such as property storage, movement/encumbrance, combat participation, damage, skills, conditions, equipment, finance, apprenticeship, teams, and saving.
3. Standard objects in `std/` compose those features into characters, NPCs, rooms, items, equipment, weapons, armor, and skill daemons.
4. Authored objects in `d/`, `daemon/`, `quest/`, and parts of `obj/` specialize the standards with world content, NPC stats and scripts, martial arts, special actions, conditions, items, shops, factions, and quests.

The central architectural fact is that gameplay rules do not live in a single layer. A combat hit, for example, spans `feature/attack.c`, `adm/daemons/combatd.c`, `feature/damage.c`, character properties, enabled skill daemons, weapon definitions, condition state, and command initiation. Similarly, learning spans character skill state, skill daemons, teacher NPCs, family relationships, and multiple commands. The Godot migration should regroup these rules into cohesive typed domain systems while preserving the original formulas and state transitions.

The most suitable first subsystem is **character state and derived attributes**, implemented first as a pure, typed, serializable domain model with legacy property-name migration metadata. Nearly every later rule depends on its vocabulary (`gin/kee/sen`, effective and maximum values, attributes, internal resources, experience, potential, skills, family and flags), but it can be specified and tested without scenes, animation, command parsing, or combat orchestration.

## Architectural overview

### Object composition

The mudlib uses multiple inheritance as feature composition. The most important composition roots are:

```text
MudOS/FluffOS driver
|
+-- std/char.c (CHARACTER)
|   +-- feature/action.c
|   +-- feature/alias.c
|   +-- feature/apprentice.c
|   +-- feature/attack.c
|   +-- feature/attribute.c
|   +-- feature/command.c
|   +-- feature/condition.c
|   +-- feature/damage.c
|   +-- feature/dbase.c -> feature/treemap.c
|   +-- feature/edit.c
|   +-- feature/finance.c
|   +-- feature/message.c
|   +-- feature/more.c
|   +-- feature/move.c
|   +-- feature/name.c
|   +-- feature/skill.c
|   `-- feature/team.c
|       |
|       +-- std/char/npc.c (NPC) + feature/clean_up.c
|       |   `-- authored NPCs and class masters
|       `-- obj/user.c + feature/autoload.c + feature/save.c
|
+-- std/room.c (ROOM)
|   +-- feature/dbase.c
|   `-- feature/clean_up.c
|       `-- authored rooms and specialized bank/guild/hockshop rooms
|
+-- std/item.c (ITEM)
|   +-- feature/clean_up.c
|   +-- feature/dbase.c
|   +-- feature/move.c
|   `-- feature/name.c
|       `-- std/equip.c + feature/equip.c
|           +-- weapon types
|           `-- armor slot types
|
+-- std/item/combined.c (COMBINED_ITEM)
|   +-- feature/clean_up.c
|   +-- feature/dbase.c
|   +-- feature/move.c
|   `-- feature/name.c
|       +-- money stacks
|       +-- medicine stacks
|       `-- throwing-weapon stacks
|
`-- std/skill.c (SKILL)
    `-- std/force.c (FORCE)
        `-- authored skill daemons and special-action dispatchers
```

Sources: `include/globals.h`, `std/char.c`, `std/char/npc.c`, `obj/user.c`, `std/room.c`, `std/item.c`, `std/item/combined.c`, `std/equip.c`, `std/skill.c`, `std/force.c`.

This inheritance graph should not be copied into Godot. Much of it exists to work with LPC cloning, driver hooks, and permissive dynamic property lookup. Godot-side composition should instead follow domain responsibilities: character state, combatant state, progression, inventory, equipment, conditions, faction membership, and world placement.

### Dynamic property database

Most authored state is stored in a nested mapping accessed by slash-delimited string keys through `set()`, `query()`, `add()`, and corresponding temporary variants. `feature/dbase.c` delegates tree traversal to `feature/treemap.c`. Persistent `dbase` and nonpersistent `tmp_dbase` are intentionally separate. A `default_ob` provides prototype-like fallback values and is heavily used by cloned items.

This mechanism mixes several kinds of information:

- durable character state, such as `combat_exp`, `potential`, `family`, `marks`, current resources, and authored flags;
- authored definition data, such as names, descriptions, stats, exits, objects, item properties, skill actions, and inquiries;
- transient runtime state, such as equipped object references under `armor/*`, `weapon`, `last_damage_from`, guarding, pending interactions, and combat modifiers under `apply/*`;
- executable function values, such as action selectors, inquiry callbacks, chat callbacks, and item descriptions.

Sources: `feature/dbase.c`, `feature/treemap.c`, `adm/daemons/race/human.c`, `std/weapon/sword.c`, `daemon/class/swordsman/master.c`, `d/city/eastdoor1.c`.

Recommended Godot equivalent: replace stringly typed property trees with explicit typed state and definition types. Preserve original property names only in import metadata and save migration adapters. Do not expose a universal `query("path")` API as the primary game architecture.

## Classification of the original mudlib

### 1. MudOS / FluffOS runtime infrastructure — do not port directly

The following exist primarily because ES2 runs inside an LPC driver:

- object cloning/loading and lookup: `new()`, `clonep()`, `find_object()`, `load_object()`, `children()`, `call_other()`;
- object containment as both inventory and location: `environment()`, `all_inventory()`, `present()`, `move_object()`;
- driver lifecycle callbacks: `create()`, `setup()`, `init()`, `reset()`, `heart_beat()`, `clean_up()`, `net_dead()`;
- driver command machinery: `enable_commands()`, `add_action()`, `query_verb()`, `command()`, `input_to()`;
- timers and deferred execution: `call_out()`, `remove_call_out()`, function pointers stored in mappings;
- save-file serialization: `save_object()`, `restore_object()`, `__SAVE_EXTENSION__`;
- UID/eUID, wizard privilege, master object, simul-efuns, runtime config, telnet, sockets, intermud, FTP, login sessions, profiling, and wizard commands.

Representative sources: `feature/command.c`, `feature/save.c`, `feature/action.c`, `feature/clean_up.c`, `adm/obj/master.c`, `adm/obj/simul_efun.c`, `adm/daemons/cmd_d.c`, `adm/daemons/logind.c`, `adm/daemons/securityd.c`, `adm/daemons/network/`, `include/net/`, `cmds/wiz/`, `cmds/arch/`, `cmds/adm/`.

Godot replacement: scenes/resources, explicit factories and repositories, signals or typed events, `Timer` only where presentation/world timing requires it, and an application save service. Omit telnet, intermud, wizard security, UID/eUID, command-path search, and LPC compatibility.

### 2. Core game mechanics — typed GDScript system candidates

Gameplay-bearing reusable rules include:

- attributes and derived modifiers: `feature/attribute.c`;
- current/effective/maximum resource damage and recovery: `feature/damage.c`;
- combat relationships and attack selection: `feature/attack.c`;
- hit resolution, defense, wounds, rewards, and death penalties: `adm/daemons/combatd.c`;
- skills, enabled mappings, practice progress, and level thresholds: `feature/skill.c`;
- action/busy state: `feature/action.c`;
- conditions: `feature/condition.c`, `daemon/condition/`;
- encumbrance and ownership transfer rules: `feature/move.c`;
- equipment slots and modifiers: `feature/equip.c`;
- currency payment: `feature/finance.c`;
- family/apprenticeship relationships: `feature/apprentice.c`;
- teams: `feature/team.c`.

These are semantic sources, not proposed one-to-one Godot classes.

### 3. Game data / authored content — JSON or Godot Resource candidates

Good data candidates include:

- NPC identity, base attributes, skill loadouts, dialogue topics, attitude, family, carried items, and chat configurations in authored NPCs, for example `daemon/class/swordsman/master.c` and `d/canyon/npc/general.c`;
- skill action descriptions, modifiers, valid uses, costs, prerequisites, and special-action IDs, for example `daemon/skill/fonxansword.c`;
- weapon action templates in `adm/daemons/weapond.c`;
- item names, descriptions, values, weight, material, slots, modifiers, and study metadata, for example `obj/weapon/longsword.c`, `d/city/npc/obj/wuqing_sword.c`, and `d/latemoon/obj/book.c`;
- condition definitions where behavior can be expressed as periodic effects, for example `daemon/condition/snake_poison.c` and `daemon/condition/bandaged.c`;
- quest target/reward/time tables in `quest/qlist*.c`;
- room descriptions, legacy exits, spawn lists, environmental tags, doors, and authored interaction metadata in `d/`;
- day-phase table data loaded by `adm/daemons/natured.c` from `adm/etc/nature/day_phase`.

Procedural callbacks embedded in these files must be separated from their data during import.

### 4. World / room topology — reference for later RPG map conversion

`std/room.c` models a MUD room as a property container with an `exits` mapping, optional two-sided doors, an `objects` spawn table, and `valid_leave()` gates. Its `reset()` restores missing authored objects and attempts to return wandering NPCs to their start room.

The structural scan found 561 authored objects inheriting `ROOM`. Region directories under `d/` contain clusters ranging from small areas to large hubs: for example `d/city/` has 54 room objects, `d/choyin/` 62, `d/latemoon/` 74, and `d/oldpine/` 41. These counts are topology evidence, not desired scene counts.

Normal rooms are largely declarative. `d/city/street1.c`, for example, defines description, three exits, and an outdoor region tag. Special rooms mutate exits or add command-like verbs: `d/oldpine/keep2.c` closes the escape route and spawns attackers when the player moves east; `d/village/lake.c` adds paddle and dive transitions; `d/city/eastdoor1.c` gates travel on character marks and consumes a token-like mark.

Recommended Godot equivalent:

- import legacy rooms and exits into an analysis-only topology dataset;
- cluster adjacent rooms into `Region -> Map/Scene -> Zone/Interior/Portal` based on place semantics;
- convert ordinary exits to continuous walkable adjacency;
- convert meaningful boundaries, interiors, hazards, scripted transitions, and region changes into portals or interactables;
- preserve legacy room paths on maps/zones/portals as traceability metadata;
- express `valid_leave()` semantics as typed entry/interaction requirements, not movement commands.

Do not create one scene per LPC room and do not use `current_room_id` as the whole physical location.

### 5. NPC behavior and lifecycle

`std/char/npc.c` extends the full character object. It adds:

- authored item and money creation;
- acceptance rules for nonlethal fights based on attitude and three resource ratios;
- return-to-home behavior invoked by room resets;
- probabilistic idle/combat chat dispatch;
- random room movement;
- helpers that dispatch enabled spells, force functions, and martial actions.

`std/char.c::heart_beat()` calls `chat()` for non-users. Auto-aggression is initiated in `feature/attack.c::init()` when another object enters the same environment, based on killer lists, vendetta marks, attitude, and bellicosity. `std/room.c::reset()` owns replenishment and home-return behavior, so authored identity, mutable NPC state, and physical placement are entangled.

Authored NPCs commonly combine data with bespoke logic. Examples include faction-master recruitment in `daemon/class/fighter/master.c`, a combat loadout and item exchange in `d/canyon/npc/general.c`, and a multi-step courthouse escort driven by command calls and timers in `d/choyin/npc/magistra.c`.

Recommended Godot equivalent:

- `NpcDefinition`: authored identity, stats, skills, dialogue, faction, drops, and behavior profile IDs;
- `NpcRuntimeState`: health/resources, conditions, relationships, persistent flags, and respawn/death state;
- `SpawnDefinition`: map, zone, named marker, respawn policy, and schedule;
- behavior components/state machines for patrol, aggression, combat choice, dialogue, vendor, teacher, quest, and scripted sequence behavior;
- explicit encounter/respawn services rather than room `reset()`.

### 6. Combat, damage, conditions, and character state

#### Character resources and state

Characters use three parallel primary resources:

- `gin` / `eff_gin` / `max_gin`;
- `kee` / `eff_kee` / `max_kee`;
- `sen` / `eff_sen` / `max_sen`.

Normal damage reduces current values; wounds reduce effective values and clamp current values to the new effective value. Healing restores current values only up to effective values; curing restores effective values up to maxima. Negative effective values cause death, while negative current values cause unconsciousness first. Sources: `feature/damage.c`, `std/char.c`.

`heal_up()` consumes food and water, restores the three current resources using constitution plus `atman`, `force`, or `mana`, slowly repairs effective values, and regenerates the three internal resource pools from raw `magic`, `force`, and `spells` skill levels. Starvation/dehydration suppress parts of recovery. Source: `feature/damage.c`.

Race setup supplies defaults and derived maxima. Human maxima depend on age and internal resource maxima; weight depends on strength. Source: `adm/daemons/race/human.c`. Monster defaults use different age/stat curves in `adm/daemons/race/monster.c`.

#### Combat resolution

Combat is rule-driven and heartbeat-paced, not collision-driven:

1. `fight` or `kill` commands establish combat relationships. A friendly fight is consensual/accepted and normally ends when damage lands; killing records lethal intent. Sources: `cmds/std/fight.c`, `cmds/std/kill.c`, `feature/attack.c`.
2. A character heartbeat selects up to the first four opponents and asks `COMBAT_D` to fight. Source: `feature/attack.c`.
3. Courage versus opponent composure determines attacking versus guarding unless the victim is busy/unconscious. Source: `adm/daemons/combatd.c::fight()`.
4. The action comes from the enabled martial skill, weapon action, or race default. Source: `feature/attack.c::reset_action()`, `adm/daemons/combatd.c::do_attack()`.
5. Attack/defense power is approximately skill-level cubed, scaled by current `sen` versus maximum `sen`, plus combat experience. Temporary attack/defense modifiers apply. Source: `adm/daemons/combatd.c::skill_power()`.
6. Dodge is tested first using `AP/(AP+DP)` semantics; parry is tested after a failed dodge. Busy defenders have dodge and parry divided by three. Source: `adm/daemons/combatd.c::do_attack()`.
7. Base damage comes from temporary applied damage, the action, strength, enabled force, enabled martial art, weapon/monster hooks, and combat-experience defense reduction. Armor may prevent the wound portion. Source: the same function plus `std/force.c` and `adm/daemons/weapond.c`.
8. Failed attacks can trigger a guarding riposte. Hits may interrupt busy actions. Combat use can improve basic skills and combat experience under specific comparisons and random checks.

Damage description strings and combat narration are presentation data mixed into resolution logic. They should become structured outcomes (`dodged`, `parried`, `hit`, `wounded`, `damage_type`, `limb`, `riposte`, resource deltas) rendered by presentation code.

#### Death and conditions

Unconsciousness disables the character, rewards the defeater, clears enemies, and schedules revival. Death clears conditions, creates a corpse and transfers inventory, clears combat/team relationships, then sends users through a ghost/death flow while destroying NPCs. Player death also triggers experience, potential, skill, vendetta, thief, and bellicosity changes in `adm/daemons/combatd.c::killer_reward()`. Sources: `feature/damage.c`, `adm/daemons/chard.c`, `obj/corpse.c`, `adm/daemons/combatd.c`.

Conditions are a mapping from condition ID to arbitrary state. Each update dynamically invokes a daemon. The daemon mutates the character and returns flags including continue and no-heal. Examples: periodic wounds and mental damage from snake poison, constitution/force-based drunkenness, and periodic wound curing from bandages. Sources: `feature/condition.c`, `include/condition.h`, `daemon/condition/snake_poison.c`, `daemon/condition/drunk.c`, `daemon/condition/bandaged.c`.

Recommended Godot equivalent: a deterministic `CombatResolver` over typed `CombatantState`, a `DamageService`, a typed `ConditionInstance` collection updated by explicit game-time ticks, and structured combat events. Randomness must be injectable/seedable. Keep the lethal/nonlethal distinction and the three current/effective/maximum resource tracks unless a later design decision explicitly changes them.

### 7. Skills, martial arts, progression, and inner power

#### Skill state and mapping

`feature/skill.c` stores:

- raw skill levels in `skills`;
- per-skill accumulated improvement in `learned`;
- enabled special-skill mappings in `skill_map`.

Effective skill equals temporary modifiers plus half the basic skill plus the full enabled special skill. Improvement points level a skill when they exceed `(level + 1)^2`. Learning too many skills relative to base spirituality divides improvement amounts. Death normally removes one raw level from every skill and clears mappings. Source: `feature/skill.c`.

`cmds/std/enable.c` defines usage categories such as unarmed, weapon types, force, parry, dodge, magic, spells, movement, and arrays. A special skill validates which categories it can fill. Changing the enabled force, magic, or spell school resets its accumulated internal resource pool to zero.

#### Skill definitions and special actions

`std/skill.c` defines the protocol: learning/effect validation, martial versus knowledge type, level-up hooks, and file-based dispatch for exert, perform, cast, conjure, and scribe actions. `std/sserver.c` provides random offensive-target selection for special actions.

An authored martial art combines data and rules. `daemon/skill/fonxansword.c` contains action templates, prerequisites (`max_force`, required enabled force, equipped sword), compatible uses, practice resource costs, and the path to special actions. `daemon/class/swordsman/fonxansword/swordjab.c` implements a special multi-attack based on combat experience and charges effective `kee`. `daemon/skill/fonxanforce.c` routes exert functions; its heal action is implemented separately in `daemon/class/swordsman/fonxanforce/heal.c`.

#### Progression paths

The commands contain real progression rules:

- `learn`: teacher must know more; family/recognition and master restrictions apply; potential and `gin` are spent; martial learning is capped by combat experience; teacher and student intelligence affect cost (`cmds/std/learn.c`, `std/char/master.c`).
- `practice`: only an enabled special skill can be practiced; its skill-specific validation and practice logic run; basic-skill level controls improvement and whether weak-mode limits apply (`cmds/std/practice.c`).
- `selflearn`: only listed basic skills at level 40+; costs potential and `gin`; combat experience gates progress (`cmds/std/selflearn.c`).
- `study`: an inventory item supplies skill metadata; literacy, experience, skill validation, `sen`, difficulty, and maximum book level apply (`cmds/std/study.c`, `d/latemoon/obj/book.c`).
- `exercise`, `meditate`, `respirate`: convert `kee`, `sen`, or `gin` into force, mana, or atman; each has cross-resource health prerequisites and skill/stat-scaled gains; exceeding twice the maximum may grow the maximum subject to skill-based caps (`cmds/std/exercise.c`, `cmds/std/meditate.c`, `cmds/std/respirate.c`).

Recommended Godot equivalent: `SkillDefinition` resources plus a typed `SkillProgressState`, `SkillLoadout` for enabled mappings, `ProgressionService`, `TrainingService`, and data-driven `AbilityDefinition` objects with procedural effect strategies only where required. The command parser is not part of the rule.

### 8. Inventory, equipment, items, and economy

#### Ownership and encumbrance

LPC object containment represents rooms, character inventories, containers, and carried unconscious characters. `feature/move.c` recursively propagates object weight into containing objects, rejects transfers over maximum encumbrance, and automatically unequips moved equipment. This contains useful semantics but relies directly on `environment()` and driver movement.

Recommended Godot equivalent: explicit inventory/container ownership and item stack records; world pickups have separate physical representations. A transfer service validates capacity and equipment state. Do not make scene-tree parentage authoritative inventory ownership.

#### Items and stacks

`std/item.c` is a named, movable, property-bearing object. `std/item/combined.c` adds stack amount, weight scaling, automatic merging by base LPC file, and delayed destruction at zero. Money, medicine, and throwing weapons specialize this stack behavior. Sources: `std/item.c`, `std/item/combined.c`, `std/money.c`, `std/weapon/throwing.c`.

Item clone prototypes use `set_default_object(__FILE__)` so authored constant properties remain on the master object while clones store only overrides. This is an LPC memory optimization and maps naturally to immutable item definitions plus lightweight runtime instances/stacks.

#### Equipment

`feature/equip.c` supports one armor per `armor_type`, a primary weapon, an optional secondary weapon, shields, two-handed restrictions, and applied stat modifiers. Equipping weapons resets the character's action source. `include/armor.h` and `include/weapon.h` define slot/type and weapon flags. Heavy generic equipment applies dodge penalties in `std/equip.c`; concrete weapon/armor bases set categories and defaults.

Recommended Godot equivalent: an explicit equipment-slot model, item definitions containing modifier lists and weapon traits, and an equipment service that atomically validates and applies/removes modifiers. Preserve primary/secondary/two-handed/shield interactions.

#### Economy

Currency is physical stacked gold/silver/coin with base values. `feature/finance.c` sums inventory currency and requires appropriate denominations for exact payment; `std/room/bank.c` converts denominations; `feature/vendor.c` and `cmds/std/buy.c` drive NPC vendors; `std/room/hockshop.c` values, pawns, and sells items at fixed percentages.

Recommended Godot equivalent: store currency as typed denominations or a wallet domain object while preserving denomination/exact-change behavior if design review confirms it is meaningful. Vendor inventory and prices should be authored data. Buying, selling, conversion, and reward payout belong to an economy service.

### 9. Factions / families / apprenticeship

Family membership is a nested character mapping containing family name, generation, master ID/name, entry time, title, and privileges. `feature/apprentice.c` creates families, recruits one generation down, assigns titles, and tests direct apprenticeship.

The handshake is split across `cmds/std/apprentice.c` and `cmds/std/recruit.c`. NPC masters add authored acceptance gates and side effects. Examples include courage/composure requirements and class assignment for the swordsman master (`daemon/class/swordsman/master.c`), a sworn phrase and bespoke class rules for the fighter master (`daemon/class/fighter/master.c`), and gender/class/initiation requirements for the bonze master (`daemon/class/bonze/master.c`). `std/char/master.c` restricts learning after betrayal and limits non-direct disciples. `cmds/std/expell.c` removes membership, zeros score, and halves all skills. Killing one's direct master can clear the family and change betrayer state in `adm/daemons/combatd.c::killer_reward()`.

Recommended Godot equivalent:

- `FactionDefinition` and rank/title data;
- `FactionMembershipState` with lineage and mentor reference;
- declarative recruitment requirements and consequences;
- an apprenticeship/mentorship service for offers, acceptance, betrayal, expulsion, and teaching permissions;
- quest/dialogue interactions for ceremonial sequences.

Do not use NPC object identity or name equality as the long-term authoritative reference; use stable IDs while retaining original LPC IDs/names for migration traceability.

### 10. Quests, scripted events, and special room/NPC logic

There are at least two distinct content patterns.

The formal timed-kill quest system stores quest tables in `quest/qlist*.c`, selected by experience tier. Each entry supplies a display-name target, type, time, and experience/potential/score rewards. `u/cloud/npc/god.c` selects a tier using combat experience and recent completion state, stores the selected mapping and deadline directly on the player, and `adm/daemons/combatd.c::killer_reward()` completes kill quests by comparing the victim's display name and deadline. `cmds/usr/quest.c` reports the current task.

This system is gameplay-bearing but tightly coupled and fragile: completion uses display-name equality; quest mutation and rewards occur inside combat death rewards; the issuer lives under a wizard home directory; and retrieval quest code in the issuer is commented out. These facts should be preserved as evidence, not treated as a polished generic quest architecture.

Separately, authored rooms/NPCs encode localized quest-like sequences and puzzles through flags, temporary state, inventory exchange, dynamic exits, custom verbs, movement, and timers. Examples include:

- mark-gated city travel in `d/city/eastdoor1.c`;
- an ambush and temporarily sealed route in `d/oldpine/keep2.c`;
- boat and underwater transitions in `d/village/lake.c`;
- item-for-reward exchange in `d/canyon/npc/general.c`;
- a timed courthouse escort/conversation sequence in `d/choyin/npc/magistra.c`;
- an item that teaches a skill and also teleports through a custom action in `d/latemoon/obj/book.c`.

Recommended Godot equivalent: a typed quest/event state machine with stable entity/item/location IDs, explicit triggers, requirements, actions, deadlines, and reward transactions. Use reusable interaction nodes/components for doors, exchanges, hazards, escorts, and portals. One-off procedural scripts remain appropriate only when a declarative sequence cannot express the behavior clearly.

### 11. Commands whose logic represents actual gameplay rules

Commands are not all runtime plumbing. The parser and textual syntax should be removed, but the following command handlers contain rules that must be migrated into interactions/services:

| Command area | Gameplay semantics to preserve | Representative sources |
| --- | --- | --- |
| Combat initiation | no-fight zones, consensual sparring, lethal intent, NPC acceptance | `cmds/std/fight.c`, `cmds/std/kill.c`, `cmds/std/biwu.c` |
| Movement/doors | capacity/busy restrictions, leave gates, fleeing, following, two-sided door state | `cmds/std/go.c`, `cmds/std/open.c`, `cmds/std/close.c`, `std/room.c` |
| Progression | enabled skills, teacher learning, practice, self-study, books, cultivation | `cmds/std/enable.c`, `cmds/std/learn.c`, `cmds/std/practice.c`, `cmds/std/selflearn.c`, `cmds/std/study.c`, `cmds/std/exercise.c`, `cmds/std/meditate.c`, `cmds/std/respirate.c` |
| Abilities | enabled-skill dispatch, costs, targeting, improvement chances | `cmds/std/perform.c`, `cmds/std/exert.c`, `cmds/std/cast.c`, `cmds/std/conjure.c`, `cmds/std/chant.c`, `cmds/std/scribe.c` |
| Inventory/equipment | transfers, stacks, no-drop/get flags, combat delays, slot validation | `cmds/std/get.c`, `cmds/std/drop.c`, `cmds/std/give.c`, `cmds/std/put.c`, `cmds/std/wear.c`, `cmds/std/wield.c`, `cmds/std/remove.c`, `cmds/std/unwield.c` |
| Economy | affordability, exact denominations, vendor purchase | `cmds/std/buy.c`, `feature/finance.c`, `feature/vendor.c` |
| Social/faction | apprenticeship handshake, recruitment, expulsion, team formation | `cmds/std/apprentice.c`, `cmds/std/recruit.c`, `cmds/std/expell.c`, `cmds/std/team.c`, `cmds/std/follow.c` |
| Information/interactions | authored inquiry topics and callback responses | `cmds/std/ask.c` |
| Thievery | success/notice probabilities, busy/equipment modifiers, failure aggression | `cmds/std/steal.c` |

Purely communicative, terminal, wizard, file-management, network, and administration commands do not become gameplay systems.

### 12. Systems that should be redesigned for a native RPG

| LPC design | Why it exists / problem for Godot | Native RPG redesign |
| --- | --- | --- |
| One object containment graph for rooms, inventories, corpses, and carried characters | Convenient MudOS `environment()` semantics | Separate world placement, inventory ownership, container contents, and carry/rescue state |
| One room object per text location and exit command | Text MUD navigation | Cluster rooms into continuous maps/zones; portals only at meaningful boundaries |
| `heart_beat()` for combat, recovery, conditions, NPC chat, age, and idle timeout | Driver-wide periodic callback | Explicit domain turns/ticks plus world timers; unrelated clocks remain separate |
| `add_action()` custom verbs | Text parser extensibility | Context-sensitive interactables and action UI feeding domain commands |
| `call_out()` chains and stored function pointers | LPC asynchronous scripting | Signals, state machines, scheduled domain events, and Godot timers where appropriate |
| Global daemons and string paths | LPC singleton/service discovery | Explicit service dependencies and stable resource/entity IDs |
| Universal dynamic `dbase` and `tmp_dbase` | Flexible authored LPC state | Typed state/definitions plus controlled extensible flags |
| Room `reset()` spawning and recalling NPC objects | Loaded-room lifecycle | Spawn/encounter policies independent of scene loading |
| Display-name matching for quests | Easy LPC content scripting | Stable quest target IDs and typed objectives |
| Combat narration generated inside resolver | Text-first presentation | Structured outcomes rendered by UI, animation, VFX, and audio |
| Login/autoload save files | Persistent multiplayer body and cloned objects | Versioned single-player save snapshot with definition IDs and runtime instance state |

## Major daemons and responsibilities

The following daemons materially affect gameplay or content interpretation:

| Daemon | Original responsibility | Port decision / Godot equivalent |
| --- | --- | --- |
| `adm/daemons/combatd.c` | hit resolution, combat pacing choices, status narration, auto-aggression starts, death/quest rewards | Port semantics into combat, reward, and encounter services; split presentation strings |
| `adm/daemons/chard.c` | race initialization, current/effective resource initialization, encumbrance, corpse creation and inventory transfer | Split into character factory/derivation and death/drop service |
| `adm/daemons/weapond.c` | generic weapon action templates and post-hit throw/bash behavior | Weapon-action data plus effect strategies |
| `adm/daemons/race/human.c`, `adm/daemons/race/monster.c`, `adm/daemons/race/beast.c` | race defaults, limbs, stat/resource/weight formulas, default attacks | Race definitions plus character derivation rules |
| `adm/daemons/natured.c` | day phase, outdoor descriptions, game time, noon mana effect | World clock/environment system; preserve noon spell-resource rule if retained |
| `adm/daemons/rankd.c` | relationship/attitude/gender-dependent forms of address | Dialogue localization/presentation rules; only gameplay-relevant social predicates enter core |
| `adm/daemons/inquiryd.c` | inquiry parsing support called by `ask` | Dialogue/topic service, not a parser daemon |
| `adm/daemons/logind.c` | login, character creation, restore, initial attributes/items, world entry | Do not port login/network flow; extract character-creation defaults and initial spawn semantics |
| `adm/daemons/cmd_d.c` | scans command paths and resolves verbs | Omit; Godot input/action routing replaces it |
| `adm/daemons/aliasd.c`, `channeld.c`, `emoted.c`, `fingerd.c` | text-MUD aliases, channels, emotes, user lookup | Mostly omit or replace with local presentation features if later desired |
| `adm/daemons/securityd.c`, `updated.c`, `profiled.c`, network daemons | wizard security, code update, profiling, network services | Omit from gameplay migration |
| `adm/daemons/virtuald.c` | placeholder virtual-object compiler returning no object | Omit |
| `daemon/skill/*.c` | authored skill definitions and hooks | Import into skill/ability definitions plus typed effect logic |
| `daemon/condition/*.c` | condition tick behavior | Condition definitions/effect handlers |
| `daemon/class/*` | faction masters, class items, and special actions | Authored faction/NPC/item/ability data plus selected procedural rules |

`include/globals.h` is the path registry connecting these layers. It is important for understanding dependencies, but the path macros themselves should not be recreated as a Godot service locator.

## Core character architecture

The full LPC character is a large aggregate whose public API emerges from sixteen feature parents. Setup performs race derivation through `CHAR_D`, initializes resources and capacity, resets the action source, enables commands, starts the heartbeat, and assigns command paths. Source: `std/char.c`, `adm/daemons/chard.c`, `feature/command.c`.

Recommended Godot decomposition:

- `CharacterDefinition`: stable identity defaults, race, authored base stats, NPC profile reference;
- `CharacterState`: durable attributes, resources, progression, faction, flags, reputation, age/playtime;
- `CombatantState`: current/effective/max tracks, combat resources, intent, opponents, guarding/busy state;
- `SkillProgressState` and `SkillLoadout`;
- `InventoryState` and `EquipmentState`;
- `ConditionState`;
- `RelationshipState` for family, mentor, vendettas, and selected social state;
- pure services for derivation and state transitions;
- a world-facing character controller that owns movement/animation but is not authoritative for rules.

Avoid a single `Dictionary` that recreates the entire LPC dbase. Some flexible world/quest flags will still be needed, but they should live in a namespaced, schema-controlled flag store.

## Room and world architecture

Legacy room files provide four valuable inputs:

1. topology: which places are adjacent;
2. authored place identity: names and descriptions;
3. population and object placement: `objects` mappings;
4. special rules: doors, gates, resources, no-fight/outdoor tags, scripted transitions, and custom interactions.

They do not supply physical scale, collision geometry, or a suitable RPG scene boundary. A later world-analysis pass should build a graph from `exits`, annotate special transitions, and propose map clusters region by region. The `d/` directory names are useful initial region candidates, but nested directories sometimes represent buildings, subareas, item/NPC organization, or author organization rather than guaranteed map boundaries.

## NPC architecture

NPC definitions frequently set the same fields as player characters and call the same combat/skill methods. This supports semantic parity: NPCs and players should use the same authoritative combat, damage, condition, skill, inventory, and equipment rules. The physical NPC scene should be an adapter over domain state, not a separate rules implementation.

At the same time, not every NPC needs persistent state. The migration should distinguish unique/story NPCs, respawning encounter NPCs, ambient NPCs, summoned/temporary entities, and corpses/undead transformations. Evidence for these lifecycle types appears in `std/room.c`, `std/char/npc.c`, `feature/damage.c`, `adm/daemons/chard.c`, `obj/corpse.c`, and `daemon/class/taoist/necromancy/animate.c`.

## Combat architecture

The original combat resolver is centralized enough to preserve formulas but has several cross-cutting hooks:

- action selection can call skill or weapon functions stored as properties;
- enabled force, enabled martial art, weapon, and monster may each modify a hit;
- weapon post-actions can consume a stack or disarm/break an opponent's weapon;
- conditions and busy actions affect pacing and survivability;
- death reward code also owns quest completion and family betrayal consequences.

The Godot resolver should define ordered extension points matching the original ordering, because reordering force, martial, weapon, armor, and experience adjustments can change results. Quest completion, faction consequences, drops, and presentation should subscribe to a resolved death event rather than live inside hit resolution.

## Skill architecture

The LPC skill protocol conflates four concerns: definition metadata, compatibility/prerequisites, action selection, and file-path dispatch to special abilities. The migration should separate them while preserving the call order and calculations. Skill identifiers such as `sword`, `force`, and `fonxansword` should remain stable legacy IDs during migration.

Some base skill daemons are nearly markers (`daemon/skill/sword.c`), while specialized skills are rich rules (`daemon/skill/fonxansword.c`). This argues against one script per skill by default. Use data for action tables and common requirements; use effect implementations for genuinely unique behavior.

## Inventory and item architecture

Authored items are mostly definition data with occasional callbacks. A migration importer should initially classify each item as:

- pure definition;
- stack/currency/consumable;
- equipment/weapon/armor;
- container;
- study source;
- quest/key item;
- scripted interactable with procedural behavior.

Items should reference definitions by stable IDs. Unique mutable state—durability if introduced, remaining liquid, blood-soaked bandage uses, autoload parameters, quest state—belongs to item instances/stacks. Corpse inventory transfer should use the same transfer service as other containers but a separate decay/lifecycle policy.

## Persistence and state concepts

`obj/user.c` inherits the character plus autoload and save features. The LPC driver serializes non-static variables; static fields such as command path, temporary dbase, enemy arrays, team references, and some timers are runtime-only. `feature/autoload.c` separately serializes selected inventory objects as file path plus string parameter. On login, `adm/daemons/logind.c` restores account/body state, calls setup, reconstructs autoload items, equips starter cloth, and moves to `startroom` or a death room.

Persistent concepts observed include:

- identity and character creation fields;
- durable attributes, age/playtime, resources, experience, potential, learned points, score, morality-like counters, and behavior flags;
- skill levels/progress/mappings;
- conditions (the feature comments state they are saved);
- family lineage and betrayal;
- quest mapping, deadline, factor, and completion streak;
- marks/vendettas and numerous authored story flags;
- selected inventory via autoload rather than a general world snapshot.

Recommended Godot equivalent: a versioned save schema containing stable definition IDs and explicit runtime state. Separate player/character state, world state, unique NPC state, quest state, and inventory instances. Store absolute or remaining game-time deadlines according to desired pause behavior; do not copy real-time `time()` assumptions without design review. Provide migration adapters from legacy field names but no LPC save-object reader is required until an explicit save-import requirement exists.

## FluffOS versus Eastern Stories gameplay

| Concern | FluffOS/MudOS responsibility | Eastern Stories gameplay meaning |
| --- | --- | --- |
| Objects | clone/load/find/destruct objects | definitions and runtime entities/items/NPCs |
| Inheritance | compose LPC method sets | reusable character, item, room, skill semantics |
| Environment | containment and location | world placement, inventory ownership, containers |
| Heartbeats/callouts | schedule callbacks | combat cadence, regeneration, conditions, dialogue events, decay |
| Commands | parse verbs and search command paths | player intents and validation rules |
| Mappings/functions | dynamic data and callbacks | authored definitions, flags, effects, scripted interactions |
| Save/restore | serialize LPC variables to files | durable player/world progression |
| UID/security/network | multiplayer server operation | no required native-RPG equivalent |

The migration target is always the right-hand gameplay meaning, implemented with Godot-native constructs.

## Recommended Godot-side subsystem mapping

| Original subsystem | Recommended native equivalent |
| --- | --- |
| `dbase`/`tmp_dbase` | typed definitions and state; scoped flag store for open-ended authored flags |
| character feature aggregate | composed domain state plus pure services |
| race daemons | race definitions and derivation policy |
| `combatd` + attack/damage features | deterministic combat resolver, damage service, combat events |
| conditions | typed condition instances and tick/effect registry |
| skill feature/daemons/commands | skill definitions, progress/loadout state, progression/training/ability services |
| item/equip/move features | item definitions/instances, inventory transfer service, equipment service |
| finance/vendor/bank/hockshop | wallet/economy service and vendor definitions |
| family/apprentice/master commands | faction definitions, membership state, mentorship service, recruitment interactions |
| room graph and `go` | topology import data, clustered Godot maps/zones/portals, native movement |
| room reset and NPC return home | spawn/encounter policies and NPC behavior state machines |
| inquiries/custom actions | dialogue and interaction graph with procedural effect hooks |
| quest tables and kill rewards | quest definitions/state machine, objective event listeners, reward service |
| user/save/autoload/login | character creation flow and versioned application save service |
| nature daemon | world clock and environmental rule service |

## Migration risks and tightly coupled areas

1. **Stringly typed shared state.** The same property tree holds definitions, persistent state, temporary object references, executable callbacks, and arbitrary story flags. Missing or misspelled keys silently become zero in many formulas. A typed migration needs a field inventory before changing semantics. Sources: `feature/dbase.c`, authored files throughout `d/`.

2. **Rules split across commands and objects.** A filename-based classification would miss rules in commands (`learn`, `exercise`, `steal`, `go`) and authored NPC/room callbacks. Each migrated feature needs dependency tracing. Sources: `cmds/std/`, `d/`, `daemon/class/`.

3. **Combat extension order.** Force, martial skill, weapon/monster, armor, experience, post-action, riposte, progression, and death rewards are order-sensitive. Source: `adm/daemons/combatd.c`.

4. **Persistent versus temporary ambiguity.** LPC `static` fields and `tmp_dbase` are not saved, while arbitrary dbase flags are. Some gameplay sequences rely on temporary pending state and callouts. Sources: `feature/dbase.c`, `obj/user.c`, `cmds/std/apprentice.c`, `d/choyin/npc/magistra.c`.

5. **Location and ownership are conflated.** `environment()` means room, inventory owner, container, corpse, or carried body depending on context. Source: `feature/move.c`, `feature/damage.c`, `adm/daemons/chard.c`.

6. **Authored content embeds code.** Mappings can contain closures, and rooms/items/NPCs add arbitrary verbs. Automated extraction will require a procedural-content exception list. Sources: `daemon/class/swordsman/master.c`, `d/city/eastdoor1.c`, `d/latemoon/obj/book.c`.

7. **Identity uses paths, display names, and runtime objects.** Quests compare names, skills derive daemon paths from IDs, family checks IDs plus names, and item stacks merge by LPC base path. These need stable IDs and traceability aliases. Sources: `globals.h`, `feature/apprentice.c`, `feature/skill.c`, `std/item/combined.c`, `adm/daemons/combatd.c`.

8. **Real-time/server assumptions.** Age, quest deadlines, idle timeouts, day phases, respawn/reset, decay, and recovery use server time, heartbeats, or callouts. A pauseable single-player RPG needs explicit time domains. Sources: `obj/user.c`, `std/char.c`, `adm/daemons/natured.c`, `obj/corpse.c`, `u/cloud/npc/god.c`.

9. **Legacy inconsistencies and apparent defects.** Examples observed include `d/village/lake.c::valid_leave()` recursively calling itself, a duplicated condition in `d/canyon/npc/general.c::accept_object()`, inconsistent property spellings such as `apprentice_availavble`, and condition calls such as `receive_healing()` not present in the inspected damage feature. These should be logged and resolved through behavior tests/design decisions rather than blindly reproduced or silently fixed.

10. **Multiplayer-era rules may need an explicit product decision.** Player-versus-player consent, online teachers, teams, link-dead behavior, and exact command timing have semantics beyond presentation. Network/runtime mechanics can be omitted, but any retained gameplay effect must be deliberately translated. Sources: `cmds/std/fight.c`, `cmds/std/learn.c`, `feature/team.c`, `obj/user.c`.

## Proposed migration order

1. **Legacy schema and character state.** Catalogue stable IDs and typed fields; implement no gameplay yet beyond value objects, validation, and serialization contracts.
2. **Derived attributes, resources, damage, healing, and conditions.** These provide testable state transitions without world scenes.
3. **Skill definitions, skill progress, mappings, and cultivation/training.** Preserve formulas and prerequisites with deterministic tests.
4. **Item definitions, stacks, inventory, equipment, and currency.** Establish stable content IDs and modifier handling before combat equipment integration.
5. **Combat resolver.** Port attack/dodge/parry/damage ordering with injected randomness and structured outcomes; add death/reward events without presentation.
6. **Faction/family/apprenticeship and teaching permissions.** Build on character and skill state.
7. **NPC definitions/runtime state and reusable behavior profiles.** Keep placement separate.
8. **Quest/event framework.** Consume combat, inventory, faction, and world events through stable IDs.
9. **Legacy topology extraction and region-by-region map design.** Cluster rooms into physical maps/zones/portals before scene production.
10. **Godot world runtime and presentation integration.** Native movement, interactions, scenes, UI, animation, audio, and effects consume authoritative domain results.
11. **Content migration in vertical slices.** Migrate one coherent starting region with its NPCs, items, faction/skills, and quests, then expand with validation tooling.

## Proposed Phase 1 scope — analysis/design only

Phase 1 should define the **typed character-state foundation and legacy schema catalogue**, without implementing combat, scenes, commands, NPC behavior, or authored content.

Deliverables for that future phase should be:

- a field catalogue for base attributes, current/effective/max `gin/kee/sen`, force/mana/atman, experience/potential/learned points, age, carrying capacity, skill state, faction membership, conditions, and scoped flags;
- stable legacy-ID conventions for skills, items, NPCs, rooms, factions, conditions, and quests;
- typed value/state design and versioned save-schema design;
- documented derived-value formulas from `feature/attribute.c`, `adm/daemons/race/human.c`, `adm/daemons/race/monster.c`, and `adm/daemons/chard.c`;
- test vectors captured from the LPC formulas, including boundary ages and resource clamping;
- a decision log for ambiguous fields and observed legacy defects;
- no scene, map, UI, or combat implementation.

This scope minimizes rework because combat, skills, equipment, factions, quests, NPCs, and persistence all depend on a precise character-state vocabulary.

## Source coverage

### Directory-wide structural scans

The pass inventoried files and searched inheritance, includes, daemon references, exits, spawn tables, special hooks, conditions, quest keys, and command usage across:

- `reference/es2/mudlib/std/`
- `reference/es2/mudlib/feature/`
- `reference/es2/mudlib/include/`
- `reference/es2/mudlib/daemon/`
- `reference/es2/mudlib/cmds/`
- `reference/es2/mudlib/d/`
- `reference/es2/mudlib/adm/`
- `reference/es2/mudlib/obj/`
- `reference/es2/mudlib/quest/`
- targeted `reference/es2/mudlib/u/cloud/` quest references

The scan found 561 `ROOM`, 307 `NPC`, 134 `ITEM`, 108 `SKILL`, 36 `EQUIP`, and numerous weapon/armor-derived authored objects. These are inheritance occurrences, not necessarily unique gameplay definitions or migration targets.

### Files read directly

The following representative sources were read in full or, for the large combat daemon and quest issuer, in complete relevant chunks:

- root/readmes and headers: `mudlib/README`, `std/README`, `feature/README`, `include/README`, `obj/README`, `adm/README`, `include/globals.h`, `mudlib.h`, `combat.h`, `condition.h`, `skill.h`, `room.h`, `armor.h`, `weapon.h`, `user.h`;
- character/core: `std/char.c`, `std/char/npc.c`, `std/char/master.c`, `obj/user.c`, `feature/action.c`, `apprentice.c`, `attack.c`, `attribute.c`, `condition.c`, `damage.c`, `dbase.c`, `finance.c`, `move.c`, `skill.c`, `team.c`, `treemap.c`;
- runtime/persistence support: `feature/autoload.c`, `command.c`, `save.c`;
- rooms/items/equipment: `std/room.c`, `std/item.c`, `std/item/combined.c`, `std/equip.c`, `std/money.c`, `std/room/bank.c`, `hockshop.c`, `class_guild.c`, `std/weapon/sword.c`, `_sword.c`, `throwing.c`, `std/armor/armor.c`, `shield.c`;
- skill bases and examples: `std/skill.c`, `std/force.c`, `std/sserver.c`, `daemon/skill/sword.c`, `daemon/skill/dodge.c`, `daemon/skill/force.c`, `daemon/skill/fonxansword.c`, `daemon/skill/fonxanforce.c`, `daemon/class/swordsman/fonxansword/swordjab.c`, `daemon/class/swordsman/fonxanforce/heal.c`, and `daemon/class/taoist/necromancy/animate.c`;
- gameplay daemons: `adm/daemons/combatd.c`, `adm/daemons/chard.c`, `adm/daemons/weapond.c`, `adm/daemons/natured.c`, `adm/daemons/cmd_d.c`, `adm/daemons/virtuald.c`, `adm/daemons/inquiryd.c`, `adm/daemons/rankd.c`, `adm/daemons/race/human.c`, `adm/daemons/race/monster.c`, `adm/daemons/race/beast.c`, and `adm/daemons/logind.c`; daemon inventory also covered alias/channel/emote, security/update/profile, and network categories;
- driver infrastructure: `feature/clean_up.c`, `adm/obj/master.c`, and `adm/obj/simul_efun.c`;
- conditions/death: `daemon/condition/poison.c`, `snake_poison.c`, `drunk.c`, `bandaged.c`, `obj/corpse.c`, `obj/bandage.c`, `obj/drug/snake_drug.c`;
- faction NPCs: `daemon/class/swordsman/master.c`, `daemon/class/fighter/master.c`, `daemon/class/bonze/master.c`;
- commands: `cmds/std/abandon.c`, `apprentice.c`, `ask.c`, `buy.c`, `close.c`, `drop.c`, `enable.c`, `exercise.c`, `expell.c`, `exert.c`, `fight.c`, `get.c`, `give.c`, `go.c`, `kill.c`, `learn.c`, `meditate.c`, `open.c`, `perform.c`, `practice.c`, `recruit.c`, `respirate.c`, `selflearn.c`, `steal.c`, `study.c`, `team.c`, `wear.c`, `wield.c`, `suicide.c`, and `cmds/usr/quest.c`;
- world/NPC examples: `d/city/street1.c`, `d/city/eastdoor1.c`, `d/oldpine/keep2.c`, `d/village/lake.c`, `d/canyon/npc/general.c`, `d/choyin/npc/magistra.c`;
- authored item examples: `obj/weapon/longsword.c`, `d/city/npc/obj/wuqing_sword.c`, `d/latemoon/obj/book.c`, `obj/money/coin.c`;
- quests: `quest/qlist1000.c`, aggregate searches across all `quest/qlist*.c`, `u/cloud/npc/god.c`, and completion logic in `adm/daemons/combatd.c`.

## Final recommendation

The single first subsystem to port should be **typed character state and derived attributes**. It is the dependency root for damage, combat, skills, cultivation, equipment modifiers, factions, quests, NPC parity, and saves; it can be validated against small, explicit LPC formulas; and it establishes the boundary that prevents the Godot project from recreating ES2's universal dynamic property database.
