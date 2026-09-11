# NGE5A0 — Player Body Facts Authority + Persistence Semantics Contract

## RESULT

Implementation on `phase/source-valid-new-game-entry`, starting from approved
`6e73cf80b7b42bddc0d561e2992c77733bc578ca`. NGE0–NGE4 are owner-approved.
NGE5A0 is the separately authorized prerequisite; complete NGE5A and NGE5B are not started.
NGE5A0 implementation and verification PASS; await owner review. No PR or merge.

## BLOCKER DISCOVERY

NGE5A's required pre-audit found an existing production path, not a future training feature:
combat completion -> `CombatProgressionService` -> `CharacterSkillState.improve_skill()` ->
registered unarmed effect -> permanent strength change. The previous Player death projection
re-derived body weight/capacity from current strength, whereas runtime carry capacity remained
setup-time state. Restore incorrectly required saved capacity == current strength * 5000.

The owner explicitly approved the independent body authority and continuation policy implemented
here. This does not claim that a fresh character was manually trained to level129.

## LEGACY SOURCE SEMANTICS

Directly inspected relevant implementations and dependencies:

- `reference/es2/mudlib/daemon/skill/unarmed.c`: after new raw level `s`, if `s % 10 == 9`
  and `str < s / 4` (integer division), add2 to str only.
- `reference/es2/mudlib/feature/skill.c::improve_skill`: strict learned threshold, one level,
  reset learned, then invoke `skill_improved`.
- `reference/es2/mudlib/adm/daemons/combatd.c`: HIT attacker improvement can invoke that skill
  path when AP < DP and the gin/intelligence draw is >30 in non-user/user combat.
- `reference/es2/mudlib/feature/dbase.c::add/set`: the attribute write has no body refresh hook.
- `reference/es2/mudlib/adm/daemons/race/human.c::setup_human`: only zero own weight triggers
  `40000 + (str - 10) * 2000` initialization.
- `reference/es2/mudlib/adm/daemons/chard.c::setup_char/make_corpse`: capacity is initialized
  only if zero, using str*5000; corpse copies the victim's existing weight and capacity.
- `reference/es2/mudlib/feature/move.c`: weight and maximum encumbrance are separate static
  runtime fields; setters do not clamp. Contents encumbrance is separate from own weight.
- `reference/es2/mudlib/adm/daemons/logind.c::make_body/get_passwd/enter_world`,
  `reference/es2/mudlib/obj/user.c::setup`, `reference/es2/mudlib/std/char.c::setup`,
  `reference/es2/mudlib/feature/save.c::restore`: reconstruction/setup chain described below.

No LPC, skill progression formula, combat formula, RNG source, or NPC body policy changed.

## LIVE BODY VS FULL LOGIN

Same live LPC body: ordinary str growth does not refresh established weight/capacity.
Human/chard setup is conditional on zero, not an attribute observer. Corpse copies stored facts.

Full login after the old body is gone: logind creates the configured body, restores saved state,
enters the world and calls user.setup -> char.setup -> race/chard setup. Static move fields of
the new body start at zero, so this reconstruction can derive again from saved current strength.
Reconnecting to an already-existing body is distinct. No login runtime is being ported.

## NATIVE CONTINUE DECISION

Owner-approved **native save-continuation compatibility substitution**:
native Save/cold Continue means exact continuation, not legacy new-login-body reconstruction.
See [Player Body Facts and Native Continue](DECISIONS.md#player-body-facts-and-native-continue).

## PLAYER BODY AUTHORITY

`game/core/characters/player_body_facts.gd` is Node-free, typed, read-only through its public API,
with exactly `body_weight` and `maximum_encumbrance`. No Dictionary, property bag, race registry,
or generic body rebuild system. All signed int64 field values are representable, including zero
and negative values: LPC setters and the existing v1 capacity schema impose no positivity clamp.
There is no validation equality against current strength. A runtime Player must have a non-null
body object to pass `is_valid()`; omitted/null constructor input never derives guessed values.

`NewPlayerInitialization.body_facts` and the resulting `WorldPlayerRuntimeState.body_facts`
refer to the exact same object. Existing scalar convenience getters only delegate, never duplicate
stored facts. Every production constructor explicitly supplies fresh-body or legacy-v1 interpretation.
Independent fresh Players receive independent objects. No strength setter updates body facts.

Fresh source Human str30:80000/150000; technical Human str20:60000/100000.
`PlayerBodyFacts.fresh_human` reuses existing `CharacterDerivedValues` formulas only at birth.
Source food/water initialization still uses its birth weight and existing capacity functions.

## STRENGTH PROGRESSION

The test establishes raw unarmed128/learned16641, then calls production `improve_skill` with1:
16642 >129², new level129. Registered unarmed effect sees30 <129/4=32 and raises str to32.
The same body object remains80000/150000. No production skill/registry changes were needed.
Post-v1-restore str32 at level139 becomes34 while its body remains84000/150000.
Technical str20 at level89 becomes22 while its body remains60000/100000.

## DEATH FACTS

`WorldPlayerRuntimeState.death_context()` copies body facts, identity facts, and Character gender.
Source strength32 after the real effect yields corpse weight80000/capacity150000, not84000/160000.
Old Pine already delegates actual Player death to this method. Its unrelated NPC path is unchanged.
Player corpse restore capacity validation now uses the saved Player capacity, not derived strength;
v1 missing Player weight interpretation remains the one specified below.

## ENCUMBRANCE

Audited fresh inventory composition, Session starter transfer, loot adapter, inventory/equipment
projections/adapters, capture, restore and death. Existing Player carry consumers use
`player.maximum_encumbrance`, now a delegation to the one body authority. No equipment or transfer
formula was changed. NPC consumers/authority remain independent.

Own body weight80000 is not cloth weight3000 and not inventory contents weight. Focused tests
check exact150000 acceptance and150001 rejection, plus the production loot adapter rejecting
157000 despite str32 and admitting exactly150000 after fixture ballast is reduced.

## LEGACY V1 INTERPRETATION

No schema or field changes. For valid v1, restore Character first, then
`PlayerBodyFacts.from_legacy_v1(saved_strength, saved_capacity)`:

- Missing weight derives once from saved strength. str32 ->84000.
- Existing capacity is authoritative. Saved150000 remains150000, not160000.
- No birth, food fill, cloth grant, ID allocation or identity heuristic.
- After restore, ordinary strength growth does not change either established body fact.

Existing NGE1 arbitrary exp/food/water/equipment/items/RNG/allocator regression is retained; its
historical fixture explicitly establishes a representable body instead of writing a removed scalar.
New JSON -> fresh production candidate coverage proves divergent-capacity v1 and Player corpse
restore, shared body injection into both physical maps, and no new cloth/initialization draws.

## V1 REPRESENTABILITY

Current capture checks identity first (source identity remains rejected at `player.facts`).
For technical identity, v1 can represent body weight only when it equals human_weight(current str).
Otherwise capture returns `UNREPRESENTED_CHARACTER_STATE` at `player.body_facts.body_weight`.
It never adds a body field to v1 or silently loses weight. Saved capacity comes from body authority.
Ordinary technical saves and representable restored v1 remain writable; capacity need not equal
current str*5000. The existing repository/Save failure flow receives the typed capture failure.

## SCHEMA2 CONTRACT

Future NGE5A schema2 MUST persist exact Player body_weight and maximum_encumbrance and restore both
without derivation. Native Continue does not invoke birth or emulate LPC full login. Only a future
source-backed explicit rebuild/transformation event may change body facts; none is implemented here.
This slice implements no schema2 codec, content revision serialization, or source Save/Continue.

## TESTS

Godot4.7.2:

- `--headless --path game --script res://tests/run_nge5a0_tests.gd`: **260 assertions,
  0 failures, exit0**, including body facts, retained NGE1 old-save regression and NGE4 route.
- Complete `--headless --path game --script res://tests/run_tests.gd`: **17,553 assertions,
  0 failures, exit0**. Final log `build/nge5a0-canonical-final.log`; focused log
  `build/nge5a0-focused.log` (local ignored evidence, not committed).
- Headless editor PASS; repository/static checks, `git diff --check`, changed-file trailing
  whitespace and changed-document local links PASS.
- reference/es2, build/CI/export/project settings, scenes, NPC/Combat/Skill production delta:0.
  DECISIONS contains only the explicitly approved Player body decision.

During implementation, corrected new fixture mistakes (DTO field name, defensive snapshot copy,
unavailable transfer destination), two historical Player test-subclass constructors, and the obsolete
restore test expecting divergent saved capacity to fail. No production rule was weakened to satisfy
those tests. An initial editor command used a relative log path that Godot resolved under user://;
final validation uses absolute log paths and has no such directory error.

NGE4 physical headless round-trip regression now checks the same body authority and80000/150000
at Inn/Snow/Old Pine/return checkpoints. Movement/handoff code and scenes are untouched.

Additional real desktop smoke used the existing QA source-entry launcher into the production
OldPineWorldSession (run_token14, start43069181). No state injection or direct movement callback.
`move_right` real input for35 frames moved the Player from(0,0) to(102.66665,0) in Snow Inn.
The same body authority `-9223371845091194671` retained80000/150000; cloth remained worn and Session
item count12. helper_live/session_active/game_capture_ready were all true; launch current_run_errors
was empty and editor log cursor9 had no appended errors after the run. Screenshots at frames1447
and4246 both had stale_frame=false. Game stopped afterward. This was a binding/movement smoke,
not a new full traversal or UI acceptance claim; loot capacity was tested through its real typed adapter.
No claim is made of schema2, source cold Continue, mobile or packaged-build acceptance.

## NGE5A READINESS

**READY for separately authorized NGE5A work after owner review.** The owner decision is fixed;
NGE5A0 validation passed. Complete NGE5A remains
separately authorized work. NGE5B/public New Game cutover, Snow population, Lake, Phase5B4,
generic body frameworks, PR and merge are outside this slice. Stop for owner review.
