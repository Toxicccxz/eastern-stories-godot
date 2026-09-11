# S2 — Snow Workplace Income + Source Currency Composition + Minimal Access

Status: **S2 IMPLEMENTATION COMPLETE — AWAIT OWNER REVIEW**. S1 is owner-approved/closed.
Branch: `phase/snow-town-core-hub`; starting HEAD `c5f4472e147dba79c1eb6fd520debcd2e873a879`.
Base main: `047f29083e881156abbdad6ed480bffc1350dfa8`. No PR/merge or S3 authorization.

## Source and dependency check

Inspected under `reference/es2/mudlib/`:

- `d/snow/workplace.c`, `square.c`, `mstreet1.c`, `mstreet2.c`;
- `obj/money/silver.c`, `std/money.c`, `std/item/combined.c`;
- `feature/damage.c`, `feature/move.c`, `feature/clean_up.c`;
- `include/globals.h`, `doc/applies/clean_up`, `doc/mudlib/feature/clean_up`.

The repository ES2 driver configuration's cleanup setting is infrastructure, not a fixed
Work-relative gameplay timer. No external port was used; source remains unchanged.

## Eligibility and resource mutation order

`workplace.c::do_work()` has **one** `gin < 30 || sen < 30` condition and one failure response.
`TOO_TIRED` changes nothing and allocates no reward. There is **no busy rule**, cooldown, work
duration, skill/progression reward, recovery or RNG in this action.

Success is synchronous: `receive_damage("sen",30)` → `receive_damage("gin",30)` → create
silver → amount 1 → attempt delivery. Native `spirit.current` then `essence.current` use the
existing damage methods; effective/maximum values, kee, food/water, potential/experience,
Player body facts/capacity and skills are untouched. Exactly 30 succeeds to 0; it does not
invent an unconscious transition. Fresh 100/100 becomes 70/70, 40/40, 10/10; fourth Work rejects.

## Composition / currency authority

`SnowWorkService` is one typed, stateless room-action composition with `SnowWorkResult`, not a
job system, NPC service, wallet, reward registry or generic transaction framework.
`SnowOutdoorController` checks current active map/zone, live Player, open world gate, no active
fight, unpaused/input-enabled runtime and physical proximity (96 px) to the mill landmark.
The visible Work button calls the same action. Runtime reachability is not claimed as LPC busy.

`SourceSilver` holds global source facts: definition `es2:obj/money/silver`, legacy
`obj/money/silver.c`, money_id `silver`, base_unit 两, base_weight 37, base_value 100.
Its identity, stack compatibility `/obj/money/silver`, and value are the existing Old Pine
silver facts, now shared by Old Pine loadout composition and Workplace. Existing restore
projections already include silver; no second definition registration/catalog is needed.
Currency conversion/payment/change-making and coin/gold content are not implemented.

Each eligible Work consumes a fresh session allocator ID and creates/registers a real
ItemInstance + CombinedStack state, then uses the existing transfer/merge service. The newly
moved object survives compatible direct-inventory merging; previously held silver IDs are
removed through existing lifecycle authority. The index only forgets snapshots of IDs proven
absent from Inventory. Three Works leave one Player silver stack, amount 3, weight 111, not
three persistent stacks or a numeric balance. NPC loadouts and initial counts are unchanged.

## Source delivery failure

`silver->move(me)` may fail capacity after both resource costs and creation. Workplace ignores
its result; the new object is temporarily ownerless. General MudOS/driver cleanup later deals
with such infrastructure garbage; exact removal time is not an authored Work timer.

## Owner-approved compatibility substitution

On capacity failure, Native preserves spent sen/gin and consumed allocator sequence, invokes
existing `ItemLifecycleService.destroy_item()` on the new parentless leaf, then removes its
derived index snapshot. It returns `DELIVERY_FAILED_CAPACITY`. There is no refund, ground
drop, orphan persistence, timer or alternate destruction path. Cleanup failure is a typed
authority failure with an error, never a persistent-orphan fallback. Focused tests prove
that the established lifecycle handles this case safely. This is **not exact timing parity**;
only orphan infrastructure lifetime is substituted. One S2-only decision records owner approval.

## Physical topology / NPC boundary

The existing `snow.outdoor` resident gains three zones, not three new scenes/rooms:
`snow.square ↔ snow.mstreet1 ↔ snow.mstreet2 ↔ snow.workplace`. Native walking/Areas own
crossing; the mill has a stable scene landmark and narrow Work button, not an invented NPC.
Closed side routes have physical collision. Existing south/east Snow routes remain intact.

| Source | Active S2 route | Deferred / physically blocked | Source NPCs |
| --- | --- | --- | --- |
| mstreet1 | south square, north mstreet2 | east school1, west bank | none |
| mstreet2 | south mstreet1, east workplace | north mstreet3, west smithy | drunk 1 + scavenger 1, metadata only |
| workplace | west mstreet2 | no other source exit | none instantiated |

The LPC Workplace also sets no_fight. S2 does not enable Snow combat/population or create
actors from descriptive text. Its interaction rejects native fighting/frozen state.
No Snow NPC runtime, spawn ledger entry or simulated ambient behavior is added.
New wall shapes are read by the existing placement validator; legal zone seams and wall/void
rejection are tested without a duplicate coordinate authority.

## Save revision / compatibility precheck

**schema2 / SOURCE_ENTRY_V1 unchanged.** No required save field, existing zone ID, NPC ledger,
allocator format, content revision, public New Game profile or restore semantics changed.
New geometry lies outside the original five outdoor zones; the Square north wall opens only
the authorized route. All other resident maps, Player/Inventory/Stack/Index/Gate bindings remain
the same objects while walking. Restore creates fresh objects with exact semantic state.

Compatibility evidence is not only a newly constructed fixture: exact main `047f290...` was
exported into `build/s2-main-baseline`, run to produce a legal SOURCE_ENTRY_V1 save without
Player silver, and terminated. Current S2 restored it and recaptured an identical whole JSON
snapshot (`s2-main-save.log`, `s2-main-restore.log`, exit 0). No birth/refill/reward is synthesized.

Capacity-failure test uses QA-only cloth weight near capacity, never a production cheat. A writer
process performs real service allocation/failed transfer/lifecycle cleanup and production Save;
it exits. A second process uses a fresh manual Runtime Host's Continue and proves whole-snapshot
equality (resources, graph, RNG, position, sequence) and next-ID continuation. Existing dormant
Old Pine NPC items remain part of Session; “Player only has cloth” does not mean an empty world graph.

## Verification / distinct self-audit

- Focused `run_snow_work_tests.gd`: **122 assertions, 0 failures, exit 0**, including two
  separately terminated/started process gates and their internal checks. No double-counting
  child checks into the reported 122.
- Complete canonical `run_tests.gd`: **18,438 assertions PASS, 0 failures, exit 0** through
  `tools/ci/verify.py`; covers prior NGE/body/save/route, inventory/stack/lifecycle, NPC,
  combat, RNG and Shell regressions. Full suite ran once after final executable edits.
- Python tooling **46 tests PASS**; repository/static checks PASS; Godot **4.7.2** development
  editor validation PASS. Canonical log preserved at `build/s2-complete-godot.log`.
- Direct worktree `verify.py` aggregate exits 1 at sanitizer because ignored owner-local
  `game/addons/.godot_ai_update/backup/4.0.2` and `pending.json` contain forbidden development
  references. This existing workstation artifact is preserved, not a green aggregate claim.
  Sanitizing a repository-content copy (tracked + S2 untracked files, ignored backups excluded)
  passes; sanitized headless editor validation and canonical-main startup (120 frames) exit 0,
  without script errors. No sanitizer/build/CI edits or gate bypass.
- Self-audit rechecked source mutation order, no busy/RNG/recovery, typed graph ownership,
  incoming-stack survival, cleanup owner context, compatible save projections, exact boundaries,
  unchanged bootstrap/public entry and absence of S3 mechanisms.

## Live desktop acceptance

Canonical ApplicationShell launched through Godot AI; existing pre-start typed configuration was
used with isolated profile `s2-live-20260911` to protect owner saves. Only the canonical shell was
re-instantiated for that profile before the player route; no gameplay values were patched.
Chinese name 雪工 was entered with Unicode key events into the focused LineEdit; female and
Start Journey used real mouse clicks. This is desktop input evidence, not an Android IME claim.

Real movement: Inn → Square → mstreet1 → mstreet2 → Workplace. Real Work clicks produced
70/70 + 1, 40/40 + 2, 10/10 + 3; fourth TOO_TIRED, sequence stays 4, all three RNG streams and
authority references unchanged. Escape → actual Pause Save succeeded. Process **80160** ended;
fresh process **49788** began with zero Session, then real Continue restored Workplace at
`(324.3333435, -748.0007324)`, resources10/10, silver3, sequence4. Entire saved/captured snapshot
matched, SHA256 `c6d81e45ab0905d2fbec55230aebeeeb16b98feedea71db32470ca9e3bc0602d`.
Real west/south walking returned to Square `(1.66672, 0.0000024)`, Work UI hidden, four residents.

Helper/session/capture health true; live non-stale frame observations included 8343 → 13737 →
19529 before restart and 7161 after restart. Final current-run game log contains no errors.
One preliminary QA eval mixed indentation and paused
the debugger; it was discarded and the successful run restarted. No production error is inferred
from that QA mistake. No direct controller Work/traversal calls substitute for this live path.

## Deferrals and stop

No bank, exchange, payment, purchases, food/drink, recovery, school, smithy, mstreet3, teaching,
apprenticeship, Snow population, Lake or Phase5B4. S3 may be considered only after owner review
and its own authorization; the compatibility decision does not generalize to other transfers.
No PR, CI trigger, merge, branch deletion or worktree deletion. Owner-local tooling remains intact.
