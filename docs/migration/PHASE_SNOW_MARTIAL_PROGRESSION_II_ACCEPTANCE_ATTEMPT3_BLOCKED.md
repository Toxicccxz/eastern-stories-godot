# Snow Martial Progression II — Live Acceptance Attempt 3

## Result and owner boundary

**ACCEPTANCE TOOLING TRANSPORT BLOCKED — BEFORE PLAYER CREATION.**

P2 implementation/local verification remains **OWNER APPROVED / FROZEN**.
Live acceptance remains **OPEN**. Existing framebuffer mouse input and the real
Escape key both worked. The connected tool could not enter the mandatory Chinese
Player name: `game_manage(input_key, key="林", pressed=true)` returned
`sent=false`, `error="Unknown key: 林"`; the focused name field stayed empty.
No Player was created, and Start Journey was never pressed. Per the owner's
Attempt3 transport-failure stop rule, no replacement primitive or input script was
written and no further gameplay acceptance was attempted.

This is not evidence of a gameplay, Flee, balance, natural EXP6 reachability or
Liuh-Ken implementation defect. No automatic Attempt4 is authorized.

## Frozen identities

| Identity | Value |
| --- | --- |
| Branch | `phase/snow-martial-progression-liuh-ken` |
| P1 | `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd` |
| Primary implementation | `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401` |
| Executable/test freeze | `81d0cb63da15f9e384392de98cbaa3fd21475a51` |
| Starting local/remote HEAD | `9620c6bfd19eb8f5ef35797db3ebb430a89a1c73` |
| Main | `36a26b13e2bdebeb44c14c0a013d509000c29476` |

Fresh fetch matched these identities. Worktree/index started clean. Every delta
after the executable freeze was documentation only: the two earlier acceptance
reports, runtime report, STATUS and ROADMAP. Production, tests, tooling, project,
build/CI configuration and DECISIONS remained unchanged. A GitHub search for this
phase head in all PR states returned no PR.

## Preserved prior attempts

- [Attempt1](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_BLOCKER.md):
  **INCONCLUSIVE / OPERATIONAL-CONTROL FAILURE** (owner disposition).
- [Attempt2](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_ATTEMPT2_BLOCKED.md):
  **INCONCLUSIVE / OPERATIONAL INPUT SCRIPT FAILURE** (owner disposition).
  Its positive evidence remains real Escape pause, logical1s/event2 and frozen
  Combat RNG, Player ACTIVE at kee78/79, natural EXP0→1, progression draw9/bound178.
  Its temporary input snippet failed compilation before any Resume/Flee input.

Both reports and their ignored evidence remained byte-identical:

| Artifact | Raw SHA-256 |
| --- | --- |
| Attempt1 report | `e4df830035a155b5d2464b4f210c73eec25ea5de6b1b7d09aa2b2e2e70fa2b63` |
| Attempt2 report | `d7a692393f911373358d7717d9c7c864bded0409a3e1167d63392014fb46dd8c` |
| `build/smp2-live-evidence.json` | `294c16afb7335bf0c74f9ce83d42cc1e78e90e6e66f70c56f377a299fa7a501b` |
| `build/smp2-attempt2-evidence.json` | `ff4b48a0e020e50cbdb002862b867d909c4c046197e10b9ced4279dabde7f0c8` |

## Actual runtime and preflight

The canonical ApplicationShell ran in official Godot4.7.2, game PID73468, connected
to editor PID57724 / session `game@97025dc50369cd37`. APPDATA alone was isolated
under ignored `build/smp2-attempt3-env/roaming`; no prepared save was supplied.
The existing development profile was retained, and the menu reported no saved journey.

The existing editor listens on6117, whereas the tracked project adds6107 to its
launch arguments. The editor-launched menu process PID61756 consequently had both
arguments and no live helper. As in the prior setup, canonical PID73468 was launched
explicitly with6117, without changing configuration. Only PID73468's helper was
connected to this editor. Neither menu process created a Player. After stopping,
both PIDs were verified absent; the pre-existing editor was retained.

| Preflight step | Observed result |
| --- | --- |
| Fresh game framebuffer | 1152×648; `stale_frame=false`, frames_drawn3167 |
| Real menu click | Separate existing mouse press/release at (576,300), within observed New Game rectangle; setup panel opened |
| Real Escape | Separate existing key press/release; setup closed and main menu returned |
| Health after Escape | helper_live=true, session_active=true, game_capture_ready=true; status=live, suspended=false, tree_paused=false |
| Name setup | Reopened setup and clicked the observed name field at (470,234) |
| Required text input | Existing `input_key("林")` rejected with `Unknown key: 林`, sent=false |
| Stop-state framebuffer | `stale_frame=false`, frames_drawn13373; focused name field visibly empty |
| Stop-state health | helper_live=true, session_active=true, game_capture_ready=true; no debugger break |
| No Player proof | Runtime tree SessionSlot and StagingSlot each had0 children; shell logs consistently session_count0/staging_count0 |

All input used existing `game_manage input_mouse/input_key` operations. No
`game_eval`, temporary GDScript, InputEventKey snippet, function/variable declaration,
runtime-evaluated input, callback invocation, state injection or ad-hoc compilation
was used. Read-only node/UI/tree/log inspection and framebuffer capture supplied
the evidence. A first SessionSlot lookup used an incorrect path and returned
found=false; the subsequent actual tree established the correct path
`/ApplicationShell/RuntimeHostSlot/OldPineGameRuntimeHost/SessionSlot` and child count0.

Read-only inspection of the existing helper's `_game_input_key` implementation
confirmed it resolves a key name with `OS.find_keycode_from_string`, rejects
KEY_NONE, and does not supply a Unicode/text-input parameter. No callable existing
game text-input operation was exposed in the connected tool inventory. This
documents the available transport limitation, not an assertion about every possible
desktop input facility. No workaround was implemented under this authorization.

Runtime error disclosure: the launch logged a Windows root-certificate-store read
error; editor logs also contained existing script warnings, and Escape caused a
virtual-keyboard-not-supported warning. None produced a debugger break or prevented
the observed mouse/Escape path. The run is therefore not described as having a
completely empty error log. The decisive stop reason is the explicit name-input
rejection, not an inferred connection or gameplay failure.

## Encounter ledger and untested acceptance

The encounter ledger has **zero rows**. Fresh Players0, entered encounters0,
successfully completed encounters0, accepted Flee requests0, successful Flees0.
EXP evolution, starting character attributes/equipment/resources, damage and
recovery are **not applicable**, because no Player existed; this is not an EXP0
gameplay result. No 36-encounter pacing or survivability conclusion can be drawn.

Physical school/Old Pine travel, apprenticeship, Learn, EXP6, Liuh Enable, mapped
combat, Save, cold Continue/state-RNG equality and post-Continue combat remain
**NOT RUN / UNACCEPTED**. Terminating these menu processes is cleanup only, not
the required Save/cold-Continue acceptance evidence.

## Evidence, validation and integration boundary

Ignored evidence: `build/smp2-attempt3-evidence.json`, raw SHA-256
`ef305d6c507fe8741b89123e5bed05165f840cc47c249a1db21703171dc8edfd`.
Runtime log and isolated environment remain under ignored `build/smp2-attempt3-env/`.
No generated evidence or save is added to Git.

Result changes are limited to this report and minimal STATUS/ROADMAP updates.
Repository static checks, 195 changed-document relative links/anchors and
`git diff --check` pass. Executable/test byte identity is rechecked against the
freeze; the previously approved gameplay/Python suites are not represented as
fresh Attempt3 runs. No legacy mechanic was ported or changed in this attempt.

Commit subject: `Record third Liuh-Ken acceptance result`; normal push to the same
phase branch. The resulting commit identity and remote equality are reported to
the owner after push. No PR, remote CI, merge, Final Audit, P3 or Migration Tooling
P3 was started. The milestone remains implementation-approved and unintegrated;
live acceptance is blocked awaiting owner review.

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW**
