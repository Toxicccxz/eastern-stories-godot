# S6B — Fresh Water Supply Loop

## Status and authority

**S6B — OWNER APPROVED / CLOSED** at `add8d32107277fef7cc57a4a121c64b6b9b5c027`.
Owner closeout recorded during S7A; the implementation evidence below is unchanged.
No final Snow PR or merge. S7A is analysis only; S7B implementation is not authorized.
Branch: `phase/snow-town-core-hub`. Starting local/remote HEAD:
`945a8bde0d8d2734f737b51fb6619cf42e8ff5cd`; main/merge base:
`047f29083e881156abbdad6ed480bffc1350dfa8`.
S6A is **OWNER APPROVED / CLOSED** at the starting HEAD. Its original scan is retained in
[S6A](PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md).

Owner A–M choices were recorded **before production changes**, in decision-only commit
`8b577b9b55ebd69b8063046f3277d1cb7e84bcfa` — `Record owner-approved S6B water decisions`.
Implementation/tests/docs follow in `Add fresh water supply loop` on this same branch.
The [DECISIONS ledger](DECISIONS.md) is the exact approved boundary, not a new proposal.

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment,
interaction translation and presentation. This slice preserves source wine/Fill/water semantics
(Type A) within explicitly approved interaction, access and persistence substitutions (Type B).
It is not a Type C redesign, full liquid system, alcohol implementation or complete Snow hub.

## Sources and the approved boundary

Source files consulted/rechecked (all under `reference/es2/mudlib/`, unchanged):

- `feature/liquid.c`: complete Drink/Fill order, +30, no clamp, empty survives, retained drunk metadata.
- `obj/example/wineskin.c`: complete canonical definition and independent initial liquid mapping.
- `d/snow/npc/waiter.c`, `feature/vendor.c`, `cmds/std/buy.c`: offer, price, creation/delivery order.
- `feature/finance.c`, `obj/money/coin.c`, `obj/money/silver.c`, `obj/money/gold.c`,
  `std/item/combined.c`, `feature/move.c`: unchanged payment/quantity/weight/capacity boundaries.
- `feature/damage.c`, `feature/skill.c`: water capacity and effective dodge dependencies.
- `d/oldpine/epath2.c`, `d/oldpine/waterfall.c`: Vine branches and first water source.
- `d/oldpine/riverbank1.c`, `d/oldpine/riverbank2.c`, `d/oldpine/cliff1.c`,
  `d/oldpine/cliffside.c`, `d/oldpine/pine1.c`: existing physical return route; River water deferred.

A selects only unlimited `waterfall.c::resource/water=1`, embodied as
`oldpine.outdoor.waterfall_basin`. No source depletion/reset/save object is introduced.
B supersedes **only playable SOURCE_ENTRY_V1** nonpositive Vine dodge: select existing Waterfall
without drawing, clamping the bound, fabricating a draw or modifying skills. Original `random(0)`
runtime semantics remain unproven; monotonic low-dodge branch selection is an **owner Type B choice**.
Other content revisions retain the existing ambiguity result. Positive dodge still performs exactly
one draw in `[0, dodge)`, `<5` Waterfall, otherwise Passage, rejecting invalid draws without retry.
The real source bridge action, presentation, destination validation and movement remain in use.

C/D preserve the actual offered item. E stages alcohol as explicit mutation-free refusal.
F preserves same-ID fill-over-wine. G preserves water decrement/+30 and legal live state boundaries.
H/I restrict use to Player-direct-held, ACTIVE world, noncombat, not busy.
J explicitly adopts the existing waiter Vendor failure policy **for wineskin only**, not Bank.
K/L define typed composition and embedded item3, without a second Inventory or root-version bump.
M requires a real nearby Waterfall point and a stable selected item; no direct environmental Drink.

## Canonical content and typed ownership

| Source field | Native authority / exact value |
| --- | --- |
| source identity | `es2:obj/example/wineskin`, legacy `obj/example/wineskin.c` |
| name / aliases / unit | `SourceWineskin`: 牛皮酒袋 / wineskin, skin / 个 |
| weight / value | definition700 /20; Inventory owns live weight700 |
| max_liquid | `LiquidDefinition.maximum_portions=15` |
| liquid/type, name | `LiquidState.Content.RED_WINE` → alcohol / 红酒; `CLEAR_WATER` → water / 清水 |
| liquid/remaining | `LiquidState.remaining`, integer0..15, independent per stable ItemInstanceId |
| liquid/drunk_apply | definition6, retained after Fill; never applied by water |
| liquid/drink_func | no generic hook/Callable; canonical water has no custom effect |

Fresh purchase is RED_WINE15, not empty or water. Ordinary ITEM+F_LIQUID is not a combined stack,
food, weapon or armor. That canonical fact is checked without imposing global role exclusivity.
No weight-per-portion: wine/full/partial/empty all retain own weight700 and value20.

`LiquidCollection` is one Session-owned typed association; Inventory remains existence, direct parent
and weight authority; ItemInstance remains definition identity. Register/definition/snapshot copies
are independent; live state is intentionally mutable only through the owning graph. UI stores only
selection identity and presentation, not resource/content authority. No dbase, generic payload,
condition scheduler, arbitrary effect dispatch, gameplay RNG or Node dependency enters liquid rules.

## Purchase ordering and failures

`WineskinPurchaseService` is the narrow second staged waiter offer, not a generic shop rewrite.
Existing Inn admission/proximity and S3B payment remain unchanged. Ordered stages:

1. Validate canonical item/liquid/persistence facts and price20 before spending.
2. Existing `can_afford()` results0/2 reject. Source coin-only denomination anomaly remains.
3. Existing ordered `pay()`; failed partial payment does not proceed to product allocation.
4. Allocate one unique session ID; register weight700, index, fresh RED_WINE15.
5. Transfer using **post-payment** current weight and actual maximum encumbrance.
6. On paid failure, retain payment/sequence consumption. Destroy only a safe parentless product via
   ItemLifecycle, then forget liquid association, then derived index. Cleanup failure is explicit
   authority failure, never success, refund, ground drop, orphan Save or delayed timer.

Independent literals: silver1+coin100 buys for20 → silver1+coin80. Post-payment weight is
37+80+700=817: capacity817 succeeds;816 rejects after payment and one allocation, then cleanup.
Malformed static offer rejects before payment. Allocation overflow occurs after payment and keeps
the spent20. Partial registration and rejected destruction have explicit tested outcomes.
Unlimited repeated purchases produce different IDs; no shared wine instance/finite stock.

## Fill / Drink and availability

`HeldLiquidUseService` receives narrow current availability/source/encounter facts. Runtime decides
physical availability; the rule layer owns the actual mutations. It never schedules recovery.

Fill: authority/ordinary availability → direct Player-held → busy/combat → source → valid canonical
liquid → replace content with CLEAR_WATER, remaining15. Full, partial and empty wine/water are valid.
It discards old contents directly, no extra item/confirmation/empty-first gate. Player water is
unchanged. Item identity/parent/weight/value, money, allocator, busy, conditions and RNG are unchanged.

Drink: authority/ACTIVE availability → busy → direct-held → combat → valid liquid. Wine returns
`ALCOHOL_DEFERRED` without mutation. Water then requires remaining>0 and water<maximum capacity.
Success **remaining -=1, then Player water +=30**, no clamp or immediate healing. Body80000 gives
capacity400:400 rejects;399→429;0→30. Empty0 remains alive and refillable. At429 the existing S5B
opportunities reduce water normally:29 opportunities→400 still rejected,30th→399 permits another.

Direct-held is not recursive/root ownership: ground, nested, NPC and wrong-character requests fail.
Paused/unpublished/staged/non-ACTIVE/transitioning/world-frozen requests fail; existing busy remains
busy. Encounter/fighting is a deliberate staged rejection, not source fighting-success busy2.
Neither action creates drunk or touches other character resources, conditions, skills or cadence.

The Session holds one `HeldLiquidPanel`, stable-ID selection across maps and truthful contents/remaining.
Wine's button explains deferred alcohol; Fill explains discarding contents. This is not an inventory
redesign. Presentation processes while paused solely to hide; authoritative action gates remain closed.
Waterfall's static `Marker2D` at(1200,900) requires the active map, correct authoritative zone,
valid physical placement and <=96 proximity. Merely being somewhere in Old Pine/Waterfall is insufficient.
River Gorge deliberately exposes no Fill. Clear-water Drink needs no water-source proximity.

## Persistence

Only embedded `NativeItemStateSnapshot` evolves2→3. Root remains schema2 / `SOURCE_ENTRY_V1`, identical
root keys and three saved RNG streams. No SOURCE_ENTRY_V2, liquid source depletion, cadence or UI fields.
`NativeLiquidConsumableRecord` contains stable ID, typed content, remaining. JSON encodes content as
`RED_WINE`/`CLEAR_WATER`, remaining as the established exact decimal-int string.

- Item1 accepts exactly five historical keys; empty food/liquid records.
- Item2 additionally requires food records; empty liquid records.
- Item3 additionally requires `liquid_consumables`.
- Decode legal1/2 into3, then current definition validation; resave writes3, not old-byte equivalence.
- Reject duplicates, dangling/non-liquid IDs, missing required state, unknown enums/extra/missing keys,
  negative/>15 remaining, wrong weight and unsupported schemas. Both content kinds0..15 are valid.
- Forged old wineskin records without state fail; never synthesize red wine15 or refill empty items.

Existing item capture/validator/restorer/composition own the format. Restore creates fresh liquid state
and derived index, borrowing the same restored Inventory/Equipment/Armor into runtime. Exact stable
IDs, parents, counts, allocator continuation, resource facts and RNG survive without allocation/draw.
Actual exact pre-S6B `945a8bde` writer generated a root2/item2 Save in a separate process; current
reader successfully continued it with empty liquids, food459/water399 and full normalized snapshot
equality. Continue left the original file bytes unchanged. Root1/pre-cutover saves remain unsupported.

## Local validation evidence

Validation uses Godot **4.7.2**, isolated test storage. Logs/artifacts under ignored `build/s6b-*` are
local execution evidence, not committed artifacts or GitHub CI. No complete remote gate is claimed.

- Focused `run_snow_water_tests.gd`: **118 assertions,0 failures,exit0**.
- Complete canonical `run_tests.gd`: **19,135 assertions,0 failures,exit0** on the frozen-code run
  (`build/s6b-canonical-frozen-output.log`). Focused log: `build/s6b-focused-acceptance-output.log`.
- Python `unittest discover -s tools/tests`: **46 PASS**; repository static checks PASS.
- Development editor/headless, repository-content sanitizer, sanitized editor and120-frame canonical
  startup: PASS/exit0. Known sandbox Windows root-certificate-store diagnostic is not a script error.
- Four independent write/read process pairs: fresh wine15, water15, water14, water0 PASS. All persisted
  state equality and file non-rewrite checked, not merely one selected liquid field. Empty writer's
  repeated water0 setup is explicitly a test fixture; it is not claimed as the natural player journey.
- Strict legacy1/2 fixtures, exact old2 separate writer/reader, malformed records, fresh object identity,
  allocator/RNG neutrality, positive/nonpositive Vine and source-derived arithmetic PASS.
- Changed-file trailing whitespace0;92 local Markdown links checked,0 broken; `git diff --check` PASS.

Sanitizer input is a copy of tracked/nonignored repository game content, not the owner workstation's
ignored Godot AI update backups. Those backups/configuration are preserved and not committed; no
direct-worktree sanitization claim is substituted for this repository-content validation.

Distinct self-audit rechecked source order, narrow Type B substitutions and changed production files.
It corrected overly specific wine display text back to authored 红酒 and a live Pause presentation
issue (panel failed to hide while inheriting paused processing). No recovery/combat formula changed.
Intermediate regression failures were stale item-version expectations, a test's incorrect assumption
that start_busy(0) clears busy, a one-frame UI test timing expectation, and one run loading a new text
assertion against its already cached old display class. Final runs use frozen code and retain exact
unrelated regression expectations; no cadence disabling or gate weakening was used.

### Real desktop journey — no gameplay-state injection

Canonical ApplicationShell; QA setup changed **only the empty Host's isolated storage profile**
`s6b-live-20260913`, before New Game/Continue. No position, skill, resource, money, item or RNG injection.
Real keyboard/actions, framebuffer clicks, CharacterBody travel, Area entry and actual UI were used;
Unicode name entry used InputEventKey, not direct LineEdit state assignment.

1. New Game 雪泉/female → Snow Inn → Square → Workplace; two Work actions; physical Bank.
2. Actual silver1→coin100 conversion, return Inn contact, actual purchase20:
   silver1+coin80; new wineskin RED_WINE15; allocator next5.
3. Real wine Drink returned ALCOHOL_DEFERRED, water391/remaining15 unchanged, conditions0.
4. Walk Snow east road→Old Pine north approach→East Bridge. Actual Hold Vine with unchanged
   effective dodge0 selected Waterfall landing(1200,780). World RNG stayed exactly
   `2314742684390040342` before/after; no fabricated draw.
5. Walk to(1200,897.333984), near Waterfall point. Actual Fill changed wine15→water15, Player water382
   unchanged. Actual Drink changed382→412 and15→14, no condition, allocator still5.
   The exact399→429 boundary is independently tested, **not misreported as the live value**.
6. Actual Pause Save at water410/food380, same position. Saved wineskin ID:
   `oldpine-session-8105ef4b9aee93ecb6c1e639458057fb.dynamic.4`, clear14,weight700,direct Player-held.
7. Terminated process82152; fresh process76528, real Continue then Pause. The full normalized captured
   snapshot equals the file, fingerprint `52e90c57148370e6b853183297246d9848ad53d7a736d544443b0dae56c6e058`.
   Same money, ID, content14, weight/parent, allocator5, location and all persisted RNG/Player facts;
   no refill/resurrection. Paused liquid panel now hidden; gameplay/liquid state frozen.
8. Resume and physically return Waterfall→River Gorge east bank→Cliff1→Cliffside→Pine Entrance
   (-80,469.333252). Actual climb UI/portal entry, no teleport or new shortcut. Existing authored
   bandit encounter `encounter:production:1` blocked further walking toward Snow. Read-only evidence:
   active_encounter=true, fighting=true, liquid_available=false. No aggression change; game stopped.

Helper evidence: helper_live/session_active/game_capture_ready all true. Nonstale frames advanced
(e.g.35254 during first Fill/Drink;49727 at cold-process return encounter). Successful launches had
current_run_errors=[]; retained editor warnings are not represented as clean-warning claims.
Before the successful journey, stale editor constructor metadata required a graceful editor restart,
and a mistaken QA-only read of a nonexistent method interrupted an earlier attempt. Those attempts
are not used as successful gameplay evidence. Restart normalized two default viewport settings;
only that unintended normalization was restored. Project configuration has zero intended delta;
owner-local plugin backups/configuration were not cleaned or changed.

## Changed areas and deferrals

Changes total32 production files,13 test files and7 documents across both commits (excluding UID
companions). Production: new `core/items/liquid/*`, `data/items/source_wineskin.gd`, `application/liquid/*`,
`ui/liquid/held_liquid_panel.gd`, typed liquid record; existing item snapshot/projections/codec/
validator/capture/restorer/composition; source item catalog; Session/save wiring; Inn controller/scene;
Waterfall controller/scene point; Vine policy/source-entry adapter. No second inventory or wallet.
Tests: new focused/cold-process runners and canonical registration; existing tests changed only for
embedded3, supported old1/2 conversion, or wineskin no longer being deferred production content.
Docs: this record, S6A owner-close annotation, current STATUS/ROADMAP/Native Save contract,
historical Vine supersession annotation; separate first decision commit.

Reference delta0. No Green/north Snow geometry, source edit, drunk, condition cadence, alcohol effects,
direct environmental Drink, River Fill, weight-per-liquid, generic shop/liquid engine, root schema
bump, recovery/combat timing change, offline/age/idle change, new player grant or return shortcut.
Existing S5B healing/metabolism remains active and supplies natural water depletion; new use never
invokes immediate healing. Remaining waiter inventory/NPC, other liquids and future content are
deferred, not silently treated as implemented. Wine-only Vendor cleanup must not generalize to Bank.

No PR created, no merge, no new CI claim; preserve branch/worktree/owner-local files. The next slice
is **not authorized**. Stop for owner review.
