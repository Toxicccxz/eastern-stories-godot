# S5A — Player Recovery / Metabolism / Heartbeat Source Contract

## EXECUTIVE RESULT

**S5A OWNER APPROVED / CLOSED.** This document records the pre-S5B analysis, not current runtime.
Owner subsequently approved A–M in [DECISIONS](DECISIONS.md); the resulting
[S5B implementation/evidence](PHASE_SNOW_TOWN_CORE_HUB_PLAYER_RECOVERY_CADENCE.md) supersedes
historical pending-authorization/no-cadence statements below. S5A itself changed no gameplay.

ES2 naturally consumes food/water and repairs resources only when character execution reaches its
shared condition/recovery opportunity. This is **6–15 eligible heartbeat invocations**, not 5–14:
`tick = 5 + random(10)` followed on successive invocations by `if (tick--) return`.
Busy freezes that countdown; fighting alone does not. Conditions execute first; a no-heal flag
skips the entire heal, including metabolism. None of the seven source condition daemons returns it.

**SOURCE TIMING GAP — WALL-CLOCK PERIOD NOT PROVEN FROM REPOSITORY.** The bundled efun manual
says administrator-defined, usually two seconds; neither that example nor the checked ES2 config
proves this game's actual driver period. Do not label 12–30 seconds an established ES2 contract.

Current Native has the pure recovery calculation and two condition handlers, but **neither has a
production caller/cadence**. Recommend one Session-owned Player opportunity authority, not per-map
timers. Its combat, life-status, RNG, restart and time policies require owner review first. In
particular, the current world gate is closed during active combat: blindly requiring `is_open()`
would contradict source fighting recovery. Reusing existing Combat cadence as though it were the
ES2 heartbeat would also be an unapproved timing substitution.

## EXACT BASELINE

- Repository: `Toxicccxz/eastern-stories-godot`.
- Branch: `phase/snow-town-core-hub`; local/remote starting HEAD
  `52ece42255c6094cd2378013245eb2f86e35d5ef`, `Add Snow waiter dumpling supply loop`.
- `origin/main` and remote main: `047f29083e881156abbdad6ed480bffc1350dfa8`;
  merge-base equals main. Initial working tree clean; no open Snow branch PR.
- S1/S2/S3A/S3B/S3C/S4A/S4B: **OWNER APPROVED / CLOSED** under current owner instruction.
  Snow is unmerged; final PR unauthorized. Remote refs/PR state independently read, not inferred.

## AUTHORITY / SCOPE

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment,
interaction translation and presentation. Type A preserves source semantics; Type B is an
accounted Native translation; Type C is new design. This is not freeform RPG redesign.

Native authority: exact HEAD code → [DECISIONS](DECISIONS.md) → STATUS → ROADMAP → latest phase
document → older documents. `reference/es2/` remains gameplay/content authority. S4B receives
only a current approval annotation; its evidence and locked A–J/H1/K are not rewritten.
All future choices here are **OWNER DECISION REQUIRED**, not provisional entries in DECISIONS.

## SOURCE COVERAGE

LPC paths below are relative to `reference/es2/mudlib/`. No LPC driver execution or external port.

| Scope actually inspected | Sources |
| --- | --- |
| Complete primary files | `std/char.c`, `feature/damage.c`, `feature/condition.c`, `include/condition.h` |
| Complete condition set | `daemon/condition/bandaged.c`, `drunk.c`, `iceshock.c`, `poison.c`, `rose_poison.c`, `slumber_drug.c`, `snake_poison.c` |
| User lifecycle / persistence | `obj/user.c`, `feature/save.c`, `cmds/usr/quit.c`, `include/user.h`; `adm/daemons/logind.c` restore/reconnect/init_new_player/enter_world |
| Character dependencies | `feature/action.c`; `feature/command.c::enable_player/disable_player`; `feature/attack.c::fight_ob/attack`; `std/char/npc.c` chat; `adm/daemons/chard.c::setup_char`; `adm/daemons/race/human.c`; `feature/skill.c::query_skill` |
| Combat/busy examples | `adm/daemons/combatd.c` busy branches; `d/force/recover.c`; `daemon/class/swordsman/fonxansword/counterattack.c`; `feature/food.c` |
| Driver/document evidence | complete `adm/etc/config.ES2`, `doc/efuns/set_heart_beat`, `random`, `save_object`, `restore_object`; `doc/LPC/types/general` static semantics; `doc/driver/done-mudos` interval note; `doc/mudlib/std/char` |
| Broad searches | All mudlib `.c` set_heart_beat sites; entire mudlib CND_NO_HEAL_UP; all condition returns; reference config/header/code/docs timing/static/save searches |

Native inspected: `game/core/characters/{character_recovery,character_resource_state,
character_recovery_state,character_internal_resource_state,recovery_skill_levels,
new_player_initialization_policy}.gd`; condition state/system/flags/result/IDs and both effects;
`core/skills/character_skill_state.gd`; `core/combat/busy/action_busy_state.gd`;
`runtime/world/{oldpine_world_session_controller,world_resident_map_coordinator}.gd`;
`runtime/combat_encounter/{world_simulation_gate,combat_encounter_coordinator,
combat_encounter_scheduler,combat_encounter_resolution}.gd`; combat slice lifecycle adapter;
`runtime/persistence/{oldpine_game_runtime_host,oldpine_session_load_coordinator,
oldpine_save_eligibility,oldpine_world_save_capture}.gd`; root codec/snapshot/value types,
validator and character restorer. Broad game `.gd` searches covered recovery/condition callers.

Current-context documents inspected include Snow Work/Bank/S4A/S4B, Phase2A/2B, NGE final audit,
DECISIONS, STATUS, ROADMAP, Native Save and Application Shell contracts. Older phase deferrals
are historical, not evidence that already implemented skills/Save/Bank are still missing.

## CHARACTER HEARTBEAT ENTRY

Table 1: source `std/char.c::heart_beat`. “Later” means execution can reach the later stage;
the top-level function does not run all stages on every invocation.

| Stage / source function | Blocking condition | Tick decrement? | Condition update? | Heal? | Player-visible consequence |
| --- | --- | --- | --- | --- | --- |
| Effective threshold / heart_beat | any eff gin/kee/sen <0: remove enemies, die, return | no | no | no | mortal wound wins first |
| Current threshold / heart_beat | any current <0: remove enemies; living→unconcious, otherwise die; return | no | no | no | zero is not negative |
| Busy / continue_action | busy was nonzero at branch entry; return even if action clears it | no | no | no | recovery countdown itself is delayed |
| Nonbusy flee + attack | qualifying wimpy may flee; attack cleans/selects/fights | later | later | later | attack precedes recovery; no new busy check after attack |
| NPC chat | only !userp; destructed self returns | later if survives | later | later | Player does not chat here |
| Post-decrement countdown | old tick nonzero returns | yes | no | no | old1 becomes0 but still returns |
| Old tick0 / reset | set tick=5+random(10) before condition | yes, briefly -1 then reset | yes | conditional | random draw occurs even if heal later suppressed |
| update_condition | uncaught callback error can abort subsequent execution | already done | yes | unless flag2/error | mutations/removal happen first |
| Short-circuit / heal_up | bit2 suppresses heal | already done | already done | otherwise yes | no-heal also suppresses food/water decrement |
| Peace shutdown | no-heal or heal returns0, not fighting, not interactive, no nearby interactive | already done | already done | evaluated first | may disable heartbeat, not ordinary connected Player |
| User tail | !interactive returns; otherwise update_age + idle check | already done | already done | already done/skipped | runs even when no-heal skipped heal |

Exceptions from callbacks are not clean “skipped ticks”: reset and prior mutations may already
have happened. No exception rollback or scheduler retry contract is implied.

## HEARTBEAT START / STOP

**SOURCE FACT — Player:** new-body login restores saved fields, then `logind::enter_world`
execs the connection and calls user.setup. `obj/user.c::setup` updates age, then char.setup:
set heartbeat1 → assign random tick → enable_player → chard setup, then restore_autoload.
Re-entering setup rerolls tick; receive_damage/receive_wound (even zero damage), start_busy(nonzero)
and fight_ob(valid other object) enable heartbeat **without resetting tick**.

`obj/user.c::net_dead` explicitly disables heartbeat, destroys the login link, removes enemies,
marks netdead and schedules user_dump900. The still-existing body's reconnect enables heartbeat
and cancels dump, with **no setup and no tick reset**. Full new-body login instead rerolls.
Later external damage/busy/fight can re-enable a netdead body's heartbeat; do not promise that
every disconnected extant object is inert forever. apply_condition itself does not enable it.

The peace-shutdown branch requires `!interactive`; connected Players never satisfy it, even
fully healed or with no-heal. A disconnected user is still userp and keeps Player food/water
gates, though it can satisfy noninteractive shutdown. Nearby means direct occupants of the same
environment via first_inventory/next_inventory, not a global online Player test.

**SOURCE FACT — NPC:** same base setup/countdown/damage starts; chat runs, food/water gates do
not apply. Nonfighting NPC can stop if heal returns0 or flag2 and no same-environment interactive.
Remaining CONTINUE alone does not guarantee heartbeat remains on. The only additional `.c`
set_heart_beat site found is `d/wiz/npc/judge.c`, an NPC-specific restart, not Player policy.
No Player-wide disable switch should be inferred from NPC shutdown.

## RANDOM TICK CONTRACT

Bundled `doc/efuns/random` explicitly gives inclusive `[0,n-1]`: random10 is0–9, stored tick5–14.
Only heartbeats reaching the post-decrement are counted below (not busy/death-return calls).

| Initial/reset tick | Calls returning on old nonzero tick | Call reaching condition/heal | Total eligible calls |
| --- | --- | --- | --- |
| 5 | #1 old5→4, #2 4→3, #3 3→2, #4 2→1, #5 1→0 | #6 old0→-1, then reset | 6 |
| 6 | #1 old6→5 through #6 old1→0 | #7 old0, then reset | 7 |
| 14 | #1 old14→13 through #14 old1→0 | #15 old0, then reset | 15 |

Each completed opportunity resets before condition callbacks. Inter-opportunity separation is
6–15 eligible calls; same bound from setup to first opportunity. A uniform draw would imply an
average10.5 eligible calls, **not** a proven wall-clock duration or fixed average replacement.
Driver-enable phase relative to its global next heartbeat adds a separate first-call timing issue.

## WALL-CLOCK HEARTBEAT EVIDENCE

`adm/etc/config.ES2` identifies MudOS0.9.20 and configures cleanup180, swap120, reset1800;
none is the heartbeat period. `include/runtime_config.h` has no proven interval setting.
Searches across source/config/header/docs found the bundled set_heart_beat manual's
administrator-configurable “usually2 seconds”, and done-mudos noting configurable microseconds
on ualarm systems. Neither records the actual ES2 driver build/runtime selection. Historical
`doc/mudlib/std/char` also loosely claims idle users' heartbeats stop; executable !interactive
overrides that prose. No external driver default is promoted to source authority.

**SOURCE TIMING GAP — WALL-CLOCK PERIOD NOT PROVEN FROM REPOSITORY.** With an owner-selected
Native base period H, the model has6H–15H eligible time between opportunities absent blocking.
An optional2-second **Type B candidate** is grounded only in the bundled manual's example;
it is not approved and is not a claim that original ES2 ran2 seconds. Owner may require actual
driver evidence instead. Choosing1 second from convention has no better repository proof.

## BUSY ORDERING

`feature/action.c` supports integer/function busy; positive integers decrement once, negative
integers clear, functions continue until false. Caller returns unconditionally after the action.
Thus busy1→0 still skips countdown, conditions, heal, age and idle **for that call**. Repeated busy
adds delay before the next opportunity, not merely a discarded heal. No catch-up is in this branch.
If attack/chat sets busy after the earlier check, this heartbeat still reaches tick; next call
sees busy. A Native check only after advancing busy would mis-handle busy1 and same-call mutations.

Native ActionBusyState covers integer facts, not LPC function actions. CombatSliceOpportunityExecutor
already owns combat busy advancement. A future recovery adapter must receive pre-opportunity busy
evidence or share a narrow ordered event, not advance busy a second time. Outside-combat busy lifetime
is a separate unresolved application boundary; do not invent a general scheduler to clear it.

## COMBAT ORDERING

The fighting early return in damage.c is commented out. Executable heartbeat does attack before
condition/recovery and does not retest fighting or busy to veto heal. Therefore an uninterrupted
nonbusy fighting heartbeat **can recover**. `combatd.c` checks defender busy for defenses and
interrupts it; ordinary fighting does not itself always set busy. Concrete indirect blockers:
`feature/food.c` fighting eat sets busy2, `d/force/recover.c` sets busy1 during fighting,
fonxansword counterattack sets actor busy1 and may set target busy(skill/20+2).
These active/special actions are examples, not S5B implementation scope.

Native CXR has an already-approved different combat opportunity/time model and commits lifecycle
around attack chains. Recovery must not reinterpret its interval as a proven ES2 heartbeat or
run all overdue combat first and all overdue recovery afterward without an ordering decision.
If combat continuity is selected, use a narrow same-Session ordered opportunity integration;
do not create a second encounter scheduler or let two owners decrement busy.

## CONDITION ORDERING

`feature/condition.c` snapshots keys, traverses that array backward; no authored stable mapping
order is guaranteed. apply_condition replaces the complete payload, not additive duration.
Failure to load a daemon is caught/logged and removes it; loaded callback execution is **not**
caught. Returned flags are ORed even when its original ID is removed for absence of bit1.
Empty collection becomes0; missing/empty condition set returns0. Zero/negative payloads still
reach handlers; each handler defines expiry, not a global duration filter.

## CND_NO_HEAL_UP COVERAGE

Header values: CONTINUE=1, NO_HEAL_UP=2. Return2 would remove the condition yet block this
opportunity; return3 would keep it and block. Neither combination is returned by current daemons.
Full mudlib search `CND_NO_HEAL_UP` found only the header and char.c consumer. Complete reading
of all seven bodies also checks numeric returns, not merely macro spelling.

| Source condition | Payload / update | Continuation / removal | Can suppress heal? |
| --- | --- | --- | --- |
| bandaged | int; eff_kee<max → cure3, store old-1 | old==0 returns0; otherwise1, including negative | no |
| drunk | int; limit=(con+max_force/50)*2; see below | unconscious branch0; else store old-1, old==0→0 else1 | no |
| iceshock | int; gin damage25, kee wound25, sen damage25; old-1 | old<1→0 else1 | no |
| poison | mapping; kee damage d, wound d/2; duration--, writes mapping to **snake_poison** | decremented duration<1→0 else1 | no; wrong-ID/payload defect |
| rose_poison | int; sen wound20, kee damage10; old-1 | old<1→0 else literal1 | no |
| slumber_drug | int; same limit; high/living unconscious; otherwise message/decrement | unconscious0; old==0→0 else1 | no |
| snake_poison | int; kee wound10, sen damage10; old-1 | old<1→0 else literal1 | no |

**No source condition currently suppresses heal via bit2.** A callback error aborting execution
is not a no-heal flag and must not be disguised as one. no-heal is the current update's output,
never a permanent character field or a count of remaining duration.

## EXACT HEAL_UP ORDER

Table 2. All arithmetic is integer division, separately truncated toward zero. S=current,
E=effective, M=maximum; q=con/3 + paired-current-internal/10; raw levels are query_skill(id,1).

| Resource/stage | Precondition | Formula | Clamp / early return | update_flag | Saved state |
| --- | --- | --- | --- | --- | --- |
| water first | >0 | water-=1 | none | +1 | internal_resources.water |
| food second | >0 | food-=1 | none | +1 | internal_resources.food |
| water gate | userp and new water<1 | none | return accumulated flag | none | mutations above remain |
| gin | reached | S+=con/3+atman/10 | if S>=E: S=oldE; if E<M: E++ | +1 if S<oldE OR E repaired, otherwise0 | gin current/effective/max |
| kee | reached after gin | S+=con/3+force/10 | same | same | kee track |
| sen | reached after kee | S+=con/3+mana/10 | same | same | sen track |
| food gate | userp and new food<1 | none | return accumulated flag | none | primaries above remain |
| atman | max_atman!=0 and atman<max | +=raw magic/2 | cap above max | +1 on entry even gain0 | atman/max_atman |
| force | max_force!=0 and force<max | +=raw force/2 | cap above max | same | force/max_force |
| mana last | max_mana!=0 and mana<max | +=raw spells/2 | cap above max | same | mana/max_mana |
| return | end | accumulated count | not a changed-points total | return | not persistent gameplay state |

## FOOD / WATER METABOLISM

Both lose exactly1 only when positive, regardless of standing/moving/fullness. They never cross
zero by this subtraction; existing negative values remain negative, not repaired/clamped. No weight,
capacity, food bonus, hunger damage, thirst damage, death or sleep rule is present in heal_up.
Even full primary/internal resources still consume positive food/water. No-heal skips both.

## WATER-ZERO SEMANTICS

Player water1/food400 → water0/food399, flag2, **no primary/effective/internal recovery**.
Water0/food400 →0/399, flag1. Negative water also blocks. It does not cause damage/death.
Food keeps decrementing even without water. NPCs bypass this userp gate.

## FOOD-ZERO SEMANTICS

Player water2/food1 →1/0: primaries/effective repair still run; internals do not. If both
start1, water gate stops before primaries. Food0 with positive water allows primary recovery
but never internals. Already-held force/atman/mana still contribute to primary gains even with
food0; only their subsequent passive refill is blocked. NPCs bypass the food gate too.

## GIN / KEE / SEN RECOVERY

Base con, not query_con/apply modifier: gin gain=con/3+atman_current/10;
kee gain=con/3+force_current/10; sen gain=con/3+mana_current/10. Paired internal current is
observed before passive internal recovery. Example con29, force19 gives9+1=10, not48/3 or
a fractional sum. No multiplication by elapsed seconds, skill multiplier or combat penalty.

## EFFECTIVE RESOURCE REPAIR

After adding q, clamp to **old** E if reached; then repair E by1 if E<M. S does not follow E upward.
Example S70/E80/M100,q10 → S80/E81/M100; next →S81/E82. Full S100/E100/M100 stays full.
Even q0 with S=E<M repairs E by1; a lower S and zero/negative gain still takes the below-E flag
branch. No receive_curing bulk heal and no maximum recomputation are substituted.

## INTERNAL RESOURCE RECOVERY

Order is **atman → force → mana**. Maximum truthiness is !=0, not >0. Current>=maximum,
including over-cap values, remains unchanged. Eligible raw0/1 gives0 but increments flag;
raw3 gives1; e.g. force9/max10/raw5 adds2 then caps10. Fields have no general zero clamp.
Negative current/maximum and raw values are possible through generic LPC writes; no new range
constraint is implied. Native raw_level(magic/force/spells) supplies the existing three-field
RecoverySkillLevels adapter; mapped/effective skill and equipment modifiers are wrong inputs.

## UPDATE_FLAG SEMANTICS

At most eight increments: two metabolism, three primary/effective branches, three internals.
Not a boolean, resource-point total, nor a promise that something actually changed. Reaching
full E=M from below changes S but contributes0; being below E with gain0 contributes1. Internal
gain0 on eligible branch contributes1. Thus all zero actual gains can still prevent peace shutdown.
For interactive Player the shutdown condition is already false, so count does not decide whether
to continue the Player's lifetime clock. Preserve pure count; do not stop Player cadence at count0.

## FRESH PLAYER EXAMPLES

Native `NewPlayerInitializationPolicy` + default CharacterRecoveryState/CharacterInternalResourceState:
age14, base attributes30, gin/kee/sen100/100/100, food/water400, all six internal current/max
facts0, raw magic/force/spells0 and no initial skills. Body80000 and capacity150000 are independent
saved facts. Cloth adds armor1, not con or recovery. The food400 birth is the locked NGE correction
of LPC pre-body capacity0; this timeline is **source-equivalent heal applied to current Native birth**,
not a claim that literal uncorrected LPC birth already had400.

One unsuppressed opportunity while idle: food399/water399, all primaries100, internals0, flag2.
These are calculations, not a live S5A execution; current production does not advance them.

## WORK / RECOVERY EXAMPLES

Assume Work actions occur before any intervening opportunity, with no conditions or other damage.
Work consumes sen30 then gin30, unchanged by this analysis; kee stays100 and internals stay0.

| Starting action state | Eligible heal opportunities | gin / sen | food / water | flag for last heal |
| --- | --- | --- | --- | --- |
| Work once:70/70 | 1 | 80/80 | 399/399 | 4 |
| Work once:70/70 | 2 then3 | 90/90 then100/100 | 398/398 then397/397 | 4 then2 |
| Work twice:40/40 | 1,2,3 | 50/50,60/60,70/70 | 399,398,397 each | 4 |
| Work twice:40/40 | 6 | 100/100 | 394/394 | 2 |
| Work three times:10/10 | 1 | 20/20; Work still TOO_TIRED | 399/399 | 4 |
| Work three times:10/10 | 2 | 30/30; Work now allowed | 398/398 | 4 |

Work at exactly30 succeeds to0 (not a negative threshold). No XP/skill, arbitrary rest action,
Work cooldown or speed bonus. Water depletion can prevent this loop; food alone cannot replenish
water. S5B would close a bounded natural-food/repeated-income loop, **not an indefinite complete
supply economy**: no playable water refill has been authorized.

## DUMPLING / OVERSHOOT EXAMPLES

New Game→Work→Bank→Inn already earns the required denominations. First legitimate unsuppressed
heal makes400→399; actual direct-held out-of-combat Eat can then make399→459, remaining2/value0.
Later heal calls make459→458→…→400 after59 calls. At400 Eat still rejects `>=capacity`;
call60 yields399 and permits another bite. No normalization; over-cap food persists exactly.
Those60 calls consume water too, provided positive; food decrement continues even at water0.
Pause/busy/no-heal opportunities must not be counted as actual heal calls.

Future live acceptance must observe the first real decrease before eating, with no QA food edit.
Travel/purchase may span more opportunities: assert the observed pre-bite food plus60, not a
fabricated399. A controlled timing test may separately prove exact399→459. Save/fresh Continue
must preserve both food and partial item state without birth refill.

## CURRENT NATIVE CHARACTERRECOVERY AUDIT

Table 3: line-by-line comparison of damage.c heal_up with `CharacterRecovery.apply_tick` and its
resource setters. No code changes. “Match” is within represented ordinary resource invariants.

| Semantic | Source | Native pure service | Exact match? | Implementation concern |
| --- | --- | --- | --- | --- |
| no-heal | char short-circuits before heal | bool input returns0 before any mutation | yes composition | not character-persistent flag |
| water then food | positive only -1 each | same order/checks | yes | no capacity clamp |
| water zero | post-decrement <1 and userp | same with explicit Player bool | yes | caller must supply correct role |
| gin | base con/3+atman/10 | same integer operands/order | yes ordinarily | extreme negative case below |
| kee | base con/3+force/10 | same | yes ordinarily | no effective skill/modifier |
| sen | base con/3+mana/10 | same | yes ordinarily | internal refill occurs later |
| primary cap | clamp at old E | setter caps early, then same branch | equivalent ordinarily | not a new heal-to-maximum rule |
| effective repair | reached E then E++ below M | same, S remains oldE | yes ordinarily | lower-bound mismatch below |
| food zero | after primaries <1 and userp | same | yes | don't gate primaries on food |
| internal order | atman/force/mana | same | yes | do not infer constructor field order |
| skill/2 | raw query with1 | three explicit raw inputs /2 | yes | caller adapter still needed |
| internal bounds | max!=0, current<max, upper cap | same, no general field clamp | yes | oversupplied stays oversupplied |
| update count | branch count, not changed amount | same branches | yes ordinarily | caller must not use as Player sleep signal |

**Existing bounded mismatch, not newly fixed:** Phase1 CharacterResourceState clamps current at-1,
where direct LPC heal arithmetic can go lower for sufficiently negative con/internal contributions.
Example S0/E100,q=-2: LPC S=-2, Native S=-1. At E=-1/M100,S=-1,q=-1, LPC S=-2 and no E repair;
Native setter clamps S=-1, then E repairs to0. This is outside normal fresh active Player state but
is not universal parity. Phase2A already documents the -1 floor; do not silently “fix” it or hide
it when enabling new negative-state paths. Finite-width arithmetic overflow is likewise not
proven cross-driver parity. No confirmed ordinary fresh-player formula defect was found.

## CURRENT NATIVE CONDITION AUDIT

ConditionIds names all seven source IDs; default ConditionSystem registers only **snake_poison**
and **bandaged**. The other five are retained typed state, not executing gameplay. Duration payload
is integer; poison has typed damage/remaining/message, not unrestricted dbase. Save validator checks
known IDs' payload kind, and restorer recreates the exact payload without calling handlers.

When explicitly called, update_once sorts a snapshot of stable IDs ascending (existing approved
DECISIONS substitution), applies effects once, ORs flags and removes without CONTINUE. Missing
Native handler retains state rather than emulating failed LPC file loading. Snake poison damages
even old duration<=0 before removal; bandaged cures3 then decrements, old0 removes but negative
continues. No production handler returns NO_HEAL_UP. The test-only flag handler is not content.

Search across game scripts finds update_once/CharacterRecovery.apply_tick invocations only in
tests, apart from definitions. Hence conditions do not periodically advance in combat, ordinary
world, paused time or Continue. Persistence alone is not execution support; no no-heal state is
serialized. Enabling shared conditions is a real new runtime behavior, not merely wiring recovery.

## CURRENT NATIVE SCHEDULING AUDIT

Session `_process(delta)` currently advances only CombatEncounterCoordinator. Its scheduler exists
only for an active encounter, accepts application-active time and that encounter's gate ownership,
and processes participant opportunities/busy/attacks/lifecycle. It does not update conditions/heal.
Production recovery references otherwise derive capacities/initialization or expose saved state;
no hidden Session/Map recovery timer was found. Source-enabled active actions are not passive heal.
Neither existing combat timing nor the historical test names prove a Player metabolism clock.

## SESSION / MAP OWNERSHIP ANALYSIS

| Candidate owner | Continuity / freeze / duplicate risk | Recommendation |
| --- | --- | --- |
| Session, borrowing exact Player | one lifetime across Inn/Snow/Old Pine; replace with Session; explicit pause/staging/save/encounter input | narrowest owner |
| Player body Node | body/view changes on map handoff; risk reset/duplicate clock | reject view ownership |
| Player runtime pure state | durable character is right subject but should not read SceneTree/time; would still need adapter | typed cadence state may be composed, not a second ticking owner |
| Active resident map | inactive maps detached; activation resets or duplicates unless special transfer machinery | reject per-map timers |
| Combat scheduler only | absent in ordinary Inn/world and rebuilt per encounter | reject sole owner; allow narrow ordered combat integration |
| Global world/Autoload | unnecessary multi-character/offscreen authority, crosses Host Session swap | out of scope |

WorldResidentMapCoordinator retains one Player runtime and resident instances. Handoff temporarily
detaches source, commits Player location, attaches destination and reconciles; its transition/partial
failure flags matter. Session survives; therefore successful Inn↔outdoor/Snow↔Old Pine must not
reroll/reset cadence. Inactive resident NPCs remain frozen under existing DECISIONS; Player ticking
in the active map does not authorize offscreen NPC recovery. Do not count staging/half-commit time.

## PAUSE SEMANTICS

ES2 has no local menu pause. Current Shell uses SceneTree.paused; SessionSlot is PAUSABLE, Shell/Host
ALWAYS. Pause-origin Settings/Save/result remain frozen. Recommended: freeze cadence and partial
base interval without catch-up (Type B consistent with existing Shell). Continuing while paused is
Type B alternate lifecycle translation, not Type A; catch-up on Resume is an additional Type B
time policy with burst/damage/resource surprises and no ES2 pause evidence. No menu rest benefit.

## OFFLINE / CLOSED-APP SEMANTICS

Online interactive object keeps heartbeat. Netdead disables it but extant body may be externally
reawakened; reconnect retains tick and age's old timestamp. Quit saves then destructs; a full login
restores fields and runs setup, not a loop based on elapsed offline time. Chard only fills undefined
primary tracks; Human setup recalculates maxima, which is not elapsed recovery. No inspected login/
save path computes food or heal count from last_on. last_on is link/account bookkeeping in quit.

Recommend **no closed-app catch-up** (source absence of simulation preserved, Native exact Save
translation). Bounded/full catch-up invent offline depletion/reward and are Type C without new
evidence; also risk instant hunger, death-condition bursts, thousands of draws and clock tampering.
Do not equate disabled netdead heartbeat with a persistent body running offline indefinitely.

## SAVE / CONTINUE CADENCE

`tick` and `last_age_set` are static. Bundled save_object and LPC type docs explicitly exclude static
variables. F_SAVE uses save_object/restore_object; condition mapping and resource dbase are durable,
countdown is not. Same-body reconnect retains it; fresh setup rerolls. **Native Continue is not
already obligated to reproduce full-login reroll**, just as it preserves independent body facts.

Table 4 separates current behavior from proposals, which remain unapproved.

| Context | Source evidence | Current Native | Proposed future | Decision? |
| --- | --- | --- | --- | --- |
| Ordinary active world | eligible char calls count | no recovery/condition cadence | Session Player count | A/B/F |
| Busy | early return before countdown | combat owns integer busy advancement | freeze count using pre-step busy; never double-decrement | C |
| Combat | attack then possible condition/heal | gate closed, combat keeps running | preserve nonbusy eligibility with narrow ordered integration | D/E |
| Paused | no equivalent | Session tree paused | retain phase, no time/catch-up | G |
| World gate frozen | no same global gate | encounter owns freeze | block ordinary world; only explicit active-encounter path may advance | D/G |
| Map handoff | character tick independent of room | same Player/Session, synchronous transition | retain phase, exclude transitional/failed state | lifecycle translation |
| Save | static tick omitted | paused UI; serialized synchronous Host capture | complete opportunity before/after capture, never mid-update | I/K |
| App closed | no extant quit object | no process simulation | no catch-up | H |
| Continue | new body/setup rerolls | fresh Session, exact saved gameplay/three RNGs | prefer exact new cadence state if approved | I/K |
| Unconscious | zero currents can later heal; no living guard in heal | status committed, no automatic revive/recovery | explicitly defer in smallest ACTIVE-only slice | L |

Exact remaining-count + sub-interval + RNG persistence would preserve future Native outcomes but
is an observable **Type B departure from fresh LPC login**. Reroll-on-Continue aligns with that LPC
path but changes upcoming recovery and consumes a draw on load, conflicting with current zero-draw
restore guarantee. Fixed reset is also Type B, not source static restoration. Do not label any of
these already chosen. Save should remain possible between opportunities; adding a normal countdown
must not make the game permanently “busy” or save-ineligible.

## RECOVERY RNG

Source makes one random10 at setup and one **before** each condition opportunity, even when heal
will be skipped. Damage/busy/reconnect do not draw a new tick. An error after reset retains that draw.
The source uses driver RNG, not the project's three typed streams; identical driver-wide draw
interleaving is not a promise the Native game makes.

| Choice | Benefits | Risks / compatibility |
| --- | --- | --- |
| World-interaction RNG | existing saved stream | elapsed recovery changes future vine branch; semantic coupling, not free reuse |
| Combat RNG | existing saved stream | waiting in Inn changes attack/flee draws; worse mismatch |
| NPC-initialization RNG | already saved | unrelated spawn roll coupling; reject |
| Dedicated Player cadence RNG | isolation, reproducible count sequence | new typed stream/capture/restore/schema decision required |
| Fixed cadence | no new RNG, simpler tests | removes random variability; Type B timing substitution |

Recommend dedicated cadence source if owner selects randomized counts. Seed it only through approved
new-session composition; restore exactly with no draws. Do not use global RNG or steal an existing
stream. Rehydration must not trigger an extra initial randomization before installing saved state.

## AGE / IDLE BOUNDARY

`obj/user.c::update_age` initializes static last_age_set on first call, adds time()-last_age_set to
mud_age, updates timestamp and sets age=14+age_modify+mud_age/86400. It is opportunistically checked
after the shared tick, **not one age increment per recovery**. Busy delays checks but the next call
can count that elapsed time. Same-body reconnect may include disconnected elapsed time in age;
fresh-body setup initializes timestamp, so it does not synthesize that interval. mud_age/age mapping
persists; last_age_set does not. save() itself does not call update_age to flush pending elapsed time.

Native age is already a saved identity fact, not a running mud_age clock. Age scheduling is separate
scope; enabling heal does not require it. Do not reintroduce age15 gift reroll (explicitly rejected).
After interactive age update, query_idle>1200 invokes user_dump/quit; netdead timeout is900. These
are multiplayer session administration, not recovery rules. Omit idle logout, connection handling
and driver reset infrastructure; no single-player idle punishment/recovery speed modifier.

## UNCONSCIOUS / DEATH BOUNDARY

Source checks negative effective before negative current on entry. unconcious disables commands,
removes enemies, sets currents0, and schedules revive(random(100-con)+30); it does not explicitly
disable heartbeat. `feature/command.c::disable_player` only disables commands. Subsequent calls
with currents0/eff>=0 can reach heal even while not living; heal has no living/ghost guard.
Negative current again while nonliving instead invokes die. die clears conditions; user becomes
ghost with current/effective1 and goes to DEATH_ROOM, NPC is destroyed. Ghost recovery is not
automatically excluded by heal_up. An invalid con-driven revive random bound remains outside scope.

Important order: condition damage is after the entry threshold check and there is **no second
threshold check before heal**. E.g. sen5→-1 through snake damage can recover to9 with con30/mana0
on that same opportunity; it is not automatically committed unconscious between those steps.
A negative effective wound can also be incremented by subsequent heal before next heartbeat;
do not insert a new death check halfway and call it exact parity. Callback errors are separate.

Native has committed ACTIVE/UNCONSCIOUS/DEAD life status separate from resource evidence;
CombatEncounterResolution inspects/commits lifecycle around opportunities and existing adapter
sets unconscious currents0. No general timed revive is supplied by recovery. Recommend smallest
S5B explicitly activate **ACTIVE Player only** and defer unconscious/ghost recovery (Type B staged
omission), never auto-revive from positive recovered currents. If shared conditions are enabled,
owner must settle post-condition lifecycle ordering and threshold reconciliation at a defined
boundary before claiming parity. Reuse lifecycle executor, not a new Snow death/respawn policy.

## FUTURE DRUNK INTEGRATION

drunk limit=(base con+max_force/50)*2. Above limit while living: unconscious and immediate0 removal.
Nonliving branch prints only before ordinary decrement. Living above limit/2 damages sen10;
above limit/4 damages sen3 then calls missing receive_healing(gin10,kee15). Other ranges only
decrement; old0 removes, negative continues decreasing. All surviving branches return1, not2.
If callback completes, ordinary heal follows even after its unconscious branch; con30/internals0
can replenish currents0→10 without reviving commands. Missing method behavior is not silently
replaced with receive_heal. Shared cadence should eventually host drunk **before heal**, not a
second wine timer. This task neither implements the handler nor changes its revive/call_out defect.

## SAVE IMPACT

Existing capture/value types/CharacterStateSnapshotRestorer already preserve base con, all three
current/effective/maximum tracks, force/mana/atman current/max, food/water and raw skills needed
by recovery; typed condition payloads also persist. Primary capacity and body authority are not
rebuilt on Continue. Thus **recovery result persistence exists; cadence persistence does not**.

GameSaveSnapshot stores only combat, npc_initialization and world_interaction RNG. Codec has strict
exact root keys and strict rng keys for those three; adding a field under unchanged unversioned
schema2 is **not automatically backward compatible**. Item schema2 is unrelated to Player time.
Recommend owner review a versioned root/typed cadence extension with explicit pre-S5 handling
(migration initialization or rejection); do not decide schema3, a revision bump, or defaults here.
Existing development-save policy permits explicit cutoff but does not silently invalidate S4B saves.

Public Save is in paused Shell; Host serializes requests and coordinator synchronously checks
eligibility→captures→writes. It does **not** acquire WorldSimulationGate for Save; that gate is
encounter-owned. Do not describe a nonexistent save gate as current implementation. Restore staging
uses disabled processing; old Session suspension/rollback and current-Session publication are explicit.

Future proposal: no await/timer callback/reentrant Save inside condition→heal opportunity. At a due
boundary, either the whole successful ordered opportunity precedes capture or capture precedes it;
capture cadence and gameplay from the same boundary. Atomic visibility is not rollback: if a future
handler fails midway, retain reached mutations and block unsafe capture until explicitly resolved,
not replay effects/refund. Use existing operation/pause/staging guards; no second global freeze or
general transaction framework. New cadence must not run in a candidate before Host publishes it.

## OWNER DECISIONS REQUIRED

Table 5. **Recommendations only; none approved by S5A.** Existing S4B/Bank/Work decisions unchanged.

| Row | Options / classification | Recommendation and consequence |
| --- | --- | --- |
| A — cadence shape | Random6–15 eligible counts: A shape; fixed mean10.5/min6/max15: B timing; activity-driven rest/speed bonuses: C | Preserve randomized counts; no fixed “5–14 ticks” |
| B — base wall-clock | Prove exact driver period before claiming A seconds; explicitly select H as B; arbitrary interval called source: invalid | Require explicit H;2s is only a bundled-manual-grounded B candidate, not a proven/approved fact |
| C — busy | Freeze countdown on pre-step busy:A; advance count but suppress heal:B; ignore busy:C relaxation | Preserve freeze including busy1→0; borrow existing busy owner, no double-advance |
| D — combat | Nonbusy fighting still eligible:A; stop all while encounter:B omission; metabolism-only/no heal:C rule change | Prefer source eligibility with ordered combat bridge; open-world-only fallback needs explicit B approval |
| E — conditions | Compatible shared opportunity with supported handlers:A ordering/B staged coverage; wait for complete conditions:dependency deferral; recovery-only:B omission | Shared before-heal result boundary, existing two handlers only if lifecycle rowL settled; unsupported IDs must remain visibly deferred, not treated as executed |
| F — character scope | Player only:B staged scope; all NPCs:A wider source scope but violates current inactive-map limits; generic state with only Player activation:B architecture | One Player activation only; no NPC/offscreen simulation |
| G — Pause | Freeze phase/no catch-up:B; run in Pause:B alternate; resume catch-up:B altered lifecycle | Freeze as existing Shell does; menu time cannot recover/deplete |
| H — app closed | No catch-up:A absence of offline heal with B Native continuation; bounded/full offline simulation:C | No catch-up; timestamps not recovery inputs |
| I — phase persistence | Exact count+fraction:B vs fresh login; reroll:A new-login aspect/B vs current Native restore; fixed reset:B; elapsed scheduler state:B | Prefer exact restart-stable phase; distinguish same-body reconnect and fresh LPC login |
| J — RNG | Dedicated:B isolation architecture retaining A random range; reuse world/combat:B observable coupling; fixed cadence:B | Dedicated, independent of all three existing streams; rowK required |
| K — save extension | Explicit versioned extension + approved old-save initialization:B; explicit development cutoff:B; silent optional keys:invalid contract | Owner choose compatibility/version policy before coding; no S5A schema edit |
| L — life/ordering | Full unconscious/ghost parity:A scope needs revive/death boundary; ACTIVE-only:B staged omission; auto-revive:C | Start ACTIVE-only, preserve existing terminal authority; specify condition→heal then lifecycle reconciliation and combat tie order before enabling damaging conditions |
| M — age/idle | Age clock:A separate mechanics; deferred age:B staging; omit MMO idle:runtime omission; idle buffs/punishment:C | No age/idle in S5B; do not restore rejected gift reroll |

Rows D/E/L are real dependencies, not implementation details to decide silently. Exact source
negative-state recovery versus committed Native lifecycle needs an explicit boundary; if the owner
chooses a smaller recovery-only/no-combat slice, record its omissions instead of claiming full ES2
heartbeat parity. A dedicated RNG/phase recommendation does not itself authorize save-contract edits.

## PROPOSED S5B BOUNDARY

**NOT AUTHORIZED.** After owner resolves A–M: one typed Session-owned Player recovery/condition
opportunity state with a thin active-runtime time adapter, borrowing the exact CharacterState,
raw skill inputs and existing pure recovery. No Node in formulas, no per-map timer, no generic
heartbeat emulator. Preserve phase across physical map handoffs; pause/swap/staging cannot tick.
Implement only explicitly selected combat/life/condition coverage with narrow ordering seams.

Future focused acceptance:6/7/15-call traces; prebusy freeze and no double busy decrement; same-call
combat/condition order; bit2 suppresses food/water too; water1/food1 boundaries; raw0/1 update counts;
effective old-cap repair; independent cadence RNG; no influence on existing streams; map continuity;
paused/staged/save frozen boundaries; pre-S5 handling and exact cold phase continuation if selected.
Real acceptance must use existing New Game→Work→Bank→Inn UI, naturally observe399, eat to459,
see next458, save/cold Continue, and prove menu/offline time did not synthesize metabolism.
After three Works, two legitimate updates should restore Work eligibility30/30. No QA hunger edit.

## OUT OF SCOPE

No production/test/scene changes, recovery Timer/scheduler, live condition activation, RNG/schema
implementation, age, idle logout, offline rewards, wine/drunk/receive_healing repair, revive changes,
NPC recovery/population, new water source, Vendor/Bank/Work/dumpling changes, school/teaching,
Lake or Phase5B4. No final PR, merge, cleanup of owner-local tooling, branch or worktree deletion.

## VERIFICATION / EVIDENCE

Evidence is independent exact-HEAD/source reading and broad call-site/config/flag searches, not a
new LPC/Godot execution claim. Numerical examples derive directly from source, not production
test expectations. Independent arithmetic checks reproduced the6/7/15-call traces, Work examples
and59/60-call overshoot boundaries; these are not Godot test assertions.
Docs-only checks PASS: repository static checks,74 local Markdown links (zero broken), changed-doc
trailing whitespace (zero), git diff --check and exact four-document allowlist against52ece422.
No gameplay suite/live game/sanitizer rerun is needed
for these documentation-only changes; S4B's18,834 assertions are **not** S5A evidence.
Zero production/tests/scenes/reference/Save/schema/DECISIONS deltas are required before commit.

## STOP STATE

S4B: OWNER APPROVED / CLOSED. S5A: ANALYSIS COMPLETE — AWAIT OWNER REVIEW.
S5B: NOT AUTHORIZED. Snow: UNMERGED / NO FINAL PR. Commit/push this docs-only slice, then stop.
