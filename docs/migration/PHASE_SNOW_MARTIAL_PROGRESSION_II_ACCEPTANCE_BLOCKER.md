# Snow Martial Progression II — P2 Natural Acceptance Blocker

## Verdict

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW.**

The implementation/local gates pass. The required natural EXP6 journey did not
complete: the sole fresh player became unconscious in its first Bandit03 encounter.
This is a failed acceptance attempt, not proof that EXP6 is impossible, and not a
confirmed Liuh-Ken implementation defect. Tool input/observation timing contributed
to the failure; that limitation is recorded below rather than attributed to balance.
The finish has not been lowered. No balance fix, state injection, save edit or retry
of the lost journey was performed. No Final Audit is authorized by this result.

## Immutable identities

- Phase: `phase/snow-martial-progression-liuh-ken`.
- P1 parent: `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd`.
- Implementation: `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401`.
- Immutable pushed live implementation: `81d0cb63da15f9e384392de98cbaa3fd21475a51`.
  This second commit removes only two final blank lines from the shared validator;
  it corrects the staged new-file whitespace finding without rewriting history.
- Base main: `36a26b13e2bdebeb44c14c0a013d509000c29476`.
- Live process PID 34380; helper run `r572556130-4`; Godot 4.7.2 Steam.
- No production/test/config edits occurred after the live run began. Later changes
  are this evidence and current-status documentation only.

## Actual route and state evolution

The canonical ApplicationShell main scene, development storage profile, was launched
from the existing editor. Public New Game was clicked and its existing-save notice
confirmed. Name 林清 was supplied with Unicode InputEventKey events to the focused
LineEdit, male and Start Journey through framebuffer button clicks. This was one
fresh gameplay journey, without QA birth stats, scripted RNG or discarded combats.
The preexisting saved journey was not overwritten.

| Observation | Evidence |
| --- | --- |
| Birth | `snow.inn`, physical `(0,0)`, EXP0, unarmed0, liuh0, no mapping, both weapon references empty, gin100, kee100/100 |
| Physical route to Liu | Walked east through the Inn exit, square, north street; closed school door stopped x370.993. Clicked Open, then walked through school2 to schoolhall `(1034.662,-403.333)` |
| Real panel | Both raw0 skills, learned0, costs22, effective0, potential99, EXP0; no mapping |
| Apprenticeship | Clicked existing Apprentice: “柳淳风收你为徒。你成为封山剑派第十四代弟子。” |
| Learn | Five real basic-unarmed button clicks total. After first three: raw2, learned0, gin55, available potential96. After five: raw3/learned0, EXP0, gin63. Final spent4: fifth click crossed the existing EXP rejection boundary rather than awarding a fifth improvement |
| Recovery before combat | Existing natural cadence during travel/inspection recovered gin to100; kee remained100/100. No Work/Bank/Buy/Eat/Water/Hockshop operation or resource injection occurred |
| Physical Old Pine route | Walked back through school gate to north street/square, down sroad1, east eroad1/2/3, south through production portal. Old Pine entry `(450,-350.667)`, EXP0/raw3/kee100/100 |
| Encounter approach | Walked to clearing `(600.334,529.333)`, then south into the actual aggression area at `(600.334,665.000)` |
| First combat observation | EXP0, raw3, gin100, kee45/effective71, ACTIVE and fighting |
| Terminal observation | EXP0, unarmed3/learned0, liuh0/learned0, no mapping; gin0, sen0, kee0/effective38/max100; UNCONSCIOUS; no active fight |

The retained receipt is `encounter:production:1`: exactly one encounter, 20 ordinary
opportunity events over logical times1–10 seconds, no tactical events, successful
world completion (outcome6/COMPLETED), result1/DEFEAT, resolution failure0/NONE.
The engine did not fail an attack chain or get stuck in an unresolved encounter.

| Event | Logical time | Damage received by Player |
| --- | --- | --- |
| 2 | 1s | 25, reverse attack |
| 7 | 4s | 30, ordinary forward attack |
| 10 | 5s | 34, reverse attack |
| 20 | 10s | 25, reverse attack; unconscious terminal result |

EXP remained0 throughout. The actual four progression draw/bound pairs retained in
these events are89/175, 76/145, 78/111 and60/99. They are inspection of committed
results, not new RNG draws. Exact Combat RNG changed from
`-9018574111121211479` at birth to `-7051549971471219022` at defeat;
WorldInteraction changed from `-323266751137631579` to `6425414248562580585` through
the real Learn operations; NPC remained `774805433455860127` in the inspected logs.

## Input timing limitation and stopping point

The approach sequence included `pause_game` through the helper's action-state
timeline. That API sets Input.action_press/release; it did not deliver the actual
key event used by the shell's pause handler. Consequently the game continued at
normal production cadence while inspection tool calls completed. A subsequent
framebuffer click at the observed Flee button did not register a tactical request
before defeat (receipt tactical count0). **Successful Flee is not claimed.**
Real Escape key events afterward did open Pause; they were too late to preserve
this character. This is not evidence of a defective Flee button or proof that a
human cannot escape promptly.

At stop, the game is paused for owner inspection. The active map is OldPineOutdoor
and the active Player Camera2D belongs to that map. `player_recovery_time_allowed()`
is false; independent source review confirms the existing cadence requires ACTIVE,
so waiting cannot naturally recover this unconscious character through that path.
No recovery rebalance or revival was introduced. Per the stop-loss instruction,
the failed run is retained and no new lucky run is substituted.

## Live evidence quality and tooling incidents

The accepted gameplay launch reported `current_run_errors=[]`, helper_live=true,
session_active=true and game_capture_ready=true. These health fields remained true
at the paused terminal inspection. Actual framebuffer observations were non-stale:
frames1166 (menu of an earlier pre-game launch), 10216 (street), 32262 (Old Pine)
and41146 (paused defeat); the gameplay frame counter later advanced to48693.
The game log contains no gameplay error. It reports the existing Windows warning
“Virtual keyboard not supported by this display server” during New Game submission;
physical Unicode input worked, and no mobile keyboard qualification is claimed.

Before this one character was created, a first editor launch caught an in-memory
old request_learn signature during script refresh; stop/scan/relaunch resolved it.
A later QA Unicode-input helper snippet used spaces inside the helper's tab-indented
wrapper and caused a compile break. It was corrected to tabs and the process was
restarted **before New Game created any character**. No production code was changed
for either tooling incident. A too-long movement timeline was rejected by the
600-frame API cap before execution and split into two normal input sequences.

Ignored local evidence: `build/smp2-live-evidence.json` preserves read-only snapshots,
all20 retained events with exact draw bounds/results, and the current-run log. It
is deliberately excluded from version control and release output.

## Acceptance accounting

| Criterion | Result |
| --- | --- |
| Complete deterministic implementation gates | PASS: focused283, canonical20,544, Python656; static/editor/sanitized PASS |
| Public source-valid New Game / actual physical Liu route / apprenticeship | PASS in this run |
| Natural basic Learn | raw0→3 observed; raw4 not reached |
| Natural EXP6 | BLOCKED / not reached; sole encounter ended EXP0 |
| Liuh raw5 and Enable | NOT REACHED; no liuh Learn or Enable was performed in this run |
| Real committed mapped-liuh action/text/RNG | NOT REACHED; covered deterministically only |
| Successful Flee and return to Liu | NOT REACHED |
| Save / terminate full process / fresh Continue | NOT RUN; existing save untouched |
| Exact live full-state/RNG restore and post-Continue mapped combat | NOT RUN; automated enabled/disabled persistence tests pass |
| Physical Android/iOS | Deferred to owner-authorized later Final Audit |

Implementation tests remain green; no production change followed them except the
two-blank-line correction. The blocker is the uncompleted live acceptance gate.
Owner review is required before another bounded natural acceptance attempt or any
change to the finish/route/balance. This report does not request or assume such a change.

**NO PR. NO merge. NO Final Audit. NO P3. NO Migration Tooling P3.**

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW**
