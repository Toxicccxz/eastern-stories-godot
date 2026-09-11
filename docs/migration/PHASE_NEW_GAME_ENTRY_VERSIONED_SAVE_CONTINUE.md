# NGE5A — Versioned Source Save / Cold Continue

## Current policy — NGE5A1: Drop Pre-Cutover Save Compatibility

Owner-approved follow-up starts at `9a050822314d05f21b14302d8bb1b828860e0f93` on the same
`phase/source-valid-new-game-entry` branch. Old-save A is **SUPERSEDED**, not erased from history.
See [Pre-Cutover Development Save Compatibility](DECISIONS.md#pre-cutover-development-save-compatibility).
The historical NGE5A sections below describe what was implemented and verified at that commit;
their schema1 compatibility statements are no longer the final branch contract.

### Removed because legacy-only

- Schema1 decoder/writer branches and supported-version constant; only schema2 is accepted.
- V1 representability checks and explicit v1 fixture writer (`versioned_save_fixture.gd` + UID).
- `PlayerBodyFacts.from_legacy_v1` and DTO current-strength missing-weight derivation.
- DTO default Player/20 identity reconstruction, old scalar capacity constructor argument and
  compatibility accessor. Player identity/body are explicit snapshots; missing objects stay null
  and validation rejects them rather than inventing facts.
- Successful v1 decode/Continue, v1 missing identity/body and divergent-capacity migration tests.
  A small unsupported-header test replaces that compatibility burden; unsupported-load rollback
  coverage verifies the current Session and input file remain intact.

### Retained because forward runtime

Strict schema2, typed revisions, exact identity/body/cloth/item persistence, four source residents,
all five Old Pine NPC states/tombstones, off-map corpses, RNG and allocator continuation remain.
PlayerBodyFacts remains independent of ordinary strength growth; death/carry read stored facts.
The real unarmed129 strength32/body80000/capacity150000 roundtrip regression is retained.
NativeItemStateSnapshot's independent internal schema1 is unrelated to game-root schema1 and
is unchanged, as are legacy LPC item import semantics and combat/skill definitions.

`LEGACY_OLDPINE_V1` temporarily describes the current technical New Game profile: explicit
schema2 identity Player/20, exp600, long sword, two residents. It is not a legacy reader. No
long-term promise is made; removal after NGE5B may be appropriate. `SOURCE_ENTRY_V1` is the forward
baseline. No public New Game cutover, Host/repository rewrite, new slots, migration UI, automatic
file deletion or owner-save cleanup is performed. Existing overwrite confirmation and explicit
Save can replace an unsupported development file using the unchanged transaction rules.

### NGE5A1 verification

Focused codec/source/technical/body regressions: 326 assertions, zero failures, exit0.
Complete canonical `run_tests.gd`: 17,747 assertions PASS, exit0. Godot4.7.2 headless editor
validation PASS. No complete-suite retry or stabilization fix was needed.
Historical NGE5A assertion counts below remain historical and are not rewritten as current counts.

Real desktop smoke reused the unchanged isolated `nge5a-live-source` QA profile, not owner saves.
QA setup supplied source female Player `续雪`, age14, food123/water234 and deterministic RNG.
Real move-right input moved her inside the Inn to `(73.3333358764648, 0)`; a real QA Save button
click used the production coordinator/repository. The game process stopped; a fresh
`nge5a_cold_continue.tscn` process used the real ApplicationShell Continue button.
The restored Session had four residents, five NPCs, twelve items and worn cloth; identity,
body80000/capacity150000, food/water and position matched the saved state. Player runtime object
identity changed. Allocator scope `oldpine-session-383fe4181fcc9f6e8fcfb20ef06489ab` and next1
were exact, as were RNG states (combat `-7542915721565470398`, NPC `-1136062569884875933`,
world interaction `-6705295025768092158`). Read-only probes inspected results; they did not
invoke Save/Continue or relocate the Player. This was the required forward-path smoke, not a
repeat of the historical complete route or a claim of technical-profile live coverage.

Godot AI reported helper_live/session_active/game_capture_ready=true, no current-run errors;
post-Continue captures were non-stale with frames14312 ->15349. Both test processes stopped
normally. `git diff --check` and changed-file trailing-whitespace checks PASS. Source ES2,
build/CI/export, project.godot and owner-local Godot AI files are unchanged.

Distinct self-audit confirmed root-v1 branches/helpers/fixture writer are gone, while the
independent item schema and exact-body authority remain. No Host/repository flow was rewritten.
NGE5A1 implementation/verification PASS; await owner review. No PR/merge or NGE5B work.

## Historical NGE5A implementation and evidence

Everything below records the approved NGE5A implementation before the NGE5A1 owner decision.

## RESULT

Implemented on `phase/source-valid-new-game-entry` from owner-approved
`bab5ee45745dd96b516fd3bdc12071100b4bbf10`. NGE0–NGE5A0 remain approved.
NGE5A implementation, focused verification, complete canonical regression and real desktop
Save/cold Continue PASS. Await owner review; no PR or merge. NGE5B is not started.

## SCHEMA1 CONTRACT

`GameSaveSnapshot.LEGACY_SCHEMA_VERSION = 1`. Strict original root and Player JSON fields:
no `world_content_revision`, identity, or body object. Existing top-level Player
`maximum_encumbrance` remains in v1 JSON. Explicit v1 encode preserves that shape;
unknown fields and lossy identity/body requests fail closed. Formats other than 1/2 reject.
Historical fixtures now explicitly request v1 instead of confusing the normal writer with v1.

## SCHEMA2 CONTRACT

`CURRENT_SCHEMA_VERSION = 2`; every production `OldPineWorldSaveCapture.capture` writes it.
Adds root `world_content_revision` and Player `identity` / `body_facts`. Both versions use
strict field lists, existing decimal-string int64 encoding, finite-position checks, and
the existing internal `NativeItemStateSnapshot` v1. Unknown fields are not retained.
Missing/unknown v2 revision, missing identity/body, unsupported race and incompatible legacy
identity reject. No permissive migration framework, second inventory DTO, or metadata bag.
`session_kind = oldpine` and slot `default-v1` are unchanged.

## WORLD CONTENT REVISION

Typed `WorldContentRevision.Value` has exactly two contracts:

- `LEGACY_OLDPINE_V1`: existing Outdoor + Cave and legacy technical identity.
- `SOURCE_ENTRY_V1`: Snow Inn + Snow Outdoor + existing Old Pine Outdoor + Cave.

Wire values use those exact names. V1 implies legacy solely because it is v1. No inference
from exp, items, name, date, commit or location. V2 legacy never gains Snow. Unknown revision
cannot fall back to a default. Build metadata is not a world revision.

## SESSION CONTENT PROFILE

Session stores the revision separately from bootstrap mode. Technical NEW_GAME selects legacy;
SOURCE_ENTRY selects source; RESTORE adopts the snapshot revision. Existing technical bootstrap,
five-NPC definitions, loadouts and RNG draw order are unchanged. Source fresh initialization is
not called by restore. The source-map registration helper is shared by fresh and restore paths;
only the former activates the Inn birth location.

## PLAYER IDENTITY PERSISTENCE

`PlayerIdentitySnapshot`: display_name, title, age, race_id. Gender remains in CharacterState.
V1 supplies Player / empty title / 20 / human; v2 captures exact facts. Current supported race
is human, with the existing nonblank-name/nonnegative-age validity contract; no aging or race
framework. Legacy revision requires its technical identity. Source title 普通百姓, name 续雪,
age14 and female gender were preserved through actual cold Continue.

## PLAYER BODY FACTS PERSISTENCE

`PlayerBodySnapshot` stores body_weight and maximum_encumbrance. The convenience DTO capacity
accessor delegates to that one object; v2 JSON has no duplicate top-level Player capacity.
Restorer constructs a fresh `PlayerBodyFacts` directly from stored values, never strength.
Signed int64 values remain permitted under NGE5A0; no new clamp or positivity rule.
Registered unarmed128 ->129 raises source strength30 ->32 while body80000/capacity150000
remain exact through capture, codec and fresh restore. Player death facts use restored identity
and body; corpse cross-validation no longer assumes Player20 or re-derived current-strength weight.

## V1 BODY INTERPRETATION

The v1 decoder/legacy DTO constructor interprets missing weight once using the existing
`CharacterDerivedValues.human_weight(saved_strength)`; saved capacity is copied exactly.
V1 str32/capacity150000 -> body84000/150000. Duplication preserves the resulting body object
values, and v2 decode always supplies its explicit body snapshot. Post-restore ordinary strength
growth does not refresh body. Explicit v1 encoding rejects a body weight it could not represent.
This implements the already-approved NGE5A0 decision; DECISIONS has no new delta.

## LEGACY FORMAT UPGRADE

Repository load, preview and normal Continue do not write files. Tests compare exact bytes.
Only an explicit new production Save upgrades a restored v1 Session to schema2/LEGACY_OLDPINE_V1.
No source rebirth, age14 conversion, cloth grant, resource refill, location migration or extra maps.
Repository primary/tmp/bak names, rotation and recovery behavior are unchanged.

## ITEM / CLOTH PERSISTENCE

The existing Old Pine definition projections accept a narrow revision input. Source adds exactly
the existing `SourcePlayerCloth` item/armor definition (`es2:obj/cloth`); legacy projections do not.
All existing playable Old Pine item and corpse definitions remain. No new authored items.
Existing Phase4 capture/restore owns Inventory/Combined/Equipment/Armor. Exact restored equipment
and armor objects are injected into Player/NPC state. Cloth remains directly owned and worn;
empty hands stay empty. Same semantic item IDs have fresh runtime ItemInstance objects.

## SOURCE CAPTURE

Capture uses the active Player body for exact physical position but always reads NPC/corpse
authorities from the resident Outdoor, including when it is detached and Player is in Snow.
Before saving it checks the Player position against the active map's production geometry.
It uses the existing production coordinator, eligibility and repository. No direct JSON writer
was added to runtime. Active encounter and other transient save gates are unchanged.

## SOURCE RESTORE

Existing restore composition creates a fresh authority graph, then the Session stages either
two or four residents. Source staging registers the existing physical Snow/Old Pine passages.
Only the saved active map is attached for activation; exact saved coordinates are assigned before
placement validation. There is no initial Inn activation followed by teleport. Inactive maps
remain detached/staged and bind the same Player. No bootstrap items, NPC factory rerolls, corpse
construction callbacks or new allocator draws. Host remains the sole current-Session authority.

## SNOW POSITION RESTORE

Inn main floor and all five Outdoor route zones are supported. The existing placement validator
now accepts the neutral resident-map boundary and discovers Snow's actual WorldPhysicalZoneArea2D
collision nodes. It checks zone membership and static-collision footprint without copying room
coordinates into another table. Region/map/zone/combat-location remain the one location contract.
Unknown/inconsistent locations, nonfinite points and out-of-bounds positions fail closed.
Focused coverage restores every Snow zone; live proof restores a non-spawn Square position.

## OLD PINE POSITION RESTORE

Existing Outdoor zone/collision and Cave passage validation remains. Source and legacy revisions
both use it. Source North Approach and Cave are covered by focused fresh-graph tests and second
encode/decode/cold reconstruction. Live North Approach restore was exactly (450,-354.333404541016).
No Cave content expansion or unsupported Cave-zone fallback.

## NPC OFF-MAP STATE

Exactly five authored Old Pine ledger entries remain, including dead tombstones. Tests compare
the entire re-encoded NPC record set (stable identity, character/skills/progression/resources,
life/existence, body, position and live loadout IDs), not just count. Snow has no added NPCs.

## CORPSE OFF-MAP STATE

A focused source-Inn fixture contains the existing fat-bandit tombstone, corpse, worn leather and
nested item graph in detached Outdoor. Fresh restore and source recapture preserve entire corpse,
NPC and item records. The fixture now uses the saved next sequence instead of hardcoded dynamic0,
which belongs to source cloth. No live kill was required or claimed for this fixture.

## RNG / ALLOCATOR

All three existing random-stream snapshots and allocator scope/sequence continue unchanged.
No gameplay random stream selects revision, identity, body, placement or cloth identity.
Focused tests assert all three RNG states, exact allocator continuation and item IDs; live proof
compared int64 strings, avoiding JSON floating-point rounding in debugger output.

## APPLICATION CONTINUE

No production ApplicationShell/Host/New Game code change. The normal Continue operation already
uses the versioned repository and restore composition. Tests exercise v1 and source through Host,
including destruction followed by cold Continue; actual desktop proof uses the real menu button.
Public New Game remains Player20 / exp600 / long sword / two maps / 12 bootstrap items.

## REPOSITORY SAFETY

Invalid v2 identity rejects before file rotation; existing backups survive. Unknown revision
cannot load. Production capture rejects invalid Player placement before repository writes.
All existing repository corruption, tmp/bak, transaction and recovery regressions pass.
QA uses only `user://save-data/tests/nge5a-live-source`; owner development/release saves are untouched.

## FAILURE ROLLBACK

Candidate validation occurs before current-session suspension. Invalid revision load retains
the current Session. Existing full rollback matrix passes. No fallback empty Host, replacement
technical New Game, or partial source profile is used on restore failure.

## LIVE DESKTOP

Godot4.7.2, Godot AI helper/session/capture live. Bounded QA launches source with female 续雪,
food123/water234 and deterministic seeds before the route; maxFPS60 for repeatable input.

1. Run16: real move-right crosses Inn -> Square; further right/down reaches
   (100.666709899902,73.3333358764648). Real click on a QA-only Save button invokes the production
   coordinator/repository, outcome0. No codec/direct file write in the acceptance route.
2. Stop the actual game process. Run17 starts unchanged ApplicationShell with the isolated profile.
   Real Continue click restores that exact position, source identity/body/resources, cloth/empty
   hands, all12 IDs, scope and sequence1. Old Session190756948055 becomes402418305784;
   Player -9223371843027597076 becomes -9223371651784111357.
3. Exact random states before/after: combat -7542915721565470398;
   NPC -1136062569884875933; world -6705295025768092158.
4. Real movement after Continue traverses Square -> south/east route -> eroad3 -> Old Pine North.
   Same Session/Player, four residents, one active map, camera enabled, five NPCs.
5. Real Escape -> Pause -> Save displays “Your journey was saved.” Stop process again.
   Run18 real Continue restores North at (450,-354.333404541016), with source profile/identity and
   food123/water234 unchanged. Runtime tree is ApplicationShell -> Host -> SessionSlot -> Session;
   staging slot empty, active slot has one map.

Screenshots were non-stale; run17 frames321 ->2360 ->9435 ->16669 advanced. Runs16–18 launched with
`current_run_errors=[]`. Editor cursor15 remained clear through the player route. Initial run15
encountered stale editor script-cache diagnostics after the multi-file edit; stop+filesystem scan
resolved it, with no production workaround. A later optional inspection-only eval had a compile
error; it did not execute or alter state and is not gameplay evidence.

## COMPLETE CANONICAL

- Focused `run_nge5a_tests.gd`: **399 assertions /0 failures**, exit0.
- Complete `run_tests.gd`: **17,820 assertions PASS**, exit0; final log has no script/runtime errors.
- Development headless editor, sanitized headless editor and sanitized canonical main startup PASS.
- Repository/static checks, `git diff --check`, changed-text trailing whitespace: PASS/0.
- Unchanged sanitizer retains production schema/revision/Snow/restore/Session files and removes QA,
  tests and Godot AI. Prepared from tracked plus new nonignored repository files to exclude the
  existing owner-local ignored plugin update backups; those remain untouched.
- Reference/es2, DECISIONS, build/CI/export, project.godot and public New Game delta:0.

Ignored local logs: `build/nge5a-focused.log`, `build/nge5a-canonical-final.log`,
`build/nge5a-editor.log`, `build/nge5a-sanitized-editor.log`, `build/nge5a-sanitized-startup.log`.
Initial failures were obsolete v1-only expectations and QA fixture/method assumptions; none were
hidden by weakening the supported gameplay contracts. No new LPC mechanic/formula was ported;
NGE5A0 source/body decision and existing source content definitions remain authoritative.

## OUT OF SCOPE

No public source New Game cutover, name/gender UI, source birth reroll, save-location/content
upgrade, new Snow population, supply/shop/training systems, Lake, serpent or Phase5B4. No mobile
testing, new save slots, settings changes, build/CI changes, PR or merge.

## NGE5B READINESS

Source Save/cold Continue and legacy v1 Continue are ready for owner review. Public source New Game
cutover remains a separately authorized NGE5B slice, not implemented by this readiness statement.
