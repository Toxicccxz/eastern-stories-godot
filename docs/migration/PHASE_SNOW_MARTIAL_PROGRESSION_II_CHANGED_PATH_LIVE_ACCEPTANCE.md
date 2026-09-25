# Snow Martial Progression II — Changed-Path Live Acceptance

## Verdict

**BLOCKED — AWAIT OWNER REVIEW.** P2 implementation/local verification remains
**OWNER APPROVED / FROZEN**; live acceptance remains **OPEN**.

The owner-authorized existing fixture produced one verified source-valid Player.
Real walking, school-door input, apprenticeship and five basic-unarmed Learn clicks
worked. The first natural Bandit03 encounter reached EXP1, but real Escape took
effect only after five logical seconds and five damaging ripostes. No Flee input
was sent. The required early-pause/Flee procedure was not completed, so this is
**INCONCLUSIVE / OPERATIONAL-CONTROL TIMING FAILURE** for sustainable progression,
not proof of a Flee, balance, EXP6 reachability or Liuh-Ken defect.

Separately, retained production receipts expose a **CONFIRMED PRODUCTION LIFECYCLE
BLOCKER**: after reaching the death threshold, death inventory processing returned
`INVALID_ITEM_FACTS` for the unchanged source birth cloth. The caller recorded
`DEATH_INVENTORY_BLOCKED`, resolution recorded `LIFECYCLE_FAILED`, and the encounter
remained RESOLVING. A corpse had already been created, but lifecycle completion had
not succeeded. This is an observed product-path failure, not merely a failed QA
query. Its root cause and whether it predates P2 were not established; it is not
attributed to the Liuh implementation. No fix or new audit investigation was made.

Gameplay stopped on this sole timeline. No revival, retry from an earlier state,
replacement Player, balancing change or further acceptance attempt occurred.

## Frozen identities and scope

| Identity | Value |
| --- | --- |
| Phase branch | `phase/snow-martial-progression-liuh-ken` |
| P1 | `c44658ef0e9b557b7a002f4d79ca7bef0fd6b4bd` |
| Primary implementation | `8f4ef1dcc41ccbc9b77760a98d5d47d0be499401` |
| Executable/test freeze | `81d0cb63da15f9e384392de98cbaa3fd21475a51` |
| Starting docs local/remote HEAD | `b009c073ec521005db401983296af53de20a3155` |
| Integrated main | `36a26b13e2bdebeb44c14c0a013d509000c29476` |

Fresh fetch matched the frozen identities, with clean worktree/index. All changes
after the executable freeze were documentation only. Production, tests, fixture,
tools, project/build/CI configuration, DECISIONS and reference source were unchanged.
Any-state phase PR search returned no PR. No remote CI or integration was requested.

## Reused historical evidence versus fresh evidence

The owner explicitly reused the unchanged integrated Source-valid New Game Entry
evidence for real Unicode name input, gender selection, setup UI and source birth
composition/input behavior. See [public cutover](PHASE_NEW_GAME_ENTRY_PUBLIC_CUTOVER.md)
and [NGE Final Audit](PHASE_NEW_GAME_ENTRY_FINAL_AUDIT.md). This run does **not**
requalify real typing or claim that fixture assignment was player keyboard input.

Fresh evidence covers fixture bootstrap and exact observed birth, actual physical
school/Old Pine travel, production apprenticeship/Learn, natural combat EXP and
real pause. Successful Flee, EXP6, Liuh training/Enable, mapped combat, Save/cold
Continue and post-Continue combat were **not established**.

Owner historical dispositions remain:

- [Attempt1](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_BLOCKER.md):
  INCONCLUSIVE / OPERATIONAL-CONTROL FAILURE.
- [Attempt2](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_ATTEMPT2_BLOCKED.md):
  INCONCLUSIVE / OPERATIONAL INPUT SCRIPT FAILURE.
- [Attempt3](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_ATTEMPT3_BLOCKED.md):
  INCONCLUSIVE / ACCEPTANCE TOOLING TRANSPORT BLOCKED.

Those three reports remain byte-identical. Their raw SHA-256 values are respectively
`e4df830035a155b5d2464b4f210c73eec25ea5de6b1b7d09aa2b2e2e70fa2b63`,
`d7a692393f911373358d7717d9c7c864bded0409a3e1167d63392014fb46dd8c`, and
`70562b442ed5b999a8f3a81122b52a6cc6f197aa2259d92fe819aab4ee08bee9`.
Their owner-reviewed classifications are not revised by this distinct result.

## Bootstrap and exact source birth

Canonical ApplicationShell ran in official Godot4.7.2, PID34628, connected to the
existing editor PID57724 / `game@97025dc50369cd37` on6117. APPDATA alone was isolated
under ignored `build/smp2-changed-path-env/roaming`. No existing save or Session
was present; the menu showed no saved journey. Process launch changed no tracked
configuration. The normal development storage profile remained in effect.

One direct call, exactly once, returned true:

```gdscript
return PublicNewGameTestFixture.request(get_tree().root.get_node("ApplicationShell"))
```

The existing tracked fixture was not edited. No new helper/QA scene/input script
was created. The bootstrap exception ended after this invocation. A genuine Escape
press paused the newborn Session for independent observation.

| Birth fact | Independently observed |
| --- | --- |
| Identity | 凌雪, 女性, age14, human, 普通百姓 |
| Session / Character object IDs | `292460431926` / `-9223371742414632273` |
| World revision | `SOURCE_ENTRY_V1` |
| Location | `snow.inn`, `snow.inn.main_floor`, (0,0) |
| Eight base attributes | strength/courage/intelligence/spirituality/composure/personality/constitution/karma all30 |
| EXP / potential / spent | 0 / 99 / 0 |
| gin / kee / sen | each current100/effective100/maximum100 |
| Food / water | 400 / 400 |
| Body weight / maximum encumbrance | 80000 / 150000 |
| Player-owned inventory | exactly one `es2:obj/cloth`, worn as cloth |
| Primary / secondary weapon | both absent |
| Raw / learned / mappings | all empty |
| Family / master / class | all empty; generation0 |
| Lifecycle / encounter | ACTIVE, present/available, no encounter |

Initial Combat RNG state `1197025768595358094`, WorldInteraction
`-7031455415972511627`, NPC `5439108073463561557`. Full encoded birth evidence also
retains their seeds, allocator and the complete item/NPC graph. Birth did not save;
the isolated user-data tree contained only the Godot log, with no progression save.

## Real input and physical route

All post-bootstrap actions used existing `game_manage input_key`, `input_mouse` or
directional `input_sequence`. No evaluator input, direct gameplay callback, location
setter, skill/resource mutation, fixture progression or scheduler advancement call
was used.

Real walking went Inn → square → mstreet1 → school1. Closed-door collision stopped
the body at (370.9973,-395.9998); the real contact button opened the door. Walking
through school2 reached schoolhall (1027.3330,-395.9998), then the real Liu contact
panel opened. The real Apprentice button established `family.fonxan`, generation14,
master `teacher.liu_chunfeng`, class `swordsman`.

Five real basic-unarmed Learn clicks reached raw3/learned0, EXP0. After three clicks
raw2/learned6/gin56 was observed; after five, raw3/learned0/gin54. Resource changes
include ordinary recovery between calls. No Liuh Learn/Enable shortcut occurred.

The Player walked back along Snow streets/east road, through the production portal
to Old Pine north approach (450,-350.6667), then to (600.3337,529.3326) outside
Bandit03's aggression. Pre-fight kee was100/100, EXP0, ACTIVE, no active encounter.
A short 48-frame downward input entered aggression and ended near (600.3337,668.6667).

## Encounter ledger and pause evidence

| Entered encounter | EXP before → after | Pre-fight kee | Received damage | Flee request / completion | End observation | Recovery |
| --- | --- | --- | --- | --- | --- | --- |
| 1, natural Bandit03 | 0 → 1 | 100/100 | 28+19+28+24+32 = 131 recorded riposte damage | none / none | death threshold; failed lifecycle, held RESOLVING | not attempted |

**Successful completed encounters0; successful Flees0.** This single failed
encounter is not counted toward the maximum36 successful encounters. No subsequent
encounter occurred. The recorded damage sum is resolver damage, not a claim of a
simple final-resource subtraction: the failed death path also transitions resources.

The movement primitive returned, and a separate real Escape press was sent next.
No intervening expensive query was made. The combined orchestration yielded after
31 seconds while Escape was still outstanding; this is tool-call wall time, not
combat logical time and not proof of a specific transport root cause. By the first
paused observation, time was5s/events10/kee-1,-1/EXP1. It was already too late for
the specified first-opportunity pause/Flee procedure. No Resume or Flee was sent
after finding the terminal threshold and failed lifecycle.

Two successive observations, and a later final observation, all showed
paused=true, logical time5, scheduler events10, Combat RNG`141106303399134421`.
Thus real pause and stable observation were demonstrated, but only after the
encounter had reached its failure barrier. This does not prove that a healthy,
active encounter was paused early enough. Tactical retained event count stayed0.

Retained events show Bandit03 guarding at each second and Player default-unarmed
attacks dodged with damaging ripostes. The reverse defender-progression receipts:

| Scheduler event | Time | Damage | Progression draw / bound | Player EXP before → after |
| --- | --- | --- | --- | --- |
| 2 | 1s | 28 | 128 / 172 | 0 → 0 |
| 4 | 2s | 19 | 121 / 153 | 0 → 0 |
| 6 | 3s | 28 | 80 / 125 | 0 → 0 |
| 8 | 4s | 24 | 25 / 101 | 0 → 0 |
| 10 | 5s | 32 | 13 / 99 | 0 → 1 |

These are already committed draws, not evaluator draws. No preferred result was
selected or rerolled.

## Confirmed lifecycle blocker and state distinctions

Read-only retained authority showed:

- `CombatEncounterResolution.failure=2` (`LIFECYCLE_FAILED`), lifecycle receipt count1.
- Victim `oldpine.player`, receipt outcome4 (`DEATH_INVENTORY_BLOCKED`).
- Nested death inventory outcome3 (`INVALID_ITEM_FACTS`), completion2
  (`BLOCKED_INCOMPLETE`), restart disposition2 (`DO_NOT_RESTART_FROM_BEGINNING`).
- Stopped item `oldpine-session-bcdf50f4b78bc4ba733a327214d8bb69.dynamic.0`, the
  exact source cloth identified in the birth inventory.
- Corpse `oldpine-session-bcdf50f4b78bc4ba733a327214d8bb69.dynamic.1` already exists;
  deferred-effect count0; encounter phase2 (`RESOLVING`).

Character `life_threshold()` returned2 (DEAD) and battle presentation said Dead,
while WorldPlayerRuntime still reported life_status0/present/available and the failed
lifecycle receipt retained new_life_status0. These are distinct observed layers of
an incomplete lifecycle, **not a successful ACTIVE return to world control**. No
successful death/Flee completion or safe recovery is claimed.

This product-path blocker is independently evidenced by existing typed receipts
and source enum definitions. No second Player or synthetic reproduction was used,
and no root-cause repair was attempted. The Flee/survivability test remains
inconclusive because Flee had never been requested.

## Read-only observation, health and evidence limits

The owner separately authorized minimal read-only `game_eval` expressions after an
initial pre-birth query was denied by automatic approval review. Before that
additional authorization, the Player had not been created. Subsequent observations
used only getters, copied receipts/snapshots and formatting; no variables, functions,
classes or lambdas were declared. The fixture call above is the sole mutation
exception. Observation did not produce the gameplay values it reported.

`capture_random_state()` was inspected in all three Godot adapters: it copies the
stored seed/state without drawing. `OldPineWorldSaveCapture.capture` and
`GameSaveJsonCodec.encode` project/validate copies, including a detached restoration
validation graph; they do not replace the live Session, write files, or advance live
RNG. The exact birth projection expression and other observation expressions are
retained in ignored evidence. Birth Combat RNG matched before/after capture.

Health checks after successful observations reported helper_live=true,
session_active=true, game_capture_ready=true, with no observed debugger break.
The final paused framebuffer had stale_frame=false/frame94014. During retained
event collection the plugin briefly disconnected and reconnected to the same
editor/process; that interrupted query supplied no evidence. An orchestration
attempt to store its missing structured result also failed outside the game. Later
successful individual reads supplied the recorded event evidence; no gameplay
input or replacement character was used to recover observation.

The process log contains a Windows root-certificate-store error at launch and a
virtual-keyboard warning from the existing fixture setup. It contains no SCRIPT
ERROR or Parse Error. Therefore a completely empty runtime log is not claimed.
There is no observed query-caused mutation/error; the connection interruption's
cause was not diagnosed or represented as a proven GDScript failure.

Ignored evidence `build/smp2-changed-path-evidence.json` has raw SHA-256
`e958fef78098117491de961a19fc7f6600c87ef4aa7063ec0edac7ae595306db`.
It contains full birth graph, identities, training reads, retained event/draw arrays,
pause comparisons, final RNG/skills and typed failure receipts. Logs remain under
ignored `build/smp2-changed-path-env/`; neither evidence nor saves are tracked.

## Final state, cleanup and unfulfilled gates

Same Session/Character; EXP1, unarmed raw3, liuh raw0, mapping empty, effective
unarmed1. Final RNG states: Combat`141106303399134421`,
WorldInteraction`-8715384423759567047`, NPC`5439108073463561557`.
No natural recovery, final training, Enable or mapped Liuh action was accepted.

No gameplay Save was requested. PID34628 was normally closed after evidence capture
and verified absent. No new game process or Continue followed; cleanup is not cold
restore proof. Exact cold equality, zero restore draws and post-Continue mapped
combat remain NOT RUN. The owner must review before any further work.

## Documentation validation and integration

Only this distinct report, the runtime report's current disposition, STATUS and
ROADMAP are changed. Repository/static checks, 204 changed-document relative links and
anchors, and whitespace checks pass. Freeze-to-current executable/test identity and
all three historical report hashes are preserved. Previously approved automated
suite counts are historical, not fresh tests for this live run.

Result commit subject: `Record Liuh-Ken gameplay acceptance blocker`, normally pushed
to the same phase branch. The exact resulting docs commit/remote equality is reported
after push. No gameplay/code, tests, fixture, tooling, DECISIONS or reference source
changes. No PR, remote CI, merge, Final Audit, P3 or Migration Tooling P3. The phase
is not integrated on main.

**P2 LIVE ACCEPTANCE BLOCKED — AWAIT OWNER REVIEW**
