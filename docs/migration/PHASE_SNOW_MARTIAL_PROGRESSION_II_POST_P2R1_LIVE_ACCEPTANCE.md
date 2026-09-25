# Snow Martial Progression II — Post-P2R1 Live Acceptance

## Verdict and owner disposition

**BLOCKED BEFORE BOOTSTRAP — INCONCLUSIVE / ACCEPTANCE INPUT-SEQUENCE CAPABILITY GAP.**
P2 live acceptance remains OPEN. This is not a gameplay, Flee, survivability,
EXP6 pacing or Liuh-Ken defect and is not a P2R1 live regression.

The owner has approved and closed
[P2R1](PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md).
The approved executable/test freeze is `798842879ebea52b33e7e2136f606a3741659590`.
Its pre-existing source-entry / Player-death integration-defect classification
and narrow known-cloth repair remain accepted and unchanged.

The requested atomic real-input sequences cannot be expressed by the installed
`input_sequence` primitive. This was established by the connected tool contract
and its exact implementation before creating a Player. No bootstrap, gameplay
input, game_eval, new game process or acceptance encounter was started.

## Frozen identities and preflight

| Identity | Value |
| --- | --- |
| Branch | `phase/snow-martial-progression-liuh-ken` |
| Starting HEAD / fetched origin phase / approved freeze | `798842879ebea52b33e7e2136f606a3741659590` |
| Integrated main | `36a26b13e2bdebeb44c14c0a013d509000c29476` |
| P1 | `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd` |
| Original P2 implementation | `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401` |
| Previous executable freeze | `81d0cb63da15f9e384392de98cbaa3fd21475a51` |

Fresh fetch matched local/remote HEAD and integrated main. Worktree/index were
clean. Any-state phase PR search returned zero results.

The connected session inventory reported `game@97025dc50369cd37`, editor PID57724,
official Godot4.7.2, plugin/server4.0.4, readiness `ready`, canonical
`res://scenes/application/application_shell.tscn`, play state `stopped`.
`editor_state` confirmed game status `stopped`, helper_live=false,
session_active=false and game_capture_ready=false. These are expected for the
stopped game, not evidence of helper failure. No fresh runtime/framebuffer proof
or empty current-run error claim is made. The blocker is an input capability
mismatch, not an inferred connection/port problem.

## Exact capability evidence

The connected `game_manage` contract describes `input_sequence` as frame-timed
**action state** steps `{at_frame, action, pressed, strength}`. It does not expose
key or mouse steps and explicitly excludes running inside `batch_execute`.
The tracked implementation independently confirms this:

| Boundary | Current behavior |
| --- | --- |
| [game_helper.gd](../../game/addons/godot_ai/runtime/game_helper.gd), `_plan_input_sequence`, lines790–853 | Requires a nonempty String `action` on every step (lines821–823); normalizes only at_frame/action/pressed/strength (lines839–844). |
| Same file, `_run_input_sequence`, lines857–899 | Validates InputMap action names, then calls only `_game_input_action(step)` at line883. |
| Same file, `_game_input_action`, lines716–733 | Calls `Input.action_press/release`, reports `delivery="action_state"`; emits no InputEventKey or InputEventMouseButton. |
| Same file, `_game_input_key`, lines651–662 | Separate command creates InputEventKey and sends it via `Input.parse_input_event`. |
| Same file, `_game_input_mouse`, lines665–692 | Separate command creates and parses mouse events with framebuffer coordinates. |
| [batch_handler.gd](../../game/addons/godot_ai/handlers/batch_handler.gd), lines18–30 | Explicitly prohibits deferred `game_command` subcommands because no completion channel exists inside a batch. |
| [ApplicationShell](../../game/runtime/application/application_shell_controller.gd), `_unhandled_input`, lines246–282 | Pause/resume handles delivered input events; an action-state write does not supply that event. |

Consequently, neither authorized sequence can be represented:

- A: frame-timed movement/release followed by a genuine Escape press/release.
- B: genuine Escape press/release followed by a framebuffer Flee mouse click.

Using `action="pause_game"` would repeat the historical action-state/event
confusion. Adding invented key/mouse fields does not add dispatch support.
Sequential external tool calls still depend on transport latency; parallel calls
do not guarantee input ordering. Editor batching is explicitly unsupported.
No such substitute was attempted. No temporary script, input helper, plugin
change, evaluator input, gameplay callback or scheduler manipulation was used.

## Historical reuse and fresh acceptance coverage

The unchanged integrated [public New Game cutover](PHASE_NEW_GAME_ENTRY_PUBLIC_CUTOVER.md)
and [NGE Final Audit](PHASE_NEW_GAME_ENTRY_FINAL_AUDIT.md) remain the owner-approved
historical evidence for Unicode name input, gender UI and public setup behavior.
This task did not requalify typing or birth. PublicNewGameTestFixture was read
and left unchanged; its authorized one-time invocation was **not used**.

| Required fresh evidence | Actual result |
| --- | --- |
| Source birth and isolated fresh Player | NOT RUN; zero Players created, no prepared Save consumed |
| School route / real door / apprenticeship / Learn | NOT RUN |
| Encounter ledger / early pause / damage / Flee requests and results | Empty ledger; zero entered or completed encounters; timing unavailable |
| EXP evolution / recovery / finite36 contract | NOT RUN; no Player EXP or recovery observation |
| P2R1 live death behavior | NOT EXERCISED; no death, no regression conclusion |
| EXP6 / return / unarmed4 / liuh5 / Enable / effective unarmed | NOT RUN; no final skill or mapping values |
| Mapped Liuh action / bound4 / authored feedback | NOT RUN |
| Real Save / durable snapshot | NOT RUN |
| Old game PID termination / fresh game PID | Not applicable; no game process launched or terminated |
| Cold equality / post-Continue mapped combat | NOT RUN |

This preflight adds no evidence for a product defect, unsustainable survival or
stochastic reachability failure. The previous failed death is not balance evidence.

## Preservation, validation and delivery

Attempt1/2/3, the pre-P2R1 changed-path report and the P2R1 repair report are
preserved byte-for-byte. Only this distinct report, current runtime disposition,
STATUS and ROADMAP change. Executable/test/tooling/source/DECISIONS and Save
schemas remain identical to the approved freeze.

The docs-only gate passed repository/static checks, 212 changed-document relative
links/anchors, whitespace, exact four-file scope and protected-file identity.
All five historical report files matched the approved freeze's raw bytes.
The previously approved 2,282 focused / 20,608 canonical / 656 Python counts remain
historical P2R1 evidence; no new gameplay test or live run is claimed here.

Result subject: `Record post-P2R1 Liuh-Ken acceptance blocker`; normally pushed to
the existing phase branch. The final response records the resulting docs SHA,
remote equality and clean worktree/index. No PR or remote CI was requested; no
merge or integration is claimed. Owner review is needed to resolve the required
mixed real-event atomic input capability; this task does not authorize building it.

NO gameplay/code changes. NO balance change. NO Flee change. NO EXP change.
NO Save schema change. NO PR. NO merge. NO Final Audit. NO P3.
NO Migration Tooling P3.

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW**

## Recheck after owner update to Godot AI 4.2.3

At the owner's request, repeated the capability preflight after the owner update
commit `d9f6770a4dddb0b7fdc74e8a50ba6ff50964c150` (`godot AI update`). Fresh fetch
confirmed local/origin phase equality at that SHA, unchanged main
`36a26b13e2bdebeb44c14c0a013d509000c29476` and clean worktree/index.

The newly connected session `game@3efd0af432bc0526` reported plugin/server4.2.3,
Godot4.7.2-stable (steam), editor PID73616, readiness `ready`, canonical
ApplicationShell scene and play state `stopped`. Thus the update is active, not
merely present on disk. Custom-tool discovery returned zero tools.

The 4.2.3 tool contract still documents only action-state sequence steps. Direct
comparison of game_helper.gd before/after the update shows just the screenshot
HDR argument changed; `_plan_input_sequence`, `_run_input_sequence` and their
action-only dispatch are unchanged. The updated batch handler still forbids
`game_command` subcommands. The two required atomic real-key/mouse sequences
remain unsupported. No malformed sequence, separate latency-dependent fallback,
temporary script or gameplay callback was attempted.

Gameplay/test source remains identical to approved P2R1 when excluding the owner's
addon update and project.godot change. The owner update also removed explicit
1152x648 viewport defaults from project.godot; this recheck did not alter or restore
them and does not claim whole-development-project byte equality with P2R1.

No game process, Player, bootstrap, encounter, Save or Continue was started in
this recheck. All fresh gameplay gates above remain NOT RUN. P2R1 stays OWNER
APPROVED / CLOSED; this remains an acceptance-input capability blocker, not new
gameplay evidence. Only this report is extended; no code/tooling change is made.

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW**
