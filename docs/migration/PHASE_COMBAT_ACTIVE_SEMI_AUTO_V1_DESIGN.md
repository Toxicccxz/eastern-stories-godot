# Combat Active Semi-Auto V1 Design

## 1. Executive Summary

CXR1 locks the first redesigned combat experience to **ES2 Active Semi-Auto**:
characters automatically conduct ordinary attacks and ordinary defense, while the player makes
important tactical decisions such as martial techniques, internal-force actions, spells, tactical
defense, battle-usable items, target selection, and flee.

The target flow is:

```text
World Exploration
  -> CombatTrigger
  -> CombatEncounter
  -> Active Semi-Auto Scheduler
  -> Existing Combat Core
  -> Semantic Combat Events
  -> Dedicated Battle Presentation
  -> CombatEncounterResult
  -> Return to the same World Session
```

This is a translation of ES2's automatic ordinary combat plus manual tactical intervention, not an
emulation of MudOS heartbeat. It is not ATB, turn-based combat, action combat, or an idle-only auto
battle. The encounter layer owns participants, sides, targets, scheduling, tactical requests, the
single queue slot, lifecycle, and completion. Existing typed Character, Skill, Equipment,
Inventory, Combat, Death, Corpse, Save, Session, and application-lifecycle authorities remain the
source of truth. Presentation consumes typed semantic facts and never decides gameplay outcomes.

This document specifies contracts only. It creates no classes, scenes, timers, controls, assets,
formulas, balance values, or test behavior.

Primary evidence is the completed
[Combat Experience Redesign Analysis](PHASE_COMBAT_EXPERIENCE_REDESIGN_ANALYSIS.md). Durable
integration constraints come from the
[Application Shell contract](../production/contracts/APPLICATION_SHELL_CONTRACT.md),
[Mobile Application contract](../production/contracts/MOBILE_APPLICATION_CONTRACT.md), and
[Native Save/Load contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md).

## 2. Owner Decisions

The following V1 decisions are locked:

- The interaction model is **ES2 Active Semi-Auto**. CXR implementation will not compare or
  prototype ATB and conventional turn-based alternatives.
- The character knows how to fight; the player makes important tactical decisions.
- Ordinary attacks, ordinary cadence, dodge/parry/guard, and ongoing ordinary progression are
  automatic.
- Martial specials, internal-force actions, spells, tactical defense, battle-usable items, target
  selection, and flee are player-triggered.
- A dedicated active encounter freezes normal world simulation and uses its own scheduler.
- V1 has exactly one visible, cancellable, replaceable queued player tactical action.
- Cooldown is not the central restriction model.
- SPAR, LETHAL, and SCRIPTED are encounter modes of one engine and one presentation.
- Active encounters remain restart-unsafe. Manual Save is blocked; V1 does not serialize them.
- Lethal NPC loot remains in the existing world corpse/inventory flow after battle.
- Temporary art must be replaceable without changing combat rules or encounter orchestration.

These owner decisions are recorded here rather than in `docs/migration/DECISIONS.md`, because CXR1
is a new product architecture specification and does not change an already implemented
LPC-to-Godot compatibility behavior.

## 3. Goals

- Preserve ES2's readable exchange of ordinary martial attacks and defenses without requiring a
  button press for every basic attack.
- Give players meaningful timing, resource, target, commitment, and escape decisions.
- Separate domain truth, encounter orchestration, and presentation.
- Reuse the already-audited combat and character authorities rather than create a second combat
  engine.
- Support collections of participants and open side IDs from the first encounter API, even when
  the first playable proof is one player against one NPC.
- Make automatic combat produce semantic actions and tactical windows rather than an unexplained
  periodic HP drain.
- Remain usable through the same semantics on desktop and mobile.
- Preserve Session, Save, lifecycle, world-location, death, corpse, and loot ownership.
- Permit placeholder presentation to evolve into a production visual language without domain
  changes.

## 4. Non-Goals

Active Semi-Auto V1 is not:

- ATB, readiness bars, speed gauges, universal turns, or action points;
- conventional turn-based combat;
- collision-driven action combat or real-time arena movement;
- click-every-basic-attack combat;
- idle-only auto battle;
- an MMO-style universal cooldown-bar system.

V1 does not require tactical pause, 2x speed, companion AI, summon gameplay, complex boss phases,
large combo trees, a full interrupt framework, auto-battle configuration, generalized auto-wimpy,
full combat rebalance, final animation/VFX/audio/UI art/icons, or final accessibility and
localization. CXR1 also does not decide exact pixel layout or presentation technology.

## 5. Legacy ES2 Semantics Being Preserved

The redesign preserves these gameplay semantics established by CXR0:

- ordinary combat proceeds automatically once relationships exist;
- ordinary fight decisions may attack, enter/continue guarding, miss, dodge, parry, hit, wound,
  progress skills, interrupt busy, and immediately riposte where the existing pipeline allows;
- learned skill, enabled/mapped combat style, ordinary auto-attack behavior, and active special
  technique are distinct concepts;
- busy occupies actor opportunities, weakens ordinary defense through existing rules, and may be
  interrupted by damage according to the existing typed policy;
- automatic guard is stateful and different from a player-requested defensive commitment;
- fight/nonlethal intent and lethal intent are distinct, including the possibility of asymmetric
  relationship facts;
- special actions may be multi-hit, control, AoE, resource/wound manipulation, temporary modifier,
  or escape behavior rather than one generic damage shape;
- lifecycle/death checks occur at the existing outer opportunity boundary, after a complete
  forward/reverse attack chain;
- death inventory, corpse, loot, and item identity remain existing authorities;
- gameplay RNG remains Session-owned and presentation consumes no gameplay draws.

The redesign deliberately does not preserve per-object `heart_beat()`, `call_out()`, room object
identity, command-string dispatch, daemon paths, dbase payloads, or textual broadcast mechanics.
Those are runtime/interface artifacts, not the gameplay contract.

## 6. Modernization Principles

1. **Domain truth decides what happened.** Animation, hitboxes, progress bars, and text cannot
   change success, damage, death, or progression.
2. **Encounter orchestration decides when a rule opportunity occurs.** It does not duplicate the
   rule formula.
3. **Presentation decides how semantic facts look and sound.** Combat log wording is derived data.
4. **Automatic does not mean opaque.** Ordinary actions emit readable starts/resolutions and leave
   visible tactical windows.
5. **Timing is encounter-local, not ATB.** There is no accumulated readiness value or global turn
   order.
6. **Existing exact authorities are injected, not copied.** Character, Inventory, Equipment,
   Armor, and RNG references remain Session-owned.
7. **Failure is honest.** Invalid tactical requests are rejected or cancelled with a typed reason;
   the system never silently substitutes an ordinary or different tactical action.
8. **Layout owns size; art fills the layout.** Asset dimensions do not define the combat API or UI
   geometry.

## 7. Architecture Overview

### 7.1 Domain truth

Domain truth remains in typed, largely Node-free systems:

- `game/core/characters/character_state.gd` and its attribute/resource/condition composition;
- `game/core/skills/character_skill_state.gd`, mappings, progression, and authored improvement
  effects;
- `game/core/cultivation/cultivation_service.gd` and existing training/learning services;
- `game/core/equipment/equipment_state.gd`, `game/core/armor/armor_state.gd`,
  `game/core/inventory/inventory_state.gd`, item identity and stack authorities;
- `game/core/combat/` math, action selection, resolver, force, progression, busy completion,
  relationship, post-action, and reverse-attack ordering;
- existing death inventory, corpse, loot, and item lifecycle services.

### 7.2 Encounter orchestration

The new layer introduces typed encounter context around those authorities:

```text
CombatTrigger
  -> validated participant bindings + sides + mode
  -> CombatEncounter
  -> scheduler opportunities / tactical requests
  -> existing typed combat services
  -> ordered CombatEvents
  -> typed completion policy
  -> CombatEncounterResult
```

It owns encounter-local transient facts but not character/resource/inventory truth.

### 7.3 Presentation

Dedicated battle presentation receives encounter projections and ordered semantic events, collects
typed player intent, and renders feedback. It can use Nodes, Controls, animations, VFX, and audio,
but contains no damage, target-validity, Save, corpse, or lifecycle authority.

## 8. Existing Combat Core Preservation Boundary

The following remain authoritative and should be reused without casual rewrites:

- `CharacterState`, base attributes, gin/kee/sen, internal resources, conditions, and thresholds;
- `CharacterSkillState`, skill mapping, progression, authored improvement effects, cultivation,
  Practice, Selflearn, and Learn;
- `EquipmentState`, `ArmorState`, `InventoryState`, item identity/index, and combined stacks;
- `CombatRelationshipState` and integer `ActionBusyState`;
- `CombatMath`, `CombatActionSelector`, `CombatAttackResolver`, standard force policy;
- combat progression, busy interruption, relationship completion, and synchronous reverse attack;
- lifecycle/death ordering, death inventory, corpse, loot, and item lifecycle;
- Session-owned combat RNG and save continuation.

Current runtime bridges are reusable but need encounter-general boundaries:

- `game/runtime/combat_slice/combat_slice_character_binding.gd` already keeps exact authority
  references; a general participant binding should preserve that property.
- `game/runtime/combat_slice/combat_slice_projection_builder.gd` and
  `combat_slice_opportunity_executor.gd` prove the ordinary opportunity pipeline; CXR4 should wrap
  or generalize it rather than place it behind a map Timer.
- `combat_slice_lifecycle_adapter.gd` and `combat_slice_death_adapter.gd` preserve audited ordering;
  encounter resolution should invoke them at the same outer boundary.
- `godot_combat_random_source.gd` remains connected to the Session-owned stream.
- `combat_slice_presenter.gd` contains useful result-to-cue precedent, but its English strings and
  direct HUD shape are not the future event/presentation contract.

The current exception is orchestration: `game/runtime/world/oldpine_outdoor_controller.gd` owns
trigger handling, `OpportunityTimer`, participant-loop scheduling, lifecycle invocation, and HUD
updates. Those responsibilities move behind encounter boundaries incrementally. The map continues
to own physical proximity, selection, interaction, and authored world trigger facts.

Current playable gaps that CXR must not mistake for the final contract are also explicit:

- `CombatSliceOpportunityExecutor.initiate_lethal_combat()` establishes reciprocal lethal intent
  only; it is preserved while CXR2 adds mode/side types, then wrapped by later trigger integration
  rather than treated as complete SPAR/asymmetric relationship support.
- the map cadence iterates its current participant array on each Timer tick; that is a validated
  slice ordering, not the new encounter scheduler API or a permanent timing value;
- lifecycle execution is called from the map loop and presentation is English log text; audited
  Core ordering stays, while ownership and event projection change;
- current Inventory/Wield/Wear interactions have no general encounter gate. CXR1 does not silently
  forbid or permit battle equipment changes; that remains an explicit later owner decision.

## 9. CombatTrigger

`CombatTrigger` is an immutable semantic request to establish an encounter. It contains only enough
data to revalidate and create encounter context:

- stable trigger/correlation ID;
- closed cause: player lethal attack, player spar/fight, NPC aggression, vendetta/hostility,
  scripted encounter, or future quest encounter;
- requested encounter mode/intent;
- initiator semantic Character ID;
- candidate participant IDs with proposed side IDs;
- source world location/encounter anchor as semantic location data;
- optional stable authored policy/encounter ID;
- narrow typed facts required by that trigger kind.

It must not contain Node/ObjectID, Area2D references, Scene paths, `Callable`, an unrestricted
Dictionary, presentation resources, or resolved mutable snapshots.

The world runtime detects the fact and submits the trigger. The coordinator re-resolves exact
Session-owned authorities and revalidates existence, life state, current location, combat
permission, and authored trigger rules. This preserves the legacy detect-then-recheck intent
without reproducing `call_out()` or room-object identity. Battle presentation never branches on
why combat started; it reads established encounter mode and semantic events.

## 10. CombatEncounter

`CombatEncounter` is the authoritative transient context for one active battle. Conceptually it
owns:

- encounter identity and accepted trigger snapshot;
- lifecycle phase such as establishing, active, resolving, completed, or failed-to-establish;
- participant collection and stable side identities;
- encounter mode and result policy identity;
- hostile relationship topology within the encounter;
- current valid target per actor where applicable;
- scheduler state required for active semi-auto opportunities;
- zero or one queued player tactical request;
- ordered semantic event sequence/cursor;
- completion fact and exactly one typed result.

Invariants:

- participant semantic IDs are unique;
- each participant has one side ID for the encounter;
- each binding resolves to the exact current Session-owned authorities;
- no CharacterState, InventoryState, EquipmentState, ArmorState, or gameplay RNG clone exists;
- current targets are absent or refer to valid participants permitted by target rules;
- no active scheduling occurs before establishment or after completion;
- completion/result is monotonic and cannot be reopened by presentation;
- at most one queued player action exists;
- presentation visibility and animation state are not encounter lifecycle truth.

The encounter is not a global singleton. One current Session may own at most one active dedicated
encounter in V1, coordinated through runtime/application ownership described below.

## 11. Participants / Sides

A participant is identified by semantic Character ID and an open stable `side_id`, plus narrow
encounter role/tags and an exact authority binding. It can represent a player or NPC now and must
not prevent allies, companions, summons, reinforcements, or multiple hostile groups later.

The model is collection-based, never fixed `player` and `enemy` fields. Sides describe encounter
alignment, not the entire world faction/diplomacy system. Hostility is an encounter relation between
sides/participants and may preserve asymmetric lethal facts where existing rules require it.

Participant status distinguishes at least present/eligible, temporarily unable to act,
unconscious, dead, fled/removed, and no longer targetable. These are encounter projections over
authoritative life/existence state, not replacements for it.

Adding/removing a participant is an explicit orchestration transition with typed events. V1 does
not require reinforcements, but the collection and event model must not require replacement to add
them later.

## 12. Encounter Modes

One encounter engine and one battle presentation support:

- **SPAR**: nonlethal intent and a non-corpse conclusion policy. Exact spar victory threshold and
  the legacy armed-friendly wound inconsistency remain later compatibility decisions.
- **LETHAL**: lethal relationship, life/death, death inventory, corpse, and return-to-world loot
  semantics remain relevant.
- **SCRIPTED**: a stable policy ID may select a narrow authored conclusion/constraint policy. This
  is an extension seam, not a generic scripting engine or arbitrary callback dispatcher.

Mode affects rule/result policy, not a separate resolver or separate BattleScene. Presentation may
label the mode but does not enforce nonlethality or create corpse outcomes.

## 13. World Freeze

When a dedicated encounter becomes active:

- normal player world movement and world combat buttons are unavailable;
- NPC roaming and unrelated NPC world simulation do not progress;
- portals, Vine, Passage, Cave exits, and world interaction transitions do not trigger;
- world physics cannot commit new gameplay transitions;
- pending world interactions are cancelled, quarantined, or held according to their existing typed
  contracts before activation;
- the world does not continue invisibly behind battle presentation;
- no elapsed-world-time or hidden physics catch-up occurs after battle.

The resident world graph remains alive and authoritative for location, NPC state, corpses, and
return. The player's source position/location is retained; encounter entry does not silently move
the world character. The encounter runs its own scheduler while world simulation is frozen.

Ownership transition:

```text
ApplicationShell
  -> persistent OldPineGameRuntimeHost (sole current-Session owner)
      -> same committed OldPineWorldSession
          -> frozen World Presentation
          -> one active CombatEncounter + Battle Presentation
          -> resolved result applied
          -> same World Presentation resumes
```

Battle presentation is not a second Session owner. CXR3 decides the concrete Host/Session scene-slot
mechanism while preserving the existing one-Host/zero-or-one-Session invariant.

## 14. Active Semi-Auto Scheduler

The scheduler is encounter-local orchestration. It creates semantic opportunities; it does not
calculate attacks or mutate presentation. It supports:

- ordinary combat opportunity;
- automatic attack/guard decision opportunity;
- committed tactical action wind-up/execution/recovery;
- integer busy advancement at the chosen opportunity boundary;
- action completion and continuation;
- later narrow NPC tactical decision opportunities.

There is no `readiness += speed`, readiness meter, universal turn order, action-point pool, or one
Timer per character. Exact cadence and durations are not fixed in CXR1.

For each opportunity the scheduler asks current encounter/domain facts what may proceed, invokes
the existing ordinary or tactical policy, records ordered semantic events, completes the full
forward/reverse chain, and only then permits the existing outer lifecycle gate. Presentation may
pace already-decided events for readability, but cannot delay or reorder domain commitment in a way
that changes outcomes.

Lifecycle pause freezes scheduler progression exactly; resume continues from the same remaining
encounter state with no wall-clock catch-up.

## 15. Ordinary Auto-Combat

The player never requests each ordinary attack. On an actor's ordinary opportunity:

1. encounter validates actor and relationship eligibility;
2. busy/commitment rules determine whether the opportunity advances busy rather than attacks;
3. a valid current hostile target is used, or target selection chooses another permitted hostile;
4. existing fight/guard logic decides attack versus automatic guarding/no action;
5. existing mapped style, weapon, action selection, resolver, force, progression, completion, and
   reverse-attack pipeline decides the outcome;
6. ordered events describe start, defense/outcome, mutations, progression-relevant feedback, and
   completion;
7. lifecycle remains at the audited outer boundary.

Learned skills do not automatically become buttons. Enabled/mapped martial and weapon facts affect
ordinary behavior only where current semantics already support them. Active specials remain explicit
registered tactical actions.

## 16. Busy / Commitment / Recovery

`ActionBusyState` remains domain truth. CXR does not delete busy or replace it with UI cooldowns.
The player-facing vocabulary is semantic:

- wind-up;
- technique/cast execution;
- committed action;
- recovery;
- hard commitment or temporarily unable to issue another tactical action.

Rules:

- martial special, internal-force, spell, tactical defense, and flee execution are busy-blocked in
  V1; battle-item eligibility/busy behavior remains part of the later item-category owner decision
  and must be explicit rather than inherited from UI behavior;
- target selection, queue cancellation, and replacing the queued request remain available while
  busy because they do not execute the tactical action;
- ordinary automatic behavior follows the existing opportunity semantics: a busy actor advances
  busy and does not make its own ordinary attack that opportunity; other eligible participants'
  automatic opportunities continue;
- existing combat math still applies busy defensive weakness and interrupt logic;
- a queued action may wait while busy/recovery remains, then is revalidated immediately before
  execution;
- presentation reads typed busy/commitment changes and availability reasons; it never decrements
  busy on animation completion;
- UI must not expose raw `Busy = 2` as the intended explanation.

CXR1 does not equate busy units to seconds or animation length and does not choose durations.

## 17. Tactical Action Model

One typed tactical request model covers categories without flattening their behavior:

- martial special / perform-equivalent;
- internal-force / exert-equivalent;
- spell / cast-equivalent;
- tactical defense;
- battle-usable item;
- flee.

A request conceptually includes actor ID, stable action/policy ID, action category, declared target
selection, and a request correlation ID. Action definitions/policies declare narrow prerequisites,
target rules, costs, and execution behavior. They are explicitly registered by stable semantic ID;
there is no daemon path, `call_other`, `Callable`, command parser, or generic apply Dictionary.

Presentation exposes a small Quick Actions area plus expandable Martial, Internal, Spell, Item,
Defense, and Flee categories. This is an information hierarchy, not a final pixel layout. The full
eligible action catalog remains reachable without putting every learned skill permanently on-screen.

## 18. One-Slot Action Queue

V1 has exactly one queue slot for the player-controlled actor.

### Request-time validation

On input, validate encounter active state, actor identity/life, action registration, target shape,
known/enabled prerequisites visible at request time, and whether the action may execute now. Then:

- executable now: accept for immediate encounter scheduling;
- valid but temporarily blocked by busy/recovery: place in the empty slot;
- another valid action selected while occupied: replace the previous slot and emit both replacement
  facts;
- invalid: reject with a typed reason and leave the existing queue unchanged unless the player
  explicitly cancels/replaces it.

### Execution-time validation

Immediately before execution, revalidate all mutable facts, including target existence/life,
weapon/mapping, resource amount, actor consciousness/life, encounter state, and action-specific
prerequisites. If invalid, cancel with an explicit typed reason. Never redirect to another target,
substitute another action, spend cost, or perform an ordinary attack as if it were the requested
action.

The queue is visible and cancellable. It contains no list, combo script, repeated macro, or hidden
second slot. Execution/cancellation is monotonic and callback duplication cannot fire it twice.

## 19. Cooldown Policy

Cooldown is not the central combat rule. Default restrictions use existing semantics:

- busy/recovery/commitment;
- resource cost;
- required weapon or equipment;
- skill and mapping prerequisites;
- actor/target condition and life state;
- target rules;
- technique-specific authored prerequisite.

A later technique may declare a narrow explicit cooldown only after gameplay justification. V1 does
not assign universal seconds, display mandatory cooldown wheels, or use cooldown as a substitute for
ES2 busy/resource rules.

## 20. Automatic vs Tactical Defense

Automatic defense is part of ordinary resolution: dodge, parry, and guard/riposte occur without a
button press for every incoming attack. Existing guarding facts remain domain state.

Tactical defense is a player-requested committed action/policy. It may later trade offensive
pressure for defense, apply a temporary typed effect, or execute an authored martial/internal
defensive technique. It is scheduled, validated, evented, and constrained like other tactical
actions.

The two concepts never share a single ambiguous `defend` flag. CXR1 deliberately does not choose
the numeric effect or whether tactical defense replaces an upcoming ordinary opportunity or layers
over it.

## 21. Enemy Telegraph

Telegraphs are semantic encounter commitments for meaningful enemy actions, not every ordinary
attack. Suitable actions include dangerous martial techniques, committed heavy attacks, major
spells, and future interruptible wind-ups.

Conceptual progression:

```text
TELEGRAPH_STARTED
  -> ACTION_COMMITTED
  -> ACTION_RESOLVED
```

Future-compatible terminal facts include `ACTION_CANCELLED` and `ACTION_INTERRUPTED`, but V1 does
not create a general interrupt framework. The encounter/action policy owns the commitment and
result. Animation, progress bar, and audio visualize the current fact but cannot complete, cancel,
or interrupt it themselves.

## 22. Combat Events

Presentation consumes ordered typed semantic events. The model may use a closed event kind plus
narrow typed detail records rather than one class per kind, but it must not become an untyped
payload dictionary.

Required semantic coverage includes:

- encounter started/ending/ended and result;
- participant entered/removed and target changed;
- ordinary action started/resolved;
- hit, miss, dodge, parry, guard, damage, and resource change;
- tactical requested/queued/replaced/cancelled/started/failed/resolved;
- telegraph started/ended and commitment transition;
- busy/recovery changed;
- unconscious and death;
- flee requested/attempted/succeeded/failed.

Events carry semantic IDs, participant IDs, target IDs, typed numeric/resource facts where needed,
ordered encounter sequence, and failure/cancellation reason. They do not carry localized sentences,
Texture2D, Nodes, animation names as rule truth, or arbitrary maps. Presentation acknowledgement,
if later used for pacing, is separate from domain event commitment.

## 23. Combat Log

The optional lightweight log derives localized/flavored lines from typed events and presentation
metadata. It preserves ES2 martial-text identity, detail, and explanation, but it is supplemental.

Essential information must also be readable through participant state, HP/resources, statuses,
target highlight, telegraph, queued action, and direct feedback. Domain events do not embed final
English/Chinese prose. Hiding the log cannot hide a required tactical fact.

## 24. Targeting

Encounter owns the current target for each actor where needed. Ordinary attacks consume a current
valid hostile target; if it is absent/invalid, encounter target policy may select another valid
hostile and emits a target-change event. The player may explicitly select a valid hostile target.

Tactical actions declare typed target rules. The architecture supports concepts such as SELF,
CURRENT_HOSTILE, SINGLE_HOSTILE, SINGLE_ALLY, ALL_HOSTILES, and ALL_ALLIES without requiring all
of them in the first implementation. Request-time and execution-time validation are both required.

Selection is semantic by participant ID. Target highlight is presentation only. Losing a target
does not allow the UI to silently pick a replacement for a queued tactical action.

## 25. Multi-Opponent Boundary

CombatEncounter, events, targeting, results, and presentation projections use participant
collections and side IDs from CXR2 onward. They cannot assume two actors, equal sides, or one hostile
group. Independent actors may receive independent ordinary opportunities.

Presentation may serialize or stagger visible animations to remain readable, but pacing cannot
combine, suppress, or delay domain opportunities in a way that changes damage or RNG. CXR1 defines
no rule such as limiting multiple enemies to one enemy's total damage. Any later multi-opponent
balance rule requires explicit approval and deterministic tests.

The first runtime proof may remain player versus one NPC, but its API/test fixtures must include
collection semantics and reject duplicate participant IDs.

## 26. Flee

Flee is a tactical action with typed stages:

- request and request-time validation;
- committed attempt;
- success or failure event;
- successful encounter completion result;
- return through a valid world location policy.

The encounter does not set an arbitrary world position. It retains the authoritative source
location/anchor and returns a semantic result for world/session orchestration to apply. Exact flee
formula, cost, destination, pursuit/vendetta behavior, and team handling remain owner decisions.
Generalized auto-wimpy is not V1 scope.

## 27. Battle Presentation

Dedicated battle presentation is a replaceable SceneTree/UI layer responsible for:

- participant visuals and battlefield composition;
- player and hostile HP/relevant resources;
- current target and important statuses;
- current commitment, busy/recovery, and queued action;
- available Quick Actions/categories and typed input intent;
- enemy telegraphs;
- hit/damage/defense feedback;
- optional combat log;
- short victory/defeat/spar/flee result presentation.

It must not own CharacterState, relationships, target validity, scheduler, formulas, RNG,
progression, death, corpse, inventory, Save eligibility, or encounter completion. It does not move
world actors or infer hits from animation collisions.

## 28. Presentation Asset Replaceability

Hard boundary:

```text
Semantic combat state/events/IDs
  -> presentation resolver/catalog
  -> presentation resources
  -> Controls / participant renderer / animation / VFX / audio
```

Combat Core and Encounter must not depend on Texture2D, Sprite2D, Control/Theme, font, animation,
audio, VFX, asset paths, or source image dimensions. Replacing all battle visuals must leave
targeting, damage, skill semantics, scheduler, and Save/lifecycle contracts unchanged.

Character presentation may later be rectangles, sprites, skeletal 2D, illustrations, 3D, or another
renderer. The encounter emits `ACTION_STARTED`, `DODGED`, `PARRIED`, `DAMAGED`, and `DIED`-style
facts; a resolver decides their visual/audio representation.

## 29. Theme / BattleVisualSet / Presentation Catalog Boundary

Future presentation should use:

- one Godot Theme for shared Button, Panel, Label, ProgressBar, tooltip, focus, disabled, font, and
  spacing behavior;
- a typed `BattleVisualSet`-like Resource for shared battle frames, target marker, telegraph,
  queued-action indicator, generic slot/fallback icons, and result presentation;
- typed content presentation definitions mapping semantic skill/action/NPC IDs to display metadata,
  icon, animation ID, VFX ID, and SFX ID.

These are presentation lookup concepts, not CXR1 implementation commitments. Gameplay definitions
retain semantic IDs and no direct asset references. Missing metadata uses a presentation fallback,
not a gameplay failure or generic Dictionary.

## 30. Reusable Battle UI Components

The future scene should compose narrow components rather than one monolithic BattleScene script:

- Battlefield;
- participant presentation;
- player/participant status panels;
- target panel/selector;
- tactical action bar and category panel;
- queued-action indicator;
- telegraph presentation;
- combat feedback layer;
- combat log panel;
- result presentation.

One encounter-facing presenter/coordinator adapter may distribute typed projections/events. Child
components do not call combat services directly. Exact scene names and hierarchy remain CXR6 work.

## 31. Placeholder-First Art Policy

- **CXR2-CXR5:** only minimal programmer presentation needed to prove contracts—Controls, Labels,
  ProgressBars, simple symbols, ColorRect, or placeholder participant visuals. No final art effort.
- **CXR6:** first dedicated battle-presentation and visual-language phase; production-oriented Theme,
  panels, icons, martial styling, feedback, and telegraph structure may begin.
- **CXR9:** narrow polish/playability and only balance changes proven necessary for Old Pine.

The required evolution is placeholder UI -> production asset set -> future visual/theme revision
without changing encounter or combat semantics. If reskinning requires a Game Core change, the
boundary is wrong.

## 32. Responsive Layout / Asset-Dimension Independence

**Layout owns size. Art fills/presents inside the layout.**

Battle presentation uses Containers, anchors, minimum touch targets, scalable textures,
StyleBox/StyleBoxTexture/NinePatch-style resources, wrapping, and scrolling. A source texture's
pixel size never determines the API or fixed button geometry. Text remains Godot Control-rendered,
not baked into art, supporting localization, accessibility, wording changes, and responsive sizing.

The existing mobile minimum applies: qualified usable safe landscape is at least 800x480 logical
units, standard safe padding is 16, and ordinary touch controls are at least 64x64 with at least 8
spacing where the shared mobile contract requires it. CXR1 does not specify final positions.

## 33. Mobile / Desktop UX

One encounter and one command model serve mouse, keyboard, controller semantics, and touch. Input
adapters submit the same typed intents. No platform-specific damage, timing, target, or queue rule
exists.

Touch use must not require high-frequency or frame-perfect tapping. The one-slot queue provides
forgiving input during short busy/recovery windows. Controls respect Shell-lived SafeArea,
landscape, touch sizing, modal ownership, Android Back, input quarantine, and held-contact clearing.
Desktop preserves semantic focus/input behavior. Physical-device qualification is not part of
CXR1.

## 34. Lifecycle

ApplicationShell and its existing mobile lifecycle authority remain in control:

```text
foreground/focus loss
  -> interaction blocked and held input cleared/quarantined
  -> SceneTree pause freezes encounter scheduler and Battle Presentation
  -> World remains frozen
foreground + focus + presentation readiness
  -> no catch-up
  -> explicit Resume gate remains authoritative
  -> encounter continues from the same state
```

Battle presentation and scheduler do not create a second focus/pause policy, ALWAYS-processing
Timer, or wall-clock continuation. Pending queue/telegraph/commitment facts remain transient in the
same Session graph across an ordinary same-process lifecycle pause, but are not serialized.

## 35. Save / Load Boundary

V1 active encounters are restart-unsafe:

- normal manual Save is blocked while an encounter is establishing, active, resolving, or still
  has relationship/busy/guard/lifecycle transient state;
- no CombatEncounter, queue, telegraph, battle UI, or scheduler state enters GameSaveSnapshot;
- no battle autosave is introduced;
- active battle cannot be reconstructed by Continue or Recovery;
- existing completed manual Save, backup/temp recovery, RNG persistence, and A/B Session restore
  transaction remain unchanged.

`game/runtime/persistence/oldpine_save_eligibility.gd` currently blocks cadence, opponents, lethal
markers, busy, interrupt, guarding, aggression, handoff, and incomplete lifecycle. CXR8 integrates
the explicit active-encounter fact into this same authority; it does not create a second Save policy
inside Battle Presentation.

## 36. Encounter Resolution

Encounter completion is a domain/orchestration decision and produces exactly one typed
`CombatEncounterResult`-like value. Result kinds conceptually include:

- victory;
- defeat;
- spar conclusion;
- fled/escape;
- narrow scripted result;
- failed/aborted establishment where no active encounter was committed.

The result contains semantic encounter/mode/participant/outcome facts and the return policy input
needed by runtime orchestration. It does not grant XP, create items/corpses, or store presentation
text. Completion occurs only after required full attack chains and lifecycle/result policies reach
their valid boundary.

## 37. Return to World / Corpse / Loot

For lethal NPC defeat:

```text
Encounter resolves
  -> typed result
  -> existing death/lifecycle and world state are complete
  -> Battle Presentation closes
  -> same resident World Session resumes
  -> corpse remains in World
  -> normal Corpse/Loot interaction transfers items
```

There is no JRPG reward screen that bypasses InventoryState or corpse authority. A short victory
presentation is allowed but is not an item/XP/death owner. SPAR produces no normal lethal corpse.
Player defeat delegates to existing unconscious/death facts; CXR1 invents no penalty or ghost flow.
Flee returns through a validated world/session policy and never silently teleports.

## 38. Enemy AI Boundary

Ordinary automatic combat behavior is scheduler + existing fight/guard/resolution policy. Tactical
NPC decision-making is a separate typed policy seam that may later choose a special, defense, spell,
item, or target based on encounter projections.

V1 does not require sophisticated AI or boss phases. AI is not embedded in BattleScene, does not
read visual animation state, does not own RNG, and cannot call arbitrary callbacks. A no-tactical-
choice NPC still participates fully in ordinary automatic combat.

## 39. V1 Scope

Required:

- dedicated Battle Presentation;
- automatic ordinary combat and defense;
- player tactical actions and visible commitment/busy/recovery;
- exactly one queued tactical action;
- HP/relevant resources and statuses;
- target selection;
- collection-based multi-participant architecture;
- flee;
- lightweight combat log;
- basic enemy telegraphs;
- SPAR and LETHAL modes, plus narrow SCRIPTED extension boundary;
- world freeze;
- typed semantic events and encounter result;
- return-to-world/death/corpse/loot integration;
- replaceable presentation assets;
- shared mobile/desktop semantics;
- Save and lifecycle integration.

## 40. Explicitly Deferred Features

- tactical pause and 2x speed;
- companion/summon tactical AI;
- complex bosses and phases;
- large combo/macro queues;
- general interrupt framework;
- auto-battle configuration and generalized auto-wimpy;
- full balance pass;
- final animation, VFX, audio, art, and skill icons;
- final accessibility/localization;
- active-encounter Save/Load;
- generic scripted encounter engine;
- full equipment/item policy during battle;
- all target-rule and action-category implementations at once.

## 41. Development Roadmap

| Slice | Status after CXR1 | Primary goal |
|---|---|---|
| CXR0 | COMPLETE | Combat redesign analysis and evidence base. |
| CXR1 | ACTIVE SEMI-AUTO V1 DESIGN COMPLETE | Lock contracts and implementation boundaries. |
| CXR2 | READY TO BEGIN | Typed CombatTrigger/CombatEncounter/participant/side/mode/result core without BattleScene ownership. |
| CXR3 | Planned | World trigger -> frozen world -> encounter -> same world return lifecycle. |
| CXR4 | Planned | Encounter-local active semi-auto scheduler; remove cadence ownership from map controller without ATB. |
| CXR5 | Planned | Tactical action requests, validation, busy integration, and one-slot queue. |
| CXR6 | Planned | Dedicated Battle Presentation, replaceable assets, telegraph, feedback, and combat log. |
| CXR7 | Planned | Real multi-opponent targeting and SPAR/LETHAL completeness. |
| CXR8 | Planned | Resolution, death, corpse, loot, Save, and application lifecycle integration. |
| CXR9 | Planned | Fresh New Game Old Pine playability and only proven narrow balance stabilization. |
| CXR10 | Planned | Final audit, canonical validation, PR, CI, merge, and post-main verification. |

Only after CXR10 is integrated into green `main` may a new Technical Demo release-validation
branch/candidate be created. Parked Phase10D2 artifact hashes remain historical and must not be
reused as current candidate evidence.

## 42. Risks / Mitigations

| Risk | Mitigation |
|---|---|
| Scheduler accidentally becomes ATB | Prohibit readiness accumulation, speed bars, and universal turn order; test opportunities as encounter events. |
| Encounter duplicates Combat Core truth | Encounter stores references and orchestration facts only; formulas and resource mutation remain existing services. |
| Animation/presentation becomes authoritative | Commit typed results/events before rendering; animation callbacks cannot decide hit/damage/death. |
| Old WorldController coupling survives | CXR3/CXR4 move trigger/lifecycle/scheduling behind encounter coordinator while map retains only physical world facts. |
| Busy/recovery meaning is unclear | Keep ActionBusyState authoritative, expose semantic commitment events, and defer seconds/durations. |
| Queue race or stale state | Separate request-time and execution-time validation; one monotonic slot; typed cancellation reason; no substitution. |
| Multiple participants become unreadable | Domain opportunities remain independent; presentation may stagger cues without changing outcomes. |
| Architecture work changes balance | Reuse existing resolver and RNG contracts; defer cadence/defense/flee values and isolate CXR9 balance. |
| Save/lifecycle ownership duplicates | Reuse Host/Shell/eligibility authorities; active encounter remains unsaved and freezes through existing lifecycle gate. |
| Asset paths leak into Core | Resolve semantic IDs only in presentation catalogs/resources; no Godot assets in encounter/domain types. |
| BattleScene becomes monolithic | Compose narrow UI components behind an encounter presenter/adapter. |
| Layout depends on placeholder PNG | Containers/anchors/minimum sizes own geometry; scalable art fills it. |
| Combat log is the only readable truth | Require bars, statuses, target, telegraph, queue, and direct feedback independently of log. |
| Final art starts too early | Enforce placeholder-first CXR2-CXR5, visual-language work in CXR6, narrow polish in CXR9. |
| RNG draw order drifts | Scheduler/action policies use Session-owned source and deterministic tests; presentation consumes zero gameplay RNG. |
| Lifecycle checks truncate reverse attacks | Preserve full forward/reverse chain before outer lifecycle evaluation. |

## 43. Remaining Owner Decisions

CXR1 intentionally does not choose:

- exact ordinary attack cadence;
- exact busy/recovery durations or their visual timing;
- exact tactical-defense effect;
- exact enemy tactical-action frequency;
- exact telegraph duration;
- exact flee formula, cost, and return-location policy;
- whether equipment may change during battle;
- exact battle-usable item categories;
- starter character combat balance;
- whether tactical defense replaces an ordinary opportunity or layers over it;
- exact Quick Slot count and whether V1 slots are configurable;
- exact battle transition visual;
- exact combat-log placement;
- final visual style/theme;
- final character presentation technology;
- final audio/VFX approach;
- exact SPAR conclusion rule and compatibility response to armed friendly wound behavior;
- conditions/recovery advancement policy during encounter time;
- initial set of authored tactical actions.

Each decision must be made in the owning later slice with source/current-system evidence and tests;
the architecture above permits those choices without changing its ownership model.

## 44. CXR2 Entry Criteria

CXR2 may begin because this design now fixes the following boundaries:

- **CombatTrigger:** immutable semantic IDs/cause/mode/candidates/location; no Nodes or arbitrary
  payload.
- **CombatEncounter:** Session-scoped transient orchestration over exact authorities; collection,
  phase, targets, queue, event ordering, and monotonic result invariants.
- **Participants/sides:** unique semantic Character IDs with open stable side IDs; not hard-coded
  1v1.
- **Modes:** one engine for SPAR, LETHAL, and narrow SCRIPTED policy.
- **Target ownership:** encounter owns current semantic targets; actions declare typed target rules.
- **World freeze:** same resident Session remains authoritative; exploration cannot progress or
  catch up.
- **Scheduler:** encounter-local opportunities with no readiness/turn model; existing Core performs
  calculation and mutation.
- **Combat Core:** existing Character/Skill/Equipment/Combat/RNG/lifecycle authorities remain
  authoritative.
- **Busy:** existing typed state; scheduler advances it; presentation explains commitment.
- **Tactical requests:** stable registered IDs with request-time and execution-time validation.
- **Queue:** exactly one visible/cancellable/replaceable player slot; no silent substitution.
- **CombatEvent:** ordered typed semantics with narrow detail records; no string or Dictionary soup.
- **Presentation:** non-authoritative consumer/intent source; no formulas or Session ownership.
- **Asset replaceability:** semantic ID -> presentation resolver/resource -> renderer; layout owns
  size.
- **Save/lifecycle:** active encounter unsaved; existing Shell/Host pause/resume and Save eligibility
  remain sole authorities.
- **Resolution/return:** typed result; same world Session resumes; existing corpse/loot flow remains.
- **V1 non-goals:** ATB, turn-based, action combat, universal cooldowns, multi-action queue, final
  art, active-combat Save, and broad balance are excluded.

### CXR2 implementation boundary

CXR2 should introduce only typed, Node-free or minimally runtime-neutral encounter foundation:
trigger cause/mode, participant/side references, lifecycle state, target facts, result kinds, and
core invariant validation. It may define narrow ports for resolving exact authorities and emitting
events, but it must not implement scheduling, world freezing, tactical actions, queue execution,
BattleScene, UI, timers, Save mutation, corpse behavior, or balance. Existing production world flow
must remain behaviorally unchanged until later slices integrate it deliberately.

After this document:

- **CXR0 — COMPLETE**
- **CXR1 — ACTIVE SEMI-AUTO V1 DESIGN COMPLETE**
- **CXR2 — READY TO BEGIN**
- **Phase10D — PARKED pending combat redesign**
