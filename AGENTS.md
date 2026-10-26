# AGENTS.md

## Mission

Build a **modern wuxia RPG on the foundation of Eastern Stories / ES2**, for today's players
(owner, 2026-10-23; DECISIONS「产品定位」): rules and movement on authored 2D maps, every map shown
through a fixed-angle 3D voxel view (owner, 2026-10-22; see [Maps and art](#maps-and-art)).

This is not a graphical shell around a MUD client. ES2's world — rooms, people, items, skills,
families, quests, formulas, progression and its authored text — is the foundation. Where its rules,
pacing or presentation would put a modern player off, we change them; where the world has gaps, we
add regions, families, NPCs and quests that fit it.

The measure of progress is **playable content a player enjoys**, not documents, audits or tooling.
Work steadily: every change leaves the game runnable, and each content package adds something the
owner can walk to, see and use.

## Roles

* **Owner**: sets direction, decides changes to ES2 and new content, playtests player-visible
  changes, merges PRs.
* **Agent**: plans, implements, tests, self-reviews, commits, pushes branches and opens PRs.
  The agent never merges.

## Sources

* `reference/es2/` is the original ES2 LPC mudlib and the source for everything ported from ES2.
  It is read-only.
* Read the relevant LPC (including inherited/included code) before porting a mechanic or content.
  Port its formulas, conditions, state transitions and authored text as they are; when behavior is
  ambiguous, follow the LPC, not assumptions. Changing them is a separate, recorded step
  ([Changing ES2](#changing-es2)).
* Keep legacy paths/IDs on definitions (e.g. `es2:d/oldpine/npc/bandit`) for traceability.
* New content (not in ES2) needs an owner-approved plan and must fit the world bible once it
  exists; its data says where it comes from, so ES2 and new content stay distinguishable.
* Do not use external ports or reimplementations as sources unless the owner asks; other games
  inspire designs, never text or content.
* `u/cloud/` contains real gameplay content linked from `d/` (a whole town); treat it as content,
  not wizard space.

## Core Migration Rule

**Translate game semantics, not the LPC runtime.**

1. **Data/content** → data files loaded into typed definitions.
2. **Game rules** → typed GDScript domain code.
3. **MudOS/FluffOS infrastructure** → replace with Godot-native behavior or omit.

Do not build an LPC interpreter, FluffOS compatibility layer, Telnet/socket code, wizard/euid
security, or login/server daemons. `call_out()` → timers/events; `heart_beat()` → explicit system
ticks; `environment()` → the right location/inventory/ownership relation; LPC inheritance → understand
the behavior, don't reproduce the tree.

Known driver semantics may be applied as one global rule instead of per-site exceptions
(e.g. MudOS `random(n)` with `n <= 0` returns 0). Record such rules once in `DECISIONS.md`.

## Changing ES2

The game is for today's players. Plans lead with how a modern RPG would handle it and show ES2's
behaviour beside it — whether ES2 would read as a bug to them (a line that speaks of other players,
a loss nobody tells the player about, an NPC that refuses a gift and keeps it, an offer that can
never be taken, a loophole such as killing one's master to change families for free) or just as
slow, opaque or punishing.

* Nothing changes silently. Every change to ES2 behaviour gets one short entry in
  `docs/migration/DECISIONS.md`: what ES2 does, what we do, why.
* Ported formulas are not edited in place. Pacing, balance and rule changes go into explicit,
  data-configured knobs; the knob keeps ES2's value as its **经典模式** (classic) value, and the
  default is the agreed modern one.
* Changes inside an owner-approved plan need no further question. Changes that alter the game's
  direction — a system's design, a region's story, removing ES2 content — need the owner's
  agreement first.

## Technology

* Godot 4.7.2, modern fully typed GDScript. Prefer Godot-native APIs and composition.
* Pure domain logic in `RefCounted` classes. Use `Node` only for scene lifecycle, signals, timers,
  physics, rendering or editor integration.
* Autoloads only for genuinely global lifecycle services. Dev/QA helpers must be opt-in, never
  active by default.
* No third-party runtime dependencies without a concrete need. The Godot AI addon is dev-only and
  stripped from releases.
* Player-facing text goes through `tr()`; do not show legacy room IDs or debug labels to players.

## Architecture

**Game Core** (`game/core`) owns authoritative rules and state: character, combat, skills, inner
power, conditions, inventory/equipment, NPC state, families, quests, economy, save data. It must not
depend on nodes, positions, scenes, UI or presentation timing.

**World Runtime** (`game/runtime`) owns physical embodiment: maps, movement, collision, spawns,
zones, portals, interactables, transitions. Runtime components are **generic and data-configured**;
do not add region-specific controllers/adapters (`oldpine_*`, `snow_*`) for mechanics that will
recur in other regions. Timing such as combat cadence is explicit configuration, not an implicit
node default.

**Presentation/UI** (`game/presentation`, `game/ui`) reacts to results. It does not own world state
or rules, and runtime does not construct UI directly.

**The game rule decides what happened. The presentation decides how it looks.**

## World Model

`World -> Region -> Map/Scene -> Zone/Interior/Portal -> Physical Position`

* Cluster adjacent MUD rooms that form one continuous place into one map; meaningful subdivisions
  become zones; portals only for real scene transitions.
* Preserve meaningful doors, locks, hazards, quest gates and scripted transitions.
* Keep legacy room IDs as zone metadata; show the room's authored description to the player
  (on entering a zone or on "look"), not its ID.
* Location state is region/map/zone/position, not a single `current_room_id`.
* Physical walking is Godot-native (`CharacterBody2D`, collision). Core decides whether an action is
  allowed; runtime performs it.
* Floors, climbs, caves and drops are transitions between maps (portals, stairs, room verbs), not
  3D height. A slope or stair run is a 2D path; its height, if shown, is presentation only.

## Maps and art

Owner decision (2026-10-22): **every map in the project gets a fixed-angle voxel view, dressed
as richly as 饮风客栈's upper floor.** Long-term rules:

* **One source per fact.** `tools/maps/layouts/<region>.json` is the map: tiles (walkable area,
  collision), zones, portals, doors, spawn points, and every piece that blocks — a blocked box with
  its `{"look": {...}}` (kind, rotation, colours), or generated from the room's `life`
  (`tools/maps/life.py`). `python -m tools.maps.paint` writes the scene,
  its `Furnishings` nodes included. The voxel view draws furniture only from those nodes; never
  copy a footprint or coordinate into a second file.
* **Voxel config** per map: `game/data/<region>/voxel/<map>.json` (map id without the region,
  e.g. `snow.inn_upstairs` → `snow/voxel/inn_upstairs.json`), named by the layout's
  `scene.presentation`. It holds only what blocks nothing: lights, windows, rugs, wall hangings,
  small floor things, cut-away walls (`low_walls`), buildings' outward shape, flora, actor looks,
  entrance labels.
* **Code** in `game/presentation/voxel/`: the view, geometry, lighting and occlusion at the top;
  `props/` (shapes, furniture, fixtures, architecture), `terrain/` (ground, landmass, foliage,
  trees), `actors/`, `shaders/`. A new prop kind goes in the props file of its category and is
  data-configured (size, colours); no per-map or per-region scripts.
* **The 2D runtime stays authoritative.** Positions, collision, reach, doors, saves and RNG are
  the 2D map's; the voxel view only shows them and never changes a rule or a saved value.
* **Richness standard** for every room, street and wild map, whatever its region's style:
  - Everything ES2's text names is there (饮风客栈's 招牌 and 红木门, the square's 木架, 武馆's
    旗杆 and 石狮). Additions fit the room's purpose and never contradict the text.
  - Each room is furnished for what it is (a guest room: bed, linen, washstand, rack, chest;
    a shop: counter, goods, stock), plus lived-in detail (slippers, teapots, books, jars).
  - Repeated rooms differ (theme, furniture, colours); each region keeps its palette and
    materials ([美术规划](docs/design/美术规划.md)).
  - Light for day and night (windows, lamps, lanterns); outdoor maps get flora and ground detail.
  - Doors, exits, spawn points and NPC reach stay clear; added furniture is blocked in the layout
    and the walk-through tests still pass.
* **Assets.** Today all forms are code-built boxes. Imported art goes under `game/assets/<kind>/`
  (`models/`, `textures/`, `audio/`, `fonts/`), named by what it is, with its source in
  [LICENSE_PROVENANCE](docs/production/LICENSE_PROVENANCE.md). Scratch renders and archives stay
  in `build/`.

## Data-Driven Content

Content is data, not code:

* NPCs, items, shops/vendors, spawns, zones and room metadata live in data files under
  `game/data/` and are loaded into typed definitions by generic loaders.
* No one-script-per-item/NPC classes, no one-service-per-shop-offer, no ID-based `if`/`match`
  chains for content, no long positional constructors for authored content (use named fields).
* Each fact has one home. Do not duplicate item stats or values across files.
* Scripts are for genuinely procedural behavior (custom NPC actions, room verbs, special skills).

## Tooling

A tool is justified only by a **consumer in the game**. Before building or extending a tool, name
the game data it will produce and the loader that will read it. Content importers are best-effort:
extract what is regular, flag the rest for human review, keep manual overrides separate so reruns
don't clobber them. Stop hardening a tool once further work stops changing its real output.

## How Work Is Done

Work in **content packages**: a coherent, playable increment the owner can test
(e.g. "Snow shops complete", "internal power: obtain → cultivate → use in combat → save").

For each package:

1. Read the relevant LPC and existing code. For a large or architectural change, present a short
   plan and get owner agreement first.
2. Implement with focused tests for rules, formulas and state transitions (seed/inject RNG).
3. Run the affected suites during development; run the full `verify.py` once before opening the PR.
4. Self-review the diff (a fresh-context review pass for large changes).
5. Launch the game for a smoke check when runtime/UI/scene code changed; report what was and wasn't
   checked live.
6. Open a PR with: what changed, LPC sources consulted, tests run, **3–5 things for the owner to
   playtest**, and open questions/deviations for the owner to decide.

The owner's playtest is the acceptance for player-visible behavior, feel and pacing. Automated or
agent-driven play is a debugging aid, not an acceptance gate. Do not block on tooling limits; report
them and move on. The owner may batch that acceptance: when the ROADMAP says so (currently "After
the grey box"), packages ship with the agent's windowed walkthrough and keep their 试玩 items for
the owner's unified playtest.

Do not refactor unrelated code or add speculative features. Do not migrate adjacent systems just
because they are nearby. When blocked on a real decision, ask the owner once with a recommendation.

## Documentation

Keep documentation small and current:

* `docs/production/STATUS.md` — one page: 已实现 (what is built), 待试玩 (built, waiting for the
  owner's playtest), 待制作 (next), 待决定, known issues. Overwrite it; don't append history (git
  and PRs hold history). Update it from the code, the merged PRs and DECISIONS, not from older
  notes: a "not yet" in a historical doc is not a task.
* `docs/production/ROADMAP.md` — forward plan only.
* `docs/migration/DECISIONS.md` — 现行规则 (the rules in force, by system) at the top, then the
  deviations and global rules in force, one short entry each, newest first. When a decision
  replaces an entry, update 现行规则 and move the old entry verbatim to `DECISIONS_HISTORY.md`
  with a line naming its replacement; point code citations at the entry in force.
* One short note per content package under `docs/migration/` only when it records something the
  code and PR don't: LPC→native mapping, source anomalies, deferred items.

No per-sub-slice reports, formal-audit documents, re-audits, blocker write-ups or evidence logs in
the repository. Existing historical docs stay as they are; don't extend them.

## Git and CI

* `main` is stable. Branch from the latest `main`: `phase/<slug>`. One package (or a few small
  related ones) per branch and PR; multiple focused commits are fine.
* The PR runs the four required jobs (Godot Verify, Windows, Android, iOS); merging runs no CI,
  so what reaches `main` must have passed on the PR. Fix failures on the same branch. When `main`
  moves after a PR's CI ran (another PR merged), merge `main` into the branch so CI runs again
  before the owner merges. The owner merges.
* Don't force-push published branches, rewrite history, delete remote branches, change repository
  settings/secrets, or publish releases.
* If a manual CI run on `main` fails, fix it on a narrow `hotfix/<issue>` branch before other work.

## Save Policy

Development builds don't promise backward-compatible saves; a contract change may require New Game.
Current-contract Save/Continue must restore exact state and stable identities, write atomically and
fail closed on unsupported files. Never delete save files automatically. Details:
[save contract](docs/production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy).

## Commands

Godot 4.7.2 lives at `build/toolchain/editor/` (git-ignored; do not delete `build/toolchain/`).

```text
python tools/ci/verify.py --godot <godot>                                 # full gate (~10 min)
<godot> --headless --path game --script res://tests/run_suite.gd -- <res://tests/...test.gd> ...
<godot> --headless --path game --editor --quit                            # parse/import check
```

Write logs and scratch output under `build/`, never the repository root or `game/`.

## Repository Shape

```text
reference/es2/   original LPC (read-only, outside res://)
docs/            production/ (status, roadmap, build, policies) and migration/ (decisions, notes)
tools/           ci/, build/, migration/, maps/ (Python, standard library; maps/layouts = map source)
game/            Godot project: core/ runtime/ application/ data/ presentation/ ui/ scenes/ tests/
                 data/<region>/voxel/ map visual configs; scenes/world/<region>/ painted maps;
                 presentation/voxel/ the voxel view
```
