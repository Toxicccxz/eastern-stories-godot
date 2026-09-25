# Snow Martial Progression II — Live Acceptance Attempt 2

## Owner disposition and result

P2 IMPLEMENTATION / LOCAL VERIFICATION: **OWNER APPROVED / FROZEN**.
P2 LIVE ACCEPTANCE: **OPEN**.
Attempt1: **INCONCLUSIVE / OPERATIONAL-CONTROL FAILURE**, as explicitly reviewed by
the owner. Its report and ignored evidence remain byte-identical; it establishes no
Liuh-Ken, Flee, balance or EXP6 impossibility defect.

Attempt2: **BLOCKED — OPERATIONAL INPUT FAILURE**. One fresh Player reached natural
EXP1 in its first encounter. Real Escape successfully froze that encounter. My
subsequent QA input snippet declared `key` twice in one scope and failed compilation
before its Resume or Flee events executed. This is an acceptance operator/tooling
failure, not a confirmed production implementation, survivability or pacing defect.
The attempt stopped; no replacement Player was created and no balance was changed.

## Frozen identities and preflight

| Identity | Exact value |
| --- | --- |
| Branch | `phase/snow-martial-progression-liuh-ken` |
| P1 | `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd` |
| Primary implementation | `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401` |
| Executable/test freeze | `81d0cb63da15f9e384392de98cbaa3fd21475a51` |
| Starting local/remote HEAD | `a1d1c30c5da53e131bfa31f5604b5939b0bf4b92` |
| Main | `36a26b13e2bdebeb44c14c0a013d509000c29476` |

Fresh fetch matched these identities. Freeze-to-HEAD delta was exactly the four
authorized documents: Attempt1 blocker, runtime report, STATUS and ROADMAP.
Tracked worktree/index were clean. No phase PR was found in any state.
`game`, `tools` and `reference` compared equal to the executable freeze, including
all production, tests and tracked project/build/CI configuration. No implementation
or DECISIONS changes were authorized or committed for this attempt.

Attempt1 PID34380 was already absent at preflight; the editor also reported stopped.
No revival, resource refill, old-save restore or reuse of that timeline occurred.
Preserved raw SHA-256:

- Attempt1 report: `e4df830035a155b5d2464b4f210c73eec25ea5de6b1b7d09aa2b2e2e70fa2b63`.
- `build/smp2-live-evidence.json`: `294c16afb7335bf0c74f9ce83d42cc1e78e90e6e66f70c56f377a299fa7a501b`.

## Isolated storage and preparation incidents

The actual Player ran in Godot4.7.2 official, PID62080, on the canonical
`res://scenes/application/application_shell.tscn`. Its user-data root was the isolated
`build/smp2-attempt2-env/roaming/Godot/app_userdata/Eastern-Stories-Godot`.
The development save profile was unchanged. The public menu showed no saved journey;
SessionSlot child count was0 before public New Game. No prepared save was injected.

Preparation required diagnosing the existing development tool connection:

1. Isolating both APPDATA and LOCALAPPDATA hid the existing tool authentication
   record from a second editor. That editor did not connect and was normally closed.
2. Each newly launched official editor automatically omitted the two tracked default
   viewport-size settings. The exact two-line incidental change was inspected and
   reversed to HEAD bytes before creating the Player; no other change was restored
   or hidden. The saved diagnostic copy remains ignored under the isolated build
   directory. Production/config/test differences were zero before the journey.
3. Keeping LOCALAPPDATA unchanged while isolating APPDATA allowed normal tool
   authentication. Editor PID57724 listened on6117. Project-added6107 overrode its
   generated game argument, so the playable isolated process was launched explicitly
   with6117. An editor-launched menu-only process PID50668 remained as the editor's
   play session; it never created a Player and was stopped during cleanup. PID62080
   was positively read from the helper before New Game, throughout gameplay and
   before the failed operation. No input or gameplay evidence is attributed to the
   menu-only process.
4. The server briefly disconnected/reconnected during safe Snow traversal. The same
   Player/process resumed inspection, still EXP0 and out of combat; actual position
   was re-read before further movement. No character restart occurred.

These incidents did not justify changing production configuration or gameplay.
No tracked game/test/tool/config bytes changed during the claimed Player timeline.

## Sole fresh Player and physical route

Public New Game, focused name-entry Unicode key events, male selection and Start
Journey framebuffer clicks created 林清. Initial read-only state/log/snapshot evidence:

- Snow Inn `(0,0)`, age14, all eight base attributes30, gin/kee/sen100/100/100.
- EXP0, potential99, spent0, no skills, mappings, family, master or class.
- Authored cloth equipped; primary and secondary weapon references both absent.
- Session object273099524688; Character object`-9223371761775539518`.
- Combat RNG`-20446870830579194`, WorldInteraction RNG`-6292611666605796297`,
  NPC RNG`3276959579382216269`; no QA replacement or extra inspection draw.

The later pre-training encoded snapshot was captured at Snow square after physical
Inn exit; location was therefore square and naturally elapsed food/water were399,
not a claim that this snapshot was the exact birth instant. Birth map/position and
resource evidence were separately read before travel. No save file was written.

Real movement followed Inn → square → mstreet1 → school1. Closed-door collision
stopped the Player around x370.997; real Open and walking through school2 reached
Liu in schoolhall. Actual panel clicks established the existing apprenticeship.
Five real unarmed Learn requests naturally reached raw3: first three reached raw2,
fourth added progress without another level, fifth reached raw3. The raw2 observation
caused a physical return from south street to finish training rather than a grant.
Liuh remained unlearned and unmapped. Gin was64 after final training and naturally
recovered to100 during the subsequent travel; no resource setter, Work, supplies,
time acceleration or custom RNG was used.

The same Player physically walked back to square/sroad1, east through eroad1/2/3,
then south through the production portal. Old Pine entry was `(450,-350.667)`.
It walked to `(600.334,532.999)` before a short downward movement entered the real
Bandit03 aggression area at `(600.334,672.333)`. No encounter constructor, portal
callback, location setter or teleport was used.

## Correct real-pause proof

The input path constructed actual pressed/released InputEventKey values with
KEY_ESCAPE and delivered them through Input.parse_input_event. It did not use the
helper's `pause_game` action state, a shell callback or a direct pause assignment.
An initial safe Inn pause/resume verified the route before combat.

After the first meaningful attack opportunity, the same real Escape path paused
the first encounter **before** expensive inspection. Two independent observations:

| Frame | Actual paused | Scheduler time | Event count | EXP | Kee current/effective | Combat RNG |
| --- | --- | --- | --- | --- | --- | --- |
| 28798 | true | 1s | 2 | 1 | 78/79 | `-4293924811956605127` |
| 29032 | true | 1s | 2 | 1 | 78/79 | `-4293924811956605127` |

The frame counter advanced while scheduler time/events and RNG stayed fixed. This
is a successful pause-control observation; it does not establish successful Flee.
Before the later QA error, helper_live/session_active/game_capture_ready were true.
The earlier menu framebuffer was non-stale at frame2125. This run had the existing
Windows virtual-keyboard warning on public setup, with successful actual name entry.

## Per-encounter evidence and finite stop

| Encounter | EXP before→after | Pre-encounter kee | Damage received | Flee | Result | Recovery before next |
| --- | --- | --- | --- | --- | --- | --- |
| 1, production Bandit03 | 0→1 | 100/100/max100 | 22 from genuine reverse attack | No request executed; tactical events0 | ACTIVE/fighting, paused at time1/event2; no completion | No next encounter; stopped operationally |

Retained event1: Bandit03 ENTERED_GUARDING, bounds`[90,5]`, draws`[33,4]`.
Event2: Player ATTACK_CHAIN_COMPLETE, default unarmed attack dodged, genuine reverse
damage22. Exact committed bounds:
`[78,1,16,601,30,1,16,601,601,15,19,22,178]`;
draws:`[16,0,6,202,7,0,7,483,553,0,11,10,9]`.
The EXP increment's retained progression draw was9 below178. Inspection performed
no new draw. Resolution failure was0/NONE; no terminal result yet existed.

Counts: **1 started encounter, 0 successfully completed encounters, 0 successful
Flees, 0 later encounters**. The 36-success limit was not exhausted. EXP6 pacing and
survivability under a successful Flee procedure remain untested, not failed.

## Exact operational failure

While the real game was already paused, I assembled one QA operation intended to
send real Escape to resume, immediately click the observed Flee rectangle
`(28,483)` size`(166,64)`, then verify acceptance and pause again if necessary.
The two copies of the Escape snippet both declared `var key` in the same scope.
Godot rejected the entire temporary helper script before executing any input:

`Parser Error: There is already a variable named "key" declared in this scope.`

Therefore the intended Resume and Flee click were **not executed**. The error is
in my temporary acceptance script, not a tracked game script. The debugger reported
`status=break`, `can_debug=false`, `helper_live=false`. A tooling resume attempt
returned changed=false; process-loop proof stayed false, tree_paused=true and frame
33346 unchanged. This cannot be reported as a working live helper or a successful
Flee queue/execution path. No in-combat experiments were continued after this stop.

The operator stopped the editor-launched menu process normally. Normal window-close
did not release PID62080 from the compile break, so the owned test process was ended
after preserving evidence. PID62080, menu PID50668 and historical PID34380 were
verified absent. This cleanup is not the required successful Save/cold-Continue
termination gate: no Save had occurred. No replacement Player was created.

## Uncompleted gates and retained evidence

Natural EXP6, return to Liu, raw unarmed4/liuh5, real Enable, effective mapped value,
mapped-liuh combat/text/bound4, optional weapon transition, successful Flee/retreat,
between-encounter recovery, Save/full process restart/Continue, durable/RNG equality
and post-Continue combat are **NOT REACHED**. No production, Flee, balance or
stochastic reachability defect is established by this operational interruption.

P2 implementation/local verification remains OWNER APPROVED / FROZEN. Its prior
283 focused /20,544 canonical assertions and656 Python tests were not rerun for
this evidence-only task; they are historical implementation results, not fresh
Attempt2 counts. Static/diff/document checks are run for the new documentation.

Ignored evidence includes `build/smp2-attempt2-evidence.json` (full pre-training
encoded graph, read-only state and receipts) plus `build/smp2-attempt2-env/` logs.
Evidence JSON SHA-256:
`ff4b48a0e020e50cbdb002862b867d909c4c046197e10b9ced4279dabde7f0c8`.
Attempt1's report is not edited; its owner's interpretation is recorded here and
in current status, without rewriting the historical observations.

Only this report, STATUS and ROADMAP are included in the result commit. No
gameplay/code/test/DECISIONS change, PR, merge, remote CI request, Final Audit, P3
or Migration Tooling P3 is performed. A future attempt requires owner review;
none is started automatically.

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW**
