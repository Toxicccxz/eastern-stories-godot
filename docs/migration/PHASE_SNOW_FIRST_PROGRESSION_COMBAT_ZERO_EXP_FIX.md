# Snow First Progression — P2B-ZE1 zero-EXP combat fix

## Authority and result

Owner-approved narrow Type B implementation on `phase/snow-first-progression-loop`,
parent `affbe5030a5a2f03c2bff2ab14195f9f86c5f53c` (approved P2B analysis).
P2 is `611535dfe10ce858206574c5494bc5e9a2accbe7`; P1 is
`5780139b82fad932f6bc7786ea295c20602ae0a5`; frozen main is
`88be5c0e9e297b8f92d38b1f14a131a0cb8abf4e`. Preflight matched these identities
with a clean worktree/index. The historical P2/P2B reports remain unchanged.

**ZE1 implementation and local regression PASS. P2 live acceptance remains BLOCKED / incomplete.**
The single fresh gameplay timeline reached natural EXP1 and normal unconscious defeat,
not E>=2 and return-to-learning. No new zero-bound or incomplete-chain defect was observed.
This is a failed acceptance attempt, not evidence that the existing defeat rules are defective
or authorization to redesign them. No Final Audit, PR, merge, P3 or Migration Tooling.

## Exact production change and decision

The only production delta is four added lines in `CombatAttackResolver.resolve()` at the
existing defense-factor loop (two comment lines, one condition, one `break`). At that stage,
**original defender EXP0 AND attacker EXP>=0** exits with zero reductions and zero draws.
The check uses the original defender field, not a factor that could have halved to zero
on the abnormal negative-attacker path. No result/API/enum changes.

Source consulted: `reference/es2/mudlib/adm/daemons/combatd.c`, particularly the ordered
attack region and lines362–366: `defense_factor = your["combat_exp"]` followed by
`while (random(defense_factor) > my["combat_exp"])`, integer damage reduction and halving.
See the approved [DECISIONS entry](DECISIONS.md#snow-first-progression-p2b-ze1--zero-exp-combat-defense-boundary).
Historical MudOS `random(0)` return/error/state consumption remains unproven. This is an
explicit compatibility translation, not a historical-driver claim or a global random rule.

All earlier mutation/draw ordering remains; later damage, wound, progression, status, busy,
relationship and post-action stages still execute or fail at their existing boundaries.
Positive EXP retains actual draws, strict comparison and truncation. Invalid negatives
remain fail-closed. Generic Combat/World/NPC RNG and persistence are unchanged.

## Deterministic verification

Focused combat: **1,466 assertions / 0 failures**. Snow progression: **247 / 0**.

| Case | Evidence |
| --- | --- |
| Defender0, attacker0 and5 | HIT, zero iterations, factor0, exactly four earlier calls; bounds `[2,10+E,10+E,10]`, draws `[0,1,1,0]`; requested damage5, vitality100->95, interrupt reached |
| Defender1 | Actual bound1/draw0 retained; bounds `[2,10,10,10,1]`, five calls, zero reduction iterations |
| Positive multiple reductions | Bounds `[2,22,22,30,40,20,10]`; draws `[0,20,20,0,20,6,5]`; damage15->10->7, factor40->20->10 |
| Invalid negatives | Defender-1 still fails; attacker-1/defender1 retains one iteration and draw1 before factor0 failure; attacker-1/defender0 also fails before damage |
| Ordinary forward | Positive NPC attacks fresh Player0 through actual opportunity executor, damage/wound/progression complete without reverse |
| QUICK and RIPOSTE | Fresh Player forward dodge, guard cleared, correct reverse IDs/types, Player100->78 current/effective, conditional source EXP0->1, post-action reached; no third reverse |
| Reverse shared RNG | Bounds `[4,60,1,16,601,30,1,16,601,601,25,20,22,178]`; draws `[0,0,0,0,0,r,0,0,1,1,0,0,1,0]`, r=0/29; exactly14 calls |
| Later failure | Wound damage0 remains `WOUND_RANDOM_BOUND`; preceding damage-stage completion and actual earlier draws preserved |
| Generic adapter | `next_below(0)` and negative bound still return-1, retain state, and preserve next positive draw against a peer stream |

Deterministic test setup constructs state/RNG only in tests. It is not live gameplay evidence.
The former defender0 invalid assertion was replaced by negative-defender coverage plus the
separate approved zero-success cases, not weakened into an unconditional success assertion.

## Full local verification

Godot **4.7.2.stable.steam.ed1daf0bf**; canonical `res://tests/run_tests.gd`:
**20,261 assertions / 0 failures** (prior20,179, increase82). Python **46 tests / OK**.
Repository/static checks PASS. Development headless editor, release sanitizer, sanitized
editor import and sanitized canonical-main startup all exited0; sanitizer reported zero
validation errors. No GDScript parse/test failure in these checks.

Used the established P2 repository-content sanitizer route: copied1,713 tracked/nonignored
game files into an isolated staging tree, preserving ignored owner backups; then called
`prepare_release_project` and `validate_release_project`. No exported-device qualification.
These are local results, not CI.

Environment diagnostics remain visible: Windows root-certificate-store read error;
headless editors also reported inability to launch configured `adb` and save Steam's
external `editor_data/editor_settings-4.7.tres` under sandbox permissions. They did not
cause nonzero exits or script/test failures. No owner configuration was changed to hide them.
The live editor omitted the two default viewport dimensions in `project.godot`; those
exact lines were restored after editor shutdown, leaving zero project/config delta.

## Real main-scene attempt (2026-09-15 UTC)

Canonical `application_shell.tscn` launched through Godot AI into the production world.
Isolated `build/ze1-live-env/Roaming` protected owner saves. One New Game, no save reload,
state setter, EXP grant, enemy modification, RNG replacement/seed/reset or direct gameplay callback.
Chinese name 林清 was entered as real Unicode key events into the focused name field.
All buttons were framebuffer mouse inputs; movement used actual input actions and physics.

Initial `helper_live=true`, `session_active=true`, `game_capture_ready=true`,
`current_run_errors=[]`. Real captures had `stale_frame=false`, with advancing frame counts:
14 at main menu, 8,624 at closed school gate, 10,266 at Liu contact,
22,536 on Old Pine entry, 29,918 at the observed defeat/pause screen.

| Acceptance step | Actual evidence |
| --- | --- |
| New Game / Inn | 林清, male, source-fresh E0; began at `snow.inn` |
| School traversal | Walked through Square/mstreet1/school1; closed gate blocked x370.993; clicked Open; physically traversed school2 and schoolhall to x1008.996/y-399.666 |
| Apprenticeship | Actual UI recruited into 封山剑派第十四代弟子 |
| Learn | Four individual requests: raw1/progress0, raw2/0, raw2/1, raw3/0; available potential99->95. Fifth request correctly reported insufficient EXP, retained raw3/E0 and charged gin |
| Old Pine entry | Walked out of school through Snow sroad1/eroad1/2/3 and real portal into `oldpine.outdoor` at `(450,-328.667)` |
| Combat | Entered production Bandit03 aggression area at `(600.334,672.333)`. Normal cadence produced complete attack chains, dodges and RIPOSTE hits; HUD retained two 23-damage hit messages |
| ZE1 boundary | Natural Player EXP rose0->1; damage/wound and completed chains demonstrate continuation beyond the old zero-EXP failure. Final `resolution.failure=NONE`, no active encounter |
| End of attempt | Unconscious defeat, vitality `0 / 39 / 100`, E1; no successful Flee, return to Snow, or post-E>=2 Learn |
| Remaining acceptance | Production learned-skill projection at E>=2, Save after that progression, full process restart/Continue, exact persisted-state/all-RNG comparison and next RNG continuation were **NOT REACHED / NOT VERIFIED** |

The automation's move-to loop continued trying to reach y700 after aggression froze walking;
it did not promptly switch to Flee. This is an acceptance-control mistake. It must not be
presented as a newly discovered combat, balance or lifecycle defect. Existing defeat feedback
directs the player to the main menu, and recovery eligibility requires an ACTIVE player
(`OldPineWorldSessionController.player_recovery_time_allowed`). No revival or balance fix was added.
The failed timeline was retained, not restarted to select favorable RNG.

After the defeat/state observation, an additional read-only event-export `game_eval` failed
with mixed tabs/spaces. It caused a QA-only debugger break (`can_debug=false`); the helper
resume operation did not restore the main loop. Therefore the detailed completed-event/RNG
export did **not** succeed. No exact live draw-prefix/state comparison is claimed. This happened
after the real gameplay result and is not a production script failure or a new random boundary.
Logs were preserved, not cleared. Game/editor were then stopped for cleanup; this shutdown
is **not** the requested post-progression Save/cold-Continue proof.

Local ignored evidence: `build/ze1-live-events.jsonl`, `ze1-live-final-logs.log`,
`ze1-frame-1789443057979168500.png`, focused/full `ze1-*.log` files. Durable facts above
do not rely on these workstation files being present in another checkout.

## Scope and integration state

Separate self-review confirms the sole production edit is the resolver guard; three test files
plus DECISIONS/this report/STATUS/ROADMAP document it. Zero legacy-source, enemy, balance,
EXP-grant, advanced-skill, RNG-adapter/stream, Save schema/revision or migration-tooling delta.
Historical P2/P2B documentation is untouched. One implementation commit is authorized for this
same branch. No PR/merge or remote integration CI; no claim of milestone integration on main.
ZE1 is independently verified; full P2 live acceptance still needs owner review and a successful
complete route. This report does not approve another repair or Final Audit.
