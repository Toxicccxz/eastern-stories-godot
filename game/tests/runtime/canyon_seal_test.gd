extends RefCounted

## 天驼关 B (d/canyon): the 印鉴 chain. 赫造基 tells one who gives him eight taels the secret of
## the smooth wall (set_temp 军营/swear); the oath there (owner, canyon plan Q3: a button, only
## for one who was told) takes them into the 兵器库 and spends the secret; the 后备兵 trades a
## fake 印鉴 for exactly three gold, once (Get_seal); 严廷殷 throws out whoever offers it (camp2,
## 将军/kick, the fake stays with them); the 后备兵 then swaps it for the real one, once (his own
## check, saved); 严廷殷 gives the 古剑 for that, which teaches sword to 50 from 2500 exp.
## Walks use the move actions (MapPlaces). TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const ADVISER: StringName = &"canyon.npc.adviser"
const GENERAL: StringName = &"canyon.npc.general"
const SELLER: StringName = &"canyon.npc.seller"
const FAKE_SEAL: StringName = &"es2:d/canyon/npc/obj/fake_seal"
const SEAL: StringName = &"es2:d/canyon/npc/obj/seal"
const OLD_SWORD: StringName = &"es2:d/canyon/npc/obj/old_sword"
const SWEAR: StringName = &"canyon.canyon4.swear"
const SECRET: Array[String] = [
	"赫造基说道：好极了，我就告诉你一项秘密吧。",
	"赫造基说道：在那片光滑的山壁前发誓 我爱.....。",
	"赫造基说道：或许你可以发现奇特的事喔。",
]
## canyon4.c do_swear(): message_vision() as the one swearing reads it.
const STRUCK: Array[String] = [
	"突然间一阵强光将你给罩住了",
	"轰隆～～～～～～～～～～～～～～～～～～",
	"～～～～～轰隆～～～～～轰隆～～～～～～",
	"～～～～～～～轰隆～～～～～～～～轰隆～",
	"你惨叫了一声:哇，好痛啊～～～～～～",
	"～～～～～～～～～～～～～～～～～～～～",
	"～～～～～～～～～～～～～～～～～～～～",
	"～～～～～～～～～～～～～～～～～～～～",
	"～～～～～～～～～～～～～～～～～～～～",
	"～～～～～～～～～～～～～～～～～～～～",
]
const KICKED: Array[String] = [
	"严廷殷说道：你拿给我的是什么东西啊!",
	"严廷殷说道：别想拿这种东西来骗我",
	"严廷殷说道：给我滚出去",
	"严廷殷没有收下。",
]
## Deviation (天驼关 B, owner to decide): once he gave the real one, money is kept as he says.
const DONE_WITH: Array[String] = [
	"后备兵说道：如果是钱的话，我先没收了。",
	"后备兵说道：其他的东西我都不要，别再来烦我了。",
]
const CAMP: Array[StringName] = [&"canyon.camp1", &"canyon.camp2", &"canyon.camp7", &"canyon.camp8"]
const BACK: Array[StringName] = [&"canyon.camp7", &"canyon.camp2", &"canyon.camp1", &"canyon.canyon4"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_rules()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_no_secret(tree, session)
	await _test_secret(tree, session)
	await _test_swear(tree, session)
	await _test_fake_seal(tree, session)
	await _test_thrown_out(tree, session)
	await _test_real_seal(tree, session)
	await _test_old_sword(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var fake: ItemContentDefinition = catalog.item(FAKE_SEAL)
	var real: ItemContentDefinition = catalog.item(SEAL)
	_check(fake.display_name == "印鉴" and fake.value == 3000 and fake.description == "上面刻著镇国大将军。\n", "fake_seal.c: 印鉴, worth 3000")
	_check(real.display_name == "印鉴" and real.value == 0 and real.description == "泛著黄光，上面刻著镇国大将军。\n", "seal.c: 印鉴 (HIY), 泛著黄光, worth nothing")
	var sword: ItemContentDefinition = catalog.item(OLD_SWORD)
	_check(sword.display_name == "古 剑" and sword.weapon_skill_type == &"" and sword.study != null and sword.study.skill_id == &"sword" and sword.study.exp_required == 2500 and sword.study.max_skill == 50, "old_sword.c: sword to 50 from 2500 exp, no weapon")
	var swear: ServiceDefinition = catalog.service(SWEAR)
	_check(swear.kind == &"act" and swear.zone_id == &"canyon.canyon4" and swear.act.verb == "发誓：我爱东方故事II" and swear.act.acts.size() == 1 and swear.act.acts[0].temp == "军营/swear", "光滑的山壁 · 发誓：我爱东方故事II, only with 军营/swear (owner, Q3)")
	_check(catalog.npc(ADVISER).dealings().object_rules.size() == 4 and catalog.npc(GENERAL).dealings().object_rules.size() == 4 and catalog.npc(SELLER).dealings().object_rules.size() == 7, "adviser.c, general.c, seller.c accept_object()")


## seller.c's value()==30000 is exact; general.c tells the two 印鉴 apart by their names, which
## differ only by colour: the rules name the items.
func _test_rules() -> void:
	var rules: Array[NpcObjectRule] = GameContent.catalog().npc(SELLER).dealings().object_rules
	for value: int in [29999, 30001, 20000]:
		var offer := NpcObjectRule.Offer.new(value)
		var rule: NpcObjectRule = NpcObjectRule.decide(rules, offer)
		_check(rule != null and not rule.accept and rule.gives.is_empty(), "%d is not three gold: refused" % value)
	var exact := NpcObjectRule.Offer.new(30000)
	_check(NpcObjectRule.decide(rules, exact).gives == FAKE_SEAL, "30000 exactly: the fake 印鉴")
	var general: Array[NpcObjectRule] = GameContent.catalog().npc(GENERAL).dealings().object_rules
	var real := NpcObjectRule.Offer.new(0)
	real.item_name = "印鉴"
	real.item_id = SEAL
	var fake := NpcObjectRule.Offer.new(0)
	fake.item_name = "印鉴"
	fake.item_id = FAKE_SEAL
	_check(NpcObjectRule.decide(general, real).gives == OLD_SWORD, "the real 印鉴: the 古剑")
	var thrown: NpcObjectRule = NpcObjectRule.decide(general, fake)
	_check(not thrown.accept and thrown.set_temps == ["将军/kick"] and thrown.move_zone_id == &"canyon.camp2", "the fake: 将军/kick, out to camp2, refused")


## Without the secret the smooth wall is a wall: no button there (canyon4.c's add_action()
## returns 0, ES2's 什么?).
func _test_no_secret(tree: SceneTree, session: WorldSessionController) -> void:
	_check(session.handoff_to(&"canyon.pass", &"canyon.canyon4", &"canyon.canyon4", &"canyon.canyon4.armory_return").succeeded(), "TEST-ONLY: on 隘口中道")
	await tree.physics_frame
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var wall: ActService = gorge.service(SWEAR) as ActService
	_check(await MapPlaces.drive(tree, gorge, MapPlaces.service_spot(gorge, SWEAR)) and wall.in_reach(), "at the smooth wall")
	_check(wall.context_title() == "" and gorge.interaction_title() == "", "no oath to swear: %s" % gorge.interaction_title())
	_check(wall.point.get_node_or_null("Visual") == null, "no diamond gives the secret away")


## adviser.c accept_object(): worth nothing → Thank You; under 800 → 钱太少了吧！没收。 (kept);
## 800 or more → the secret (军营/swear); told already → 勉强收起来 (kept).
func _test_secret(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.marks["军营"] = 1 # TEST-ONLY: listed by the 大队长 (天驼关 A)
	_check(await MapPlaces.drive_through(tree, gorge, CAMP), "into the 将军营帐")
	gorge.npc_life._advance_ambience(0.0)
	var context: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(context, CurrencyDenomination.Value.SILVER, 40, &"test.silver") # TEST-ONLY
	_check(gorge.select_npc(_npc(gorge, ADVISER).character_id), "赫造基")
	var blade: ItemHandlingResult = gorge.give_to_selected(_new_item(session, &"es2:d/canyon/npc/obj/blade"))
	_check(blade.done() and blade.lines[0] == "赫造基说道：ㄟ....Ｔhank Ｙou!!!", "a blade: Thank You, kept: %s" % [blade.lines])
	var little: ItemHandlingResult = gorge.give_to_selected(&"test.silver", 7)
	_check(little.done() and little.lines[0] == "赫造基说道：钱太少了吧！没收。" and _amount(session, &"test.silver") == 33 and not player.temp_marks.has("军营/swear"), "seven taels: 钱太少了吧！没收。, kept, no secret: %s" % [little.lines])
	var enough: ItemHandlingResult = gorge.give_to_selected(&"test.silver", 8)
	_check(enough.done() and enough.lines.slice(0, 3) == SECRET and player.temp_marks.get("军营/swear", 0) == 1, "eight taels: the secret: %s" % [enough.lines])
	var more: ItemHandlingResult = gorge.give_to_selected(&"test.silver", 1)
	_check(more.done() and more.lines[0] == "赫造基说道：即然你那么有心，那我就勉强收起来了。" and _amount(session, &"test.silver") == 24, "told already: 勉强收起来, kept")
	# The secret survives Save and Continue (set_temp() flags are saved, owner).
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null and GameSaveJsonCodec.encode(snapshot).text.contains("军营/swear"), "the save holds the secret")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "天驼关 B told the secret")
	_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))


## canyon4.c do_swear(): the lightning, the secret spent, and the 兵器库.
func _test_swear(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, gorge, BACK), "back out to 隘口中道")
	var wall: ActService = gorge.service(SWEAR) as ActService
	_check(await MapPlaces.drive(tree, gorge, MapPlaces.service_spot(gorge, SWEAR)) and wall.in_reach(), "at the smooth wall")
	_check(gorge.interaction_title() == "光滑的山壁 · 发誓：我爱东方故事II", "光滑的山壁 · 发誓：我爱东方故事II: %s" % gorge.interaction_title())
	gorge.interact()
	await tree.physics_frame
	await tree.physics_frame
	var location: WorldLocationState = player.world_location()
	_check(session.active_map_id() == &"canyon.armory" and location.zone_id == &"canyon.blackmarket", "in the 兵器库: %s" % location.zone_id)
	var seen: Array[String] = hud.log_lines()
	var at: int = seen.rfind(STRUCK[0])
	_check(at >= 0 and seen.slice(at, at + STRUCK.size()) == STRUCK, "struck by lightning: %s" % [seen.slice(-12)])
	_check(not player.temp_marks.has("军营/swear"), "the secret is spent")


## seller.c accept_object(): exactly 30000 → the fake 印鉴, once while the player still has it
## (Get_seal is saved: one who lost it buys again, 默认); anything else, or the fake before 严廷殷
## threw the player out, is refused.
func _test_fake_seal(tree: SceneTree, session: WorldSessionController) -> void:
	var armory: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var context: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(context, CurrencyDenomination.Value.GOLD, 11, &"test.gold") # TEST-ONLY
	armory.npc_life._advance_ambience(0.0)
	_check(armory.select_npc(_npc(armory, SELLER).character_id), "the 后备兵")
	var two: ItemHandlingResult = armory.give_to_selected(&"test.gold", 2)
	_check(not two.done() and two.lines == ["后备兵说道：你给我这个做什么？我不要，你拿回去吧。", "后备兵没有收下。"] and _amount(session, &"test.gold") == 11, "two gold: refused: %s" % [two.lines])
	var three: ItemHandlingResult = armory.give_to_selected(&"test.gold", 3)
	_check(three.done() and three.lines.slice(0, 2) == ["后备兵说道：不亏是武林中人，一眼就看出端倪了", "后备兵说道：这个印鉴就看在钱的份上和你交换了"] and _amount(session, &"test.gold") == 8, "three gold: %s" % [three.lines])
	_check(_carried(session, FAKE_SEAL) != &"" and player.temp_marks.get("Get_seal", 0) == 1, "the fake 印鉴, and Get_seal")
	var again: ItemHandlingResult = armory.give_to_selected(&"test.gold", 3)
	_check(again.done() and again.lines.slice(0, 2) == ["后备兵说道：我已经给你了啊。", "后备兵说道：那么多钱，那我就没收了:P"] and _amount(session, &"test.gold") == 5 and _all_carried(session, FAKE_SEAL).size() == 1, "three gold again: kept, no second seal")
	var early: ItemHandlingResult = armory.give_to_selected(_carried(session, FAKE_SEAL))
	_check(not early.done() and early.lines[0] == "后备兵说道：你给我这个做什么？我不要，你拿回去吧。" and _carried(session, FAKE_SEAL) != &"", "the fake back before 严廷殷 saw it: refused")
	# Lost (dropped here), the fake is bought again: Get_seal is saved for good (默认).
	_check(armory.drop_item(_carried(session, FAKE_SEAL)).done() and _carried(session, FAKE_SEAL) == &"", "the fake dropped")
	var lost: ItemHandlingResult = armory.give_to_selected(&"test.gold", 3)
	_check(lost.done() and lost.lines[1] == "后备兵说道：这个印鉴就看在钱的份上和你交换了" and _all_carried(session, FAKE_SEAL).size() == 1 and _amount(session, &"test.gold") == 2, "the fake lost: three gold buy another: %s" % [lost.lines])
	_check(await MapPlaces.take_passage(tree, armory, &"canyon.blackmarket.east"), "out east onto 隘口中道")
	# Back beside the smooth wall, the secret spent: no oath.
	var gorge: WorldMapController = session.active_map() as WorldMapController
	_check((gorge.service(SWEAR) as ActService).in_reach() and gorge.interaction_title() == "", "out of the 兵器库 by the wall, the secret spent: no oath (%s)" % gorge.interaction_title())


## general.c accept_object(): the fake 印鉴 gets the player thrown out to the camp fire with
## 将军/kick, and they keep it (return 0).
func _test_thrown_out(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, gorge, CAMP), "into the 将军营帐 again")
	gorge.npc_life._advance_ambience(0.0)
	_check(gorge.select_npc(_npc(gorge, GENERAL).character_id), "严廷殷")
	var thing: ItemHandlingResult = gorge.give_to_selected(_new_item(session, &"es2:d/canyon/npc/obj/blade"))
	_check(thing.done() and thing.lines[0] == "严廷殷说道：ㄟ....Ｔhank Ｙou!!!", "a blade: Thank You, kept: %s" % [thing.lines])
	var tael: ItemHandlingResult = gorge.give_to_selected(&"test.silver", 1)
	_check(tael.done() and tael.lines[0] == "严廷殷说道：啊，真是谢谢你了。", "a tael: 啊，真是谢谢你了。: %s" % [tael.lines])
	var fake: StringName = _carried(session, FAKE_SEAL)
	var offered: ItemHandlingResult = gorge.give_to_selected(fake)
	await tree.physics_frame
	_check(not offered.done() and offered.lines == KICKED, "你拿给我的是什么东西啊!: %s" % [offered.lines])
	_check(player.world_location().zone_id == &"canyon.camp2" and player.temp_marks.get("将军/kick", 0) == 1 and _carried(session, FAKE_SEAL) == fake, "out at the camp fire, 将军/kick, the fake still theirs")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "天驼关 B thrown out")
	_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))


## Eight taels more for the secret, the oath again; seller.c swaps the fake for the real one,
## once (his check, saved); then money is kept as he says (deviation) and the rest refused.
func _test_real_seal(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(await MapPlaces.drive_through(tree, gorge, [&"canyon.camp7", &"canyon.camp8"]), "back to the 军师")
	gorge.npc_life._advance_ambience(0.0)
	_check(gorge.select_npc(_npc(gorge, ADVISER).character_id) and gorge.give_to_selected(&"test.silver", 8).lines.slice(0, 3) == SECRET, "eight taels: the secret again")
	_check(await MapPlaces.drive_through(tree, gorge, BACK), "out to 隘口中道")
	_check(await MapPlaces.drive(tree, gorge, MapPlaces.service_spot(gorge, SWEAR)), "at the smooth wall")
	gorge.interact()
	await tree.physics_frame
	await tree.physics_frame
	var armory: WorldMapController = session.active_map() as WorldMapController
	_check(armory.map_id() == &"canyon.armory", "the oath again: the 兵器库")
	armory.npc_life._advance_ambience(0.0)
	var seller: NpcRuntimeState = _npc(armory, SELLER)
	_check(armory.select_npc(seller.character_id), "the 后备兵 again")
	var swapped: ItemHandlingResult = armory.give_to_selected(_carried(session, FAKE_SEAL))
	_check(swapped.done() and swapped.lines.slice(0, 2) == ["后备兵说道：好吧！即然被你发现了，只好认栽了。", "后备兵说道：这个真的你就拿去吧"], "the fake for the real one: %s" % [swapped.lines])
	_check(_carried(session, SEAL) != &"" and _carried(session, FAKE_SEAL) == &"" and not player.temp_marks.has("将军/kick") and seller.has_flag(&"check"), "the real 印鉴; 将军/kick deleted; his check set")
	Finance.add_money(Finance.session_context(session), CurrencyDenomination.Value.GOLD, 3, &"test.gold2") # TEST-ONLY
	var done: ItemHandlingResult = armory.give_to_selected(&"test.gold2")
	_check(done.done() and done.lines.slice(0, 2) == ["后备兵说道：我已经给你了啊。", "后备兵说道：那么多钱，那我就没收了:P"] and _carried(session, FAKE_SEAL) == &"", "swapped, three gold: kept, no fake: %s" % [done.lines])
	var back: ItemHandlingResult = armory.give_to_selected(_carried(session, SEAL))
	_check(not back.done() and back.lines == DONE_WITH + ["后备兵没有收下。"] and _carried(session, SEAL) != &"", "the real one offered him: refused: %s" % [back.lines])
	var silver: ItemHandlingResult = armory.give_to_selected(&"test.silver", 1)
	_check(silver.done() and silver.lines.slice(0, 2) == DONE_WITH and _amount(session, &"test.silver") == 14, "a tael: kept, as he says (deviation): %s" % [silver.lines])
	# His check survives Save and Continue (the NPC's memory, owner 乔阴 B).
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(encoded.text).snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "Continue in the 兵器库")
	if restored.succeeded():
		var again: NpcRuntimeState = _npc(restored.candidate.active_map() as WorldMapController, SELLER)
		_check(again != null and again.has_flag(&"check"), "after Continue, the 后备兵 remembers he gave it")
		restored.candidate.free()
		await tree.process_frame
	_check(await MapPlaces.take_passage(tree, armory, &"canyon.blackmarket.east"), "out east")


## general.c accept_object(): the real 印鉴 for the 古剑; study.c reads sword from it.
func _test_old_sword(tree: SceneTree, session: WorldSessionController) -> void:
	var gorge: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	_check(await MapPlaces.drive_through(tree, gorge, CAMP), "to 严廷殷")
	gorge.npc_life._advance_ambience(0.0)
	var general: NpcRuntimeState = _npc(gorge, GENERAL)
	_check(gorge.select_npc(general.character_id), "严廷殷 again")
	var given: ItemHandlingResult = gorge.give_to_selected(_carried(session, SEAL))
	_check(given.done() and given.lines.slice(0, 2) == ["严廷殷说道：真是谢谢你了。", "严廷殷说道：为了答谢你，这把古剑送你，当做报酬吧。"], "the real 印鉴: %s" % [given.lines])
	var sword: StringName = _carried(session, OLD_SWORD)
	_check(sword != &"" and _carried(session, SEAL) == &"", "the 古剑 is the player's, the 印鉴 his")
	state.skills.set_raw_level(SkillIds.LITERATE, 10) # TEST-ONLY
	state.progression.combat_experience = 2499 # TEST-ONLY
	_check(session.martial_arts().study(sword).outcome == StudyResult.Outcome.COMBAT_EXPERIENCE_TOO_LOW, "below 2500 exp: too deep")
	state.progression.combat_experience = 2500 # TEST-ONLY
	var read: StudyResult = session.martial_arts().study(sword)
	_check(read.outcome == StudyResult.Outcome.STUDIED and hud.log_lines()[-1] == "你研读有关基本剑法的技巧，似乎有点心得。", "study: sword: %s" % hud.log_lines()[-1])
	_check(Work.capture(session) != null, "Save with the 古剑")


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			return npc
	return null


## How many the stack `id` still holds (0 once it is gone).
func _amount(session: WorldSessionController, id: StringName) -> int:
	var context: MoneyInventoryContext = Finance.session_context(session)
	return context.stacks.stack_state(id).amount if context.stacks.has_stack(id) else 0


## An item of `definition_id` the player carries (the first), or empty.
func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var found: Array[StringName] = _all_carried(session, definition_id)
	return &"" if found.is_empty() else found[0]


func _all_carried(session: WorldSessionController, definition_id: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for row: PlayerInventoryRowProjection in session.player_inventory_rows():
		if row.item_definition_id == definition_id:
			found.append(row.item_instance_id)
	return found


## TEST-ONLY: an item of `definition_id` in the player's pack.
func _new_item(session: WorldSessionController, definition_id: StringName) -> StringName:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var allocation: SessionItemIdAllocationResult = session.item_id_allocator().allocate(context.inventory)
	var item := ItemInstance.new(allocation.item_instance_id, definition_id)
	assert(context.inventory.register_item(item, content.own_weight))
	assert(context.index.register_snapshot(item))
	var destination := InventoryTransferDestination.new(context.endpoint(), true, true, 1000000)
	assert(InventoryTransferService.new().transfer(context.inventory, item.item_instance_id, destination).succeeded)
	return item.item_instance_id


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("canyon_seal: " + message)
