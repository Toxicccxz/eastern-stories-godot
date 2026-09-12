# S4A — Snow Inn Supplies / Vendor / Consumables Source Contract

## EXECUTIVE RESULT

**Current status: OWNER APPROVED / CLOSED (analysis only).** Owner subsequently authorized
S3C Bank physical access before Vendor. The historical analysis below records the S4A baseline;
S3C resolves sequencing item K operationally, not recommendations A–J. S4B remains NOT AUTHORIZED.
See [S3C Bank access](PHASE_SNOW_TOWN_CORE_HUB_BANK_PHYSICAL_EXCHANGE.md).

S4A is analysis complete / awaiting owner review. S1/S2/S3A/S3B are OWNER APPROVED / CLOSED.
S4B and the final Snow PR remain NOT AUTHORIZED. No executable change accompanies this contract.

**SOURCE FACT:** Snow's ground-floor waiter sells four real, unlimited clone-on-demand offers:
dagger50, wineskin20, dumpling15, chicken leg30 (coin-value units). Quote precedes payment;
payment precedes cloning and delivery. Ordinary delivery failure is ignored by the Vendor,
which still announces purchase success. Neither Bank nor Workplace cleanup decisions cover this case.

**CURRENT NATIVE FACT / INFERENCE:** S3B supplies money authority, not an accessible Bank or a
shop. Workplace silver alone cannot buy any of these sub-100 offers: source affordability returns2
without adequate small change. Coins alone also fail the locked silver-presence branch. Thus a
complete normal-player income/supply loop still needs an owner-authorized denomination-access
path; do not grant coins, make change automatically or
advertise this loop as already playable.

**SOURCE FACT / CURRENT NATIVE FACT:** Dumpling is the smallest consumption candidate. Wine
requires the deferred drunk chain; chicken leg is also a hammer and becomes a persistent bone;
dagger needs its own weapon-action projection, not the current sword slash. Current item Save
does not encode portions, liquid contents or the bone variant. Source Inn upstairs is unnecessary
for ground-floor commerce. The birthday cake dependency is genuinely missing.

## EXACT BASELINE

- Repository: `Toxicccxz/eastern-stories-godot`.
- Branch: `phase/snow-town-core-hub`.
- Exact starting local and remote HEAD: `e7ef0cb26411fa5a39f72e50aa5176e2435fa09a`.
- Immediate predecessor: `85d57549fffdc8cb782e2373b4741048606787ef`
  (`Record owner-approved S3B finance decisions`).
- Local/origin and independently read GitHub main: `047f29083e881156abbdad6ed480bffc1350dfa8`.
- Initial worktree clean; GitHub open-PR lookup for this branch empty; Snow remains unmerged.
- Source-valid New Game Entry is the integrated baseline, not a new S4A implementation.

## AUTHORITY / SCOPE

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment,
interaction translation and presentation. This is source-faithful migration, not freeform redesign.

Type A = source-semantic migration (default). Type B = Native translation with observable
substitutions explicitly accounted for and owner-approved. Type C = new design, requiring separate
approval. Recommendations below are not decisions or implementation authorization.

Read root/docs AGENTS and current DECISIONS, STATUS, ROADMAP, Snow S1/S2/S3A/S3B documents and
relevant NGE Inn/final-audit records. Current Native authority is exact-HEAD code, then DECISIONS,
STATUS, ROADMAP, latest phase/audit, older phase documents, old proposals. Historical documents
are not proof of current missing/present functionality. `reference/es2/` governs source semantics.
Locked S3B A–H and birth/body decisions are not reopened.

## SOURCE COVERAGE

Paths in source sections below are relative to `reference/es2/mudlib/`. Required room, waiter,
Vendor/buy/finance, consumable, condition and item inheritance files were read completely; related
large character/daemon files were inspected at the setup, resource, action and lifecycle functions
used here. No running LPC driver is claimed.

| Area | Files actually inspected / scope |
| --- | --- |
| Snow physical/NPC | `d/snow/inn.c`, `inn_2f.c`, `guestroom.c`, `n_room.c`, `e_room.c`, `w_room.c`, `square.c`, `inneryard.c`; `d/snow/npc/waiter.c`, `traveller.c`, `rat.c` |
| Exact goods | `obj/example/dagger.c`, `wineskin.c`, `dumpling.c`, `chicken_leg.c`; exact `obj/example/cake.c` existence checked: absent |
| Commands / commerce | `cmds/std/buy.c`, `say.c`, `wield.c`; `feature/vendor.c`, `finance.c` |
| Item chains / consumption | `std/item.c`, `std/equip.c`, `std/weapon/dagger.c`, `hammer.c`; `feature/food.c`, `liquid.c`, `move.c`, `clean_up.c`, `dbase.c`, `name.c`, `equip.c`, `action.c`, `autoload.c` |
| Character / condition | `std/room.c`, `std/char.c`, `std/char/npc.c`; `feature/damage.c`, `condition.c`; `daemon/condition/drunk.c`; `adm/daemons/chard.c` setup/corpse, `adm/daemons/race/human.c`, `adm/daemons/weapond.c` action lookup and bash hook |
| Referenced loadout / headers | `obj/cloth.c`, `std/armor/cloth.c`, `obj/money/coin.c`, `std/money.c`; `include/weapon.h`, `dbase.h`, `name.h`, `room.h`, `condition.h`; globals inheritance macro lookup; `adm/simul_efun/object.c` destruct wrapper |
| Cake alternatives | `d/latemoon/obj/cake.c`, `d/latemoon/npc/obj/cake.c`, `d/city/npc/obj/cake.c`, `d/choyin/obj/cake.c`, `d/choyin/npc/obj/cake.c` |
| Runtime documentation / searches | `doc/efuns/call_other`, `doc/applies/init`; whole-mudlib searches for cake/蛋糕/生日快乐 and `receive_healing`; source searches for food/drink callbacks, Snow `resource/water`, condition/recovery dispatch |

Traveller/rat references establish population ownership, not authorization to migrate their
simulation. Traveller's cloth/coin chain is separate from waiter's empty authored loadout.
Greeting rank formatting is presentation, not a price or eligibility dependency.

## SNOW INN SOURCE TOPOLOGY

**SOURCE FACT — `d/snow/inn.c`, `std/room.c`:** 饮风客栈 has east→square,
up→inn_2f, northwest→wizard entrance with a closed wood door. Its object slots specify
traveller2 and waiter1; `setup()`/room reset own those spawns. `valid_startroom` is not a
Save eligibility rule. The commented board is not active content.

**SOURCE FACT:** `inn_2f.c` returns down→inn, has closed north/east/west guest-room doors
to `n_room/e_room/w_room`, and rat6. The three rooms return to the second floor.
Lodging/reputation wording does not implement a rental fee, rest command or supplies gate.
`guestroom.c` is instead 春风武馆's guestroom, connected north to `inneryard.c` (which exits
south to it), not an Inn upstairs dependency. Do not conflate its name with the Inn guest rooms.

## WAITER SOURCE CONTRACT

**SOURCE FACT — `d/snow/npc/waiter.c`, `std/char/npc.c`, `std/char.c`, human/chard setup:**

- 店小二; alias `waiter`; male; age22; combat_exp10000; dodge300; friendly; rank respect 小二哥.
- NPC plus F_VENDOR; no explicit weapon/armor/money carry calls. Towel in prose is not a loadout.
- Human defaults fill unspecified attributes with `10 + random(21)` per attribute, rather than
  the fresh Player's fixed30. Human maxima at age22 without relevant authored skills are
  gin220/kee220/sen100. Default body/capacity follow NPC setup; do not substitute PlayerBodyFacts.
- On interactive arrival while waiter is not fighting: inherited init, replace pending greeting,
  schedule greeting1 second later; greeting rechecks same environment and uses random(3) for text.
  `list` is registered as a local action. Greeting RNG/timing is not purchase randomness.
- No authored chat_chance/random_move configuration. Inherited contact/combat behavior still exists.
  Friendly accept_fight refusal is not invulnerability or a blanket prohibition on killing him;
  Inn has no authored no-fight flag. A permanently invulnerable shop terminal is not exact NPC parity.
- Room reset recreates a missing object slot; a surviving displaced character is asked to
  return home subject to inherited living/fighting checks. This is not per-purchase restocking.
- Birthday `relay_say` chain is separate from commerce; see missing-cake section.

**INFERENCE:** One persistent vendor identity/contact in the existing Inn suffices for an initial
commerce boundary. It does not require travellers, rats, upstairs or a general Snow population.
NPC combat, greeting and respawn omissions must be explicit staged coverage, not claims of full waiter parity.

## VENDOR OFFER TABLE

**SOURCE FACT:** all four exact files exist. `vendor_goods` values are paths, not prices or stock.

| Offer key | Source path | Exists? | Display name | Value/price | Type | Own weight | Purchase dependency | S4B candidate? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dagger | `/obj/example/dagger` | yes | 匕首 | 50 | DAGGER/EQUIP | 1000 | coin change; typed item + weapon/action projection | conditional, not definition-only full parity |
| wineskin | `/obj/example/wineskin` | yes | 牛皮酒袋 | 20 | ITEM + F_LIQUID | 700 | coin change; liquid state; drunk/lifecycle decisions | defer until complete dependencies approved |
| dumpling | `/obj/example/dumpling` | yes | 包子 | 15 | ITEM + F_FOOD | 80 | coin change; portions + item Save | smallest food candidate |
| chicken leg | `/obj/example/chicken_leg` | yes | 烤鸡腿 | 30 | HAMMER/EQUIP + F_FOOD | 350 | coin change; bone variant; hammer action/hooks | larger dependency, stage explicitly |

## ITEM SOURCE TABLE

**SOURCE FACT — exact goods plus their standard roots:**

| Item | Aliases / unit | Definition vs instance state | Inheritance and callbacks |
| --- | --- | --- | --- |
| dagger | `dagger` / 把 | steel; base value50; weight1000; damage4; flag EDGED\|SECONDARY; skill dagger | DAGGER→EQUIP→ITEM+F_EQUIP; WEAPON_D actions slice/pierce/thrust; no item-specific hit/post callback |
| wineskin | `wineskin`, `skin` / 个 | value20; max_liquid15; per-clone liquid `{type:alcohol, name:红酒, remaining:15, drunk_apply:6}` | ITEM + F_LIQUID; drink/fill, no authored drink_func |
| dumpling | `dumpling` / 个 | value15 initially, becomes0 on first accepted bite; remaining3; supply60 | ITEM + F_FOOD; no authored/inherited finish_eat implementation in this item chain |
| chicken leg | `chicken leg`, `chicken`, `leg` / 根 | value30→0; remaining4; supply40; bone material; damage1; flag0; skill hammer | HAMMER→EQUIP + F_FOOD; bash/crush/slam; custom finish_eat keeps and renames the same object if weapon_prop is truthy |

ITEM composes F_CLEAN_UP/F_DBASE/F_MOVE/F_NAME. EQUIP adds F_EQUIP. `std/equip.c::setup`
weight-based dodge penalties start at3000, so neither Inn weapon receives that penalty.
None of these offers inherits COMBINED_ITEM. One purchased food with portions is not a stack
of independent foods. Do not store portions in CombinedStack.amount.

## PRICE AUTHORITY

**SOURCE FACT — `feature/vendor.c::buy_object/get_vendor_list`, item create methods:**
lookup path→call `query("value")` on the source/prototype object. Values50/20/15/30 are positive
authored fields, not `value()` money totals, a Vendor markup, inherited zero or Native prices.
List presentation uses the same prototype values. Consumed clone value0 does not alter the
untouched prototype's next quote. `set_default_object` supplies shared defaults while clone
mutations shadow them (`feature/dbase.c`). No offer uses a computed price function here.

## BUY COMMAND ORDER

**SOURCE FACT — `cmds/std/buy.c` and `feature/vendor.c`:**

1. Parse `item from target`; malformed/missing argument refuses.
2. `present(target, environment(me))`: direct local target; absent refuses.
3. If target is a user object, only announce a purchase request and return1; no transaction.
4. Install default refusal text; call target.buy_object→path/prototype price. Price<1 returns0.
5. Call can_afford. Result0 refuses insufficient total; result2 refuses insufficient change.
6. For result1 call `pay_money(price, 0)`, then `compelete_trade`, then return1.
7. Completion rereads offer path, `new(path)`, `move(me)` ignoring its return, then purchase text.

No explicit busy, ghost, awake, fighting or vendor-living check in this command. Physical target
selection is not recursive/root-owned lookup. There is no quantity argument, negotiation or auto-use.
`buy.c` does not inspect pay_money's return: its insufficient-total return0 would not itself stop
completion if reached. With unchanged synchronous ordinary offers, can_afford1 precedes that call;
the relevant partial-payment terminal path is a thrown error, which prevents subsequent cloning.
Do not generalize to arbitrary mutating quote callbacks or assume a modern rollback transaction.

## S3B FINANCE DEPENDENCY

**CURRENT NATIVE FACT — `game/application/finance/money_payment_service.gd`,
`money_payment_result.gd`, `money_inventory_context.gd`; `game/core/finance/source_affordability.gd`:**
reuse direct Player selections, exact can_afford0/1/2, ordered gold→silver→coin payment,
typed stage/residual/mutation results, partial debits retained, immediate full-depletion lifecycle
and checked integer failures. A future caller may create goods only after successful payment;
typed terminal failure is the S3B replacement for the source throw, not an implicit refund.

Reuse `SourceCurrencyDefinitions` (coin/silver/gold), existing Inventory/Combined/Index,
SessionItemIdAllocator, ItemInstance, transfer and lifecycle authorities. The borrowed finance
context is not a wallet, new balance or inventory owner. Product creation is not Bank conversion.
Do not add rollback or a generic transaction engine.

**NOT DECIDED:** purchased-goods failure/cleanup/refund/compensation, product stock and free gifts.
S3B Bank C and S2 reward cleanup have different ordered operations and bounded authorization.

**INFERENCE:** Fresh Player has no money. Work gives silver only; all four prices require coins.
S3B's Bank service currently has no physical/UI access. A normal-player purchase demonstration
therefore needs a separately approved access boundary, or explicitly labelled QA coin setup
which proves purchasing but not the complete earned-money loop. No automatic change shortcut.

**SOURCE FACT / CURRENT NATIVE FACT:** this is not merely an exact-change solver. For these
prices, `amount % 10000 != 0`, so **absence of a silver object returns2 even if coins alone
cover the full price**. Price15 with coin100 only returns2; silver1 plus coin15 returns1 and
payment removes coin15 without debiting silver. With immediate full-depletion cleanup, converting
the only silver into coins does not solve this: no silver object remains. Retaining silver while
exchanging another silver can satisfy the gate. Any future QA setup must supply the actual
required presence as well as coin value. This already-locked S3B anomaly must not be repaired
inside Vendor or hidden by a total-balance label.

## PRODUCT CREATION ORDER

**SOURCE FACT:** An invalid source path can fail already during prototype quote/list lookup,
before payment. Separate that from `new(path)` failing after payment completed. The latter has no
catch or compensation before the success message. Constructor errors/partial objects depend on
the LPC driver; no reliable orphan count is implied for a failed constructor. The four offer files
are present; a post-payment clone failure is a configuration/runtime failure case, not evidence
that any of these four currently always fails.

## PRODUCT DELIVERY ORDER

**SOURCE FACT — `feature/move.c`:** equipped marker/unequip→resolve destination→capacity check
unless destination is already an ancestor→old-parent weight removal→move_object→new-parent
weight addition→interactive mover presentation→return1. These newly cloned products are not
equipped and have no parent; the ancestor exception does not bypass capacity.

Check current post-payment inventory encumbrance plus the product's full weight, not weight1
or final food portion count. Capacity equality is allowed; only `>` rejects. Moving ordinary
products does not merge. Product init registers use actions, not a custom fulfillment callback.
Payment depletion timing follows already-approved S3B, including its capacity consequences.

## PRODUCT DELIVERY FAILURE

**SOURCE FACT / CURRENT NATIVE FACT:** the table distinguishes executable branches from
unproven driver failures. No four-offer post-move merge hook was found.

| Stage | Payment already mutated? | Object created? | Player receives item? | Source result | Cleanup owner | Native mismatch | Owner decision? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Parse/target/price<1/afford0 or2 | no | no clone | no | refusal; user-target request is separate return1 | none | existing typed refusal fits | no new money decision |
| Prototype path load/query failure | no | no purchased clone; possible prototype load | no | error before pay; no success text | driver loading | production lookup/config validation | B, distinct pre-pay case |
| pay_money terminal error | possibly partial debits | no | no | abort before completion; debits survive | existing money path | S3B typed terminal failure | already locked, not reopened |
| post-payment new/constructor error | completed payment | uncertain on constructor error | no completed delivery | abort before success text; no refund code | driver/error cleanup, not Vendor | typed creation failure/consumed allocation | B |
| ordinary product move returns0 (capacity) | completed payment | yes | no; still parentless | ignores0, announces success, buy returns1 | later F_CLEAN_UP opportunity | no Native ambient LPC collector; ownerless graph may persist | A + C |
| invalid destination returned failure | completed payment | yes | no | same ignored-return sequence if it returns normally | later F_CLEAN_UP | stale Player/context is authority failure, not normal capacity | distinguish from A |
| successful ordinary move | completed payment | yes | yes, direct inventory | message then return1 | normal item lifecycle | straightforward ordered result | no refund/auto-equip |

F_CLEAN_UP retains contained/interactively protected objects, destroys eligible parentless
objects when invoked. There is no Vendor cleanup timer or known exact deadline. A failed item
is not placed on the Inn floor. Containment unchanged does not mean the purchase was atomic:
payment has already changed. Runtime errors inside move/init are not equivalent to a returned0;
there is no evidence of an additional authored merge/side-effect failure in these four items.

## VENDOR STOCK / CLONING

**SOURCE FACT:** static source-path mapping; each purchase clones a fresh object. No stock
counter, carried merchandise, reservation, sale ledger, NPC money credit, decrement, retry,
refund or explicit failed-goods destruction. Room reset concerns NPC presence, not supplies.
Unlimited availability while the relevant Vendor is accessible is Type A, not invented generosity.

## FOOD CONTRACT

**SOURCE FACT — `feature/food.c`:** id match→ghost refusal→busy refusal→zero remaining refusal
→food already at/above capacity refusal→if drink_func, water already at/above capacity refusal
→add full food_supply→optional water_supply→if fighting start_busy2→set instance value0
→decrement remaining→if now0 final text and finish_eat; destroy if falsy→otherwise bite text→return1.
The eat_func customization code is commented out. Neither Inn food has drink_func/water_supply.
No resource healing, XP, skills, RNG or outside-combat busy is added by eating.

## WATER / DRINK CONTRACT

**SOURCE FACT — `feature/liquid.c`, wineskin:** id→ghost→busy→zero remaining→already full water
checks, all before mutation. Then decrement liquid first→drink text→water+=30→if fighting busy2
→empty text if now0→optional liquid/drink_func early return→alcohol condition addition→return1.
Wine adds no food. Fifteen initial portions; empty skin survives, remains weight700/value20.

Fill is a separate action: id/busy then current room resource/water required; discard/fill text,
combat busy2, type water/name清水/remaining=max_liquid/drink_func0. No ghost check in fill.
drunk_apply6 remains stored but water type does not apply alcohol. Snow source search finds no
resource/water supply; neither Inn prose nor a wine container establishes free drinking water.
Refill/world water access is outside this proposed first commerce boundary.

## ALCOHOL / INTOXICATION CONTRACT

**SOURCE FACT — `daemon/condition/drunk.c`:** each accepted wine drink replaces drunk duration
with old+6 via condition state; no direct immediate healing/damage. On a later condition update,
let `L = (con + max_force / 50) * 2` with LPC integer division, using base con and max_force.

| Ordered branch | Source mutation / continuation |
| --- | --- |
| duration>L and living | unconcious(); return0, so current condition is removed; no duration decrement |
| otherwise not living | drunken text; then common decrement/return |
| otherwise duration>L/2 | current sen receive_damage10; then common decrement/return |
| otherwise duration>L/4 | current sen receive_damage3, then receive_healing gin10, then kee15; then common tail if execution continues |
| otherwise | no resource effect; common tail |

Common tail writes duration-1, then tests OLD duration:0 returns0/removes, any other value returns1.
Old1 therefore stores0 and continues one more opportunity; negative values keep decrementing.
Return1 is CND_CONTINUE, not CND_NO_HEAL_UP. Multiple conditions aggregate flags in F_CONDITION;
drunk does not own scheduling or independently forbid recovery.

`std/char.c` services busy and returns before its longer update tick; that tick resets to
`5 + random(10)`, updates conditions, then calls heal_up unless the aggregated no-heal flag
short-circuits it. Thus condition frequency is not one drink/one update or a fixed seconds promise.
The condition dispatcher catches daemon-load failures but not handler execution errors. These
dependencies belong to a future Native opportunity/lifecycle contract, not an emulated heartbeat.

**SOURCE FACT — BROKEN/AMBIGUOUS API:** whole-mudlib search finds `receive_healing` only in
these two drunk calls; `feature/damage.c` implements `receive_heal`, not that name. Do not
silently change it to healing10/15. Whether missing external calls return zero/no-op or raise
on the relevant driver is not established by a running LPC test here; either way successful
healing is unsupported. If it raises, prior sen damage remains and the common tail is not reached.

With con30/max_force0, L60:16..30 enters the defective branch,31..60 damages sen10,
61+ while living calls unconsciousness. Repeated drinks can produce6/12/18, but intervening
condition updates and the water gate matter; this is not a promised three-drink runtime schedule.
Unconsciousness also removes enemies, zeros gin/kee/sen, disables interaction, may award a prior
attacker, and schedules revive `random(100-con)+30` (`feature/damage.c`). It can trigger from
drunk duration with otherwise positive resources. This is not just a cosmetic status icon.

**CURRENT NATIVE FACT:** `game/core/conditions/condition_system.gd` registers only snake_poison
and bandaged. DRUNK duration is a typed known state/Save shape, but has no handler; unknown
handlers are retained/skipped, not treated as successful drunk effects. Phase2B explicitly deferred
this defect/lifecycle. `CombatSliceLifecycleAdapter` accepts combat opportunity results, not an
arbitrary drunk duration; its existence does not complete drunk wake scheduling/Save. No general
world-active recovery/condition scheduler was found in the inspected production runtime callers.

## CONSUMPTION ORDER

**SOURCE FACT**, using the detailed food/drink order above:

| Item | Food delta | Water delta | Alcohol/effect | Precondition | Mutation order | Consumed on success? | Consumed on refusal? | Timer/RNG? | Save consequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| dumpling | +60 | 0 | no primary-resource healing | id, not ghost/busy, remaining!=0, food<cap | food→combat busy→value0→portion-1→finish/destruct branch | one of3 portions; terminal destruction branch | no; unchanged | none in eating | remaining/value; final removal/index/weight |
| chicken leg | +40 | 0 | final bone mutation if weapon_prop | same food gates | food→combat busy→value0→portion-1→finish callback | one of4 portions; object normally survives as bone | no | none in eating; weapon use is separate RNG/hooks | remaining/value/variant/weight150, same ID and equipment reference |
| wineskin/red wine | 0 | +30 | drunk old+6 | id, not ghost/busy, remaining!=0, water<cap | portion-1→text→water→combat busy→empty text→condition | one of15 portions; empty skin survives | no, including no drunk addition | drink itself none; later drunk/unconscious chain has update/timer/RNG | liquid type/name/remaining/effect configuration; duration; deferred lifecycle |

No explicit direct-ownership check exists in eat/drink themselves. Per item init and bundled
`doc/applies/init`, objects in the same room can expose their actions as well as carried objects;
nested contents are not thereby a recursive-use API. Native direct-inventory-only use, or a
blanket combat-use prohibition, would be observable Type B restrictions requiring accounting.
No new unrestricted action dispatcher or command-string interpreter is justified.

## RESOURCE CAPACITY / SATURATION

**SOURCE FACT — `feature/damage.c::max_food_capacity/max_water_capacity`, `feature/move.c`:**
each capacity is own `query_weight()/200`, not inventory-inclusive `weight()` or carry capacity.
Native `CharacterRecovery.maximum_food_capacity/maximum_water_capacity` already implements it.
Player body80000 gives400 each; maximum carry150000 is an independent fact.

- At food400 or greater, either food refuses before value/portion/resource mutation.
- At water400 or greater, wine refuses before decrement/water/drunk mutation; food fullness is irrelevant.
- Food399 + dumpling60 =459; food360→420; food340→400. Chicken food399→439.
- Water399 + wine30 =429; water370→400; next drink refuses. No fractional portion or clamp.
- A food with truthy drink_func would require BOTH resources below their caps before adding
  full amounts; if either gate fails neither resource changes. This generic branch is not an Inn offer.
- Negative nonzero portion values pass the truthiness test and decrement further. Those malformed
  legacy states are not authored fresh goods; do not confuse a Native validation rejection with
  source normalization. Out-of-range arithmetic validation must fail explicitly, not change formulas.

**CURRENT NATIVE FACT:** `CharacterRecoveryState.food/water` are existing typed integer authority;
use them, not a second hunger meter. Fresh post-body fill is a birth-only owner decision.
Later strength changes do not rebuild PlayerBodyFacts or refill supplies. `heal_up` consumes
food/water under its separate recovery rules; consumption does not call it or regenerate gin/kee/sen.
Recovery scheduling/metabolism remains a later slice.

**CURRENT NATIVE FACT / INFERENCE:** fresh food/water400 already refuses eating/drinking.
Work spends gin/sen, not food/water. With no world-active recovery/metabolism, buying food does
not itself open a source-valid consumption opportunity or enable another Work action. A focused
use test may disclose QA setup below capacity; it must not be reported as a completed natural
early-game replenishment loop. Do not lower birth supplies or consume them on walking to make
an acceptance path possible without separate authorization.

## CONSUMABLE LIFECYCLE

**SOURCE FACT:** final food portion calls finish_eat before optional immediate destruct.
Dumpling defines no finish_eat; the source's default/falsy-callback destruction path is its intended
terminal path, not a delayed Combined zero-amount timer. The absent-method driver convention is
not independently executed here; do not claim a driver test. Chicken's explicit finish_eat is unambiguous:
truthy weapon_prop→rename 啃得精光的鸡腿骨头, alias only bone, own weight150, change long, return1.
It keeps same identity, unit根, value0, remaining0, damage1/hammer and existing equipment marker.
Absent weapon_prop returns0, selecting destruction instead (relevant to a broken weapon).

`adm/simul_efun/object.c::destruct` calls remove first; `feature/move.c::remove` attempts unequip,
removes own weight from the parent and updates prototype retention before efun destruction.
For the normally surviving chicken, set_weight propagates -200 to its current parent; no
new bone allocation or automatic unwield occurs. Wine never destroys its empty container and
does not reduce weight with liquid portions. There is no freshness/decay timer on these foods.

**INFERENCE:** existing ItemLifecycle/transfer/index/equipment authorities should be reused for
terminal deletion, with a narrow typed consumable state. Neither a generic payload Dictionary
nor a new item persistence owner is justified. Bone is an instance variant, not a new semantic ID.

## FREE CAKE / MISSING SOURCE ANALYSIS

**SOURCE FACT — BROKEN/MISSING AUTHORED DEPENDENCY:** full-mudlib cake/蛋糕/生日快乐 scan and
exact path check confirm `obj/example/cake.c` absent. Waiter relay_say matches ES2 or es2 plus
生日快乐, executes jump/say text, and if `present("cake", ob)` is absent attempts new of that
missing path, move to speaker, then gift text. `cmds/std/say.c` relays to local inventory objects.
No date/calendar/account-birthday check, payment or once-per-account flag exists. Direct cake
possession is the local guard, not a persistent gift entitlement. Successful cake creation is unproven.

**POSSIBLE SUBSTITUTE — OWNER DECISION REQUIRED:** latemoon's two cake files are 雪花糕,
value50/weight1000/5×food80; city NPC cake is value300/weight1000/5×80; choyin's two cakes are
大饼,value25/weight130/5×60. Same alias does not prove the absent birthday object's identity,
price or effect. No source-valid replacement can be selected merely by filename. Recommend
deferring this broken gift rather than inventing free supplies. No other free Inn food path was
established by the source scan. This is not authorization to create a cake or a new free-water source.

## DAGGER / WEAPON ANALYSIS

**SOURCE FACT:** `/obj/example/dagger` is a real offered weapon, damage4/skill dagger,
EDGED|SECONDARY (6), single-handed; `cmds/std/wield.c` requires direct inventory and not already
equipped. F_EQUIP requires character environment and weapon_prop; empty primary uses primary,
otherwise free secondary/no shield permits this secondary-capable item. No dagger-specific
attribute/skill threshold. Existing hand/weapon/shield state decides remaining cases. Buying only
delivers; no equip call. Source verbs are three randomly selected WEAPON_D actions:
slice(砍伤,dodge20), pierce(刺伤,dodge-30/parry-30), thrust(刺伤,dodge15/parry-15).
These are source action fields, not permission to change already-audited Combat math.

**CURRENT NATIVE FACT:** WeaponDefinition can describe skill/secondary/identity; equipment,
weight and item Save foundations can carry an ordinary dagger once explicitly registered.
But `game/runtime/world/oldpine_weapon_content_resolver.gd` recognizes long/short sword only;
`game/runtime/combat_slice/combat_slice_content_profile.gd` returns slash for a weapon. Registering
dagger and reusing slash would silently approximate its actions/damage types/RNG distribution.
Minimum complete support requires explicit verified action/content projection in addition to
definition, restore lookup and inspection/wield resolution. Do not start new combat design.

Chicken is more costly: HAMMER's bash/crush/slam all reference `weapond::bash_weapon`, whose
parry branch uses RNG/weights/strength/rigidity and can disarm or break the opponent weapon.
Breaking sets weapon_prop0 and changes value/name, which affects final food destruction if that
weapon is a chicken leg. Treating chicken as food-only or bone as trash is an observable omission.
Recommend staging it instead of slipping weapon-break/variant persistence into a small supply slice.

## CURRENT NATIVE FIT

**CURRENT NATIVE FACT**, paths relative to `game/`:

| Authority inspected | Reuse / gap |
| --- | --- |
| `application/finance/money_payment_service.gd`, `money_payment_result.gd`, `money_inventory_context.gd`; `data/items/source_currency_definitions.gd` | ordered money selection/payment; no goods orchestration or accessible Bank |
| `core/characters/character_recovery_state.gd`, `character_recovery.gd`, `player_body_facts.gd`; `application/new_game/` composition | one food/water authority, own-body capacity; birth only fill; no eating service |
| `core/conditions/condition_system.gd`; Phase2B record | typed duration storage, two active handlers; no drunk implementation or general scheduler |
| `core/persistence/native_item_state_snapshot.gd`, `native_item_record.gd` | embedded v1 identity/parent/own weight, stacks, equipment/armor; no portions/liquid/value/bone variant |
| `core/persistence/game_save_snapshot_validator.gd`; save value/codec and runtime capture | food/water and known drunk duration can serialize; storing duration does not execute intoxication |
| `data/oldpine/oldpine_native_item_definition_projections.gd`, `oldpine_item_content_definitions.gd`; weapon resolver | existing fixed item/restore/content registration, no four Inn goods |
| `runtime/persistence/oldpine_world_restore_composition.gd`, `oldpine_save_eligibility.gd` | exact authored Old Pine NPC slots/character aggregates; not a generic new Snow waiter restore path |
| `runtime/combat_slice/combat_slice_lifecycle_adapter.gd` | existing combat unconscious/death composition; no general drunk revive contract |

Production searches did not find an existing consumable use service to extend. Reuse the
single item graph, derived WorldItemInstanceIndex, allocator and character-owned equipment/armor;
do not create Vendor-owned copies, a wallet, a second resource state or parallel save collection.

## INN PHYSICAL REUSE

**CURRENT NATIVE FACT — `game/data/snow/snow_world_definitions.gd`,
`game/runtime/world/snow_inn_controller.gd`, `game/scenes/world/snow/snow_inn.tscn`:**
existing resident map `snow.inn`, zone `snow.inn.main_floor`, region snow is a continuous960×600
interior with physical walls, source birth spawn and east portal to `snow.outdoor`/Square.
Square's west entry returns to it. Source traveller/waiter counts are metadata, not spawned actors.
Shared resident Session/Player authority already exists; don't create a second Inn Session.

**INFERENCE:** One future contact/NPC placement and commerce interaction in this floor is enough;
no new room, upstairs, guestroom, portal or town population is needed. Waiter persistence and
interaction authorization still need an explicit boundary; geometry reuse alone doesn't solve them.

## SAVE / REVISION IMPACT

**CURRENT NATIVE FACT:** root schema2 / SOURCE_ENTRY_V1 and embedded NativeItemStateSnapshot v1
remain unchanged. Development pre-cutover saves have no long-term compatibility promise. S3B's
same-schema success is not proof every new consumable/NPC fits the existing format.

| Settled state / boundary | Current representability and required work |
| --- | --- |
| affordability refusal | unchanged existing snapshot; ordinary Save eligibility still required |
| terminal payment failure before goods | valid settled partial money graph/allocator can persist under S3B; authority-corrupt/incomplete graphs must fail Save, not normalize/refund |
| pay + deliver ordinary dagger | IDs/parent/weight/equipment and allocator fit existing item shape after explicit content/weapon registration; no auto-equip |
| pay + failed delivery | money loss fits; parentless item can be captured by current item authority, so cleanup/retention choice must be explicit; do not silently orphan-persist or refund |
| purchased/part-eaten food | character food fits; portions/value and chicken variant do NOT fit current item records; don't restore every food as fresh |
| final dumpling removal | removal/weight/index/allocator fit settled graph; partial-food lifecycle still needs typed state and validation |
| chicken bone | same ID/own weight representable, but alias/name/value/variant/weapon-state continuation not currently encoded |
| wine/empty skin | water fits; liquid remaining/type and empty status absent from current item records; weight cannot encode remaining |
| drunk duration | known duration shape serializes; missing handler/opportunity semantics and revive timer not solved by that shape |
| waiter | current exact OldPineSpawnDefinitions ledger, expected character Equipment/Armor aggregates and map/definition validation exclude a new Snow spawn; capture/restore must explicitly evolve |
| Vendor stock | none in source; static offers are content, not finite-stock save state |

**CURRENT NATIVE FACT:** Save eligibility requires a ready stable session/map and no active
encounter, operation/handoff, pending aggression/lifecycle/cadence/corpse work; character busy and
relationship guards apply. It does not reject a merely stored drunk duration as such. Do not use
that acceptance as proof timed intoxication is restart-stable. New use in combat (busy2) cannot
be declared immediately saveable. A transient operation/error is not a new legal checkpoint.

**OWNER DECISION REQUIRED:** approve explicit typed item-state extension and content/old-save
policy before full consumables or waiter. Root schema2 is not necessarily impossible to extend,
but its current codec cannot represent these states unchanged. Select embedded/root versioning
and SOURCE_ENTRY_V1 compatibility only with an explicit contract; no schema3 or SOURCE_ENTRY_V2
is invented here. Missing NPC slots cannot be silently bootstrapped into an old save. Deferred
timer state cannot be replaced with an implicit reset, permanent drunkenness or automatic recovery.

## SOURCE ANOMALIES

**SOURCE FACT / AMBIGUITY:** distinguish the following, rather than silently repairing them:

- Missing birthday cake is an active broken authored dependency, not a commented offer.
- `receive_healing` is absent; desired healing and missing-method driver behavior are separate questions.
- Vendor ignores move0 and reports success after payment: executable non-atomic behavior, not rollback.
- Prototype quote can fail before payment; a later clone failure is a different stage.
- Food/water overshoot, old-duration-zero expiry, negative truthy portions/durations and constant
  wineskin weight/value are literal semantics, not bugs to clamp away.
- Chicken is both edible and weapon; final same-object bone mutation is authored behavior.
- F_FOOD calls an absent default finish_eat on dumpling; destruction is the falsy-return branch.
  Source relies on optional external-method conventions; no LPC runtime proof is fabricated.
- Room-init actions may allow nearby ground consumption; direct inventory-only Native UX changes reachability.

## OWNER DECISIONS REQUIRED

Every row below is **OWNER DECISION REQUIRED**; recommendations remain unlocked. A/B/C here
denote migration types, not the previously locked S3B decision letters.

| Decision | Source / Native mismatch; options and classification | Save consequence / recommendation (not approval) |
| --- | --- | --- |
| A — paid ordinary capacity failure | Source retains payment and transient parentless goods for later cleanup (Type A semantics, needs Native lifetime adapter). Immediate ItemLifecycle cleanup with payment retained is Type B timing substitution. Preflight reject, refund/compensation or ground drop change losses/availability and are Type C economy changes, not infrastructure-only fixes. | Recommend immediate lifecycle + retained payment/consumed allocation, typed failed delivery, ONLY with new Vendor-specific approval. No Bank C/S2 inheritance. Neither no-orphan persistence nor refund is automatic. |
| B — creation/definition failure | Quote definition resolution before pay is Type A to source prototype lookup. Treat missing required production content as explicit configuration error, no sale; do not make up a price. A genuine post-pay creation failure retains completed payment (Type A loss semantics) and any consumed allocator ID. Moving all possible creation/admission checks before pay changes failure timing (Type B if bounded configuration handling, not capacity preflight); refund is Type C. | Recommend validate static offer definitions as content integrity and quote before pay; retain typed post-pay failure, do not pretend delivered. Partial construction cleanup requires explicit scope; don't roll back allocation/payment. |
| C — failure presentation | Literal success text despite delivery0 is Type A. Honest `paid=true, delivered=false` and suppressed success text is observable Type B, not altered money math. | Recommend explicit failure with ordered result. No fake received item or silent success; document owner approval separately. |
| D — stock | Unlimited source mapping/clones Type A; finite stock/restock/limits Type C. | Recommend unlimited; no stock Save or NPC inventory of merchandise. |
| E — missing cake | Keep broken failure (Type A observable defect, undesirable runtime authority error); explicitly defer gift (Type B staged coverage); substitute another cake/create a recipe Type C without original identity/effect evidence. | Recommend defer broken gift, no replacement/free item. No gift entitlement Save invented. |
| F — wine/drunk | Literal absent healing + duration/lifecycle branches require proven driver semantics (Type A); replacing name with receive_heal is an observable Type B compatibility repair, not already approved; water-only wine/no intoxication is Type C effect removal. Native update cadence/revive scheduling needs its own Type B contract. | Recommend defer playable wine until API-defect decision, condition opportunity/lifecycle and restart-stable temporary state are covered. Duration storage alone is insufficient. |
| G — use interaction reachability | Direct-inventory-only use omits source nearby-ground actions (Type B). Out-of-combat-only use omits source fighting busy2 branch (Type B restriction). Exact source reachability/busy rule is Type A but needs current interaction/encounter composition. | Recommend a clearly approved initial interaction restriction if broad combat/world use is excluded; don't label it full parity. No new arbitrary cooldown or resource clamp. |
| H — partial items / waiter continuation | Current item fields cannot store portions/liquid/variant; exact NPC ledger lacks waiter. Typed persistence extension preserving effects is Type B architecture; resetting portions/respawning waiter on Continue loses state and is not an acceptable silent substitution. | Recommend agree typed extension and development-save cutoff/compatibility before production. Do not assume schema2/V1 unchanged means compatible. |
| I — weapon coverage | Dagger needs source action selection; chicken adds hammer post-actions and same-ID bone. Literal content mapping is Type A; stripping weapon use/using slash/destroying bone changes observable behavior (Type B omission or Type C redesign, must be explicit). | Recommend stage these offers until supported; do not broaden a small food slice into unreviewed Combat/weapon-break work. |
| J — waiter embodiment | One source NPC with actual setup/life/placement and inherited combat/reset is Type A with Native adapters. A commerce-only invulnerable/static terminal omits behavior (Type B staged representation, not a full waiter). | Recommend one explicitly scoped contact, no general population, with persistence/omissions approved; no reroll/respawn on Continue. |
| K — denomination access | Work silver plus can_afford2 is source-valid; coins alone also fail the locked silver-presence branch. Bank physical access is absent; automatically changing silver for purchases or gifting initial coins changes existing rules (Type C). | Recommend owner sequence a narrow source-backed Bank access task separately, or explicitly limit first Vendor proof to QA-supplied silver plus coin; the latter is not full supply-loop acceptance. |

No decision is needed to invent clamping, healing food, portion-based weight loss, delayed final
food destruction or finite stock: those are not default source translations. Exact food deltas,
refusal-before-mutation and immediate destruction branch should remain Type A. Optional-method
uncertainty must be resolved/documented before claiming literal dumpling driver parity, without
inventing a custom finish_eat effect.

## PROPOSED S4B BOUNDARY

**INFERENCE / PROPOSAL ONLY:** the four-offer/full-consumption sketch is too large to treat as
just an Inn UI. Recommend owner first settle A–E and interaction/persistence/denomination scope,
then authorize a bounded waiter-contact + quote/afford/pay/create/deliver + **dumpling** slice in
the existing Inn, including typed portions/value continuation and honest failure presentation.
Make omitted existing offers explicit pending content, not missing-file claims or replacement goods.

Dagger can be separately included if its narrow source action projection/resolver/Save validation
is explicitly in scope; generic WeaponDefinition alone is insufficient. Chicken and playable wine
should wait for their respective weapon-variant and drunk/lifecycle contracts, unless the owner
explicitly expands the slice after reviewing these dependencies. No free cake implementation.

Focused future checks should prove literal price/denomination refusals, ordered payment and goods
failures, fresh clone identity, weight/capacity after payment, saturation overshoot, terminal food
lifecycle, partial-portion cold Continue and same waiter/allocator identities. Physical evidence
must use real Inn navigation/UI/use/Save/fresh process, with any QA money and below-capacity
food/water setup disclosed. An earned-money
path is not complete until genuine denomination access exists. No recovery scheduler is smuggled in
to create hunger, thirst or repeated work eligibility for the test.

## OUT OF SCOPE

No S4B implementation, production/test/scene edits, shop service/UI, waiter population, food/drink
service, alcohol runtime, dagger content, new Inn rooms, recovery/metabolism/heartbeat, Bank world
content, paper money, smith/herbalist/hockshop, school/bamboo sword/apprenticeship/teaching,
temple/revive/postoffice, Lake or Phase5B4. No provisional DECISIONS changes, final PR or merge.

## VERIFICATION / EVIDENCE

This slice's evidence is source inspection and exact-HEAD Native dependency analysis, not a new
gameplay test run. Source branches/formulas were independently re-read rather than inferred from
S1 summaries. Remote baseline refs and empty open-PR result were independently queried.

Docs-only verification PASS: repository static checks, 68 local Markdown targets, changed-doc
trailing whitespace and `git diff --check`; exact four-doc allowlist compared against starting
HEAD. Production/tests/scenes/reference/schema/build/CI/DECISIONS have zero delta. S3B receives
only a current status annotation; its implementation/evidence body remains historical. No Godot,
live game, sanitizer or complete gameplay suite is required for this non-runtime slice. In particular
S3B's18,620 assertions are not S4A evidence. The commit/owner report records final check outcomes.

## STOP STATE

S3B: OWNER APPROVED / CLOSED. S4A: ANALYSIS COMPLETE — AWAIT OWNER REVIEW.
S4B: NOT AUTHORIZED. Snow final PR: NOT AUTHORIZED / NONE. Snow: UNMERGED.
All proposed S4A substitutions remain OWNER DECISION REQUIRED. Stop after docs commit/push on
the same phase branch; no next-slice work, branch/worktree deletion or owner-local tooling changes.
