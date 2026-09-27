# Old Pine Lake + Production Serpents — P2C Acceptance

Date: 2026-09-26. Branch: `phase/oldpine-lake-serpent-production`.
Executable/test baseline: `ef8b7d601983c80d817bf28a93e554f2472a49a6` (P2B).

## Disposition and scope

**P2C — DESKTOP INPUT / COLD RESTORE / REPRESENTATIVE DEATH VERIFIED;
TOUCH DEVICE QUALIFICATION PENDING — AWAIT OWNER REVIEW.**

This is the owner-authorized P2C acceptance slice, not Final Audit. No gameplay,
test, plugin, dependency, CI, source or Save-schema change was needed. No new QA
script/platform or production backdoor was added. No PR, merge, next major phase,
Phase5B4 or Migration Tooling P3 is started. Overall ACCEPTANCE COMPLETE is withheld
because the representative actual touch-device path remains unqualified.

Read root/docs AGENTS, [P2B runtime](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_P2B_RUNTIME.md),
[P1 requirements and amendment](PHASE_OLDPINE_LAKE_SERPENT_PRODUCTION_SOURCE_ANALYSIS.md#owner-policy-amendment--2026-09-26),
[current Save contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md#development-save-policy)
and [locked M/W/R](DECISIONS.md#old-pine-lake--owner-locked-p2a-foundations).
Source rules remain those already established in P1/P2A/P2B; this slice does not
re-analyze or rebalance Lake, serpent, combat, death or recovery rules.

## Baseline and evidence reuse

Fresh fetch found local/origin phase at the exact P2B baseline. No phase PR in any
state was returned by the repository PR search. The starting index was clean;
the only worktree delta removed explicit desktop viewport width1152/height648
from `game/project.godot`, matching the previously encountered editor save behavior.
The starting bytes were retained at ignored `build/p2c-initial-project.godot`.
After closing the editors, the two lines were restored under the owner's existing
specific authorization to retain this configuration contract. `git diff --exit-code
-- game` then passed. This creates no tracked code delta from P2B. Live framebuffers
were already1152×648. Owner files and normal saves were not copied, edited or deleted.

| Evidence | Treatment in P2C |
|---|---|
| P2B ordinary Inn/Snow/Old Pine/Vine/Waterfall/Lake route and return | Reused; no new journey from Snow |
| Five production contacts and participant-count progression | Reused; local approach repeated only as required to reach the changed input and restored-world checkpoints |
| Fifth-target Tab/Enter | Reused as keyboard evidence only |
| Flee/reentry and Fill to CLEAR_WATER15 | Reused; Fill is not falsely included in the older saved state |
| P2A rules/transactions, P2B Lake and16 affected regression groups | Reused; no repeated16-group debug run without code changes |
| Mouse fifth target and manual Attack | Previously missing; fresh real-input proof below |
| True process restart/equality and actual death/corpse | Previously missing; fresh A/B proof below |
| Representative touch-device path | Still PENDING; no connected device/input capability |
| Final complete canonical local verification | Fresh run below; earlier discovery/targeted results are not substituted |
| Paths requiring requalification after a P2C product repair | None: no product repair |

## Environment and disclosed QA boundaries

Official Godot4.7.2 `ed1daf0bf`, fixed executable
`build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe` (GUI companion for live work),
unchanged Godot AI4.2.3, canonical `res://scenes/application/application_shell.tscn`.
The inactive Steam editor was normally closed before the official isolated editor
PID36616 used the existing workstation debug port6107. That editor was also normally
closed after acceptance. No plugin/project debug configuration was changed.

Reused isolated APPDATA: `build/p2b-live/AppData/Roaming`; save suffix
`Godot/app_userdata/Eastern-Stories-Godot/save-data/development/default-v1.json`.
LOCALAPPDATA remained normal for existing helper transport; no credential copying.
Initial public menu had no Session and exposed the existing compatible isolated Save.
That P2B Save contained five full-health serpents, Player at Lake north, source cloth
and purchased red-wine wineskin15, QA Player vitality maximum100000, money/supplies
as disclosed in P2B. It was saved **before** P2B Fill/combat; later P2B actions were
not treated as saved. All P2C Continue/Save operations used the actual public UI.

Before the independent death branch, paused and outside an encounter, existing typed
state access through game_eval set Player combat_experience250000 and raw unarmed100;
production `oldpine.outdoor.lake.serpent.1.character` kee current/effective1/1,
maximum unchanged1800. Its lifecycle remained ACTIVE. Player remaining vitality
was approximately69227/71155/100000; no refill was needed. No attributes, other NPCs,
definitions, formulas, seed/state, rewards or mapping were changed. No sixth snake.
These four disclosed setup writes preceded the death route; all later observations
were read-only and all actions were normal input. No direct death/lifecycle invocation,
negative-life setup, forced hit, selected seed, redraw or gameplay callback was used.
This is wounded-state engineering acceptance, **not** natural growth or a novice
victory against five full-strength serpents.

## Real mouse input and complete-set Attack

Windows computer-use targeted the returned game window, activated it, and observed
the actual1152×648 framebuffer plus editor game-window chrome. This resolved the
initial occluded-window capture. Native clicks have press/release ownership in the
OS input primitive. Preflight clicked public Continue and Flee: actual Session
publication and accepted/started/resolved Flee feedback proved delivery, beyond sent=true.

At physical position approximately(1438.331,2426.332), six participants were present
and authoritative Player target was `oldpine.outdoor.lake.serpent.1.character`.
Native mouse dragged the visible horizontal scrollbar to its right end, exposing
the fifth card; one click changed target to `oldpine.outdoor.lake.serpent.5.character`.
The card acquired the current-target gold border and UI showed **Target: Changed**.
No repeated blind click loop, direct target setter or keyboard substitution.

Real Flee completed; without moving or disabling aggression, the Player clicked the
visible production snake2 body and then the normal **Attack** button. Authority
reported six participants and target `oldpine.outdoor.lake.serpent.2.character`.
Thus manual Attack used the production complete-set entry rather than isolating
the selected target. Normal Flee then physically walking north restored safe world
control. Retained UI receipts show Queued: Accepted → Execution Started: Accepted
→ Resolved: Disengaged. No forced encounter/flee callback.

## Cross-process checks A and B

Both checkpoints use actual Pause-menu **Save**, visible **Your journey was saved**,
normal Alt+F4 process termination, an OS process lookup proving the old PID absent,
a new game PID with empty main-menu Session, and an actual mouse click on **Continue**.
The editor could remain, but no old game Session survived. Immediately after Continue,
normal Escape paused before further gameplay; comparison was against the restored
running objects, not merely the file. Subsequent play is outside the equality boundary.

| Field | A — five alive | B — snake1 dead, four alive |
|---|---|---|
| Actual saved UTC | 2026-09-26T07:48:11Z | 2026-09-26T07:57:01Z |
| Old game PID, confirmed absent | 58720 | 37304 |
| New game PID | 37304 | 55500 |
| Session object before → after | 964354379036 → 1234199121247 | 1234199121247 → 1279849925989 |
| Character object before → after | -9223371099813704399 → -9223370829968962177 | -9223370829968962177 → -9223370788076253961 |
| Save position x/y | 1438.33068847656 /2096.32446289063 | 1438.33068847656 /2195.32666015625 |
| Kee current/effective/max | 80195/81403/100000 | 69045/70967/100000 |
| EXP /potential /spent | 0/99/0 | 250006/100/0 |
| Formal NPC records /corpses /item records | 10/0/15 | 10/1/16 |
| Allocator next_dynamic_sequence | 2 | 4 |
| Complete saved = pre-exit = restored runtime snapshot | **PASS** | **PASS** |

The pure existing `OldPineWorldSaveCapture.new().capture(session, &"development",
saved_at_utc).snapshot` → `GameSaveJsonCodec.encode(...).text` path was source-checked:
it creates snapshot/builder values, reads stored RNG, and performs no Save request,
file write, Session replacement, RNG draw or gameplay mutation. game_eval returned
this existing projection without a temporary script/helper. The exact original
metadata timestamp/profile/null build_commit were supplied for comparison; no durable
field was omitted or normalized away. Encoded pre/post runtime text was equal, and
both parsed complete documents equal the actual saved JSON. Runtime JSON evidence
is ignored under `build/p2c-{a,b}-{pre,post}-runtime.json`.

This comparison covers root schema2/item3, **SOURCE_ENTRY_LAKE_V1**, all ten slot
records, stable Player/NPC/item IDs, attributes/body, current/effective/max resources,
skills/learned/mappings/affiliation, equipment, full item/container graph, positions,
allocator and all three RNG seed/state pairs. Runtime host had exactly one Session
and ten NPC records, with newly allocated Session/Character objects. No duplicate NPC.
The constant item scope was `oldpine-session-df48abe5a1926a9ed5ae0d76ab45793a`.
Both saves correctly still held RED_WINE15 in `.dynamic.1`; this slice did not claim
that the unsaved P2B Fill had survived. Real battle damage/RNG and location distinguish A.

| Stored RNG | Seed, both checkpoints | State A | State B |
|---|---|---|---|
| Combat | -4332726960126679729 | -6183341740649988944 | -6161310312020194714 |
| NPC initialization | 5317432777314293827 | -6195616932558569798 | -6195616932558569798 |
| World interaction | 3537733373800266396 | 9129066360235789054 | 9129066360235789054 |

Read int64 evidence was formatted as decimal strings to avoid debugger JSON float
precision loss. All restored seeds/states equal their saved values. No extra draws.
Actual saved evidence: A37586 bytes, SHA256
`1bc189ba5dfff085ca04d6e4e8ae84231747094f3889ad89c53eafbce44669e7`;
B38816 bytes, SHA256
`276bdf43880db7b0d7cd8aba90d9c97f93d25f0a8f66e19be0b8ff992ab77988`.
Copies `build/p2c-checkpoint-a.json` / `build/p2c-checkpoint-b.json` are local ignored
evidence, not shipped saves or committed artifacts.

After A equality, real movement re-entered all five contacts; native scrollbar and
click again selected snake5 with six participants and Target: Changed. Real Flee
completed and the Player physically returned north. Thus the restored graph was usable.

## Actual death, corpse and restored return

From the disclosed positive-health precondition, real movement entered snake1's
ordinary production contact. During a pause, two reads showed identical paused=true,
scheduler logical time2.0, event count4, Combat state-7450874159908355972. Real Resume
continued production scheduling. Ordinary attacks produced visible27 and22 damage;
snake1 became DEAD/exists_in_map=false, one corpse was published, and the ordinary
encounter ended with Victory (terminal kind0). There was no remaining in-range enemy
in that encounter; the other four production snakes remained independently alive.
The retained final Player event's already-committed bounds were
`[1,3,291607,291607,30,250000,22,1799]`, draws
`[0,1,50406,221753,14,76720,3,1313]`; observation did not draw again.

Corpse `.dynamic.3` belongs to `oldpine.outdoor.lake.serpent.1.character`, at(1340,2470),
Lake zone, male/age400, fresh stage0, capacity200000, no invented contents or worn loot.
B persisted raw unarmed100, naturally acquired dodge1/parry1 and retained learned
progress; these are QA-path effects, not a natural progression claim. After B cold
restore, the exact corpse/slot/item graph matched. Real movement entered Lake at
(1438.331,2246.661), left north to River Gorge(1438.331,2176.993), then returned to
Lake(1438.331,2246.661). Snake1 remained DEAD, the same corpse ID remained, and the
ledger stayed ten records. No reset-style resurrection or duplicate instance.
Existing automated tombstone-without-corpse coverage is reused, not re-enacted for
every snake or death order.

## Health and device qualification

All three live launches reported helper_live=true/session_active=true and
current_run_errors=[]; the final runtime log had no non-info entries. Read-only
captures completed without debugger break. Final actual framebuffer observations
advanced from frame11828 to13779 with stale_frame=false while paused. Normal Pause
freezes gameplay, not framebuffer rendering. Game PID55500 and editor PID36616 were
normally closed after evidence capture; the isolated B save remains intact.

**Touch — PENDING (device/tool capability), not a demonstrated product defect.**
Read-only Windows HID enumeration found no touch device; Android `adb devices -l`
returned no connected device. The available Godot AI input surface exposes mouse,
keyboard/actions and gamepad, not genuine touch. No device installation, plugin
upgrade, emulated-touch claim or broad device matrix was introduced. The outstanding
representative check is real touch movement/scroll/pick fifth/Flee with applicable
safe-area/focus/Pause/Back/background behavior. Desktop mouse and historical keyboard
passes do not satisfy that device qualification.

## Existing failure disposition and final local verification

P2B's18 failed assertions and one script error were checked against its committed
corrections and retained `build/p2b-affected-regressions.log` (all16 groups pass101.12s).
Root causes: stale three-group/five-NPC/zone/room counts; old closed-Lake and old-world
public restore expectations; BF4 QA courage draw bound after15 new production NPC
draws; restore adversary assuming sorted slot0 had human loadout. The last now selects
a human by identity. No production RNG/formula changed; no canonical test was removed.
No unresolved discovery failure was silently dropped; the complete run below is the
final gate, not a replacement by targeted pass counts.

Final command (no skip flags, no additional duplicate run_tests invocation):

```text
python tools/ci/verify.py --godot build/toolchain/editor/Godot_v4.7.2-stable_win64_console.exe
```

Python3.12 used UTF-8 mode. Exact executable/test commit:
`ef8b7d601983c80d817bf28a93e554f2472a49a6`; tracked game/tools matched that commit
before execution. Coverage: complete Python tooling tests, repository/static,
development editor import/parse, full registered gameplay suite, actual release
sanitizer and sanitized-project editor validation. **PASS**, exit0, **543.8597017s**
(9m03.86s). All five stages completed; the canonical gameplay suite reported
21605 assertions passing, with no failed assertions or script errors. This was one
complete P2C invocation, not a composition of partial runs.
Logs: ignored `build/p2c-verify-full.log`, `build/p2c-verify-result.json`.
Post-run executable/test identity against the same commit also passed. Documentation
relative links/anchors and `git diff --check` passed before the docs-only commit.

Later docs-only changes do not invalidate this executable evidence. Final Audit
should reuse a successful result on unchanged executable/test bytes rather than
repeat it without cause. Relevant code changes require impact-based requalification.

## Owner gate

No new production defect identified in the executed runtime paths. No Lake repair,
rebalance, dependency upgrade or test-platform change. Historical P2B reports stay
unchanged. Current-state docs link this report and preserve the device gap.

**P2C — TOUCH QUALIFICATION PENDING / AWAIT OWNER REVIEW.**
**LAKE — IMPLEMENTED; OVERALL LOCAL ACCEPTANCE NOT YET COMPLETE.**
**FINAL AUDIT / PR / MERGE — NOT STARTED.**
