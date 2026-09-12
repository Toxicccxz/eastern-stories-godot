# S3A — Currency Exchange / Payment Source Contract

**Current status: OWNER APPROVED / CLOSED.** Owner-approved S3B A–H choices are recorded in
[DECISIONS](DECISIONS.md); implementation/evidence is in
[S3B](PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_IMPLEMENTATION.md).
The analysis and proposal/authorization wording below are historical S3A evidence, not the current gate.

## EXECUTIVE RESULT

**S3A ANALYSIS COMPLETE — AWAIT OWNER REVIEW.** Source archaeology, dependency analysis and
owner-decision preparation only. S1/S2 are OWNER APPROVED / CLOSED; S3B is NOT AUTHORIZED.
No Bank, payment, coin/gold production content, vendor, geometry, test or save implementation.

The important corrections to assumptions are:

- **SOURCE FACT:** `can_afford()` is neither a balance comparison nor a correct general exact-change
  solver. Equality is not universally rejected: 1 silver paying100 passes; 100 coin paying100 fails
  with2 because the silver object is absent. See the executable decision tree below.
- **SOURCE FACT:** `pay_money()` creates **no change and no objects**, and has no success `return 1`.
  Its final residual can throw after earlier gold/silver mutations. A result1 from `can_afford()`
  does not guarantee payment completion. No `pending_buy` mechanism was found.
- **SOURCE FACT:** Bank creates a new target at its authored **amount1**, attempts movement with that
  weight, then sets the full converted amount, announces conversion, and deducts source currency.
  A failed move is ignored. Existing target growth and post-move growth both bypass capacity rejection.
- **SOURCE FACT:** Standard denomination up-conversion rounds the **quantity actually deducted** down;
  unconverted remainder stays in the source stack. It does not normally throw the remainder away.
- **CURRENT NATIVE FACT:** Existing item/stack/transfer/lifecycle/save authorities can represent most
  steps. They do not supply an economy policy or execute the one-second stack destruction intent.
  Adding a Wallet or another persistence graph is unnecessary and prohibited.
- **OWNER DECISION REQUIRED:** Money lookup scope, anomalous affordability/payment, zero-depletion
  lifetime, Bank delivery failure, growth/capacity order and transactional substitution must be chosen
  explicitly. The S2 work-reward decision grants no Bank or vendor cleanup permission.

## EXACT BASELINE

Before edits, local Git and independent GitHub REST refs/PR collection agreed:

| Fact | Verified value |
| --- | --- |
| Repository | `Toxicccxz/eastern-stories-godot` |
| Main / origin/main | `047f29083e881156abbdad6ed480bffc1350dfa8` |
| Current branch | `phase/snow-town-core-hub` |
| Local / remote starting HEAD | `241a33a678d74c4aa0e3d1e53323dcaa877d387a` |
| HEAD subject | `Add Snow workplace income loop` |
| Ancestors after main | `c5f4472e147dba79c1eb6fd520debcd2e873a879` then `241a33a678d74c4aa0e3d1e53323dcaa877d387a` |
| Working tree / staged state | Clean / empty |
| Snow PRs, all states, this head to main | None |

This document's commit is a documentation-only successor, not a new implementation baseline.
Existing main contains Source-valid New Game Entry via PR15. Snow remains unmerged.

## AUTHORITY / SCOPE

Read root/docs AGENTS and, in order, ES2_ARCHITECTURE_ANALYSIS, STATUS, ROADMAP, DECISIONS,
PHASE_NEW_GAME_ENTRY_FINAL_AUDIT, PHASE_SNOW_TOWN_CORE_HUB_REBASELINE and
PHASE_SNOW_TOWN_CORE_HUB_WORK_INCOME. Current code > DECISIONS > STATUS > ROADMAP > latest
phase/audit > older phase docs > proposals for current native facts; original `reference/es2/`
controls gameplay semantics. Latest explicit owner approval supersedes stale S2 review checkpoints.
The early architecture document's Wallet suggestion and S1's broad finance options are not approved
authority to replace physical currency or decide this slice's anomalies.

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment,
interaction translation and presentation. Type A = semantic migration (default); Type B = native
translation with any observable substitution explicitly owner-reviewed; Type C = new design,
not authorized. Unpleasant source results are not permission to fix them silently.

Labels: **SOURCE FACT** means inspected executable LPC or bundled runtime documentation;
**CURRENT NATIVE FACT** means inspected code at the starting HEAD; **INFERENCE** identifies
deductions/recommendations rather than executed LPC evidence. **OWNER DECISION REQUIRED** is not approval.
LPC paths below are relative to `reference/es2/mudlib/`; native paths start with `game/`.

## SOURCE COVERAGE

Direct reads (whole small files, or complete named dependency functions):

- `feature/finance.c`, `cmds/std/buy.c`, `feature/vendor.c` — complete payment path.
- `std/room/bank.c`, `d/snow/bank.c`, `d/city/bank.c` — shared implementation and both specializations.
- `obj/money/coin.c`, `silver.c`, `gold.c`, `thousand-cash.c` — **all four** money definitions.
- `std/money.c`, `std/item/combined.c`, `feature/move.c`, `feature/clean_up.c`, `feature/name.c`,
  `feature/dbase.c`, `include/dbase.h`, `include/globals.h` — identity, amount, capacity, lifetime.
- `std/char.c` inheritance/setup and `visible()`; `std/room.c` including setup/reset — inherited context.
- `adm/obj/simul_efun.c`, `adm/simul_efun/object.c` (`destruct`),
  `adm/simul_efun/file.c` (`base_name`) — runtime adapters actually used.
- `d/snow/npc/smith.c`, `waiter.c`, `herbalist.c` — quote/fulfillment/stock definitions.
- `daemon/class/beggar/master.c::attempt_apprentice`; ronin/assassin counterparts including their
  surrounding comment delimiters — distinguish live callers from commented examples.
- `std/room/hockshop.c` — distinguish its `pay_player()` creation from finance `pay_money()`.
- Bundled `doc/efuns/{present,sscanf,call_other,destruct,call_out}`, `doc/applies/clean_up`,
  `doc/mudlib/feature/finance`, `doc/mudlib/std/bank` — supporting, not overriding executable code.

Repository-wide searches across the mudlib (including `u/`, not only Snow), with comment review:

| Search | Result / coverage boundary |
| --- | --- |
| `can_afford` | Definition/docs; live callers `buy.c` and beggar master. Ronin and assassin calls are inside block comments. Beggar treats BOTH1/2 as wealthy and refuses recruitment; no payment. |
| `pay_money` | Definition/docs; only live call `buy.c:28`, passing an extra0. No change-generating overload found. |
| `pending_buy` and case-insensitive `pending.?buy` | No matches. No reservation, deferred buyer debt or pending stock state to migrate. |
| `do_convert`, literal `"convert"`, `inherit BANK` | One command implementation/registration in standard Bank; Snow and City inherit it, no override. |
| `buy_object`, `compelete_trade`, `F_VENDOR` | Shared feature plus Smith override; numerous other vendor consumers, not all read as content. No additional implementation of these methods found. |
| `obj/money` directory | Four `.c` definitions; paper currency is real source content but not a production S3B assumption. |
| Native finance/payment/wallet/pending names | No existing `.gd` finance/payment/wallet authority found; currency multiplication and physical stacks already exist. |

No external port or live LPC driver was used. Tables below are source-derived desk traces, not
claims of running the original server. Driver argument-count/default-return and exact scheduling
details not proved by the bundled documentation remain distinguished from source-level branches.

## MONEY DENOMINATION CONTRACT

**SOURCE FACT:** All inherit MONEY → COMBINED_ITEM → F_MOVE/F_NAME/F_DBASE/F_CLEAN_UP.
Each `create()` sets name/aliases, clone default-object reference, prototype facts, then `set_amount(1)`.

| Source (`obj/money/`) | Display name | Exact aliases | money_id | base_value | base_weight | base_unit |
| --- | --- | --- | --- | ---: | ---: | --- |
| coin.c | 钱 | coin, coins, coin_money | coin | 1 | 1 | 文 |
| silver.c | 银子 | silver, ingot, silver_money | silver | 100 | 37 | 两 |
| gold.c | 黄金 | gold, ingot, gold_money | gold | 10000 | 37 | 两 |
| thousand-cash.c | 一千两银票 | thousand-cash, thousand-cash_money, cash | thousand-cash | 100000 | 3 | 张 |

`unit` is 些 for the first three, 叠 for the note; it differs from quantity `base_unit`.
Definition/merge identity is the exact base source path, e.g. `/obj/money/silver`, not display name,
shared `ingot` alias, `money_id` or face value. `base_name()` strips the clone `#number` suffix.
Finance hardcodes `gold_money/silver_money/coin_money`; it **ignores thousand-cash value**.
Bank's explicit format can use `thousand-cash`, since it has the suffixed alias and an existing file.
Aliases `ingot`, `coins`, `cash` do NOT automatically work as Bank type names: Bank appends `_money`.

**CURRENT NATIVE FACT:** Reuse `game/data/items/source_silver.gd`: ID `es2:obj/money/silver`,
weight37/value100/unit两; Old Pine loadout definitions already consume it. Do not register a second
silver authority. Coin/gold/paper source presence does not mean production native support exists.

## COMBINED MONEY BEHAVIOR

**SOURCE FACT:** `std/money.c:5-14`, `std/item/combined.c:11-61`:

- `amount` is a per-object static int. `value()` = amount × base_value, not `query("value")`.
  Positive set sets amount and own weight = amount × base_weight. Currency is one real object per stack.
- Negative requested amount raises an error before mutation. `add_amount(delta)` calls
  `set_amount(old+delta)`; it is not an independent clamp or wallet adjustment.
- Requested0 schedules `destruct_me` in1 second; **old amount and weight remain**, even though the
  caller considers it spent. A later positive update does not cancel that callout.
- `move()` calls inherited move first. Only after successful movement into a `living` destination
  does it enumerate **direct** inventory and merge every same-base object into the incoming survivor.
  Sibling objects are immediately `destruct`ed; finally survivor amount is set to total. No room,
  ordinary bag or corpse merge is implied. No generic mutable sibling state is copied.
- Destruction goes through `adm/simul_efun/object.c::destruct` → item `remove()` → driver destruction;
  move.remove subtracts own weight and default-object reference count, and attempts unequip if marked.
- Autoload stores amount text and reapplies set_amount, not the static field or pending callout.
  Native item persistence intentionally has its own complete-graph contract, not LPC logout parity.

**INFERENCE (source-ordered):** Full depletion leaves a briefly spendable/convertible positive stack.
Two conversions before its callout can reuse it. If that pending object survives a later merge/growth,
its callout can destroy the grown amount; if it is absorbed/destroyed, its old positive quantity can
be transferred into a fresh survivor. Exact availability of a second player command in that window
depends on runtime scheduling; the stale amount is certain. Never label immediate amount0/deletion
as exact parity. See decision G; no new timer is implemented here.

## LOOKUP / IDENTITY CONTRACT

**SOURCE FACT:** Finance uses one-argument `present` (`finance.c:17-19,56-58`); bundled present docs
search current character inventory and then its environment inventory, not a recursive owned graph.
Bank uses explicit `present(type+"_money", this_player())` (`bank.c:42-43`), so direct Player children
only. Neither sums all matching objects: each expression returns one object. Money inside a carried
bag is not implicitly payment money. A missing denomination can be supplied by a ground stack in
finance; payment then mutates that ground object without first picking it up/capacity-checking it.

`feature/name.c::id` also checks visibility and optional `apply/id` masquerade. `std/char.c::visible`
consults wizard visibility/invisibility/ghost/astral vision. These are legacy lookup dependencies,
not permission to add disguise/wizard systems. Normal money definitions set none of those overrides.
Stable-ID deterministic selection and Player-direct-only access would be explicit translations,
not a claim that one-argument present meant owned money. Multiple matching ground objects' order
is not specified as authored gameplay data; no all-ground-money summation is justified.

## can_afford() CONTRACT

**SOURCE FACT:** `feature/finance.c:12-49`, excluding the commented-out older algorithm at40-47.
Let P=requested price; G/S/C be `value()` of the three selected objects (absent =0). Object
**presence** is separate from numeric value. With positive ordinary prices:

1. T=G+S+C. If **T < P**, return0.
2. If coin exists: if **C < P%100**, return2. If absent: nonzero P%100 returns2.
3. If silver exists AND coin exists: if **S+C < P%10000**, return2.
   If silver exists but coin is absent, this comparison is **skipped entirely**.
   If silver is absent: nonzero P%10000 returns2, regardless of sufficient coin.
4. Otherwise return1.

Every comparison is strict `<`; equality passes that comparison. Comments saying “proper money”
are an intention, not proof of the algorithm's correctness. 0 means insufficient selected total;
2 means one of these actual gates failed, which can be a false rejection; 1 means these gates passed,
which can still be a false promise of payable denominations. No state is changed by this function.

### Source-derived truth table

Counts below are ordinary visible direct stacks; 0 means **absent**, not an existing raw-zero object.
P and T are coin-value units. “buy” assumes a non-user vendor already quoted that positive P.

| Gold | Silver | Coin | P | T | Return / reason | buy result |
| ---: | ---: | ---: | ---: | ---: | --- | --- |
| 0 | 0 | 0 | 1 | 0 | 0, T<P | insufficient money |
| 0 | 0 | 100 | 99 | 100 | 2, no silver and P%10000=99 | insufficient change |
| 0 | 0 | 100 | 100 | 100 | **2 despite exact total**, no silver | insufficient change |
| 0 | 0 | 100 | 101 | 100 | 0 | insufficient money |
| 0 | 1 | 0 | 99 | 100 | 2, no coin and P%100=99 | insufficient change |
| 0 | 1 | 0 | 100 | 100 | **1 exact**, residues0/100, silver-present/coin-absent skip | pay completes, silver pending destruction |
| 0 | 1 | 0 | 101 | 100 | 0 | insufficient money |
| 1 | 0 | 0 | 9999 | 10000 | 2, no coin | insufficient change |
| 1 | 0 | 0 | 10000 | 10000 | **1 exact**, both residues0 | pay completes, gold pending destruction |
| 1 | 0 | 0 | 10001 | 10000 | 0 | insufficient money |
| 0 | 1 | 100 | 199 | 200 | 1, C>=99 and S+C>=199 | consumes silver and99coin |
| 0 | 1 | 100 | 200 | 200 | **1 exact**, 200>=200 | both stacks pending destruction |
| 0 | 1 | 100 | 201 | 200 | 0 | insufficient money |
| 0 | 1 | 100 | 50 | 200 | 1, both lower gates pass | coin100→50, silver unchanged |
| 0 | 0 | 10000 | 10000 | 10000 | 1, both residues0 | coin pending destruction |
| 0 | 100 | 0 | 10000 | 10000 | 1, silver-present skip | silver pending destruction |
| 1 | 1 | 0 | 9900 | 10100 | **1**, no-coin silver check skipped | pay throws after silver depletion intent |
| 2 | 1 | 0 | 19900 | 20100 | **1**, same skipped check | gold2→1, silver depletion intent, then throw |
| 1 | 0 | 10000 | 19900 | 20000 | **2**, absent silver | buy rejects although direct pay would finish |

This covers total just below/equal/above price, exact denominations and false positives/negatives.
An existing raw-zero silver object can make an otherwise rejected coin-only payment pass; a raw-zero
coin object can enable the S+C check and make the no-coin false positive disappear. Do not collapse
“present with0” and “absent.” Normal concrete money starts1; full depletion does not produce raw0.
P=0 with no money returns1; positive-balance negative P is not validated as a price here. `buy.c`
rejects quoted prices<1 first. No `pending_buy` affects any branch.

## pay_money() ORDERED MUTATION CONTRACT

**SOURCE FACT:** `feature/finance.c:51-94`. Lookup is gold→silver→coin, then sum all three values;
payment processing order is also gold→silver→coin. Let A be mutable remaining price:

| Position | Predicate | Mutation / next A |
| --- | --- | --- |
| 65 | T<A | return0 before any debit |
| 67-74 | gold present AND A>=10000 | If gold.value>=A: add_amount((-A)/10000), then A%=10000. Otherwise subtract the entire gold.value from A, then gold.set_amount(0). |
| 76-83 | silver present AND A>=100 | Same, divisor100. Compare against **whole current A**, not only the silver remainder or planned coin contribution. |
| 85-90 | coin present AND A>0 | If coin.value>=A: add_amount(-A), A=0. Otherwise throw `F_FINANCE: Not enough money!` without decrementing coin. |
| 93 | A>0 | Throw the same error; no compensation. |
| end | A<=0 | Function falls through, no explicit success return. `buy` ignores return anyway. |

For positive prices, signed integer truncation of `(-A)/unit` removes floor(A/unit) units, not
ceil(A/unit). `A%unit` is **unpaid residual**, not newly minted change. No change denominations,
creation, move, allocator draw, seller credit, fee, `pending_buy`, or explicit `destruct` call occurs
in finance. `set_amount(0)` and exact-depleting add_amount emit delayed destruction through Combined.
Do not reinterpret the declared `int` as a reliable success boolean. Bundled documentation does
not establish the deployed driver's fallthrough value or extra-argument strictness; the source
call `pay_money(price,0)` supplies an unused extra argument to a one-argument function.

### Mutation traces for future independent tests

**INFERENCE from the numbered source steps; no driver execution claimed:**

| Input / invocation | Exact sequence / visible consequence |
| --- | --- |
| silver1+coin100, buy199 | can=1; gold skipped; silver.value100<199 → A99, set silver0 (old1/weight37 remains pending); coin100→1, A0; buy fulfills. After callback silver disappears. |
| gold2+silver3+coin50, pay10225 | gold2→1, A225; silver3→1, A25; coin50→25; no creation or scheduled depletion. Debit value10225 exactly. |
| gold2+silver1, buy19900 | can=1; gold2→1, A9900; silver100<A → A9800, old silver1 pending; no coin; throw. No goods. Gold mutation is immediate, silver is lost when callback executes. |
| gold1+silver1, buy9900 | can=1; gold is not touched because A<10000; silver becomes pending; A9800 throws. 100 value eventually lost, gold retained, no goods. |
| gold1, direct pay50 | T sufficient, gold/silver/coin debit branches do nothing; A50 throws, no mutation. Normal buy blocks earlier with can=2. |
| coin100, direct pay50 | succeeds in-place to50; normal buy blocks with2 due missing silver. |
| gold1+coin10000, direct pay19900 | gold set0 pending, A9900; coin10000→100; succeeds. Normal buy rejects2. |
| T<P | return0, no debit; buy normally already rejected. |
| direct pay0 or negative, ordinary positive stacks | all denomination debit guards false, falls through without mutation. Not a priced-buy path. |

**OWNER DECISION REQUIRED:** Preserve ordered partial loss/error as a typed outcome or authorize
a narrowly specified correction. Atomic preflight/rollback changes behavior. “Failed change delivery”
is **not applicable to pay_money**; inventing a change mint to repair it is not a source migration.

## buy.c / VENDOR PAYMENT DEPENDENCY

**SOURCE FACT:** `cmds/std/buy.c:11-32` order:

1. Parse `<item> from <target>`; missing/malformed input fails.
2. Resolve target with `present(target, environment(me))`, direct room contents. Not Player inventory.
3. If target is userp, only announce purchase intention and return1; no pending record/payment.
4. Set default refusal text; call `owner->buy_object(me,item)`; price<1 returns0.
5. Call Player can_afford(price). 0 → insufficient money;2 → insufficient change; neither pays.
6. Otherwise call pay_money(price,0), ignore its return, then `compelete_trade(me,item)`, return1.
   A thrown payment error interrupts before fulfillment; prior payments are not reversed.

There is no generic quantity parser, stock decrement, busy/fight/ghost rule, living-vendor check,
or explicit method-presence check here. An item string must match the vendor's supported key.
Do not add a quantity purchase interface by pretending the command already supplied it.

**SOURCE FACT:** `feature/vendor.c:5-26` quotes prototype `vendor_goods/<what>` string-path
`query("value")`. On completion it looks up the mapping again, clones the object, calls move(Player)
without checking return, then announces purchase. Mapping is not decremented; this is unlimited
on-demand cloning, not finite live goods in NPC inventory. If the mapping no longer supplies a string,
fulfillment does nothing after payment; no pending reservation exists. If new/load throws, payment
is already done. A normal return0 from goods move leaves ownerless goods and a purchase announcement.

Smith is a distinct override: `d/snow/npc/smith.c` quotes300 only for `铁锤`, then creates
`npc/obj/hammer` and ignores move result. His equipped hammer is not the stock sold. Waiter/herbalist
use the shared mapping (four/two goods respectively). `get_vendor_list` is presentation of static
offers and prototype values, not inventory availability. ROOM reset respawns tracked NPCs, not
depleted goods; there is no vendor stock lifecycle to save for this feature.

`std/room/hockshop.c::pay_player` really creates silver then coin, sets their quantities **before**
moving, but is a different payout API, not finance's missing change branch. Pawn/sell destroys the
sold object after payouts; no caller routes this through pay_money. Keep it out of S3B implementation.

**Boundary:** S3A establishes quote→affordability→payment semantics. Vendor population, goods
definitions, supply consumption/state, fulfillment failure and interaction belong to later slices.
Goods-delivery loss is not Bank conversion loss: payment is already finished and the goods' weight
and creation effects are separate. Do not apply one “commerce failure” rule to both.

## SNOW BANK SOURCE CONTRACT

**SOURCE FACT:** `d/snow/bank.c` inherits BANK without overriding its commands. Sign advertises only
convert; standard `init()` also registers deposit, whose body is empty. No withdraw, account balance,
interest, deposit mutation or account persistence implementation. Snow has annihir1 and east exit
to mstreet1; no_fight/no_magic lines are commented out. NPC combat/population is not a prerequisite
to understanding the room method and is not migrated here. City Bank shares the same method.

`std/room/bank.c:17-40` parsing order:

- `%d %s to %s`: explicit count/from/to; no fixed allowlist or same-type prohibition.
- Else `%d %s`: only literal `gold` defaults to silver, `silver` to coin.
- Else `%s`: same two defaults, count1. `coin` alone has no default; explicit coin→silver works.
- Invalid form refuses; values<1 are checked later. There is no locale-name mapping, fee, skill,
  busy rule, account state, ownership permission beyond direct present, or RNG.
- Explicit paper conversion is source-supported, e.g. `1 thousand-cash to gold` →10gold.
  Not including paper in a proposed first slice is a documented scope deferral, not source absence.

### Conversion validation and order

**SOURCE FACT:** numbered positions refer to `std/room/bank.c` above:

1. Parse; resolve from and to direct Player objects (42-43).
2. Only when to is absent, test `/obj/money/<to>.c` file_size<0 and reject missing target (44-45).
   Thus invalid target is reported before missing source or invalid count. Existing to bypasses file check.
3. Reject missing from (47), count<1 (48), from.query_amount<count (50), in that order.
4. Read bv1=source.base_value; only zero is explicitly refused (53-54). Not a `money_id`/MONEY check.
5. bv2=existing target.base_value, else target prototype query via call_other (56).
   No positive/zero bv2 validation is added by source.
6. If bv1<bv2: q=count-count%(bv2/bv1). Otherwise q=count (58).
   Reject q==0 (59). The source holding check used the **original request**, not rounded q.
7. k=q*bv1/bv2 (integer expression evaluated at its use). New target: new→move(Player)→set_amount(k)
   (61-64). Existing target: add_amount(k) (66). No check/refund for ordinary move failure.
8. Announce q and k with original objects' names/base_units (68-71).
9. Source add_amount(-q) (73); return1 (75). Full-source depletion is delayed, not immediate.

`bv1/bv2` need not be immutable in general LPC; prototype defaults can be overridden per instance.
An object matching a suffixed alias with relevant methods/base_value can enter this protocol without
money_id; arbitrary custom counterfeit/content behavior is not proved by these four money files.
If an unusual target has bv2=0, division is unguarded. On the new-target branch object creation/move
precedes the set_amount argument division; existing-target division precedes add mutation. Missing
methods, invalid signed values and driver integer overflow are error boundaries, not invented fees
or successful conversions. Future bounded native requests should use known definitions/checked
arithmetic and explicit unsupported/error results; broader compatibility choice is decision H.

### Ratios / quantity examples

**SOURCE FACT / arithmetic consequences:** for the actual positive definitions, ratios divide exactly.

| Request (sufficient holding) | q debited | k credited | Unconverted source |
| --- | ---: | ---: | --- |
| 1 silver→coin | 1 | 100 | holding minus1 |
| 1 gold→silver | 1 | 100 | holding minus1 |
| 1 gold→coin | 1 | 10000 | holding minus1 |
| 99 coin→silver | 0 | none; refused | all99 |
| 100 coin→silver | 100 | 1 | zero only after delayed destruction if exact holding |
| 199 coin→silver, holding199 | 100 | 1 | **99 coin retained** |
| request199 coin, holding150 | none | refused at holding check | all150, not auto-downsized to100 |
| 101 silver→gold, holding101 | 100 | 1 | **1 silver retained** |
| 1 thousand-cash→gold | 1 | 10 | holding minus1 |
| q silver→silver | q after adding q | q temporarily added | final original amount, same object |

No rounding-value loss for these positive divisible denominations in a successful settled distinct-type
exchange: q*bv1=k*bv2. Custom non-divisible base_values could truncate value (not a standard coin fact).
Same-denomination exchange temporarily grows the same object then subtracts q; no new object/ID,
no final balance change, but temporary weight can trigger overload messages. Do not invent a same-type
rejection as though the LPC contained one.

## MOVEMENT / CAPACITY DEPENDENCIES

**SOURCE FACT:** `feature/move.c:46-95` order: equipped marker/unequip → resolve destination →
ancestor test → if not ancestor, reject current contents+moving subtree weight **>** max → remove old
parent encumbrance → move_object → add new encumbrance → interactive mover presentation.
Failure can preserve containment but leave equipment detached. Currency normally has no equipped
marker. A new coin object has no ancestor, and equality with cap passes. Source currency is still
carried during Bank's target-move check; future net weight is NOT used.

`set_weight` (31-39) propagates weight difference to environment; add_encumbrance (15-27) warns
when over capacity but never clamps/rejects the update, then propagates to ancestors. Underflow is
logged, not clamped. For standard money no custom overload hook was found. No movement/init/merge
is performed by a simple add_amount. A changed existing stack can exceed cap without being dropped.

### Existing target vs new object

| Property | Existing target found | New target |
| --- | --- | --- |
| Identity / allocation | Same target ID; no clone | Fresh amount1 object; one allocation needed natively |
| Initial operation | add_amount(k) | move amount1 BEFORE set_amount(k) |
| Capacity admission | None | Check one unit weight (coin1, silver/gold37, note3), before source debit |
| Final amount growth | No capacity rejection | After successful move, no capacity rejection either |
| Ordinary move failure | Not applicable | Return ignored, set full k on ownerless target anyway |
| Source debit | After target increase and message | After attempted move, target set and message, including move failure |
| Merge | None | Successful move into living Player can merge by exact base path |

**INFERENCE — worked capacity vectors**, contents include all carried items, not body weight.
Use max1000 solely for an arithmetic example, not a new gameplay cap:

- New coin absent, silver holding2, current contents999; convert1silver→coin. Clone coin1 admission
  reaches1000 and succeeds; set100 raises contents1099; silver2→1 subtracts37; final **1062>1000**.
  Checking final100coin weight before movement would incorrectly reject this source-success path.
- Existing coin1, silver2, current contents1000; same conversion adds100weight (1100), then subtracts37;
  final **1063**, no admission check or new ID. Temporarily overloaded warnings are possible even if
  a later source debit brings the final total below cap.
- New silver absent, coin200, contents1000; convert100coin→silver: clone37 is rejected, remains
  ownerless; set1; announce; coin200→100; final Player contents900, **no silver delivered**. Lost value100
  once considering Player inventory, despite room return1. New ID is still consumed in a native clone analogue.
- Existing silver1 under the same total-load/coin200 setup: add1silver (+37), then coin200→100 (-100);
  final937 with silver2. Same requested exchange, different result because a target already exists.
- If all source coin100 is used instead, add_amount(-100) leaves the old100 visible/pending; its
  weight is not removed until the scheduled callback. Source deduction cannot be reported as an
  immediate physical weight reduction in that case.

**SOURCE FACT:** In failed new-target delivery there is no explicit Bank destruction/ground move.
The target remains environment-less. `feature/clean_up` destroys such inactive ownerless objects
when driver cleanup runs; bundled clean_up docs tie it to runtime configuration/inactivity, not a
Bank-relative timer. Normal players cannot present it in Player/room inventory. Exact cleanup timing
is unproved and not a native gameplay rule. Immediate callback errors could stop before deduction;
ordinary returned capacity failure does not. Keep those failure kinds distinct.

**INFERENCE (non-normal lookup case):** If present misses an existing same-base target due to alias/
visibility, successful new-target move can absorb that stack; the subsequent Bank set_amount(k)
overwrites the merged total. Thus “no existing target” means no lookup result, not necessarily no
same-base object. Ordinary unmodified visible money avoids this edge. Do not add disguise infrastructure
to S3B; declare this unsupported boundary rather than claim whole-driver parity.

## CURRENT NATIVE FIT

**CURRENT NATIVE FACT:** inspected current authorities; paths here are relative to `game/`.

| Code | Reuse / constraint |
| --- | --- |
| `data/items/source_silver.gd`, `data/oldpine/oldpine_npc_definitions.gd::silver_content/loadout_item_definitions` | One shared silver definition/value/stack compatibility, already in Old Pine restore inputs; no duplicate registration. |
| `core/items/item_instance.gd` | Immutable semantic instance ID + definition ID, not amount/parent/value bag. |
| `core/items/combined/{currency_definition,combined_stack_definition,combined_stack_state,combined_stack_collection}.gd` | Currency value multiplication; base weight/compatibility; per-instance amount. Collection returns copies and is aggregate-local. CurrencyDefinition is not an account. |
| `core/items/combined/combined_stack_service.gd::{register_stack,set_amount,add_amount,transfer_and_merge}` | Positive growth updates Inventory weight without capacity check. Zero returns typed DELAYED_DESTRUCTION_REQUESTED with old amount/weight and delay1. No internal timer. Incoming identity survives merge; absorbed IDs report lifecycle removal. |
| `core/inventory/{inventory_state,containment_endpoint}.gd` | Liveness/one direct parent/own weight; CHARACTER/ITEM/WORLD endpoints; stable-sorted direct children, ancestry, derived recursive contents weight. No new currency graph needed. |
| `core/inventory/{inventory_transfer_service,inventory_transfer_destination,inventory_transfer_result}.gd` | Exact detach-before-destination ordering; caller supplies authoritative max; ancestor exception; strict > rejection. Reports capacity, containment and detach separately. |
| `core/characters/player_body_facts.gd` | Maximum encumbrance independent of live strength; future Bank must use established Player max, not recalculate it. |
| `core/items/lifecycle/item_lifecycle_service.gd` | Stateless removal with leaf/subtree policy, exact direct-owner Equipment/Armor context; no fallback delete on failure. Parentless leaf removal is available, but policy to use it for Bank is NOT authorized. |
| `runtime/world/world_item_instance_index.gd` | Identity projection only; Inventory is liveness authority. Forget removed IDs only after actual lifecycle success. |
| `core/persistence/session_item_id_allocator.gd` | Session scope + monotonic sequence; no gameplay RNG/ObjectID; overflow/collision fails. Restore max(saved sequence, represented same-scope sequence+1). Do not refund consumed sequence or allocate another subsystem's IDs. |
| `application/snow/snow_work_service.gd` | S2-specific costs/reward/cleanup composition, **not** a reusable commerce policy. |

No runtime/application consumer of Combined's `DELAYED_DESTRUCTION`/delay result was found in the
search. Existing Core emits the intent; merely calling add_amount to deplete money would leave
spendable value indefinitely unless future composition handles it. This is a real S3B dependency,
not permission to implement recovery/global scheduling. Existing valid stack growth already permits
over-cap state; there is **no need to modify Combined/Inventory to preserve this source fact**.

**INFERENCE — smallest future seam:** explicit denomination inputs resolved from the one item graph,
a narrow typed affordability result, and separately ordered payment/exchange results containing
selected/created/debited IDs, amount changes, transfer result, lifecycle intents/failure stage and
completed mutations. No generic transaction engine, call_other dispatcher, arbitrary payload map,
global catalog, cloned Character/Equipment authority or persisted numeric balance. Query summaries
may total money for display but cannot become spend authority. Selection-scope policy must be explicit.

## SAVE / REVISION IMPACT

**CURRENT NATIVE FACT:**

- Root `core/persistence/game_save_snapshot.gd` = schema2; embedded `native_item_state_snapshot.gd`
  remains item schema1. `game_save_json_codec.gd::_encode_items/_decode_items` stores exact
  instance/definition IDs, decimal-int64 own_weight, optional direct parent, stack amount and
  Equipment/Armor references; no denomination enum or fixed currency-count column.
- `native_item_persistence_composition.gd` captures all registered Inventory IDs resolved through
  the index, delegates to `native_item_state_capture.gd`, then existing validator. Restore creates
  fresh items/Inventory/Combined/Equipment/Armor, fresh derived index and continued allocator.
  `native_item_state_restorer.gd` reconstructs parents without gameplay capacity checks and preserves
  saved weight/amount, including raw0; it does not refill money or execute change/merge/Bank.
- `native_item_state_validator.gd` requires known definition, valid graph and nonnegative amount;
  it does not reject over-cap contents. Parentless records can exist; they are NOT automatically
  garbage-collected or omitted from capture. Unknown coin/gold definitions currently fail restoration.
- `data/oldpine/oldpine_native_item_definition_projections.gd::create` currently gets silver through
  NPC loadout definitions plus other existing items/cloth/corpse. No production coin/gold projection.
  Future coin/gold needs explicit shared item+stack projections; currency value stays authored data,
  not serialized cached wallet. Duplicate silver would invalidate projections.
- `runtime/persistence/oldpine_world_save_capture.gd` captures the same graph + allocator and calls
  restore preparation as validation. `oldpine_world_restore_composition.gd::prepare` injects the exact
  restored Equipment/Armor into Player/NPC, preserving independent body facts and the existing ledger.
  `world_content_revision.gd` and public source save policy remain SOURCE_ENTRY_V1, schema2 only.
- DECISIONS already says item schema1 omits pending combined-destruction intents. A snapshot during
  the positive-old-amount window restores that amount with no pending callout. Do not silently change
  that ledger entry or claim that a future delayed executor would already have durable continuation.

**INFERENCE:** Coin/gold stacks, ordinary payment and settled Bank quantity/ID changes require no
structural save-field change. Existing arrays/IDs/int64s suffice; adding production definitions to
the explicit restore inputs is still necessary. Old source saves lacking coin/gold can remain valid
without granting any new items; older binaries will reject new definitions (no backward-binary promise).
Keeping SOURCE_ENTRY_V1 is a reasonable **candidate**, not a demonstrated S3B round-trip PASS.
Future S3B must prove exact pre-S3B source-save restore and post-operation cold recapture, including
over-cap state, allocator continuation, no born-again spent stacks and no accidental orphan saves.

If an owner choice adds durable outstanding exchange/pending destruction, that is a separate state/
save-contract question; do not invent schema3 to avoid choosing the lifetime boundary. Bank geometry,
population/ledger changes are excluded here and need their own compatibility analysis. No schema or
revision changed in S3A; S2's recorded exact pre-S2 main-save proof is historical evidence, not this
slice testing a future implementation.

## SOURCE ANOMALIES AND OWNER DECISIONS REQUIRED

These are **proposals, not entries in DECISIONS.md**. Each row separates literal semantics from a
native substitute. A = source-faithful gameplay; B = explicit observable native compatibility
substitution; C = new design, not authorized. Names A/B below are option labels, not automatic approval.

| Issue | SOURCE FACT / exact observable result | Current Native capability | Native option A | Native option B | Compatibility consequence / recommendation | Gate |
| --- | --- | --- | --- | --- | --- | --- |
| A — affordability2/equality/false-positive1 | Coin100 buying100 returns2; silver1 buying100 returns1; gold1+silver1 buying9900 returns1 then pay error. | No finance service; typed denomination/amount inputs available. | Type A: preserve exact presence tests/strict comparisons and distinguish2 from0. | Type B: explicit corrected exact-denomination feasibility test; no auto-change. | B admits source-rejected coin purchases and can reject partial-debit paths before mutation. Recommend owner explicitly choose, with A as default semantics; do not inherit S1's unapproved broad fix. | **OWNER DECISION REQUIRED** |
| B — payment partial mutation / alleged change | No change creation; gold can decrement and silver become pending before error. No explicit success return. | Existing ordered amount results + lifecycle intent; typed error can expose completed mutations. | Type A gameplay + Type B error signaling: preserve ordered debits, report terminal typed failure instead of driver error. | Type B: simulate/preflight denomination debit before mutating to avoid partial loss; refund/rollback is another observable variant. | Recommend ordered result unless owner elects the bounded no-loss correction. Creating automatic change or seller accounts is Type C, NOT a default fix. No change-delivery cleanup is needed because no such source path exists. | **OWNER DECISION REQUIRED** for error/partial-debit substitute; no change-mint authorization |
| C — Bank new-target move failure | New amount1 fails move; target set to k ownerless; source still debited after announcement; return1. Cleanup later/infrastructure, not room code. | Transfer returns typed failure but leaves registered parentless item; lifecycle can remove it; save can retain it if left registered. | Type A visible order/lifetime intent: retain transient object until a narrowly specified cleanup opportunity; requires lifetime/Save ownership, not permanent orphan storage. | Type B: retain failed-move/source-debit order and consumed ID, then immediate existing-lifecycle cleanup plus typed delivered=false. | Recommend B for bounded native graph hygiene **only if separately approved for Bank**. It changes lifetime/return presentation, not compensation. Type B alternative: reject/no debit; dropping money on ground is additional observable policy, not legacy. | **OWNER DECISION REQUIRED**; S2 grants none |
| D — existing growth and default-one admission | Existing target bypasses move; new target checks only one unit then grows; both may end over cap. Source remains carried during admission. | Stack growth already has no cap veto; transfer can exactly check amount1 first. | Type A: preserve both ordered paths, cap equality, warnings as result facts, no new growth limit. | Type B: require net/final weight within cap or pre-size target before transfer. | Recommend A; B changes valid source conversions. Net-weight and pre-sized gross-weight policies differ and must not be conflated. | **OWNER DECISION REQUIRED** before any alternate capacity rule |
| E — atomicity | Exchange credits/attempts target BEFORE source debit; buy debits BEFORE goods; normal failures can expose partial results. | Existing services report partial operations; persistence reconstruction atomicity is a different boundary. | Type A: retain independently ordered operations/results; never call whole commerce atomic. | Type B: preflight/all-or-nothing Bank or payment with an exact separately specified policy. | Recommend A + narrowly approved C cleanup/error handling. Do not generalize a Bank choice to vendor, pawn or S2. Atomic economy policy is not implied by transactional Session Load. | **OWNER DECISION REQUIRED** for transactional substitution |
| F — money ownership/selection | Finance can mutate ground money; Bank direct-only; one object per alias, no recursive sum, visibility matters. | Explicit endpoints + stable IDs; no implicit present runtime. | Type A scope + Type B deterministic representation: explicit direct Player then bounded current-place candidates, chosen identity documented; extra world boundary needed. | Type B: Player direct currency only, explicit denomination IDs, deterministic selection; no bag/ground fallback. | Recommend B as a bounded native ownership contract; disclose source ground-money access removal. Do not silently sum all owned descendants or implement world wallet. | **OWNER DECISION REQUIRED** |
| G — full depletion and pending destruction | Zero requests leave old positive amount/weight; later callback destroys object; repeated operations/Save can retain or reuse value in that window. | Core emits intent; runtime does not execute it. Item schema1 intentionally omits intent. | Type A timing intent: add narrowly owned one-second runtime execution later, preserving old amount and cancellation semantics; pause/Save policy must be specified. | Type B: execute depletion through lifecycle immediately in specifically approved payment/exchange operations; no old amount window, no new persisted timer. | Recommend resolving G before S3B; never ignore the intent (unbounded free currency). B is pragmatic but changes weight, repeated-use and Save behavior; S2 cleanup is NOT authorization. Do not globally rewrite Combined. | **OWNER DECISION REQUIRED** |
| H — supported conversion domain / identity anomalies | Explicit paper and same-type conversions exist; no MONEY check; unusual IDs/base_values can reach division/method errors or hidden-stack overwrite. | Stable definitions, no arbitrary LPC methods; int multiplication currently unchecked in currency/weight helpers. | Type A on supported canonical positive definitions; same-type transient growth preserved; unsupported legacy cases explicit. | Type B: whitelist coin/silver/gold requests, reject same-type; ordered typed invalid/overflow errors. | Recommend coin/silver/gold as first bounded scope, paper explicitly deferred, same-type retained if admitted. Limiting arbitrary aliases is explicit translation, not a new counterfeit subsystem. Do not invent clamp/rates or overflowing success. | **OWNER DECISION REQUIRED** for changed rejection behavior/invalid arithmetic policy |
| I — vendor fulfillment after payment | Goods new/move can fail after payment; normal move0 still announces purchase; stock mapping unchanged. | Item transfer/lifecycle present; no vendor runtime. | Type A future vendor order + explicit orphan lifetime boundary. | Type B future vendor preflight/compensation policy. | No selection now: defer vendor-specific decision until its slice; cannot borrow Bank/Work rule. | **OWNER DECISION REQUIRED before future Vendor implementation**, not permission to start it |

The Bank cleanup recommendation specifically considers nine aspects: legacy Player receives no
target after move0; this follows ignored return + later source debit; transient lifetime belongs to
MudOS cleanup; native registration otherwise persists; A retains that transient boundary, B immediately
cleans, no-debit/refund or ground-drop are further observable options; classifications/compatibility
are in C/E/G; B is recommended only with fresh owner approval. This is not exact cleanup-timing parity.
Arithmetic allocation failures have no proved legacy int64 boundary; any future typed failure must
record its actual reached stage and prior mutations, not pretend that cloning never happened.

## PROPOSED S3B BOUNDARY — NOT AUTHORIZED

**INFERENCE / review proposal only:** after the owner chooses affected rows, implement just shared
coin/gold definitions alongside existing SourceSilver, explicit denomination lookup, typed affordability,
ordered payment and Bank conversion using the same Inventory/Combined/Index/Allocator/Lifecycle.
Define full-depletion handling and exact error/result shape first. No new repository/service framework.
Do not automatically include Bank map/NPC, vendors, purchases or consumables in that approval.

Independent future tests should use the tables above: all0/1/2 equality boundaries and presence-vs0;
direct-vs-bag/ground policy; gold→silver→coin debit trace; can1 followed by payment error; no change
objects/no RNG; original requested quantity check before Bank rounding; preserved remainder;
same-type identity; existing growth vs default-one new move; exact cap/overcap/new-target rejection;
source quantity exhausted vs partially reduced; cleanup/allocator/Save behavior for each chosen failure;
pre-S3B save load and fresh graph cold recapture with exact new currency IDs. Expected results must
label any owner-approved divergence separately from original LPC. These tests are NOT implemented here.

## OUT OF SCOPE

S3B, Bank runtime/geometry/access/population, coin/gold production integration, payment service,
vendor purchasing, waiter/Inn food/drink, recovery scheduler, Snow NPC population, school/bamboo sword,
apprenticeship/teaching, smithy/herbs/hockshop/postoffice/temple/revive, Lake and Phase5B4 remain out.
No gameplay/source/config/backups/build/CI/test/scene/schema edits; no PR, merge, branch/worktree
deletion or owner-local cleanup. No S3A recommendations are promoted into DECISIONS.

## VERIFICATION / EVIDENCE

Source functions and native dependencies above were read directly; repo-wide call/entry searches
were reviewed for commented-out code. Twenty arithmetic affordability vectors were cross-checked
in a transient in-memory desk calculation against the written branch predicates, not a new gameplay
test or a running LPC interpreter. No historical suite/runtime requalification is justified for this
docs-only slice. S2's122/canonical18438/Python46 and desktop proof remain S2 evidence, not S3A results.

Precommit checks PASS: existing `tools/ci/repository_checks.py`; all61 local Markdown link targets
across the three changed documents; trailing whitespace; `git diff --check`; and the exact
three-document changed-path allowlist. New untracked document content was included explicitly.
Review both ranges separately: main→HEAD includes the already-approved S1/S2 implementation and
S2's17-line DECISIONS entry; starting `241a33a`→S3A must contain only this document and minimum
STATUS/ROADMAP synchronization. Production/tests/scenes/schema/reference/DECISIONS/build/CI
S3A deltas were verified0. No aggregate sanitizer or live game is claimed/run; ignored Godot AI backups
remain untouched. Final execution results and immutable commit are reported to the owner.

## STOP STATE

S1 OWNER APPROVED / CLOSED. S2 OWNER APPROVED / CLOSED.
S3A analysis complete / awaiting owner review, not owner-approved.
S3B NOT AUTHORIZED. Snow major has no final PR or merge.
Commit/push only these documents on the same branch, then stop for owner direction.
