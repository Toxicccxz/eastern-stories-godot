extends RefCounted

## Snow 4E: give, drop, put and get from (cmds/std/give.c, drop.c, put.c, get.c)
## with the NPCs' accept_object() as data; the drunk's do_drink(); the shops and
## teachers bound to their NPCs' bodies (vendor, learn.c, apprentice.c) as data.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const Master := preload("res://tests/support/snow_master.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_object_rules()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	await _test_waiter(tree, session)
	await _to_square(tree, session)
	await _test_give(tree, session)
	await _test_drop_put(tree, session)
	await _test_drunk(tree, session)
	await _test_shops(tree, session)
	await _test_teachers(tree, session)
	await _test_save(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for id: StringName in [&"snow.npc.waiter", &"snow.npc.annihir", &"snow.npc.herbalist", &"snow.npc.smith", Master.MASTER_ID]:
		_check(catalog.npc(id) != null, "%s has a body" % id)
	_check(catalog.npc(&"snow.npc.waiter").dealings().vendor_id == &"snow.vendor.waiter" and catalog.npc(&"snow.npc.waiter").rank_respect == "小二哥", "店小二 sells from his body; rank_info/respect")
	_check(not catalog.npc(&"snow.npc.annihir").dealings().is_fight_deferred() and not Master.definition().dealings().is_fight_deferred(), "安惜迩 and 柳淳风 can be fought (their skills are ported)")
	var kinds: Array[StringName] = []
	for map_id: StringName in [&"snow.outdoor", &"snow.inn"]:
		for service: ServiceDefinition in catalog.services_for_map(map_id):
			kinds.append(service.kind)
	_check(not kinds.has(&"vendor") and not kinds.has(&"teacher") and kinds.has(&"bank") and kinds.has(&"hockshop"), "only rooms' own commands are room services: " + str(kinds))
	var teaching: NpcTeaching = Master.definition().teaching()
	_check(teaching.family_id == &"family.fonxan" and teaching.family_generation == 13 and teaching.f_master and teaching.apprentice.requires == {&"cor": 20, &"cps": 20}, "the master's family, F_MASTER and attempt_apprentice()")
	_check(Master.definition().short_name() == "封山剑派第十三代掌门人「风雨双侠」柳淳风", "name.c short(): assign_apprentice()'s title and his nickname")
	_check(catalog.skill(&"literate").display_name == "读书识字" and catalog.skill(&"liuh-ken").can_enable_for(&"unarmed") and catalog.skill(&"fonxansword").valid_enabled_uses() == [&"sword", &"parry"], "skills.json")
	_check(NpcTeacher.teachable_skills(catalog.npc(&"snow.npc.fist_trainer"), catalog) == [&"unarmed", &"liuh-ken", &"dodge"], "李火狮 teaches what he has and the game defines")
	_check(NpcTeacher.teachable_skills(catalog.npc(&"snow.npc.teacher"), catalog) == [&"literate"], "魏无极 teaches literate")
	_check(NpcTeacher.teachable_skills(catalog.npc(&"snow.npc.trainee"), catalog).is_empty() and NpcTeacher.teachable_skills(catalog.npc(&"snow.npc.guard"), catalog).is_empty(), "nobody else admits a student")
	_check(catalog.item(&"es2:d/snow/obj/denotation").max_encumbrance == 10000, "the 功德箱 holds 10000")


func _test_object_rules() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var keeper: Array[NpcObjectRule] = catalog.npc(&"snow.npc.keeper").dealings().object_rules
	_check(not NpcObjectRule.decide(keeper, NpcObjectRule.Offer.new(0)).accept, "庙祝不收 an object worth nothing")
	var donation: NpcObjectRule = NpcObjectRule.decide(keeper, NpcObjectRule.Offer.new(10))
	_check(donation.accept and donation.effect == NpcObjectRule.EFFECT_TEMPLE_DONATION, "money is a donation")
	var drunk: Array[NpcObjectRule] = catalog.npc(&"snow.npc.drunk").dealings().object_rules
	var flags: Dictionary[StringName, bool] = {&"has_alcohol": true}
	_check(NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(20, &"alcohol", 0)).lines[0].text == "去去去去去.. 我又不是收破烂的...", "an empty one")
	_check(NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(20, &"alcohol", 5)).lines[0].text == "真没诚意, 剩么一点... ", "five sips or fewer")
	_check(not NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(20, &"alcohol", 6, flags)).accept, "多谢, 不过我还有酒: and returns 0")
	var taken: NpcObjectRule = NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(20, &"alcohol", 6))
	_check(taken.accept and taken.set_npc_flag == &"has_alcohol", "wine when he has none")
	_check(NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(20, &"water", 15)) == null, "water: accept_object() returns 0")
	var teacher: Array[NpcObjectRule] = catalog.npc(&"snow.npc.teacher").dealings().object_rules
	_check(not NpcObjectRule.decide(teacher, NpcObjectRule.Offer.new(499)).accept, "诚意不够 below five taels")
	_check(NpcObjectRule.decide(teacher, NpcObjectRule.Offer.new(500)).mark_giver == "魏无极", "500 marks the giver")
	_check(NpcObjectRule.decide(teacher, NpcObjectRule.Offer.new(1, &"", 0, {}, {"魏无极": 1})).accept, "a marked student's gift is kept")
	_check(catalog.npc(&"snow.npc.farmer").dealings().object_rules.is_empty(), "the farmer has no accept_object()")


## The waiter in the Inn: his body, his goods, his greeting and how one addresses him.
func _test_waiter(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var waiter: NpcRuntimeState = _npc(map, &"snow.inn.main_floor.inn.waiter.1")
	var shop: VendorService = map.service(&"snow.inn.waiter") as VendorService
	_check(waiter != null and shop != null and not shop.in_reach(), "the waiter stands in the Inn, his shop on him")
	_check(_beside(map, session.player_runtime(), &"snow.inn.main_floor", &"snow.inn.main_floor.inn.waiter.1"), "beside the waiter")
	map.advance_npc_heartbeat(1.1)
	var greetings: Array[String] = ["店小二笑咪咪地说道：这位小姑娘，进来喝杯茶，歇歇腿吧。", "店小二用脖子上的毛巾抹了抹手，说道：这位小姑娘，请进请进。", "店小二说道：这位小姑娘，进来喝几盅小店的红酒吧，这几天才从窖子里开封的哟。"]
	_check(greetings.has(hud.log_lines().back()), "waiter.c greeting(): one of three lines: " + hud.log_lines().back())
	_check(shop.in_reach() and map.interaction_title() == "店小二 · 购买", "购买 beside his body")
	_check(not shop.request_purchase("dumpling").delivered and shop.feedback.text == "你的钱不够。", "buy.c: no money")
	map.select_npc(waiter.character_id)
	map.spar_selected()
	_check(hud.log_lines().any(func(line: String) -> bool: return line.contains("领教小二哥的高招")), "rankd.c: rank_info/respect 小二哥")
	await tree.process_frame
	# Back to where the session's other suites start from.
	_check(map.relocate_player(&"snow.inn.main_floor", &"snow.inn.main_floor.player_birth"), "back to the Inn's middle")
	await tree.physics_frame


func _to_square(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	await MapPlaces.take_passage(tree, session.active_map() as WorldMapController, SnowWorldDefinitions.INN_EXIT_PORTAL_ID)
	var square: bool = await MapPlaces.drive_to_zone(tree, session.active_map() as WorldMapController, &"snow.square")
	_check(square and session.player_runtime().world_location().zone_id == &"snow.square", "out of the Inn")


func _test_give(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 300, &"test.coins")
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 12, &"test.silver")
	# The keeper takes money (keeper.c accept_object()); give.c destructs a gift with a value.
	_check(_beside(map, player, &"snow.temple", &"snow.temple.keeper.1"), "in the temple")
	var keeper: NpcRuntimeState = _npc(map, &"snow.temple.keeper.1")
	map.select_npc(keeper.character_id)
	var gift: ItemHandlingResult = map.give_to_selected(&"test.coins", 10)
	_check(gift.done() and gift.destroyed and gift.lines == ["庙祝说道：多谢这位小姑娘，神明一定会保佑你的。", "你拿出十文钱给庙祝。"], "give 10 coin to keeper: " + str(gift.lines))
	_check(Finance.amount(money, CurrencyDenomination.Value.COIN) == 290 and not session.inventory_state().is_registered(gift.item_id), "ten coins split off and gone")
	# keeper.c: over 100, a bellicose giver may be eased: random(val/10) > kar, then random(kar) + val/1000.
	player.state.attributes.bellicosity = 50
	player.state.attributes.karma = 20
	var draws := ScriptedWorldInteractionRandomSource.new([21, 3])
	var eased: ItemHandlingResult = ItemHandlingService.give(player, keeper, true, &"test.coins", 250, _authorities(session), draws)
	_check(eased.done() and draws.requested_bounds() == [25, 20] and player.state.attributes.bellicosity == 50 - 3, "keeper.c donation eases bellicosity: " + str(draws.requested_bounds()))
	# Only money has a value() (std/money.c): the keeper refuses anything else, and
	# give.c's notify_fail shows, as the NPC not taking it (modern fixes).
	_add_item(session, &"test.cloth", &"es2:obj/cloth")
	var refused: ItemHandlingResult = map.give_to_selected(&"test.cloth")
	_check(refused.outcome == ItemHandlingResult.Outcome.REFUSED and refused.lines == ["庙祝没有收下。"] and session.inventory_state().is_direct_child(&"test.cloth", money.endpoint()), "a worthless gift: nothing changes hands")
	_add_item(session, &"test.book", &"es2:obj/old_book")
	_check(map.give_to_selected(&"test.book").lines == ["庙祝没有收下。"], "an old book (value 70) is no money either")
	# An NPC without accept_object() takes nothing; one knocked out is not living().
	_check(_beside(map, player, &"snow.sroad2", &"snow.sroad2.farmer.1"), "beside the farmers")
	var farmer: NpcRuntimeState = _npc(map, &"snow.sroad2.farmer.1")
	map.select_npc(farmer.character_id)
	_check(map.give_to_selected(&"test.coins", 1).lines == ["农夫没有收下。"], "the farmer has no accept_object()")
	farmer.set_life_status(CharacterRuntimeLifeStatus.Value.UNCONSCIOUS)
	_check(not map.selected_npc_takes_gifts() and map.give_to_selected(&"test.coins", 1).lines == ["这里没有这个人。"], "give.c: living(who)")
	farmer.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	# The scavenger takes anything: worth something it is destructed, worth nothing he carries it.
	_check(_beside(map, player, &"snow.mstreet2", &"snow.mstreet2.scavenger.1"), "beside the scavenger")
	var scavenger: NpcRuntimeState = _npc(map, &"snow.mstreet2.scavenger.1")
	map.select_npc(scavenger.character_id)
	var cloth: ItemHandlingResult = map.give_to_selected(&"test.cloth")
	_check(cloth.done() and not cloth.destroyed and cloth.lines == ["收破烂的说道：多谢这位小姑娘！", "你给收破烂的一件布衣。"], "give cloth to scavenger: " + str(cloth.lines))
	_check(session.inventory_state().is_direct_child(&"test.cloth", ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, scavenger.character_id)), "he carries it now")
	# 魏无极's tuition: under five taels he refuses, and the part stays with the player (DECISIONS 4E).
	_check(_beside(map, player, &"snow.school", &"snow.school.teacher.1"), "in the school")
	var teacher: NpcRuntimeState = _npc(map, &"snow.school.teacher.1")
	map.select_npc(teacher.character_id)
	var short: ItemHandlingResult = map.give_to_selected(&"test.silver", 4)
	_check(short.outcome == ItemHandlingResult.Outcome.REFUSED and short.lines == ["魏无极说道：你的诚意不够，这钱还是拿回去吧。", "魏无极没有收下。"], "four taels refused: " + str(short.lines))
	_check(Finance.amount(money, CurrencyDenomination.Value.SILVER) == 12, "nothing lost on a refusal")
	var tuition: ItemHandlingResult = map.give_to_selected(&"test.silver", 5)
	_check(tuition.done() and tuition.lines == ["魏无极点了点头，说道：很好，从今天起你随时可以来问我有关读书识字(literate)的任何问题。", "你拿出五两银子给魏无极。"] and player.state.marks == {"魏无极": 1}, "five taels: marks/魏无极: " + str(tuition.lines))
	_check(Finance.amount(money, CurrencyDenomination.Value.SILVER) == 7, "the tuition is paid")
	await tree.process_frame


func _test_drop_put(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var money: MoneyInventoryContext = Finance.session_context(session)
	var street: Vector2 = map.physical_zone(&"snow.mstreet1").global_rect().get_center()
	_check(_place(map, player, &"snow.mstreet1", street), "in the street")
	var dropped: ItemHandlingResult = map.drop_item(&"test.coins", 20)
	_check(dropped.done() and dropped.lines == ["你丢下一些钱。"] and map.dropped_item_ids() == [dropped.item_id], "drop 20 coin: " + str(dropped.lines))
	var view: WorldFloorItemView = map.floor_item_view(dropped.item_id)
	_check(view != null and view.global_position == street + Vector2(0, 28) and map.dropped_item_location(dropped.item_id).zone_id == &"snow.mstreet1", "it lies in front of the player's feet")
	_add_item(session, &"test.cloth2", &"es2:obj/cloth")
	var worthless: ItemHandlingResult = map.drop_item(&"test.cloth2")
	_check(worthless.destroyed and worthless.lines == ["你丢下一件布衣。", "因为这样东西并不值钱，所以人们并不会注意到它的存在。"] and not session.inventory_state().is_registered(&"test.cloth2"), "drop.c destructs what is worth nothing")
	var before: int = Finance.amount(money, CurrencyDenomination.Value.COIN)
	_check(map.select_floor_item(dropped.item_id) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "picked up again")
	_check(Finance.amount(money, CurrencyDenomination.Value.COIN) == before + 20 and map.dropped_item_ids().is_empty() and _coins(session) == dropped.item_id, "combined.c merges the player's coins into the stack picked up")
	# The 功德箱: put in, see what is inside, take out (get.c `from`).
	var box: StringName = ItemSpawnDefinition.item_instance_id(session.item_id_allocator().scope, &"snow.temple.denotation.1")
	_check(_beside(map, player, &"snow.temple", &"snow.temple.denotation.1"), "beside the box")
	_check(map.container_in_reach() == box, "the box is in reach")
	var put: ItemHandlingResult = map.put_in_container(_coins(session), 30)
	_check(put.done() and put.lines == ["你将一些钱放进功德箱。"] and session.inventory_state().is_direct_child(put.item_id, ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, box)), "put 30 coin in box: %s %s" % [put.outcome, put.lines])
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 300, &"test.heavy_silver")
	var heavy: ItemHandlingResult = map.put_in_container(&"test.heavy_silver")
	_check(heavy.outcome == ItemHandlingResult.Outcome.TOO_HEAVY and heavy.lines[0].ends_with("对功德箱而言太重了。"), "move.c: the box holds 10000")
	_check(map.select_floor_item(box) and map.open_selected_loot() and session.shared_ui().loot_rows().size() == 1 and session.shared_ui().loot_rows()[0].amount == 30, "拾取 on the box lists what is in it")
	var taken: ItemHandlingResult = map.take_from_selected_container(put.item_id)
	_check(taken.done() and taken.lines == ["你从功德箱中拿出一些钱。"] and session.shared_ui().loot_rows().is_empty(), "get coin from box")
	_check(map.put_in_container(_coins(session), 7).done(), "seven coins stay in the box for the save")
	session.shared_ui().close_loot()
	await tree.process_frame


## drunk.c do_drink(): drinks, drops the emptied wineskin, asks for wine; and gives.
func _test_drunk(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(_beside(map, player, &"snow.mstreet2", &"snow.mstreet2.drunk.1"), "beside the drunk")
	var drunk: NpcRuntimeState = _npc(map, &"snow.mstreet2.drunk.1")
	var action: NpcDrinkAction = drunk.definition().talk().chat_entries()[0]
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, drunk.character_id)
	var skin: StringName = &""
	for id: StringName in session.inventory_state().direct_children(holder):
		if session.liquid_collection().state(id) != null:
			skin = id
	session.liquid_collection().state(skin).remaining = 1
	map.npc_life._act(drunk, action)
	_check(hud.log_lines().slice(-2) == ["醉汉拿起牛皮酒袋咕噜噜地喝了几口红酒。", "醉汉丢下一个牛皮酒袋。"], "the last sip, then drop wineskin: " + str(hud.log_lines().slice(-2)))
	_check(drunk.character_state.recovery.water == 30 and map.dropped_item_ids().has(skin) and session.inventory_state().direct_parent(skin).kind == ContainmentEndpoint.Kind.WORLD, "liquid.c water+30; the empty skin lies where he stands")
	map.npc_life._act(drunk, action)
	_check(hud.log_lines().back() == "醉汉说道：酒..... 给我酒...." and not drunk.has_flag(&"has_alcohol"), "no alcohol: has_alcohol = 0, and he asks")
	# A full wineskin from the player: accepted and moved to him (only money has a
	# value(), std/money.c); he drinks from it next.
	var bought: VendorPurchaseResult = VendorPurchaseService.buy(TestContent.waiter(), "wineskin", GameContent.catalog(), Finance.session_context(session), session.food_collection(), session.liquid_collection(), session.item_id_allocator(), player.maximum_encumbrance)
	_check(bought.delivered, "a wineskin bought")
	map.select_npc(_npc(map, &"snow.temple.keeper.1").character_id)
	_check(map.give_to_selected(bought.item_id).outcome == ItemHandlingResult.Outcome.NOT_HERE, "the keeper is not here")
	map.select_npc(drunk.character_id)
	var given: ItemHandlingResult = map.give_to_selected(bought.item_id)
	_check(not given.destroyed and given.lines == ["醉汉说道：多谢啦.....", "你给醉汉一个牛皮酒袋。"] and drunk.has_flag(&"has_alcohol") and session.inventory_state().is_direct_child(bought.item_id, holder), "give wineskin to drunk: " + str(given.lines))
	map.npc_life._act(drunk, action)
	_check(hud.log_lines().back() == "醉汉拿起牛皮酒袋咕噜噜地喝了几口红酒。" and session.liquid_collection().state(bought.item_id).remaining == 14, "he drinks the gift")
	drunk.character_state.recovery.water = 380
	var lines: int = hud.log_lines().size()
	map.npc_life._act(drunk, action)
	_check(hud.log_lines().size() == lines, "sated at 380: he only sings, which prints nothing")
	drunk.character_state.recovery.water = 0
	await tree.process_frame


func _test_shops(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	_check(_beside(map, player, &"snow.herbshop", &"snow.herbshop.herbalist.1"), "in the herbshop")
	var herbalist: NpcRuntimeState = _npc(map, &"snow.herbshop.herbalist.1")
	var shop: VendorService = map.service(&"snow.outdoor.herbshop.herbalist") as VendorService
	_check(shop != null and shop.in_reach() and shop.request_purchase("medicine").delivered, "buy medicine from 杨掌柜")
	# heal_me(), judged on the asker (DECISIONS 4E).
	map.select_npc(herbalist.character_id)
	_check(map.ask_selected("治伤").back() == "杨掌柜说道：这位小姑娘，您看起来气色很好啊，不像有受伤的样子。", "unhurt")
	var vitality: CharacterResourceState = player.state.vitality
	@warning_ignore("integer_division")
	vitality.apply_wound(vitality.maximum * 4 / 100)
	_check(map.ask_selected("疗伤").back() == "杨掌柜说道：哦....我看看....只是些皮肉小伤，您买包金创药回去敷敷就没事了。", "a scratch: 95% or more")
	@warning_ignore("integer_division")
	vitality.apply_wound(vitality.maximum / 2)
	_check(not map.ask_selected("开药").back().begins_with("杨掌柜说道：这位") and map.ask_selected("开药").size() == 2, "heal_me() returns 0: ask.c's own answer")
	vitality.cure(vitality.maximum)
	vitality.heal(vitality.maximum)
	# The smith's shop goes with his body.
	_check(_beside(map, player, &"snow.smithy", &"snow.smithy.smith.1"), "in the smithy")
	var smith: NpcRuntimeState = _npc(map, &"snow.smithy.smith.1")
	var forge: VendorService = map.service(&"snow.outdoor.smithy.smith") as VendorService
	_check(forge.in_reach() and map.interaction_title() == "王铁匠 · 购买", "王铁匠 · 购买")
	smith.set_life_status(CharacterRuntimeLifeStatus.Value.DEAD)
	smith.set_exists_in_map(false)
	map.runtime_body_for_character(smith.character_id).refresh_runtime_state()
	_check(not forge.in_reach(), "no smith, no hammer")
	session.reset_room("d/snow/smithy.c")
	var next: VendorService = map.service(&"snow.outdoor.smithy.smith") as VendorService
	_check(next != null and next != forge and next.npc != smith and next.in_reach(), "the new smith sells again")
	# 安惜迩 can be fought (offense/defense routes; the fight itself: offense_defense_routes_test).
	_check(_beside(map, player, &"snow.bank", &"snow.bank.annihir.1"), "in the bank")
	map.select_npc(_npc(map, &"snow.bank.annihir.1").character_id)
	hud.refresh_live_state()
	_check(hud.attack_is_enabled() and hud.spar_is_enabled(), "攻击/切磋 on 安惜迩")
	_check(map.interaction_title() == "" or map.interaction_title().begins_with("钱庄"), "the bank is the room's, not his")
	await tree.process_frame


func _test_teachers(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var hud: SharedGameplayUI = session.shared_ui()
	# 魏无极 teaches literate to the student he marked (recognize_apprentice()).
	_check(_beside(map, player, &"snow.school", &"snow.school.teacher.1"), "in the school")
	var school: TeacherService = map.service(&"snow.outdoor.school.teacher") as TeacherService
	_check(school != null and school.in_reach() and map.interaction_title() == "魏无极 · 请教", "魏无极 · 请教")
	var learned: LearnResult = school.request_learn(&"literate")
	_check(learned.success and school.last_lines[0] == "你向魏无极请教有关「读书识字」的疑问。" and player.state.skills.has_raw_level(&"literate"), "learn literate from wey: " + str(school.last_lines))
	player.state.marks.clear()
	school.request_learn(&"literate")
	_check(school.last_lines[0] == "魏无极说道：咦？我不记得收过你这个学生啊...." and school.last_lines.size() == 2 and school.last_lines[1].begins_with("魏无极"), "no mark: his say, then learn.c's refusal: " + str(school.last_lines))
	player.state.marks["魏无极"] = 1
	# 李火狮 teaches 封山剑派's students only; his refusal's notify_fail wins.
	_check(_beside(map, player, &"snow.school2", &"snow.school2.fist_trainer.1"), "in the practice yard")
	var yard: TeacherService = map.service(&"snow.outdoor.school2.fist_trainer") as TeacherService
	yard.request_learn(&"unarmed")
	_check(yard.last_lines == ["李火狮说道：对不起，这位小姑娘，您不是我们武馆的弟子。", "李火狮不愿意教你拳法。"], "a guest: " + str(yard.last_lines))
	# 柳淳风 takes the player as his apprentice, then 李火狮 teaches them.
	_check(_beside(map, player, &"snow.schoolhall", &"snow.schoolhall.master.1"), "in the hall")
	var hall: TeacherService = map.service(&"snow.outdoor.schoolhall.master") as TeacherService
	_check(hall.takes_apprentices() and hall.request_apprentice() == NpcApprenticeship.Outcome.RECRUITED and player.facts.title == "封山剑派第十四代弟子", "apprentice 柳淳风")
	_check(hud.log_lines().back() == "恭喜您成为封山剑派的第十四代弟子。", "recruit.c's congratulation")
	map.select_npc(_npc(map, &"snow.schoolhall.master.1").character_id)
	hud.refresh_live_state()
	_check(hud.attack_is_enabled() and hud.spar_is_enabled(), "攻击/切磋 on 柳淳风")
	_check(_beside(map, player, &"snow.school2", &"snow.school2.fist_trainer.1"), "back in the yard")
	_check(yard.request_learn(&"unarmed").success, "李火狮 teaches a 封山剑派 student")
	await tree.process_frame


func _test_save(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var street: Vector2 = map.physical_zone(&"snow.mstreet1").global_rect().get_center()
	_check(_place(map, player, &"snow.mstreet1", street), "in the street")
	var dropped: ItemHandlingResult = map.drop_item(_coins(session), 3)
	# The 竹剑, taken in the weapon storage, lies dropped in the cellar (another map).
	var sword: StringName = ItemSpawnDefinition.item_instance_id(session.item_id_allocator().scope, &"snow.weapon_storage.bamboo_sword.1")
	_check(_beside(map, player, &"snow.weapon_storage", &"snow.weapon_storage.bamboo_sword.1") and map.select_floor_item(sword) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN, "the 竹剑 taken")
	var cellar: WorldMapController = session.world_map_of(&"snow.cellar")
	var below: WorldLocationState = cellar.location_for_zone(&"snow.secret_storage")
	var moved: InventoryTransferResult = InventoryTransferService.new().transfer(session.inventory_state(), sword, InventoryTransferDestination.new(ContainmentEndpoint.new(ContainmentEndpoint.Kind.WORLD, below.combat_location_id), true, true, WorldMapController.WORLD_CAPACITY), player.state.equipment, player.armor)
	_check(moved.succeeded and cellar.floor_items.add_dropped_item_view(sword, below, cellar.floor_items.at_feet(below, cellar.physical_zone(&"snow.secret_storage").global_rect().get_center())), "test-only: the 竹剑 dropped below")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null and snapshot.floor_items.size() == 3, "the save keeps the dropped coins, the drunk's wineskin and the 竹剑 below: %s" % [dropped.lines])
	var raw: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(snapshot).text)
	_check(raw.world_content_revision == WorldContentRevision.serialized(WorldContentRevision.CURRENT_PUBLIC) and raw.player.character.marks.keys() == ["魏无极"] and int(raw.player.character.marks["魏无极"]) == 1, "revision and marks/魏无极 in the save: " + str(raw.world_content_revision))
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "4E")
	_check(walker._failures.is_empty(), "Save/Continue keeps dropped items, the box's coins, the scavenger's cloth, marks: " + str(walker._failures))
	_check(dropped.done(), "dropped before saving")


## The player's coin stack now (a merge keeps the moved stack's identity).
func _coins(session: OldPineWorldSessionController) -> StringName:
	return Finance.session_context(session).select(CurrencyDenomination.Value.COIN).item_id


func _authorities(session: OldPineWorldSessionController) -> ItemHandlingService.Authorities:
	return ItemHandlingService.Authorities.new(Finance.session_context(session), session.food_collection(), session.liquid_collection(), session.item_id_allocator())


func _add_item(session: OldPineWorldSessionController, id: StringName, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var item: ItemInstance = ItemInstance.new(id, definition_id)
	_check(context.inventory.register_item(item, content.own_weight) and context.index.register_snapshot(item) and context.inventory._apply_reparent(id, context.endpoint()), "test item %s" % id)


## The player stands next to the marker `point_id` in `zone_id`, where a save could hold them.
func _beside(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			return _place(map, player, zone_id, marker.global_position + offset)
	return false


func _place(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, at: Vector2) -> bool:
	map.runtime_player_body().global_position = at
	return player.set_world_location(map.location_for_zone(zone_id))


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok: _failures.append("4E: " + label)
