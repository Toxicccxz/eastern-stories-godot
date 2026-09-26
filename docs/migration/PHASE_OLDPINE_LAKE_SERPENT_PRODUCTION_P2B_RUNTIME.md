# Old Pine Lake + Production Serpents — P2B Runtime

## Disposition and identity

**P2B — IMPLEMENTED / TARGETED VALIDATION COMPLETE / AWAIT OWNER REVIEW**

**LAKE CURRENT-WORLD COMPOSITION — IMPLEMENTED**

**P2C / FINAL AUDIT / PR / MERGE — NOT STARTED**

Date: 2026-09-26. Branch: `phase/oldpine-lake-serpent-production`.
Implementation starts at P2A `1fcb17998717c3f9170a1a4dbb2604d3a3ab8a0f`, from integrated main
`01f7b18253a1936bce4a1fb11a507a356769c409`. The commit carrying this report is the P2B
delivery; preceding P1/P2A reports are unchanged. No separate phase branch or PR.
The owner authorized P2B implementation, scoped regression updates, this report and normal push.

## Source and fixed boundaries

Read/reused authoritative [lake.c](../../reference/es2/mudlib/d/oldpine/lake.c),
[serpent.c](../../reference/es2/mudlib/d/oldpine/npc/serpent.c),
[riverbank1.c](../../reference/es2/mudlib/d/oldpine/riverbank1.c),
and the inherited NPC/Beast/defaults and existing Fill chain identified by
[P1](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md).
The source paths above are relative to the repository root; see the linked P1 authority inventory.
Lake has one northern exit, five ordinary aggressive serpents and `resource/water=1`.
No poison, swimming, arbitrary shore water, invented drops, Cave/Keep, new martial art or rebalance.
The existing Beast factory, liquid service, combat resolver/scheduler and Flee policy are reused.
M/W remain locked by [P2A decisions](DECISIONS.md#old-pine-lake--owner-locked-p2a-foundations);
R remains CURRENT WORLD ONLY. DECISIONS and reference source are unchanged.

## Production changes

- `oldpine_outdoor.tscn`: Lake extends the existing continuous Outdoor map south of Riverbank1.
  Ground is x900–1500/y2200–3000; solid pool x930–1250/y2380–2870; west, east and south
  walls retain a northern route. The old Lake barrier is removed, not the surrounding world walls.
  Camera bottom is 3015. No new loading transition. Existing River/Cliff routes remain.
- World/spawn definitions add Lake zone/combat location and one INITIAL_ONLY five-slot group.
  Stable points `oldpine.outdoor.lake.serpent.1` through `.5` bind five authored physical bodies
  at (1340,2470), (1430,2505), (1340,2545), (1440,2590), (1350,2640).
  Each has its own presence shape. No BF4 publication/helper is used by production.
- Outdoor initialization appends those five after scouts/Tall/Fat, using the existing source
  Beast factory and NPC RNG in stable order. Each serpent requests only cps/per/con bounds
  `[11,31,41]`; five add 15 draws. No Combat/World RNG initialization change or new stream.
  Identity, independent body/state and absence of loadout/reward items are checked.
- Restore binds all ten existing records to authored bodies, including dead slots; no fresh
  factory or default repair. Rebinding/activation does not duplicate NPCs. Existing corpse,
  allocator and item graph authorities are retained.
- Lake automatic aggression and manual Attack use the P2A complete-set transaction. Contacts
  are synchronously checked before freezing; same-zone membership alone cannot admit an NPC.
  Consumed contacts survive thaw, and actual separation permits reentry. Non-Lake pair admission
  is unchanged. No coordinator/scheduler/resolver/Flee implementation change.
- Runtime location and Save placement share half-open center ownership at y2200. Early Area
  overlap cannot assign the other zone before the physical center crosses. Pool and perimeter
  collision remain Save-invalid, with seam positions 2199/2200/2201 covered.
- Shore marker (1100,2325) adds Fill through existing `HeldLiquidUseService`. The direct-held
  instance, ACTIVE/busy/combat, actual distance96 and legal placement checks remain authoritative.
  Lake Fill and Waterfall Fill share the same UI/service; no new liquid authority.

Key production files are the Outdoor scene/controller, `oldpine_spawn_definitions.gd`,
`oldpine_world_definitions.gd`, placement/restore composition, `world_content_revision.gd`,
codec, Session/Vine/Inn consumers and `held_liquid_panel.gd`.

## Current contract and consumer review

Public `WorldContentRevision.CURRENT_PUBLIC` is now **SOURCE_ENTRY_LAKE_V1**.
Root schema2/item schema3 are unchanged. SOURCE_ENTRY_V1 and LEGACY_OLDPINE_V1 remain recognized
metadata but public canonical/backup/temp paths explicitly refuse them without rewriting bytes,
adding missing entities, automatically starting New Game or retaining a closed five-human world.
Unknown marker, current malformed content, I/O and unsupported schema remain distinct failures.

The reviewed source-entry consumers are: source birth revision; Snow map restore eligibility;
source cloth, money, dumpling and wineskin definitions; Inn purchase projections; food/liquid UI;
source recovery cadence; and the approved nonpositive-dodge Vine branch. Their checks now refer
to the current public contract. A changed marker does not disable these unchanged mechanics.
The frozen old Snow P1 file still exercises raw decode/affiliation semantics, but public support
now asserts explicit refusal rather than promising successful restoration of its old catalog.

## Tests and separate implementation review

Owner-authorized layered policy is recorded in root AGENTS.md and the current roadmap.
The existing P2A runner has bounded `--lake-only` and `--lake-regressions` selections; canonical
registration still includes every existing test plus the new Lake integration. No generic runner
platform, skipped CI gate or removed mechanism coverage.

`oldpine_lake_production_test.gd` checks current birth/ten identities, handoff/no extra RNG,
real authored bindings, seam/collision validation, five actual contacts/manual fifth target,
Flee/contact separation, normal and wounded/dead/corpse full encoded roundtrips, old primary and
backup/temp refusal with unchanged bytes, shore Fill and Waterfall regression. Typed placement,
money, damage and scheduler setup in this test are integration preconditions, not real-input proof.
Existing restore tests retain malformed ledger, rollback, placement, atomic and RNG coverage.

The broad marker/catalog change justified **one** full gameplay discovery run. It found stale
three-group/five-NPC counts, closed-Lake expectations, old public-world success expectations and
a restore test assuming sorted slot0 had human loadout. Those expectations were updated to the
current contract; the loadout adversary now selects a human by definition/identity. Existing BF4
still adds a QA-only extra slot (unpublishable); its fixed courage bound changed 30→18 because the
five production serpents consume their source NPC draws before that extra QA serpent is created.
The Combat draw script/formula is unchanged. All discovered failed groups were rerun successfully.

Separate content review confirmed: Game Core remains position-independent; actual contact/zone
and collision checks stay in runtime; presentation owns no outcome or RNG; strict current ledger
validation is not weakened. No new runtime QA helper is introduced; existing BF4 test guards only track the changed catalog.
No plugin, CI, source, Save format, combat formula, Flee policy or historical migration tooling
modification is introduced.

## Executed validation

Commands use official `build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe`.
Logs are ignored local evidence under `build/`; they are not committed artifacts.

| Command / check | Result and elapsed time |
|---|---|
| `--headless --path game --editor --quit` | PASS, 8.39s; initial import/parse gate |
| `--headless --path game --script res://tests/run_oldpine_p2a_tests.gd -- --foundations-only` | PASS; reused during development; elapsed time not retained |
| `--headless --path game --script res://tests/run_oldpine_p2a_tests.gd -- --lake-only` | PASS, 1.07s reported suite time |
| `--headless --path game --script res://tests/run_tests.gd` | Discovery run exit1, 7m32.46s; 18 assertion failures and one test script error described above; **not a full-suite PASS** |
| `--headless --path game --script res://tests/run_oldpine_p2a_tests.gd -- --lake-regressions` | PASS, 101.12s suite time; all 16 affected groups, zero failures and no script errors |

Affected groups: serpent definition, world definition, spawn foundation, Lake production,
world restore, Beast integration, Outdoor smoke, portal aggression, River/Cliff route,
Snow first progression, Snow water, player recovery cadence, public source New Game,
Snow/Old Pine connection, versioned source Save and Beast/human Save regression.
The full suite was not repeated after these scoped corrections. No full Python, migration-tool
audit, exports, sanitizer run or final canonical `verify.py` is claimed for P2B; final canonical
verification remains required at phase closure. Final static/doc results are recorded below.

## Real canonical runtime smoke

Official Godot4.7.2, unchanged Godot AI4.2.3, canonical ApplicationShell. Isolated APPDATA under
`build/p2b-live/AppData/Roaming`; actual user-data suffix
`Godot/app_userdata/Eastern-Stories-Godot/save-data/development/default-v1.json`.
The isolated profile began without a Save or Session. Normal owner Save files were untouched.
LOCALAPPDATA stayed normal solely for the existing plugin transport capabilities; no credentials
were copied. Earlier isolated-editor transport startup failures were resolved without plugin or
gameplay changes. Debug port6107 was used as workstation tooling, not a gameplay decision.

Disclosed QA **before** route: existing PublicNewGameTestFixture creates valid source female 凌雪;
Player vitality current/effective/maximum set to100000 for safe input observation; existing finance
fixture supplies one silver/100 coins and existing purchase service supplies one red-wine wineskin.
No skills, EXP, NPC health or Combat/World/NPC RNG injection. This does not qualify real name typing,
natural progression, survivability or winning against five full-strength serpents.
After this precondition, route actions use real input, not gameplay callbacks/state assignment.

1. Frame-timed physical movement: Inn → Snow streets/east route → Old Pine north → East Bridge.
   Real vine selection/Hold Vine UI uses existing source dodge0 branch → Waterfall. Physical east
   bank walk reaches Lake at (1438.331,2206.327), without a Lake portal or teleport.
2. Actual Escape opens Pause; actual Save button reports **Your journey was saved**. Main-menu
   Continue restores ten authored NPCs and the saved item scope/location. Initial live inspection
   found the camera retained old bottom2230; it was corrected to3015 and verified after Continue.
3. Actual movement to (1097.343,2323.663) exposes Fill. The actual Fill button returns FILLED (9),
   discarded_wine=true, preserving wineskin ID
   `oldpine-session-df48abe5a1926a9ed5ae0d76ab45793a.dynamic.1` and replacing wine with15 clear water.
4. Subsequent clean runtime `r933207-3` starts by actual Continue from that real Save, not a new
   fixture. Along x1438.331, contact entries occur near y2261.328,2279.662,2334.663,2363.997,
   2426.332 with respectively 1,2,3,4,5 eligible serpents. Encounters have 2–6 participants.
   Out-of-range Lake bodies are not pulled in. All five remain independently visible/bound.
5. Actual Flee buttons restore world control. At five contacts, existing horizontal scrollbar
   exposes the fifth card. Real Tab/Enter on `Participant5/SelectTarget` changes authoritative
   target to `oldpine.outdoor.lake.serpent.5.character`. Frame47555 shows **Target: Changed** and
   the fifth card's gold current-target border, `stale_frame=false`; no Battle UI changes.
6. Real Flee completes, then movement returns north to Riverbank (1438.331,2180.660). Physical
   reentry produces a fresh encounter and progresses to all five again. Original stationary thaw
   did not immediately restart combat. Final Flee returns no active encounter, open world gate;
   completion outcome6 (COMPLETED), terminal kind3 (DISENGAGED). Physical exit ends at
   (1438.331,2176.993), empty opponent/lethal-target arrays; actual Escape pauses before shutdown.

Health: helper_live/session_active/game_capture_ready were true; framebuffer frames6501,12661,
16587,31078,47555 advanced with stale_frame=false. Final clean-run game log contains only info,
no runtime errors. NPC RNG stayed `-6195616932558569798`, World RNG `9129066360235789054` across
this combat route; Combat RNG changed through actual combat, ending `-798786263622076983`.
Restored Session in the final run is952794877241; persisted scope is unchanged. These observations
are read-only state reads, not commands producing game outcomes.

Evidence limitations are explicit: one earlier QA expression dereferenced a null completion
receipt before it existed, triggering debugger break. That run was stopped; the existing real Save
was normally Continued into the clean run above. Some framebuffer mouse press/release attempts did
not register; no target/Flee success is inferred from sent=true. Native UI keyboard activation
provided the fifth-target result and subsequent Flee evidence. Neither issue was patched in product
code. No full process-restart/equality qualification is claimed from these editor stop/run cycles.
Total live work spans setup/diagnosis and resumed smoke; no single benchmark duration was retained;
the final clean run observed about702 seconds. This is functional evidence, not a timing target.

## Remaining acceptance and integration

P2C retains formal full-process cold Continue with exact durable equality and applicable lifecycle/
interaction proof not already covered here (including representative real corpse/death persistence).
Manual Attack complete-set wiring is covered by the targeted integration test; live entry here is
automatic aggression. Mouse-only fifth-card operation was not conclusively qualified; native
keyboard UI was. Natural novice victory/balance and natural EXP pacing are not P2B claims.
No known product blocker remains in the executed P2B scope. Broader canonical coverage is pending,
not silently converted into a PASS by layered testing.

No PR, remote CI, merge, P2C, Final Audit, Phase5B4 or Migration Tooling P3 started.
Current branch is implementation-complete for this slice, not integrated on main.

## Final static and repository checks

- Bundled Python3.12 `-X utf8 tools/ci/repository_checks.py --repository .`: PASS, 0.23s.
- `-X utf8 build/p2b-doc-check.py` (bounded adaptation of the existing ignored document checker):
  PASS, 0.15s; six changed/new documents and312 relative link/anchor occurrences, zero errors.
- `git diff --check`: PASS. `project.godot` equals the starting HEAD; the editor's automatic
  removal of explicit1152×648 viewport settings was restored before delivery.
- Fresh fetch confirms phase base remains `1fcb17998717c3f9170a1a4dbb2604d3a3ab8a0f` and main
  remains `01f7b18253a1936bce4a1fb11a507a356769c409`; GitHub all-state phase PR search returned none.
- No delta under `reference/`, `.github/`, `game/addons/`, DECISIONS or historical P1/P2A reports.
  Test logs, isolation data and local checker remain ignored under build. No generated artifacts
  or Save files are staged. Runtime/editor were stopped after evidence collection.
