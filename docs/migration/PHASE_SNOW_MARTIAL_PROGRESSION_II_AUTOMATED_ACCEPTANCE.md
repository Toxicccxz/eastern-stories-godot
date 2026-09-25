# Snow Martial Progression II — Automated Functional Acceptance

## Disposition and scope

**PASS — P2 IMPLEMENTATION + AUTOMATED FUNCTIONAL ACCEPTANCE COMPLETE
— AWAIT OWNER FINAL-AUDIT AUTHORIZATION.**
Branch: `phase/snow-martial-progression-liuh-ken`.
Fresh fetch matched local/origin starting SHA
`96b92799b663adc76776be15f1f9f0e656a2d9c7`; worktree/index were clean and
the any-state phase PR search returned none. P1, P2 implementation, P2R1 and P2R2
are owner-approved/closed. This delivery changes tests and documentation only.
The retained Godot AI update is separate from P2R2 and remains for later branch-level
Final Audit review. No production formula, resource rule, Save schema or plugin changes.

The [owner acceptance decision](DECISIONS.md#snow-martial-progression-ii--automated-functional-acceptance)
replaces the previous live-input/grind protocol for P2 functional closure.
Natural time-to-EXP6 is **BALANCE / PACING QUALIFICATION**, deferred to later
human usability/playtesting. Physical traversal and process-restart persistence retain
their existing subsystem evidence; this test does not relabel direct calls as live input.

## A. Existing genuine live evidence

- Integrated public New Game and source-entry journeys remain historical evidence;
  [P2R2](PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md) separately qualified generalized
  names through automated public Shell tests.
- [Attempt2](PHASE_SNOW_MARTIAL_PROGRESSION_II_ACCEPTANCE_ATTEMPT2_BLOCKED.md) and
  [changed-path acceptance](PHASE_SNOW_MARTIAL_PROGRESSION_II_CHANGED_PATH_LIVE_ACCEPTANCE.md)
  observed natural production EXP0→1. The latter also reached Liu by real movement,
  apprenticed and learned basic unarmed through real UI input.
- Changed-path live play exposed the source-cloth death-facts defect. The separately
  approved [P2R1 repair](PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md)
  closes that integration defect; no natural-grind completion or successful live Flee
  is inferred from an operationally inconclusive attempt.
- The latest human birth observation saw the manually created male Player 阿松大,
  age14, SOURCE_ENTRY_V1, Snow Inn, base attributes30, EXP0/potential99, full primary
  resources and worn source cloth. Food/water were384/384 after elapsed runtime.
  Birth-frame food forensics are no longer a functional gate. This observation is
  neither new automated evidence nor proof of EXP6 progression.

No historical Attempt1/2/3, changed-path, P2R1 or P2R2 report is rewritten.

## B. New deterministic production-path evidence

The dedicated [acceptance suite](../../game/tests/runtime/snow_martial_progression_acceptance_test.gd)
runs in the existing focused runner and canonical gameplay runner. It creates the
canonical ApplicationShell with existing isolated in-memory SaveFileOperations and
uses the unchanged PublicNewGameTestFixture (凌雪/female). This is test harness
input, not Unicode typing qualification. Tests run in a separate headless Godot process;
the owner's paused human game receives no input.

| Stage | Functional evidence |
| --- | --- |
| Source entry | Public setup creates SOURCE_ENTRY_V1 at Snow Inn; age14, eight30s, EXP0/potential99, full resources, only worn source cloth, empty hands/skills/relationship, no autosave. Exact initialization remains covered by existing New Game tests; elapsed food/water is nonblocking. |
| Relationship/basic Learn | Test contact placement, production Liu apprenticeship, exact family/master/generation14/class; real LearnService produces basic raw1 with gin/potential debit. No relationship/raw/learned assignment in this stage. |
| Natural EXP capability | A deterministic non-user attack through fight decision, live projection, action selection, resolver and completion awards the defending Player EXP0→1. Committed progression draw51/bound108; no assignment produces this increment. This is an automated combat scenario, not a new Bandit03 live encounter. |
| Exact EXP6 gate / Liuh Learn | **TEST-ONLY EXP6/basic unarmed4 prerequisite construction**, never claimed naturally earned. Five real Liu LearnService improvements build liuh0→5; EXP5 at raw4 refuses without RNG/potential debit, EXP6 permits raw5. Gin ends1, potential99/spent6. No direct liuh5 assignment in the story. Separate post-loop raw5 probes reject EXP11 and accept EXP12, accumulating29 then leveling to6 on the second Learn. |
| Enable/Disable | Production Liu contact enables unarmed→liuh, effective7. Disable removes only the mapping and preserves raw/learned/internal resources; re-enable succeeds. |
| Four-action Combat | Every index0–3 commits the independently authored expected ID/full text through the real resolver. Exactly one bound4 selection precedes limb/math draws; feedback consumes no RNG. Source dodge/parry metadata has no AP effect. Existing reverse tests execute both QUICK and RIPOSTE with a separately selected current mapped action. |
| Basic progression target | A mapped hit uses normal completion to improve basic unarmed learned0→1, preserves liuh5/learned0, and awards EXP6→7. |
| Equipment mapping | Wielding primary selects weapon action while retaining the mapping; unwield restores Liuh selection. Secondary-only equipment still rejects Liuh Learn before RNG. |
| Save/Continue | Public Pause/Save serializes the complete state. Old Shell/Session/Character are freed (weak-reference proof); a fresh Shell uses public Continue. New object identities, exact full durable snapshot equality, root schema2/item schema3, and unchanged Combat/WorldInteraction/NPC RNG are asserted. |
| Post-Continue Combat | Restored unarmed4/liuh5/effective7/mapping executes another committed bound4 Liuh action through normal completion and authored feedback. |
| P2R1 | Unchanged source-cloth death regression runs in focused and canonical gates: aligned armor facts, completed normal death/corpse lifecycle, no INVALID_ITEM_FACTS. |
| Flee | Existing production tactical queue/Flee and broader canonical combat regressions remain required; no new real-time input race. |

Save equality includes raw skills, learned progress, mapping, EXP7, potential100/spent6,
family/master/class, equipment, location, inventory/item allocator/world/NPC state and
all three durable RNG streams. The full normalized pre-Save projection matches the
public Save payload (only Save metadata excluded); identical fixed-metadata capture
before Save versus after Continue compares the complete encoded snapshot.
The checkpoint and contact placement exist solely inside the test. Scripted random
sources drive functional branches, not the owner's runtime or production probabilities.
The suite uses existing support seams; no new QA framework or gameplay bootstrap helper.

## Validation

| Gate | Result |
| --- | --- |
| Dedicated automated story | PASS: 110 assertions, 0 failures |
| Focused Snow/Learn/Combat/Flee/Save/P2R1 gate | PASS: 2,055 assertions, 0 failures |
| Canonical gameplay | PASS: 21,055 assertions, 0 failures |
| Full Python suite | PASS: 656 tests on Python 3.12.14; also 656 on system Python 3.14.3 |
| Repository/static, development headless/editor | PASS on official Godot 4.7.2 |
| Actual sanitizer + sanitized-project headless/editor | PASS; all five verify.py stages exit0 |
| Changed-document links/anchors, whitespace and scope | PASS: 5 documents / 231 relative links and anchors; test/docs-only scope |

Commands: `godot --headless --path game --script res://tests/run_snow_martial_tests.gd`
and `python tools/ci/verify.py --godot <official-4.7.2-console>`.
Ignored execution logs are `build/smp2-automated-focused.log` and
`build/smp2-automated-complete.log`; they are not release artifacts.
The verify.py invocation used system Python 3.14.3; the full Python suite was also
run successfully on the available bundled Python 3.12.14, recorded separately in
`build/smp2-automated-python312.log`. No Python dependency or toolchain file changed.
The first local test draft had two inferred-Variant WeakRef declarations, corrected
to explicit WeakRef types before accepted runs. A sandbox-only certificate-store
error was avoided with normal host permissions and existing isolated validation storage.
Neither incident changed production or weakened a gate.

## Review and owner gate

Source checks revisited `daemon/skill/liuh-ken.c`, `cmds/std/learn.c`,
`daemon/class/swordsman/master.c` and `adm/daemons/combatd.c`; reference bytes stay
unchanged. Review checks test-only prerequisite construction, production transition
ownership, independent action expectations, old graph destruction and whole-state
restore comparison. This is functional verification, not the milestone Final Audit.

No balance, Flee, EXP formula, Liuh semantic or Save schema changes. No PR, merge,
Final Audit, P3 or Migration Tooling P3. Human pacing/usability and later owner-authorized
Final Audit smoke remain deferred. Remote CI is neither triggered nor claimed.
The delivery response records the acceptance commit and matching remote SHA.

**P2 IMPLEMENTATION + AUTOMATED FUNCTIONAL ACCEPTANCE COMPLETE
— AWAIT OWNER FINAL-AUDIT AUTHORIZATION.**
