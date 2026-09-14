# Migration Decisions

## Snow First Progression P2 — owner-approved bounded teaching embodiment

**Authority:** Owner approved/closed P1 `5780139b82fad932f6bc7786ea295c20602ae0a5`
and authorized P2 A–F on `phase/snow-first-progression-loop` only.

**Decision:** Embody school1 → school2 → schoolhall as three continuous Snow outdoor zones.
The red gate supports physical Open/Close from both sides, defaults closed on cold start/Continue,
and is transient. Its closed collision footprint remains save-invalid even while open; no relocation
on load. Side routes, guard, fist trainer, trainees and the inner school remain deferred.

Liu Chunfeng is a bounded teaching contact, not a combat/persistent NPC. Preserve his authored
identity, all eleven skill levels and source teaching facts; expose only basic unarmed Learn.
Use existing LearnService, F_MASTER, improvement and combat formulas. One request makes at most
one gameplay draw from the existing saved world-interaction stream at the source progress point;
presentation text consumes none. No gifted experience, balance changes or advanced skill UI.

The public first-apprenticeship chain retains effective cor/cps ≥20, failed pending intent,
Cancel/retry, and idempotent master acknowledgement. Pending is transient per Player. Cross-family,
reverse recruitment and betrayal interfaces remain deferred. Correct active Session/map/zone,
placement, proximity, active life, noncombat/nonbusy and input quarantine are approved Type B
contact gates, not claims about LPC busy restrictions.

First recruitment records the complete source family/master/generation14, distinct family title
and privileges, swordsman class, actual UTC entry seconds, and source display title through a
controlled recruitment seam. No skills or rewards are granted. Owner permits the smallest strict
versioned relationship extension within root2; item3 and SOURCE_ENTRY_V1 remain unchanged.
Historical absent fields remain absent; historical nonempty relationships without an entry time
retain UNKNOWN/NOT_RECORDED, never load time. Old valid root2 saves must remain readable.

**Compatibility impact:** Narrow physical/contact staging only; not full school or Liu NPC parity.
Type C: none. Natural combat evidence may be BLOCKED; no gameplay correction is authorized to
manufacture success. Sources: `d/snow/school1.c`, `school2.c`, `schoolhall.c`,
`daemon/class/swordsman/master.c`, `cmds/std/{apprentice,recruit,learn}.c`,
`feature/{apprentice,skill,attribute}.c`, relative to `reference/es2/mudlib/`.

## Hockshop valuation / payout / sell lifecycle (H2)

**OWNER APPROVED — H2.** H1 is OWNER APPROVED / CLOSED at
`7dc3efcdbe7a27fd0d39ee648053dff6f7c612b7`. This A–N package is recorded in a
standalone decision-only commit before production implementation. It supersedes H1's
recommendations, not its source archaeology. No Type C redesign is approved.

- **A — Type B scope:** Value/appraisal and irreversible sell only. Defer pawn and its60%
  transaction, tickets, retrieve, custody, loan and auction; no dormant production pawn API.
- **B — Type B truthful omission:** Do not repeat the source ticket/redeem promise or invent
  redemption. The contradictory prose and low-value pawn formatting remain documented defects;
  reconsidering pawn requires a separate owner decision.
- **C — Type A ownership / Type B selection:** Exact ItemInstanceId replaces textual aliases.
  Appraisal and execution independently require current index/inventory existence, Player direct
  ownership and supported leaf content. Wielded/worn items remain eligible. Reject stale, ground,
  nested, other-character, corpse-held, container, living and unknown items; no recursive sale.
- **D — Type B typed representation carrying Type A facts:** Narrow hybrid: exact dumpling
  FoodState.current_value (fresh15, bitten0); valid wineskin Liquid association with existing
  immutable value20; static source projections cloth0, short sword300, long sword700, leather200.
  No universal mutable price, dbase dictionary, query emulator or merchant inventory. Known-zero
  and unsupported are distinct. Current swords have no new depreciation state.
- **E — Type A zero / Type B invalid-state boundary:** Zero appraises WORTHLESS and rejects
  sale with no allocation, payout or destruction. Negative/malformed/unsupported values fail
  closed explicitly; no abs, clamp-to-one or emulated broken coercion for invalid Native state.
- **F — Type A payout / Type B checked boundary:** Checked integer source_value*80 then /100;
  for positive valid values preserve pay_player's result<1→1. Overflow fails before allocation
  or mutation. Quote actual payout; no floating point or pawn calculation API. Fresh dumpling12,
  wineskin16, leather160, short sword240, long sword560.
- **G — Type A physical money:** Silver first (N/100), then coin (N%100), skipping zero.
  Never gold or wallet. Each attempt allocates a new canonical full-quantity stack BEFORE move.
  Do not reuse Bank's amount1 admission or directly grow an existing target. Normal merge retains
  the incoming ID and destroys old same-denomination stacks.
- **H — Type A ordered partial capacity result:** Sold item remains held/equipped during
  admission. Ordinary capacity refusal continues after its required cleanup; retain earlier
  delivered money and destroy the sold item after normal attempts complete, even if both fail.
  No refund, rollback, ground drop, final-total/net-weight preflight or existing-stack bypass.
- **I — NEW Hockshop-specific Type B cleanup:** Immediately after each ordinary capacity
  refusal, destroy that parentless clone through authoritative ItemLifecycle, retaining consumed
  allocator sequence/ID, BEFORE attempting the next denomination. No orphan persistence, ID reuse,
  cleanup timer or compensation. This deliberately replaces later MudOS cleanup, NOT its exact
  timing, and is separately approved, NOT inherited from Work/Bank/Vendor. Cleanup failure returns
  AUTHORITY_FAILURE, retains reached effects and stops: no later denomination or sold-item
  destruction. This supersedes H1's suggested all-attempts-before-cleanup order.
- **J — Type A payout-before-destruction / Type B authority errors:** After normal attempts and
  cleanups, use existing lifecycle with LIVE Player Equipment/Armor/Inventory/Combined authorities.
  Clear the exact hand/worn slot without invented secondary promotion; remove Inventory/stack,
  then Food/Liquid associations, then derived index. Allocation/registration/merge/cleanup or
  final detach/destruction errors stop with typed AUTHORITY_FAILURE and prior effects retained,
  never rollback or false success. Current non-money stack commerce remains unsupported.
- **K — Type B future physical scope:** H3 front room /d/snow/hockshop only; hockshop2 deferred.
  Narrow authored-closed reopenable local door, no generic door engine or persistent door state;
  fresh Session/cold Continue may restore the closed default. No H2 scene/topology/door changes.
- **L — Type B future interaction:** H3 physical room/proximity-scoped exact-instance Value/Sell
  panel, not global Inventory Sell, merchant NPC, stock/cash or anywhere-commerce. H2 provides
  no world permission or player-facing UI; physical gates belong to the separately authorized H3.
- **M — unchanged Save:** Root schema2 / embedded item schema3 / SOURCE_ENTRY_V1. No saved
  transaction, account, stock, ticket, door or sale history. Existing money, item absence,
  equipment/armor and Food/Liquid absence plus allocator continuation carry settled full/partial/
  zero-delivery sales. Restore allocates zero gameplay IDs; legal baseline saves remain supported.
- **N — staged authorization:** H1 closed; H2 typed core current. H3, distinct Final Audit and
  the one final milestone PR are NOT authorized now. Commit/push H2 then stop for owner review.

Sources: `reference/es2/mudlib/std/room/hockshop.c`, `feature/move.c`,
`std/item/combined.c`, `adm/simul_efun/object.c`, `feature/equip.c`, `feature/food.c`,
`feature/liquid.c`, `obj/cloth.c`, `obj/example/dumpling.c`, `obj/example/wineskin.c`,
`d/oldpine/obj/{short_sword,long_sword,leather}.c`, `obj/money/{coin,silver,gold}.c`.
See [H1 archaeology](PHASE_SNOW_HOCKSHOP_LOOT_MONETIZATION_CONTRACT.md). Prior service
failure policies, PlayerBodyFacts, economy, recovery and owner-local tooling remain unchanged.

## Snow north public spine and Core Hub finish line (S7B)

**OWNER APPROVED — S7B.** S7A is OWNER APPROVED / CLOSED at
`04c77650ea72d48cae1173a422a78c3c0188abd5`. Record these decisions separately before
production implementation. They approve the bounded S7A A–L recommendations, not a final
Snow audit/PR/merge. Source semantics remain Type A; the observable staged omissions and
physical embodiment below are **Type B milestone scope**, not authored source closures.

- **A — extent:** Extend the existing `snow.outdoor` resident continuously from mstreet2
  through distinct `snow.mstreet3`, `snow.mstreet4`, `snow.crossroad` zones. Preserve exact
  reciprocal north/south source adjacency; no new map, ordinary-walking portal or shortcut.
  Southwestern sroad2–5 and other optional branches remain deferred.
- **B — external boundaries:** Crossroad itself is required. Its north Goathill and east
  Green directions remain visible static closed content boundaries, with no destination
  definition, travel action, portal, guard, key or invented authored lock.
- **C — Hockshop:** Static east frontage only. No interior, NPC, appraisal, pawn/sell,
  payout/destruction, custody/ticket/retrieve or persistence. Source doors do not authorize
  generic door runtime. No failed-transfer cleanup decision is generalized to Hockshop.
- **D — Herbshop:** Static west frontage only. No interior, herbalist/woodcutter, medicine,
  inquiry, healing or poison cure. Frontage is not service parity.
- **E — Postoffice:** Static west frontage on mstreet4 only. No interior, officer, mailbox,
  mail fees, accounts, online/offline mail or fake local inbox.
- **F — School:** Later progression; mstreet1 east remains closed. No teachers, training,
  faction/apprenticeship or free weapon access.
- **G — Smithy:** Later commerce/weapon content; mstreet2 west remains closed. No hammer,
  repair or crafting.
- **H — ordinary interiors:** Exposed source services receive honest facades/signs and
  collision boundaries, not empty accessible interiors or unusable service buttons.
  These closures are staging, not claims that ES2 permanently closes the shops. mstreet4
  has no executable east exit: add no alley route, zone, interaction or future-region gate.
- **I — secret/storage:** herbshop1, secret_storage, weapon-storage puzzle and unrelated
  storerooms do not block this bounded milestone; no invented secret entrance.
- **J — healing:** Accept existing eligible S5B slow effective-resource recovery as the
  current healing finish line. Preserve cadence, food/water, condition freezes and lifecycle;
  no new recovery Timer, combat recovery, poison scheduling or medicine.
- **K — loot:** Excess-loot monetization remains an acknowledged high-value later commerce
  gap, not a Snow Core blocker. Do not add selling/value projections in S7B.
- **L — completion:** Source New Game, Work, Bank, dumpling, wineskin/water, eligible recovery,
  Old Pine link, north spine, honest deferred frontages/regions and old/new-position Save/
  Continue must work within existing authority. Keep root2/item3/SOURCE_ENTRY_V1; no new
  mutable street/door/NPC state or gameplay RNG use. All38 rooms are not required. A distinct
  Final Snow Audit is the next possible phase **only after S7B owner approval and separate
  authorization**; implementation completion does not close the milestone or authorize PR.

Sources: `reference/es2/mudlib/d/snow/mstreet2.c`, `mstreet3.c`, `mstreet4.c`, `crossroad.c`,
`hockshop.c`, `herbshop.c`, `postoffice.c`, `d/green/path6.c`, `d/goathill/mroad1.c`.
See [S7A analysis](PHASE_SNOW_TOWN_CORE_HUB_NORTH_STREET_CORE_SERVICES_REBASELINE.md).
No Type C redesign is approved; existing PlayerBodyFacts, item authority, prior service
failure policies and owner-local tooling remain unchanged.

## Fresh water supply loop (S6B only)

**OWNER APPROVED — S6B.** S6A is OWNER APPROVED / CLOSED at
`945a8bde0d8d2734f737b51fb6619cf42e8ff5cd`. These A–M decisions are committed separately
before implementation. They authorize no final Snow PR, alcohol runtime or next slice.

- **A — source selection:** First source is `d/oldpine/waterfall.c`, resource/water1,
  represented by `oldpine.outdoor.waterfall_basin`. Unlimited; no depletion, reset or cooldown.
- **B — narrow Type B Vine supersession:** For playable SOURCE_ENTRY_V1 only, effective dodge<=0
  selects the existing Waterfall branch through normal presentation/movement with zero World RNG
  draws. No clamp, fake draw, dodge mutation, skill grant or reverse cliff edge. Historical
  random(0) behavior is still unproven; this resolves the monotonic low-dodge intent, not new
  Type A evidence. Positive bounds retain exactly one existing draw, range [0,bound), <5 Waterfall,
  otherwise Passage; invalid draws remain typed failure. Other revisions and authored random-bound
  policies retain their previous ambiguity behavior.
- **C — canonical content:** Waiter sells `es2:obj/example/wineskin` from `obj/example/wineskin.c`:
  牛皮酒袋, aliases wineskin/skin, unit个, weight700, value/price20, max15, fresh alcohol/红酒15,
  drunk_apply6. Ordinary ITEM+F_LIQUID, not combined/food/weapon/armor. Unlimited fresh-ID purchases.
- **D — truthful fresh wine:** Preserve RED_WINE15, including through Save/Continue. No empty,
  clear-water or renamed substitute. Staged UI must explain incomplete alcohol support honestly.
- **E — Type B alcohol omission:** Alcohol Drink returns typed ALCOHOL_DEFERRED before mutations:
  zero portions/water/busy/conditions/RNG. No harmless wine substitute. ConditionSystem, drunk,
  missing receive_healing, recovery condition freeze and unconscious/revive remain untouched.
- **F — Type A fill and identity:** Full/partial/empty wine or water can be discarded/refilled
  to CLEAR_WATER15 on the SAME item/definition/parent/weight, zero allocation. No empty-first rule,
  poured-wine item or replacement. Authored drunk_apply6 remains; water never applies drunk.
- **G — water semantics and valid-state boundary:** Validate action/item, ACTIVE/in-world ordinary
  availability, busy, direct ownership, staged combat exclusion, valid positive remaining, then
  Player water<capacity. Success decrements one portion then adds30 water without clamping or
  immediate healing. Body80000 capacity400:400 refuses unchanged,399→429,0→30. Empty0 survives,
  with same ID/parent/weight700/value20/content. No food/condition/busy/RNG mutation. Native legal
  liquid states are remaining0..15; source arbitrary negative truthiness is not normalized.
- **H — Type B reachability:** Specific Player-direct-held instance only, no ground/nested/NPC/
  other-holder use. Distinct wineskins remain independent. This is not full LPC add_action reach.
- **I — Type B noncombat/ACTIVE staging:** Reject active encounter/fighting without busy or other
  mutation. Existing busy blocks but is not advanced/cleared. Successful noncombat use adds no
  busy; source fighting-success busy2 is deferred. Require published active Session, ACTIVE world
  Player and ordinary interaction availability; paused/staged/nonworld/dead/ghost use is excluded.
- **J — wineskin-specific Vendor extension:** Explicitly extend S4B waiter A–D ONLY to this offer.
  Resolve/validate item/liquid/persistence facts and canonical price before affordability/payment;
  malformed static facts reject free. Preserve S3B0/1/2 and ordered payment. After payment allocate
  → full-weight registration → index → fresh liquid state → post-payment capacity transfer.
  No pre-payment final-weight preflight. Paid failure retains money and sequence/ID consumption;
  destroy only safe parentless product through authoritative ItemLifecycle, then liquid association,
  then derived index. No refund/drop/orphan Save/timer/fallback. Cleanup failure is authority failure.
  Truthful paid=true/delivered=false. Dumpling remains unchanged; no generic Vendor/Bank policy.
- **K — Type B typed composition:** Session owns one LiquidCollection keyed by ItemInstanceId;
  LiquidState holds typed RED_WINE/CLEAR_WATER plus remaining. Definitions own max/hydration/drunk
  metadata/display/weight/value. Inventory owns existence/parent/weight. No UI text/dictionary/
  Callable/parent/price in mutable payload, duplicate inventory or generic consumable engine.
  Do not infer universal liquid-versus-food/weapon/armor/stack role exclusivity from this one item.
- **L — Type B embedded format:** Item schema2→3, deterministic typed liquid_consumables records
  of ID/content/remaining. Root schema2, SOURCE_ENTRY_V1, root keys and three saved RNG streams
  unchanged. Strict item1 five historical keys; item2 adds food_consumables; item3 also requires
  liquid_consumables. Unknown/missing/extra keys reject. Legal old1/2 decode with empty liquid
  records then current validation; explicit resave writes3, not old JSON byte equality. Never
  recreate fresh wine for missing state. Reject duplicate/dangling/non-liquid/missing records,
  unknown content, negative/>15 remaining, wrong weight/identity. Both content kinds0..15 valid,
  including empty live items. Restore fresh collection with exact IDs/parents/allocator, no draw
  or allocation/refill. Preserve supported root2/item1 food-validation behavior; root1 unsupported.
- **M — Type B bounded physical/UI scope:** Only Waterfall exposes environmental Fill, requiring
  current active-map/authoritative zone/valid placement/near-marker proof and selected direct-held
  instance. No map-ID-only access or direct environmental Drink. Static marker is not saved/item/NPC.
  Fill validates availability → ownership → busy/combat → water source → liquid facts, then sets
  CLEAR_WATER and max15; Player water unchanged. Held clear-water Drink is map-independent via one
  Session UI. Show contents/remaining and truthful wine-discard action. Riverbanks remain authored
  but staged; no Green/Snow north/Lake or new return shortcut. Work/Bank/dumpling and S5B unchanged.

Source facts: `reference/es2/mudlib/feature/liquid.c`, `obj/example/wineskin.c`,
`d/snow/npc/waiter.c`, `d/oldpine/epath2.c`, `d/oldpine/waterfall.c`, `feature/damage.c`,
`feature/vendor.c`, `feature/finance.c`, `feature/move.c`. See
[S6A archaeology](PHASE_SNOW_TOWN_CORE_HUB_WATER_DRINK_SOURCE_CONTRACT.md).
S4B wine deferral and single-offer boundary are superseded only as explicitly scoped above;
its historical evidence and unrelated decisions remain unchanged. S5B's embedded item2 checkpoint
is historical after L; its recovery behavior, independent body facts and timing remain unchanged.

## Player recovery / metabolism cadence (S5B only)

**OWNER APPROVED — S5B.** S1/S2/S3A/S3B/S3C/S4A/S4B/S5A are OWNER APPROVED / CLOSED.
These A–M choices supersede S5A's recommendations, not its source findings. This ledger is
committed separately before production implementation; it does not authorize a final Snow PR.

- **A — Type A count shape:** Preserve `5 + random(10)` stored countdown5–14 and source
  post-decrement semantics: reset5/6/14 yields recovery on eligible pulse6/7/15. At old0,
  draw/store the next reset before applying recovery. No fixed mean or reroll after a failure.
- **B — Type B timing:** Native S5B uses an owner-approved **2.0-second base pulse because
  the original wall-clock heartbeat period is not proven**. The bundled manual's usual2s
  is supporting context, not proof of ES2 deployment. Unblocked opportunities take6–15
  pulses (12–30 seconds of eligible Native time). Process all complete active-delta pulses
  synchronously in order and retain remainder; reject non-finite/negative time, no silent cap.
- **C — source busy ordering:** At each due base pulse inspect busy at entry. Consume the
  pulse's time but do not decrement countdown, recover, update conditions, advance busy or
  draw RNG. Busy1 still blocks. Existing busy authority remains the only advancement owner.
- **D — Type B staged combat omission:** Source permits nonbusy fighting recovery. S5B
  freezes accumulator/countdown during any active encounter or fighting relationship,
  consuming no recovery RNG/metabolism. Resume the same phase after combat. Do not change
  combat timing or use its scheduler as heartbeat; noncombat world-gate freezes also freeze time.
- **E — staged condition dependency:** Any active condition payload (including unsupported
  IDs or zero/negative durations) freezes the entire S5B phase. No handlers, duration mutation,
  expiry or RNG. Source condition→no-heal→recovery order cannot be partially activated by
  healing while its conditions are frozen. This is not source condition behavior/parity.
- **F — Player-only staged scope:** Exactly one Session-owned cadence for SOURCE_ENTRY_V1
  Player. None for NPCs, inactive residents, corpses or LEGACY_OLDPINE_V1 technical sessions.
  Invalid/unpublished/staged candidates cannot tick; unsafe handoff/swap freezes time.
- **G — Type B Pause:** Freeze the complete phase and resume its exact in-memory remainder
  and countdown, without catch-up or reroll. Menus never grant rest/recovery time.
- **H — no offline simulation:** Closed-app time causes zero recovery/metabolism. No clock,
  login/save timestamp, elapsed offline calculation or bounded catch-up is introduced.
- **I — transient phase:** LPC `tick` is static and not saved. Native Save does not reset the
  live phase; fresh Source Session/Continue creates accumulator0 and draws one initial tick.
  Do not save countdown, accumulator or cadence RNG. Map activation/handoff/rollback, Pause,
  combat and condition appearance/removal retain the same live authority without reroll.
- **J — independent transient RNG:** One typed private recovery random source, with injectable
  deterministic tests and dedicated production RNG; no global random state or use of combat,
  NPC-initialization or world-interaction streams. Continue draws only the new transient stream;
  the three persisted streams restore exactly with zero draws. No RNG field is added to Save.
- **K — unchanged Save contract:** Root schema2, embedded item schema2 and SOURCE_ENTRY_V1
  remain exact. Pre-S5B saves load without migration or new optional keys. Only existing
  character facts mutated by recovery persist. Capture is synchronous at a settled boundary;
  ordinary counting does not itself block Save. No cadence section or recovery timestamp.
- **L — ACTIVE-only staged life scope:** Freeze for UNCONSCIOUS/DEAD/other non-ACTIVE state;
  no recovery, metabolism, revive, ghost behavior or new lifecycle reconciliation. Only an
  existing legitimate return to ACTIVE resumes the retained phase. This omits source paths.
- **M — deferred age/idle:** No age/mud_age clock, idle timeout, user_dump, netdead/login
  heartbeat, age gifts or idle rewards/penalties. This is not a general heartbeat emulator.

Implementation must borrow existing `CharacterRecovery.apply_tick` with current raw magic,
force and spells, Player=true/no-heal=false only after the staging guards. No formula, food,
Work, Bank or Vendor changes. Water remains a real supply limit; no refill/starvation system.
Sources: `reference/es2/mudlib/std/char.c`, `feature/damage.c`, `feature/condition.c`,
`include/condition.h`, `doc/efuns/random`, `set_heart_beat`, `save_object`.
Archaeology: [S5A contract](PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md).

## Snow waiter / dumpling supply loop (S4B only)

**OWNER APPROVED — S4B.** These decisions take effect under the owner's S4B instruction.
S1/S2/S3A/S3B/S3C and S4A analysis are OWNER APPROVED / CLOSED. The historical S4A
recommendation table is not rewritten. This does not authorize a final Snow PR or later goods.

- **A — Vendor-specific Type B:** Resolve/quote, affordability, successful ordered payment,
  allocate/create goods, then attempt full-weight delivery. Ordinary capacity failure keeps all
  payment/depletion and consumed IDs/sequences. Immediately remove the provably parentless
  product through authoritative ItemLifecycle, remove associated food state only after removal,
  then update the derived index. No refund, ground drop, orphan persistence, timer or retry.
  Cleanup failure is an explicit authority failure; no fallback. This is separately approved
  for Vendor, not inherited from Workplace S2 or Bank S3B and not a general failed-transfer policy.
- **B — static validation / ordered failure:** Validate the supported offer, source price,
  item/food/persistence definitions before affordability/payment. Missing/malformed content
  rejects without payment or allocation, never substitutes a product/price. After successful
  payment, allocation/creation/registration failures retain reached money/sequence mutations.
  A known safe parentless live partial product may be cleaned using A's ordered lifecycle.
  Unknown ownership is not destroyed; cleanup failure has no fallback or compensation.
  Capacity admission still uses post-payment inventory, never an earlier final-weight preflight.
- **C — Type B truthful presentation:** Report paid=true/delivered=false when paid goods
  are not received. Suppress LPC Vendor's unconditional success text without changing money order.
  Preserve underlying affordability, payment, allocation, transfer and cleanup evidence.
- **D — Type A stock:** Unlimited clone-on-demand offers; every purchase creates a fresh ID.
  No stock counts, restock, cooldown, merchant money/inventory, sold-out state or stock Save.
- **E — Type B staged omission:** Waiter's missing /obj/example/cake remains deferred.
  No substitute cake, free supplies, birthday relay or persistent gift entitlement.
- **F — deferred wine contract:** No wineskin/red wine, water-only substitute, drunk,
  receive_healing repair or intoxication/lifecycle scheduling. Liquid/condition semantics
  require a later explicit contract.
- **G — Type B initial use reachability:** Eat only the specific Player-direct-held food
  instance, ACTIVE and outside combat with ordinary world interaction available. No ground,
  nested, NPC-held or combat use; no new busy2/timer. Preserve an existing applicable busy
  block. Use remains map-independent, never Inn-only or waiter-proximity-dependent.
- **H — typed state / exact semantics:** Session owns one typed food collection keyed by
  ItemInstanceId, associated with the existing item graph, not CombinedStack/scene/UI/payload.
  Dumpling starts portions3/value15; accepted bite adds food60 without clamping, sets value0
  and decrements one portion. Body-fact weight determines capacity; reject at food>=capacity.
  Final bite uses authoritative immediate item destruction, then removes food association
  and index. If removal fails, already-reached food/value/portion mutations remain, with
  authority failure, no rollback or fallback, and no legal successful Save checkpoint.
- **H1 — bounded embedded format evolution:** NativeItemStateSnapshot current version1→2;
  captures encode item schema2 and deterministic typed food records. Decoder accepts exact
  old schema1 keys as empty food state, or exact schema2 keys including food records.
  Unknown versions/keys, duplicate/dangling/non-food records and missing required food state
  reject. A schema1 dumpling without food state fails, never receives fresh portions.
  Legal live dumpling states are only 3/15, 2/0, 1/0. Root schema2 and SOURCE_ENTRY_V1 stay
  unchanged; root schema1 remains unsupported. Pre-S4B semantic continuation is preserved;
  resaving necessarily changes embedded representation1→2, not byte-identical old JSON.
- **I — deferred authored weapon goods:** No dagger/sword-action substitution, chicken/hammer,
  bone variant or their persistence. These remain real deferred waiter offers, not placeholders.
- **J — Type B staged contact:** One deterministic scene-owned 店小二 commerce contact in
  existing Inn main floor, with only the dumpling offer. No NPC character/body/equipment,
  RNG greeting, combat/death, reset/respawn ledger, AI, birthday relay or dialogue system.
  Static contact reappears as scene content on Continue; no mutable waiter Save record.
  Full waiter parity is explicitly not claimed.

**K — sequencing only:** Owner-approved S3C supplies natural Work→Bank→Inn denomination
access. No starter coins, Vendor change-making or denomination normalization is authorized.
S3B's exact affordability/payment anomalies and source price15 remain unchanged.

Sources: `reference/es2/mudlib/d/snow/inn.c`, `d/snow/npc/waiter.c`,
`obj/example/dumpling.c`, `cmds/std/buy.c`, `feature/vendor.c`, `feature/finance.c`,
`feature/food.c`, `feature/move.c`, `feature/clean_up.c`, `std/item.c`.
These are owner-selected boundaries, not a general consumables/commerce authorization.

## Currency exchange / payment core (S3B only)

**OWNER APPROVED — S3B.** The following A–H decisions are locked by the owner's S3B instruction,
not proposals. S3A is OWNER APPROVED / CLOSED. These decisions do not authorize Bank world/UI,
Vendor purchasing or a general economy framework.

- **A — Type A:** Preserve executable `can_afford()` presence checks, strict `<` comparisons and
  distinct 0/1/2 meanings, including false rejections and false-positive1. Coin100 paying100 is2;
  silver1 paying100 and gold1 paying10000 are1; gold1+silver1 paying9900 is1 although payment fails.
- **B — source order / typed errors:** Payment processes gold → silver → coin. Preserve mutations
  completed before a later error; return a typed failure at that stage. No rollback, refund,
  auto-change, new denomination minting or seller credit. Results expose completed mutations.
- **C — Bank-only Type B:** New target allocation and authored amount1 creation precede its
  one-unit-weight transfer attempt. On ordinary failed delivery, establish the converted target
  amount, debit source in source order, then immediately destroy the parentless target through
  ItemLifecycle. Forget index state only after authoritative removal. Keep consumed sequence;
  no refund/source restoration/drop/persistent orphan/timer/retry. Cleanup failure is an authority
  failure with no fallback. This is separately approved for Bank, not inherited from S2 or applicable
  to Vendor. Exact MudOS cleanup timing is deliberately not preserved.
- **D — Type A:** Existing target growth has no transfer/capacity admission. New targets move at
  amount1 before full growth and before source debit. No final/net/gross weight preflight or
  post-growth veto; over-cap results and strict-cap equality are retained.
- **E — Type A:** Payment and Bank are ordered, non-atomic operations. No generic transaction,
  compensation engine or rollback snapshot. Transactional native Save reconstruction is unrelated.
- **F — Type B:** Finance selects at most one stack per denomination from direct Player inventory
  only. No ground, NPC, bag/recursive or world fallback. Duplicate direct stacks use ascending
  stable-instance-ID selection without summing or merging. Presence remains distinct from amount0.
  Bank retains its source direct-only scope. Removing finance's ground-money fallback is explicit.
- **G — S3B-only Type B:** At each full-consumption point, complete denomination arithmetic,
  invoke existing lifecycle immediately and forget the index only after success before continuing.
  No stale-positive one-second window, timer or pending-destruction save state. Stop on lifecycle
  failure, retaining earlier mutations, without fallback deletion. Global Combined semantics and
  the existing item-schema1 omission remain unchanged outside this composition.
- **H — bounded Type B representation:** Only canonical coin(value1/weight1/unit文), shared
  silver(100/37/两), gold(10000/37/两). Exact source-path stack compatibility; no duplicate silver.
  Same-type exchange retains temporary target growth then source subtraction, not a shortcut.
  Reject unsupported denominations/aliases/custom per-instance values explicitly; use checked
  arithmetic, never overflow/clamp to success. Genuine thousand-cash content remains deferred.

**I — boundary, not a Vendor failure decision:** Vendor fulfillment remains deferred. S2, Bank
cleanup and payment decisions must not be generalized to future goods delivery or other commerce.

Sources: `reference/es2/mudlib/feature/finance.c`, `cmds/std/buy.c`, `feature/vendor.c`,
`std/room/bank.c`, `d/snow/bank.c`, `obj/money/{coin,silver,gold,thousand-cash}.c`,
`std/money.c`, `std/item/combined.c`, `feature/move.c`, `feature/clean_up.c`.
Reviewed archaeology: [S3A contract](PHASE_SNOW_TOWN_CORE_HUB_CURRENCY_EXCHANGE_PAYMENT_CONTRACT.md).

## Snow Workplace undeliverable reward cleanup (S2 only)

**Decision (owner-approved):** When the source work reward is created but cannot be moved to
Player because of capacity, Native preserves the already-applied sen30 then gin30 costs and
consumed SessionItemIdAllocator sequence, then immediately destroys the undelivered reward
through the existing ItemLifecycle authority. Its derived index snapshot is removed only after
authoritative destruction. Native does not refund the work cost, drop the reward, persist the
orphan or introduce a cleanup timer.

**Compatibility impact:** `d/snow/workplace.c` ignores `silver->move(me)` failure; source leaves
a transient ownerless object for later MudOS/driver cleanup (`feature/move.c`, `feature/clean_up.c`).
Immediate deterministic cleanup replaces only that infrastructure lifetime, not eligibility,
resource order, reward amount, inventory outcome or allocator consumption. Exact cleanup-timing
parity is not claimed. Cleanup failure is an authority error with no alternate destruction or
persistent-orphan fallback. This decision applies only to the audited Snow Workplace path; it is
not a general policy for future failed transfers.

### Native Character Entry

**Decision (owner-authorized NGE5B):** Native single-player New Game collects only display name
and an explicit legacy male/female gender selection. MUD account ID/password/email and account
security are not migrated. Name preserves the source meaning of 1–6 Chinese/Han characters,
counted as Unicode code points rather than old-encoding bytes. Invalid input is rejected without
renaming or trimming. Internal stable CharacterId and save keys remain separate from display name.

**Source / impact:** `reference/es2/mudlib/adm/daemons/logind.c::check_legal_name` (called by `get_name`) expresses 1–6 Chinese
characters through 2–12 bytes. The native validator uses Unicode Han membership and does not
recreate multiplayer account or banned-name infrastructure. Birth stats, explicit-save policy and
existing gender-dependent rules are unchanged; no other character creation choices are added.

## Pre-Cutover Development Save Compatibility

**Decision (owner-approved NGE5A1):** Development saves produced before the NGE5B public source
New Game cutover carry no compatibility promise. The project has not publicly released and has
no real-player save compatibility obligation. Schema1 is unsupported: no reader, migration,
upgrade, missing-field interpretation or guaranteed restoration is retained.

Current schema2 + `LEGACY_OLDPINE_V1` remains only as the pre-cutover technical New Game test
profile; it is not a historical-save compatibility contract and has no long-term stability
promise. It may be removed at NGE5B unless the owner establishes a new reason to retain it.
Schema2 + `SOURCE_ENTRY_V1` is the forward save baseline.

Unsupported files are rejected, not automatically deleted, rewritten or archived. Existing
New Game confirmation, explicit Save, primary/tmp/bak transactions, recovery and Session rollback
remain. No second slot or migration UI. NGE5A0 independent body authority and exact schema2
continuation are unchanged. This supersedes old-save A and only the v1 interpretation portion of
the body decision below; it does not authorize NGE5B or public New Game cutover.

## Player Body Facts and Native Continue

**Decision (owner-approved NGE5A0):** Player own body weight and maximum encumbrance are independent
typed runtime facts. Ordinary strength growth, including registered unarmed improvement, does not
refresh either value. Carry and death use those stored facts. Fresh Human initialization reuses the
existing source formulas once. NPC body authority is not merged with Player authority.

**Native continuation:** Future schema2 explicitly saves both facts and cold Continue restores them
exactly. Native Save/Continue does not emulate LPC full-login body reconstruction. Only a future
explicit source-backed body rebuild/transformation event may re-derive established facts.

**Legacy v1 interpretation — SUPERSEDED by NGE5A1 (historical record):** Existing saved maximum_encumbrance is authoritative even when it differs
from current strength*5000. v1 has no Player body_weight: derive that missing field once from saved
current strength, then retain it as runtime authority. Until schema2 exists, v1 capture fails closed
if runtime body weight differs from human_weight(current strength); it cannot silently lose that fact.

**Reason / compatibility impact:** In the same LPC body, unarmed's str+=2 does not invoke setup;
Human weight and chard capacity initialize only when zero, and corpse copies existing facts.
On a full new-body login, static move fields begin at zero and setup may derive them again from
saved strength. Native exact continuation deliberately does not reproduce that login-induced change.
This is a native save-continuation compatibility substitution plus a v1 missing-field interpretation,
not a new growth formula or a legacy world/profile upgrade.

Sources: `reference/es2/mudlib/daemon/skill/unarmed.c`, `feature/skill.c`, `feature/dbase.c`,
`feature/move.c`, `adm/daemons/race/human.c`, `adm/daemons/chard.c`, `adm/daemons/logind.c`,
`obj/user.c`, `std/char.c`, `feature/save.c`.

## New Player Delayed Gift Randomization

**Decision (NGE1 owner-approved B):** Fresh native Human Player starts at age14 with all eight
base attributes30. Do not implement `gift_tag`, a pending gift allocation, a gift RNG stream, or
the delayed age15 login overwrite. This is a **compatibility substitution**, not a claim of exact
legacy execution. Other authorized gameplay attribute progression remains allowed.

**Legacy:** `adm/daemons/logind.c::init_new_player` sets attributes30 and gift_tag; the later full
`enter_world` with age>=15 overwrites them with `10 + random(21)`. `obj/user.c::update_age`
establishes age14 initially. Future native age/mud_age progression MUST NOT automatically reintroduce
this overwrite; a fresh source analysis and owner decision are required first.

## Fresh Food / Water Initialization

**Decision (NGE1 owner-approved B):** Only fresh NEW_GAME birth establishes the body, derives food
and water capacity, then initializes them once to capacity: at weight80000, **400/400**.
This is a **legacy initialization-order compatibility correction**.

**Legacy execution:** `adm/daemons/logind.c` queries capacities before body setup;
`feature/move.c` initially has weight0 and `feature/damage.c` divides weight by200, producing
**0/0**, not400/400. `adm/daemons/race/human.c` later establishes body weight.
Continue, Restore, map transition, respawn/revive, load-failure recovery, returning from Old Pine,
opening menus and general recovery MUST NOT invoke this birth refill. No recovery formula changes.

## Legacy Native Save Preservation

**Status: SUPERSEDED by Pre-Cutover Development Save Compatibility (NGE5A1).** The following
records the previously approved old-save A decision, not the current branch policy.

**Decision (NGE1 owner-approved A):** Legal native saves created before Snow cutover remain
Legacy Native Technical-Demo Saves and restore their actual stored values. New Game revisions do
not rewrite existing saves. This is a **save compatibility policy**.

Do not relocate the player to Snow, reset attributes/experience, remove the starter weapon, grant
cloth, replenish food/water, rerun birth, revive NPCs/rebuild tombstones, alter corpses, redraw RNG,
or change allocator continuation. Existing native schema1 itself identifies the technical profile;
never infer it from experience, inventory or timestamps. Its absent Player metadata is interpreted
as the existing Player/age20 facts without recalculating saved gameplay values. This approves no
schema2, world revision implementation, Snow geometry, shops or training work.

## Active Semi-Auto V1 SPAR establishment is unarmed-only

**Decision:** CXR9 owner authorization restricts SPAR establishment to participants
without a wielded primary weapon. A weapon yields typed `SPAR_WEAPON_NOT_ALLOWED`
before Encounter activation/freezing. No automatic unwield, damage suppression,
HP clamp, revive, lethal conversion or corpse is introduced. Existing
`SPAR_MORTAL_WOUND` remains defense-in-depth for invalid/future states.

**Reason:** `cmds/std/fight.c` establishes reciprocal friendly intent, but
`adm/daemons/combatd.c::do_attack` allows wounds when either lethal intent OR a
weapon is present, before positive friendly damage removes the relationships.
`std/char.c` treats negative effective resources as mortal. That conflicts with
the native non-corpse SPAR contract.

**Compatibility impact:** Legacy armed friendly fights are deliberately unsupported
in V1; future armed/practice-weapon spar needs a separate policy. The newly exposed
unarmed zero-base-damage conflict is resolved by the separate owner authorization
below, not by inventing a positive damage floor.

## Unarmed zero base damage contributes zero without a random draw

**Decision:** Following the reproduced CXR9 unarmed-SPAR blocker, the owner
explicitly authorized only this exception: when the attacker has no primary
weapon and projected base damage equals zero, its base random term is zero and
consumes no RNG. Continue the unchanged source-ordered action/strength/armor
calculation. Negative base damage and armed zero base damage still fail at
`APPLY_DAMAGE_RANDOM_BOUND`; all other non-positive random-bound rules remain.

**Reason:** `adm/daemons/combatd.c::do_attack` calculates
`(damage + random(damage)) / 2` before adding strength. Human unarmed action and
`chard.c::setup_char` do not establish a positive base damage; the native empty-hand
projection is zero. Local `doc/efuns/random` does not establish historical driver
semantics for zero. Rejecting that ordinary unarmed path prevented the approved
unarmed-only SPAR from concluding.

**Compatibility impact:** This is an explicit narrow substitution, not a claim
that the old driver consumed no RNG for `random(0)`. It supersedes the earlier
non-positive-bound decision only at this empty-primary-hand base-damage stage.
It applies equally to unarmed LETHAL and SPAR; it does not grant damage, suppress
wounds, alter skills, clamp HP, or generally redefine the random adapter.
Sources: `reference/es2/mudlib/adm/daemons/combatd.c`, `adm/daemons/chard.c`,
`adm/daemons/race/human.c`, `doc/efuns/random`.

## Active Semi-Auto V1 Flee is same-position disengagement

**Decision:** The owner authorizes queued, busy-blocked Flee for LETHAL/SPAR,
deterministically successful when execution validation passes. It consumes no
resource or RNG and returns control at the unchanged physical position. Included
opponent and lethal relations are reconciled; V1 retains no cross-Encounter
pursuit/vendetta. No teleport, reward, healing, corpse or timed immunity is added.

**Reason:** `cmds/std/go.c::do_flee` randomizes a room exit, not a general escape
success roll. Continuous native world has no equivalent in-Encounter exit list.
Source `feature/attack.c::remove_all_enemy` leaves killer markers, but persistent
pursuit and killer Save serialization are not represented by this V1 boundary.

**Compatibility impact:** This explicitly differs from legacy killer preservation
and room-exit movement; it does not change ordinary portal/handoff policy. Physical
leave/reenter controls subsequent aggression. Implementation and acceptance
progress are recorded in CXR9; this approved decision is not a validation PASS.

## Native saves require a restart-stable gameplay boundary

**Decision:** A native Save is accepted only when every represented character and Old Pine runtime
authority is restart-stable. Ordinary opponents, lethal intent, busy/interrupt state, guarding, pending
aggression, active or committed-partial handoff, pending Cave exit, incomplete death lifecycle, active
combat cadence, and unrepresented temporary attribute modifiers block capture. Stable ACTIVE,
fully committed UNCONSCIOUS, and coherent completed DEAD states remain eligible; non-authoritative UI
state and the schema-v1 combined-stack delayed-destruction omission do not block Save.

**Reason:** These facts either describe an ordered transition that cannot be resumed by the closed save
schema or depend on runtime opportunities intentionally rebuilt fresh after Load. Persisting them merely
to allow Save would turn transient scheduling into durable gameplay state. Capturing after the current
event/frame preserves synchronous mutation ordering without adding a heartbeat or transaction runtime.

**Compatibility impact:** Native Save may reject states in which the LPC runtime could serialize user
fields. It never clears combat/busy state to make a save possible. Once eligible, the complete represented
world is captured all-or-nothing through the native repository; Load reconstructs fresh transient combat,
Area, UI, and cadence state. This is a native process-restart safety policy, not an LPC quit emulation.

## Inactive resident Old Pine maps freeze outside the SceneTree

**Decision:** Phase 9B3B1 retains instantiated Old Pine map Nodes for the lifetime of one
`OldPineWorldSession`, but only the active map is attached to the SceneTree. An inactive resident map is
detached without being freed and receives no physics, Area overlap, input, Camera, `_process()`,
`_physics_process()`, OpportunityTimer, combat, recovery, condition, or aggression progression.

**Reason:** The original MUD can continue processing objects outside the player's current room, but the
native prototype has no proven off-screen scheduling contract. Keeping a detached map instance preserves
NPC, corpse, loot, item, signal, and physical-view identity across a map round trip without prematurely
building persistence or a global heartbeat simulator.

**Compatibility impact:** Inactive Old Pine maps are frozen rather than globally simulated. They resume
from their retained runtime state when reattached; no elapsed off-screen combat, recovery, condition, or
NPC activity is synthesized. This is an in-memory session-lifetime rule, not save persistence.

## Non-positive authored world random bounds become ordered typed ambiguities

**S6B supersession:** The owner-approved SOURCE_ENTRY_V1 playable Vine exception above now selects
Waterfall for effective dodge<=0 with zero draws. The original policy/evidence below is historical
for that case and remains current for other revisions/interactions. Positive Vine behavior is unchanged.

**Decision:** When a future authored world interaction reaches an LPC `random(bound)` call with
`bound <= 0`, native code returns a typed legacy ambiguity/failure at that exact source position, consumes
no RNG draw, applies no clamp, and selects no invented branch. Phase 9B3B1 records this boundary but does
not yet implement or execute Vine randomness.

**Reason:** `d/oldpine/epath2.c` calls `random(query_skill("dodge"))`, while the locally available MudOS
documentation does not define zero or negative bounds. The existing Combat decision already uses ordered
typed failures for the same missing driver evidence; authored world interactions require an explicit scope
extension before the Vine path is implemented.

**Compatibility impact:** Positive authored bounds will retain their exact range and source ordering.
Non-positive states become diagnosable instead of crashing, clamping, or silently choosing waterfall or
passage. Presentation and mutations completed before the random position remain observable. Sources:
`reference/es2/mudlib/d/oldpine/epath2.c`, `reference/es2/mudlib/doc/efuns/random`.

## Cross-map ordinary exits use location availability reconciliation

**Decision:** Native cross-map ordinary exits commit the destination `WorldLocationState` and then run a
typed combat-opponent availability reconciliation. They do not reproduce `cmds/std/go.c`'s immediate
`remove_all_enemy()` inside portal or map-handoff code. Ordinary opponent membership can be removed as
out-of-location while independent lethal-target markers continue to follow the closed relationship rules.

**Reason:** Godot physical/world movement is not routed through the LPC directional-command runtime, and
the existing world slice already translates separation into current-location availability facts. Keeping
that boundary avoids hiding command-specific relationship mutation in a generic portal callback and also
allows a busy player to be reconciled without executing an attack or decrementing busy.

**Compatibility impact:** A cross-map ordinary exit such as the future Passage-to-Waterfall transition
cleans ordinary opponents through the explicit post-commit availability opportunity rather than at the
exact `go.c` move-return statement. Lethal intent is not erased merely by handoff. Sources:
`reference/es2/mudlib/cmds/std/go.c`, `game/core/combat/relationship/combat_opponent_selection_service.gd`.

## Combat invalid random bounds become ordered typed failures

**Decision:** Phase 5B2A returns a typed legacy-invalid result when ordinary attack resolution reaches
`random()` with a non-positive apply-damage, defense-factor, or wound-damage bound. The failure occurs at
the exact source position. Mutations already completed before that position are retained; in particular,
kee damage is not rolled back when the later wound `random(D)` bound is invalid.

Phase 5B2B2 extends the same decision to post-attack progression. A reached health-ratio expression
whose `max_gin` is zero becomes a typed division failure at that exact branch; a reached non-positive
progression `random()` bound or out-of-contract injected draw becomes a typed ordered failure. No
maximum is invented and no prevalidation moves the failure ahead of resolver mutations. Consequently,
late HIT failures preserve prior force, damage/wound, combat-exp, potential, and skill mutations exactly
as far as source order had completed. Sources: `reference/es2/mudlib/adm/daemons/combatd.c`,
`feature/skill.c`.

The Phase 5B2B2 formal audit extends this to the later `report_status(victim, wounded)` expression.
When a positive-damage HIT reaches `selected_kee * 100 / max_kee` with `max_kee == 0`, native code
returns a typed failure at that position, after progression and before busy interruption. Earlier mutations
remain, while busy remains untouched. This avoids both a Godot crash and an invented divisor. Source:
`reference/es2/mudlib/adm/daemons/combatd.c:149-160,390-432`.

Phase 5B3B1 extends the same ordered policy to reached `fight()` perception and courage calls.
`100 + effective perception <= 0` fails only when the target is invisible; visible targets never validate
that bound. `raw cps * 3 <= 0` fails only after perception has passed and only when the victim is living
and not busy; QUICK never validates it. A prior perception draw remains consumed when the later courage
bound fails. Guarding is set before the fixed `random(5)` presentation draw, so an invalid guard draw
retains that mutation. Source: `reference/es2/mudlib/adm/daemons/combatd.c::fight()`.

Phase 5B3B2A extends the policy to the terminal guarding-riposte call
`random(my["cps"])`. The exact REGULAR/negative-or-zero-damage/live-guard predicate is evaluated first;
the victim's guarding flag is then cleared, and only then is the original attacker's current raw cps read
as the random bound. A non-positive bound or out-of-range injected draw returns a typed failure while the
guard clear and all earlier attack/relationship mutations remain committed. No minimum cps is introduced.
Sources: `reference/es2/mudlib/adm/daemons/combatd.c::do_attack()`,
`reference/es2/mudlib/feature/dbase.c::query_entire_dbase()`.

**Reason:** The mudlib does not prove the deployed MudOS/FluffOS behavior for `random(0)` or a negative
bound. Clamping to one, prevalidating all later bounds, or allowing a defense loop to hang would each alter
observable source ordering. A typed result keeps the Godot domain safe while preserving all preceding
integer calculations, random consumption, loop iterations, and resource transitions.

**Compatibility impact:** Valid positive-bound attacks are unchanged. Invalid legacy states return a
diagnosable failure instead of a driver-specific error or hang. A wound-bound failure is explicitly a
partial mutation, not an atomic attack rollback. Sources:
`reference/es2/mudlib/adm/daemons/combatd.c:312-380`,
`reference/es2/mudlib/feature/damage.c:12-68`.

## Condition update order

**Decision:** A single native condition update uses a snapshot of active condition IDs sorted by stable ID string in ascending order.

**Reason:** `feature/condition.c` obtains `keys(conditions)` from an LPC mapping and iterates that array backwards. The mudlib does not define mapping key order as gameplay data, yet multiple conditions can mutate the same resource and therefore need a deterministic native order. Stable ID order is independent of insertion order, hash layout, and save/restore behavior.

**Compatibility impact:** Multiple simultaneous conditions may resolve in a different order from a particular MudOS/FluffOS process. Individual condition formulas, flag aggregation, snapshot behavior, and post-update removal semantics remain unchanged. Source: `reference/es2/mudlib/feature/condition.c`.

## Cultivation percentage division by zero

**Decision:** If a Phase 3B1 health-percentage check reaches a primary resource whose maximum is zero, return a typed `LEGACY_ZERO_MAXIMUM_*_DIVISOR` failure at that exact validation position, without mutation.

**Reason:** `exercise.c`, `meditate.c`, and `respirate.c` calculate `current * 100 / maximum` without guarding zero. The LPC command therefore aborts with a driver division error rather than producing a gameplay failure string. A pure domain transition must not crash the application, and treating zero as merely “below 70%” would hide the source defect and alter validation evidence.

**Compatibility impact:** The native call returns a diagnosable failure instead of throwing a MudOS/FluffOS runtime error. It preserves validation order and the absence of mutation. No positive minimum is imposed on internal-resource current or maximum values. Sources: `reference/es2/mudlib/cmds/std/exercise.c`, `meditate.c`, `respirate.c`.

## Self-learning with non-positive intelligence

**Decision:** Phase 3B2 rejects `selflearn` with a typed `LEGACY_NON_POSITIVE_INTELLIGENCE` failure when base `int` is zero or negative, without mutation.

**Reason:** `selflearn.c` computes `300 / int` without a zero guard. Zero aborts immediately. Negative intelligence produces a negative gin cost and later passes it to `receive_damage()`, which raises an error for negative damage; the LPC path may already have modified potential/skill progress before that error. A native domain transition must not crash or leave a partially applied transaction.

**Compatibility impact:** Normal positive-intelligence behavior is unchanged. Invalid legacy states receive a deterministic typed failure instead of a driver error or partial mutation. This is not a new gameplay minimum for valid characters. Sources: `reference/es2/mudlib/cmds/std/selflearn.c`, `feature/damage.c`.

## Learn legacy runtime errors preserve completed mutations

**Decision:** Phase 3C1 converts division-by-zero, invalid `random()` input, and negative `receive_damage()` points into typed `LearnResult` legacy errors at the exact LPC execution position. Unlike the earlier Selflearn substitution, Learn does not roll back mutations already completed before that point.

**Reason:** `learn.c` has observable mutation-sensitive errors: the raw-zero entry is later than the two intelligence divisions; `learned_points` increments before `random()`; an NPC teacher with a negative gin cost can reach `improve_skill()` and `skill_improved()` before the final negative gin damage errors. Crashing the Godot application is unacceptable, while validating everything before mutation would also change behavior.

**Compatibility impact:** Ordinary Learn behavior is unchanged. Invalid legacy states return a diagnosable result instead of a driver exception, but retain only the raw skill, teacher sen, potential, learned progress, level, or authored effect mutations which LPC had already performed. No minimum intelligence or silent clamp is introduced. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/damage.c`, `feature/skill.c`.

## Learn teacher identity keeps one narrow legacy name field

**Decision:** Native relationships use a stable `TeacherId` (`StringName`) as primary identity, while `ApprenticeshipState` also retains `legacy_master_name` solely for the F_MASTER direct-apprentice predicate.

**Reason:** `learn.c::is_appr_of()` compares master ID plus generation, whereas `feature/apprentice.c::is_apprentice_of()` compares master ID plus persisted master display name and is called by `std/char/master.c::prevent_learn()`. Replacing both with one modern predicate would silently erase a real source discrepancy.

**Compatibility impact:** New content does not use display names as identity, but migrated saves can reproduce the second legacy comparison. The two predicates remain intentionally separate. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `feature/apprentice.c`, `std/char/master.c`.

## Learn runtime facts and randomness are explicit projections

**Decision:** Inventory-based spouse discovery, `present()`/`living()`/`userp()` checks, and `random()` are replaced by typed `TeachingContext` facts plus a deterministic roll supplied by the caller.

**Reason:** These operations belong to LPC inventory/world/runtime infrastructure. The gameplay semantics needed by Learn are only whether this teacher is the spouse, available, a character, awake, and player-style for sen payment, plus a roll satisfying the MudOS range contract.

**Compatibility impact:** Learn retains the original validation order, strict thresholds, player/NPC sen distinction, and random upper-bound formula. The caller is responsible for producing world/relationship facts and a roll `0 <= roll < upper`; Phase 3C1 does not implement their runtime sources. Source: `reference/es2/mudlib/cmds/std/learn.c`.

## Missing Learn policies are explicit

**Decision:** A teacher with no `prevent_learn()` policy has `NO_ADDITIONAL_POLICY` and continues. If relationship fallback requires recognition, a teacher with no recognition policy returns `RECOGNITION_POLICY_ABSENT`; an authored recognition policy whose known dependency is not migrated returns `RECOGNITION_DEPENDENCY_UNAVAILABLE`. An unimplemented authored `valid_learn()` similarly returns `SKILL_LEARN_DEPENDENCY_UNAVAILABLE`.

**Reason:** The mudlib dynamically calls methods which many objects do not define, and does not document the deployed driver's missing-lfun behavior. Prevention is a negative veto and can have an explicit no-veto default; recognition is a positive authorization and cannot be manufactured. Treating every unknown skill hook as the permissive `std/skill.c` default would also erase known authored overrides.

**Compatibility impact:** Teachers and skills whose rules are understood receive explicit policies. “No authored method,” “authored allow,” “authored reject,” and “known dependency unavailable” remain distinguishable. Driver-dependent or not-yet-migrated paths stop with a typed result instead of crashing, silently allowing, or masquerading as a normal authored rejection. Sources: `reference/es2/mudlib/cmds/std/learn.c`, `std/char/master.c`, `std/skill.c`, and the representative teacher/skill daemons listed in `PHASE_3C1_LEARN_CORE.md`.

## Hand-slot state has one native authority

**Decision:** `EquipmentState` exclusively owns the native primary and secondary weapon slots. `EquippedWeaponRef` uses a stable runtime instance ID plus an immutable scalar definition snapshot; the migration does not reproduce the LPC combination of character `query_temp()` object references and a separate mutable item-side `equipped` marker.

**Reason:** The duplicated LPC representation is tied to object environments and dbase/runtime APIs. Recreating both halves would add a compatibility layer and permit divergence without adding gameplay meaning. Stable identity and one authoritative typed state preserve all confirmed slot selection, duplicate, wield-order, and unwield behavior.

**Compatibility impact:** Phase 4A1 transition outcomes match `feature/equip.c`, including secondary-only and two-handed quirks. Later Inventory must enforce cross-owner instance identity and translate move/transfer into an explicit unwield transition; it must not introduce a second authoritative equipped flag. Sources: `reference/es2/mudlib/feature/equip.c`, `cmds/std/wield.c`, `cmds/std/unwield.c`, `feature/move.c`, `std/item.c`.

## Native item persistence preserves the complete represented domain state

**Decision:** Native item schema version 1 snapshots every represented live `ItemInstance`, its exact `InventoryState` own weight and direct parent, `CombinedStackState.amount`, and per-character Equipment/Armor instance references. Restore validates the complete snapshot and reconstructs fresh aggregates all-or-nothing. It does not reproduce LPC's autoload-only inventory loss or replay gameplay transfer/wield/wear operations.

**Reason:** Legacy `F_SAVE` serializes user fields but not ordinary inventory objects. `feature/autoload.c` separately recreates only selected direct inventory objects, and generic hand/armor slot state is not restored. The native domains already own stable instance identity, recursive containment, stack amount, and equipment references; discarding them would make native saves incomplete and would reproduce a runtime limitation rather than gameplay semantics.

**Compatibility impact:** Native saves retain ordinary and nested items plus generic hand/armor state that LPC logout did not retain. Immutable weapon, armor, and stack facts are rebuilt from current definition projections, while saved current own weight is preserved exactly. Legacy autoload is handled by the separate Phase 4B5D one-way importer. Sources: `reference/es2/mudlib/feature/autoload.c`, `feature/save.c`, `obj/user.c`, `cmds/usr/quit.c`, `std/money.c`, `obj/bandage.c`.

## Schema v1 omits pending combined-stack destruction intents

**Decision:** Native item schema version 1 does not persist a pending one-second combined-stack destruction intent. It snapshots only the amount and own weight observable at capture time and restores the stack as an ordinary live instance without synthesizing a new intent.

**Reason:** `std/item/combined.c::set_amount(0)` leaves the old amount and weight observable and schedules destruction through a non-durable `call_out`. Legacy money autoload therefore saves the old visible amount during that window, and the pending callout does not survive reload. Runtime scheduling is deliberately outside Phase 4B5A.

**Compatibility impact:** A pending positive stack can survive reload with its old positive amount and weight; a raw-zero stack restores with amount zero and its exact saved own weight, without automatically scheduling destruction. A future durable scheduler policy would require a new explicit schema decision. Sources: `reference/es2/mudlib/std/item/combined.c`, `std/money.c`, `feature/autoload.c`.

## Legacy autoload import builds validated data instead of replaying login

**Decision:** Phase 4B5D translates legacy autoload strings in original order into an immutable schema-v1 snapshot candidate and typed evidence, then stops. It does not execute `new()`, `move()`, or `autoload()`, does not replay capacity/merge/callback failures, and does not mutate live aggregates. Source-proven bandage wear is represented in candidate Armor data after direct placement; unsupported entries leave the batch explicitly incomplete.

**Reason:** Executing LPC paths would require a compatibility runtime and could leave partial live mutations before a later failure. Phase 4B5A already defines trusted structural reconstruction as the native persistence boundary. A pure importer can preserve traceable data and sequential authored semantics while allowing application policy to reject or inspect incomplete migrations before explicitly restoring anything.

**Compatibility impact:** Imported direct items can reconstruct even where legacy `move(user)` capacity would have failed, and supported entries remain inspectable without reproducing a prior callback abort. No live state changes until a caller separately accepts the candidate and invokes native restore. Sources: `reference/es2/mudlib/feature/autoload.c`, `obj/bandage.c`, `std/item/combined.c`.

## Legacy zero-money import keeps clone state plus a transient intent

**Decision:** Importing a source-produced money parameter `"0"` creates a candidate stack with amount `1` and one unit of the concrete currency's base weight, then emits a typed one-second destruction intent outside schema v1. The importer does not start a timer.

**Reason:** Each concrete money clone executes `set_amount(1)` in `create()`. Its later `autoload("0")` calls `set_amount(0)`, which schedules destruction but does not assign zero or update weight. Saving raw zero in the candidate would invent a state the executable restore path never exposed.

**Compatibility impact:** If an application accepts this unusual candidate but does not later execute the external intent, the one-unit stack remains live. Schema v1 itself is unchanged and still does not durably persist pending destruction. Sources: `reference/es2/mudlib/std/money.c`, `std/item/combined.c`, `obj/money/coin.c`, `gold.c`, `silver.c`, `thousand-cash.c`.

## Item destruction stops on an unexpected native equipment-detach failure

**Decision:** Phase 4B5B prevalidates structure, then attempts exact hand cleanup followed by exact Armor cleanup. If a referenced instance unexpectedly cannot be removed from one of those native authorities, lifecycle returns a typed failure and does not remove the item's Inventory/stack registration. Any earlier successful hand cleanup is not rolled back and is reported in the result.

**Reason:** `feature/move.c::remove()` logs an `unequip()` failure and continues to driver destruction. Reproducing that continuation in the native split-authority model would remove the item while leaving an impossible authoritative Equipment/Armor reference. Current typed transitions normally succeed whenever their identity predicate was true, so this is an invariant-defense path rather than a new gameplay rejection.

**Compatibility impact:** Structurally valid current states preserve LPC's ordinary cleanup-then-destruction behavior. A corrupted or future custom aggregate that reports an item equipped but refuses exact detach keeps the item live instead of reproducing a dangling-reference defect. The result honestly exposes any cleanup already completed; no invented rollback occurs. A composed multi-sibling stack merge commits each successfully destroyed sibling's positive quantity before attempting the next lifecycle transition, so a later injected detach failure cannot erase an earlier sibling's quantity; normal successful final totals and survivor identity are unchanged. Direct-character lifecycle context must contain both authoritative aggregates—explicit empty states mean empty, while `null` means the authority was omitted and is rejected. Sources: `reference/es2/mudlib/feature/move.c`, `feature/equip.c`, `std/item/combined.c`.

## Death and corpse inventory ordering uses stable instance IDs

**Decision:** Phase 4B5C snapshots a victim's direct item IDs in ascending stable-ID order, evaluates `owner_is_killed` policies in that order, and processes survivors in descending snapshot order to preserve `chard.c`'s reverse loop. Corpse final scatter uses ascending direct-child order.

**Reason:** `adm/daemons/chard.c` snapshots `all_inventory(victim)`, invokes hooks over that array, then walks survivors backwards; `obj/corpse.c` walks its `all_inventory()` array forwards. The mudlib does not define object-chain allocation order as authored gameplay data, but policy destruction and ignored transfer failures make order observably affect partial results. `InventoryState.direct_children()` already supplies deterministic stable-ID snapshots, so the death domain must state how legacy forward/reverse traversal maps to that native order.

**Compatibility impact:** A particular MudOS process may have evaluated or moved items in a different object-chain order. Direct-only membership, policy-before-transfer ordering, reverse survivor concept, per-item partial mutations, final forward scatter concept, and all item formulas remain unchanged. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `obj/corpse.c`.

## Incomplete synchronous death hooks cannot restart the whole death flow

**Decision:** A death-item hook that requires unavailable native runtime work, or a destruction failure after observable cleanup, returns a typed incomplete result with `DO_NOT_RESTART_FROM_BEGINNING`. Phase 4B5C deliberately provides no generic continuation token or scheduler.

**Reason:** `owner_is_killed()` runs synchronously over one direct-inventory snapshot before survivor movement. By the time a native boundary is encountered, a normal death may already have created/placed a corpse and earlier policies may already have destroyed items or detached equipment. Re-running the complete operation would duplicate or reorder those mutations.

**Compatibility impact:** Future NPC/runtime orchestration must continue from the recorded boundary using current authoritative aggregates; it must not call the whole Phase 4B5C process again. This preserves the LPC ordering without introducing callback dispatch or a runtime workflow engine. Sources: `reference/es2/mudlib/adm/daemons/chard.c`, `daemon/class/scholar/windspring.c`, `feature/move.c`.

## Combat lethal relationships use stable character identity

**Decision:** Native combat opponent, lethal-target, and last-opponent identities use stable `CharacterId` values; guarding remains a targetless boolean. Legacy public `id()` strings remain migration metadata and are not used as the authoritative lethal relationship key.

**Reason:** `feature/attack.c` stores live enemy objects but stores `killer` entries as public ID strings. Different live entities can share a public ID, so reproducing that mixed identity model would let one entity's lethal marker accidentally match another entity and would conflict with the stable identity already used by native relationship state.

**Compatibility impact:** Simultaneous legacy entities with the same public ID no longer share or collide on a lethal marker. Cleanup, selection, friendly-stop eligibility, and all local relation mutations remain source-ordered; only the ambiguous public-ID collision is not reproduced. Sources: `reference/es2/mudlib/feature/attack.c`, `reference/es2/mudlib/adm/daemons/combatd.c`.

## Corpse loot requires a near-corpse spatial range

**Decision:** Phase 8B1 replaces LPC same-room corpse reachability with a map-local circular `LootInteractionRange Area2D` of radius 96 Godot pixels, centered on each runtime corpse view. Corpse selection and Inspect may occur by clicking, but Open Loot and every Take re-evaluate the player's current physical presence in that range. The range fact belongs only to the Old Pine scene/world interaction adapter; Inventory, Corpse, stack, and item Core receive no position or distance rule.

**Reason:** `cmds/std/get.c` and `present(arg, environment(me))` make source reachability depend on sharing one discrete room. The native map is continuous and the current player/corpse bodies are roughly 36 pixels wide, so a 96-pixel circle permits deliberate nearby interaction without extending across the 150-pixel spacing between authored bandit spawn centers. `Area2D` supplies the physical representation and enter/exit notifications; execution also checks current corpse/player positions so a corpse created while already overlapping the player cannot miss its initial range fact.

**Compatibility impact:** A player on the same continuous Godot map but farther than 96 pixels from the corpse cannot Open Loot or Take until approaching it. Once admitted, all item ownership, capacity, corpse-worn, stack merge, and fighting/busy results remain governed by the migrated source rules. Source: `reference/es2/mudlib/cmds/std/get.c`; native scene scale: `game/scenes/world/oldpine/oldpine_outdoor.tscn`.

## Old Pine Outdoor directly connects to the Pine Maze

**Decision:** Phase 9B1 adds one bidirectional, continuously walkable physical threshold between the existing Old Pine Outdoor prototype and the native Pine Entrance zone. It is an RPG geography consolidation, not a `PortalDefinition` and not a claim that the LPC rooms have a direct exit.

**Reason:** The LPC graph has no ordinary edge from the currently embodied Central/North Outdoor area to `pine1`. Its source route is `epath2` vine → `passage` or `waterfall` → River/Cliff → `cliffside` → `pine1`. Requiring that entire chain would block the low-dependency Pine content on conditional skill/RNG traversal, Cave/River authoring, and cross-scene state handoff. Native RPG geography may cluster legacy rooms into continuous maps while retaining their authored identities and meaningful boundaries.

**Compatibility impact:** Players can enter Pine Entrance directly from the current Outdoor map earlier than the LPC topology permits. The Pine-side `pine2 → keep1` and `cliffdown → cliff2` boundaries remain represented but closed, all eight Phase 9B1 legacy room IDs remain traceable, and no new LPC exit is recorded. Sources: `reference/es2/mudlib/d/oldpine/epath2.c`, `passage.c`, `waterfall.c`, `riverbank1.c`, `cliff1.c`, `cliffside.c`, `pine1.c`.

## Random Pine room exits become one fixed continuous maze

**Decision:** Phase 9B1 translates `pine1` through `pine7` and `cliffdown` into one fixed continuous spatial maze with repeated forks, occlusion, a traversable loop, a safe dead end, a reliable route to Pine Cliff Edge, and a reliable return route. There is no ROOM exit emulator, reset-time topology mutation, or navigation RNG.

**Reason:** The Pine rooms use random exit targets to create disorientation within a text-room runtime. `pine1`, `pine2`, and `pine4` through `pine7` rebuild those exits during reset, while `pine3` selects them during create; several fixed links provide an authored skeleton: `pine1 west → pine4`, `pine4 north → pine5`, `pine5 north → pine6`, `pine6 west → pine7`, `pine7 southwest → cliffdown`, plus `pine2 east → keep1`. Reproducing mutable exit tables would port the LPC runtime representation instead of its maze intent and would make physical collision/navigation unstable.

**Compatibility impact:** A given playthrough and scene reload use the same Pine geometry instead of source reset/load randomization. The native layout preserves getting-lost pressure through physical loops, similar branches, barriers, and dead ends while guaranteeing reachability and return. Pine navigation consumes no random source. Sources: `reference/es2/mudlib/d/oldpine/pine1.c`, `pine2.c`, `pine3.c`, `pine4.c`, `pine5.c`, `pine6.c`, `pine7.c`, `cliffdown.c`.
