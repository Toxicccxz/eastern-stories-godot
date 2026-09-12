# S3C — Snow Bank Physical Access + Exchange Interaction

## Baseline and authorization

Implementation complete / awaiting owner review on `phase/snow-town-core-hub`.
Starting local/remote HEAD: `5fc0627447c299b943c55789c02860a99bf4a54c`.
Main remains `047f29083e881156abbdad6ed480bffc1350dfa8`.
S1/S2/S3A/S3B are OWNER APPROVED / CLOSED. Owner also closed S4A **analysis** and
authorized this dependency-driven physical-access slice, not S4B.
S4A item K is resolved operationally: provide denomination access before Vendor.
S4A A–J recommendations are not promoted to decisions; DECISIONS is unchanged.

## Source and scope

Directly rechecked authoritative LPC:

- `d/snow/mstreet1.c`: west Bank, east school1, south Square, north mstreet2.
- `d/snow/bank.c`: 安记钱庄, east mstreet1, sign describing currency conversion,
  one authored `d/snow/npc/annihir` object. No NPC is implemented here.
- `std/room/bank.c`: `init()` registers room-level `convert`; the exchange
  does not call the NPC. `deposit` has no implemented body. No account service.
- `feature/finance.c`: exact affordability branches, including absent-silver rejection.
- `obj/money/coin.c`, `silver.c`, `gold.c`: values1/100/10000, weights1/37/37,
  default amount1; coins 文 and silver/gold 两.
- `std/item/combined.c`, `feature/move.c`: amount/weight changes, merge identity,
  default-one capacity admission and ordered mutation dependencies.

All paths above are relative to `reference/es2/mudlib/`. Existing S3B typed
conversion/payment implementations and locked compatibility choices remain unchanged.
This is Type A rule reuse plus Type B physical/UI translation, not new Type C design.
Source Bank room parity is **not** complete: its authored NPC remains deferred.

## Native physical representation

`snow.bank` is another zone of the existing `snow.outdoor` resident; legacy path
`/d/snow/bank`, display 安记钱庄. Only neighbour is `snow.mstreet1`, in both directions.
The original linear `ROUTE_ZONE_IDS` corridor is unchanged.
The existing mstreet1 west wall is split for a walk-through door; the east school
wall and north/south routes remain. Bank north/south/west walls and counter use
CollisionShape2D, so runtime collision and existing Save placement validation agree.
Bank floor spans x[-500,-100], y[-550,-250]; exchange marker at (-375,-400).
Counter occupancy is blocked. Boundary reconciliation uses existing half-open zones.

No new map, portal, load screen, Player, Session, account or NPC is created.
The narrow exchange interaction is embodied by `SnowOutdoor/BankExchange`,
not by a fake banker or a general commerce registry.

## Composition and input

`SnowOutdoorController` borrows live Player, InventoryState, CombinedStackCollection,
WorldItemInstanceIndex, EquipmentState, ArmorState and SessionItemIdAllocator.
It passes independent Player `maximum_encumbrance` to unchanged
`BankConversionService.convert()`. No copied inventory, balance, arithmetic or wallet.

Available only inside the tree, initialized, unpaused, controlled ACTIVE Player,
world gate open, no active fight relationship, current outdoor/bank location,
within96 of counter marker, and valid physical character footprint.
An inactive detached resident cannot service exchange. Work availability remains separate.

`SnowBankInteractionResult` describes BLOCKED / INVALID_INPUT / CONVERSION; the last
case retains the actual S3B BankConversionResult including stage and partial mutations.
`SnowBankExchangePanel` supplies typed denomination IDs, quantity text, Convert and feedback.
Strict decimal parsing accepts positive int64, including leading zeros; empty, zero,
negative, fractional, signs, whitespace, exponent and overflow reject without mutation.
It never uses float conversion, SpinBox rounding or clamping. Same denomination is allowed.
Editing quantity or navigating a denomination popup quarantines held movement through the
existing input boundary; movement resumes only after release. No new world timing authority.

Displayed amounts use the same `MoneyInventoryContext.select()` as conversion:
one deterministic selected direct-held canonical stack, not recursive or duplicate-stack sum.
Authority failure displays an error indicator, not a fabricated zero balance.
Normal failures distinguish missing currency, invalid quantity, insufficient quantity,
round-to-zero and capacity delivery failure. Exceptional failures show safe text and
log the typed outcome/stage; raw enum numbers are not player-facing.

## Ordered conversion and denomination evidence

No algorithm is recomputed in the controller. S3B preserves original requested-amount
validation before upward-conversion rounding; target credit precedes source debit.
Existing target growth has no new admission check. A new target allocates and attempts
movement at amount1, then receives its full quantity. Same-type conversion is not blocked.

Fresh source Work twice consumes sen/gin30 twice, creates/merges real silver2;
silver1 → coin100 leaves silver1 + coin100, gin40/sen40, no other Work changes.
The natural fixture proves allocator continuation1 → 2 → 3 → 4 (birth, two Works, new coin);
tests compare relative sequence progression, not a new hard-coded allocation rule.
No gameplay RNG is consumed by exchange.

The separate one-Work controller fixture converts its last silver: coin100, no silver
object, `can_afford(15)` = DENOMINATION_REJECTED (source2). The two-Work setup retains
silver and returns AFFORDABLE (source1). No Vendor/product/purchase is instantiated.

Capacity controller fixtures prove:

- At capacity150000, absent coin target's one-unit move fails; ID consumed, silver
  debited/depleted, target immediately destroyed through S3B authorized lifecycle/index
  cleanup. No target reaches Player/ground/Save; no refund. UI says capacity failure,
  original currency spent, target not received. This is the separately approved **Bank**
  policy, not an extension of S2 or a precedent for Vendor.
- Existing coin1 target at capacity150000 grows to101, then silver1 is removed:
  final contents150063. No allocation/admission/preflight final-weight rejection.
- Same-type conversion retains identity and net amount; malformed duplicate stacks
  display/use lexical-first7, not total107.

## Save / cold Continue

Root schema2, embedded item schema and SOURCE_ENTRY_V1 unchanged.
Existing scene-driven placement validation recognizes Bank additively.
Automated terminated writer/fresh reader processes verify entire encoded snapshot equality
inside Bank, exact semantic IDs/weights/parents, resources/body, RNG, position and allocator.
The fresh reader allocates the next ID without collision.

Before changing production, exact `5fc0627…` was archived and imported in an isolated
directory. Its unchanged `run_snow_pre_finance_save.gd` generated a valid source save with
one Work reward. Current code loaded that file via fresh Host Continue, compared its
entire snapshot and verified allocator continuation. No relocation, extra coin/gold,
state refill, ID reset or compatibility migration is added.

## Verification and distinct self-audit

Local Godot4.7.2-stable, isolated test storage:

- Focused `run_snow_bank_access_tests.gd`: **384 assertions, 0 failures, exit0**:
  S3C80 + unchanged S3B182 + S2/physical regression122. Child-process assertions are not
  inflated into this count.
- Complete canonical `run_tests.gd`: **18,729 assertions PASS, exit0**, no SCRIPT ERROR.
  This is the observed full-run count, not a sum inferred from historical phase reports.
- Python tooling: **46 tests PASS**; repository/static checks PASS.
- Development and repository-content sanitized headless editor: exit0, no script errors.
  Isolated Windows engine prints a root-certificate-store diagnostic; it is recorded,
  not represented as a gameplay/parser failure or silently removed from logs.
- Repository-content sanitizer retains Bank production scripts/scene and S3B services,
  strips tests/QA/Godot AI. Ignored owner-local update backups were neither copied into
  that input nor modified; no claim that direct-worktree sanitizer ignores them.
- Exact pre-S3C save compatibility PASS.

Separate diff/source/architecture review: finance Core/service files untouched; no
runtime scheduling, NPC, goods, Wallet, bank accounts, schema/revision change or school
opening. The earlier S2 west-boundary test was updated precisely because Bank is now open;
school blocking and original Work route remain tested. Test fixture errors during initial
development were corrected, including activating the real resident before controller calls;
aborted sections fail explicitly. The focused final run is clean.
Source/reference, DECISIONS, build/CI/export and owner-local tooling deltas are zero.
Precommit checks include changed-document links, trailing whitespace and `git diff --check`.

## Real desktop player validation

Canonical ApplicationShell, existing pre-start isolated profile `s3c-live-20260912`.
Only Shell storage configuration was replaced before the route to protect owner saves;
no Player money/resources/location were injected. Unicode key events entered 雪银;
female and Start Journey used real buttons.

Real action input/CharacterBody/Area route:
Inn → Square → mstreet1 → mstreet2 → Workplace; two real Work clicks → silver2/40/40;
west/south to mstreet1, west into Bank; real Convert → silver1 + coin100.
Observed price15 query1, sequence4, exact same live authority objects and unchanged RNG.
Real east exit reached mstreet1; further east stopped at x70.993, school still blocked.
Walked back to Bank and used Escape → Pause → Save.

Writer process **76612** terminated. Fresh process **17132**, zero Session at menu,
real Continue restored Bank at **(-339.741424560547,-399.666412353516)**, 40/40,
silver1/coin100, body80000/capacity150000, sequence4, exchange available.
Full encoded saved/restored snapshot SHA256:
`9a40f42f89431090bd125a252da5e1c303b378557633e518ae95f0aad95eb79b`.
No special Bank restore/reset code is involved.

Further real movement was stopped by north/west/south exterior walls at y-520.993,
x-470.924 and y-279.004; Bank zone retained. Counter is separately placement-tested.
Helper_live/session_active/game_capture_ready all true, current-run game errors absent.
Non-stale captures: writer frame353593; fresh reader frame7080. Retained old editor
errors during initial launch were explicitly distinguished from clean current-run logs.
This is desktop evidence, not a new Android/iOS qualification claim.

## Deferrals and stop

Bank `annihir`, deposit/withdraw/accounts, all Vendor/Inn goods/consumables, recovery,
school/training, other Snow population, Lake and Phase5B4 are not implemented.
S4B remains NOT AUTHORIZED. No new compatibility decision.
No final Snow PR, merge or branch/worktree removal. Local PASS is not remote CI evidence.
Commit/push this slice on the same milestone branch, then await owner review.
