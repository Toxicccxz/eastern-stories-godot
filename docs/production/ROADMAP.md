# Roadmap

## Goal

A native 2D Godot RPG that carries ES2's content and rules — regions, NPCs, items, skills,
families, quests — with modern maps, movement and UI, reliable Save/Continue, and a coherent
start → early → middle → late play chain. Faithful to the LPC where it matters; deliberate
single-player adaptations are owner decisions recorded in
[DECISIONS](../migration/DECISIONS.md). No release date is set; steady, playable progress matters
more than speed.

Progress is measured by playable content packages, not documents, commits or assertion counts.
[PROJECT_SCOPE](PROJECT_SCOPE.md) tracks per-package dispositions.

## Near term — make content cheap to add

The first two regions proved the rules and foundations but each NPC/item currently costs many
hand-written files. Fix that before adding breadth.

| # | Package | Done when |
|---|---|---|
| 1 | **Workflow reset** | Slim AGENTS/docs, one-page STATUS, single-suite test runner. |
| 2 | **Data-driven content** | NPCs, items, vendors and spawns load from data files through generic loaders into the existing typed definitions; existing Snow/Old Pine content converted with unchanged behavior; per-item classes, per-offer purchase services and ID `match` chains removed. |
| 3 | **Generic map runtime** | One data-configured map controller plus reusable zone/portal/spawn/interaction components; explicit combat cadence; UI no longer dispatches on concrete map types; terrain on `TileMapLayer` with a placeholder TileSet; zones show the room's authored ES2 description. |
| 4 | **Content importer + Snow complete** | A best-effort LPC → data importer for NPCs/items/vendors/spawns (manual overrides kept separate); all of Snow's rooms, NPCs, shops and services playable. Record the time per NPC as the baseline for later regions. Five PRs: 4A importer + street NPCs, 4B south road and shops, 4C Inn upstairs / school inner rooms / secret storage, 4D ask, talk, wandering and room reset, 4E give, put and drop, shops and services bound to NPCs, teachers as data. |
| 5 | **Localization foundation** | One PR after Package 4, before the second region: Godot translation set up with Simplified Chinese as the source locale, hard-coded player text (and the English labels some panels still show) moved to `tr()`, a key scheme and extractor for data text (POT), a pseudo-locale check that finds untranslated text, font fallback. No translations yet (they wait for release readiness; Traditional Chinese first). |

Small correctness items ride along with the package that touches the code: `apply/*` stat
bonuses in combat, the missing Keep scene reference. New player text follows
[LOCALIZATION](LOCALIZATION.md) from Package 5 on.

## Then — systems and regions

Order may change after the near-term packages; each item is a content package with owner playtest.

* **Internal power**: `force`/`fonxanforce` obtain → enable → exercise → combat use → save.
* **Offense/defense routes**: `sword`/`parry`/`dodge`, `fonxansword`, `chaos-steps` with real
  learning and equipment prerequisites (teachers already teach what `skills.json` defines);
  practice/self-learning reachable in play; then 柳绘心 (Snow's study) can be placed and 柳淳风
  and 安惜迩 fought.
* **Combined items**: amounts that merge and split (`std/item/combined.c`): Snow's 桃符纸, 蛇药
  and the travellers' 飞刀.
* **Conditions and treatment**: condition-producing attacks, update cadence, cures and supplies.
* **Old Pine remainder**: full Cave, Keep, Tree and other deferred routes and actors.
* **Pacing knobs**: data-configured multipliers (default = original) decided from owner playtests.
* **Second region and family**: chosen by source connections; must reuse shared systems.
* **Breadth**: remaining regions (including `u/cloud`), families, special abilities
  (perform/exert/cast), quests (`quest/qlist*`), NPCs that wander across maps, doors, death/ghost realm.
* **Presentation**: art direction and assets, audio, animation, consistent Chinese UI.

## Later — release readiness

Systematic playtesting and balance, device qualification (touch, iOS runtime), formal player-save
baseline, product IDs/signing, and resolving [license/provenance](LICENSE_PROVENANCE.md) — the ES2
rights question must be settled before any public distribution.

## History

Phases 1–10, combat redesign, Snow/Old Pine packages, Migration Tooling v1, Lake and Shared UI are
recorded in git history, PRs #1–#25 and the historical `PHASE_*` / `MIGRATION_TOOLING_V1_*` files
under `docs/migration/`.
