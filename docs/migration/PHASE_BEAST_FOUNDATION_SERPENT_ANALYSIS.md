# Source-valid Beast Foundation + First Serpent Runtime Integration

## Status and locked scope

BF1 — Source Contract + Typed Beast Initialization: **implementation and focused self-audit PASS**.
Base: `5cf3f4efb80816cb40389d093b7187e4cabdff5b`; branch:
`phase/beast-foundation-serpent-runtime`. Base main push workflow
[34302052253](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34302052253)
completed successfully. BF1 was owner-approved at `a6ebe800943a5300cdfa192dc8bd19b45d111a0d`.
BF2 — Beast Combat Facts + Bidirectional Combat Projection: **implementation and distinct self-audit
PASS** (201 new focused assertions), owner-approved at `06c0c10bcd35697b333d4e6c219c9a5c37bf3062`.
BF3 — Race-aware Persistence + Death Body Facts: **implementation and distinct self-audit PASS**
(162 new focused assertions), owner-approved at `472b1d368ab09dcf36a49d95abca1aaa85643691`.
BF4 is **implementation / distinct self-audit PASS — PENDING OWNER REVIEW**.
Run A remains accepted; expanded owner-authorized deterministic QA Run B passes the death/world gate.
No PR or merge; BF5 has not started. This is not major-phase closure.

This document consolidates the owner-accepted Source-valid Beast / Serpent dependency analysis
and Post-Phase10D migration coverage review from the task conversation, with the owner's explicit
Lake/persistence scope correction. Related repository evidence:
[Phase 9A §11](PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md),
[Phase 5A](PHASE_5A_COMBAT_DEPENDENCY_ANALYSIS.md), [decisions](DECISIONS.md).
This is source-semantic migration plus necessary native composition, not a new creature design.

| Slice | Boundary / acceptance | Status |
|---|---|---|
| BF1 | Exact formulas, fresh defaults/RNG, typed authored facts, serpent definition | PASS; owner-approved |
| BF2 | Bidirectional live Combat projection, limbs/bite/intrinsic modifiers, riposte | PASS; owner-approved |
| BF3 | Race-aware restore/body validation and death facts at the lowest real composition boundary | PASS; owner-approved |
| BF4 | QA-only single-serpent integration using production authorities and real player input | PASS; retained Run A + deterministic QA Run B; owner review pending |
| BF5 | Separately authorized formal audit and eventual final integration gate | Not started |

All slices stay on this major branch. Readiness is not authorization to continue.
Lake is **outside the entire milestone**: no Riverbank1→Lake entrance, Lake geometry, five production
serpent spawns, multi-serpent inclusion policy, save upgrade policy, or normal-player Lake Save/Continue
claim. Do not put a fake production serpent in Central Clearing/Pine or `all_spawns()` for testing.

## Authoritative source contract

Paths below are relative to `reference/es2/mudlib/`; source remains read-only.

| Inspected source | Relevant meaning |
|---|---|
| `d/oldpine/npc/serpent.c` | Exact authored identity, maxima, attributes, limbs, verbs, four applies, exp/score; no loadout or special hooks |
| `adm/daemons/race/beast.c`, `include/race/beast.h` | Presence-based defaults, ordered draws, piecewise maxima, weight, default action setup and Beast action table |
| `adm/daemons/chard.c`, `include/race.h` | Explicit race dispatch; missing current then effective resources use maxima; capacity; reset_action; corpse body facts |
| `std/char.c`, `std/char/npc.c` | NPC→Character composition, setup→CHAR_D, legacy scheduling; NPC attitude/carry/chat boundaries |
| `feature/attack.c` | reset_action mapped-skill→weapon→default precedence; aggression; ordinary scheduling boundary |
| `adm/daemons/combatd.c` (ordinary attack / skill_power sections) | Action and target limb draws, AP/DP, damage then wound, intrinsic apply consumers, progression |
| `feature/skill.c::query_skill`, `feature/attribute.c`, `feature/dbase.c::query` | Effective skill versus raw skill; raw attribute contribution; absent Beast karma has no human default-object fallback |
| `adm/daemons/race/human.c` | Preserve human random order/defaults, NPC authored-max precedence and body weight |
| `d/oldpine/npc/wolf_dog.c`, `butterfly.c`, `venomsnake.c` | Boundary comparisons only; none migrated |

Native inspection includes existing Character resource/attribute/derived authorities, NPC definition,
overrides/factory/runtime, Old Pine content/spawn definitions and existing Character/NPC/loadout tests.
No external port or driver compatibility layer is used.

### Exact setup order and presence semantics

1. NPC `create()` authors fields and intrinsic temp applies before `setup()`.
2. `std/char.c::setup()` establishes driver identity/liveness/heartbeat; `tick = 5 + random(10)`
   is **legacy scheduling infrastructure**, not a native NPC-initialization draw.
3. `chard.c` dispatches race. Beast assigns unit `只`; when `actions` is undefined it establishes
   `default_actions` from authored verbs, or a generic text mapping if verbs are absent.
4. Missing gender becomes `雄性`, then missing age and attributes are resolved in the order below.
   Beast does not set karma and does not attach human's default object; absent numeric karma is zero.
5. Only missing max_gin/max_kee/max_sen receive the age formulas. Beast weight is assigned only if the
   old queried weight is zero. `chard.c` then fills missing gin/kee/sen from their maxima, followed by
   missing eff_gin/eff_kee/eff_sen from maxima (not from current).
6. Capacity is assigned `raw str * 5000` if the old queried capacity is zero; then `reset_action()`.
   Reset selects mapped skill first, otherwise weapon, otherwise default actions. An authored
   `actions` value is not a blanket guarantee it survives this final reset.

BF1's factory constructs one unpublished typed Character aggregate; it composes each complete resource
track rather than reproducing observable LPC dictionary writes. There are no callbacks between these
assignments. Only after successful resource construction does the existing skill/loadout composition
run. Input definitions are never mutated. RNG consumed before an invalid draw/unsupported resource
shape is not rolled back or rerolled. `create_one()` retains its existing nullable failure contract.

Explicit authored zero is present. Missing facts alone get defaults. Global resource invariants are
unchanged: Beast tracks that cannot be represented exactly (`maximum < 0`, values below -1,
current > effective, effective > maximum) return null **before loadout mutation**, not a clamped NPC.
This limits supported content; it does not claim the LPC rejected such values. Human construction is
unchanged. An authored low effective value with absent current implies current=maximum in LPC;
that too is rejected if unrepresentable, not repaired to current=effective.

Current definitions have no authored weight/capacity override fields. BF1 covers their fresh-zero
starting path only; it does not invent generalized per-instance body overrides. Negative calculated
weights and authored ages are not clamped. Missing limbs are not automatically filled with human limbs;
successful initialization alone does not establish Combat readiness. `unit=只` remains presentation
metadata recorded here, without adding a new presentation field in BF1.

### Default RNG order

| Field | Beast missing default | Native mapping |
|---|---|---|
| age | random(40)+5 | runtime age |
| str | random(41)+5 | strength |
| cor | random(21)+5 | courage |
| int | random(11)+5 | intelligence |
| spi | 0, no draw | spirituality |
| cps | random(11)+5 | composure |
| per | random(31)+5 | personality |
| con | random(41)+5 | constitution |
| kar | not set; numeric zero, no draw | karma |

All draws use the existing injected `NpcInitializationRandomSource`; session ownership is unchanged.
Authored fields skip only their own draw. No global RNG, timer, heartbeat emulation, or restore reroll.
Human remains age random(30)+15, followed by eight random(21)+10 draws for missing attributes.

### Derived formulas

`a` = raw age, `s` = raw strength. No age floor and no force/mana/atman additions.

| Native method / legacy field | Exact branches |
|---|---|
| `beast_maximum_essence` / max_gin | a≤3: 50; a≤10: 50+(a−3)×20; a≤30: 190+(a−10)×5; else 290+(a−30) |
| `beast_maximum_vitality` / max_kee | a≤5: 50; a≤20: 50+(a−5)×25; else 425+(a−20)×5 |
| `beast_maximum_spirit` / max_sen | a≤20: 50; else 50+(a−20)×10 |
| `beast_weight` / weight | 2000+(s−10)×2000 |
| existing `maximum_encumbrance` | s×5000 |

Methods live in the existing `CharacterDerivedValues`, not a second character authority.
The repeated `my["max_gin"] = my["max_gin"] = ...` / max_kee assignments have no different numeric
result. The header's “at least 2 kg” comment is not enforced by its executable weight formula.

## BF1 typed composition and exact serpent definition

`NpcDefinition` gains an optional, defensively copied `NpcAuthoredCombatFacts` companion:
ordered `Array[String]` limbs, ordered `Array[StringName]` verbs, and four explicit integer getters
`intrinsic_attack/damage/armor/dodge`. Constructor inputs, getter arrays and definition snapshots do
not alias mutable callers. Read-only public API follows existing definition conventions; GDScript's
underscored backing fields are not language-enforced private storage. There is no generic apply map,
property bag, registry, action VM or serialized combat snapshot. Absence remains null for existing humans.
This data boundary does not validate/resolve arbitrary verbs or execute Combat; that consumer is BF2.

The small explicit human/Beast initialization policy stays in `NpcCharacterStateFactory`.
No second factory/hierarchy or generic race service is introduced. Existing raw skill, equipment,
Armor, Inventory, stack and runtime composition paths are retained.

`OldPineNpcDefinitions.serpent_definition()` and catalog lookup now expose:

- ID `oldpine.npc.serpent`; source `d/oldpine/npc/serpent.c`; name 黑冠巨蟒; alias `serpent`;
  original long description retained; race `野兽`→`beast`; age 400; aggressive attitude and the existing
  aggressive-on-player-presence capability metadata (no new behavior implementation).
- Authored str=40, cor=70, int=10, spi=20; gender missing→雄性; kar missing→0.
- **Exactly three fresh draws**: cps random(11)+5 → per random(31)+5 → con random(41)+5.
- Authored resource maxima win over age400 formulas (660/2325/3850): resulting current/effective/max
  are gin 900/900/900, kee 1800/1800/1800, sen 500/500/500.
- Weight 62000; capacity 200000; combat experience 250000; score 1000.
- Limbs `头部, 躯干, 尾巴`, verbs `bite`, intrinsic attack/damage/armor/dodge `60/20/90/80`.
- No raw skills or loadout; no authored hit_ob, post_action, perform, spell, condition-producing hook,
  or pursuer. No inferred fang/skin/money/medicine drop.

Catalog existence is not placement. `OldPineSpawnDefinitions.all_spawns()` is untouched: three scout
slots + one tall + one fat NPC, 11 NPC item objects and the existing separate player starting sword
(normal 12-item bootstrap). BF1 tests verify unchanged authored counts and existing loadout behavior;
they do not claim a newly run real New Game acceptance journey.

## Locked future consumers — NOT implemented by BF1

### BF2 Combat

Beast action table: hoof=100%/瘀伤, bite=20%/咬伤, claw=missing damage field/抓伤,
poke=30%/刺伤. Serpent only selects bite. `query_action()` still executes random(1) for one verb.
Preserve this Combat RNG draw; do not confuse it with fresh initialization draws. Text source for bite:
`$N扑上来张嘴往$n的$l狠狠地一咬`.

Projection must combine **live** learned skills/equipment/Armor with intrinsic definition facts, exactly
once, for forward attack, serpent-as-defender, and guarding reverse attack. Never turn dodge80 into raw
dodge, armor90 into a fake worn item, or use 16 human limbs/punch as fallback. Armor90 affects the
source wound gate, not all current damage. Do not cache effective skills at initialization.

Independent source checkpoints at full sen500, no raw skills: AP =
`(60³ / 3 / 500) * 500 + 250000 = 322000`; DP =
`(80³ / 3 / 500) * 500 + 250000 = 420500`, with integer truncation at each division.
These are BF2 acceptance expectations, **not BF1 Combat test results**.
Keep current Combat math, resolver, resources, relationships, busy, Encounter and scheduler intact;
produce correct inputs rather than inventing Beast combat/cadence or a tactical Bite button.

### BF3 persistence/death

Known human-only consumers remain unchanged in BF1:
`game/runtime/persistence/oldpine_world_restore_composition.gd` NPC body validation and
`game/runtime/world/oldpine_outdoor_controller.gd` death-context weight construction.
Later make only the narrow race-aware body-fact change, reusing the existing Character/item/NPC/RNG
snapshots and real restorer composition. Prove fresh graph B preserves mutable resource/skill/condition
facts, cps/per/con without reroll, RNG continuation and exact restored Equipment/Armor authorities;
rebuild immutable definition facts from the catalog. Existing human saves must still work.

Use the **lowest real persistence/composition boundary**, with test-only composition if needed.
Do not invent a production serpent slot, serialize duplicate limbs/applies, or claim main-game
Save→cold Continue serpent coverage. Current analysis expects schema sufficiency; if actual composition
cannot represent necessary state, stop and document the exact blocker before any schema change.
Death reuses DeathContext/DeathInventoryService/CorpseState with the source name/age/gender/62000 weight/
200000 capacity and empty loadout; no Beast death subsystem or invented loot.

### BF4 runtime / later Lake

Controlled QA-only single-serpent setup may use real factory/runtime/bindings/Encounter/scheduler/
Combat/lifecycle/corpse authorities. It must not become a production world entry. After preconditions,
use real selection/UI/input/cadence, not direct callbacks as player proof. Follow helper health,
non-stale advancing frames and runtime-error evidence rules. No such validation is claimed in BF1.

Lake remains future authored content. Before adding its five slots, revisit source aggression/init,
current pair-entry and WorldSimulationGate, obtain owner approval for multi-enemy inclusion, and define
old-save content-version/tombstone behavior. No policy is chosen here.

## Ambiguities and explicitly deferred content

- Wolf dog age4 authors kee/eff_kee200 while missing max_kee derives50. Executable LPC leaves the
  inconsistency; BF1 rejects an equivalent unrepresentable track, without raising max, clamping, or
  relaxing Character invariants. Wolf migration needs a separate owner compatibility decision.
- Butterfly str6 calculates weight−6000; formula is preserved, but butterfly content/chat/peaceful
  behavior and runtime implications are not migrated. Phase9A's zero-base-damage concern is partly
  superseded by the explicit CXR9 unarmed-zero decision; this does not constitute butterfly parity.
- Venomsnake has damage-dependent hit_ob → snake_poison20 plus pursuit. It remains deferred with
  Phase5B4; serpent requires neither.
- Missing/invalid verbs, generic fallback text, preauthored actions and mapped/weapon precedence are
  source contract evidence, not a generalized action interpreter. BF2 must not silently accept an
  unavailable authored provider.
- No new ES2 compatibility substitution is adopted; DECISIONS.md remains unchanged.

## BF1 verification and distinct self-audit

Godot `4.7.2.stable.official.ed1daf0bf`; focused command:
`godot --headless --path game --script res://tests/run_bf1_tests.gd`.

| Suite | Assertions | Result |
|---|---:|---|
| Beast derived formulas | 61 | PASS |
| Beast initialization + human missing-default regression | 142 | PASS |
| Serpent definition / creation / isolation / unchanged spawn counts | 76 | PASS |
| Closed Character state/formulas | 177 | PASS |
| Phase7B1/9B1 NPC spawn foundation | 396 | PASS |
| Phase9B2 NPC Armor loadout | 106 | PASS |
| **Total** | **958** | **PASS** |

Expected numeric tables and RNG sequences are literal independent source calculations, not calls back
into the implementation. Every formula branch has below/exact/above coverage; tests cover missing
versus explicit zero, all per-attribute draw skips, invalid lower/upper draws at all seven positions,
unsupported resource tracks in all three channels, exact serpent facts and independent authorities.

Headless editor import PASS; full canonical runner `--check-only` PASS (registered new BF1 suites,
**did not execute** the complete historical suite). Repository/static checks PASS; `git diff --check`
and changed-file trailing-whitespace checks PASS. Initial sandbox import had a certificate-store
environment error and an invalid relative log destination; isolated elevated validation with an
absolute log path passed. Neither required a project/tooling or gameplay change.

Distinct self-audit after the initial tests independently reviewed the production diff and source
order, constructor/getter alias boundaries, nullable failure paths, human defaults and unchanged
loadout code. It added missing-human-age regression coverage before the final focused run. It found
no remaining BF1 correctness blocker and made no Combat/restore/death changes. This is slice
self-verification, **not BF5 formal audit**.

All reference/es2, DECISIONS, production spawn/map/runtime/Combat/restore/death changes = 0.
Live gameplay validation is not applicable to this Node-free initialization/data slice; no real
serpent encounter, save or death proof is claimed. BF4 owns that later integration gate.
Owner main-worktree project/plugin edits remain outside this isolated worktree and are excluded.

Historical BF1 stop: BF2 was ready for owner authorization, not yet started at that checkpoint.

## BF2 implementation — combat facts and bidirectional projection

Starting HEAD: `a6ebe800943a5300cdfa192dc8bd19b45d111a0d`, same isolated phase worktree/branch.
No changes to the owner's main-worktree project/plugin edits. No rebalance or new compatibility
decision. This slice supplies inputs to the existing ordinary pipeline; it does not implement a
second Beast combat algorithm or an encounter/runtime placement.

### Source recheck and native mapping

Exact BF2 rechecked files, all below `reference/es2/mudlib/`:

- `adm/daemons/race/beast.c`, `d/oldpine/npc/serpent.c`: ordered anatomy/verbs, bite action,
  intrinsic attack60/damage20/armor90/dodge80 and authored character facts.
- `feature/attack.c`, `feature/skill.c`: mapped martial → primary weapon → default action precedence;
  effective skill = raw/2 + mapped raw + skill modifier; existing NPC progression thresholds.
- `feature/equip.c`, `feature/attribute.c`: additive equipment deltas and effective strength inputs.
- `adm/daemons/combatd.c`, `adm/daemons/weapond.c`: skill power, action/limb RNG order,
  dodge/parry/damage/wound, progression and guard/reverse sequencing; existing weapon action data.
- `feature/action.c`: positive damage requests interruption, but integer busy clears only when
  `busy < interrupt`; being hit alone does not guarantee clearing busy.
- `adm/daemons/race/human.c`, `std/weapon/sword.c`, `d/oldpine/obj/short_sword.c`,
  `d/oldpine/obj/long_sword.c`, `d/oldpine/obj/leather.c`, `std/armor/cloth.c`: human/weapon regressions,
  leather armor5 and inherited dodge `-6000 / 3000 = -2`.

| Legacy fact | Native consumer / composition |
|---|---|
| `limbs` | NPC-derived `CombatSliceContentProfile.limbs()` → defender snapshot; exactly 头部, 躯干, 尾巴 |
| `verbs = ({"bite"})` | `BeastCombatActionDefinitions.bite()` → existing one-entry `CombatActionSet` |
| `apply/attack = 60` | Attacker **usage bonus** = intrinsic60 + current Armor attack; not raw unarmed |
| `apply/damage = 20` | Projected apply damage = intrinsic20 + verified current weapon damage; separate from action percentage |
| `apply/armor = 90` | Defender armor = intrinsic90 + current Armor armor; wound gate only |
| `apply/dodge = 80` | Current effective dodge queried with intrinsic80 + current Armor dodge |
| Mutable skills/resources | Read from exact live CharacterState for each forward/reverse projection; no startup cache |

Production edits are limited to new typed bite data, `CombatSliceContentProfile`,
`CombatSliceProjectionBuilder`, and `WorldCombatBindingAdapter.from_npc()`.
The NPC adapter derives race/anatomy/intrinsics from the NPC definition instead of inheriting the
caller's human/bandit prototype facts; only the caller's already-verified weapon configuration is
retained. It preserves exact Character/Equipment/Armor/relationship/busy authority identities.
Forward snapshots and reverse modifier projections use the same additive contributions.
Existing CXR participant identity checks and scheduler still pass the same authorities into
`CombatSliceOpportunityExecutor`; no Encounter, target, queue, Flee or world-freeze changes.

### Narrow readiness boundary

`CombatSliceContentProfile.Readiness` explicitly distinguishes unsupported race, missing facts,
empty/invalid limbs, empty verbs, unsupported verbs/distributions, inconsistent action data, and
invalid weapon configuration. Generic `NpcDefinition.is_valid()` is unchanged: a valid initialized
noncombat NPC can be rejected by this combat consumer. The existing adapter retains its null-failure
contract; callers needing the reason can inspect the definition-derived profile's typed readiness.
Projection rejects an unready participant or mismatched Beast action facts before core execution.
No missing Beast anatomy/action is replaced with human limbs, punch, or default sword slash.

The current supported default distribution is exactly `[bite]`. Unknown/claw/hoof/poke and duplicate
or multiple verbs are explicitly not ready, not successful no-ops. Only bite is migrated; claw's
missing source damage is not filled in. Mapped actions or unverified primary weapons retain the
existing explicit unavailable-provider result, without falling back to bite. A real verified sword
does use the existing weapon provider ahead of bite, as `reset_action()` requires.

### Execution and independently derived expectations

Bite is ordinary action data: text `$N扑上来张嘴往$n的$l狠狠地一咬`, damage percentage20,
damage type 咬伤, zero force contribution, no special hook. No raw skill or tactical `combat.bite`
registration is created. `CombatActionSelector` remains unchanged and consumes `next_below(1)`
even with one action. This draw precedes the target limb draw in forward and reverse bodies.

Tests use a real BF1-created serpent with cps/per/con rolls `[0,0,0]`, plus a **test-only** controlled
human opponent. There is no production player buff, new authored armor, spawn or QA scene.
Literal source-derived checkpoints include:

- Full-spirit AP322000 and DP420500 through the existing math/resolver, with integer truncation
  after each division. Raw unarmed/dodge/parry initially remain absent.
- On bite hit with damage and strength rolls0: `(20+0)/2 = 10`, bite adds2, strength adds20 →
  current damage32. This proves intrinsic20 and action20% are distinct and each used once.
- Player test attack damage100 against armor90: current kee loses100 for wound rolls90 and91;
  effective kee loses0 at exact90 and10 at91. No flat subtraction of90 from current damage.
- Empty-hand parry uses **unarmed** skill power, not raw parry; source ordinary rules still allow
  serpent to parry. Armed/unarmed and busy handling remain in the existing resolver.
- NPC misses can level unarmed to2; next effective unarmed1 raises AP to325500 without caching.
  Successful dodge/parry progression updates live raw skills; intrinsic dodge stays separate.
- Forward dodge progression changes serpent experience to250001 and raw dodge to2; guarding
  reverse sees new experience, calculates AP322001, selects bite with a fresh random1 and resolves
  both dodge and hit branches. Both QUICK and RIPOSTE guard-roll branches are covered.
- Real wear/remove of leather produces armor95/dodge78 then restores armor90/dodge80. A typed
  test-only modifier fixture checks nonzero Armor attack/unarmed contributions through the actual
  wear service. Real long-sword wield/unwield composes damage45→20 and slash→bite. Both forward and
  reverse templates/modifier projections are checked; projection never writes raw skills.

Example complete forward hit RNG bounds (specific target, so no random opponent discovery):
`[60, 1, 16, 322500, 322500, 20, 40, 1000, 32, 1968]`.
Example live reverse-hit chain:
`[15, 1, 3, 1253500, 110, 20, 1, 16, 572001, 1155001, 20, 40, 500000, 32, 1968]`.
Tests compare every bound and relevant draw, not only final resources. Existing CXR9 unarmed
zero-apply `random(0)` substitution remains unchanged; no new RNG substitution is introduced.

### BF2 verification and distinct self-audit

Godot `4.7.2.stable.official.ed1daf0bf`; each command is
`godot --headless --path game --script res://tests/<runner>.gd`:

| Runner | Assertions | Result |
|---|---:|---|
| `run_bf2_tests` (profile58 + execution104 + projection39) | 201 | PASS |
| `run_bf1_tests` (includes Phase7/9 NPC + Armor loadout and Character regression) | 958 | PASS |
| `run_phase_5b2a_tests` | 664 | PASS |
| `run_phase_5b2b1_tests` | 912 | PASS |
| `run_phase_5b3b2b_tests` | 888 | PASS |
| `run_cxr4_tests` (scheduler, lifecycle, ordinary opportunity, resident Session) | 791 | PASS |
| **Executed assertions, including overlap between regression runners** | **4,414** | **PASS** |

Godot headless editor import and canonical runner `--check-only` PASS, no script errors.
New suites are registered in the canonical runner, but the complete historical suite was **not run**.
Repository/static checks, `git diff --check`, changed/new-file trailing whitespace checks PASS.

The distinct post-implementation review rechecked the production diff, both projection directions,
source action/skill/equipment ordering, CXR authority construction, malformed-data failures and
copy boundaries. It added actual NPC parry progression and initialized-but-unready NPC rejection
coverage. During test construction, incorrect test API calls and a runner name collision were fixed;
busy and reverse-parry expectations were corrected directly from `feature/action.c` and `combatd.c`
(not by changing production formulas to match tests). Final logs have no script errors or failures.
No remaining BF2 correctness blocker was found; this is not the later BF5 formal audit.

All Combat Core formulas/algorithms, tactical registry, Encounter/scheduler, production spawn ledger,
maps/Lake, restore/schema/death/corpse, `reference/es2` and `DECISIONS.md` remain unchanged in BF2.
Human 16 limbs/punch and long25/short15/leather5/dodge−2 remain unchanged. No fake equipment or raw
skills, generic apply Dictionary, dispatch VM, gameplay RNG source or Node/timing dependency added.
No real serpent gameplay proof is claimed: BF2's approved gate is Node-free controlled execution;
BF4 still owns the separately authorized live runtime gate.

Historical BF2 stop: **BF2 PASS; BF3 was ready for authorization, not started at that checkpoint.**
Wolf/butterfly/venomsnake, multiple/weighted Beast verbs, unknown-provider compatibility, Phase5B4,
source-generic fallback/preauthored actions and other Beast hooks remain deferred. No PR or merge.

## BF3 implementation — race-aware persistence and death body facts

Starting HEAD: `06c0c10bcd35697b333d4e6c219c9a5c37bf3062`, same isolated worktree and
`phase/beast-foundation-serpent-runtime` branch. BF1/BF2 are owner-approved. BF3 does not reopen
Combat or claim normal-player serpent Save/Continue. **Serpent persistence composition capability
verified** is the precise completed boundary; a production serpent slot still does not exist.

### Rechecked source and body policy

Rechecked below `reference/es2/mudlib/`: `adm/daemons/chard.c`, `adm/daemons/race/human.c`,
`adm/daemons/race/beast.c`, `d/oldpine/npc/serpent.c`, `obj/corpse.c`, `feature/damage.c`,
`feature/move.c`, `include/race.h`, and `include/race/beast.h`.

- Human setup uses `40000 + (str - 10) * 2000`; Beast setup uses
  `2000 + (str - 10) * 2000`. `chard.c` gives **both** races capacity `str * 5000`.
- Source setup supplies missing initial resources/body values. It is not a Load algorithm.
- `make_corpse()` copies the victim's stored `query_weight()` and `query_max_encumbrance()`,
  name, gender and age. `feature/move.c` stores body weight separately from contents encumbrance;
  changing raw strength alone does not assign either stored body field.
- `feature/damage.c`'s actual death lifecycle clears conditions and commits destruction/ghost
  behavior outside this slice. `CorpseState`/Death core already accept non-human metadata.
  No Beast-specific corpse/loot/decay algorithm is needed.

`game/core/npcs/npc_body_facts.gd` is the only new production class. `NpcBodyFacts.derive()` takes
a valid immutable NPC definition and raw strength, delegates to the already-closed derived formulas,
and returns only expected body weight/capacity. Null/invalid definitions and unsupported races fail
closed. It owns no anatomy, combat modifiers, resource maxima, RNG, presentation or save state.
`matches_saved()` compares both body scalars exactly. No clamping or formula duplication is added.

The existing fresh NPC factory now uses this same narrow seam for its two body outputs; attribute,
age, resource initialization and draw ordering are unchanged. This is not a new species registry.
For serpent str40, the result remains **62000 / 200000**, age400 and gender雄性.

### Production restore and Save capture

`OldPineWorldRestoreComposition._restore_npc_ledger()` replaces its unconditional human-weight
calculation with `NpcBodyFacts.derive(definition, saved strength)` and exact saved-body comparison.
Definition/spawn identity, authored age, location, item/loadout validation and the existing error path
`.derived_character_facts` remain in place. Unknown races do not fall back to human.

The rest of reconstruction is unchanged: existing `CharacterStateSnapshotRestorer` rebuilds saved
mutable state, with the exact Equipment returned by Phase4 item restore and the exact restored Armor
passed into `NpcRuntimeState`. No fresh NPC factory call, Beast defaults, maxima recomputation or
RNG draws occur on this restore path. The NPC definition is resolved from the existing catalog.

Actual `OldPineWorldSaveCapture.capture()` calls this same `prepare()` validation after capture, so
normal human Save receives the correction automatically; no second Save-side race switch is added.
The existing corpse restorer already takes NPC body weight from the validated saved NPC record;
its remaining human calculation applies to Player, and capacity is race-neutral. It needs no change.

### Lowest-boundary capability proof and limits

`tests/support/beast_persistence_fixture.gd` is **test-only composition** of the real production
Character capture method, `NpcSpawnStateSnapshot`, `GameSaveSnapshot` v1, JSON codec/validator,
Phase4 native item capture/restore, the production body validation helper, Character restorer,
`NpcRuntimeState` constructor and RNG state adapter. It intentionally does not call full production
Session restoration for a serpent. No new production restoration API, fake world slot, or QA scene
was introduced merely to make that test possible.

Proof covers living, unconscious and dead/not-existing records, fresh graph B object identities,
exact semantic IDs, age/gender, cps/per/con plus other initialized attributes, all resource tracks,
combat experience250007, raw unarmed1/learned3, typed duration/poison condition payloads, existence,
location and position. Death-status DTO tests prove representation, not execution of `die()`;
preserved condition payloads there are not a claim that the death lifecycle retains conditions.

Serpent's authored maxima900/1800/500 remain saved maxima, not age400 default formulas. After damage
and wound, living kee restores as1677/1783/1800; gin888/900/900 and sen479/500/500 also restore exactly.
No serialized race/name/limbs/verbs/intrinsic dictionary or combat profile is introduced. Definition
lookup reobtains limbs `[头部, 躯干, 尾巴]`, bite and intrinsic60/20/90/80.

The empty real item snapshot reconstructs fresh Inventory/Combined/index and exact injectable
Equipment/Armor authorities with **zero item records**. There is no second Inventory save model.
RNG proof uses the real PCG32 adapter with a test-only counting subclass: fresh A consumes3
cps/per/con draws; restore consumes0 and preserves exact saved seed/state; a subsequent legitimate
fresh NPC factory call consumes3 draws and matches the uninterrupted original stream.

A separate normal production Session capture/prepare test preserves all5 human NPCs and12 bootstrap
items, rejects wrong weight/capacity for every human slot at the original failure path, and still
rejects an added unapproved serpent slot. Existing tests separately cover human Equipment/Armor,
item identities, location, tombstones, corpse graph and RNG continuation. No schema version change,
old-save upgrade, missing-slot insertion or Lake five-serpent policy is attempted.

### Death adapter and regression correction

`OldPineOutdoorController._death_context_for()` now uses `npc.body_weight` and
`npc.maximum_encumbrance` for NPC victims; it keeps the existing Player path unchanged.
Death does not run the initialization/validation formula again. This deliberately preserves already
established runtime body values even if raw strength has subsequently changed. The existing restore
consistency policy still compares saved body values to saved strength; no general dynamic body-update
system or new policy for such divergence is introduced here.

The actual detached controller adapter is tested after a lowest-boundary restore into graph B.
Its DeathContext preserves 黑冠巨蟒/雄性/400/62000/200000 and exact Equipment/Armor references.
Unchanged `DeathInventoryService` produces one fresh corpse, own weight62000, capacity200000,
no worn items and no loot. No silver, skin, fang, medicine, quest item or NPC effect is synthesized.
Changing strength to99 after initialization does not silently rewrite stored body facts at death.
Player str20 still produces Player/男性/age20/60000/100000 through the unchanged Player adapter.

The Phase8 regression initially exposed four old assertions that expected a raw strength edit to30
to force NPC death-time body recalculation; independent review found two matching Tall assertions.
Those six expectations in `oldpine_outdoor_smoke_test.gd` and
`oldpine_pine_maze_tall_bandit_test.gd` now assert source copying of pre-edit stored body facts.
The strength edits and lifecycle/loot tests remain, not removed or weakened into no-op tests.
This is the **explicit BF3 owner-requested correction**, not a new compatibility substitution.
Historical Phase7B2 wording about death-time strength recalculation describes the old implementation
and is superseded by this BF3 evidence; historical phase documents and DECISIONS are not rewritten.

### BF3 validation and distinct self-audit

Godot `4.7.2.stable.official.ed1daf0bf`; commands use
`godot --headless --path game --script res://tests/<runner>.gd`:

| Runner | Assertions | Result |
|---|---:|---|
| `run_bf3_tests` (body/persistence110 + death17 + human Save35) | 162 | PASS |
| `run_bf2_tests` | 201 | PASS |
| `run_bf1_tests` | 958 | PASS |
| `run_phase_10b3_tests` (includes Phase4 item/death, Phase6 lifecycle, Phase7/9 NPC) | 4230 | PASS |
| `run_phase_10b4_tests` (normal capture/transaction + restore) | 1091 | PASS |
| `run_phase_8b1_tests` (corpse/loot and related lifecycle/NPC) | 2218 | PASS |
| `run_phase_9b1_tests` (Tall integration and related regressions) | 4184 | PASS |
| **Executed assertions, including overlap between regression runners** | **13044** | **PASS** |

Headless editor import and canonical runner `--check-only` PASS. New suites are registered in the
canonical runner; the full historical suite was **not executed**. Repository/static checks,
`git diff --check` and changed/new-file trailing whitespace checks PASS.

Distinct self-audit reviewed production diffs, source stored-vs-derived body semantics, Save's shared
validation, corpse restore's already-validated NPC weight, factory draw order, identity injection,
no-reroll paths and protected scope. It added restored-graph death, production extra-slot rejection
and explicit mutable-authority isolation checks. One initial test used wrong owner-property names;
only that test was corrected, and the stalled headless test process was stopped. Final validation
logs have no script errors or remaining failures. No remaining BF3 blocker was found.

Combat/bite/projection/scheduler unchanged; Lake, production spawn ledger, save schema/codec,
Character restorer, Death core/Corpse core, Phase5B4, `reference/es2` and DECISIONS unchanged.
Owner main-worktree project/plugin edits remain untouched. BF3 has no live gameplay acceptance
requirement: detached-adapter and headless Session regression evidence is not real-player or live
serpent runtime evidence. BF4 remains the separately authorized integration gate.

**BF3 PASS — PENDING OWNER REVIEW. BF4 READY FOR AUTHORIZATION, NOT STARTED.**
No PR, merge, production serpent, normal-player serpent Save/Continue claim or milestone closure.

## BF4 controlled runtime integration — PASS / owner review pending

Starting HEAD: `472b1d368ab09dcf36a49d95abca1aaa85643691`; same isolated worktree/branch.
Continued the preserved uncommitted BF4 work, without restarting Run A or discarding valid work.
The earlier blocker and failed Run B are retained below as history, followed by the authorized
resolution and final evidence. This is not formal audit, milestone integration or BF5 authorization.

### Runtime seam and QA isolation

The only production edit is in `OldPineOutdoorController`: a narrow registration/removal seam for
an already-created NPC, its map-owned `WorldCharacterBody2D`, presence Area and content profile.
It reuses existing map membership, physical lookup, selection, aggression, binding and world-gate
consumers. It neither creates a spawn nor initializes a character nor establishes a relationship.
Duplicates, player bodies, missing standard collision nodes, wrong-map/invalid inputs and removal
while the world is frozen or the NPC is fighting are rejected. Presence signals are disconnected on
removal. The existing five authored bodies retain their current initialization and signal wiring.

`tests/runtime/bf4_serpent_publication.gd` is explicit QA-only precondition/observation code. It
loads no substitute game scene. After canonical ApplicationShell -> real New Game, it calls the
real `NpcCharacterStateFactory` with the Session's Inventory/Combined/NPC RNG and the real serpent
definition. It publishes one simple rectangle/label at `(700,300)` in the existing clearing.
This is **not authored geography** and does not alter the production spawn ledger. It retains a
reference to the actual scheduler for read-only event inspection, not a second combat loop.
Removal/republication is covered in automated tests. Session teardown removes the whole QA setup.

No production path references the harness. The existing sanitizer excludes `tests/`. QA logs state
that this Session must not be saved; capture is tested to reject the unapproved extra spawn rather
than persist it. No Save eligibility/repository/schema change or persistent QA content is introduced.

### Actual desktop evidence — Run A

Used the canonical main scene of an ignored validation copy with identical gameplay sources.
The branch's Godot AI4.0.1 cannot share the owner's running4.0.2 server. For development tooling only,
the copy uses the owner's existing4.0.2 addon; neither tracked addon nor owner files were modified.
Game user storage is isolated through APPDATA; LOCALAPPDATA remains normal so the editor can
authenticate to the already-running service. Copy-only debug port6117 avoids the owner's6107.
Connected editor: `bf4-live-project@bf9b90bc197cac5e`, Godot4.7.2 official, run `r84926-1`.

Startup returned `helper_live=true`, `session_active=true`, `current_run_errors=[]`; editor state
confirmed `game_capture_ready=true`. Main Menu framebuffer frame638 was non-stale. A real click on
New Game entered the canonical Host/Session. No player position or combat state was assigned.

QA publication preserved source-fresh age400, weight62000, capacity200000, kee1800/1800/1800,
experience250000, three limbs, bite and intrinsic60/20/90/80. Frame4038 showed the physical placeholder.
Real `move_right` press/release over54 frames moved Player from `(450,300)` to approximately
`(607.667,300)` and entered the actual presence Area. Existing aggression resolved READY (12),
then the real CXR Encounter pair was `[qa.bf4.serpent, oldpine.player]`.

Frame4772 showed active LETHAL Battle, the correct Chinese serpent identity and damaged Player.
The actual scheduler recorded **five** serpent `es2:adm/daemons/race/beast/bite` forward actions,
each with selection RNG bounds `[1]`; intervening Player actions were the existing sword slash.
Real Session `GodotCombatRandomSource` was not replaced or seeded by QA. Source-fresh serpent stayed
at full vitality; Player naturally died. Final result DEFEAT(1), Player DEAD(2), one Player corpse,
active Encounter false, active scheduler null, Battle hidden, world gate open and old cadence false.
Frame8311 showed the actual Defeat/world state. These frames all had `stale_frame=false` and advanced.
This proves runtime correctness, **not difficulty/balance acceptance**.

### Run B — original wounded-only attempt (historical failure)

Returned through actual Escape / Return to Main Menu / confirmation / New Game input. In a fresh
Session the only serpent state override was vitality **1/1/1800** before approach. Attributes,
experience, race/body/anatomy/intrinsics and RNG behavior were untouched. The same real54-frame
movement triggered aggression/Encounter. Player again died; the serpent stayed1/1/1800. Frame24557
was non-stale, showing defeat. This is **not** serpent death/corpse proof or natural balance evidence.

Further source-based diagnosis shows retries cannot satisfy the requested ordinary death gate with
this fresh Player and only current/effective serpent vitality changes:

- Existing Player has strength20, long-sword apply damage25, no force factor/hit augmentation;
  the ordinary slash has no action damage percentage.
- `combatd.c` damage maximum is `(25+24)/2 + (20+19)/2 = 24+19 = 43` with integer division.
  Its combat-experience defense loop can only reduce this value.
- A wound requires `random(damage) > armor`; serpent armor90 remains source-locked. A roll at most42
  cannot exceed90. Lowering current/effective kee to1 or0 does not change this wound gate.
- Damage may lower current kee and cause unconsciousness, but cannot lower effective kee below0.
  Existing lethal Encounter resolution does not silently convert unconsciousness into death.

Rechecked `d/oldpine/npc/serpent.c`, `adm/daemons/race/beast.c`, `include/race/beast.h`,
`std/char/npc.c`, `feature/attack.c::init`, `adm/daemons/combatd.c::auto_fight/start_aggressive`
and damage/wound arithmetic, plus `feature/damage.c`; native factory/projection/resolver/lifecycle
paths agree. This is an **acceptance-precondition limitation, not evidence of a BF2 formula bug**.
At that checkpoint no Combat fix, player buff, serpent armor nerf, forced RNG or direct death call
was made. Owner subsequently authorized the expanded QA-only precondition below; DECISIONS remains
unchanged because this does not substitute a production gameplay rule.

### Initial blocked validation (historical, superseded below)

BF4 initial focused run: **82 assertions, 81 passing, 1 failing** — the explicitly required wounded
serpent death expectation. It is retained, not relabeled as success. Earlier QA mistakes (unnamed
collision shape, wrong authority property) were corrected; final focused log contains no script
errors. Both cases now have a completion guard so an aborted test cannot silently print PASS.
At that checkpoint the unfinished suite was not yet added to the complete canonical runner.

Existing regressions all PASS: BF1 958; BF2 201; BF3 162; CXR8 169; CXR9 368; Phase7B3 2299;
Phase9B3B3 2467; Phase8B1 2218; Phase10C1B 1039. Total **9881 executed assertions**, including overlap.
Headless editor import and repository/static checks PASS. Full historical canonical suite not run.
Sanitizer preparation PASS; its output has no `tests/` directory. `git diff --check` and
changed/new-file trailing whitespace checks PASS. The first worktree editor normalized project
settings; those task-generated changes were explicitly reverted, not mixed into the BF4 diff.

After the completed live paths, a QA-only reflective inspection expression failed to compile and
the helper stopped advancing. That attempted inspection is excluded from evidence; the game was
stopped. It did not occur on the recorded successful Run A path. No stale framebuffer was accepted.
At that checkpoint registration cleanup hardening had only headless evidence; the resumed live copy
included that exact current production file and passed below.

Self-audit found no serpent-ID gameplay exception, second scheduler, fake authority, production spawn,
Lake, schema, balance, artwork or Phase5B4 changes. Owner main-worktree edits and source remain
untouched. At that checkpoint serpent corpse/Open Loot/control return remained pending; those gates
are satisfied only by the separate authorized live Run B below, not by Run A or BF3.

### Blocker resolution — DETERMINISTIC QA-WOUNDED LIFECYCLE PROOF

Owner explicitly permits two extra Run B preconditions, only under `res://tests/`:

| Player fact | Before | After |
|---|---:|---:|
| Base strength | 20 | 20 |
| Force factor | 0 | 0 |
| strength_modifier | 0 | 180 |
| CombatMath effective strength | 20 | 200 |
| combat_experience | 600 | 250000 |
| Existing long-sword projected apply damage | 25 | 25 |

The QA helper computes modifier as `200 - base_strength - force_factor` and verifies through the
existing CombatMath projection. No Player production creation, equipment, skill or resource change.
Serpent only has current/effective vitality1/1 with maximum1800; definition/race/age/attributes,
gin/sen/maxima, combat experience250000, anatomy/bite, intrinsics60/20/90/80, weight62000 and capacity
200000 remain source-defined. The QA state must never be saved.

`WoundedProofRandom extends CombatRandomSource` is configured through the existing Session seam
before input. Its immutable ordinal script was fixed BEFORE executing combat, not selected after
failure. `MAX` denotes `bound-1`: `[0,0,0,0,0,0,0,0,MAX,MAX,0,0,0,91,0,MAX]`.
Unexpected exhaustion/invalid bounds fail closed, and setup cannot reset an already configured script.
It supplies legal numbers, not results, and preserves every actual production RNG call.

| Ordinals | Production stage | Draw policy |
|---|---|---|
| 1–5 | Serpent courage, bite selection, Player limb, dodge, defender progression | 0 each |
| 6–8 | Player courage, slash selection, serpent limb | 0 each |
| 9–10 | Dodge and parry checks | MAX each |
| 11–13 | Weapon damage, strength, defense loop | 0 each |
| 14 | Wound | 91 |
| 15–16 | Attacker and defender hit progression | 0, MAX |

Actual live bounds: `[60,1,16,572000,120,42,1,3,670500,250001,25,200,250000,112,120,1799]`.
Actual draws: `[0,0,0,0,0,0,0,0,670499,250000,0,0,0,91,0,1798]`.
The seeded headless factory produces courage bound30 at ordinal6 instead of live42 (source-random
serpent composure); the same predeclared zero remains legal. NPC/world RNG were not replaced.

**NO RETRY / NO SEED FISHING:** the first complete authorized deterministic combat execution passed;
the same script was used for focused regressions and exactly one authorized live Run B. An earlier
headless setup attempt used the wrong Player authority property (`character_state` instead of `state`)
and stopped before any scripted draw; only that QA API typo was fixed, not the sequence or production.
The previous wounded-only attempt predates this authorization and remains failed historical evidence.

### Resumed live Run B — exact lethal and world evidence

Compatible ignored copy, same tooling isolation as Run A. Current production registration cleanup
was synchronized before launch. Editor `bf4-live-project@3fc313a554da3ce0`, run `r22431-1`.
Canonical ApplicationShell, real New Game click `(576,300)`. Health: helper_live/session_active/
game_capture_ready true; current_run_errors empty. Final game log has no errors, full40 editor rows
contain existing warnings only (no errors). Non-stale frame1050 shows Main Menu.

After the explicit preconditions, real move_right press/release over54 frames moved Player from
`(450,300)` to `(611.3337,300)`, physically triggering presence/aggression/Encounter. No teleport,
combat-start, direct wound/death/lifecycle/loot callback was used. The retained actual Scheduler
contains serpent ordinary bite (selection bound1), legitimately dodged, then Player ordinary slash:

- action `es2:adm/daemons/weapond/slash`; unchanged weapon `es2:d/oldpine/obj/long_sword`;
- apply damage25, actual effective strength200;
- requested damage `(25+0)/2 + (200+0)/2 = 112`; defense loop exits normally;
- armor90, wound bound112 / draw91, `91 > 90`, wound `112-90=22`;
- effective vitality `1-22` saturates to **-1** by existing resource semantics;
- resolver threshold DEATH(3), actual lifecycle requested DEATH(2), DEATH_COMPLETE(3),
  partial stage COMPLETE(5), DeathInventory SUCCESS(0), real CorpseState/world publication.

The existing lifecycle builds DeathContext from the same NPC authority, invokes DeathInventoryService
and publishes the returned corpse; the observed receipt carries corpse ID
`oldpine-session-61d3d1b3e449d8be33f75cda9fbe7d38.dynamic.0`. No alternative Death chain exists in QA.
Observed corpse: 黑冠巨蟒 / 雄性 / age400 / own weight62000 / contents capacity200000 / zero children.
No silver/fang/skin/medicine/quest item was invented. Serpent is DEAD and exists_in_map=false.

Non-stale frame7408 shows world Victory, Player220/220/220, corpse, and real log of the bite dodge
and112-damage slash. Pointer click on corpse `(665,324)`, then actual Open Loot `(373,180)` displays
**Corpse of 黑冠巨蟒 / Empty**, frame12646. Actual Close `(956,276)`, then fresh20-frame move_down
changes position to `(611.3337,358.6665)`. Frame17533 shows moved Player/camera and retained corpse.
All frames advance with stale_frame=false. Battle closed, active Encounter false, scheduler null,
world gate open, old cadence false, Player ACTIVE: this proves live control return, not Player death.
Validation game/editor gracefully stopped after evidence; owner's editor/session left untouched.

**BALANCE CLAIM: NONE.** This is neither natural victory, source-fresh Player capability nor normal
New Game difficulty evidence. Run A alone retains the natural source-fresh combat evidence.

### Final focused verification / distinct self-audit

BF4 **101 assertions PASS**, including the original retained death expectation, exact fixed draws,
lethal112/22/-1 facts, corpse identity/body/empty contents, same authorities, registration/removal,
world/Encounter gates, five-human/twelve-item bootstrap and extra QA-slot Save rejection.
Re-ran all nine earlier regressions: BF1 958; BF2 201; BF3 162; CXR8 169; CXR9 368; Phase7B3 2299;
Phase9B3B3 2467; Phase8B1 2218; Phase10C1B 1039 — **9881 PASS**, including overlap.
Total focused executions **9982 assertions PASS**. Canonical runner now includes BF4; only its parse
check is run, not the complete historical suite. Godot4.7.2 headless editor validation PASS.

Distinct self-audit rechecked source-locked facts, typed-state identities, body registration cleanup,
source-ordered fixed RNG and exact lethal threshold, real lifecycle receipt, player-input evidence,
no fake authority/scheduler/results, and production-vs-QA separation. No additional production change
was needed to resolve Run B. Existing authoritative factory/combat/lifecycle/corpse/loot is reused.
Repository checks, sanitizer, whitespace/diff checks PASS; sanitized output excludes QA/tests.
`reference/es2`, DECISIONS, Core, authored data/scenes, production RNG/formulas/defaults, Save schema,
tracked plugin/project settings unchanged. Parent-worktree user edits preserved.

**BF4 PASS — PENDING OWNER REVIEW. STOP.** No BF5, formal audit, full canonical, PR or merge.
