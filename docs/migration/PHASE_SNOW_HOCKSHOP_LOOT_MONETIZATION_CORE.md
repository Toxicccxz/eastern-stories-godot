# Snow Hockshop / Loot Monetization — H2 Typed Core

## Scope and baseline

H2 implementation complete; awaiting owner review, not a final milestone audit or integration.
Branch: `phase/snow-hockshop-loot-monetization`. H1 start:
`7dc3efcdbe7a27fd0d39ee648053dff6f7c612b7` (local/remote identical, clean index/worktree,
no PR). Main/merge base: `112f3208937c9f5a480b9f27588af811599937ac`, unchanged at start.
Standalone `021a996` — **Record owner-approved H2 Hockshop decisions** changed DECISIONS
only, before production changes. [A–N ledger](DECISIONS.md#hockshop-valuation--payout--sell-lifecycle-h2)
is approved authority; [H1 archaeology](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md)
is now OWNER APPROVED / CLOSED. H1's old options are not new permission.

Only typed appraisal, sell payout and lifecycle composition are implemented. No player access,
room/location gate, scene, controller, door, UI, pawn API, merchant stock or generic transaction
framework. H3 must supply physical permission and truthful result presentation separately.

## Source rechecked

Read-only paths relative to `reference/es2/mudlib/`:

- `std/room/hockshop.c` in full: value/sell gates, percentage, minimum, denomination order,
  ignored ordinary move return and payout-before-destruction. Pawn retained only as archaeology.
- `d/snow/hockshop.c`, `d/snow/hockshop2.c`: front-room actions, door and deferred back-room prose.
- `feature/move.c`, `std/item/combined.c`: equipped-before-move, strict capacity, full stack
  weight, living merge/incoming survival and zero-amount delayed destruction.
- `adm/simul_efun/object.c`, `feature/equip.c`, `std/equip.c`: remove-before-driver destruction,
  exact hand/armor cleanup, no secondary promotion and derived contribution removal.
- `obj/cloth.c`, `obj/example/dumpling.c`, `feature/food.c`, `obj/example/wineskin.c`,
  `feature/liquid.c`: absent cloth value, mutable food value and independent liquid content.
- `d/oldpine/obj/short_sword.c`, `long_sword.c`, `leather.c`: exact300/700/200 facts.
- `obj/money/coin.c`, `silver.c`, `gold.c`, `std/money.c`: money exclusion, canonical
  identity/weight/amount and distinct value() versus query("value").

Native dependencies inspected: MoneyInventoryContext/BankConversionService/CurrencyArithmetic;
CombinedStackService/Collection; Inventory/ItemLifecycleOwnerContext/Service;
Food/Liquid definitions/collections/state; EquipmentState/ArmorState;
WorldItemInstanceIndex; SessionItemIdAllocator; NativeItemPersistenceComposition/domain,
definition projections and existing finance/food/liquid/world-save test conventions.

## Typed valuation

`HockshopValuation.appraise` returns `HockshopValuationResult`, never display-string authority.
Outcomes distinguish SELLABLE, WORTHLESS, MONEY_REJECTED, UNSUPPORTED_ITEM,
INVALID_ITEM_STATE, NOT_DIRECTLY_HELD, ITEM_NOT_FOUND and AUTHORITY_FAILURE.
Results carry exact instance/definition, source value and actual payout. Sell invokes appraisal
again; retaining or modifying a prior quote cannot authorize stale identity/value/ownership.

Validation: complete borrowed authorities → live Inventory/index identity → Player direct parent
→ canonical currency rejection → supported leaf/catalog → valid associated state → checked quote.
Ground, null parent, nested, corpse-held/other-character items and containers are not sellable.
No inferred value from damage/weight/display name or definition-name patterns. Unknown is not zero.

| Current canonical non-money content | Authority | Value / actual sell |
| --- | --- | --- |
| `es2:obj/cloth` | Narrow immutable HockshopStaticValues | 0 / WORTHLESS; worn cloth retained |
| `es2:obj/example/dumpling` | Exact FoodState.current_value; valid portions/value pair | fresh15 / 12; bitten0 / reject |
| `es2:obj/example/wineskin` | Existing LiquidDefinition.value; valid live LiquidState | 20 / 16 for wine15/partial, water15/14/0 |
| `es2:d/oldpine/obj/short_sword` | Narrow immutable source projection | 300 / 240 |
| `es2:d/oldpine/obj/long_sword` | Same | 700 / 560 |
| `es2:d/oldpine/obj/leather` | Same | 200 / 160 |

Coin/silver/gold use SourceCurrencyDefinitions identification and reject before trade valuation.
Only five positive definitions sell; cloth and bitten dumpling are supported worthless states.
Food/liquid authority is not copied into a second price database. Current static gear does not
gain mutable depreciation. Malformed/negative data fails closed (Type B), without abs or minimum
payout. Arithmetic is checked value*80 followed by integer /100, then minimum1 for valid positive
value. Literal value1→1,124→99,125→100 and overflow cases are tested without expanding the catalog.

## Ordered physical payout and failures

`HockshopSellService` borrows one MoneyInventoryContext, FoodCollection, LiquidCollection and
SessionItemIdAllocator. Its payout invokes `HockshopPayoutService`, never BankConversionService.
No Node, signals, callbacks, async suspension, timers or RNG. Inventory still owns liveness/weight/
parent; other existing aggregates retain their own authority. No new persistence authority.

For each nonzero silver N/100, then coin N%100:

1. Allocate a durable ID; record allocation evidence even if the attempt later fails.
2. Register canonical item/index/stack at FULL quantity and weight before admission.
3. Check arithmetic integrity, not final/net capacity. Call existing transfer+living merge.
4. Maintain the derived index for successfully absorbed old IDs, including partial merge failure.
5. On ordinary CAPACITY_EXCEEDED, immediately lifecycle-destroy the parentless payout clone,
   then forget its index. Only after successful cleanup may the next denomination begin.
6. After all normal attempts/cleanups, destroy the sold item through existing lifecycle using
   the LIVE Player Equipment/Armor. Forget Food, then Liquid, then index after authoritative removal.

No gold payout even for10000 (silver100). Payout100 allocates only silver1;99 only coin99.
Incoming successful clone survives; old same-denomination IDs are removed. Failed allocations
which produced IDs remain consumed even when their clones are cleaned. No ID reuse, timer, ground
money, refund, compensation or release of sold weight/equipment before admission.

| Sword300→payout240, free capacity while still held | Silver2 weight74 | Coin40 weight40 | Delivered / sold item |
| --- | --- | --- | --- |
| 114 | delivered | delivered at exact equality | 240 / destroyed |
| 50 | rejected, immediately cleaned | delivered | 40 / destroyed |
| 90 | delivered | rejected, immediately cleaned | 200 / destroyed |
| 20 | rejected, cleaned | rejected, cleaned | 0 / destroyed |
| 74 | delivered at equality | rejected, cleaned | 200 / destroyed |
| 40 | rejected, cleaned | delivered at equality | 40 / destroyed |

Existing stacks do not bypass incoming full-weight admission. E.g. old silver1/coin5 with free50:
silver1 remains, new silver2 fails; new coin40 survives merged at45 and old coin5 ID disappears.
At free114, new silver survives at3 and new coin at45. Source payment order differs intentionally
from Bank's amount1 admission and existing-target growth.

Typed results separate overall SOLD/REJECTED/AUTHORITY_FAILURE, reached stage, quote, payout
attempts, delivered value, allocation/creation/transfer/cleanup evidence and final lifecycle result.
SOLD means the normal source-shaped sequence completed, NOT necessarily full payment. A merge
failure after successful transfer records the admitted money as delivered, without claiming success.
Do not automatically retry an authority-failed sale: earlier money may already be delivered.

Allocation/registration/stack/index/arithmetic/merge failure stops at its reached stage. Earlier
effects remain, no sold-item destruction or later denomination. Exceptional creation failure may
retain an incomplete parentless object; it is NOT normal capacity cleanup or a successful settled
sale. Failed cleanup similarly leaves evidence and stops. H2 invents no general compensation.
If final detach/removal fails, delivered money remains and item absence is not falsely reported.
Invalid graphs fail existing capture/validation. A coherent partial graph plus retained sale item
can still be structurally saveable; H3 must explicitly handle this unsettled-operation boundary,
not silently retry or label it complete. H2 does not change Save eligibility.

## Lifecycle / continuation proof

Primary and secondary short swords sell through exact hand cleanup; primary removal does not
promote secondary. Long sword clears its hand. Worn leather clears its exact cloth slot and
armor5/dodge−2 contribution through Armor authority. Fresh food removal forgets Food state;
all legal wineskin variants remove Liquid state without replacement/refill. Other items remain.

Root schema2 / embedded item schema3 / SOURCE_ENTRY_V1 are unchanged. Tests use existing full
WorldSaveCapture → GameSaveJsonCodec encode/decode → NativeItemPersistenceComposition and
OldPineWorldRestoreService candidate → activation → identical full recapture. Six cases cover
full/partial/no-delivery sword sales plus armor/food/liquid. No sold item/association returns,
no orphan/retry/refund, physical money exact, allocator includes failed IDs, next allocation is
collision-free, and all three saved RNG streams restore exactly. Recovery RNG consumes zero
draws during H2. Restored graph objects are fresh; semantic IDs remain exact.

Exact pre-H2 compatibility was separately executed: git archive of integrated main
`112f3208937c9f5a480b9f27588af811599937ac`, unchanged
`run_snow_spine_cold_process.gd write mstreet3` → terminated writer → current H2 reader.
PASS: complete recapture equality, source Work/silver/allocator/RNG/location exact, no file rewrite,
and normal physics after Continue. This is a serializer/runtime regression, not Hockshop UI proof.

## Verification and separate self-review

Local evidence (not GitHub CI):

- H2 focused: **298 assertions, 0 failures, exit0**.
- Complete canonical: **19,708 assertions, 0 failures, exit0**, including final H2 coverage.
- Python tooling: **46 PASS**. Repository/static checks PASS.
- Repository-visible content sanitizer PASS; sanitized headless editor and canonical startup exit0,
  no errors. H2 core retained; tests/QA/Godot AI stripped. Owner-local ignored backups untouched.
- Development headless editor PASS/exit0. Final focused/canonical/development/sanitized/baseline
  logs contain zero SCRIPT ERROR / ERROR / FAIL entries. All96 local file links in the five
  changed documents resolve. Trailing whitespace0; git diff --check PASS; forbidden deltas0.

Separate self-review checked source ordering, source-versus-Type-B distinctions, readonly quotes,
actual live authority borrowing, incoming identity, checked arithmetic, fault-path partial effects,
schema/RNG boundaries and lack of player access. Tests independently specify LPC-derived expected
numbers and observe creation/removal traces. Faults reuse existing typed Inventory/index/equipment
test doubles, not a production transaction or callback framework.

An initial unisolated sandbox editor invocation could not write the workstation Godot directories;
it is not PASS evidence. Subsequent validation uses isolated build-local APPDATA/LOCALAPPDATA,
without changing owner editor/configuration. Initial test syntax/mock-injection issues were corrected;
the final focused run above is clean. No helper-live/player-input claim: H2 has no changed physical
or UI path, so live Hockshop gameplay is not applicable. Sanitized startup is only a startup check.

## Deferrals / stop

H3 physical front room, local authored-closed reopenable door, proximity Value/Sell panel,
stale/failure UX, truthful partial payment and real-input journeys are NOT STARTED / NOT AUTHORIZED.
No hockshop2, pawn/redeem/tickets, merchant NPC/stock, arbitrary custom value/stack/container
commerce, weapon depreciation, economy rebalance, combat/recovery changes or new Save fields.
Reference source delta0. No project/CI/export/world/UI changes. No PR or merge; main remains the
integrated Snow Core Hub. One implementation commit follows the decision commit, then push/stop.

**H2 IMPLEMENTATION COMPLETE — AWAIT OWNER REVIEW**
