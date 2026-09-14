# S3B — Currency Exchange / Payment Core Implementation

Current owner-review status: **OWNER APPROVED / CLOSED**. Recorded during the authorized
[S4A analysis](PHASE_SNOW_TOWN_CORE_HUB_INN_VENDOR_CONSUMABLES_CONTRACT.md); S4B and the final
Snow PR remain unauthorized. The implementation/evidence body below preserves its original checkpoint.

## Scope and authority

Branch: `phase/snow-town-core-hub`; exact starting HEAD
`dc2a07ee9d8871b66fba88fa3ac102f447700696`; main
`047f29083e881156abbdad6ed480bffc1350dfa8`.
S1/S2/S3A are OWNER APPROVED / CLOSED. S3B is implementation only, awaiting owner review;
Snow major remains unmerged, with no final PR or next-slice authorization.

Owner decisions A–H were committed **before production implementation** in `85d5754`
(`Record owner-approved S3B finance decisions`). [DECISIONS](DECISIONS.md) is authoritative;
[S3A](PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_CONTRACT.md) retains historical archaeology.
No choices for Vendor, Bank physical content, paper money or accounts were added.

Directly re-read LPC sources (all below relative to `reference/es2/mudlib/`):
`feature/finance.c`, `cmds/std/buy.c`, `feature/vendor.c`, `std/room/bank.c`, `d/snow/bank.c`,
`obj/money/coin.c`, `obj/money/silver.c`, `obj/money/gold.c`, `obj/money/thousand-cash.c`,
`std/money.c`, `std/item/combined.c`, `feature/move.c`, `feature/clean_up.c`.
No running LPC interpreter is claimed; literal tests derive from these branches and approved substitutions.

## Architecture / files

All paths in this section are relative to `game/`; each new `.gd` has its Godot UID sidecar.

| Layer / files | Responsibility |
| --- | --- |
| `core/finance/currency_denomination.gd`, `currency_arithmetic.gd` | Canonical enum and checked nonnegative int64 addition/multiplication; failure is not clamped success. |
| `core/finance/currency_stack_selection.gd`, `money_affordability_result.gd`, `source_affordability.gd` | Selected identity/presence/amount and pure exact source 0/1/2 decision tree. |
| `data/items/source_coin.gd`, `source_gold.gd`, `source_currency_definitions.gd` | Explicit three-definition lookup, including unchanged shared SourceSilver; no global mutable registry/alias resolver. |
| `application/finance/money_inventory_context.gd`, `money_mutation_result.gd` | Borrow existing Inventory/Combined/Index/owner Equipment+Armor, deterministic direct-child lookup and S3B lifecycle composition; no owned graph/balance. |
| `application/finance/money_payment_service.gd`, `money_payment_result.gd` | Independent affordability and ordered payment; typed reached stage, selected IDs, residual and completed/failed mutations. |
| `application/finance/bank_conversion_service.gd`, `bank_conversion_result.gd` | Ordered canonical conversion with existing Session allocator, transfer and lifecycle results. Caller supplies Player's established maximum encumbrance, not strength-derived capacity. |
| `data/oldpine/oldpine_native_item_definition_projections.gd` | Add coin/gold item+stack restore inputs only for SOURCE_ENTRY_V1. Silver remains the existing shared definition. |

No existing Inventory/Combined/Equipment/Armor/allocator/Save implementation was rewritten.
Services are synchronous RefCounted composition, with no scene, Timer, UI, Bank NPC, scheduler,
RNG, Wallet, transaction manager or second persistence model. The borrowed context is for one
Player call; passing NPC authorities is not a new authorized NPC finance integration.

## Canonical money and selection

| ID | money_id | value/unit | weight/unit | unit | stack compatibility |
| --- | --- | --- | --- | --- | --- |
| `es2:obj/money/coin` | coin | 1 | 1 | 文 | `/obj/money/coin` |
| `es2:obj/money/silver` | silver | 100 | 37 | 两 | `/obj/money/silver` |
| `es2:obj/money/gold` | gold | 10000 | 37 | 两 | `/obj/money/gold` |

The real ItemInstance/CombinedStack amount remains money authority. No new starting money,
NPC loadout, world spawn or silver duplicate. Definition/source metadata follows existing SourceSilver.
Lookup selects the lexically first stable instance ID of each denomination among direct Player
children, not insertion order, recursive holdings or a sum of duplicates. It neither merges nor mutates.
Present amount0 is distinct from absent. Ground, bag descendants and other-character holdings are ignored.
Removing finance's implicit ground fallback is **F / Type B**, not literal `present()` emulation.

## Affordability and ordered payment

**A / Type A:** positive P; selected values G/S/C. Reject0 if checked total<P. Coin present:
reject2 if C<P%100; absent: reject2 if P%100!=0. Silver present: **only if coin also present**,
reject2 if S+C<P%10000. Silver absent: reject2 if P%10000!=0. Otherwise1.
Enum first three outcomes preserve these meanings. No exact-change solver or mutation.
Coin100/P100 remains2; silver1/P100 and gold1/P10000 remain1; gold1+silver1/P9900 remains1.

**B/E:** `pay` does not call affordability. Checked total insufficiency rejects before debit.
Process gold (remaining>=10000), silver (>=100), coin (>0). Sufficient gold/silver value removes
floor(remaining/unit), then takes remainder; insufficient denomination value subtracts its whole
value then fully consumes that stack. Insufficient coin is not consumed and returns typed failure.
Final positive residual also fails. Earlier changes remain; no refund, rollback, seller credit,
change or allocation. Gold2+silver1 paying19900 ends gold1, silver removed, residual9800.

**G / S3B-only Type B:** full consumption calls existing Combined zero-intent then ItemLifecycle
immediately, forgetting index only after authoritative success. The shared Combined implementation
still returns its historical delayed-destruction intent elsewhere. No stale spendable window,
timer or pending-destruction Save model is added. Failed lifecycle yields AUTHORITY_FAILURE with
its actual result; it does not silently succeed or fall back to another removal path.

## Bank conversion and failures

**H:** only canonical enum requests; unsupported target/source explicit, no arbitrary aliases,
counterfeit definitions/per-instance exchange values or paper production. Target validity precedes
source lookup failure; source presence precedes requested>=1 and holding>=**original requested**.
For lower→higher value, q=requested-requested%(target_value/source_value); q0 rejects without mutation.
Otherwise q=requested. k=q*source_value/target_value with integer arithmetic. E.g. coin199→silver
credits1 and debits100, leaving99; silver101→gold leaves1. No fees/RNG/accounts.

**D/E:** existing target grows by k first, without transfer/capacity admission/allocation, then
source loses q. Same denomination is the same selected object: 7→10→7 for q3, not an optimized no-op.
New target: allocate once → register canonical amount1 item/stack/index → attempt transfer at its
one-unit weight → set full k → debit source q. Source still weighs its old amount during admission.
Equality at capacity passes; successful growth has no final/net-weight veto. Example max1000:
new coin with silver2 and contents999 ends1062; existing coin1 with contents1000 ends1063.

**C / separately approved Bank Type B:** ordinary amount1 capacity rejection still sets target k,
debits source, immediately removes fully exhausted source (G), then lifecycle-removes parentless
target and forgets derived index. DELIVERY_FAILED retains allocation/transfer/debit/cleanup evidence.
No Player target, refund, ID reuse, drop, persistent orphan, timer or retry. Example coin200 at
contents1000/max1000 converting100 to new silver: final coin100, contents900, no silver, sequence+1.
Existing silver counterpart ends silver2/contents937. Cleanup failure is an explicit authority failure
and may leave the reported registered object: **no claim of orphan-free success on authority failure**.
This policy is neither a reuse of S2 authorization nor a precedent for Vendor.

Arithmetic is checked at its reached stage, not as an all-or-nothing preflight. Amount/own-weight/
aggregate nonnegative weight overflow fails before the corresponding unsafe shared arithmetic;
this is not a gameplay capacity clamp. Bank multiplication occurs after creation/move, as in source:
a late multiplication failure may retain a successfully moved amount1 target and consumed ID without
source debit. Parentless failed-delivery targets are cleaned on the error exit where applicable.
Existing-target overflow stops before target mutation. No literal LPC int-width/driver-error parity
is claimed; H authorizes typed checked errors. Unexpected transfer/creation/lifecycle failures stop
at their actual stage with completed changes visible, never a synthetic transactional rollback.

## Persistence and acceptance evidence

Root schema2 and SOURCE_ENTRY_V1 are unchanged. Existing embedded native item snapshot captures
identity, definition, parent, own weight, amount, equipment and allocator. New definitions only
extend restore inputs; they do not grant items when loading older saves. PlayerBodyFacts remain
independent runtime facts. No second balance, ledger, schema3 or SOURCE_ENTRY_V2.

Test files: `tests/runtime/snow_finance_test.gd`, `tests/run_snow_finance_tests.gd`,
`tests/run_snow_finance_cold_process.gd`, `tests/run_snow_pre_finance_save.gd`, plus canonical
registration in `tests/run_tests.gd`. Literal expected tables include all19 required affordability
vectors, zero presence, independent/duplicate/ground/bag/NPC selection, payment partial failure,
lifecycle failure, conversion rounding/order/capacity, same-type transient amounts and int64 edges.
Test sections check completion so a GDScript error cannot silently shorten a passing test section.

- Focused Godot4.7.2: **182 assertions, 0 failures, exit0**.
- Six scenarios each run writer then reader in independent OS processes: denominations, settled
  payment, existing target, new target, over-cap result and failed delivery. Actual production Session,
  Save repository/coordinator and fresh manual Host Continue; full encoded recapture equals the saved
  snapshot, then allocator advances without collision. RNG state remains exact. No shared writer objects.
- Overcap cold fixture uses QA-only cloth weight to hit admission equality; final contents153626
  survives save/restore exactly. No production capacity or item formula is altered.
- Exact **pre-S3B dc2a07e** archived production (only added test harness) generated a real source
  New Game + one Work save. Current code read it in a separate process via production Continue;
  full snapshot equality proves no currency grants, Player/location/silver/allocator reset. Both exit0.
- Full canonical `game/tests/run_tests.gd`: **18,620 assertions, 0 failures, exit0**; one complete
  run after focused validation, including S3B's182 and all prior regressions. No script errors in log.
- Python tooling: **46 PASS**; repository/static checks PASS.
- Final changed-file whitespace check:0; local Markdown links:68 checked,0 broken;
  `git diff --check` PASS. Only the S3B production/tests/docs and generated UID sidecars changed.
- Development and repository-content sanitized Godot4.7.2 headless editors: exit0, no script errors.
  Existing sanitizer retains finance/data and removes tests/Godot AI. Input is tracked + nonignored
  current files; ignored owner-local Godot AI update backups are not sanitizer input and remain untouched.
  This does **not** claim the known direct-worktree aggregate sanitizer issue is fixed.
- Early test-only mistakes (wrong result field/type) were corrected; their aborted runs are not PASS
  evidence. Early sandbox root-certificate denial was environmental; final isolated authorized runs
  have no such error. Logs and test storage remain ignored under `build/`, not owner Save/config.

These are local automated composition/process tests, not a live Bank UI walkthrough or GitHub CI.
No physical Bank exists in this slice, so no such live proof is claimed or required. Complete prior
runtime regression remains covered by the canonical suite, not by a new manual world tour.

## Distinct self-audit / stop

Rechecked the production decision tree against LPC and owner A–H after focused tests; reviewed
application/Core dependencies, checked arithmetic, lifecycle/index ordering, same-type source reread,
default-one admission, no shared mutable authorities and unchanged Save/body/world boundaries.
No unrelated shared-system rewrite was required. Complete baseline diff and nonignored new files
are reviewed before commit; reference/es2, scenes/UI/NPC, build/CI/export and project.godot deltas0.

Deferred: Bank physical access/UI/NPC, Vendor/payment→goods delivery policy, paper money, arbitrary
aliases/custom values, deposits/withdrawals/accounts, consumables/recovery, Snow population/training,
Lake and Phase5B4. Future callers must use live Player authority/max capacity and inspect typed partial
results; affordability1 is not permission to assume payment success. No final PR or merge is authorized.

**S3B IMPLEMENTATION COMPLETE — AWAIT OWNER REVIEW**.
