# S7B — Snow North Street Physical Spine

**OWNER APPROVED / CLOSED** at `f6c8688b61a4fd850ce80699413b00ce3324d331`.
The separately authorized [Final Snow Audit](PHASE_SNOW_TOWN_CORE_HUB_FINAL_AUDIT.md)
passed; final PR authorization is still pending. Historical implementation evidence below is unchanged.

## Baseline and authority

- Branch: `phase/snow-town-core-hub`; exact local/remote start
  `04c77650ea72d48cae1173a422a78c3c0188abd5` (`Rebaseline Snow north street and core services`).
- Main/merge base: `047f29083e881156abbdad6ed480bffc1350dfa8`. Initial worktree/index clean,
  no open PR. No branch/worktree change or owner-local cleanup.
- S7A is OWNER APPROVED / CLOSED. [Its analysis](PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_CORE_SERVICES_REBASELINE.md)
  remains historical source evidence; the subsequent owner instruction selected A–L.
- First commit `a7a4e28f5d1c014603dfabcee5f19e625cabbb86`,
  `Record owner-approved S7B Snow spine decisions`, changes only [DECISIONS](DECISIONS.md).
  Implementation follows in `Add Snow north street physical spine`.

ES2 decides WHAT / WHY / RESULT; Godot decides physical embodiment and native architecture.
Reciprocal source topology/identities are Type A. Continuous rectangles and visibly staged
service/region closures are the explicitly approved Type B scope, not authored permanent locks.
No Type C redesign or new rule formula.

## Exact source and implementation

Directly rechecked under `reference/es2/mudlib/`: `d/snow/mstreet2.c`, `mstreet3.c`,
`mstreet4.c`, `crossroad.c`, `hockshop.c`, `herbshop.c`, `postoffice.c`,
`d/green/path6.c`, `d/goathill/mroad1.c`. Inherited ROOM/door semantics and service
dependencies are accounted for by S7A; no procedural service from those files is migrated here.

| Native zone / combat identity | Source identity | Executable north/south | Deferred source side |
| --- | --- | --- | --- |
| `snow.mstreet3` | `/d/snow/mstreet3` | mstreet2 ↔ mstreet3 ↔ mstreet4 | east Hockshop, west Herbshop |
| `snow.mstreet4` | `/d/snow/mstreet4` | mstreet3 ↔ mstreet4 ↔ crossroad | west Postoffice; **no east exit** |
| `snow.crossroad` | `/d/snow/crossroad` | south mstreet4 | north Goathill, east Green |

All three use region `snow`, map `snow.outdoor`. mstreet3/4 display 雪亭镇街道;
crossroad displays 山坳. `SnowWorldDefinitions` appends these zones and exact source-exit
metadata, registering only consecutive bidirectional neighbors. Source paths in metadata
do not instantiate native destinations. mstreet4's east-alley prose does not override its
actual exits mapping; no east zone, action, alley or doorway exists. Crossroad's danger
prose is not a trigger: no bandit spawn, encounter, guard or key was invented.

Production changes are only:

1. `game/data/snow/snow_world_definitions.gd` — identities, source metadata, adjacency.
2. `game/scenes/world/snow/snow_outdoor.tscn` — ground, labels, three existing-kind physical
   zone components, static wall collision and matching visible silhouettes/frontages.

No controller, Core, Session, save, UI authority, cadence, RNG or build script changes.
The existing Snow controller, actual-zone placement validator, shared Player and one
resident handoff composition already support the new definitions; no parallel world model.

## Physical layout and honest boundaries

Existing outdoor9 + new3 = outdoor12; with Inn, Snow10→13 zones. Resident count stays4
(Snow Inn/outdoor and existing Old Pine outdoor/cave), exactly one active map child.

| Zone | Center | Rectangle |
| --- | --- | --- |
| mstreet3 | `(0,-1000)` | `200×300` |
| mstreet4 | `(0,-1300)` | `200×300` |
| crossroad | `(100,-1650)` | `400×400` |

Only the old mstreet2 north blocker is shortened: old x[-100,500] at y=-850 becomes
x[100,500]. The Workplace north wall remains; the street width200 opens northward.
Every previous zone, marker, spawn, Bank/Workplace placement and Old Pine connection remains
at its old position. No migration offset or save remapping.

- mstreet3 east 丰登当铺 · 当 and west 桑邻药铺: static facade, shutter, name and solid
  street-side collision. No generic door, proximity interaction, empty interior or service UI.
- mstreet4 west 雪亭驿: same static treatment. East is an uninterrupted plain wall,
  not an authored-looking alley promise.
- crossroad north 北·野羊山 and east 东·邻村: distinct visible direction stubs ending
  at solid boundaries. No portal, external map/zone, fake target or denied-travel action.
- School, Smithy, Temple, sroad2 and Dragonhill edges remain blocked. No southwest expansion.
- Facades add no NPC/character, timer, processing script, reward, item or world-gate owner.

## State, recovery and Save contract

Root schema2 / embedded item3 / `SOURCE_ENTRY_V1` are unchanged. Existing old item1/2
compatibility is unchanged. New valid zone+position pairs pass the existing geometric
validator; wrong-zone, ambiguous overlapping, blocked, nonfinite and outside positions fail.
No new save field, fallback spawn, corrective teleport, refill or grant.

Zone entry preserves Player/Inventory/Stacks/Index/allocator/gate/cadence identity.
The focused fixture advances 3s with recovery reset5, traverses all new zones while driving
time explicitly, retains tick4/accumulator1 and one reset draw, then advances1s to tick3.
This proves entry does not reset/replace cadence; it does not confuse paused test time with
live scheduling. Real gameplay separately ran ordinary natural metabolism throughout.
All three gameplay RNG streams and allocator continuation stay unchanged by walking.
Cold Continue creates the already-designed fresh transient recovery phase, not old phase replay.

Existing direct-held dumpling and clear-water use remain legal on new streets (399→459 food,
399→429 water); tested through unchanged typed services. Test-only purchases/fill are fixture
setup, not claims of player-visible service journeys. All new zones report no Waterfall Fill.
No alcohol, condition timing, poison, combat recovery or new food/water authority.

## Automated evidence — local execution

Godot **4.7.2-stable (Steam)**, 2026-09-13. Focused and full canonical were distinct runs.

| Check | Result |
| --- | --- |
| `res://tests/run_snow_spine_tests.gd` | **188 assertions / 0 failures / exit0** |
| Complete `res://tests/run_tests.gd` | **19,410 assertions / 0 failures / exit0** |
| Python `unittest discover -s tools/tests -p test_*.py` | **46 PASS** |
| `tools/ci/repository_checks.py` | PASS |
| Development headless editor | PASS |
| Repository-content release sanitizer | PASS |
| Sanitized headless editor + canonical startup120 frames | PASS |
| Diff/trailing whitespace and changed-document links | PASS |

New tests: `game/tests/runtime/snow_north_spine_test.gd`,
`game/tests/run_snow_spine_tests.gd`, `game/tests/run_snow_spine_cold_process.gd` (+ UIDs),
registered in the canonical runner. The older Work test replaces its now-intentionally-open
mst2 north-wall rejection with the still-closed Workplace north wall; no acceptance weakening.
First focused attempt exposed a nested test-array type mismatch and a detached-node transform
cache in overlap fault injection. Fixed the test type and exercised geometry after actual
map activation. No production fix was needed; final focused/canonical logs have no script errors.

Coverage includes independent source expectations, exact adjacency/non-neighbors, six new
closed boundaries, five old closed boundaries, physical forward/reverse Area transitions,
all three new-zone encode/decode/restore equality, runtime identity, NPC/resident counts,
allocator/RNG/cadence continuity, old Work/Bank/supply/Old Pine regressions in the full suite.
Separate OS processes write/read both **mstreet3 and crossroad**, compare entire captured
snapshots and unchanged bytes, then prove post-Continue CharacterBody walking. Their writer
uses declared position fixtures, separate from the unmodified live-input journey below.

Before any production edit, exact pre-S7B `04c7765` production generated an isolated source
save using the existing S6B cold runner (`write partial s7b-pre-04c7765`). New production then
ran `read partial` on that file: PASS, entire Player/items/liquid/money/location/allocator/RNG
snapshot equal and no saved-byte rewrite. This is real older-code output, not a new-code
approximation of an old save. Old position regressions also run unchanged in the full suite.

Ignored local logs are under `build/s7b-evidence/`: focused, canonical, Python, static,
editor-final, sanitizer, sanitized-headless, pre-save and pre-save-read. The sanitizer source
was an exact copy of tracked repository game files plus this slice's new tests, not the dirty
development directory's ignored Godot AI update backups. Source-content digest validation
passed. Backups/configuration stayed untouched; no broad cleanup or sanitizer bypass was added.

## Real desktop acceptance — canonical ApplicationShell

Normal New Game controls, Chinese name 北行/source male, real framebuffer clicks, keyboard
events and frame-timed `move_*` input. No Player position assignment, direct zone/portal/
button callbacks, fake spawn or service invocation in this journey. Read-only runtime probes
supplement actual movement and screenshots. All coordinates below are observed, not injected.

1. PID27168: New Game → Inn `(0,0)` → east doorway → Square → mst1 y≈-396 → mst2
   y≈-693 → mst3 y≈-1001. Both facades visible. Held left/right stops at x≈±70.993;
   no interior, action or zone transition. Nonstale frame12875 shows both storefronts.
2. Pause → real Save button → “Your journey was saved.” Entire paused capture equals file;
   root2/item3/source revision1. mstreet3 `(70.99318695,-1001.00213623)`, save fingerprint
   `22074e0ffa7703b38005bcadfdbbd6afd1c4b334115aa25961363f0e004017f1`.
3. Stop process → fresh PID66624 → real Continue. Exact mstreet3 position restored;
   fresh runtime objects, unchanged allocator1 and gameplay RNG states. Walk normally to
   mst4 y≈-1294. East wall and west Postoffice stop at x≈±70.993. Frame5290 nonstale
   shows Postoffice and uninterrupted east boundary.
4. Continue physically north to crossroad `(-1.25848,-1664.66187)`. Held north stops at
   y≈-1820.993 under Goathill sign; frame8325 nonstale. Return south inside the clearing,
   hold east: x≈270.993, y≈-1652.260 under Green sign, frame11013 nonstale. Still Snow,
   no external map/NPC/interaction. Same Session Player/Inventory/cadence objects throughout.
5. Pause → Save again. Entire paused capture equals file at
   `(270.99319458,-1652.26037598)`, fingerprint
   `d2e233ce1c2116916ebbf00bfb37bde7eb198386311328716b239a31450b25f5`.
   Stop → fresh PID73160 → Continue: exact position and same file hash, root2/item3/source1,
   same semantic graph/allocator/RNG, new runtime objects. Automated cold tests prove full
   snapshot equality; ordinary live metabolism may advance after entering gameplay.
6. Normal walking reverses crossroad→mst4(-1300)→mst3(-1007)→mst2(-714)→mst1(-420)→Square.
   Smithy west and School east collide at x≈±70.993; Temple east at x≈270.993.
   Then sroad1 west at x≈-70.993 and south at y≈620.990 collide; finally return to Square
   `(-1.25848,1.25842)` and Pause. No return shortcut. Frame14879 shows Square after return.

Runtime tree: `ApplicationShell → RuntimeHostSlot → OldPineGameRuntimeHost → SessionSlot →
OldPineWorldSession → ActiveMapSlot → SnowOutdoor`; one active map, 12 outdoor Area zones,
four resident maps, zero Snow NPCs. Existing OldPinePassage remains; no new passage nodes.
All walking snapshots retained allocator1 and the same three RNG states:
`-7652628861909730154 / -6413415994948829231 / 7389949936942931270`.
Natural recovery uses its separate source; its same cadence instance continued across zones.

Helper_live/session_active/game_capture_ready=true. Frames above have stale_frame=false and
advance within each process. Successful launches report current_run_errors=[]; final current-run
game log has only informational entries. Two earlier QA attempts are excluded: an invalid
String-iteration input script, then an unguarded read before valid character creation. English
test name rejection was correct existing policy, not a New Game defect. Restarted and used
normal Chinese input. No production rule/tool configuration was changed to obtain connectivity.
Original development test save/backup were copied to ignored evidence before UI Save; no
owner-local Godot AI files were touched. New live save remains a valid crossroad test save.

## Distinct self-review and remaining authorization

Reviewed source mapping, complete production diff, shared rectangle use, wall openings, half-open
join ownership, restore geometry, automatic-versus-explicit test time, and tests' independence
from production constants. No physical change south of the old north blocker; no new authority.
`reference/es2`, Core, Session, native Save contract, project settings, CI/build/export delta0.
DECISIONS delta is only the separately authorized S7B A–L entry.

Hockshop appraisal/pawn/sell/payout/destruction/custody; Herbshop medicines/healer; Postoffice
mail/accounts; School teaching/apprenticeship; Smithy equipment/craft/repair; secret/storage,
southwest streets, Green/Goathill region entry, Snow NPC population and loot monetization remain
explicitly deferred. Existing slow eligible effective-resource recovery is the approved healing
finish line, not a claim of fast-medicine parity. Prior failed-transfer substitutions do not
automatically generalize to these services. No Lake, Phase5B4 or next region.

Historical implementation stop was S7B owner review. Owner subsequently approved/closed S7B and
authorized the distinct Final Snow Audit, now PASS — PR READY. No claim of full Snow parity or
integration on main. Branch/worktree preserved; no final PR or new CI claim.
