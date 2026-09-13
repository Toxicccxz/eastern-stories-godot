# S6A — Snow Water / Drink Source Contract

## EXECUTIVE RESULT

**ANALYSIS COMPLETE — AWAIT OWNER REVIEW. No S6B implementation authorization.**

ES2 decides WHAT / WHY / RESULT; Godot decides native architecture, physical embodiment,
interaction translation and presentation. Type A is semantic migration; Type B is an explicitly
accounted native translation/substitution; Type C changes game design and requires owner approval.

**SOURCE FACT:** renewable non-alcoholic water exists. Snow's 38 rooms have no `resource/water`;
Old Pine has four such rooms, of which Waterfall and both Riverbanks already have Native physical
embodiment. A source wineskin can discard its fresh wine and fill clear water without drinking wine
or applying drunk. It survives empty and can repeat this indefinitely.

**CURRENT NATIVE FACT / IMPORTANT BLOCKER:** this is NOT yet a usable fresh-player loop. There is
no liquid content/action/persistence, and fresh source Player has effective dodge0. The existing
Vine policy explicitly refuses non-positive random bounds. The Pine shortcut does not provide a
reverse route into Cliffside/River. Do not reuse the old technical player's successful Vine route
as fresh source-player evidence, or silently decide `random(0)` here.

**RECOMMENDATION:** retain the water-only wineskin loop as the smallest *liquid-system* candidate,
prefer the existing Waterfall location if owner separately resolves the entrance dependency.
Without that resolution, the nearest inspected deterministic source-route alternative is Green
station0 via six deferred room identities from current mstreet2; that is a larger topology scope,
not an already-playable Snow well. Neither alternative is authorized by this analysis.

| Requested path | Finding |
| --- | --- |
| A: direct environmental drink | Exists globally at Choyin s_street1; none in Snow/Old Pine. Do not transplant it. |
| B: container + resource room | Source-proven renewable, no alcohol required; existing Old Pine embodiment has the fresh-player entrance blocker above. |
| C: purchased alcohol only | Waiter source sells full wine; repeated purchases are supply, not a refillable water source. Full alcohol runtime remains blocked. |
| D: another authored item | Water calabash/tea, melon and custom cola exist elsewhere; no current Native acquisition. |
| E: no current path | True for an immediately usable current fresh Native loop, FALSE as a claim that ES2 or the represented Old Pine rooms contain no renewable water. |

## EXACT BASELINE

Repository `Toxicccxz/eastern-stories-godot`; branch `phase/snow-town-core-hub`.
Starting local HEAD and actual remote branch: `add93fcf17aba82ebc05bbf5c3eb9972feb73e4d`
(`Add player recovery metabolism cadence`). Local origin/main and remote main:
`047f29083e881156abbdad6ed480bffc1350dfa8`; merge-base equals that main. Initial working tree clean;
GitHub open-PR query for this branch returned none. No branch change, reset, stash or cleanup.

## S5B CLOSEOUT

Owner explicitly approved/closed S5B at the starting HEAD. Its implementation document receives
only a current approval annotation; A–M decisions and historical evidence are retained. S1 through
S5B are OWNER APPROVED / CLOSED. S6A is analysis only; S6B and final Snow PR are NOT AUTHORIZED.
See [S5B](PHASE_SNOW_TOWN_CORE_HUB_PLAYER_RECOVERY_CADENCE.md),
[S5A](PHASE_SNOW_TOWN_CORE_HUB_RECOVERY_METABOLISM_CONTRACT.md),
[DECISIONS](DECISIONS.md), and [Native Save contract](../production/contracts/NATIVE_SAVE_LOAD_CONTRACT.md).

## SOURCE COVERAGE

Unless prefixed `game/`, LPC paths below are relative to `reference/es2/mudlib/`.
No external port, driver execution, gameplay test or live-player proof is claimed.

- Completely read the required `feature/liquid.c`, `obj/example/wineskin.c`,
  `d/snow/npc/waiter.c`, `cmds/std/buy.c`, `feature/vendor.c`, `feature/finance.c`, `feature/move.c`.
- Inspected inheritance/helpers: `std/item.c`, `std/room.c`, `feature/dbase.c`, `feature/treemap.c`,
  `feature/name.c`, `include/dbase.h`, `include/name.h`, `doc/applies/init`, `doc/efuns/add_action`,
  `evaluate`, `replace_program`, `random`; recovery/condition portions of `feature/damage.c`,
  `std/char.c`, `feature/skill.c`, and complete `feature/condition.c`, `daemon/condition/drunk.c`.
- Full-source structural searches used `rg -uuu` for `resource/water`, resource/water key variants,
  F_LIQUID/inherited liquid, max_liquid, liquid mappings/remaining, drink/fill actions, water_supply,
  water mutations and receive_healing. Broad resource/key scans complement literal slash searches;
  prose water, commented inheritance and action definitions are classified separately.
- Read all ten declaring water rooms and all eleven active F_LIQUID item definitions below,
  plus `d/village/obj/melon.c`, `d/latemoon/sell/wine.c`, `d/canyon/npc/obj/cola.c`,
  `std/medicine/powder.c`, `obj/toy/poison_dust.c`, `feature/food.c`, `d/green/water.c`,
  `daemon/skill/serpentforce.c`, and `d/snow/npc/drunk.c`. Acquisition references were searched
  globally; a reference hit is not proof of a complete runnable distant quest/vendor.
- All 38 Snow room files were read: bank, crossroad, e_room, eroad1/2/3, guestroom, herbshop,
  herbshop1, hockshop, hockshop2, inn, inn_2f, innerhall, inneryard, mstreet1/2/3/4, n_room, nyard,
  postoffice, school, school1/2, schoolhall, secret_storage, smithy, square, sroad1/2/3/4/5,
  temple, w_room, weapon_storage, workplace (each under `d/snow/`, suffix `.c`). Snow NPC/object
  loadout/vendor/water references were rescanned; only waiter/drunk supply the relevant wineskin.
- Followed route files `d/oldpine/npath1.c`, `npath2.c`, `npath3.c`, `clearing.c`, `epath1.c`,
  `epath2.c`, `epath3.c`, `passage.c`, `cliff1.c`, `cliffside.c`, `pine1.c`, `pine4.c`, `pine7.c`,
  and `d/green/path5.c`, `path6.c`, in addition to the water rooms. Adjacent-alternative comparison
  also read `d/canyon/road.c`, `canyon1.c`, `canyon2.c`, `canyon3.c`, `canyon4.c`, `camp1.c`,
  `npc/door_guard.c` (camp2 is already in the water inventory).

Current Native source checks include `game/data/oldpine/oldpine_world_definitions.gd`,
`oldpine_item_content_definitions.gd`, `oldpine_native_item_definition_projections.gd`,
`game/scenes/world/oldpine/oldpine_outdoor.tscn`,
`game/runtime/world/oldpine_vine_traversal_adapter.gd`, `oldpine_world_session_controller.gd`,
`game/core/world/vine_traversal_policy.gd`, `game/core/skills/character_skill_state.gd`,
`game/data/items/source_player_cloth.gd`, `game/core/characters/character_recovery.gd`,
`player_recovery_cadence.gd`, `game/core/conditions/condition_system.gd`, and persistence files
listed below. Historical route evidence was cross-checked, not treated as a new live run.

## ALL `resource/water` LOCATIONS

Ten declarations, all `set(..., 1)`. Two slash-key consumers: F_LIQUID fill and serpentforce practice.
The latter is a skill eligibility check, not a drinking action. No depletion/reset quantity is used.

| Source room | Display / source domain | Flag | Current Native / reachability and dependency |
| --- | --- | --- | --- |
| `d/oldpine/waterfall.c` | 瀑布前 / Old Pine | 1 | Yes, waterfall_basin; Vine conditional entrance, or Passage south. First existing-location candidate. |
| `d/oldpine/riverbank2.c` | 山涧之中 / Old Pine | 1 | Yes, river_gorge; walk south from Waterfall. |
| `d/oldpine/riverbank1.c` | 山涧之中 / Old Pine | 1 | Yes, same river_gorge; continue south from riverbank2. |
| `d/oldpine/lake.c` | 水潭 / Old Pine | 1 | No; riverbank1 south is physically closed; five authored serpents, no reason to open Lake for water. |
| `d/green/station0.c` | 工作站 / Green | 1 | No; source route from Snow crossroad via path6/path5. `outdoors="snow"` does not make this a Snow room. |
| `d/latemoon/latemoon3.c` | 傍厅 / Late Moon | 1 | No; south latemoon1, yumay tea interaction/return policy; distant region and access restoration. |
| `d/latemoon/room/bathroom.c` | 小花池 / Late Moon | 1 | No; west bathroom1, authored NPCs/bath action. Those referenced local files exist; not a proven current-player route. |
| `d/choyin/cloudpool.c` | 云梦大泽 / Choyin | 1 | No; southwest solidpath2, four serpents; distant region/hazards. |
| `d/choyin/s_street1.c` | 南门广场 / Choyin | 1 | No; bridge1/s_street2/s_street4/sw_road1 exits; also a real direct-drink well. Distant region. |
| `d/canyon/camp2.c` | 营火区 / Canyon | 1 | No; ten deferred identities from current sroad1 plus damaging chain traversal; larger than Green. |

Remote rows record executable local exits, not a certified full route from Snow. Since an existing
Old Pine location and bounded adjacent Green/Canyon alternatives were checked, distant world routes are
not expanded into this slice. `d/green/water.c` has water prose/search-for-sword, but NO water flag
or drink/fill provision. Bridge epath2's water prose likewise does not authorize filling there.

## SNOW WATER SOURCES

None in the 38 rooms, including Inn/Workplace/Bank. The waiter's tea greeting is presentation,
not a Player water mutation or item grant. Source offers are dagger50, wineskin20, dumpling15,
chicken leg30; only dumpling is currently Native. The mstreet2 drunk carries the same example
wineskin and conditionally commands drink/drop when empty, but that NPC is not implemented and
its chat/command success is not a guaranteed fresh-player free-container service. No other Snow
liquid supplier was found. Do not add water to Snow from a place name or descriptive text.

## CURRENT OLD PINE WATER SOURCES

`oldpine.outdoor.waterfall_basin` represents waterfall; `oldpine.outdoor.river_gorge` represents
riverbank2/1. Scene has WaterfallBasinZone, RiverGorgeZone, river water collision, east-bank walking
space and a closed Lake boundary. **Physical water is not an implemented fill capability.**
No current production liquid/wineskin definition or action was found in `game/core`, `game/data`,
`game/runtime`. Data metadata alone does not prove player entry, nor does a screenshot of water.

## SOURCE TOPOLOGY / REACHABILITY

Shortest inspected source path from Square to the nearest Old Pine water:

`square → sroad1 → eroad1 → eroad2 → eroad3 → npath1 → npath2 → npath3 → clearing → epath1 → epath2`
then **hold vine → waterfall**, or **hold vine → passage → south waterfall**.
Inn is one west/east link from Square. All ordinary links up to the bridge are already represented
by the current Snow/Old Pine connection; there is a resident-map handoff at the Snow/Old Pine join,
not one scene per source room. Waterfall branch stays Outdoor; Passage branch uses existing Cave
handoff and SouthExit. No new map is needed *if the entrance is available*.

The actual source branch is `random(query_skill("dodge")) < 5`. Native adapter supplies
`raw dodge / 2 + mapped special + armor dodge`; it does not use base dexterity. Fresh has no skills,
cloth dodge0; the existing leather has dodge-2, not a way to solve this. Bounds1–5 select Waterfall;
larger positive bounds may select Passage. Bound0 is unresolved historical-driver behavior and
currently returns `LEGACY_RANDOM_BOUND_AMBIGUITY` without traversal. Existing DECISIONS explicitly
lock that failure boundary. **No training, starting dodge, clamp or RNG substitution is authorized.**

Once reached: waterfall ↔ riverbank2 ↔ riverbank1 (continuous current terrain); riverbank1
`climb cliff` → cliff1; `climb up` → cliffside; north → pine1. These source climb actions have no
skill/RNG/resource test. Native Pine ↔ Outdoor shortcut provides a return to the main outdoor area,
then Snow, but Pine → Cliffside does NOT exist. The shortcut therefore cannot bypass entry to water.
See [closed River/Cliff route](PHASE_9B3B3_RIVER_CLIFF_PINE_ROUTE.md); its historical technical-player
runtime evidence is not proof of a present fresh dodge0 journey. Lake south stays blocked; Pine's
cliffdown boundary is not an authorized back door to riverbank1. Bandit presence remains a journey
risk; do not guarantee safety by changing aggression.

**Deterministic adjacent alternative:** current Workplace → mstreet2 → **mstreet3 → mstreet4 →
crossroad → Green path6 → path5 → station0**. From current mstreet2 this is six source edges/new room
identities; all six are not yet Native. Source exits are bidirectional along this chain with no
water-route skill/RNG check. Snow streets can form a continuous extension; Green boundary needs
explicit region/map/zone/entry ownership (same physical map versus resident handoff is owner-reviewed
Type B design). Other exits may be explicitly closed, without spawning all adjacent NPCs/shops.
Generic F_LIQUID fill can use station0's flag without porting its suspect custom `fillwater` verb.
This is the nearest inspected non-Vine alternative, not a proof of a globally shortest MUD path.

The adjacent Canyon comparison is current sroad1 → sroad2 → sroad3 → sroad4 → Canyon road →
`climb chain` canyon1 → canyon2 → canyon3 → canyon4 → camp1 → camp2: ten deferred room identities.
Road descent first damages gin20/kee30/sen10; canyon1 ascent back damages gin30/kee40/sen20.
Both move even on their negative-resource branch, rather than refusing admission. Camp1 authors
two peaceful door guards; there is no custom guard admission function in the inspected guard file.
This requires more physical content and damage/life integration than Green; it is not a smaller
safe water-access shortcut. Side exits/content remain a separate restoration decision.

## DIRECT DRINK SEARCH

No generic `cmds/.../drink.c` environmental action or Snow/Old Pine room drink action was found.
`d/choyin/s_street1.c` is a genuine exception: room init registers drink; only current water >= cap
refuses; otherwise message then water +=20, no container, busy/ghost/fighting check or busy mutation.
At cap400, 399→419. Tied cups are prose; the function does not allocate a cup. This cannot be copied
to the Snow Inn or Old Pine river as Type A.

Other drink hits: `d/latemoon/sell/wine.c` is COMBINED_ITEM, checks a nonempty argument, gin damage10,
sen heal20, amount-1, no water gain; `d/canyon/npc/obj/cola.c` requires argument cola, sets water to
capacity and destroys itself, no F_LIQUID/refill. Melon uses Eat, not Drink. NPC drunk's do_drink
is a chat helper, not environmental Player drinking. **A container is mandatory for generic
Old Pine refill/drink, not for every water gain throughout ES2.**

## F_LIQUID CONTRACT

ITEM supplies identity/move/dbase; F_LIQUID supplies actions, not a second container inventory.
The liquid mapping is per clone; prototype common facts use default-object fallback. `dbase::query`
calls `evaluate(data, this_object())`: a stored drink_func function IS evaluated during query.
Its truthy result short-circuits the subsequent alcohol switch; a false result does not. It is
incorrect to infer that drink_func never executes merely because liquid.c has no explicit call_other.
`std/medicine/powder.c` and `obj/toy/poison_dust.c` install such bound functions; powder/poison are deferred.

`init` exposes drink/fill for a reachable item; name::id includes visibility and alias checks.
The bundled add_action/init contract admits directly held and same-room ground items; liquid.c
does not itself demand direct ownership. It provides no recursive search into bags or another
character's inventory. Future direct-held-only use is an explicit staged Type B restriction, not
source parity or automatic inheritance of S4B Food G.

All active F_LIQUID definitions are ITEM, not COMBINED_ITEM. All support generic reusable filling
when reachable at a water room. None is currently a Native liquid item. Values below are source
facts; remote acquisition hits do not authorize bringing them to Snow.

| Source item | Weight / value / capacity | Initial contents / amount | Acquisition evidence and current suitability |
| --- | --- | --- | --- |
| `obj/example/wineskin.c` | 700 / 20 / 15 | 红酒 alcohol15, drunk_apply6 | Snow waiter offer; Snow drunk loadout. Only immediate existing-contact candidate, offer still deferred. |
| `d/canyon/npc/obj/wineskin.c` | 700 / 20 / 15 | Same red wine15 /6 | Separate file; no current acquisition, not a reason to duplicate the canonical item. |
| `obj/toy/calabash.c` | 400 / 80 / 60 | 甘泉水 water60 | Global literal calabash search found no supplier beyond its definition; do not invent a Snow sale. |
| `d/green/npc/obj/ricewine.c` | 1000 / 0 / 10 | 米酒 alcohol7 /7 | Green woman1 carry_object reference; deferred NPC/route, no established gift. |
| `d/chuenyu/obj/qiwine.c` | 1000 / 50 / 20 | 竹叶青 alcohol20 /10 | Chuenyu kitchen objects3; remote content. |
| `d/chuenyu/npc/obj/qiwine.c` | 1000 / 50 / 20 | Same | Cook carry_object; remote NPC, no current grant. |
| `d/city/npc/obj/wine.c` | 20000 / 350 / 30 | 红酒 alcohol30; drunk_bonus7 | City waiter offer; bonus key is not drunk_apply. |
| `d/latemoon/obj/wine.c` | 20000 / 20 / 30 | 红酒 alcohol30; drunk_bonus5 | room/eat2 objects reference; remote. |
| `d/latemoon/npc/obj/wine.c` | 20000 / 20 / 30 | Same | Duplicate-path definition; no current supplier established. |
| `d/latemoon/obj/teacup.c` | 1000 / 20 / 5 | 金轩茶 water5 | yumay creation reference; latemoon3 conditionally destroys returned cup on leave. |
| `d/latemoon/npc/obj/teacup.c` | 1000 / 20 / 5 | Same | Duplicate-path definition; no current supplier established. |

Additional shape: `d/village/obj/melon.c` has max_liquid15/liquid water15 but F_LIQUID inheritance
is commented out. Active F_FOOD uses top-level drink_func1, eight portions, food+20/water+40, value60,
weight1200; final rind weight150 survives. Village meloner/melonfarm references are not current
Snow supply. It is not a refillable cup. Cola/custom stack wine above also are not F_LIQUID.

## WINESKIN CONTRACT

Canonical source `obj/example/wineskin.c`: 牛皮酒袋; aliases `wineskin`, `skin`; unit个; own weight700;
value20文; max_liquid15; fresh per-instance alcohol / 红酒 / remaining15 / drunk_apply6; absent
drink_func evaluates false. Header says waterskin.c but the actual stable source identity is wineskin.
Descriptions suggesting litres do not change the executable count15.

| Legacy field | Classification / proposed typed boundary (not implemented) |
| --- | --- |
| identity, aliases, name, unit, max_liquid15 | Authored definition/display facts; existing ItemDefinitionId plus content/liquid definition. |
| set_weight700 | Existing Inventory own-weight authority; no per-portion mass or automatic fill weight. |
| value20 | Constant for this canonical fill/drink path; neither action zeros it. Do not reuse FoodState.consume_portion. |
| liquid/remaining | Mutable integer portions, including persistent empty0. |
| liquid/type | Mutable typed WATER/ALCOHOL for this scope. |
| liquid/name | Mutable content identity (RED_WINE/CLEAR_WATER), display name derived; not a free-form callback bag. |
| liquid/drunk_apply | Fresh6 and retained6 after fill/empty; typed metadata/state or validated canonical constant, never silently reset. |
| liquid/drink_func | Canonical none, fill explicitly sets0. Unsupported bound effects must fail/defer, not serialize Callable. |

Other items have other roles/values; canonical constants are not a universal liquid law.
Buying allocates a new stable instance. Filling/drinking allocates none; emptying does not destruct,
change parent, weight, unit, item value or identity. No stack merge/split or liquid inventory children.

## DRINK ORDER

`feature/liquid.c::do_drink`: (1) id match; (2) reject ghost; (3) reject busy; (4) reject falsy
remaining; (5) reject Player water >= max_water_capacity; (6) remaining -=1; (7) message;
(8) water +=30; (9) if fighting start_busy2; (10) empty message if now0; (11) evaluate queried
drink_func and return if truthy; (12) alcohol adds drunk_apply to old drunk condition; return1.
No after-add cap, food change, healing, RNG or weight/value mutation. A late custom-effect error
would occur after resource mutations; a universal transactional rollback would not be source order.
Negative remaining is truthy and decreases further; do not describe the source as `remaining > 0`.
Canonical fresh/fill/drink only reaches0..15. Future malformed-save rejection is an explicit bounded
validator contract, not evidence that LPC clamps arbitrary negative data.

## FILL ORDER

id match → busy refusal → Player environment water flag refusal → if remaining truthy discard
message → fill message → if fighting start_busy2 → type=water → name=清水 → remaining=max_liquid
→ drink_func=0 → return1. No ghost check, empty-only check, cap/weight/capacity check, finite-water
consumption, money/Player-water mutation or container allocation. Full containers can be refilled.
World supplies current reachable source truthiness; Core must not inspect positions/room strings.

## FILL-OVER-WINE BEHAVIOR

Full or partial wine is discarded and the SAME object becomes water/清水/15/drink_func0. The old
drunk_apply6 survives because these are four nested field writes, not whole-mapping replacement.
Other unmentioned extension data can likewise remain. Water type never enters the alcohol case;
fill does not apply drunk, even when starting from wine. It also does not remove an existing drunk
condition. Unsupported powder effects are not part of this candidate. No dummy drink-to-empty step.

## RENEWABLE WATER LOOP

Source permits WINE_FULL15 → wine Drink → WINE_PARTIAL14..1 → WINE_EMPTY0. Fill from ANY of those
states → WATER_FULL15; water Drink → WATER_PARTIAL14..1 → WATER_EMPTY0; Fill → WATER_FULL15 again.
Fill on full/partial water also resets15. Generic Fill never makes wine. Every arrow keeps item ID,
weight700/value20 and drunk_apply6. Water source flag stays1; empty item survives. Thus supply is
renewable indefinitely subject to action eligibility, with no replacement purchase, cooldown, stock,
RNG or cleanup timer. Player must drink after fill: merely approaching/refilling adds zero water.

## WATER CAPACITY / OVERSHOOT

`feature/damage.c::max_water_capacity = query_weight()/200`; current Native uses independent
PlayerBodyFacts.body_weight, not strength recomputation. Fresh80000 gives400. Drink at400 refuses
before portion consumption;399→429;0→30. At429, 29 eligible heal_up calls bring water to400, still
not drinkable; the 30th brings399. From0, fourteen consecutive eligible drinks give420 and leave
one of15 portions; the next refuses until water drops below400. No implicit clamp to400 in Save/UI.
Negative Player water also passes source cap comparison; do not invent a new minimum clamp.

## WATER-ZERO RECOVERY DEPENDENCY

Current natural loop: Work costs → S5B recovery/metabolism → Bank → dumpling → food supply;
dumpling does not replenish water. heal_up decrements positive water AND food first, then returns
for Player water<1. Water1→0 therefore performs NO primary/internal recovery; water0 stays0 but
positive food still decreases. Work eligibility checks gin/sen, not water: remaining gin/sen may
still fund Work before regeneration stops replenishing them. At water0, Eat does not fix recovery.
Clear-water Drink0→30 permits the next eligible opportunity at29 to recover normally; Fill alone
does not. Food<1 later stops only internal recovery, after primary recovery. These closed rules stay.

S5B uses approved Native2-second pulses and reset5..14 followed by6..15 eligible pulses per
opportunity:12..30 seconds, uniform expected21. Fresh400→0 needs400 calls:80..200 minutes, expected
140, of uninterrupted eligible non-busy time (not proven ES2 wall time). Busy consumes pulse time
without advancing count; pauses/combat/conditions/life/staging freeze full phase, extending elapsed
real time. Continue draws a new unsaved phase, never refills Player water. These are arithmetic/source
checks, not a newly timed live starvation experiment.

## CURRENT S5B CONDITION CONFLICT

Session `player_recovery_time_allowed()` rejects any nonempty condition collection. ConditionSystem
registers only snake_poison and bandaged; unknown/unimplemented handlers are skipped, not expired.
Save validator accepts drunk duration shape and saves/restores it. A hypothetical wine drink adding
drunk now would leave a persistent condition with no running remover and indefinitely freeze S5B
recovery until separately removed. Pause/Continue/fill do not cure it. Even a zero-valued stored
condition is nonempty. This is a concrete integration blocker, not the source's CND_NO_HEAL_UP rule.

## DRUNK DEPENDENCY

Source limit=`(con + max_force/50)*2`; fresh con30/max_force0 gives60. While living, duration>60
calls unconcious and returns0; otherwise nonliving only emits text. Living duration>30 damages
current sen10; else duration>15 damages current sen3 then calls missing receive_healing(gin10,kee15).
The available damage API is receive_heal, not receive_healing; global search found only these two
calls. Do not silently rename them. If execution reaches the tail, replace duration with old-1;
return0 for old0, else1 (CONTINUE), never CND_NO_HEAL_UP. Old1 writes0 and continues; old0 writes-1
then is removed by feature/condition; negatives continue decreasing unless another branch intervenes.
On the missing-method error path, later decrement/return is not guaranteed. No condition runtime,
unconscious/revive completion or historical driver error recovery is authorized here.

## ALCOHOL-BYPASS ANALYSIS

**Yes, by source Fill before any wine Drink.** Purchase retains truthful alcohol state; at an
accessible source discard/refill then only water Drink. This avoids drunk handler/cadence, missing
receive_healing and alcohol-triggered unconscious/revive dependencies. It does NOT solve existing
conditions or the fresh-player Vine barrier. Temporarily making alcohol Drink unavailable would be
Type B staged omission requiring explicit owner approval, not a claim that ES2 forbids wine.

## CURRENT NATIVE LIQUID GAP

Existing FoodDefinition/FoodState/FoodCollection are typed and Session-owned; Inventory remains
identity/parent/weight authority. Food consumption sets value0 and eventually removes an exhausted
dumpling; liquid must not borrow those mutations. Prefer a parallel narrow LiquidDefinition,
LiquidState and LiquidCollection keyed by existing ItemInstanceId; no universal consumable refactor,
dbase/query/set API or dictionary-of-effects. Current NativeItemDefinitionProjections excludes food
from stack/weapon/armor projections. Do not copy that staged restriction into a universal liquid-role
exclusivity law; the canonical wineskin being ITEM+F_LIQUID proves only its own composition.
UI can derive fullness text from typed content/portions without preserving arbitrary strings.

## PERSISTENCE REQUIREMENTS

Inspected `game/core/persistence/native_item_state_snapshot.gd`, `native_item_state_capture.gd`,
`native_item_state_validator.gd`, `native_item_state_restorer.gd`, `native_item_definition_projections.gd`,
`game_save_json_codec.gd`, `game_save_snapshot_validator.gd`, plus current production projections.
Item snapshot2 has records/stacks/equipment/armor/**food_consumables**, no liquid record. Ordinary
item records contain ID/definition/weight/parent, insufficient for remaining/type/content. Current
known SOURCE_ENTRY_V1 content has no authorized wineskin; merely adding an item definition would
lose state or reconstruct fresh wine incorrectly.

Future acceptance: same semantic ID/new runtime objects after cold Continue for all six states;
fresh alcohol15, partial alcoholN, empty alcohol0, full water15, partial waterN, empty water0.
If alcohol actions are deferred, partial/empty wine are explicitly source-derived test fixtures,
NOT player-reachable S6B evidence. Validate unique/existing IDs, definition-role match, exact count
bounds/canonical content combinations, zero survival, retained metadata, fixed weight, missing/orphan
records, allocator continuation and destruction-side collection cleanup. No refill on restore,
second Inventory, constructor-fresh liquid over restored data, new saved RNG or content-ID swap.

## ITEM SCHEMA IMPLICATION

Recommendation only: embedded item2→3 with typed liquid records. Strict codec rejects extra/missing
keys; hiding state in food, root extras or a dictionary is not compatible. Splitting WineWineskin
and WaterWineskin definitions and destroy/recreate on fill loses source identity. A new typed content
variant on the same instance solves it without changing the definition ID.

Root schema2/SOURCE_ENTRY_V1 can plausibly remain: nested item decoding has its own schema dispatch;
no new root/player/map fact is needed for liquid alone. Must explicitly extend decoder/writer,
capture/restore/validation/projections and candidate assembly, not just bump the constant. Existing
embedded1→2 decode is supported today and must be considered in any approved migration. Old legal
item2 (and supported item1) snapshots can supply empty liquid arrays because authorized wineskins
did not exist; never synthesize fresh contents for a claimed liquid item missing its record. Root
pre-cutover unsupported-save policy stays; no automatic SOURCE_ENTRY_V2 or root3. No schema changed
or approved in S6A; any added Green topology also needs its own world validation review.

## PHYSICAL WORLD OPTIONS

1. **Existing Waterfall + one nearby fill marker:** smallest geometry; Core receives a narrow current
   water-capability fact, World checks proximity/current map and selected held ID. Existing zones
   remain, no whole-map water truthiness. Fresh dodge0 admission needs separate owner resolution;
   no implicit reverse Cliffside edge, starter skill, QA teleport or engine random assumption.
2. **Riverbank2/1 marker:** also existing geometry but strictly farther after the same entrance;
   same blocker. No need to make collidable river water walkable to use a bank-side marker.
3. **Green station0 bounded route:** six deferred identities from mstreet2, source well exists,
   no Vine dependency; larger approved Snow/Green topology/region work, no full population required
   as a staged Type B embodiment. Generic Fill, not the custom fillwater runtime quirk.
4. **Lake / distant wells / tea:** unnecessary content/hazard/region dependencies. No arbitrary
   graphic direct Drink, passive refill, free Inn/Bank/Workplace water or initial container (Type C).

## VENDOR POLICY QUESTION

Source buy: quote → can_afford;0/2 refuse;1 pay → complete_trade new → move ignored → success text.
Vendor stock is unlimited new clones. Move validates weight/capacity; fill/drink later never call
move or alter weight. Existing ordered payment/lifecycle authority should be composed, not replaced.
S4B A–D cleanup/failure substitutions are specifically waiter/dumpling: owner must explicitly extend
them to wineskin. S2 failed reward disposal does not grant that authority. No refund/drop/cleanup
policy is silently generalized, and a rejected paid delivery must not be displayed as purchase success.

Source denomination proof: silver1+coin85 buys20 (`can_afford=1`), leaves silver1+coin65; from
silver1+coin100 buy wine first→silver1+coin80, then dumpling15→silver1+coin65. Money is not the blocker
at those states. All-coin85 with no silver still returns2 under the locked source presence rule;
do not replace this with a total-balance test. Two successful Works and existing Bank can establish
the required mixed denominations without new money authority. No liquid purchase is implemented yet.

## OWNER DECISIONS REQUIRED

All rows are proposals, NOT locked decisions. DECISIONS remains unchanged.

| Decision | Source / architecture classification | Recommendation and alternative requiring review |
| --- | --- | --- |
| A — source | Authored flag/refill Type A; placing interaction Type B; inventing Snow well Type C | Prefer Waterfall conditionally; Green station0 if fresh entrance cannot be resolved narrowly. |
| B — route | Existing typed traversal Type B; overriding zero-bound/adding reverse edge observable Type B or redesigned Type C | Explicitly decide fresh access BEFORE approving a complete loop. Alternative six-room Green chain; no Lake. |
| C — container | Source waiter wineskin Type A; staged offer Type B; free starter replacement Type C | Buy canonical20文 wineskin; distant cups/calabash are not currently accessible substitutes. |
| D — fresh wine | alcohol/红酒15 and retained metadata Type A | Keep exact fresh wine; selling prefilled clear water instead changes authored result (Type C). |
| E — alcohol action | Full source drink+drunk Type A needing unresolved runtime; staged omission Type B | Explicitly defer wine Drink, show unavailable reason; do not add drunk payload without updater. |
| F — fill wine | Discard+same-ID clear water15 Type A | Allow before alcohol support; no empty-first requirement or poured wine item. |
| G — reachability | Broader source action reach Type A translated to proximity Type B; direct-held staging Type B | Explicit direct-held-only first; not automatic Food G inheritance. |
| H — combat | Already-busy rejection and fighting-success busy2 Type A; noncombat staging Type B | Defer combat use explicitly; don't add busy2 outside combat or label restriction source parity. |
| I — persistence | Same instance mutable facts Type A, typed collection/DTO Type B | Mirror narrow food composition, not food consumption, generic effect maps or global role exclusivity. |
| J — schema | Versioning/migration Type B | Review embedded3 plus empty-array upgrade; root2/revision unchanged if validation proves it. No schema authorization yet. |
| K — vendor | Shared source order Type A; native delivery cleanup Type B | Explicitly extend S4B Vendor A–D to this offer; no automatic S2/Bank generalization. |
| L — UI | Native semantic interaction Type B | Truthful 红酒15/15 and staged wine warning; nearby “倒掉并装满清水”, held 清水N/15 + 喝. No parser/inventory overhaul. |

## RECOMMENDED S6B BOUNDARY

**Conditional water-only wineskin supply loop**, once A/B are resolved: unchanged Work/Bank →
explicitly extended waiter offer → physical approved water access → same-ID fill → clear-water
drink → exact typed liquid Save/cold Continue → repeat. Scope includes canonical content/typed
rules/ordered results, scoped lifecycle/vendor integration, a minimal environmental interaction
and held-use display, approved schema extension and acceptance tests. No full condition system.

**Do not authorize it as implementation-ready from location metadata alone.** A fresh-player path
must either resolve the pre-existing nonpositive Vine boundary with explicit owner review, use an
approved source-valid progression prerequisite (separate training scope), or approve the bounded
Green route. Analysis does not itself change DECISIONS or authorize any of those alternatives.

Future tests (NOT run/implemented here): canonical15/700/20/alcohol6; distinct vendor clones and
denomination order; paid capacity failure; water flag missing/false; wrong item/ghost/busy/zero and
negative legacy truthiness boundaries; full/partial/empty wine fill preserving ID/stale6; repeated
water fill/drink, no RNG/conditions;400 refusal/399→429/0→30; value/weight unchanged; empty survives;
no accidental combat busy; all six cold states, strict invalid/missing/orphan/duplicate liquid DTOs,
legal old snapshots empty upgrade, and allocator no extra IDs on fill. Distinct self-audit and real
unmodified fresh-player route/purchase/fill/drink/Pause Save/fresh-process Continue are required,
with return path and existing recovery/Bank/dumpling/Save regressions. QA state can prove a boundary,
but cannot satisfy fresh-player reachability. Do not use a technical dodge10 player for that claim.

## ALTERNATIVES

If Waterfall fresh access remains blocked, Green route is source-first but larger; approve it as a
bounded route slice rather than smuggling it into a marker edit. Purchasing more wine plus complete
drunk runtime is neither simpler nor condition-safe now. Remote tea/calabash/cola/melon require new
acquisition/content; cola and melon are not an empty-container refill loop. Copying the Choyin well
to Snow or granting hydration at Save is Type C and explicitly not recommended.

Relevant legacy quirks/defects: missing receive_healing; drunk_bonus instead of drunk_apply in
three wine definitions (no alias exists in F_LIQUID; zero apply can still store a condition);
stale drunk_apply after fill; negative truthy remaining; extra_long at max15/remaining1..3 returns
an unassigned string (presentation gap). Green station0 defines custom fillwater but calls
replace_program(ROOM): bundled runtime documentation says replacement drops its own program after
execution while retaining variables. Do not promise that custom verb remains callable. Its body,
if invoked before replacement, replaces the whole liquid mapping with water15/drunk6, unlike
generic max-based Fill. The water flag itself survives. Bathroom referenced NPC/exit files exist;
its separate take bath poison/heal action is NOT a water-quality modifier to generic Fill.
No room-specific generic fill quality override was found: even lake prose uses generic 清水.
No missing nearest-route file was found; Native deferred exits and ambiguous Vine0 are not
“missing LPC water”. Historical driver deployment behavior remains unexecuted.

## OUT OF SCOPE

No S6B, wine offer, liquid/condition code, cadence changes, schema changes, UI/scene/route edits,
new Snow/Green/Lake content, NPC population, training, school, weapons, medicine, intoxication,
revive, water convenience design, final PR, merge or tooling cleanup. Do not alter pre-cutover
save promises, PlayerBodyFacts independence, source New Game birth or closed S5B decisions.

## VERIFICATION

S6A evidence is exact-baseline inspection, exhaustive structural searches and distinct source/Native
dependency re-review. Docs-only checks PASS: repository/static check, 83 local Markdown targets,
four-document trailing whitespace, `git diff --check`, and exact four-document allowlist versus
starting HEAD. Production/test/scene/reference/DECISIONS/Save/build/CI delta is zero. Final commit/
remote status is recorded in the owner report.
No gameplay/headless/live run was needed or claimed. S5B's19,018 assertions remain historical S5B
evidence, NOT S6A evidence. No new GitHub CI or PR evidence is implied by a phase-branch push.

## STOP STATE

S5B OWNER APPROVED / CLOSED. S6A ANALYSIS COMPLETE — AWAIT OWNER REVIEW.
S6B NOT AUTHORIZED. Snow final PR NOT AUTHORIZED / NONE; milestone remains UNMERGED.
All A–L proposals await owner decision; stop after same-branch documentation commit/push.
