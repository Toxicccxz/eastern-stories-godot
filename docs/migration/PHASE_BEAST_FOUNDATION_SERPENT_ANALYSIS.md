# Source-valid Beast Foundation + First Serpent Runtime Integration

## Status and locked scope

BF1 — Source Contract + Typed Beast Initialization: **implementation and focused self-audit PASS**.
Base: `5cf3f4efb80816cb40389d093b7187e4cabdff5b`; branch:
`phase/beast-foundation-serpent-runtime`. Base main push workflow
[34302052253](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34302052253)
completed successfully. This is not major-phase closure. No PR or merge; BF2 has not started.

This document consolidates the owner-accepted Source-valid Beast / Serpent dependency analysis
and Post-Phase10D migration coverage review from the task conversation, with the owner's explicit
Lake/persistence scope correction. Related repository evidence:
[Phase 9A §11](PHASE_9A_OLDPINE_CONTENT_EXPANSION_ANALYSIS.md),
[Phase 5A](PHASE_5A_COMBAT_DEPENDENCY_ANALYSIS.md), [decisions](DECISIONS.md).
This is source-semantic migration plus necessary native composition, not a new creature design.

| Slice | Boundary / acceptance | Status |
|---|---|---|
| BF1 | Exact formulas, fresh defaults/RNG, typed authored facts, serpent definition | PASS; stop for owner review |
| BF2 | Bidirectional live Combat projection, limbs/bite/intrinsic modifiers, riposte | Not started |
| BF3 | Race-aware restore/body validation and death facts at the lowest real composition boundary | Not started |
| BF4 | QA-only single-serpent integration using production authorities and real player input | Not started |
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

BF1 stops here. **BF2 READY FOR OWNER AUTHORIZATION; NOT STARTED.**
