# S7A — Snow North Street / Core Services Rebaseline

## EXECUTIVE RESULT

**S7A ANALYSIS COMPLETE — AWAIT OWNER REVIEW.** This is a docs-only scope proposal, not an implementation authorization or a final Snow audit.

Recommend **one remaining bounded implementation: the north public spine through crossroad, with honest deferred storefront/region boundaries; then the distinct final Snow audit and owner review**. Existing income, denomination exchange, food, water and eligible recovery already form a renewable preparation loop. No additional shop is intrinsically required to make that loop function. Selling loot would add the most useful *new* economic loop, but is a separate service contract, not a street-construction dependency. Fast medicine is useful, but absence of a medicine vendor does **not** mean effective wounds cannot recover.

This proposal deliberately does not mean all ordinary Snow streets/interiors, all 38 rooms, full NPC population, apprenticeship, or full source parity. Southwestern branches remain deferred. Owner must approve the specific finish line and omissions below; neither historical S1 proposals nor this recommendation lock them.

ES2 decides WHAT / WHY / RESULT. Godot decides native architecture, physical embodiment, interaction translation and presentation. Type A = source semantic migration; Type B = Native translation/staged observable omission, explicitly accounted for; Type C = new design requiring owner approval. This is source-faithful ES2 → native Godot RPG migration, not freeform redesign.

## EXACT BASELINE

Read-only checks at analysis start:

| Fact | Verified value |
| --- | --- |
| Repository | `Toxicccxz/eastern-stories-godot` |
| Branch | `phase/snow-town-core-hub` |
| Local HEAD / actual remote branch | `add8d32107277fef7cc57a4a121c64b6b9b5c027` |
| Subject | `Add fresh water supply loop` |
| `origin/main` / actual remote main / merge base | `047f29083e881156abbdad6ed480bffc1350dfa8` |
| Working tree / index | Clean |
| Open Snow PR | None; checked GitHub head/base query |

Current code and approved DECISIONS outrank superseded phase proposals. The owner explicitly closes S6B in this instruction. S1–S6B are approved/closed; S7A is authorized; S7B and final PR are not. All LPC paths below are relative to read-only `reference/es2/mudlib/`.

## S6B CLOSEOUT

[S6B](PHASE_SNOW_TOWN_CORE_HUB_FRESH_WATER_SUPPLY_LOOP.md) ends at the baseline above. Only its current status is updated; its evidence and decisions remain historical and unchanged. Reported local evidence: focused118, canonical19,135, Python46, static/editor and repository-content sanitizer PASS; fresh-player Work×2 → Bank → wineskin → Vine → Waterfall Fill → Drink → Pause Save → fresh-process Continue PASS. Return smoke reached Pine, where existing authored combat stopped further free walking; it did not prove an uninterrupted return to Snow. Exact pre-S6B item2 saves loaded. These are prior local execution records, not newly executed S7A tests or new GitHub CI.

Ignored owner-local Godot AI update backups cause the documented direct-worktree sanitizer issue. They are preserved, not cleaned, committed or altered.

## CURRENT SNOW PLAYABLE GRAPH

Actual definitions, physical zone/collision nodes and controllers agree on **10 Snow source identities**: one `snow.inn.main_floor` zone in `snow.inn`, and nine zones in `snow.outdoor`: `snow.square`, `snow.sroad1`, `snow.eroad1`, `snow.eroad2`, `snow.eroad3`, `snow.mstreet1`, `snow.mstreet2`, `snow.workplace`, `snow.bank`.

```text
Workplace ↔ mstreet2 ↔ mstreet1 ↔ Square ↔ sroad1 ↔ eroad1 ↔ eroad2 ↔ eroad3 ⇄ Old Pine
                         ↕          ↕
                        Bank       Inn
```

The drawing shows adjacency, not compass placement: Workplace is east of mstreet2; Bank west of mstreet1; Inn west of Square; mstreet1/2 north of Square. Ordinary walking stays in one outdoor resident. Inn and Old Pine crossings are real map passages. No Snow NPC runtime population exists; the waiter is a staged scene contact with two offers, not a full NPC. Bank and Workplace are physical areas in the outdoor map, not new resident maps.

Evidence: `game/data/snow/snow_world_definitions.gd`, `snow_oldpine_connection_definitions.gd`; `game/scenes/world/snow/snow_outdoor.tscn`, `snow_inn.tscn`; `game/runtime/world/snow_outdoor_controller.gd`, `snow_inn_controller.gd`, `oldpine_world_session_controller.gd`. Source exit metadata alone is not a usable Native portal. Physical collision still closes mstreet2 north/west and mstreet1 east.

Existing deferred source connections also include Inn upstairs/wizard northwest; Square east → temple; sroad1 west → sroad2 and south → dragonhill; eroad1 north → temple; eroad3 east → the separate temple region. North expansion must not accidentally open these.

## COMPLETE 38-ROOM REBASELINE

Re-enumerated **38 direct `.c` files** in `d/snow/`; each room was read, including inherited ROOM/BANK/HOCKSHOP behavior. This count excludes `npc/` and `obj/` content. Table 1a records source facts; Table 1b supplies one current Native/classification row for every file. Neither table counts scenes as rooms.

Table 1a conventions: paths without a leading slash resolve within `d/snow/`; N/S/E/W/U/D/NW/SW are literal exit keys. All rooms inherit ROOM except Bank and Hockshop as noted. `O` means executable `outdoors="snow"`; `–` means no such field, not proof of an enclosed Native building. `nc0` means explicit `no_clean_up=0`. Omitted object/action entries mean none authored in that room, not no inherited behavior. Spawn counts are source reset slots, not current Native counts.

| File / display name | Role; exits | Objects / special behavior / flags |
| --- | --- | --- |
| `bank.c` 安记钱庄 | Bank; E mstreet1 | BANK; annihir×1; convert/deposit inherited (deposit empty); sign; no-fight/no-magic commented |
| `crossroad.c` 山坳 | Region junction; S mstreet4, N /d/goathill/mroad1, E /d/green/path6 | O, nc0; bandit warning prose only |
| `e_room.c` 客房 | Inn room; W inn_2f | West door closed; – |
| `eroad1.c` 黄土小径 | East approach; W sroad1, E eroad2, N temple | O |
| `eroad2.c` 黄土小径 | East approach; W eroad1, E eroad3 | dog×2; O |
| `eroad3.c` 山路 | Outbound approach; W eroad2, S /d/oldpine/npath1, E /d/temple/sroad | O, nc0 |
| `guestroom.c` 客房 | Martial compound guest room; N inneryard | Painting prose; nc0; –; prose direction differs |
| `herbshop.c` 桑邻药铺 | Medicine shop; E mstreet3 | herbalist×1, woodcutter×1; cabinet/sign descriptions, no room action; – |
| `herbshop1.c` 药铺密室 | Isolated secret room; no exits | No objects/actions; wall prose, nc0; – |
| `hockshop.c` 丰登当铺 | Appraisal/pawn/sell; W mstreet3, E hockshop2 | HOCKSHOP; W door closed; master spawn commented; sign; – |
| `hockshop2.c` 储藏室 | Store back room; W hockshop | Auction/locked-box prose only; no inventory/action/gate; – |
| `inn.c` 饮风客栈 | Birth/vendor; E square, U inn_2f, NW /wiz/entrance | traveller×2, waiter×1; NW door closed; valid_startroom; sign callback; board commented; – |
| `inn_2f.c` 饮风客栈二楼 | Landing; D inn, W w_room, N n_room, E e_room | rat×6; W/N/E closed doors; lodging ranks prose, no payment gate; – |
| `innerhall.c` 武馆内院 | Compound inner room; W inneryard | Permission/kitchen/bedroom prose, no gate/exits for them; nc0; – |
| `inneryard.c` 天井 | Compound courtyard; W schoolhall, E innerhall, S guestroom, N nyard | Pillar description; O, nc0 |
| `mstreet1.c` 雪亭镇街道 | Services junction; S square, N mstreet2, W bank, E school1 | O |
| `mstreet2.c` 雪亭镇街道 | Work/smith junction; S mstreet1, N mstreet3, W smithy, E workplace | drunk×1, scavenger×1; O; stale sizeof comment says3, mapping has4 |
| `mstreet3.c` 雪亭镇街道 | Pawn/herb junction; S mstreet2, N mstreet4, E hockshop, W herbshop | East closed door; O; no NPC/action |
| `mstreet4.c` 雪亭镇街道 | Postal street; S mstreet3, N crossroad, W postoffice | nc0; **no outdoors field**, no E exit despite alley prose |
| `n_room.c` 客房 | Inn room; S inn_2f | South closed door; – |
| `nyard.c` 书房 | Compound study; S inneryard | girl×1; books prose, no book spawn; – |
| `postoffice.c` 雪亭驿 | Mail access; E mstreet4 | post_officer×1; sign; leaving destroys Player temporary mailbox; – |
| `school.c` 书院 | Literacy school; N sroad2 | `npc/teacher`×1, not `teacher1`; west wing prose, no exit; – |
| `school1.c` 淳风武馆大门 | Martial entry; W mstreet1, E school2 | guard×1; east closed door; O |
| `school2.c` 淳风武馆教练场 | Training court; W school1, E schoolhall, N weapon_storage | trainee×6, fist_trainer×1; west closed door; O |
| `schoolhall.c` 淳风武馆大厅 | Master hall; W school2, E inneryard | CLASS_D swordsman/master×1; board loaded by foo; valid_startroom; – |
| `secret_storage.c` 地下密室 | Secret chamber; no static exits | obj/shield×1; bed prose; –; temporary up comes from weapon_storage |
| `smithy.c` 打铁铺子 | Smith contact; E mstreet2 | smith×1; – |
| `square.c` 广场 | Town center; N mstreet1, W inn, S sroad1, E temple | trav_blade×3; worker×4 commented; O |
| `sroad1.c` 雪亭镇街道 | South/east junction; N square, E eroad1, W sroad2, S /u/cloud/dragonhill/nroad | O |
| `sroad2.c` 雪亭镇街道 | School approach; E sroad1, W sroad3, S school | farmer×2; O |
| `sroad3.c` 青石官道 | Western road; E sroad2, W sroad4 | O |
| `sroad4.c` 青石官道 | Regional road; E sroad3, N sroad5, SW /d/canyon/road | crazy_dog×1; O |
| `sroad5.c` 青石官道 | Regional approach; S sroad4, W /d/waterfog/sroad1 | O |
| `temple.c` 城隍庙 | Local temple; W square, S eroad1 | keeper×1, paper_seal×2, denotation×1; no_fight; – |
| `w_room.c` 客房 | Inn room; E inn_2f | East closed door; – |
| `weapon_storage.c` 兵器储藏室 | Martial storage; S school2; conditional D secret_storage | bamboo_sword×1; push puzzle, delayed exit closure, reset; – |
| `workplace.c` 谷物加工厂 | Income; W mstreet2 | work/sign; no_fight1; boss/workers only prose, no NPC spawn; – |

## ROOM CLASSIFICATION

Proposed categories, **not approved completion requirements**: A implemented/sufficient core; B required remaining physical core; C required remaining gameplay service; D optional/later local Snow; E secret/special; F external-region boundary. F is a role, not permission to restore the destination. Crossroad is F **and its Snow-side physical approach is recommended before closure**. Counts: **A10 / B2 / C0 / D21 / E2 / F3 =38**. C0 is a deliberate bounded-milestone recommendation, not a claim every source service exists.

Table 1b: `OUT:x` means `snow.outdoor` / `snow.x`; `INN` means `snow.inn` / `snow.inn.main_floor`. “Adequate” refers to this proposed scope only; omitted source NPCs/actions are not full parity.

| Source room | Current Native | Physically reachable? | Gameplay available? | Class | Dependency / rationale |
| --- | --- | --- | --- | --- | --- |
| `bank.c` | OUT:bank | Yes | Currency exchange, not deposit/accounts/NPC | A | S3B/C adequate |
| `crossroad.c` | None | No | No | F | Proposed Snow approach required; Green/Goathill deferred |
| `e_room.c` | None | No | No | D | Optional lodging/door content |
| `eroad1.c` | OUT:eroad1 | Yes | East walking route; temple closed | A | Existing preparation/excursion route |
| `eroad2.c` | OUT:eroad2 | Yes | Walking; source dogs omitted | A | NPC fidelity deferred |
| `eroad3.c` | OUT:eroad3 | Yes | Old Pine passage, not temple region | A | Existing meaningful external route |
| `guestroom.c` | None | No | No | D | Martial compound, not birth Inn |
| `herbshop.c` | None | No | No | D | Optional fast curing; see healing gap |
| `herbshop1.c` | None | No | No | E | No demonstrated access trigger; not shop dependency |
| `hockshop.c` | None | No | No | D | Valuable later loot-sale loop; needs scoped contract |
| `hockshop2.c` | None | No | No | D | Ordinary but optional back room, no custody authority |
| `inn.c` | INN | Yes | Birth, two purchases; partial waiter | A | Existing core supply service |
| `inn_2f.c` | None | No | No | D | Optional rooms, no executable lodging requirement |
| `innerhall.c` | None | No | No | D | Later compound interior |
| `inneryard.c` | None | No | No | D | Later compound circulation |
| `mstreet1.c` | OUT:mstreet1 | Yes | Bank access; school closed | A | Existing service junction |
| `mstreet2.c` | OUT:mstreet2 | Yes | Work access; smith/north closed | A | Existing service junction |
| `mstreet3.c` | None | No | No | B | Missing main-axis service junction |
| `mstreet4.c` | None | No | No | B | Missing main-axis postal frontage |
| `n_room.c` | None | No | No | D | Optional Inn lodging |
| `nyard.c` | None | No | No | D | Later study/NPC; no ordinary supply role |
| `postoffice.c` | None | No | No | D | Account-based mail outside current product |
| `school.c` | None | No | No | D | Literacy/recognition progression later |
| `school1.c` | None | No | No | D | Martial entry, guard/doors later |
| `school2.c` | None | No | No | D | Faction-dependent trainer later |
| `schoolhall.c` | None | No | No | D | Master/apprenticeship/board later |
| `secret_storage.c` | None | No | No | E | Authored secret puzzle/reward |
| `smithy.c` | None | No | No | D | Hammer purchase is new weapon scope |
| `square.c` | OUT:square | Yes | Central walking/Inn access; no NPC population | A | Existing hub |
| `sroad1.c` | OUT:sroad1 | Yes | East route; west/south closed | A | Existing route; honest deferred branches |
| `sroad2.c` | None | No | No | D | Western school branch, not required north axis |
| `sroad3.c` | None | No | No | D | Western approach, no core service |
| `sroad4.c` | None | No | No | F | Canyon boundary corridor, later |
| `sroad5.c` | None | No | No | F | Waterfog boundary corridor, later |
| `temple.c` | None | No | No | D | Donation/bellicosity/special items, not base recovery |
| `w_room.c` | None | No | No | D | Optional Inn lodging |
| `weapon_storage.c` | None | No | No | D | Free bamboo sword/puzzle are later progression content |
| `workplace.c` | OUT:workplace | Yes | Work income | A | S2 adequate |

## NORTH STREET SOURCE GRAPH

| Segment | Exact source exits | Current Native | Missing dependency | Proposed treatment |
| --- | --- | --- | --- | --- |
| mstreet2 | S mstreet1, N mstreet3, W smithy, E workplace | Reachable, N/W closed | North geometry | Preserve Work; extend north only |
| mstreet3 | S mstreet2, N mstreet4, E hockshop, W herbshop | None | Street/door frontage | Continuous same-map zone, services deferred |
| mstreet4 | S mstreet3, N crossroad, W postoffice | None | Street/postal frontage | Continuous same-map zone; no invented E exit |
| crossroad | S mstreet4, N Goathill, E Green | None | Boundary geometry | Walkable Snow-side end of spine |
| Green boundary | /d/green/path6: W Snow crossroad, E path5 | None | New region | Visible staged closure at east, no live portal |
| Goathill boundary | /d/goathill/mroad1: S Snow crossroad, N mroad2 | None | New region | Visible staged closure at north, no live portal |

## MSTREET3

`d/snow/mstreet3.c` is both topology and service junction. Its east `DOOR_CLOSED` pairs with hockshop's west door; west herbshop has no authored door. No street NPC/reset object/custom action is declared. Physical street access is separable from either service. Staging herbshop closed is therefore a Type B omission, **not** a source lock.

## MSTREET4

`d/snow/mstreet4.c` has no east exit despite east-alley prose, and no `outdoors` field despite street identity. Whole-mudlib literal-reference searches for mstreet4/crossroad, plus Snow exit mutation/action scans, found no east-exit installer. Snow's discovered dynamic exit pair belongs to weapon_storage/secret_storage, not this street. Do not invent an alley route or a hidden quest. Negative search is repository evidence, not mathematical proof against arbitrary computed LPC calls.

Representing the street physically outdoors is Type B embodiment; it does not authorize adding an ES2 weather/gameplay flag. The same distinction applies to streets whose prose and mapping disagree.

## CROSSROAD

`d/snow/crossroad.c` names a mountain hollow and supplies a bandit-warning description. It declares no NPC, guard, interaction, damage, water source or entry check. It is still `outdoors=snow`. Implementing its Snow-side geometry need not spawn bandits or build either next region.

## GREEN / GOATHILL BOUNDARIES

Directly read both immediate destination files: `d/green/path6.c` and `d/goathill/mroad1.c`. They have the reciprocal exits shown above, their own outdoors region tags, and no local gating NPC/action. Pain/bandit descriptions do not implement damage or a gate.

Owner alternatives: A visible closed/labeled north/east boundary (**recommended**, Type B staged omission); B portal affordance returning typed “region not restored” (Type B, extra nonfunctional interaction); C stop before exposing crossroad (Type B, leaves main-axis endpoint absent); D build regions now (Type A content plus B embodiment, rejected scope expansion). Never claim an authored lock or invent a key. Crossroad is not access to Lake or authorization for Green water.

## HOCKSHOP SOURCE CONTRACT

`d/snow/hockshop.c` inherits `std/room/hockshop.c`. There is no active shopkeeper spawn. The inherited room itself registers **value, pawn, sell**, not retrieve. Each resolves `present(arg, this_player())`: direct held object, not nested root-owned descendants. A truthy `money_id` is refused. Appraisal and price use **`query("value")`, not `value()` and not stack amount × unit value**. Zero-value goods are refused for sale/pawn; negative truthy values are not rejected by those checks.

Exact executable rules:

- `value` quotes 60% pawn and 80% sell, integer division. No negotiation, skill, charisma, busy or fight test.
- `pawn`: announce → `pay_player(V * 60 / 100)` → destruct original item → return1.
- `sell`: announce → `pay_player(V * 80 / 100)` → destruct original item → return1.
- `pay_player` raises payouts below1 to1; creates silver first when payout/100 is nonzero, sets its **full amount before move**, attempts move without checking result, then creates/moves the coin remainder. Gold is never paid out.
- Goods remain carried during payout capacity checks. A failed first denomination does not prevent the second attempt or destruction of the goods. No source refund, transaction rollback, or automatic floor drop.
- No `no_drop`, equipped, quantity-selection, custody, ownership-record or redemption checks. Destroying equipped goods reaches item removal/unequip behavior through the existing destruction chain.

Examples from source arithmetic, not Native executions: V2000 → pawn1200 / sell1600 (silver12/16); V3 → pawn1 / sell2 coin. For V1, each percentage truncates to0 and the payout helper would raise it to1. However, `value_string(v<1)` assigns1 yet reaches no return because the returning branches are `else if`: pawn formats that result before calling the payout helper, so a driver string/type error could prevent payout. Sell does not format its price before payout and reaches the minimum1 helper directly. Keep the formatting/runtime ambiguity separate from the deterministic arithmetic; do not claim every low/negative-value pawn necessarily completes.

**There is no executable pawn/retrieve lifecycle here.** Both commands irreversibly destroy the supplied object at different rates. Sign text promises redemption, but no ticket, custody store, expiration, retrieve command or buyback table was found in this base or the mudlib reference/action search. A real redeemable pawn system would be Type C design, not this source migration.

## HOCKSHOP2

`d/snow/hockshop2.c` has an ordinary west exit to hockshop. Locked boxes, expiring goods and future auction are prose, without spawned goods, container state, guards, auction code or room gate. It is neither a proven NPC-only room nor the authority for pawn custody. Keeping its ordinary exit unavailable would be an explicit staged omission, not restoration of a source lock. It does not block a future counter-only service.

## HOCKSHOP NATIVE DEPENDENCIES

Existing foundations: semantic ItemInstance IDs, direct inventory, CombinedStack, source denominations, allocator, transfer/capacity, Equipment/Armor owner context, ItemLifecycle and save composition. Do not build a wallet or new inventory model.

Missing narrow boundaries: appraisal/offer result; source-grounded **current** sale-value projection; selected direct-held item identity; ordered denomination payout/result; goods destruction and companion food/liquid cleanup; player-facing irreversible-sale confirmation; explicit failed-payout ownership policy. `game/core/items/item_definition.gd` is identity-only, not a universal value database. `FoodState.current_value` becomes0 after eating; `SourceWineskin.VALUE` is20; source weapon-break hooks can mutate value. A static price for every instance would be wrong. Unknown source facts must not become guessed prices.

Combined payout uses `std/item/combined.c`: capacity admission happens before direct-living same-source merge; incoming object survives merge. Unlike Bank, Hockshop sets full payout amount **before** attempting admission, not default1 then growth. Existing goods may cause payout rejection even though destroying them later would free capacity. No preflight “net weight” optimization. `feature/move.c` detaches equipped items before destination validation; `adm/simul_efun/object.c` calls remove before driver destruction; `feature/clean_up.c` later removes ownerless clones. Exact cleanup timing is runtime-dependent.

S2 failed reward cleanup, S3B Bank cleanup and scoped Vendor cleanup **do not authorize Hockshop cleanup**. A future contract must separately select ordered partial-success, rejected-payout ownership and interrupted destruction handling. Immediate cleanup/refund/floor placement are distinguishable observable choices. Source pawn/sell require no new custody save state; invented ticket state would require new authority and is out of scope. Recommend later dedicated contract, not hiding commerce inside S7B.

## HERBSHOP SOURCE CONTRACT

`d/snow/herbshop.c` is an ordinary east-access shop. Cabinet/sign are descriptions, not a medicine dispenser or secret action. `npc/herbalist.c` inherits NPC + F_VENDOR and offers `medicine` → `/obj/drug/hurt_drug`, `snake drug` → `/obj/drug/snake_drug`. Prices are V2000 (20 silver) and V1000 (10 silver) through `feature/vendor.c`; unlimited newly created goods, not stock/cash accounting.

`cmds/std/buy.c` resolves the vendor in the current environment, rejects affordability2, calls payment before `compelete_trade`, then creates/moves goods with no move-result handling in F_VENDOR. This is not Hockshop's payout order. Existing payment/production definition projections are reusable; new medicines/use semantics and owner-reviewed failure policy remain necessary. The woodcutter is an authored wandering/chatting armed NPC, not an ingredient trader or a secret-room key in its inspected code.

## HERBALIST

杨掌柜's `heal_me` computes `eff_kee * 100 / max_kee`; >=100 says healthy, >=95 suggests medicine, below95 has no explicit return. It never heals, cures, charges, dispenses or schedules treatment. Additionally `feature/dbase.c` evaluates an inquiry closure with **this_object()**; `cmds/std/ask.c` queries the NPC's mapping. Thus the supplied `me` is the herbalist, not necessarily the asking patient. `adm/daemons/inquiryd.c` only formats generic inquiry topics and does not supply a missing treatment path. Treat incomplete body and receiver ambiguity as defects, not authorization to add a healer. Zero maximum would also make the division invalid.

## MEDICINE / HEALING DEPENDENCIES

`obj/drug/hurt_drug.c`: ordinary ITEM, weight30, value2000, one pill. Its `apply` action does not match an item argument; it rejects fighting, not busy. Compute `diff=max_kee-eff_kee`; diff==0 refuses; amount=min(20,diff); add directly to **eff_kee** then destroy item. No current-kee healing, condition, randomness or timed bandage. Above-max input produces a negative correction rather than that diff==0 refusal. Future translation needs a narrow selected-item interaction and exact supported state boundaries; do not silently substitute a differently clamped generic heal operation.

`obj/drug/snake_drug.c`: COMBINED_ITEM, value1000, initial amount1; misspelled `base_weiht` means expected weight is not established by the real `base_weight` consumer. Its apply action has no argument matching/fight/busy check. Only a **positive** queried snake_poison value is usable: replace with old−1, display according to new value, then stack amount−1. It does not remove the entry when it becomes0 or restore a resource. `set_amount(0)` schedules destruction without immediately setting stored amount/weight to0. It does **not** inherit `std/medicine/powder.c`; pouring a drug into liquid is not an implied feature.

`feature/condition.c` stores/replaces zero values. `daemon/condition/snake_poison.c` applies kee wound10 and sen current damage10, writes duration−1, **then** expires if previous duration<1. Therefore duration1 reduced by medicine to0 is not equivalent to “safe removal”: a subsequent source update still damages before expiry. `bandaged.c` cures effective kee by3 before decrement and expires at previous==0; it is not hurt_drug. Native `SnakePoisonConditionEffect`, `BandagedConditionEffect` and duration payloads already encode deterministic rules, but S5B does not schedule conditions and freezes recovery for **any entry**, including0. Do not equate handler existence with a playable cure loop.

Herbshop options: physical shop/static contact only (B, no new healing); hurt-drug vendor only (A effects + B selected item/contact; useful fast-cure sink); both drugs (adds condition timing/zero-lifetime and stack/save questions, premature); full inquiry/vendor (not full clinical healing, source is incomplete; invented treatment is C); all gameplay deferred with honest frontage (**recommended B staged omission**). None is authorized here. If owner makes medicine core, isolate a contract before implementation rather than quietly expanding conditions.

## HERBSHOP1 / SECRET CONTENT

`herbshop1.c` declares no exits, objects, trigger, prerequisite or return path. Full-mudlib literal `herbshop1` search found only its own file comment; herbshop/herbalist/woodcutter do not install access. Wall/cabinet prose does not prove a puzzle. Class E means isolated special content, **not a proven quest gate**. No dependency on ordinary shopping was established; do not invent access to complete a map.

## POSTOFFICE SOURCE CONTRACT

`postoffice.c` sign describes 10文 letters, free incoming mail, item fees and compensation. `npc/post_officer.c` inquiry callbacks `send_mail`/`receive_mail` instead return a prompt if Player already has temp `mbox_ob`; otherwise require the officer in its startroom, create MAILBOX_OB, attempt Player move, and reply. No executed fee, shipped item, refund or compensation mutation occurs in this path.

On leaving, `postoffice::valid_leave` destroys the Player's referenced temporary mailbox and returns1. The mailbox is a movable object in LPC for interaction binding, but not an ordinary acquired letter or durable inventory reward. Failure to move is not checked by the officer; mailbox `init` binds only in the Player environment.

## MAILBOX / MAIL INFRASTRUCTURE

`include/globals.h` resolves MAILBOX_OB to `obj/mailbox.c`. That file inherits ITEM + F_SAVE, sets no_drop/no_insert, owns an array of messages, registers mail/forward/from/read/discard, sets owner from Player account `id`, restores `/data/mail/<first-char>/<id>` and assigns temporary `mbox_ob`. It has no autoload item contract; owner death destroys it. Leaving destroys the access proxy, **not the saved mail file**.

Sending edits message text through `feature/edit.c`, asks whether to keep a copy (not a separate send-approval gate), acquires recipient via `adm/daemons/fingerd.c::acquire_login_ob`, updates/saves recipient new_mail, then writes either an existing recipient mailbox or a newly created temporary one. `/obj/login` supplies `/data/login/<first-char>/<id>` through F_SAVE. Offline delivery destroys temporary mailbox/login objects; online recipients without an open mailbox take the temporary-creation path without that offline cleanup branch. Missing recipients fail lookup; `confirm_copy` still prints “Ok”, which is not reliable delivery proof. Some discard/forward numeric lower-bound checks are absent. This is account-addressed persistent communication, not a quest journal.

Network mail files were separately located (`adm/daemons/network/mail_serv.c`, `netmail.c`, services/mail_a.c, services/mail_q.c); mail_serv was read and netmail's queue boundary inspected. They deal with remote MUD/socket/queue/global postal storage, and are **not called by the inspected Snow mailbox path**. No need to port them to make an offline Snow counter. Some network headers are external/missing in this tree; no claim is made that intermud mail currently boots. `feature/save.c` and `feature/edit.c` were read; Native must not emulate save_object/input_to or account files.

## MULTIPLAYER PRODUCT-FIT ANALYSIS

Full player-to-player postal semantics are outside approved single-player identity (display name + source binary gender, no login/password/email). A fake self-addressed inbox or NPC letter-quest service would change WHAT/WHY and is Type C, not a cheap mail migration.

Options: A full mail required (A user semantics, major out-of-product account/network architecture; reject); B interior + static officer, explicitly no mail (B, cosmetic scope); C visible frontage only (**recommend**, B staged omission); D entire postoffice omitted (B, less legible north street). C preserves recognizable service location without fake functionality or a saved mailbox ItemInstance. No new NPC contact is authorized merely by building a frontage.

## SCHOOL REBASELINE

Do not conflate `school.c` literacy school south of sroad2 with `school1/2/schoolhall` martial compound east of mstreet1. The actual school room spawns `npc/teacher.c`: 500-value recognition/marks and literacy teaching dependencies, not the alternative teacher1 file. Its follow callback is declared but the implementation is commented; restoring all NPC behavior needs separate defect review.

Martial entry has a paired closed door, guard; court has six trainees and `npc/fist_trainer.c`, whose teaching/sparring checks require 封山剑派 membership. `daemon/class/swordsman/master.c` checks effective courage/composure >=20, recruits and assigns swordsman class. It is not a free universal trainer. The guard's identity inquiry triggers random revelation/combat/book behavior, not a normal entrance fee. Ordinary room code does not impose a hidden faction gate on walking into every compound room.

Existing typed skill/learn-policy foundations do not provide full teacher population, lineage/recognition persistence, dialogue, room reset or apprenticeship interactions. School adds substantial legitimate future progression, not a prerequisite for current Work/Bank/supply/recovery. Recommend later milestone. No automatic bamboo sword or character boost.

## SMITHY REBASELINE

`d/snow/npc/smith.c` is NPC, not F_VENDOR. `buy_object` accepts only Chinese “铁锤” for300; `compelete_trade` creates/moves a hammer. Hoe/shovel being sold out is inquiry text. No repair, forging or crafting code exists here. `npc/obj/hammer.c` has weight8000/value3/damage15: shop price300 is not resale value3.

`std/weapon/hammer.c` supplies bash/crush/slam actions; `adm/daemons/weapond.c::bash_weapon` can disarm/drop/break a victim weapon on parry, mutate name/value/weapon_prop and draw RNG. Full hammer parity is more than a merchant button and must be checked against currently staged combat hooks. Defer smithy commerce; do not claim it provides repairs or is needed to wear existing looted equipment.

## OTHER DEFERRED SNOW CONTENT

| Access category | Rooms / source evidence | Dependency and treatment |
| --- | --- | --- |
| Ordinary active | Inn, Bank, Workplace; Table1 A roads | Keep current implemented service contract |
| Ordinary optional | Herbshop, Hockshop, Postoffice, Smithy; doors only where declared | Closed frontage is staged B, not a fictional source quest lock |
| Optional lodging | inn_2f and e/n/w_room | Source doors, rats; prose ranks/payment not executable gating |
| Optional progression | school, school1/2/hall, innerhall/inneryard/nyard/guestroom | Teacher/faction/NPC/presentation; no supply prerequisite |
| Ordinary storage | hockshop2; weapon_storage | Not automatically NPC-only; first has no service state, second free weapon plus separate puzzle |
| Secret | herbshop1; secret_storage | Former access unresolved; latter authored dynamic route, not ordinary commerce |
| Local special | temple | no_fight, donation/bellicosity/RNG, paper seals; not a verified healer/revive service |
| Cross-region | crossroad; sroad4/5; outgoing edges of eroad3/sroad1 | Green/Goathill/Canyon/Waterfog/temple/dragonhill remain explicit boundaries except existing Old Pine |

`weapon_storage.c::push`: empty argument fails; exact “shelf” only hints; another nonempty argument increments counter. At exactly3, adds down and only if secret_storage is already loaded installs its up exit; delayed10-second close removes both; reset clears counter. First-load return can therefore be missing; do not invent a reliable ordinary stairway. `temple` keeper's donation acceptance can lower bellicosity with RNG; denotation object's insert helper is not proof all generic put paths call it. No recovery service is implemented by those files. These special behaviors do not block the recommended finish line.

## DOOR / PHYSICAL-INTERIOR POLICY

Source pairs: mstreet3 E ↔ hockshop W; school1 E ↔ school2 W; inn_2f W/N/E ↔ guest-room E/S/W; Inn NW wizard door. `include/room.h` defines CLOSED/LOCKED/SMASHED, but `std/room.c::valid_leave` tests CLOSED; inspected open/close command/base paths do not implement a generic key requirement. They synchronize already-loaded opposite room state. Opening uses logical-not of CLOSED in a mask expression; don't silently normalize this legacy bit behavior.

Continuous small interiors or proximity counters are reasonable B embodiments when their service is authorized. An operable source-closed Hockshop door would need a narrow door interaction or an explicit always-open substitution. **Recommended S7B needs no generic door state**: visible non-passable frontage, honest deferred-service label, no quest/key fiction, no hidden functional NPC. Staged closure of originally open shops is explicitly observable B. Keep deferred interior space nonwalkable, rather than offer a broken transition. Secret/storage closures must not masquerade as restored puzzle semantics.

## CURRENT GAMEPLAY LOOPS

Current HEAD supports source New Game at Snow Inn (Human14, attributes30, potential99, exp0, gin/kee/sen100, food/water400, body80000/capacity150000, cloth armor+1, empty hands/no money/no skills); name/binary gender; walking and existing Old Pine link. Work spends sen30 then gin30 and creates real silver; insufficient resources reject before allocation. Bank converts physical coin/silver/gold with approved ordering; Inn sells source dumpling and wine-filled wineskin. Eating, Waterfall Fill to15 clear-water portions, Drink+30, and eligible metabolism/recovery make repeat preparation possible. Buying wine does not authorize drinking alcohol.

Old Pine already supplies encounters, loot/corpse interaction, equipment and save continuity; this is not a claim a fresh exp0 character wins all encounters or travels every route freely. Source nonpositive-dodge Vine selection is the approved Waterfall access substitution; don't add a Snow tap, easier bandit or teleport as part of this analysis.

| Service (Table3) | Source value | Current status | Single-player relevance | Added complexity / persistence | Recommendation |
| --- | --- | --- | --- | --- | --- |
| Bank | Convert denominations; empty deposit | Implemented bounded exchange | Essential payment access | Existing item/allocator authority | Sufficient |
| Workplace | Resource cost → silver | Implemented | Repeat income | Existing resources/items | Sufficient |
| Inn vendor | Source-priced goods | Dumpling + wineskin, staged contact | Food/water preparation | Existing food/liquid/item schema3 | Sufficient selected offers |
| Herbshop | Medicines, incomplete inquiry | Absent | Useful faster wound cure | Medium; medicine definitions/use/save validation, poison timing if included | Later; no absolute cure gap |
| Hockshop | Quote / irreversible 60% pawn, 80% sell | Absent | Highest-value new economic loop | Medium; value/payout/lifecycle policy, no source custody | Later dedicated contract |
| Postoffice | Account mail | Absent | Little current product fit | High external/account persistence | Frontage only, gameplay deferred |
| School | Literacy / faction training | Absent | Important later progression | High teacher/family/recognition state | Later progression |
| Smithy | Hammer300 purchase | Absent | Optional weapon commerce | Weapon/action fidelity + definition restore | Later |

## HEALING GAP

`feature/damage.c::heal_up` and `game/core/characters/character_recovery.gd` already restore **effective** values by1 when the current-resource gain reaches the old effective cap. Order: water/food decrement → Player water<1 stops → gin/kee/sen gain `con/3 + current atman/force/mana /10`, each current capped to old effective then effective+1 if below maximum → Player food<1 stops → internal atman/force/mana raw-skill halves and caps. Food0 does not alone prohibit primary recovery; water1 becomes0 and stops it that opportunity.

Example: con30, force0, kee current70/effective80/max100 → one eligible opportunity gives current80/effective81. From current=effective80, 20 such opportunities reach current99/effective100, then another reaches100/100. S5B provides2-second pulses, 6–15 pulses/opportunity: 21 complete intervals would cost252–630 **eligible** seconds, not a wall-clock guarantee or proof of current remaining phase. There is no need to purchase medicine to escape every ordinary effective wound.

`oldpine_world_session_controller.gd::player_recovery_time_allowed` requires source revision, live ACTIVE Player, active map/body consistency, open application/world gates; Pause, transition, restore/swap, combat/fighting, any condition and failed partial handoff freeze it. Busy separately consumes pulse time without advancing count. No condition scheduler, offline catch-up, automatic revival or combat recovery is implied. Thus fast medicine is a convenience/money sink; poisoned, unconscious/dead or locked encounter states remain distinct staged limitations. A medicine vendor alone cannot close those gaps. Bandaged handler existence is not a currently usable timed bandage loop.

## ECONOMY / LOOT-MONETIZATION GAP

Loot can be equipped/kept but cannot currently be converted to money through a Snow sale outlet. Bank exchanges money only. Work funds present goods, so lack of selling does not prevent current supply loops; it does limit the economic reward of excess equipment. **Hockshop sell is the strongest next optional commerce feature**, more directly additive than mail or an empty shop. No source redeemable pawn loop has been demonstrated. Do not label junk's appraisal a wallet balance or assume source prices multiply quantity.

Owner may require loot→sell before final PR (Option3); that would expand the proposed completion contract and require a separate approved payout/value contract plus implementation. Current recommendation accepts this explicit deficit rather than manufactures extra mandatory slices.

## SAVE/PERSISTENCE IMPACT

Root schema2 only; source revision `SOURCE_ENTRY_V1`; embedded item schema3 with currently supported legal older item versions. No new root/schema/revision authorized. Player body/capacity are independent persisted facts; no strength-derived rebuild. Pre-cutover development saves remain unsupported.

- North zones in the same resident: no new intrinsic mutable authority; definitions/zone adjacency/physical placement validation must agree. Preserve existing zone extents/save positions where possible. `game/runtime/persistence/oldpine_map_placement_validator.gd` derives Snow zone footprints from actual scene nodes and rejects collisions/ambiguous ownership. New valid zone IDs still need definition-aware restore and cold-save tests; “no schema change” is not “no Save work.”
- Static frontages/closed region bounds: no dynamic door/quest state. New maps/portals/NPC ledger entries are unnecessary for recommended S7B.
- Hockshop source sale: existing inventory/stacks/equipment/allocator and current value facts; destroyed goods must not reappear. No custody/tickets by source. New mutable value behavior would need explicit persistence modeling only when supported content requires it.
- Hurt drug: production definition/validator/use/lifecycle integration; consumed ID disappears, resource mutation already saved. Snake drug additionally needs positive/zero condition and pending-destruction semantics, not just one item definition.
- Mail: external per-account persistent store, deliberately not Native ItemSnapshot or gameplay save. School: potential family/marks/teacher persistence. Smithy: canonical hammer definition/actions and normal item restore. None is implemented here.

## PROPOSED CORE-HUB COMPLETION DEFINITION

**Finish line proposed to owner:** source-valid public birth + existing central/east route + continuous Square–mstreet1–mstreet2–mstreet3–mstreet4–crossroad axis + functional current Work/Bank/Inn food/water/recovery preparation + existing Old Pine excursion link + exact current save/cold continuation. Visibly and explicitly stage deferred local services, southwestern roads and external regions. Preserve current no-population/staged-contact boundary. Validate closure without inventing healing, loot-sale, teaching, key, NPC or mail functionality.

This is a **bounded Core Hub**, not complete Snow or all ordinary public geography: sroad2/3, sroad4/5 approaches and optional interiors remain named deferrals. Missing fast cure, monetization and training must be visible in final review. If owner rejects any of those omissions, revise this finish line before authorizing the next implementation.

## PHYSICAL COMPLETION OPTIONS

| Option | Fidelity / player value | Scope / dependencies | Judgment |
| --- | --- | --- | --- |
| 1 Central functional core only | Current loops work; north still a stub | No implementation; final audit possible if owner explicitly accepts | Smallest, less coherent main-axis endpoint |
| 2 Main north street spine | Source-shaped service junctions and end-of-town boundary; services honestly deferred | One physical slice, existing resident/Save authority | **Recommend**; bounded main axis, not literally every Snow road |
| 3 Spine + selected service | Adds meaningful loot-sale or fast-cure loop | Service contract + implementation beyond road work | Good later expansion or owner-selected larger finish line |
| 4 Near-complete ordinary town | Most interiors usable, more population | Doors, teachers/factions/medicine/mail decisions; high creep | Not necessary for current Core Hub |

All preserve A source facts plus B embodiment/explicit omission. None authorizes C new mechanics. “Full ordinary spine” here must not silently swallow all west/south road branches; if owner intends *all* ordinary streets, sroad2–5 scope must be separately selected.

## OWNER DECISIONS REQUIRED

Table5 contains recommendations only. No choice below is recorded in DECISIONS or treated as approved.

| Decision | Alternatives / classification | Recommendation |
| --- | --- | --- |
| A Physical extent | Current stub B; main north axis A+B; all38 A+B with major scope | North through crossroad, west/south branches still deferred |
| B Green/Goathill | Visible closure B; unavailable portal B; omit crossroad B; regions now A+B | Visible labeled closures, no portal/event pretending to traverse |
| C Hockshop | Full executable quote/pawn/sell A+B; physical-only B; all deferred B; invented redemption C | Deferred gameplay, frontage only; later scoped source contract |
| D Herbshop | Static-only B; hurt-only A+B; both drugs A+B with conditions; full source inquiry A+B; invented clinical treatment C | Frontage; defer medicines/inquiry gameplay |
| E Postoffice | Full source account mail A + out-of-product infrastructure; static interior B; frontage B; omit B; local fake inbox C | Frontage, no mail/NPC authority |
| F School | Source training A+B; staged deferral B; free substitute progression C | Later progression, not Core blocker |
| G Smithy | Source hammer commerce A+B; staged deferral B; invented repair/crafting C | Later weapon/commerce scope |
| H Ordinary interiors | Build all A+B; honest closed frontages B; omit with named deferral B; fictional quest/key locks C | Frontages on approved exposed spine; preserve existing documented closures |
| I Secret/storage | Restore source routes A+B; explicitly defer B; invent secret triggers C | Do not block closure unless ordinary selected service demonstrably requires them |
| J Effective-wound loop | Existing eligible recovery A with approved timing B; fast medicine A+B; free healer C | Existing slow cure sufficient; document frozen states and time cost |
| K Loot monetization | Require source sale A+B; explicitly defer B; generic wallet/vendor sell C absent source proof | Accept current no-sale gap for bounded core; highest-priority later commerce |
| L Completion rule | Current core B; proposed north/core finish line A+B; near-total Snow A+B; redesigned town C | One bounded implementation then distinct final audit, owner review and separately authorized PR |

## RECOMMENDED REMAINING SLICE PLAN

| Order / candidate | Nature / purpose | Dependencies / breadth | Required under recommendation / stop |
| --- | --- | --- | --- |
| Owner review of S7A | Choose A–L and exact finish line | No implementation yet | Required; resolve any larger scope before coding |
| S7B North Street Physical Spine | One implementation: mstreet3/4/crossroad, honest storefront/external bounds in existing outdoor resident | Typed definitions, geometry/collision/zone joins, labels, existing Save placement; no service/NPC/door scheduler | **One remaining implementation before audit**; focused tests, separate verification, real walking/Save/cold Continue; STOP owner review |
| Final Snow audit | Distinct whole-milestone integration gate | Approved boundary, focused + complete canonical/Python/editor/sanitizer and required player-visible evidence | After S7B approval; no automatic implementation expansion |
| Final owner review / final PR | Integration, not another gameplay slice | One branch/one PR; same-head four-job CI; explicit merge authorization; post-main CI | Separately authorized; no PR in S7A |

If owner chooses sale or medicine, add **one focused service contract + one selected service implementation** before final audit; do not hide them in S7B or invent an indefinite numbered chain. Current recommended plan requires no School/Smithy/Mail implementation. S7B has not been authorized.

Future test impact (inspection only, no tests edited/run): topology `game/tests/runtime/snow_outdoor_route_test.gd`, `snow_oldpine_connection_test.gd`; existing Work/Bank/food/water/recovery runners; `versioned_source_save_test.gd` and relevant cold-process runners for new-zone/unchanged old-position continuation; physical actual-input north walking/backtracking, collision barriers, unchanged Inn/Work/Bank access and representative Save→fresh Continue. If services selected later: finance plus item lifecycle/save tests for payout, medicine effective/current/zero-condition boundaries and definition restore. Static scenes/controller calls cannot prove physical traversal.

## FINAL PR READINESS CHECKLIST

- Owner-approved final boundary and S7B closure; no unreviewed Type B substitution or invented Type C content.
- Public source New Game unchanged; same name/gender, stats/body/cloth/no money/skills and Snow Inn birth.
- North topology/zone ownership/walking/collision and explicit Green/Goathill/frontage bounds; no invented east mstreet4 path or accidental side exit.
- Work ordering/no-allocation rejection and its **S2-specific** rejected-reward policy; real currency identity, Bank exact-denomination/partial-order behavior; no wallet/accounts.
- Inn purchases/food, wineskin/Waterfall/drink, eligible recovery and freeze behavior; no alcohol/condition-time expansion or source-formula changes.
- Existing Old Pine encounter/loot/equipment/return routes retained; no claim all fresh-player encounters can be won or bypassed.
- Save/cold Continue old legal positions and new north positions, exact resource/item/allocator/body identity facts; schema2/item3/SOURCE_ENTRY_V1; no pre-cutover compatibility promise.
- Current focused tests and final complete canonical/Python/static/editor/repository-content sanitized checks; honest actual-input evidence where applicable, no recycled screenshots as new proof.
- Updated STATUS/ROADMAP/phase audit, owner-approved decisions only, all named omissions; reference delta0 and no owner-local tooling changes.
- Separate final PR authorization, same-final-head Godot/Windows/Android/iOS checks, explicit merge permission, then post-main checks. No final PR now.

## OUT OF SCOPE

No S7B, streets/scenes/UI/NPC implementation, full population, new shop actions, currencies, medicine, condition scheduler, schools/teaching/apprenticeship/bamboo sword, smithy weapons/repair, postal accounts/inbox, secret rooms, Green/Goathill/Canyon/Waterfog/temple region/dragonhill, Lake, five production serpents, Phase5B4, schema/revision change, PR or merge. Source scans are not authority to implement adjacent content.

## VERIFICATION

Evidence is source/static analysis, not new runtime PASS. Read required current phase/operational docs, Native Save contract, all38 root Snow rooms, native world definitions/scenes/controllers, recovery and relevant item/condition/save consumers. Rechecked LPC ROOM/doors, HOCKSHOP, BANK, finance, vendor/buy, ITEM/Combined/move/cleanup/destruction, drugs, condition/recovery, inquiry, local mailbox/account save/editor and relevant NPCs. Important directly read dependencies beyond table rooms:

- `std/room.c`, `std/room/hockshop.c`, `std/room/bank.c`, `std/item.c`, `std/item/combined.c`, `std/medicine/powder.c`, `std/weapon/hammer.c`;
- `feature/move.c`, `clean_up.c`, `finance.c`, `vendor.c`, `dbase.c`, `damage.c`, `condition.c`, `save.c`, `edit.c`; `cmds/std/buy.c`, `ask.c`, `open.c`, `close.c`;
- `include/globals.h`, `include/room.h`; `adm/simul_efun/object.c`, `adm/daemons/inquiryd.c`, `fingerd.c`, relevant `weapond.c::bash_weapon`, network mail scope as above;
- `d/snow/npc/herbalist.c`, `woodcutter.c`, `post_officer.c`, `teacher.c`, `smith.c`, `guard.c`, `fist_trainer.c`, `keeper.c`; `d/snow/npc/obj/hammer.c`, `d/snow/obj/denotation.c`; `daemon/class/swordsman/master.c`;
- `obj/drug/hurt_drug.c`, `obj/drug/snake_drug.c`, `obj/mailbox.c`, `obj/login.c`, `obj/money/coin.c`, `silver.c`, `gold.c`; `daemon/condition/snake_poison.c`, `bandaged.c`;
- `d/green/path6.c`, `d/goathill/mroad1.c` (immediate boundaries, not full regions).

Searches across the mudlib checked target room references, hockshop/retrieve/pawn-ticket/auction references, mail entry points, and Snow dynamic exit mutation. No detected dynamic east mstreet4 route, herbshop1 access, or executable pawn redemption. Absent-pattern results are qualified, not proof against all computed runtime code. Network service/header incompleteness is not a reason to implement missing infrastructure. Historical missing waiter cake and incomplete teacher/herbalist/secret behavior remain defects/deferrals, not fixed content.

Only four Markdown documents change. Static validation PASS: 38/38 unique source-room rows and category counts; 82 local document links across the four edited documents; fully qualified Native evidence paths; `tools/ci/repository_checks.py`; `git diff --check`; trailing whitespace0; exact allowed-path delta and production/tests/reference/DECISIONS/build/CI/export deltas0. No Godot suite, editor, live game, sanitizer or Python test-suite rerun is claimed or needed for this docs-only slice. Final commit/push identity is reported externally to avoid self-referential SHA edits.

## STOP STATE

S6B — OWNER APPROVED / CLOSED. S7A — ANALYSIS COMPLETE / AWAIT OWNER REVIEW. All recommendations remain proposals. S7B implementation and final Snow PR are NOT AUTHORIZED. No new phase begins automatically.
