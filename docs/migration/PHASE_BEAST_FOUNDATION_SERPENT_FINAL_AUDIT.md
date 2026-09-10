# Beast Foundation + First Serpent Runtime Integration — BF5 Final Audit

## Executive Result

**BF5 formal local audit PASS. Implementation + formal local audit complete.**
No production or test correction was required. This checkpoint authorizes the unique final ready PR,
not merge. The milestone is **NOT fully integrated** until same-HEAD PR CI passes, the owner explicitly
authorizes merge, and post-merge main CI passes. No next milestone was started.

## Baseline / Candidate

- Branch: `phase/beast-foundation-serpent-runtime`.
- Stable base: `5cf3f4efb80816cb40389d093b7187e4cabdff5b`.
- Owner-approved BF4 / audited executable candidate: `0ecf7f54ed32cdfa79a18b770528458595945894`.
- Audit date: 2026-09-10. Fetch confirmed local/remote candidate equality, unchanged origin/main,
  clean phase worktree and no existing open phase-to-main PR before audit.
- BF5 adds this report and updates STATUS/ROADMAP only. Its containing commit is the final local
  candidate; executable source remains identical to the approved BF4 commit.
- Work performed in `build/beast-foundation-worktree`. Owner main-worktree local project/plugin
  changes were neither overwritten nor included. Their pre-audit SHA-256 values were preserved.

## BF1–BF4 Closure

The complete base-to-BF4 delta is 55 files: 12 production GDScripts, three production UID sidecars,
37 test/fixture/runner files including UID sidecars, and three documents. BF5 adds one document,
so the final milestone has 56 changed files. No unrelated production changes were found.

| Slice | Production boundary reviewed | Closure |
|---|---|---|
| BF1 | `character_derived_values.gd`; `npc_character_state_factory.gd`; `npc_definition.gd`; `npc_authored_combat_facts.gd`; `oldpine_npc_definitions.gd` | Owner-approved; source formulas/default presence/RNG order/serpent definition verified |
| BF2 | `beast_combat_action_definitions.gd`; `world_combat_binding_adapter.gd`; `combat_slice_content_profile.gd`; `combat_slice_projection_builder.gd` | Owner-approved; action/anatomy/intrinsic projections enter existing combat authorities |
| BF3 | `npc_body_facts.gd`; factory; `oldpine_world_restore_composition.gd`; outdoor death context | Owner-approved; narrow body policy, no-reroll restore composition, stored death body facts |
| BF4 | `oldpine_outdoor_controller.gd` registration/removal/lookups; QA-only publication/integration test | Owner-approved at candidate; generic physical binding seam and accepted live evidence |

All changed tests, support fixtures, four standalone runners and canonical registrations were reviewed.
The two historical human death tests now expect initialized/stored NPC weight/capacity after a QA
strength mutation, matching chard.c rather than recomputing at death. This is not a combat adjustment.

## Source Fidelity

Sampled authoritative LPC again, without reopening full archaeology:

- `reference/es2/mudlib/adm/daemons/race/beast.c`
- `reference/es2/mudlib/include/race/beast.h`
- `reference/es2/mudlib/d/oldpine/npc/serpent.c`
- `reference/es2/mudlib/adm/daemons/chard.c`
- `reference/es2/mudlib/std/char.c`
- `reference/es2/mudlib/feature/attack.c` (relationships, selection, action-provider precedence)
- `reference/es2/mudlib/adm/daemons/combatd.c` (skill power and ordinary damage/wound calculation)
- `reference/es2/mudlib/feature/skill.c` (effective skill semantics)
- `reference/es2/mudlib/feature/equip.c`
- `reference/es2/mudlib/feature/move.c`
- `reference/es2/mudlib/obj/corpse.c`
- `reference/es2/mudlib/feature/damage.c` (current/effective negative saturation)
- `reference/es2/mudlib/adm/daemons/race/human.c`
- `reference/es2/mudlib/d/oldpine/npc/bandit.c`
- `reference/es2/mudlib/d/oldpine/npc/tall_bandit.c`
- `reference/es2/mudlib/d/oldpine/npc/fat_bandit.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/short_sword.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/long_sword.c`
- `reference/es2/mudlib/d/oldpine/npc/obj/leather.c`
- `reference/es2/mudlib/std/weapon/sword.c`
- `reference/es2/mudlib/std/armor/cloth.c`
- `reference/es2/mudlib/std/equip.c`

ES2 supplies mechanics, conditions and outcomes; Godot supplies typed composition, physical bodies,
real input and presentation. No LPC object runtime, query/set store or callable daemon dispatcher
was recreated. Entire milestone `reference/es2` delta is zero.

## Architecture

Beast support is new source-valid input to existing authorities, not a second combat implementation.
No changes to CombatMath, CombatAttackResolver, relationship, busy, progression, Encounter, Scheduler,
CXR target authority or tactical queue. Typed scalar intrinsics and copied anatomy/verb arrays belong
to authored NPC facts; per-character mutable state remains independently constructed.

`NpcBodyFacts` is only Human/Beast body-weight selection plus common capacity; unsupported races fail
closed. It is not a registry. Content readiness rejects missing/invalid Beast anatomy or unsupported
verb distributions instead of borrowing human limbs/actions. Verified equipment/mapped providers retain
their existing precedence. Production intrinsic projections are not raw skills or fabricated items.

## Beast Initialization

Source order for undefined fields: age `random(40)+5`, str `random(41)+5`, cor `random(21)+5`,
int `random(11)+5`, spi `0`, cps `random(11)+5`, per `random(31)+5`, con `random(41)+5`.
Missing kar is effectively zero, with no human random default. Explicit authored zero is present.
Serpent supplies age400, str40/cor70/int10/spi20 and maxima900/1800/500; only cps/per/con draw,
with ordered bounds `[11,31,41]`. No heartbeat scheduling draw was imported.

For age `a`, source-derived missing maxima are:

| Track | Exact branches |
|---|---|
| gin | a<=3:50; a<=10:50+(a-3)*20; a<=30:190+(a-10)*5; otherwise290+a-30 |
| kee | a<=5:50; a<=20:50+(a-5)*25; otherwise425+(a-20)*5 |
| sen | a<=20:50; otherwise50+(a-20)*10 |

Weight is `2000+(str-10)*2000`, without clamp; capacity is `str*5000`.
Serpent weight62000/capacity200000. Boundary tests include negative age/weight and authored zeros.
Unrepresentable legacy resource triples are explicitly rejected by the closed native resource boundary,
not silently repaired. Source's repeated max assignment is redundant; wolf resource anomalies are
not covered by a full-parity claim.

## Serpent Combat

Exact anatomy: 头部 / 躯干 / 尾巴. Only verb `bite`: ordinary action, 20% damage modifier, 咬伤.
Intrinsic attack60/damage20/armor90/dodge80. Even one verb still consumes `next_below(1)` once.
Existing forward/reverse pipeline retains ordered random draws and live state projection.

Attack60 is usage bonus; dodge80 joins the effective dodge input before skill-power calculation;
damage20 adds to verified equipment damage; armor90 is used by the existing wound rule, not invented
current-damage reduction. Tests cover attacker/defender/reverse projections, busy/live spirit/skills,
real leather addition/removal and verified sword precedence without duplicate modifiers.
There is no tactical Bite, fabricated skill/equipment, Beast-only resolver or Phase5B4 hook.

## Persistence

**Serpent persistence composition capability verified.** This is **not normal-player serpent
Save/Continue complete**. Existing production spawn validation still rejects an extra serpent slot.

Current v1 schema/codec unchanged. No serialized limbs, verbs, intrinsic apply or combat profile.
The round trip uses existing capture/codec/item/Character restoration and a deliberately test-only
composition of production constructors. Semantic IDs and saved resources, progression, skills,
conditions, life/existence, age and body facts survive in fresh object graphs. cps/per/con are retained;
restored NPC RNG performs zero draws and continues from its saved state. Definition facts are rebuilt
from the catalog. Exact restored Equipment/Armor objects are injected, not replaced by a second pair.

Production `_restore_npc_ledger` validates supported race-aware body facts but neither calls the fresh
NPC factory nor broadens authored slots. Human Save/Restore retains five NPCs and twelve items.
Validation against saved strength is the existing derived-body policy, not support for arbitrary future
body transformations; dynamic race/body-state changes would need separate source analysis.

## Death / Corpse

NPC death copies stored runtime `body_weight` and `maximum_encumbrance`, as chard.c copies the victim's
weight/capacity. It does not rerun setup or recalculate from death-time strength. Existing Player policy
is untouched. The accepted serpent corpse is 黑冠巨蟒 / 雄性 / age400 / weight62000 / capacity200000,
with no invented loot. DeathInventoryService, CorpseState and world publication remain authoritative.

## Runtime Integration

`register_npc_body` accepts an already-created valid NPC and a map-owned, unbound non-Player body,
standard collision child and descendant presence Area. It requires the same map, no duplicate
character/member, an open world and a ready combat binding. It adds membership/binding/lookups and
selection/presence subscriptions; it neither creates NPC state nor establishes combat relationships.

`unregister_npc_body` rejects frozen-world/live-fight removal, disconnects the subscriptions, removes
lookup/list/MapCharacter membership, clears pending aggression and selected target. Caller owns physical
node removal. Existing fixed-body initialization is unchanged. No serpent-specific registration branch.

Production `OldPineSpawnDefinitions.all_spawns()` remains three groups: three scouts, one Tall, one Fat;
five NPCs, eleven NPC item objects plus Player's starting sword = twelve initial items. No serpent slot.

## QA Isolation

Publication, wounded1/1/1800 state, strength modifier180, Player experience250000 and fixed
`WoundedProofRandom` live only in `game/tests/runtime/bf4_serpent_publication.gd` and test callers.
Ignored live-copy/observation tooling remains outside tracked production. Production search for
`bf4_serpent_publication`, `WoundedProofRandom`, `prepare_wounded_proof`, `qa.bf4` and `QAOnlySerpent`
found zero references. Development's pre-existing QA bridge is unchanged and stripped for release;
it is not a normal New Game BF4 publisher. Invalid extra-slot Save remains rejected.

## Run A Evidence

**REUSED**, explicitly permitted because BF5 makes no production correction. Full original evidence
is in [BF4 source contract/evidence](PHASE_BEAST_FOUNDATION_SERPENT_ANALYSIS.md).
Run `r84926-1`: canonical ApplicationShell -> real New Game -> explicit source-fresh QA publication ->
real movement/presence/aggression -> existing Encounter/Battle. 黑冠巨蟒 executes ordinary bite using
production Combat RNG; Player naturally loses. Encounter/Scheduler release and world reopening observed.
helper_live/session_active/game_capture_ready were true; runtime errors empty; frames638/4038/4772/8311
advanced with stale_frame=false. This is source-fresh runtime behavior, not a balance defect or approval.

## Run B Evidence

**REUSED**, same unchanged-production basis. Run `r22431-1` is the accepted **deterministic QA-wounded
lifecycle proof**, not natural victory. Existing long sword25; Player effective strength200 and
experience250000; serpent1/1/1800, armor90. Fixed ordinal script was selected before input, no seed search.
Source math: `(25+0)/2+(200+0)/2=112`; wound draw91/112 exceeds armor90; wound22; effective1-22 -> -1.
Actual resolver death -> lifecycle -> corpse -> real Open Loot **Empty** -> fresh movement/control return.

Canonical menu/New Game, approach and loot used real input. Only stated preconditions used typed QA
setup; no direct attack/death/loot branch stood in for the route. Accepted frames1050/7408/12646/17533
were non-stale and advancing; helper/session/capture healthy, current errors empty. Player ACTIVE,
Encounter absent, Scheduler null, world open, old cadence false. Prior wounded-only failed attempt
remains documented history and is not promoted to PASS. **NO BALANCE ACCEPTANCE CLAIM.**

## Full Canonical Validation

Official Godot `4.7.2.stable.official.ed1daf0bf`.
Ran `tools/ci/verify.py --godot <official-4.7.2-console>` with no skip/check-only flags.
It executed `res://tests/run_tests.gd`: **16,895 assertions PASS, zero failures, exit0**.
The full verification command completed once, exit0, `Phase 10A verification PASS`.
No SCRIPT ERROR/ERROR/FAIL found in its log. This is actual complete execution, not registration proof.

Independent focused runners were also executed:

| Runner | Assertions | Failures / exit |
|---|---:|---|
| BF1 + human regressions | 958 | 0 / 0 |
| BF2 | 201 | 0 / 0 |
| BF3 | 162 | 0 / 0 |
| BF4 | 101 | 0 / 0 |

Focused total1422 includes overlapping historical checks; do not add it to canonical as unique coverage.
Initial sandboxed focused/startup runs passed but emitted Windows root-certificate-store access errors.
The same focused/startup commands were repeated outside the sandbox: identical counts, no errors.
This environmental diagnostic rerun did not repeat the full suite or change code.

## Sanitizer / Shipping Boundary

Formal verify also ran Python **46 tests PASS**, repository/static checks PASS, development headless
editor PASS, actual `prepare_release_project.py`, `validate_release_project.py` and sanitized headless
editor PASS. No verification gate changed.

Additional actual sanitized canonical-main startup: `--headless --path build/verify-release-project
--quit-after 120`, exit0, no script/runtime error in the unrestricted confirmation. Tests, Godot AI
helper and test runners are absent. Text scan found zero BF4 QA identifiers, `res://tests/`,
remote-debug or godot_ai references. Required Beast facts/body/action and world binding scripts remain.
No missing script/UID dependency was observed. This is a source-sanitized startup check, not a new
packaged-artifact or physical-device claim; Windows/Android/iOS final builds belong to PR CI.

## Regression

Complete canonical plus independent BF tests passed. Human sixteen limbs, current punch fallback,
default RNG, ordinary/Tall/Fat source facts, short sword15/long sword25 and leather armor5/dodge-2
remain unchanged. Existing closed action-subset/advanced-NPC limitations are not full human parity.
Save schema, source spawn ledger, existing loadouts, encounter/cadence and application boundaries
remain unchanged. Full milestone diff check and changed-file trailing whitespace scan pass.

## Scope Exclusions

Entire milestone deltas: reference/es2 **0**; DECISIONS **0**; export presets **0**; CI/build tooling **0**;
package identity/signing **0**; tracked project/plugin **0**. Owner local tooling changes excluded.
No Lake/map extension, Riverbank1 south portal, water runtime, production serpent placement,
multi-serpent aggregation, dynamic participants, pre-freeze collection, UI redesign or final art.

## Known Deferred Parity Gaps

Lake and five serpents require the next authorized authored-content milestone. Full Beast parity is
not delivered: wolf resource anomaly, butterfly negative-weight/content boundary, venomsnake
hit_ob/poison/pursuit and other verb distributions remain deferred. Phase5B4 martial/condition hits,
weapon post-actions and perform multi-actions are untouched. No balance adjustment/acceptance.
Legacy cloth armor_apply/armor_prop mismatch and Beast redundant max assignments are not silently
corrected. No new implemented compatibility substitution requires a DECISIONS entry.

## Integration Readiness

- Beast Foundation: **YES**, only proven initialization/body/combat seams.
- Serpent Core-Compatible: **YES**.
- Serpent Runtime-Integrated: **YES**, controlled QA publication.
- Lake Serpent Player-Reachable: **NO**.
- Full Beast Parity: **NO**.

Local implementation/formal gate is complete. Commit/push this documentation-only closure on the same
branch, then create one ready final PR against unchanged base main. Require Godot Verify, Windows
Release Build, Android Release Build and iOS Build Validation green on the same final PR HEAD.
At this local checkpoint PR/CI are pending, not claimed successful; their actual result is reported
with the final PR URL/HEAD/run. No need to rerun accepted live routes for documentation-only closure.

## Merge Boundary

**MERGE NOT AUTHORIZED.** Stop after final PR four-job CI success. Retain branch; await explicit owner
merge authorization. Fully integrated status requires the later authorized merge and green post-merge
main workflow. Do not start Lake, Phase5B4 or another major milestone here.
