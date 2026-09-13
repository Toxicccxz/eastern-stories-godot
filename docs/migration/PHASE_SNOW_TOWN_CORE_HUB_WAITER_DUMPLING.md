# S4B — Waiter + Dumpling Minimal Supply Loop

## Baseline and authority

**OWNER APPROVED / CLOSED** at `52ece42255c6094cd2378013245eb2f86e35d5ef`.
The owner subsequently authorized [S5A analysis](PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md)
only; the implementation evidence and stop-state wording below remain historical.
Implementation branch: `phase/snow-town-core-hub`.
Exact starting local/remote HEAD: `78b59f090e1497581d265741937cc43ab6ea94c7`
(`Add Snow Bank exchange access`). Main: `047f29083e881156abbdad6ed480bffc1350dfa8`.
S1/S2/S3A/S3B/S3C/S4A are OWNER APPROVED / CLOSED. No Snow final PR or merge is authorized.

Owner-approved A–J/H1 and sequencing K were recorded in [DECISIONS](DECISIONS.md) **before**
production changes, in `b00e787e453e92110610092b779d2e187c783faf`
(`Record owner-approved S4B vendor decisions`). The S4A recommendation table remains historical.
Vendor cleanup is separately authorized; it does not inherit/generalize Workplace or Bank cleanup.

## Source contract

Directly inspected LPC under `reference/es2/mudlib/`:

- `d/snow/inn.c`, `d/snow/npc/waiter.c`: actual ground-floor waiter and four offers;
  random greeting/NPC simulation and missing birthday cake dependency are not migrated.
- `obj/example/dumpling.c`: 包子 / `dumpling` / 个, value15, own weight80,
  food_remaining3, food_supply60; ITEM + F_FOOD, not Combined/weapon/armor/liquid.
- `cmds/std/buy.c`, `feature/vendor.c`: resolve/quote -> affordability -> pay -> clone -> move.
  Unlimited prototype-based stock; original Vendor reports success even after failed movement.
- `feature/finance.c`: reuse S3B's exact 0/1/2 affordability and ordered payment, including
  insufficient change when only coins are present; no wallet, automatic change or seller balance.
- `feature/food.c`: reject ghost/busy/empty/full; add food, set value0, decrement portions,
  then finish/destruct. Capacity check precedes addition; there is no post-add clamp.
- `feature/move.c`, `feature/clean_up.c`, `std/item.c`, `adm/simul_efun/object.c`:
  capacity/movement, eventual ownerless cleanup, inheritance and remove-before-efun destruction.
  Native uses existing Inventory/ItemLifecycle, not a driver compatibility layer.

`SourceDumpling` is the single content authority (`es2:obj/example/dumpling`,
legacy path `obj/example/dumpling.c`). Fresh shop quotes remain15 even after a purchased
instance's value becomes0. Three portions are one item, never three clones or Combined amount.

## Architecture and ordered results

- `FoodDefinition`, `FoodState`, `FoodCollection`: typed food-only facts; one collection owned
  by Session, keyed by stable item ID. Inventory still owns containment/weight; ItemInstance
  owns semantic identity; WorldItemInstanceIndex is a derived identity projection.
- Existing item persistence gains `NativeFoodConsumableRecord`; capture, validator, restorer
  and composition are extended in place. Restore creates a fresh food collection alongside
  fresh Inventory/Combined, preserving exact stable IDs and existing Equipment/Armor authorities.
- `DumplingPurchaseService`: narrow one-offer application composition. Resolves canonical
  item/food/persistence definitions and source quote before calling unchanged S3B services.
  After successful payment: allocate -> register full-weight80 item/index -> fresh3/value15
  food state -> Inventory transfer using **post-payment** carried weight.
- `DumplingPurchaseResult` preserves stage, price, underlying affordability/payment/allocation/
  transfer/removal evidence, paid and delivered. No ambiguous transaction bool or rollback.
- `FoodItemLifecycle`: item removal -> food association removal -> index forget. It borrows
  the established owner/inventory/stacks/index context; no money mutation is performed by eating.
- `HeldFoodUseService`: map-independent direct-Player-held, ACTIVE, ordinary world availability,
  no active combat and existing integer busy blocking. No new busy2, cooldown or scheduler.
- `SnowInnController`: stateless staged 店小二 contact at `(-240,-100)` on the existing main
  floor, outside birth/east-exit space. Proximity96 and valid active world/placement are required.
  One offer only; no contact NPC authority, spawn ledger, saved stock or runtime RNG.
- One `HeldFoodPanel` attached to Session projects direct-held instances on **all** resident maps.
  A stable-ID-backed selector targets one item; the UI owns no portions, money or containment.

Ordinary capacity failure keeps payment and consumed allocator sequence, destroys only the
provably parentless undelivered product, and truthfully reports paid/not delivered. Static bad
content rejects before payment. Allocation/index/food registration failure after payment does
not refund; safe partial parentless products use the same bounded Vendor cleanup. Cleanup
failure returns explicit authority failure with no fallback. Unknown ownership is never destroyed.

For price15: coin100 ->85, silver1 unchanged. Carried weight137 ->122; adding80 requires202.
Focused tests prove capacity201 rejects **after** paying/allocating/creating, while202 accepts.
No finite stock, denomination normalization, retry, orphan timer or merchant account exists.

## Food and lifecycle

Capacity uses existing `CharacterRecovery.maximum_food_capacity(PlayerBodyFacts.body_weight)`:
80000/200 =400. Strength and carried weight do not rebuild body authority.

| Before | Result | Food | Remaining / value |
| --- | --- | --- | --- |
| Fresh food400 | TOO_FULL, no mutation | 400 | 3 / 15 |
| Fresh food399 | accepted | 459 | 2 / 0 |
| Fresh food340 | accepted | 400 | 2 / 0 |
| QA food0, three accepted bites | +60 each | 60 ->120 ->180 | 2/0 ->1/0 -> removed |

Accepted order is resource addition -> value0 -> decrement -> terminal lifecycle. No clamp.
Dumpling has no authored finish_eat; the approved bounded final-bite path is immediate removal.
Failed final removal leaves the reached resource increase/value0/remaining0, returns authority
failure and fails live-food Save validation; it never rolls back or silently forgets a live item.
Ground/nested/NPC-owned items, combat and busy refuse without consumption. Multiple dumplings
remain independent. Existing death's default KEEP/containment transfer preserves food association;
there is no production corpse-decay scheduler. Future new destruction consumers must explicitly
compose associated-state removal after lifecycle, not assume Inventory or the UI owns food.

## Embedded persistence evolution

Root schema2 and `SOURCE_ENTRY_V1` remain unchanged. Root schema1 stays unsupported.
Only `NativeItemStateSnapshot.CURRENT_SCHEMA_VERSION` changes1 ->2.

- New capture/encoding writes embedded2 with deterministic `food_consumables` records:
  `{item_instance_id, remaining_portions, current_value}`. No duplicate weight/parent/shop state.
- Embedded1 accepts exactly the legacy five keys: schema_version, records, combined_stacks,
  equipment, armor. Decode upgrades to current typed state with an empty food array.
- Embedded2 requires those keys plus food_consumables. Unknown versions/keys and missing keys
  fail; gameplay integers retain the existing strict decimal-int64 string codec.
- Structural codec validation checks malformed/duplicate/dangling live records. Existing
  definition-aware NativeItemStateValidator checks the one-to-one food association and legal
  portions/value/weight before capture or fresh reconstruction. It rejects non-food associations,
  missing records and all combinations except dumpling3/15,2/0,1/0.
- Embedded1 containing a dumpling but no food record fails definition validation; never refill.
  There is no second Inventory model, ad-hoc food save file or mutation of a live Session on Load.

An isolated archive of exact pre-S4B `78b59f0` generated a real root2/SOURCE_ENTRY_V1/item1 Save
through the old Bank cold-process writer. Current code loaded it and compared **all fields**
semantically after only the explicit item version/empty-array representation change: Player,
body/resources/location/position, items/parents/weights/currency/hands/armor, allocator and all RNG.
No food was granted. Resave wrote item2; another fresh-process Continue retained complete encoded
snapshot equality. Old file bytes are deliberately **not** claimed identical after version upgrade.

## Verification and self-audit

Local execution evidence, not new GitHub CI:

- Dedicated `tests/run_snow_dumpling_tests.gd`: **489 assertions, 0 failures, exit0**,
  including105 S4B assertions plus existing S3C/S3B/S2 regressions.
- Complete canonical `tests/run_tests.gd`: **18,834 assertions, 0 failures, exit0**.
- Cold-process S4B write/read/finish/absent paths additionally exercise actual files, fresh Host/
  Session reconstruction, independent products and full-snapshot equality. Their subprocess
  checks are gates within the above counts, not inflated as separately counted assertions.
- Python tooling: **46 PASS**; repository/static checks PASS.
- Godot **4.7.2** development headless editor and repository-content sanitized editor PASS.
  Isolated engine logs retain the known Windows certificate-store diagnostic, not script errors.
  Sanitizer retains production food/contact/UI and strips QA/tests/debug helper.
  Owner-local ignored Godot AI update backups were neither sanitized in-place nor modified.
- Changed-file whitespace, Markdown local links, `git diff --check`: PASS.

Distinct implementation self-audit checked source mutation order and failure stages, no duplicate
finance/Inventory authority, defensive snapshot copies, fresh restored collections, strict embedded
schemas, real shared map-independent use and explicit staged omissions. Historical tests changed
only their current embedded-schema expectation1 ->2 / unknown-version test2 ->3.
No changes to reference/es2, build/CI/export, Bank arithmetic, recovery, combat or PlayerBodyFacts.

## Actual desktop acceptance

Canonical ApplicationShell, isolated profile `s4b-live-20260913`, no owner Save touched.
Real mouse/Unicode-key input created 包子客/female. Frame-timed movement and actual buttons:

1. Inn -> Square -> mstreet1 -> mstreet2 -> Workplace; Work twice -> gin/sen40, silver2.
2. Walk to Bank; Convert1 silver ->100 coin; retain silver1, food400, sequence4.
3. Physically return to Inn and approach 店小二; actual Buy -> silver1/coin85,
   `oldpine-session-6a8371cef7683fc5bf1055d19f6d5e2f.dynamic.4`, direct Player,
   weight80, portions3/value15, allocator5. No QA money, teleport or food change on this path.
4. Actual Eat at food400 -> TOO_FULL, unchanged3/value15. Then physically walk to Square;
   the same Session food view remains available outside the Inn.
5. **Explicit QA-only hunger setup** sets existing Player food to0. Actual Eat -> food60,
   same ID, remaining2/value0. Pause/Save, terminate PID39620, new process PID5016,
   real Continue -> exact complete saved snapshot, same position/parent/weight/allocator/food.
6. Actual Eat twice -> food180, no live item/food/index record. Pause/Save, terminate,
   new process PID58008, real Continue -> complete snapshot equality, no resurrection,
   allocator still5. No natural hunger/metabolism claim.

Helper health was verified: helper_live/session_active/game_capture_ready=true; non-stale
game frames advanced (purchase19178 ->21189; fresh partial Continue3818). Final process run42
had no game errors. Validation-only debugger mistakes (mixed-indentation eval, incorrect QA
Host path, incorrect QA snapshot field) were discarded/restarted or followed by fresh Continue;
they were not production failures and no gameplay was changed to repair helper connectivity.
The existing desktop virtual-keyboard unsupported warning is unrelated. Game was stopped afterward.

## Explicit deferrals / stop

Wine/liquid/drunk/receive_healing, dagger/actions, chicken/hammer/bone, missing birthday cake,
waiter body/combat/death/greeting/reset/AI/respawn, travellers, upstairs/rats, general Snow NPCs,
stock/merchant accounts, recovery/metabolism/hunger ticking, school/teaching/smith/herbs/hockshop/
postoffice/temple, Lake and Phase5B4 are not implemented or newly authorized.

This restores a staged commerce/food path, **not full waiter parity** or a natural hunger loop.
No PR, merge or next slice. Await owner review on the same Snow milestone branch.
