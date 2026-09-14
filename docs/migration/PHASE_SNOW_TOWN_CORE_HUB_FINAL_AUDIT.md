# Snow Town Core Hub — Final Integration Audit

## FINAL OUTCOME

**PASS — PR READY.** No blocking defect found within the owner-approved **Core Hub**
boundary. This is not complete Snow region parity. S1–S7B are owner-approved/closed;
this distinct audit permits requesting final PR authorization, not creating or merging it.
Fresh local validation completed on 2026-09-13. No production correction was made.

## EXACT AUDIT BASELINE

- Branch: `phase/snow-town-core-hub`.
- Audited executable HEAD: `f6c8688b61a4fd850ce80699413b00ce3324d331`.
- Local HEAD and remote phase HEAD matched at entry; working tree/index clean.
- Main and merge base: `047f29083e881156abbdad6ed480bffc1350dfa8`.
- GitHub open-PR query for this branch targeting main returned no PR.
- This document's later docs-only commit does not change the audited executable baseline.
- Main already contains Source-valid New Game Entry through PR #15. Snow public birth
  and Snow ↔ Old Pine access are retained integration dependencies, not new branch features.

## AUTHORITY / OWNER STATUS

The final-audit owner instruction closes S1, S2, S3A/B/C, S4A/B, S5A/B, S6A/B and S7A/B.
Older slice documents describe historical checkpoints, not outstanding authorization.
Read current code, [DECISIONS](DECISIONS.md), [STATUS](../production/STATUS.md),
[ROADMAP](../production/ROADMAP.md), then current-phase evidence before older proposals.
`reference/es2/` remains authoritative for ES2 semantics.

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment,
interaction translation and presentation. Type A is semantic migration; Type B requires
explicit accounting for observable substitutions; Type C requires new owner approval.
No Type C work was introduced by this audit.

## FULL MAIN→HEAD DIFF

Main → audited executable HEAD: **18 commits / 189 changed paths**, partitioned without overlap:

| Category | Paths | Meaning |
| --- | ---: | --- |
| Production scripts and UID sidecars | 116 | 69 `.gd`, 47 `.uid` |
| Production scenes | 3 | Snow Inn, Snow Outdoor, Old Pine Outdoor |
| Tests and test UID sidecars | 52 | 30 non-UID files, 22 UID files |
| Documentation | 18 | Source contracts, owner decisions, slice evidence, current status |

No unexplained file: **0**. No project/build/export/CI/addon/config delta. Audit closeout
adds this document and updates only S7B status, STATUS and ROADMAP: the resulting branch
has **19 commits / 190 changed paths**, including 19 documentation paths. Do not confuse
the milestone's approved production work with this audit's zero executable delta.

## COMMIT MAP

| Commit | Slice / purpose |
| --- | --- |
| `c5f4472` | S1 Snow source/dependency rebaseline |
| `241a33a` | S2 Work income, silver and physical access |
| `dc2a07e` | S3A currency/payment source contract |
| `85d5754` | S3B owner decisions, before implementation |
| `e7ef0cb` | S3B typed currency/payment/Bank core |
| `5fc0627` | S4A Inn Vendor/consumables analysis |
| `78b59f0` | S3C physical Bank exchange |
| `b00e787` | S4B owner decisions |
| `52ece42` | S4B waiter contact/dumpling |
| `f52cb69` | S5A recovery/metabolism analysis |
| `1f515b4` | S5B owner decisions |
| `add93fc` | S5B Player recovery cadence |
| `945a8bd` | S6A water/drink analysis |
| `8b577b9` | S6B owner decisions |
| `add8d32` | S6B fresh-water supply loop |
| `04c7765` | S7A north street/services rebaseline |
| `a7a4e28` | S7B owner decisions |
| `f6c8688` | S7B physical north spine |

## SOURCE IMMUTABILITY

`git diff main..f6c8688 -- reference/es2` is empty; audit source delta is also zero.
No external port was consulted. Principal LPC files rechecked directly in this audit:

- `adm/daemons/logind.c` (fresh setup/entry), `adm/daemons/chard.c`,
  `adm/daemons/race/human.c`, `include/login.h`, `obj/cloth.c`.
- `std/char.c`, `feature/damage.c`, `feature/finance.c`, `feature/move.c`,
  `feature/clean_up.c`, `std/item/combined.c`, `cmds/std/buy.c`, `feature/vendor.c`,
  `std/room/bank.c`, `feature/food.c`, `feature/liquid.c`.
- `obj/money/coin.c`, `silver.c`, `gold.c`; `obj/example/dumpling.c`, `wineskin.c`.
- `d/snow/inn.c`, `square.c`, `mstreet1.c`, `mstreet2.c`, `mstreet3.c`, `mstreet4.c`,
  `crossroad.c`, `workplace.c`, `bank.c`, `sroad1.c`, `eroad1.c`, `eroad2.c`, `eroad3.c`.
- `d/snow/npc/waiter.c`, `herbalist.c`, `post_officer.c`; `d/snow/postoffice.c`,
  `std/room/hockshop.c`, `obj/mailbox.c`, `include/globals.h`, `obj/drug/snake_drug.c`.
- `d/oldpine/epath2.c`, `waterfall.c`; `daemon/condition/drunk.c`, `poison.c`,
  `snake_poison.c` and the `d/oldpine/npc/venomsnake.c` poison call site.

The existing S1/S7A complete 38-room archaeology was cross-checked against the implemented
routes and deferred service dependencies; this audit does not claim it newly implemented
or live-entered every authored room.

## PRODUCTION SCOPE MAP

Paths below are relative to `game/`; the complete Git diff supplies individual filenames.

| Owner slice | Changed production groups | Boundary result |
| --- | --- | --- |
| S2 | `application/snow/snow_work_{service,result}.gd`, `data/items/source_silver.gd`, shared Snow definitions/controller, `runtime/world/world_item_instance_index.gd` | Ordered Work and guarded derived-index cleanup |
| S2/shared | `data/oldpine/oldpine_npc_definitions.gd` | Reuses canonical silver constants; no altered NPC counts/loadout behavior |
| S3B | Six `application/finance/` and five `core/finance/` scripts; coin/gold/currency definitions | Typed direct-held money operations, no wallet or generic transactions |
| S3C | Bank panel/result, Snow controller/definitions/scene | Physical same-resident Bank access and explicit UI exchange |
| S4B | Six `application/food/`, three `core/items/food/`, dumpling definition, food record and held-food panel | Session-owned typed food, ordered goods delivery/use |
| S5B | Three `core/characters/` cadence/result/random-boundary scripts and runtime recovery RNG adapter | One transient Player cadence; unchanged `CharacterRecovery` formulas |
| S6B | Six `application/liquid/`, three `core/items/liquid/`, wineskin definition, liquid record/panel | Independent typed liquid states; no alcohol simulation |
| S6B | Vine policy/adapter; Old Pine outdoor controller/scene | Approved nonpositive-dodge branch and physical Waterfall Fill point |
| S4B/S6B shared | Ten existing native item/save projection, capture, codec, validator, restorer and aggregate scripts; world save capture and item catalog | Extends the existing item authority, not another persistence system |
| Shared runtime | Session and resident-map controllers, Snow Inn controller/scene | Borrowed shared authorities, UI availability, map-independent held use |
| S7B | Snow definitions and Snow Outdoor scene | Three north zones/closed frontages; no new service code |

All 69 changed `.gd` paths and three scene paths fit these groups. UID files are resource
identity companions. Tests/runners account for all remaining executable changes.
No banking NPC, network account, vendor inventory, generic consumable engine, skill/combat
redesign, new global service locator or new region runtime slipped into this milestone.

## DECISION VERIFICATION MATRIX

| Decision authority | Code/evidence | Result |
| --- | --- | --- |
| NGE birth/body/save choices | Unchanged source-entry/body authorities; complete regression and Journey A | Retained |
| S2 failed Work delivery | Work result/service, lifecycle failure tests | Costs/sequence retained; safe orphan destroyed, no refund |
| S3B A/B/E | `SourceAffordability`, `MoneyPaymentService`, literal tests | 0/1/2 anomalies and ordered partial mutation preserved |
| S3B C/D/F/G/H | Bank/context, over-cap/zero-stack/failure tests | Scoped cleanup, one-unit admission, direct-held lookup, canonical money |
| S3C / S4B K | Physical Bank route, Journey A | No starter money/change-making workaround |
| S4B A–J/H1 | Dumpling service/state/codec/UI, focused suite | Separately approved paid-delivery cleanup and staged contact/use |
| S5B A–M | Cadence/Session guards/private RNG, focused184 | Approved timing/freezes; existing recovery formulas only |
| S6B A–M | Liquid/service/codec/Vine/Waterfall, focused118 and Journey B | Same-ID Fill, exact Drink, alcohol deferred, no new saved RNG |
| S7B A–L | Shared Snow geometry and focused188/Journey C | Continuous spine, closed services/regions, bounded finish line |

S4B's initial wine omission and S5B's historical item2 checkpoint are explicitly superseded
only by S6B. No historical cleanup decision has silently become a universal transfer policy.
DECISIONS has the approved milestone additions, but **this audit changes it by zero bytes**.

## NEW GAME

PASS, retained from main: public display-name + explicit source binary gender; Human age14,
eight attributes30, potential99, combat_exp0, gin/kee/sen100, food/water400, independent
body80000/capacity150000, cloth worn/armor+1, empty hands, no initial Player money or skills,
Snow Inn birth. Session bootstrap remains 12 items (Player cloth plus 11 existing NPC items).
Body facts are not recomputed on ordinary strength changes or Continue. No login/password/email
or delayed age15 gift reroll. Fresh supply fill is birth-only, not a Continue refill.

## SESSION / AUTHORITY OWNERSHIP

ApplicationShell → persistent Runtime Host → one current Session remains intact. Session owns
Player, Inventory, CombinedStackCollection, item index, FoodCollection, LiquidCollection,
allocator, simulation gate and recovery cadence. Resident maps/UI borrow these authorities.
Four resident maps, one active map child, 13 Snow zones (12 outdoor + one Inn), zero Snow NPC
runtime population. Waiter/Bank contacts are not saved NPC instances.

Additional real-input Inn→Square traversal in run18 compared all nine authority ObjectIDs:
Player, Inventory, stacks, index, foods, liquids, allocator, gate and cadence were each unchanged;
only active map changed `snow.inn`→`snow.outdoor`. For example Player
`-9223371627406816569`, Inventory `-9223371628027573673`, cadence `-9223371591386132754`.
These diagnostic ObjectIDs are not persistence identity. Cold Continue constructs fresh objects
but retains semantic IDs; restored Equipment/Armor are the same objects injected into runtimes.
No capture/restore duplicate authoritative collections or recurring bootstrap were found.

## WORKPLACE

`d/snow/workplace.c`: `gin < 30 || sen < 30` → unified `TOO_TIRED`; otherwise sen−30,
then gin−30, then allocate silver, set amount1, attempt delivery. Tests prove fresh100→70→40→10
and fourth rejection with no allocation **when no recovery opportunity intervenes**. Three
successful Works yield one surviving amount3/weight111 silver stack. Source merge keeps the
newly moved object; consumed IDs are not reused. No Work busy rule, cooldown, XP, skill or RNG.
Live values are reported separately below because natural recovery can interleave clicks.

## FINANCE / BANK

Canonical real ItemInstance + CombinedStack money: coin(value1/weight1/文), silver(100/37/两),
gold(10000/37/两). No numeric wallet. Affordability is not total-value subtraction:
coin100→price100 returns2, silver1→100 returns1, gold1+silver1→9900 returns1 even though ordered
payment cannot complete. Presence differs from zero amount. Vendor rejects2; no auto-change.
Payment is gold→silver→coin; errors retain completed mutations. Checked arithmetic rejects
overflow, not clamps/wraps. Duplicate direct stacks select ascending stable ID, not sum.

Bank preserves source validation/rounding and target mutation before source debit. New target:
allocate→authored amount1→one-unit-weight transfer→converted amount→source debit→scoped cleanup
if delivery failed. Existing target: grow without a move/capacity check. Same denomination grows
then subtracts from the same object. Equality at admission is legal; final over-cap inventory
is legal. Literal tests include new target1062/existing1063 against capacity1000. No preflight
of final or net weight and no rollback transaction. Save transactions are a different boundary.

## INN / VENDOR

Static scene-owned 店小二 contact, two unlimited offers only: dumpling15, wineskin20.
No waiter character/combat/greeting RNG/stock/birthday/account authority. Validate canonical
offer/projections first, then affordability/payment, allocation, full-weight registration and
delivery against post-payment inventory. Never move a final-weight precheck before payment.
Failures truthfully distinguish paid versus delivered and reached stage; no unconditional success.
Vendor cleanup is separately owner-approved for dumpling, explicitly extended to wineskin.

## FOOD

Dumpling weight80, fresh portions3/value15. Accepted bite checks direct Player ownership,
ordinary ACTIVE noncombat availability/busy and `food < body_weight/200`; adds60 without clamp,
sets value0, consumes one portion. Legal live Save states: 3/15, 2/0, 1/0. Final bite removes the
authoritative item, then food association and index; no rebirth of consumed food. Failed removal
retains already-reached mutations and returns authority failure, not a valid settled Save.
Collection is keyed by stable instance ID; no shared mutable portions or UI-owned food state.

## RECOVERY / METABOLISM

Source `std/char.c` countdown5–14 is post-decrement: opportunity on pulse6–15, resetting before
recovery. Owner-selected base pulse2.0s is Type B, not proven ES2 deployment timing. Busy consumes
pulse time but not countdown/RNG and is never advanced by this scheduler. Pause/staging/handoff,
encounter/fighting, any condition and non-ACTIVE life freeze the full phase. No NPC cadence,
condition update, offline catch-up, age/idle mechanism or resurrection was introduced.

`feature/damage.c::heal_up`: positive water−1 then positive food−1; Player water<1 returns.
Then gin uses con/3+atman/10, kee con/3+force/10, sen con/3+mana/10, with integer arithmetic;
reaching effective clamps current to the old effective value before effective+1 toward maximum.
Player food<1 then returns. Internal recovery order is atman(raw magic/2), force(raw force/2),
mana(raw spells/2), each under its source maximum guard. No invented starvation damage/refill.
`RecoverySkillLevels` remains a narrow raw-level input; no-heal remains an update input, not
persisted character permission or a condition-collection dependency in CharacterRecovery.

Loop review: finite nonnegative delta and representable subtraction checked; due pulses are
processed in order, not capped. Huge finite synthetic deltas could be expensive, but production
uses frame delta and freezes offline/staged time; no observed or reachable new unbounded loop
blocker. Collection/UI scans are bounded by represented items; no speculative optimization made.

## WATER / LIQUID

Canonical wineskin weight700/value20, RED_WINE15/drunk6 metadata. Red-wine Drink returns
`ALCOHOL_DEFERRED` with zero mutations; it does not call the defective legacy drunk path.
Waterfall Fill replaces the same item's contents with CLEAR_WATER15, discards wine visibly,
and changes neither Player water nor ID/allocator/RNG. Requires valid active physical placement
within96 of the marker, correct authoritative zone, direct ownership and ordinary availability.
No zone-ID-only Fill, portable source, ground/nested use or direct environmental Drink.

Clear-water Drink requires water<capacity, consumes one then adds30 without clamp. Empty vessel
remains a live weight700 item, may refill, and saves as remaining0. Each instance is independent.
No universal liquid/food/weapon/armor/stack exclusion is inferred from this one authored item.

## VINE / WATERFALL

`d/oldpine/epath2.c` and `waterfall.c` rechecked. SOURCE_ENTRY_V1 effective dodge<=0 takes the
existing Waterfall branch without RNG, per S6B decision; this is not a claim about LPC random(0).
Positive dodge retains the existing world-interaction draw/threshold behavior. No shortcut,
damage/formula change, new map or Green destination. Existing legacy technical profile boundary
is not broadened. Natural Journey B reached the water point through this actual traversal.

## SNOW PHYSICAL GRAPH

Within `snow.outdoor`, ordinary CharacterBody walking joins:

```text
                    crossroad [north Goathill / east Green CLOSED]
                        |
                     mstreet4 [west Postoffice CLOSED; no east exit]
                        |
                     mstreet3 [west Herbshop / east Hockshop CLOSED]
                        |
                     mstreet2 —— Workplace   [west Smithy CLOSED]
                        |
             Bank —— mstreet1                [east School CLOSED]
                        |
 Snow Inn [portal] —— Square                  [east Temple CLOSED]
                        |
                     sroad1 —— eroad1 —— eroad2 —— eroad3
                                                        |
                                                   Old Pine
```

No one-scene-per-room conversion. Geometry/zone placement validation share definitions;
new north rectangles do not relocate old positions. Source metadata is traceability, not
a second room-graph movement authority. All thirteen zone definitions match their maps.

## NORTH SPINE

S7B adds distinct mstreet3, mstreet4, crossroad continuously beyond existing mstreet2; no
additional resident, spawn population, RNG draw or gameplay service. Physical north/south
joins and half-open ownership are tested. New-zone Save/Continue preserves physical position.
Postoffice frontage is west only: prose does not authorize an invented mstreet4 east alley.

## EXTERNAL BOUNDARIES

Green/Goathill are visible colliding staged boundaries without destination, portal, guard,
key or authored-lock fiction. Existing School, Smithy, Temple, southwest route and external
edges remain closed. Journey C physically tested Goathill/Green, Herbshop/Hockshop/Postoffice,
the absent mstreet4 east route, School/Smithy, Square Temple, sroad1 west/south and eroad3 east.
Inn upper/wizard and eroad1 north were checked structurally/regression, not separately pressed
in this final live run. No claim that every deferred doorway received new live footage.

## SAVE / CONTINUE

Root schema2 and `SOURCE_ENTRY_V1` remain the public contract. Embedded item format is now3
(food and liquid records), not root schema3 or SOURCE_ENTRY_V2. Inventory remains the single
existence/parent/weight authority; side collections associate typed facts, index is derived.
Full capture equality includes Player/body/resources/skills/conditions, locations, item IDs,
parents/weights/stack amounts/food/liquid, Equipment/Armor, NPC ledger/corpses, three RNG streams
and allocator. No birth, reward, wine refill, new ID or bootstrap during Continue.
Each live Journey A/B/C used a terminated writer and fresh OS process; entire normalized
snapshot equality and unchanged file hash were checked, not just visible money/HUD.

## OLD-SAVE COMPATIBILITY

Current root2 legal item1→3 supplies empty food/liquid records; item2→3 supplies empty liquid
records. This is semantic compatibility, not byte-identical explicit resave. Missing required
state for an already-present food/liquid definition rejects, never fabricates fresh contents.
Root1 and pre-cutover legacy development saves remain unsupported.

| Fresh current-reader execution | Archived original writer/profile | Result |
| --- | --- | --- |
| Pre-S2 exact main | `047f2908`, `s2-main-047f-compat` | PASS, entire normalized snapshot/index/allocator |
| Pre-S3B | `dc2a07e`, `s3b-exact-dc2a07e` | PASS |
| Pre-S3C | `5fc0627`, `s3c-exact-5fc0627` | PASS |
| Pre-S4B | `78b59f0`, `s4b-exact-78b59f0` | PASS |
| Pre-S5B | `f52cb69`, `s5b-exact-f52cb69` | PASS |
| Pre-S6B item2 | `945a8bd`, `s6b-pre-945a8bd` | PASS, no liquid synthesized/file rewrite |
| Pre-S7B positions | `04c7765`, `s7b-pre-04c7765` | PASS |
| Current item3 | Actual Journey A/B/C files | PASS, wine15, water14, partial food and north/Old Pine positions |

Old writer artifacts were retained from slice validation; the **current readers were rerun
in this audit**, not falsely described as newly executed old writers. Existing focused tests
also construct strict version1/2/3 fixtures. Scope is current legal source saves, not arbitrary
historical development formats.

## INVALID-SAVE REJECTION

Canonical and focused regression cover unknown/missing/extra root/item keys and versions,
invalid Player/body/location/physical placement, RNG adapter/state, duplicate IDs, dangling or
cyclic parents, bad equipment/armor references, allocator malformed/stale/overflow cases,
food duplicate/missing/non-food/invalid portions-value, liquid duplicate/dangling/missing/non-liquid,
unknown content, remaining<0/>15 and wrong weight. Unknown old-version extra records reject.
No permissive fallback or fresh consumable reconstruction. Settled legal over-cap Bank outcomes
are not mistaken for malformed inventory; failed lifecycle checkpoints cannot masquerade as Save.

Save field/schema inspection found no account password/token/credential or owner-local absolute
directory introduced into gameplay data. Isolated test profile names are test metadata. Logs are
local diagnostics (may identify workstation paths), not a credential or mail-account subsystem.

## RNG

Exactly three persisted gameplay streams remain: combat, NPC initialization, world interaction.
Recovery has one private transient RNG; no global RNG, Save field or gameplay-stream borrowing.
Work, Bank, Vendor, food/liquid, street walking and nonpositive SOURCE vine consume none of the
three. Positive Vine uses the existing world stream only. Full A/C/B snapshots retained the same
three stream states; world state was `4921355087742706078` immediately before and after Vine/Fill/Drink.
Cold Continue restores those states with zero draws; only fresh transient cadence phase is drawn.

## ITEM ALLOCATOR

One durable Session scope/sequence; no item ObjectID or RNG allocation. A: birth next1,
Work1→2, Work2→3, Bank new coin→4, dumpling→5, wineskin→6. All walking/Fill/Drink/Continue retain6.
Newly moved silver survives stack merge; prior ID is retired. Failed allocated reward/goods/target
consume sequence under their specific policies. Full exhaustion/destruction never enables ID reuse.
Fresh restore reconstructs exact semantic IDs and advances stale continuation past represented IDs;
malformed same-scope IDs, duplicates and INT64 overflow fail. Existing allocator regressions pass.

## LIFECYCLE / CLEANUP POLICIES

Work, Bank and Vendor failure policies are three separately approved compositions. All retain
reached costs/sequence; only safe ownerless products are removed, using ItemLifecycle before
associated food/liquid and derived-index forgetting. No refund, ground drop, timer, persisted
orphan or generic rollback. Unknown ownership/failing removal is explicit authority failure,
not fallback destruction. Payment exhaustion is S3B-local immediate removal; global Combined
zero-amount deferred semantics are unchanged. Food last bite and empty wineskin deliberately
have different lifetimes. No new revive/ghost/unconscious recovery, corpse cadence or loot sales.

## REAL PLAYER JOURNEY EVIDENCE

Canonical ApplicationShell under actual Godot4.7.2/Godot AI4.0.4. Successful runs had
helper_live/session_active/game_capture_ready=true; non-stale framebuffer observations with
advancing frame numbers. Movement used input actions/CharacterBody/physical Area entry;
commerce/use/Save/Continue used real framebuffer HUD buttons. Chinese name was delivered as
an InputEventKey, not assigned as gameplay state. No teleport, resource/skill/item/RNG injection,
controller traversal, direct service calls or manual gameplay signals in the claimed journeys.
Only pre-game QA setup selected isolated `snow-final-audit-20260913` save storage with empty Host.
Owner development saves and local Godot AI backups were not cleaned or modified.

### Journey A — PASS

New Game→Inn→Square→mstreet1→mstreet2→Workplace; Work twice; physically Bank→silver1 to coin100;
return Inn→buy dumpling15 and wineskin20→natural metabolism→Eat→Pause Save→terminate→fresh Continue.
Work1 observed gin/sen70; Work2 observed50, because recovery occurred between clicks. No false
claim of a forced40. Final money silver1+coin65; dumpling2/value0, wineskin RED_WINE15, next sequence6.
Eat observed food382→442. Saved/continued food442/water382, exact complete snapshot.
Writer run12; cold PID29264. Nonstale frames31317/34061 documented purchases/Pause.
Save SHA-256: `2a6ca60711c62b4342f46ee4a0bd06792298e346e4a59c46704ff7b69c042b12`.

### Journey C — PASS (performed before B)

Inn/Square→mst1/2/3/4→crossroad; physically pressed north Goathill and east Green barriers,
remaining Snow. North stop approximately(-5.6666,-1820.9932), east(270.9932,-1652.2604).
Pause Save→terminate→fresh PID82248→Continue exact crossroad position/full snapshot→Resume and
walk south, check service frontages and older closures, continue toward southern route.
Hockshop/Herbshop/mstreet4 lateral walls stopped movement at approximately x=±70.993.
Nonstale frame11725 showed closed frontages. No new NPC/session/allocation/RNG on north walking.
Save SHA-256: `7164ad5d35accffc314b002941d18cd79b66d7bd3fb5a870303017ea74195e6d`.

### Journey B — PASS

From saved crossroad, physically walked Snow→Old Pine→East Bridge. Effective dodge0 confirmed;
clicked Vine then Hold Vine→existing Waterfall landing(1200,780), zero world RNG draw.
Walked to water point(1200,897.333984), filled same `.dynamic.5`: wine15→clear water15,
Player water356→356, no new ID/condition. Natural next pulse preceded Drink: water355→385,
remaining15→14; allocator6/world RNG unchanged. Nonstale frame18435 showed clear water14.
Later Pause Save food413/water383→terminate PID19552→fresh PID56504 Continue→Pause;
entire snapshot equal, same water14/location/money/IDs/allocator/three RNG streams.
Cold nonstale frame15260; four residents/one active child/zero Snow NPC/index IDs exact.
Save SHA-256: `4ee3fa69b8dddf676152e1ceaf69537998180d3bd7cd2886782ae6be397356ec`.

### QA caveats, not production PASS suppression

Exploratory helper snippets had an indentation compile error and mistaken API-field/method
names (`state.food`, direct body weight, `query_skill`, and later profile `directory` instead
of `directory_path`). These caused QA debugger errors; affected processes were stopped/restarted,
not counted as successful journeys. No production fix was made. One oversized input timeline
was rejected before applying input and split; one slow orchestration response was checked against
actual position/released inputs before continuing. An initial cold Continue click did not dispatch
and was retried as real input. Clean successful runs started with current_run_errors=[]; ordinary
retained integer-division/shadow warnings and desktop virtual-keyboard warning are not claimed absent.
Games are stopped after evidence. Food/shop panels can remain dimly visible behind Pause, while
interaction is blocked; this is a nonblocking presentation inconsistency, not active commerce in Pause.

## TYPE B OMISSION LEDGER

All **25** entries below are acceptable for this bounded PR under the cited owner decisions;
none grants automatic authority for further implementation. References are sections of DECISIONS
or the already-integrated NGE/current Snow slice contracts.

| # | Observable translation / omission | Rationale and owner reference | Player-visible effect |
| --- | --- | --- | --- |
| 1 | Post-body fresh food/water fill | NGE Fresh Food/Water B | Birth400/400 instead of initialization-order0/0 |
| 2 | Single-player account omission | NGE Native Character Entry | Name/gender, no login/password/email/mail identity |
| 3 | No delayed gift reroll | NGE gift B | No age15 login overwrite |
| 4 | Development Save cutover | NGE5A1 | Unsupported old root1 rejected, not silently upgraded |
| 5 | Exact independent body Continue | NGE5A0 | No login-time strength-driven body rebuild |
| 6 | Failed Work reward cleanup | S2 only | Spent cost/ID, no reward/drop/refund; immediate cleanup |
| 7 | Failed Bank target cleanup | S3B C | Conversion's reached debit remains; no orphan/timer |
| 8 | Direct-held bounded finance | S3B F/H | No ground/bag fallback, duplicate-ID ordering, canonical denominations |
| 9 | Immediate money exhaustion | S3B G | No stale-positive delayed-destruct window in payment |
| 10 | Static waiter contact | S4B J, S6B J | Commerce point, not living NPC/greetings/birthday |
| 11 | Paid Vendor failure cleanup/reporting | S4B A–C, S6B J | Paid but not delivered is visible; no refund |
| 12 | Bounded food reach/combat use | S4B G | Specific direct-held ACTIVE noncombat food only |
| 13 | Native 2s pulse | S5B B | Eligible opportunities12–30s, not proven deployment timing |
| 14 | Combat recovery freeze | S5B D | No fighting recovery/metabolism in staged runtime |
| 15 | Any-condition freeze | S5B E | No partial recovery while condition cadence is absent |
| 16 | Player/ACTIVE-only cadence | S5B F/L | No NPC or unconscious/dead recovery/revive |
| 17 | Pause/offline freeze | S5B G/H | Menus/closed app do not grant rest/catch-up |
| 18 | Transient recovery phase/RNG | S5B I/J | Continue creates new unsaved phase; saved streams exact |
| 19 | No age/idle clock | S5B M | No idle eviction/age gift/aging during this cadence |
| 20 | Alcohol deferred | S6B alcohol decision | Wine cannot be drunk; explicit zero-mutation refusal |
| 21 | Direct-held noncombat liquid | S6B H/I | No ground/nested/combat use or busy2 success path |
| 22 | SOURCE dodge<=0 Waterfall | S6B entry decision | Fresh Player gets existing fall branch without random(0) |
| 23 | Waterfall-only physical Fill | S6B M | Other authored water sources unavailable; near-point proof required |
| 24 | Core physical clustering/closed local services | S7B A/C–H and NGE map boundary | Continuous streets; School/Smithy/Postoffice/Hockshop/Herbshop etc. deferred |
| 25 | Closed external directions | S7B B and NGE route boundary | Green/Goathill/other unimplemented regions blocked, no invented keys |

## SOURCE DEFECT LEDGER

**12 source defects/oddities**, separate from Native staged omissions:

| # | Source evidence | Classification / treatment |
| --- | --- | --- |
| 1 | waiter references `/obj/example/cake`, absent from mudlib | Missing content; no replacement invented |
| 2 | `daemon/condition/poison.c` reapplies mapping to `snake_poison`, whose handler expects int | Apparent name/state-shape defect; deferred, not attributed to correct venomsnake integer call |
| 3 | `drunk.c` calls `receive_healing`; source search finds no implementation | Missing dependency; alcohol explicitly deferred, no repair |
| 4 | mstreet4 prose suggests east alley; executable exits omit east | Executable topology wins; no east route |
| 5 | herbalist `heal_me` falls through for low effective percentage without healing/return | Incomplete service, not a free-heal rule |
| 6 | Postoffice sign charges10; post_officer/mailbox executable send flow has no fee debit | Prose/execution mismatch; mail/account subsystem deferred |
| 7 | Hockshop sign promises redeem/retrieve; executable actions expose value/pawn/sell, no retrieval | Missing advertised path; no ticket system invented |
| 8 | finance presence/strict comparison anomalies | Deterministic behavior preserved, not normalized |
| 9 | Combined `set_amount(0)` schedules destruction and returns without storing0; move may unequip before failed capacity check | Deterministic partial lifetime/mutation, not an atomic transfer claim; scoped substitutions only |
| 10 | Vendor ignores delivery return and emits success text | Deterministic misleading presentation; owner-approved truthful Native result |
| 11 | `snake_drug.c` spells `base_weiht` | Authored typo; medicine/weight repair not implemented |
| 12 | eroad prose disagrees with executable directions | Executable exits are topology authority, not a new north route |

These are not blockers to the approved Core Hub finish line; no new legacy defect repair
was authorized or implemented in this audit.

## DEFERRED CONTENT LEDGER

- Snow services: Hockshop appraisal/pawn/sale/custody/retrieve; Herbshop medicines/healing;
  Postoffice/mail; School/teaching; Smithy/craft/repair; Temple/revive; Inn upper floor;
  secret/storage/weapon pickup.
- Public geography: southwest sroad2–5 branch; no all38-room runtime claim.
- External regions: Green, Goathill, Canyon, Waterfog, Dragonhill, external Temple, Lake.
- Systems/content: full Snow NPC population, loot monetization, fast medicine, condition cadence,
  alcohol/drunk, other waiter goods/cake/birthday, accounts/mail, teaching/apprenticeship, Phase5B4.

No placeholders mint goods, grant skills, heal for free, accept pawned loot or permit fake region
travel. Prior cleanup decisions do not pre-authorize any deferred service's failure behavior.

## CURRENT LIMITATIONS

Approved preparation loop is Work→Bank→food and wineskin→eligible slow recovery→Waterfall supply,
with public north exploration. It is not full economy/training/fast medicine/condition recovery.
Conditions can freeze recovery indefinitely until another authorized system handles them; normal
Snow supplies create no condition. No new revive or offline recovery. Closed façades are explicit
staging, not lore locks. New Snow panels have desktop live proof here, not a fresh physical-phone
qualification or new export artifact run. Cross-platform release jobs remain the future PR gate.

## PR RISK REVIEW

| Risk | Rating | Mitigation / residual boundary |
| --- | --- | --- |
| Gameplay semantics | MEDIUM | Source oddities and25 substitutions explicitly accounted; literal tests + actual loop |
| Save compatibility | MEDIUM | Strict three item versions; seven archived source profiles reread; no old-root promise |
| Persistence | LOW | One item authority, typed associations, full cold equality and malformed rejection |
| Economy | MEDIUM | Non-atomic/payment anomalies intentional; no silent refunds/capacity normalization |
| Map/geometry | LOW | Shared placement geometry, physical boundaries/north cold Continue |
| RNG | LOW | Three saved streams unchanged; private transient recovery stream tested |
| Lifecycle | MEDIUM | Scoped cleanup/failure tests; no new condition/revive cadence or fallback |
| Deferred-content expectations | MEDIUM | Visible closures, bounded title/ledger, no full-parity claim |
| CI/platform | MEDIUM | Local canonical/Python/static/sanitized pass; PR four-platform CI not yet run |

No unresolved HIGH blocker. No unsafe credential serialization, generic unrestricted payload,
mutable global collection or false success path found in introduced functionality.

## TEST / VALIDATION EVIDENCE

Fresh executions on audited HEAD, not recycled historical PASS statements:

| Validation | Result |
| --- | --- |
| Complete canonical `res://tests/run_tests.gd` | **19,410 assertions / 0 failures / exit0**; run once |
| Focused Work | 122 / 0 / exit0 |
| Focused finance | 182 / 0 / exit0 |
| Focused Bank access | 384 / 0 / exit0 |
| Focused dumpling | 488 / 0 / exit0 |
| Focused recovery | 184 / 0 / exit0 |
| Focused water | 118 / 0 / exit0 |
| Focused north spine | 188 / 0 / exit0 |
| Focused total | **1,666 assertions**, overlapping canonical coverage, not additive unique tests |
| Python unittest discovery `tools/tests/test_*.py` | **46 PASS** |
| Repository/static checks | PASS |
| Godot4.7.2 development headless editor | PASS / exit0 |
| Tracked-repository-content sanitizer | PASS |
| Sanitized headless editor + canonical main120 frames | PASS / exit0 |
| Archived source-save current readers | Seven PASS / exit0 |
| Real desktop A/B/C, cold full equality and identity traversal | PASS as detailed above |
| Audit Markdown local links/trailing whitespace/`git diff --check` | PASS at closeout |

Focused dumpling is **488 in the current runner**, not the historical S4B489 count; no test was
removed or changed by this audit. Root canonical remains the authoritative total, not summed
slice reports. Raw local logs are under ignored `build/snow-final-audit/`; runtime evidence is
the tool transcript and the concrete observations/hashes above. Local evidence is not remotely
reproducible GitHub CI proof. No current milestone PR exists and no new CI success is asserted.

Sanitizer input was a copy of Git-tracked `game/` content, excluding existing ignored owner-local
Godot AI update backups. Direct-worktree sanitation is affected by those local backups; they
were preserved, not deleted/edited to obtain PASS. Python packaging unit fixtures are not real
Android/iOS package execution evidence. No full historical suite rerun after documentation only.

## PR SCOPE SUMMARY

Proposed future final PR: **Snow Town Core Hub Restoration**. Adds Work income/access, real
source currency/payment and physical Bank exchange, staged waiter dumpling/wineskin offers,
typed food/liquid use and embedded item persistence, eligible Player recovery/metabolism,
Waterfall supply access and north public spine. Preserves integrated source-valid public birth,
Snow↔Old Pine connection and exact source Save/Continue, extending their useful preparation loop.
It must not say this branch first introduces public Snow New Game or the existing connection.
Explicit non-goals are the deferred ledger above. This is preparation only, **no PR authorization**.

## FINAL PR READINESS CHECKLIST

- [x] Owner-approved S1–S7B scope and decision correspondence verified.
- [x] Full18-commit executable baseline diff accounted for; unexplained paths0.
- [x] Fresh complete canonical, focused, Python, static and headless checks pass.
- [x] Real A/B/C and separate-process exact Continue verified without gameplay injection.
- [x] Supported old saves and malformed-state boundaries checked.
- [x] Source/build/config unchanged; no production repair; owner-local backups preserved.
- [x] Current status corrected; historical evidence retained; final risk/omission ledgers explicit.
- [x] Audit candidate is docs-only; DECISIONS byte delta0.
- [ ] Owner authorizes final PR (not yet).
- [ ] Same-final-head four-job PR CI (not yet applicable).
- [ ] Owner merge authorization and post-main CI (not yet applicable).

## STOP STATE

**Final Snow Audit PASS — PR READY.** Implementation complete within approved bounded Core Hub;
not merged or fully integrated on main. Commit/push audit docs on the same phase branch, preserve
worktree/branches/local tooling, then await owner final-PR authorization. No next Snow slice,
Green/Goathill, Lake, Phase5B4, PR or merge started.
