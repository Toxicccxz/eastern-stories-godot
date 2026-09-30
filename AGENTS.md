# AGENTS.md

## Mission

Rebuild classic Eastern Stories / ES2 as a **native 2D Godot RPG** with a modern UI.

This is not a graphical shell around a MUD client. Keep the original game's meaningful content and
rules — rooms, NPCs, items, skills, families, quests, formulas, progression — and rebuild maps,
movement, interaction and presentation as a real RPG.

The measure of progress is **playable, faithful content in the game**, not documents, audits or
tooling. Work steadily: every change leaves the game runnable, and each content package adds
something the owner can walk to, see and use.

## Roles

* **Owner**: sets direction, decides ES2 content trade-offs and deviations, playtests player-visible
  changes, merges PRs.
* **Agent**: plans, implements, tests, self-reviews, commits, pushes branches and opens PRs.
  The agent never merges.

## Authoritative Source

* `reference/es2/` is the original ES2 LPC mudlib and the behavioral reference. It is read-only.
* Read the relevant LPC (including inherited/included code) before porting a mechanic or content.
* Preserve formulas, conditions, state transitions and authored text. When behavior is ambiguous,
  follow the LPC, not assumptions.
* Keep legacy paths/IDs on definitions (e.g. `es2:d/oldpine/npc/bandit`) for traceability.
* Do not use external ports or reimplementations as sources unless the owner asks.
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

## Deviations

Do not silently redesign original mechanics. A deliberate deviation (single-player adaptation,
removing a broken LPC feature, UI-driven change) needs owner agreement and one short entry in
`docs/migration/DECISIONS.md`: what the LPC does, what we do, why.

Balance/pacing adaptations for single-player must not edit ported formulas. Put them in explicit,
data-configured knobs whose default reproduces the original.

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
* Map visuals are placeholder art for now; build terrain with `TileMapLayer` so art can be swapped
  by replacing the TileSet. Logic (zones, portals, spawn markers) stays separate from visuals.

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
them and move on.

Do not refactor unrelated code or add speculative features. Do not migrate adjacent systems just
because they are nearby. When blocked on a real decision, ask the owner once with a recommendation.

## Documentation

Keep documentation small and current:

* `docs/production/STATUS.md` — one page: what is playable, known issues, next package.
  Overwrite it; don't append history (git and PRs hold history).
* `docs/production/ROADMAP.md` — forward plan only.
* `docs/migration/DECISIONS.md` — deviations and global rules, one short entry each.
* One short note per content package under `docs/migration/` only when it records something the
  code and PR don't: LPC→native mapping, source anomalies, deferred items.

No per-sub-slice reports, formal-audit documents, re-audits, blocker write-ups or evidence logs in
the repository. Existing historical docs stay as they are; don't extend them.

## Git and CI

* `main` is stable. Branch from green `main`: `phase/<slug>`. One package (or a few small related
  ones) per branch and PR; multiple focused commits are fine.
* The PR runs the four required jobs (Godot Verify, Windows, Android, iOS). Fix failures on the same
  branch. The owner merges.
* Don't force-push published branches, rewrite history, delete remote branches, change repository
  settings/secrets, or publish releases.
* If post-merge `main` CI fails, fix it on a narrow `hotfix/<issue>` branch before other work.

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
tools/           ci/, build/, migration/ (Python, standard library)
game/            Godot project: core/ runtime/ application/ data/ presentation/ ui/ scenes/ tests/
```
