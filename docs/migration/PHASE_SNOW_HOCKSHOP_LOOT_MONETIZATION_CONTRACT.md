# Snow Hockshop / Loot Monetization — H1 Source Contract

## EXECUTIVE RESULT

**H1 ANALYSIS IN REVIEW. No implementation or owner decisions are recorded here.**

Restoring the executable Hockshop is a justified, bounded next milestone: currently obtainable
short swords, long swords and leather have unused resale values, and existing physical money,
Bank, supplies, recovery, corpse loot and exact item identity already supply the other links.
No combat redesign, merchant NPC, stock, account, custody or auction system is required.

Recommended product: front Hockshop interior in the existing Snow outdoor resident, a local
physical door, room/proximity-scoped exact-instance appraisal and irreversible sell. Defer pawn
unless owner explicitly selects its irreversible 60% result with truthful no-ticket wording.
Recommend **two implementation slices**, then a distinct final audit, on this one milestone branch.

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment,
interaction translation and presentation. Type A = source semantics; Type B = explicit Native
translation/staged restriction; Type C = new design requiring owner approval. No H1 recommendation
supersedes an existing decision merely by appearing in this document.

## EXACT BASELINE

- Repository: `Toxicccxz/eastern-stories-godot`.
- Inspected code / exact new-branch base: `112f3208937c9f5a480b9f27588af811599937ac`.
- Branch: `phase/snow-hockshop-loot-monetization`, newly created from that commit.
- Before creation: local main and remote main matched; index/worktree clean; target branch absent
  locally/remotely; GitHub open-PR listing empty. Previous branches/worktrees/backups retained.
- H1 changes only this document, STATUS and ROADMAP. No source, production, tests, configuration,
  Save implementation, DECISIONS, PR or runtime changes are authorized.

## PRIOR SNOW INTEGRATION CLOSEOUT

[PR #16 — Snow Town Core Hub Restoration](https://github.com/Toxicccxz/eastern-stories-godot/pull/16)
merged normally at the baseline above, parents `047f29083e881156abbdad6ed480bffc1350dfa8` and
`8f33739e19542f04ff42a4dc0c1ee95f4d5d73ad`, at `2026-09-14T04:43:26Z`.
[Post-main workflow 34807091663](https://github.com/Toxicccxz/eastern-stories-godot/actions/runs/34807091663)
is `push/main`, completed/success on that exact merge SHA: Godot Verify `103860993116`, Windows
`103862007707`, Android `103862007764`, iOS `103862007799`. These are GitHub-verifiable integration
results. The Final Snow Audit's canonical19,410/focused1,666/Python46 and real journeys remain
reported local evidence; they were not rerun for H1. S1–S7B and the bounded Core Hub are integrated,
not all38 rooms or full NPC/service parity.

## SOURCE FILES / AUTHORITY

All LPC paths below are relative to read-only `reference/es2/mudlib/`. Functions identify the
relevant evidence, not filename inference. Whole files were read for the three Hockshops and
their item/move/equipment/payment dependencies; targeted functions were read where noted.

| Evidence group | Files inspected / relevant functions |
| --- | --- |
| Service and physical room | `std/room/hockshop.c` (entire file); `d/snow/hockshop.c`; `d/snow/hockshop2.c`; `d/snow/mstreet3.c`; `std/room.c` (init/reset/setup/door/valid_leave behavior) |
| Identity/value | `std/item.c`; `feature/name.c`; `feature/dbase.c`; `std/char.c::visible`; `doc/efuns/present`, `evaluate`, `notify_fail`; `doc/lpc/constructs/function`, `if` |
| Transfer/stack/destruction | `std/item/combined.c`; `feature/move.c`; `feature/clean_up.c`; `adm/simul_efun/object.c::destruct`; `std/equip.c`; `feature/equip.c`; `doc/efuns/destruct`; `doc/applies/clean_up` |
| Money and payment comparison | `std/money.c`; `obj/money/coin.c`, `silver.c`, `gold.c`, `thousand-cash.c`; `feature/finance.c`; `std/room/bank.c`; `cmds/std/buy.c`; `feature/vendor.c` |
| Current consumables/birth | `obj/cloth.c`; `obj/example/dumpling.c`; `obj/example/wineskin.c`; `feature/food.c`; `feature/liquid.c`; `std/armor/cloth.c`; `std/armor/armor.c` |
| Actual loot | `d/oldpine/obj/short_sword.c`, `long_sword.c`, `leather.c` and the corresponding three `d/oldpine/npc/obj/` copies; `d/oldpine/npc/bandit.c`, `tall_bandit.c`, `fat_bandit.c`; `std/weapon/sword.c` |
| Boundary examples | `adm/daemons/weapond.c` (actions/bashing/breaking); `adm/daemons/combatd.c` post_action call site; `d/snow/obj/hammer.c`; `std/weapon/throwing.c`; `d/oldpine/obj/throwing_knife.c`; `obj/corpse.c` decay; `adm/daemons/chard.c::make_corpse`; `d/snow/workplace.c`; `d/snow/npc/waiter.c` |
| Referenced constants | `include/globals.h` HOCKSHOP/COIN_OB/SILVER_OB/features; `include/room.h`; `include/weapon.h`; `include/armor.h` |

Whole-mudlib searches (not only Snow) covered `hockshop`, `pawn`, `retrieve`, `redeem`, `ticket`,
`auction`, 当票/赎回/典物/死当/典当/拍卖, money_id, value writes, and removal/break consumers.
Textual results were separated from executable declarations/calls. Searches included docs and
headers; unrelated FTP retrieval/editor setup are not redemption implementations. Bundled LPC
docs do not prove the exact historical driver's missing-string-return/coercion or negative-division
behavior. No external port or modern-driver substitution was used to fill those gaps.

## PHYSICAL HOCKSHOP / HOCKSHOP2

`d/snow/hockshop.c` names **丰登当铺**, inherits HOCKSHOP, exits west→mstreet3/east→hockshop2.
West is `DOOR_CLOSED` (not DOOR_LOCKED). mstreet3 reciprocates east→Hockshop with a closed door.
`std/room.c` supplies shared door status/open/close and blocks leaving through a closed door;
ordinary room reset does not itself reset the static door mapping to closed on every reset.
There is no explicit no_fight, outdoors, inventory/custody mapping or active NPC spawn in the
shop. The commented beggar-master `objects` block is not population. Prose supplies a counter,
sign, dim interior and east curtain; “非请莫入” is not an executable authorization gate.

`hockshop2.c` is **储藏室**, inherits plain ROOM, west→front, setup plus replace_program(ROOM).
Whole-mudlib references found only its front-room exit and its own return route/definition.
Locked boxes and occasional auctions are prose: no auction action, contents, pawn-ticket lookup,
owner association, expiry, stored goods or service dependency. Front commands need no back room.

## COMMAND SET

**Table 1 — exact inherited Hockshop actions** (`std/room/hockshop.c::init`).

| Action | Common gates in order | Zero value | Positive value | Return |
| --- | --- | --- | --- | --- |
| value | arg/present → money_id → query(value) | Print worthless; handled | Print full value, pawn60%, sell80% and false ticket promise | 1 after printing; lookup/money rejection notify_fail→0 |
| pawn | arg/present → money_id → query(value) → !value | Reject before message/payout | Announce amount → pay_player → destruct(selected object) | 1 on normal completion; gate failure0 |
| sell | Same gates as pawn | Reject before message/payout | Announce sold (no numeric value_string) → pay_player → destruct(selected object) | 1 on normal completion; gate failure0 |

No busy, cooldown, resource/XP/skill change, RNG, no_get/no_drop check, user confirmation,
equipped rejection, living rejection or seller cash check exists in these three handlers.
No `retrieve`, redemption, ticket creation or pawn custody/loan/expiry service was found in the
bundled mudlib. **The ticket claim is in appraisal and the sign, not a created item.** Pawn and
sell differ in percentage and messages, not custody. Normal command return1 is not proof that
every payout denomination reached the player. Uncaught constructor/move/remove/runtime errors
can interrupt execution; ignored move return0 must not be conflated with an exception.

## ITEM LOOKUP

`present(arg, this_player())` searches Player direct inventory, not room contents or recursively
inside a held bag (`doc/efuns/present`; no local present override was found). A direct-held
container object itself is eligible; its children are not independently eligible through this call.
`feature/name.c::id` recognizes exact aliases, or replaces them with nonempty temporary apply/id;
it first applies Player visibility (`std/char.c::visible`: invisibility/ghost rules). Display name
is not automatically an alias. Equipped/worn items remain direct children and remain findable.
Combined stacks are one object; no quantity parser or splitting is performed by Hockshop.

Duplicate aliases may select another matching object after inventory mutation. Hockshop does not
sort, disambiguate or lock identity; bundled present documentation does not specify duplicate
tie order or ordinal-suffix parsing sufficiently to claim a stable cross-run order. Do not invent
“oldest first”, “newest first”, or recursive matching. No explicit living check prevents an unusual
direct-contained living object with a matching id/value; no such sellable entity is represented by
current normal Native items. Ground loot must first be taken into Player inventory.

Native recommendation: exact selected ItemInstanceId, resolve current index plus authoritative
direct parent at execution, list deterministic ID order. Direct ownership/equipped eligibility is
Type A; replacing aliases with precise UI selection is Type B. Current supported canonical leaf
items only, no invisibility/disguise or living-object sale emulation (bounded Type B). Neither
root-owned nested sale nor global anywhere-sale is a semantics-preserving default. New custody
or general merchant behavior would be Type C.

## VALUE SEMANTICS

Hockshop reads **`ob->query("value")`**, not `ob->value()`, not quantity×base_value and not a
market price. `feature/dbase.c::query` uses the instance property, otherwise default object value,
then evaluate; default construction does not make all future values immutable. Scalar values pass
through evaluate; function-valued/custom data is possible in LPC, but not required for current loot.
Source `value` can mutate: food writes0 and weapond bash can divide a broken weapon's value by10.
No generic dynamic price interpreter is justified by these two concrete rules.

`feature/vendor.c::buy_object` happens to read the offered prototype's same value, not an owned
partly consumed object's value. `std/money.c::value()` instead calculates amount×base_value.
All four canonical money definitions set truthy money_id and are rejected before valuation:
coin(1), silver(100), gold(10000), thousand-cash(100000), with weights1/37/37/3 respectively.
Whole-mudlib money_id search found only these four authored setters. A future noncanonical
money_id would also be rejected by source truthiness, not by a whitelist of three names.
Native currently represents coin/silver/gold only; no wallet, bank account or thousand-cash expansion.

## VALUE_STRING DEFECT

For input<1, `value_string` sets its local variable to1 but exits without a return. Because the
following branches are `else if`/`else`, it does **not** return “一文钱”. For input1..99 it returns
Chinese-number 文钱; >=100 it returns silver quotient plus optional coin text; no gold formatting.
Value0 appraisal bypasses value_string and works as worthless. Negative appraisal invokes the
broken branch; percentage0 appraisal/pawn also invokes it. Exact fallback value, `%s` handling or
string-concatenation error is **SOURCE DEFECT / UNPROVEN RUNTIME**, not established display output.

Critical distinction: pawn concatenates the defective result **before** pay_player/destruct;
therefore for value1 (60%→0), a completed pawn payout is not proven without that driver behavior.
Sell never formats its numeric payout before paying, so positive value1 sell reaches minimum1.
Do not silently describe all low-value pawn/appraisal as successful “one coin” text.

Negative integer values are truthy and pass `if (!value)`. Percentage multiplication remains
negative; small negative division's exact truncation direction is not proven in the inspected
bundled docs. In either ordinary non-overflow rounding case the result is <1. `pay_player`, if
reached, forces1. Sell has no value_string call, so its normal negative path pays1 and destroys;
pawn/appraisal may be interrupted at formatting. Integer overflow and malformed noninteger
query values are not safely portable by guessing. No current natural item's value is negative.
Recommend an owner-approved fail-closed typed unsupported/malformed result, not abs()/free minimum
income for invalid Native state. Zero remains a supported worthless value, not “unknown”.

## PAWN

Exact order: lookup → money rejection → value query → zero rejection → value-bearing message →
pay_player(value×60/100) → destruct(ob) → return1. Selected object is not moved into custody.
No ticket clone or record, retrieval handle, deadline, fee, interest or ownership state is created.
For supported positive values with nonzero computed amount, full normal completion is irreversible.
Owner options: literal executable pawn/no ticket (A semantics but retain misleading text only as
an explicitly undesirable presentation choice); defer pawn (B staged omission); implement both
with honest irreversible wording (A results+B presentation); real tickets/retrieval (C new design).
Recommend defer pawn in the first bounded product, or truthful wording if owner wants both.

## SELL

Exact order: lookup → money rejection → value query → zero rejection → sold message →
pay_player(value×80/100) → destruct(ob) → return1. It does not call value_string, split a stack,
remove an item before payout admission, drop the sold object, notify a merchant or refund a failure.
Using actual payout text in Native is a presentation translation, not evidence that LPC printed it.

**Table 2 — independent positive integer arithmetic.** Amounts are value units (文). The
created amount is the amount requested for money creation, not guaranteed delivered money.
“pawn created” assumes execution gets past its earlier message.

| Source value | Pawn raw60% | Pawn created if reached | Sell raw80% | Sell created | value_string(raw) pawn / sell quote |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 0 | 1 | 0 | 1 | both missing-return defect |
| 2 | 1 | 1 | 1 | 1 | 1文 / 1文 |
| 3 | 1 | 1 | 2 | 2 | 1文 / 2文 |
| 15 | 9 | 9 | 12 | 12 | 9文 / 12文 |
| 20 | 12 | 12 | 16 | 16 | 12文 / 16文 |
| 50 | 30 | 30 | 40 | 40 | 30文 / 40文 |
| 100 | 60 | 60 | 80 | 80 | 60文 / 80文 |
| 200 | 120 | 120 | 160 | 160 | 1两20文 / 1两60文 |
| 300 | 180 | 180 | 240 | 240 | 1两80文 / 2两40文 |
| 700 | 420 | 420 | 560 | 560 | 4两20文 / 5两60文 |
| 1000 | 600 | 600 | 800 | 800 | 6两 / 8两 |

These notation cells summarize Chinese-number formatting, not verbatim output. Actual expressions
multiply first then integer-divide by100, with no fractional carry. Recommended low-value Native
policy: preserve pay_player minimum1 and quote actual1 (Type B truthful formatting correction), not
pay0 (changes executable result). The missing-return path remains documented, not silently fixed.

## PAY_PLAYER

`std/room/hockshop.c::pay_player` normal ordered calls:

1. If amount<1 set amount=1.
2. If amount/100 nonzero: new(SILVER_OB), set_amount(amount/100), move(who), amount%=100.
3. If remaining amount nonzero: new(COIN_OB), set_amount(amount), move(who).
4. Return void; caller then destroys the sold object.

There is no move-result branch. Return0 capacity failures do not prevent remainder processing
or final sold-item destruction; an exception is a different failure path. Default money clone
amount1 exists at create time but is replaced by the **full** payout amount before admission.

## DENOMINATION ORDER

For positive normalized N: silver floor(N/100) first, coin N%100 second, omit zero denominations.
For N10000 create100 silver, not gold1. For N100 silver1 only; N99 coin99 only; input<=0 coin1 if
pay_player is reached. Money is physical ItemInstance+CombinedStack, never a credit balance.

## MOVE / CAPACITY / MERGE

`feature/move.c` orders: equipped check/unequip → resolve destination → ancestor exception/capacity
check → remove old aggregate weight → move_object → add new aggregate weight → presentation.
A new payout has no parent/ancestor exception. Capacity rejects iff current encumbrance + full
payout weight > maximum (equality passes); the still-held sold item is included. Its impending
destruction cannot free space for this admission. No whole-payout preflight exists.

`combined.c::move` calls that move first. Only after success into a **living** direct environment
does it scan all_inventory for same base_name, accumulate quantities, destruct every matching
sibling, then set_amount(total). **The incoming payout clone survives; old held stacks die.**
Rooms, nonliving containers and corpses do not merge merely because they can hold items.
Source living() is not identical to every is_character() object: a fresh corpse can wear armor
but is not thereby a living payout recipient. Normal service recipient is the living Player.

For canonical money, destroyed siblings remove their own weights and survivor growth restores
those quantities: net Player increase is the incoming full payout weight, not double weight.
Existing stacks do not waive capacity. set_amount positive recalculates amount×base_weight;
negative errors; zero schedules destruction in1s **without assigning amount0 or weight0**. Hockshop
does not ask for a zero-denomination object, so that delayed-zero behavior is not a payout stage.

Bank contrast (`std/room/bank.c`): missing target moves amount1 then sets full amount; present
target grows without move. Hockshop always creates/moves full-amount clones, even with existing
currency. Do not implement it through BankConversionService or select-and-add shortcuts.

## PAYOUT FAILURE MATRIX

**Table 3 — capacity return0, not thrown errors.** Let F be free capacity while the sold item
is still held, S=37×silver quantity, C=coin remainder. At normal living canonical merge, if silver
succeeds the coin sees F−S; otherwise it sees F. Pending orphan cleanup is driver-owned, not immediate.

| Case | Ordered outcome | Old currency / sold item / orphan consequence |
| --- | --- | --- |
| No same-denomination stack, both fit | silver then coin move | New IDs stay held; sold item destroyed last |
| Existing stacks, both fit | Full-weight admission then merge each denomination | Incoming IDs survive; old stack objects destroyed; sold item destroyed last |
| Silver fails, coin fits | Coin is still created/attempted | E.g. N240, F50: silver2(weight74) orphan; coin40 delivered; sold item still destroyed |
| Silver succeeds, coin fails | Keep successful silver | N240, F90: silver2 delivered; coin40 cannot fit remaining16; sold item destroyed |
| Both fail | Both attempts still made | N240, F20: neither delivered, both parentless; sold item destroyed |
| F exactly denomination weight | Admission succeeds | Strict > rejection, no minimum spare-capacity requirement |
| Existing target but insufficient full incoming weight | Fail before merge | Existing target remains unchanged; never grow it as a bypass |
| Sole denomination fails | No missing/zero second denomination is invented | Sold item still destroyed; failed clone remains parentless |

Source code has no floor fallback, refund, rollback, sold-item rescue or retry after its weight is
released. Parentless payout clones inherit F_CLEAN_UP: when the driver's inactive-object cleanup
calls clean_up, no environment/interactive protection applies and they destruct. Exact elapsed
time is not guaranteed here; docs describe driver-configured inactivity. This is not a pawn deposit.

Owner options: A preserve order/partial delivery and immediately lifecycle-clean failed parentless
clones with consumed IDs/no refund (new **Hockshop-specific Type B**, recommended); B abort and keep
sold item, C preflight all capacity, D drop money on floor, E rollback/refund. B/C/E change source
results and D lacks source support: these are Type C economic redesign options, not default
porting choices. None is approved in H1; S2/Bank/Vendor policies do not authorize A.
Cleanup or authority failure must not be reported as normal success or swallowed as capacity refusal.
For option A, recommend normal silver/coin attempts first, failed-clone cleanup in creation order
next, then sold-item destruction. Immediate cleanup's exact point is a Native choice, not LPC
timing parity. A cleanup authority failure stops normal completion and retains earlier effects;
it must never be silently treated as the ordinary return0-capacity case.

## SOLD-ITEM DESTRUCTION

`adm/simul_efun/object.c::destruct` calls ob->remove(caller euid) then efun::destruct.
`feature/move.c::remove` checks the simul caller, protects user objects, attempts unequip, logs
an unequip false result but normally continues, subtracts own weight from parent, and decrements
default object's no_clean_up reference. `feature/equip.c::unequip` clears exact weapon/secondary
or armor slot, updates action selection for weapons, subtracts applied properties, clears marker.
There is no owner_is_killed call in sale: that is the separate `chard.c::make_corpse` death path.

Current sellable item inheritance adds no custom remove override. Food/liquid and stack state
vanish with their LPC object. Contained-object disposition on arbitrary container destruct is
not established by the brief bundled destruct docs; do not extend a leaf sale to destructive
container commerce. remove can throw; therefore a failure after payout is possible and must be
reported with committed payout, not assumed atomic. Native already returns typed detach/removal
failures rather than emulating a log-and-continue malformed-equipment path.

## EQUIPPED / WORN ITEMS

Source allows both, with payout admission before detachment/destruction. Recommended Native
preserves this. Use the **existing live** Player EquipmentState/ArmorState through
ItemLifecycleOwnerContext; no copied pair. Primary removal does not promote secondary. Armor
removal clears the exact slot and derived contribution (leather armor5/dodge−2; cloth armor1).
Rejecting equipped sale is an optional Type B restriction, not source behavior; not recommended.

## FOOD

`obj/example/dumpling.c` fresh value15, remaining3. First accepted `feature/food.c::do_eat`
writes value0 then decrements remaining; second remaining1 is still value0; final bite normally
destroys the object. Fresh: pawn9/sell12. Partly eaten: appraisal worthless, pawn/sell rejected,
no allocation/destruction. Final depleted state is not a legal persistent live food item.
Native FoodState.current_value is already the authority; do not restore15 from SourceDumpling
when quoting. Successful fresh-food sale must forget the FoodCollection association after removal.

## LIQUID

`obj/example/wineskin.c` value20 is unchanged by `feature/liquid.c` drink/fill. Full/partial/empty,
wine/water all retain value20, pawn12/sell16; an empty wineskin is a live reusable object.
Native has LiquidDefinition.value20 and independent LiquidState content/remaining; alcohol use
remains deferred but sale need not implement drinking alcohol. After authoritative destruction,
forget LiquidCollection, then index. Do not value water or residual wine separately.

## STACK ITEMS

No naturally obtainable non-money CombinedStack item is currently registered in production.
Current three currencies are excluded. Source Hockshop handles one entire selected stack object
without multiplying query(value) by amount. Future throwing knives show why base_value is unsafe:
`d/oldpine/obj/throwing_knife.c` sets base_value80, not value; inherited THROWING/COMBINED_ITEM
does not provide a query(value) multiplier, so it is worthless to this shop. This is a deferred
source example, not current loot. No speculative stack-sale quantity UI is needed.

## CURRENT NATURAL ITEM CATALOG

Enumeration boundary: source New Game cloth; two currently offered Snow products; five production
bandits' actual loadouts; Work and canonical Bank exchange. Verified in `SourcePlayerCloth`,
`SourceDumpling`, `SourceWineskin`, `OldPineNpcDefinitions`, `OldPineSpawnDefinitions`, source money
definitions, purchase/conversion services and OldPineNativeItemDefinitionProjections. Save projection
membership alone was not treated as natural availability.

**Table 4 — all nine naturally obtainable definition IDs (six non-money).** Source paths again
relative to mudlib; payouts assume ordinary supported path and delivery capacity.

| Native definition ID | Source path | query(value) | Money? | Equip/wear | Current mutable value | Pawn / sell |
| --- | --- | ---: | --- | --- | --- | --- |
| es2:obj/cloth | obj/cloth.c | 0 (unset through inheritance) | No | Wear cloth | No | Reject / reject |
| es2:obj/example/dumpling | obj/example/dumpling.c | 15 then0 | No | No | First accepted bite→0 | 9/12 fresh; reject/reject bitten |
| es2:obj/example/wineskin | obj/example/wineskin.c | 20 | No | No | No; liquid state changes only | 12/16 |
| es2:d/oldpine/obj/short_sword | d/oldpine/obj/short_sword.c; npc/obj copy | 300 | No | Primary/secondary | No current break path | 180/240 |
| es2:d/oldpine/obj/long_sword | d/oldpine/obj/long_sword.c; npc/obj copy | 700 | No | Primary | No current break path | 420/560 |
| es2:d/oldpine/obj/leather | d/oldpine/obj/leather.c; npc/obj copy | 200 | No | Wear cloth | No | 120/160 |
| es2:obj/money/coin | obj/money/coin.c | Unset; base_value1 instead | Yes | No | Amount changes, not trade value | Rejected before value |
| es2:obj/money/silver | obj/money/silver.c | Unset; base_value100 instead | Yes | No | Same | Rejected before value |
| es2:obj/money/gold | obj/money/gold.c | Unset; base_value10000 instead | Yes | No | Same | Rejected before value |

Coin/gold are obtainable through Bank, not added to bandit loot. Normal New Game gives no money
or weapon. Silver comes from Work and bandits. Corpses exist as world containers but current
player UI takes their contents, not the corpse itself; they are not a tenth sale candidate.
Serpent is authored but unspawned; no serpent loot/reward is assumed. QA weapons/broken states,
old technical starting sword, knife/blade/glaive/black suit and later region items are excluded.
Source waiter dagger/chicken-leg and missing cake are not current production offers. Cloth tear/
bandages and Snow hammer remain unimplemented; do not populate this catalog from the whole mudlib.

## CURRENT LOOT VALUE TABLE

| Production loot source | Naturally available goods | Pawn extra / sell extra (文) | Already useful |
| --- | --- | ---: | --- |
| Each of3 scout bandits | short sword + silver3 | 180 / 240 from sword | Sword equipment; silver300 already spendable |
| Tall bandit | long sword + silver6 | 420 / 560 from sword | Stronger sword; silver600 |
| Fat bandit | short sword + leather + silver5 | 300 / 400 from gear | Sword/armor; silver500 |

Five finite initial-only NPCs can yield four short swords, one long sword, one leather plus
silver20 in total: potential added sell value1680, or pawn1260, if all are obtained/sacrificed.
This is an upper inventory-value accounting, not a claim a fresh unskilled Player can win all fights
or that NPCs respawn infinitely. No zero-valued bandit item is in these loadouts; zero-valued cloth
is birth gear and bitten food is consumed supply, not monetizable Old Pine loot.

Loot acquisition already uses existing corpse/ground exact-ID transfer and equipment paths.
Important existing limit: fresh corpse is_character permits removal of its worn leather;
after first decay it no longer does, so corpse-worn transfer is locked, not cured by Hockshop.
`CorpseContentTransferService`/`CorpseState` preserve this; obtain it while fresh. Capacity, busy,
combat/survival, range and source decay can prevent a particular loot attempt, but no new combat
system is needed to make already-held loot sellable. Do not promise every visible corpse row is
always takeable or change this boundary in a commerce milestone.

## NATIVE REPRESENTATION GAP

**Table 5 — current authority versus missing trade projection.** Paths below relative to `game/`.

| Category | Existing representation | Minimal missing piece |
| --- | --- | --- |
| All items | core/items/item_definition.gd: immutable identity/source only; ItemInstance identity only | Typed valuation result, not a generic get/set field bag |
| Money | data/items/source_currency_definitions.gd + source_coin/silver/gold.gd + CurrencyDefinition.base_value | Recognize/reject before trade valuation; do not use balance as resale |
| Dumpling | FoodDefinition.initial_value; FoodCollection→FoodState.current_value | Borrow current exact-ID food state; validate required association |
| Wineskin | LiquidDefinition.value; LiquidCollection current content/remaining | Borrow value20 from projection, validate association; no liquid price calculation |
| Short/long sword | OldPineItemContentDefinitions/NpcLoadoutItemDefinition hold weight/damage/weapon facts, NOT resale value | Explicit canonical300/700 source projection |
| Leather | ArmorDefinition and OldPine item content hold modifiers/weight, NOT resale value | Explicit canonical200 source projection |
| Cloth | SourcePlayerCloth/ArmorDefinition has no value | Explicit known-zero projection, distinct from unsupported definition |

Option A: generic immutable typed SourceTradeValue attached/provided for definitions, with a typed
food override. Viable Native architecture, but more content plumbing than immediate need; immutable
value alone is wrong for food. Option B: narrow Hockshop catalog for all values: small, but copying
15/20 and food state would duplicate authority. **Recommend C, a narrow hybrid**: typed catalog for
the four missing static values (cloth0, short300, long700, leather200); reuse existing food/liquid
projections/state; canonical money exclusion. Return known-zero/unsupported/invalid separately.
No mutable catalog state, global service locator or duplicate per-instance value. D, a generic
Dictionary/Variant LPC dbase/value evaluator, is rejected as unnecessary runtime emulation.

Future weapon value mutation must receive its own typed damaged-state design when implemented.
`weapond.c::bash_weapon` on a parry can unequip→move weapon to ground→rename→value/10→weapon_prop0;
it is a post_action on bash/crush/slam, not automatic depreciation on every sword hit. Current
production swords use slash/slice/thrust and Native has no bash/break handler/state. Hammer source
value3 and this future break path do not justify changing Combat or mutable weapon Save now.

## NATIVE AUTHORITY / LIFECYCLE DEPENDENCIES

Use Session's existing `SessionItemIdAllocator`, `InventoryState`, `CombinedStackCollection`,
`WorldItemInstanceIndex`, FoodCollection, LiquidCollection and exact Player equipment/armor.
Allocator is scope + `.dynamic.` + sequence, consumes no gameplay RNG, fails at INT64_MAX and
restores max(saved continuation, represented same-scope IDs+1). Never introduce a money allocator.

Recommended one ID per nonzero denomination clone actually attempted: silver first, coin second.
Admission failure still consumed an allocated identity; successful merge keeps the incoming ID and
removes old sibling IDs. **Do not destroy the new payout ID just because a previous stack existed.**
Arithmetic/allocation/registration/merge authority failures are explicit abnormal results, not
capacity rejections; later stages must not blindly continue after those failures. Distinguish
requested payout, clone IDs, attempted/delivered denominations, absorbed IDs, cleanup and sold-item
removal in a narrow typed ordered result. No giant Session snapshot or generic callback dispatcher.

**Table 6 — lifecycle ownership/order (recommendation built on existing code).**

| Order / authority | Exact seam | Required boundary |
| --- | --- | --- |
| Validate current leaf and live owner | Inventory direct parent + index + typed associations | Quote/execute revalidation; no early sold-item detach to free capacity |
| Payout attempts | CombinedStackService.register_stack/set_amount/transfer_and_merge | Full denomination amount before move; use actual Player capacity; maintain absorbed index IDs |
| Failed payout cleanup, if approved | MoneyInventoryContext.destroy_undelivered → ItemLifecycleService | Parentless check; consumed ID; failures explicit; no ground/refund |
| Sold weapon then armor detach | ItemLifecycleService.destroy_item with live ItemLifecycleOwnerContext | Existing service orders hand→armor; typed failure can leave earlier detach committed |
| Inventory leaf removal | InventoryState._remove_registered_leaf, called by lifecycle | Removes authoritative existence/parent/weight first; no manual index-only deletion |
| Stack association | lifecycle removes CombinedStackCollection entry after inventory removal | Current sell candidates have no non-money stack, but do not leak an association |
| Food then liquid associations | FoodCollection.forget_removed / LiquidCollection.forget_removed | Only IDs proven removed; neither may erase state of a still-live item |
| Derived identity index | WorldItemInstanceIndex.forget_destroyed_snapshots | Last; projection cannot destroy a live object |
| Presentation | refresh held list/current equipment/quote | Report success only after expected domain cleanup; replay stale ID cannot sell again |

Existing `application/food/food_item_lifecycle.gd` and `application/liquid/liquid_item_lifecycle.gd`
already implement individual post-removal forget→index patterns. Future narrow commerce composition
must ensure all required associations are forgotten once; do not call both wrappers to destroy the
same item twice. Reuse lifecycle authority, do not duplicate its internals or change EquipmentState.
Merged money cleanup has no food/liquid association in this bounded catalog.

Source order is **quote → announce → payouts → destroy sold item**, not an atomic transaction.
Native failure before final removal must retain/report earlier successful money effects; do not
claim rollback or blanket success. Corrupt/missing association detection before side effects is a
bounded Native integrity guard, not a new LPC gameplay gate. Container subtree/living sales and
arbitrary custom remove hooks remain unsupported, explicitly rather than silently “worthless”.

## SAVE / CONTINUE IMPACT

Existing `core/persistence/native_item_persistence_composition.gd` captures Inventory-resolved
identities/parents/weights, stacks, exact Equipment/Armor, food and liquid via NativeItemStateCapture;
restore produces fresh authorities, derived index and allocator. NativeItemStateValidator checks
food/liquid presence, value/portions and equipment references. Root game save preserves allocator
and Player location. Sold absence and surviving currency amount/IDs already fit these authorities.
Static valuation catalog has no save data. **Recommend no root/item schema or content revision
change: root2 / item3 / SOURCE_ENTRY_V1.** No ticket/custody/loan table or new Inventory model.

Save boundary analysis: before execution/after read-only quote can use existing eligibility;
do not yield/await/emit reentrant transaction callbacks between payout stages and cleanup. While a
future commerce call is executing, no save capture should interleave. After normal complete or
capacity-partial completion with approved cleanup, existing coherent partial holdings may be saved.
An authority failure is not automatically rejected by all existing save checks: e.g. a consistent
partial payout plus still-live item can be structurally legal. Future adapter must surface/block
unsettled operation completion and prohibit success/retry loops until resolved, with owner review
of this bounded failure handling. No generic rollback, save-every-stage or persistent transaction
log. Existing OldPineSaveEligibility is not already a Hockshop transaction guard.

For physical front room, proposed map remains `snow.outdoor`, new zone e.g. `snow.hockshop`, source
metadata /d/snow/hockshop. Add declared adjacency, actual physical zone/collision geometry and scoped
service contact. SnowWorldDefinitions/OldPineWorldRestoreComposition must recognize it;
OldPineMapPlacementValidator reads actual Snow zone shapes and checks unique center/footprint.
Retain all old valid positions, resident count and entry facts; test cold Continue inside shop and
at joins. Existing position fields suffice, but new content still needs validator/geometry tests.
If a door physically closes on cold Continue, restoration must not trap an inside saved Player or
invalidate a doorway save: prefer an always-usable local Open control and exclude door sweep from
save-legal footprint. Persisting a chosen door state would be a separate state-format decision,
not something to smuggle into “no schema change”. Recommend transient local door state, disclosed
as Type B cold-load reset, subject to owner selection.

## PHYSICAL ACCESS / DOOR OPTIONS

**Table 7 — alternatives, not approved choices.**

| Option | Type / source consequence | Native consequence / recommendation |
| --- | --- | --- |
| Front room only | B staged omission of real east back room | Recommended: small continuous Snow interior zone, east curtain honestly deferred |
| Front + hockshop2 | A topology + B embodiment | Possible but no additional executable commerce; not required now |
| Back-room auction | C invented behavior | Reject absent explicit new-design approval |
| Local physical doorway + open/close state | A closed-door intent + B local implementation/transient lifetime | Recommended, reopenable from both sides; no key/lock/fee |
| Always traversable doorway | B omission of source initial closed state | Smaller fallback only if owner accepts observable difference |
| Static door with Hockshop-only Open interaction | B narrow one-way/open-on-demand staging | Acceptable alternative; disclose omitted Close/persistence behavior |
| Generic LPC door engine | Runtime architecture recreation, not required by Type A fidelity | Reject scope expansion; this pair needs no universal door registry |

Current `scenes/world/snow/snow_outdoor.tscn` HockshopFacade/Shutter/Sign is only a frontage.
Opening service from that old street while leaving the shop inaccessible is not the recommended
physical-room restoration. No merchant NPC, inventory, cash budget, stock reset or dialogue gate
is required by the inherited room action implementation.

## UX TRANSLATION

Recommend a shop-local panel listing current Player direct-held exact IDs, including worn/wielded
items, source value and actual payout quote; value+sell first, optional owner-approved pawn. Recheck
ID/parent/value on activation and refresh after effects. Unknown content is unsupported, known0
is worthless. Label irreversible disposal and capacity-partial payment honestly; confirmation may
be Type B UX but cannot secretly add refundable gameplay. Alternative separate appraisal/transaction
screen is also B but adds navigation without a different rule. Global inventory Sell anywhere is
rejected: source actions are room-owned.

Use existing shared desktop/mobile semantic controls, selection, Back/focus and lifecycle gates.
ACTIVE/noncombat, physical reach, Pause/transition gating are Type B runtime staging, not checks
found in Hockshop LPC. Owner should approve their reuse explicitly; do not add busy/cooldown/RNG
rules to the economic core. UI does not own value, cash, quantity or destruction. No external
merchant framework, runtime scheduling or owner-local Godot AI changes.

## ECONOMIC LOOP

Sell short sword240→silver2+coin40; long sword560→silver5+coin60; leather160→silver1+coin60.
At Inn prices15/20 these equal16/37/10 whole dumplings or12/28/8 wineskins in total-value terms,
with remainders0/5/10 for dumplings. Actual purchase can still require Bank conversion because
source affordability distinguishes proper denominations and retains presence anomalies; quoting
total value must not imply every immediate purchase is allowed. One sword240 can fund a dumpling
and wineskin35 with205 value left, subject to current denomination/payment/capacity rules.

Work remains a repeatable1silver=100 per accepted action for sen30 then gin30, with no work XP or
cooldown; do not infer money/second from action count. Eligible recovery and resources constrain it.
One short sword sell is2.4 Work units of value, long sword5.6, leather1.6, but sacrifices useful gear
and requires successful exploration/loot. Three natural initial Work actions yield300 before the
fourth fails on10/10 without intervening recovery. This gives safe fallback income while excess loot
gains a use. No price, enemy, recovery or drop rebalance is proposed.

## ARBITRAGE / EXPLOIT AUDIT

| Current unlimited product / path | Cost | Pawn / sell receipt | Net money result |
| --- | ---: | ---: | --- |
| Fresh dumpling buy→sell | 15 | 9 / 12 | −6 / −3, no profit |
| Accepted bite then attempt sale | 15 | Rejected, value0 | No resale income; cannot use food then recover12 |
| Fresh wineskin buy→sell | 20 | 12 / 16 | −8 / −4, no profit |
| Empty/refill wine→water wineskin→sell | 20 | 12 / 16 | Same loss; consumed water is gameplay utility, not cash arbitrage |
| Money→Hockshop | Physical money already owned | Rejected by money_id | No denomination shortcut |

No currently offered unlimited item has value1; low-value minimum1 does not create current vendor
profit. Infinite clone stock is paid each time. Split/duplicate aliases cannot authorize repeated
sale of one exact Native ID; verify stale selection and removal. Source custom/negative values,
future vendor price overrides, broken weapon state and future stack commerce are outside this
supported catalog, not silently normalized. No source-faithful current buy→pawn/sell cash arbitrage
was found. Work/recovery repeatability is the already-approved economy, not a new exploit fix.

## OWNER DECISION MATRIX

**Table 8 — A–N remain UNDECIDED.** “Recommend” is not owner approval. A row may contain both a
source rule (Type A) and a separately named observable Native substitution (Type B).

| Decision | Options / classification / source consequence | Native consequence and recommendation |
| --- | --- | --- |
| A Functional scope | Sell-only B omits appraisal/pawn; value+sell B omits pawn; all3 A supported actions | Recommend value+sell; optional all3 only with B resolution |
| B Ticket contradiction | Irreversible pawn A result; defer B; truthful no-ticket wording B; actual custody/ticket C | Defer or label irreversible60%; reject invented redemption |
| C Selection/equipment | Direct-held A; exact ID B; equipped allowed A; reject equipped B restriction; nested/root extension C new reach | Recommend exact direct-held supported leaf, equipped allowed, stale revalidation; no living/container sale |
| D Value representation | Typed definition B architecture carrying A facts; all-values catalog B architecture; hybrid B architecture; dbase emulator is prohibited runtime imitation, not needed for A | Recommend hybrid, existing food/liquid authority + four static source values; no duplicate state |
| E Zero/invalid | Zero worthless/reject A; negative malformed fail-closed B; broken emulation attempted A but unproven; abs/min normalization C new rule | Recommend zero supported, invalid/unsupported explicit; no negative normalization |
| F Rounding/display | Multiply then divide60/80 A; pay_player minimum1 A; truthful actual quote B; pay0 C changed result | Recommend checked integer arithmetic + actual payout quote; missing-return defect retained in evidence |
| G Denominations | Silver→coin no gold A; optimized gold/wallet C changed money behavior | Recommend exact clone order and full amounts before move |
| H Capacity | Ordered partial payout A; keep item/preflight/refund/floor fallback C changed economic result | Recommend continue after capacity return0, destroy sold item last; never capacity-check after freeing sold weight |
| I Orphan/IDs | Driver-later cleanup infrastructure; immediate lifecycle cleanup B; ID consumed B native identity continuation | Recommend Hockshop-specific approval; preserve successful incoming survivor IDs, clean failed clones; cleanup failure explicit |
| J Sold cleanup | Source remove/unequip then destruction A; typed detach failure boundary B | Recommend existing lifecycle, then food/liquid/index forget; no success on unresolved authority failure; no rollback framework |
| K Physical/door | Front only B staged; both rooms A topology/B embodiment; local door B, always-open B omission; auction C | Recommend front only + narrow reopenable local closed door; disclose transient cold-load reset; no generic engine |
| L Interaction | Source room scope A; proximity panel/exact IDs/ACTIVE noncombat gates B; global Sell C changed reach | Recommend local panel, existing input/lifecycle gates with explicit staging approval |
| M Persistence | Existing exact absence/currency/allocator/location A results/B serialization; door/ticket durable state adds requirements | Recommend root2/item3/SOURCE_ENTRY_V1, no new save data; verify old/new positions and cold Continue; no interleaved/unsettled save |
| N Completion | One slice possible but broad; two bounded slices B delivery organization | Recommend H2 core + H3 runtime, focused tests each, distinct final audit, one final PR/four-job gates; stop for owner after each |

## RECOMMENDED IMPLEMENTATION PLAN

**Table 9 — two implementation slices before final audit; neither is authorized by H1.**

| Slice | Smallest responsibility | Required evidence |
| --- | --- | --- |
| H2 typed valuation/payout/lifecycle | Owner-selected A–J contract; hybrid value, exact-ID read-only appraisal, ordered sale/optional pawn, physical clone/merge and complete associated cleanup | Independent LPC-derived integer/minimum examples; zero/invalid/unknown; both hands/armor; each payout capacity case/equality; incoming survivor IDs/allocator; partial errors; food/liquid cleanup; repeated stale requests; save composition roundtrip and unaffected money/inventory regression |
| H3 physical shop/UI/end-to-end | Front zone/local door, scoped input panel, same Session authorities, world-position validation and truthful outcomes | Real walk street→door→shop; appraisal/sale of actual obtained loot; buy supplies; wear/wield cleanup projection; food/wine states; old-position and shop cold Continue; invalid/stale/partial UI result; shared desktop/mobile controls and focused runtime regressions |
| Final audit / integration | Separate audit of combined H2/H3 after owner reviews | Canonical/static/sanitized checks and required live paths per AGENTS; one final PR, exact-head4jobs, separately authorized merge, post-main4jobs |

One all-in-one implementation slice is technically possible, but value provenance, ignored delivery
results, incoming survivor identity and multi-domain destruction deserve a focused correctness gate
before adding physical UI. More than two implementation slices is not justified by present scope.
No full merchant, inventory rewrite, combat changes, scheduling or compatibility layer is needed.

## FINAL MILESTONE BOUNDARY

Target loop: Combat/Loot→Money→Supplies→Recovery→Exploration, using current source values and
already-integrated systems. Hockshop makes excess existing gear valuable; it does not guarantee
combat victory, respawn loot, remedy aged corpse armor locks or replace Work. Front shop only is
the recommended scope, not a claim back-room source content does not exist.

No Herbshop/medicine/condition cadence/alcohol/School/Smithy/Postoffice/Green/Goathill/Lake,
Snow NPC population, generic merchant/crafting/auction/accounts, ticket system or Phase5B4.
Reference source is never edited. Prior S2/Bank/Vendor cleanup substitutions remain scoped;
PlayerBodyFacts remain independent runtime facts; public source New Game and old-save policy unchanged.

## VERIFICATION

H1 verification is documentation/static only: repository checks, changed-document local file links,
trailing whitespace, git diff --check and exact changed-path/forbidden-delta checks. No Godot suite,
editor, runtime or physical-device test is claimed for this analysis. The prior green main run was
independently checked before branching. Runtime correctness remains future implementation evidence.
Before commit, the source equations/order, catalog and recommendations were reread against inspected
files, including three non-obvious boundaries: pawn formatting before payout, incoming stack survival,
and fresh-only corpse-worn transfer. No source-return/driver ambiguity is presented as proven parity.

Executed locally for H1: existing `tools/ci/repository_checks.py` PASS; all85 local file links in
the three changed Markdown documents resolve; trailing whitespace0; `git diff --check` PASS.
Changed-path allowlist is exactly this contract, STATUS and ROADMAP. Production/tests/reference,
DECISIONS/project/CI/build/export delta0. The workstation's `py -3` launcher had no registered
Python, so the unchanged check ran successfully with the bundled Python runtime instead; no
tool installation or environment configuration was changed. No new gameplay assertion count.

## STOP STATE

H1 ANALYSIS COMPLETE / IN REVIEW. Implementation awaits explicit owner decisions A–N and next-slice
authorization. No H2/H3 implementation, final PR, merge or cleanup is authorized by this document.
