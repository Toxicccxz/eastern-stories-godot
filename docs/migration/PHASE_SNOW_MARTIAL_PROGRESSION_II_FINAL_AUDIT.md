# Snow Martial Progression II — Final Audit

## Audited identities and disposition

**FINAL AUDIT PASS — READY FOR OWNER PR AUTHORIZATION.**

Owner-authorized audit on 2026-09-25, under the final automated-functional acceptance
contract. P1, P2, P2R1, P2R2 and automated acceptance remain owner-approved/closed.
No production or test repair was needed.

| Identity | Verified value |
| --- | --- |
| Repository | `Toxicccxz/eastern-stories-godot` |
| Major-phase branch | `phase/snow-martial-progression-liuh-ken` |
| Audited executable/test/docs HEAD | `c026bd1793e34c1f65829aee5f21d9999ec291aa` |
| Integrated main and exact merge-base | `36a26b13e2bdebeb44c14c0a013d509000c29476` |
| Fresh preflight local/origin phase | Both equal the audited HEAD |
| Preflight worktree/index | Clean |
| Preflight phase PR, any state | None |
| Main-to-audited-HEAD scope | 13 commits; 110 changed files |

The closing audit commit contains this report, STATUS and ROADMAP only. Its final
SHA and matching remote HEAD are recorded in the delivery response rather than
embedded as a self-referential identity. The 13/110 counts above describe the
audited branch before that docs-only closeout.

## Final branch scope

Every changed path is counted once, including tests, documentation and UID sidecars.

| Authorized group | Files | Attribution |
| --- | ---: | --- |
| Snow Martial Progression II gameplay | 35 | Liuh data/composition/UI/feedback, tests/runners, P1/P2/acceptance history and shared current/decision documents |
| P2R1 source-cloth death repair | 3 | Old Pine death-facts composition, its smoke regression, P2R1 report |
| P2R2 generalized display-name policy | 5 | Name policy, Shell controller/scene, public-source test, P2R2 report |
| Separately retained Godot AI update | 67 | Addon files listed below |
| Total | 110 | No fifth or unclassified group |

Shared DECISIONS, STATUS, ROADMAP, runtime report and canonical runner are attributed
to group 1 for unique counting; their P2R1/P2R2 content was reviewed in those groups.
The post-P2R1 live/capability report also belongs to the phase acceptance history.
The plugin is not Liuh gameplay and is not part of P2R2.

Content review covered the complete first-party production diff, tests and current
phase records. Added production lines contain no test-fixture imports, injected
EXP/skills, fixed test RNG, temporary acceptance state, bypassed guards or workstation
paths. The reverse validator extraction preserves all previous live scalar,
equipment, mapping, relationship and busy checks; the new action-source membership
check adds validation. No existing canonical suite was removed.

Zero base-to-audit delta was verified for `reference/es2`, `tools/migration`
(including schema/profile/version), `tools/tests`, `tools/ci`, `tools/build`,
`.github`, CombatMath, Learn core and both core/runtime persistence.
No Migration Tooling P3 or Native generation is present.

Reviewed authority/current records: root/docs AGENTS, README, STATUS, ROADMAP,
[DECISIONS](DECISIONS.md#snow-martial-progression-ii--automated-functional-acceptance),
[P1](PHASE_SNOW_MARTIAL_PROGRESSION_II_SOURCE_ANALYSIS.md),
[P2 runtime](PHASE_SNOW_MARTIAL_PROGRESSION_II_RUNTIME.md),
[P2R1](PHASE_SNOW_MARTIAL_PROGRESSION_II_P2R1_SOURCE_CLOTH_DEATH_FACTS.md),
[P2R2](PHASE_NEW_GAME_GENERALIZED_NAME_POLICY.md) and
[automated acceptance](PHASE_SNOW_MARTIAL_PROGRESSION_II_AUTOMATED_ACCEPTANCE.md).
This final report supersedes earlier pending-audit dispositions without rewriting
historical evidence. README's general playable-slice/platform limits remain accurate.

## Liuh contract

**PASS.** [Source liuh-ken](../../reference/es2/mudlib/daemon/skill/liuh-ken.c),
its inherited skill behavior and [Liu](../../reference/es2/mudlib/daemon/class/swordsman/master.c)
agree with the final [definition](../../game/data/combat/liuh_ken_definition.gd)
and teacher/contact composition: liuh-ken / 柳家拳, taught by 柳淳风, Learn requires
both weapon references empty, Enable allows only unarmed.

古松挂月, 傲雪冬梅, 孤崖听涛 and 荒山虎吟 retain all four exact authored texts,
with no per-level unlock. Each uses damage_percent=0, force_percent=0, 瘀伤 and
no authored post-action effect. Source dodge/parry metadata adds no Combat bonus.
The known-no-authored-hit-effect classification is restricted to reviewed Liuh;
unknown mapped arts remain unavailable. No Phase5B4/general-hook expansion.

## Learn and EXP

**PASS.** [Source Learn](../../reference/es2/mudlib/cmds/std/learn.c) and unchanged
LearnService retain ordered cost/partial-mutation semantics. Current raw4 requires
floor(64/10)=6 EXP: 5 rejects, 6 permits reaching raw5. Raw5 requires floor(125/10)=12:
11 rejects, 12 permits progress. Both weapon references, teacher policy, gin,
potential and WorldInteraction RNG remain authoritative.

Fresh acceptance builds Liuh0→5 through real LearnService, then enables
unarmed4→liuh5 for effective unarmed7. Contact Disable preserves raw/learned state
and resources. A production resolver/completion scenario genuinely awards EXP0→1
(committed draw51/bound108); a mapped hit awards EXP6→7 and improves **basic unarmed**
learned0→1, leaving Liuh5/learned0 intact. This matches
[combatd](../../reference/es2/mudlib/adm/daemons/combatd.c).

EXP6/basic-unarmed4 prerequisites and deterministic random sources are explicitly
**test-only fixtures**, not naturally earned live progress. No test prerequisite
construction leaks into production. Natural time-to-EXP6 is not an engineering gate.

## Combat

**PASS.** The existing selector/resolver/completion pipeline remains the sole
Combat pipeline. The mapped set feeds one bound4 selection per actual Liuh attack;
complete selected payload membership is validated and that selected action becomes
the resolver input and retained result. No preselection/reroll or preferred action.

Forward execution uses current authority. QUICK/RIPOSTE rebuild post-forward
authority, validate it and make their own selection. Tests cover independent action
IDs, changed mappings, stale live state and forged payload refusal before draws.
The extracted reverse guards were compared with the base implementation: only
parameterization and the additional exact action-source check change them.

Primary weapon selection overrides the stored unarmed mapping; unwield restores
Liuh. Secondary-only equipment still refuses Learn. Default/weapon singleton draws
and unknown-art refusal remain intact. CombatMath, damage, Flee, EXP probabilities,
recovery and enemy balance are unchanged. Feedback uses committed IDs/limbs and
full authored text; presentation consumes no RNG.

## Save and Continue

**PASS.** Root schema2, item schema3 and SOURCE_ENTRY_V1 are unchanged.
The fresh automated public Pause/Save payload matches the complete projected durable
state, excluding only Save metadata for that payload comparison. Old Session and
Character destruction is checked with weak references. A fresh canonical Shell's
public Continue installs new Session/Character identities and reproduces the exact
complete fixed-metadata encoded snapshot.

Coverage includes both raw/learned skills, mapping, EXP7, potential100/spent6,
family/master/class, equipment, location, item/allocator/world/NPC graph and all
three RNG streams. Continue consumes zero durable Combat/WorldInteraction/NPC RNG.
Restored unarmed4/Liuh5/effective7 then executes another committed mapped action.
Additional existing enabled/disabled round trips preserve nonzero learned progress.
These are fresh-graph automated runtime tests, not a newly claimed OS-process restart.

## P2R1 source-cloth death repair

**PASS / CLOSED.** The sole production repair resolves exact `es2:obj/cloth` through
`SourcePlayerCloth.armor_definition()` at Old Pine death-facts composition.
The source cloth, armor1/weight3000, remains outside OldPineItemContentDefinitions.
DeathInventoryService is unchanged and unknown/uncovered items still return
INVALID_ITEM_FACTS; no fail-open lifecycle path was added.

Fresh focused/canonical regressions complete SOURCE_ENTRY Player death, release the
encounter, transfer and wear the original cloth on exactly one corpse, detach the
Player armor projection, preserve the remaining item set and refuse duplicate replay.
Root-cause files at the integrated base and pre-repair P2 freeze have identical Git
blobs: this repairs a **pre-existing source-entry/death integration defect**, not
a Liuh regression. No Save-schema effect.

## P2R2 generalized display names

**PASS / CLOSED.** Default length is 1–24 Unicode code points. Letters across scripts
and attached combining marks are accepted; only internal ASCII space, hyphen-minus,
straight/curly apostrophe and middle dot are default separators. Leading, trailing
and adjacent separators, default digits, emoji, invisible/control and unsupported
characters are rejected. No trimming or normalization occurs.

Tests exercise configurable minimum/maximum, decimal-digit opt-in, separator changes,
exact reserved names, independent defaults, invalid rules and supplementary/combining
code-point boundaries. Shell and Host use the same policy. Accepted multilingual,
separator and decomposed text survives public Save/Continue and presentation exactly;
semantic `oldpine.player` identity is independent. Birth and gameplay semantics remain
unchanged. This is the owner-approved Type B display-name policy.

## Godot AI and project configuration

**PASS — ACCEPTED INDEPENDENT BRANCH DEPENDENCY UPDATE, bounded review.**
Update commit `d9f6770a4dddb0b7fdc74e8a50ba6ff50964c150` changes Godot AI
4.0.4→4.2.3. It originally touched 67 addon files plus project.godot. Commit
`3cf9c67e4514e9131f1492a36454ebc625376608` records a capability recheck, not
another plugin implementation change.

The separately owner-authorized two-line viewport restoration in P2R2 restores
1152×648. Final `game/project.godot` is byte-identical as a Git blob to integrated
main: mobile configuration, canonical scene, existing development autoloads and
debug-port configuration are unchanged. No new QA setting, path or bypass remains.

Fresh editor state confirms official Godot4.7.2, plugin/server4.2.3,
helper_live=true, session_active=true and game_capture_ready=true. This is read-only
tooling health, not a new gameplay-input claim. Development headless validation
honors the plugin's existing headless-disable path. The actual sanitizer removes
the addon, tests, development helper/QA autoloads and remote-debug activation;
sanitized-project editor validation passes without those dependencies.
First-party gameplay has no new addon dependency. Source, Save schemas and build/CI
gates are unchanged. Bounded inspection of connection authentication, allow-host
handling and update verification found no concrete release/security blocker.
This is not a line-by-line certification of the third-party plugin.

<details>
<summary>All 67 changed addon paths, relative to game/addons/godot_ai/</summary>

```text
client_configurator.gd
clients/_base.gd
clients/_cli_exec.gd
clients/_cli_finder.gd
clients/_json_strategy.gd
clients/_manual_command.gd
clients/_registry.gd
clients/_toml_strategy.gd
clients/omp.gd
clients/omp.gd.uid
clients/zcode.gd
clients/zcode.gd.uid
connection.gd
dispatcher.gd
dock_panels/port_picker_panel.gd
handlers/animation_values.gd
handlers/batch_handler.gd
handlers/editor_handler.gd
handlers/filesystem_handler.gd
handlers/filesystem_mutation.gd
handlers/filesystem_mutation.gd.uid
handlers/navigation_handler.gd
handlers/navigation_handler.gd.uid
handlers/physics_shape_handler.gd
handlers/physics_shape_refresh.gd
handlers/physics_shape_refresh.gd.uid
handlers/resource_handler.gd
handlers/script_handler.gd
handlers/shader_handler.gd
handlers/shader_handler.gd.uid
handlers/theme_handler.gd
handlers/ui_handler.gd
handlers/visual_shader_handler.gd
handlers/visual_shader_handler.gd.uid
mcp_dock.gd
migration_bridge.gd
migration_bridge.gd.uid
migration_coordinator.gd
migration_coordinator.gd.uid
migration_fallback.gd
migration_fallback.gd.uid
plugin.cfg
plugin.gd
runtime/game_helper.gd
tool_catalog.gd
utils/allow_hosts.gd
utils/client_job_owner.gd
utils/json_values.gd
utils/linux_proc.gd
utils/linux_proc.gd.uid
utils/mcp_server_state.gd
utils/mesh_workload.gd
utils/mesh_workload.gd.uid
utils/plugin_reload.gd
utils/port_resolver.gd
utils/release_verifier.gd
utils/resource_inspector.gd
utils/resource_inspector.gd.uid
utils/screenshot_encode.gd
utils/script_work.gd
utils/server_lifecycle.gd
utils/server_version_check.gd
utils/transport_capability.gd
utils/update_activation_runner.gd
utils/update_activation_runner.gd.uid
utils/update_mixed_state.gd
utils/update_mixed_state.gd.uid
```

</details>

## Fresh final gates

All executable tests ran on exact audited HEAD, using Python3.12.14 and official
Godot4.7.2 `ed1daf0bf`, isolated validation storage and normal host permissions.
No skip flags, test edits or production edits were used during this audit.

| Gate | Fresh result |
| --- | --- |
| Dedicated automated functional acceptance | PASS: 110 assertions, 0 failures |
| Focused Snow/Learn/Combat/Flee/Save/P2R1 gate | PASS: 2,055 assertions, 0 failures |
| Complete canonical gameplay suite | PASS: 21,055 assertions, 0 failures |
| Complete Python tooling suite | PASS: 656 tests, no failures/errors/skips |
| Repository/static checks | PASS |
| Development headless/editor | PASS, official Godot4.7.2 |
| Actual release sanitizer | PASS |
| Sanitized-project headless/editor | PASS |
| Complete verify.py | All five stages PASS, exit0 |
| git diff --check | PASS |
| Branch phase/current Markdown links and anchors, including this report and README | PASS: 15 documents, 369 relative link/anchor occurrences, 0 errors |

Commands: `godot --headless --path game --script res://tests/run_snow_martial_tests.gd`
and `python tools/ci/verify.py --godot <official-4.7.2-console>`.
Ignored local logs: `build/smp2-final-focused.log` and
`build/smp2-final-complete.log`. No assertion-by-assertion dump is committed.
This is actual Godot headless runtime integration plus read-only plugin health;
no new human keyboard/mouse route, physical-device qualification or process restart
is claimed. The owner's current acceptance contract permits this functional evidence.

## Historical evidence and residual

Attempt1 was operational-control failure; Attempt2 operator input-script failure;
Attempt3 an input-transport capability gap. Pre-P2R1 changed-path play exposed the
real cloth lifecycle defect, now repaired/closed. Later input-automation limitations
remain tooling history. None is reopened as an outstanding product blocker.

**One nonblocking residual:** natural time-to-EXP6 has not been balance/usability
qualified. **NON-BLOCKING FOR ENGINEERING INTEGRATION**; defer to future human
playtest/balance qualification. No rebalance or source-rule change is implied.

## Blocker ledger and owner gate

| Classification | Open count |
| --- | ---: |
| Blocking HIGH | 0 |
| Blocking MEDIUM | 0 |
| Previously confirmed cloth defect BLK-SMP2-01 | 0; P2R1 closed |

No concrete contradiction/regression was found in the owner-closed components.
This audit closes engineering readiness for the one final phase PR, not integration
on main or store/device qualification. STATUS and ROADMAP carry the current verdict;
historical reports and DECISIONS are preserved.

Final closeout scope is exactly this report, STATUS and ROADMAP, with executable/test
identity unchanged from `c026bd1793e34c1f65829aee5f21d9999ec291aa`.
No PR, merge, new feature slice, P3 or Migration Tooling P3. Remote CI was not
triggered and is not claimed for this audit; the required PR/main jobs remain future
integration gates. Stop for owner authorization.

**SNOW MARTIAL PROGRESSION II — FINAL AUDIT PASS**

**READY FOR OWNER PR AUTHORIZATION**
