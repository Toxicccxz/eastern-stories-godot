extends RefCounted

## 青石村 B: the 玉佩 and the 蒙汗药 through the real session. The 村长's story marks
## the asker (set_flag() as the code means), the drunk's two whispers for wine, 沈万年's
## jade (unique) and drug (10 taels; less is handed back), his list and buy, the 接话
## 必有妖孽, pouring the drug into wine, the player and the drunk drinking it and
## falling, and Save/Continue keeping the drugged drink and the marks. TEST-ONLY
## fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const WINESKIN: StringName = &"es2:obj/example/wineskin"
const JAR: StringName = &"es2:d/green/npc/obj/ricewine"
const DRUG: StringName = &"es2:obj/slumber_drug"
const DUST: StringName = &"es2:obj/toy/poison_dust"
const JADE: StringName = &"es2:d/green/obj/jade"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "TEST-ONLY: out on the square")
	await tree.physics_frame
	await _test_stranger_wine(tree, session)
	await _test_elder(tree, session)
	await _test_whispers(tree, session)
	await _test_shen(tree, session)
	await _test_pour_and_drink(tree, session)
	await _test_drunk_drugged(tree, session)
	await _test_save(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var elder: NpcTalk = catalog.npc(&"green.npc.oldman2").talk()
	_check(elder.answer("玉佩").size() == 6 and elder.answer_marks("玉佩") == ["elder_info"], "村长: his six lines, and set_flag() marks the asker elder_info")
	_check(elder.relay_phrases() == ["必有妖孽"] and elder.relay_answer("必有妖孽")[0].text == "对呀.. 你就是妖孽... ", "relay_say(): 必有妖孽")
	var shen: NpcDefinition = catalog.npc(&"green.npc.shen")
	_check(NpcInquiry.topics(shen) == ["这里", "名字", "传闻", "玉佩", "蒙汗药"], "沈万年 is asked about 玉佩 and 蒙汗药")
	var jade: Array[NpcInquiryRule] = shen.talk().inquiry_rules("玉佩")
	_check(NpcInquiryRule.decide(jade, {}) == null, "a stranger: give_jade() says only ?")
	_check(NpcInquiryRule.decide(jade, {"give_alcohol": 1, "had_jade": 1}).lines[0].text == "你真贪心耶... ", "greedy")
	_check(NpcInquiryRule.decide(jade, {"give_alcohol": 1}).gives == JADE, "the drunk's word: the jade")
	var drug: NpcInquiryRule = NpcInquiryRule.decide(shen.talk().inquiry_rules("蒙汗药"), {"know_drug": 1})
	_check(drug != null and drug.lines[0].whisper and drug.mark_asker == "can_buy_drug", "蒙汗药: a whisper and can_buy_drug")
	var rules: Array[NpcObjectRule] = shen.dealings().object_rules
	var paid := NpcObjectRule.Offer.new(1000, &"", 0, {}, {"can_buy_drug": 1})
	_check(NpcObjectRule.decide(rules, paid).gives == DRUG and NpcObjectRule.decide(rules, paid).accept, "ten taels: the drug")
	var short: NpcObjectRule = NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(999, &"", 0, {}, {"can_buy_drug": 1}))
	_check(not short.accept and short.unmark_giver == ["give_alcohol", "know_drug"], "less: 想骗我啊? and the flags go")
	_check(not NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(0)).accept and NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(10)).accept, "a stranger's money is kept, anything else refused")
	_check(shen.dealings().shop_front != null and shen.dealings().shop_front.buy[0].text == "我不卖东西给陌生人!", "his list and buy")
	var drunk: Array[NpcObjectRule] = catalog.npc(&"snow.npc.drunk").dealings().object_rules
	var told: NpcObjectRule = NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(0, &"alcohol", 15, {}, {"elder_info": 1}))
	_check(told.accept and told.mark_giver == "give_alcohol" and told.lines[0].whisper, "the drunk, to one who asked the 村长: the 玉佩 whisper")
	var again: NpcObjectRule = NpcObjectRule.decide(drunk, NpcObjectRule.Offer.new(0, &"alcohol", 15, {}, {"elder_info": 1, "give_alcohol": 1}))
	_check(again.mark_giver == "know_drug" and again.lines[0].text.begins_with("听说沈记商行"), "then the 蒙汗药 whisper")


## Without the 村长's story the drunk only thanks; the wine goes to him (no value()).
func _test_stranger_wine(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var drunk: NpcRuntimeState = _beside_npc(map, session, &"snow.mstreet2.drunk.1")
	drunk.set_flag(&"has_alcohol", false) # TEST-ONLY: as if he had drunk his own
	var wine: StringName = _new_item(session, WINESKIN)
	map.select_npc(drunk.character_id)
	var given: ItemHandlingResult = map.give_to_selected(wine)
	_check(given.done() and given.lines == ["醉汉说道：多谢啦.....", "你给醉汉一个牛皮酒袋。"] and session.player_runtime().state.marks.is_empty(), "a stranger's wine: 多谢啦: " + str(given.lines))
	await tree.process_frame


func _test_elder(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"green.village", &"green.path6", &"green.path6", &"green.path6.snow_entry").succeeded(), "TEST-ONLY: into the village")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var elder: NpcRuntimeState = _beside_npc(map, session, &"green.house4.oldman2.1")
	map.select_npc(elder.character_id)
	var lines: Array[String] = map.ask_selected("玉佩")
	_check(lines.size() == 7 and lines[0] == "你向村长打听有关『玉佩』的消息。" and lines[5] == "村长说道：你要找他吗? 有人说他现在以酒度日, 我也不知他的下落." and lines[6] == "村长说道：造孽啊........", "his story: " + str(lines))
	_check(player.state.marks == {"elder_info": 1}, "the asker is marked elder_info")
	# 接话: say.c, then relay_say(); badly hurt the words come out broken.
	hud.open_ask()
	_check(hud.relay_buttons_shown() == ["接话：必有妖孽"], "the 打听 panel offers the 接话")
	var said: Array[String] = map.say_beside_selected("必有妖孽")
	_check(said == ["你说道：必有妖孽", "村长说道：对呀.. 你就是妖孽..."], "relay_say(): 你就是妖孽: " + str(said))
	_check(hud._log_colors.slice(-2) == [ColoredLine.CYN, ColoredLine.PLAIN], "say.c's CYN")
	var kee: int = player.state.vitality.current
	player.state.vitality.current = player.state.vitality.maximum / 5 - 1 # TEST-ONLY
	_check(map.say_beside_selected("必有妖孽") == ["你说道：必有妖孽 ..."], "kee below max_kee / 5: 必有妖孽 ..., which he lets pass")
	player.state.vitality.current = kee
	hud.dismiss_current_panel()
	await tree.process_frame


func _test_whispers(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "TEST-ONLY: back to Snow")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var drunk: NpcRuntimeState = _beside_npc(map, session, &"snow.mstreet2.drunk.1")
	map.select_npc(drunk.character_id)
	var wine: StringName = _new_item(session, WINESKIN)
	var kept: ItemHandlingResult = map.give_to_selected(wine)
	_check(kept.lines == ["醉汉说道：多谢, 不过我还有酒...", "醉汉没有收下。"], "he still has the wine he was given: " + str(kept.lines))
	drunk.set_flag(&"has_alcohol", false) # TEST-ONLY: he drank it
	var first: ItemHandlingResult = map.give_to_selected(wine)
	_check(first.lines == ["醉汉在你的耳边悄声说道：嗯.. 你是想问我玉佩的事吧? 我卖给沈老板了, 那东西不吉祥...", "你给醉汉一个牛皮酒袋。"], "the 玉佩 whisper: " + str(first.lines))
	_check(hud._log_colors.slice(-2) == [ColoredLine.GRN, ColoredLine.PLAIN] and player.state.marks.get("give_alcohol", 0) == 1, "in whisper.c's GRN; give_alcohol")
	drunk.set_flag(&"has_alcohol", false) # TEST-ONLY
	var second: ItemHandlingResult = map.give_to_selected(_new_item(session, WINESKIN))
	_check(second.lines[0] == "醉汉在你的耳边悄声说道：听说沈记商行有在卖蒙汗药..." and player.state.marks.get("know_drug", 0) == 1, "the 蒙汗药 whisper: " + str(second.lines))
	await tree.process_frame


func _test_shen(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"green.village", &"green.path6", &"green.path6", &"green.path6.snow_entry").succeeded(), "TEST-ONLY: to the village")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var money: MoneyInventoryContext = Finance.session_context(session)
	var shen: NpcRuntimeState = _beside_npc(map, session, &"green.shop0.shen.1")
	map.select_npc(shen.character_id)
	# His own list and buy.
	var front: ShopFrontService = null
	for service: WorldService in map.services():
		if service is ShopFrontService:
			front = service
	_check(front != null and front.in_reach(), "beside his counter: 看货")
	front.interact()
	_check(front.last_lines.size() == 2 and front.last_lines[0] == "你看到:" and front.last_lines[1].begins_with("柜子上一堆冥纸和香烛等"), "list: " + str(front.last_lines))
	_check(front.request_buy() == ["沈万年说道：我不卖东西给陌生人!"], "buy: he sells nothing")
	session.shared_ui().dismiss_current_panel()
	# 玉佩: the drunk's word gets the jade, once; the second time he calls the asker greedy.
	var lines: Array[String] = map.ask_selected("玉佩")
	_check(lines == ["你向沈万年打听有关『玉佩』的消息。", "沈万年给你一个玉佩。"] and player.state.marks.get("had_jade", 0) == 1, "the jade: " + str(lines))
	var jade: StringName = _carried(session, JADE)
	_check(not jade.is_empty() and map.violates_unique(JADE), "the jade is carried, and is the only one")
	var greedy: Array[String] = map.ask_selected("玉佩")
	_check(greedy == ["你向沈万年打听有关『玉佩』的消息。", "沈万年说道：你真贪心耶..."], "asked again: greedy: " + str(greedy))
	player.state.marks.erase("had_jade") # TEST-ONLY: as after a login in ES2
	_check(map.ask_selected("玉佩") == ["你向沈万年打听有关『玉佩』的消息。", "沈万年说道：这样东西... 刚刚有人来要过了."], "while one exists no other is made (violate_unique())")
	_check(_count_items(session, JADE) == 1 and not player.state.marks.has("had_jade"), "still one jade")
	# 蒙汗药.
	var asked: Array[String] = map.ask_selected("蒙汗药")
	_check(asked == ["你向沈万年打听有关『蒙汗药』的消息。", "沈万年在你的耳边悄声说道：一份只要 10 两银子, 保证有效喔."] and player.state.marks.get("can_buy_drug", 0) == 1, "the price, whispered: " + str(asked))
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 15, &"test.silver")
	var cheap: ItemHandlingResult = map.give_to_selected(&"test.silver", 5)
	_check(cheap.outcome == ItemHandlingResult.Outcome.REFUSED and cheap.lines == ["沈万年说道：想骗我啊?", "沈万年没有收下。"] and Finance.amount(money, CurrencyDenomination.Value.SILVER) == 15, "five taels: 想骗我啊?, and the money comes back: " + str(cheap.lines))
	_check(not player.state.marks.has("give_alcohol") and not player.state.marks.has("know_drug") and player.state.marks.has("can_buy_drug"), "it costs the give_alcohol and know_drug flags, not can_buy_drug")
	var bought: ItemHandlingResult = map.give_to_selected(&"test.silver", 10)
	_check(bought.done() and bought.lines == ["老板塞了一包蒙汗药给你。", "你拿出十两银子给沈万年。"] and Finance.amount(money, CurrencyDenomination.Value.SILVER) == 5, "ten taels: " + str(bought.lines))
	_check(not _carried(session, DRUG).is_empty(), "a 包 of 蒙汗药 in hand")
	# A stranger's question about the drug is ?: ask.c's own lines.
	player.state.marks.erase("can_buy_drug") # TEST-ONLY
	player.state.marks.erase("know_drug")
	var plain: Array[String] = map.ask_selected("蒙汗药")
	_check(plain.size() == 2 and NpcInquiry.DUNNO.any(func(line: String) -> bool: return line % "沈万年" == plain[1]), "without the drunk's word: a dunno line: " + str(plain))
	await tree.process_frame


func _test_pour_and_drink(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var drug: StringName = _carried(session, DRUG)
	var wine: StringName = _new_item(session, WINESKIN)
	var liquid: LiquidState = session.liquid_collection().state(wine)
	liquid.remaining = 0 # TEST-ONLY: an empty one first
	_check(map.pour_targets().has(wine) and not map.pour_into(drug, wine) and hud.log_lines().back() == "牛皮酒袋里什麽也没有，先装些水酒才能溶化药粉。", "an empty container: nothing to dissolve it in")
	liquid.remaining = 15
	hud.open_inventory()
	await tree.process_frame
	_check(_pour_buttons(hud).has("倒进牛皮酒袋"), "the 背包 offers 倒进 for the drug: %s" % [_pour_buttons(hud)])
	_check(map.pour_into(drug, wine) and hud.log_lines().back() == "你将一些蒙汗药倒进牛皮酒袋，摇晃了几下。", "poured")
	_check(liquid.drink_func == DRUG and _carried(session, DRUG).is_empty(), "the drink carries it; the 包 is used up")
	hud.dismiss_current_panel()
	player.state.recovery.water = 0
	var drank: LiquidUseResult = HeldLiquidUseService.drink(player, Finance.session_context(session), session.liquid_collection(), GameContent.catalog().native_item_projections(), wine, true)
	var slumber: DurationConditionPayload = player.state.conditions.get_condition(ConditionIds.SLUMBER_DRUG) as DurationConditionPayload
	var drunk: DurationConditionPayload = player.state.conditions.get_condition(ConditionIds.DRUNK) as DurationConditionPayload
	_check(drank.outcome == LiquidUseResult.Outcome.DRANK and slumber != null and slumber.remaining == 100 and drunk != null and drunk.remaining == 6, "one sip: slumber_drug 100, drunk 6")
	var fell: bool = false
	for beat: int in range(20):
		session.advance_player_recovery(2.0)
		if player.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			fell = true
			break
	_check(fell and not player.state.conditions.has_condition(ConditionIds.SLUMBER_DRUG), "on the next condition update the player falls unconscious")
	session._advance_life_flow(140.0)
	_check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "and comes to")
	await tree.process_frame


## The drunk drinks a drugged 陶壶 the player gives him (worth nothing, so he keeps it) and passes out.
func _test_drunk_drugged(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "TEST-ONLY: back to Snow")
	await tree.physics_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var drunk: NpcRuntimeState = _beside_npc(map, session, &"snow.mstreet2.drunk.1")
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, drunk.character_id)
	for id: StringName in session.inventory_state().direct_children(holder):
		var held: LiquidState = session.liquid_collection().state(id)
		if held != null:
			held.remaining = 0 # TEST-ONLY: he has drunk his wineskins
	drunk.set_flag(&"has_alcohol", false)
	var jar: StringName = _new_item(session, JAR)
	var drug: StringName = _new_item(session, DUST) # 鸨母's 极乐逍遥散 works the same way
	_check(map.pour_into(drug, jar), "极乐逍遥散 into the 陶壶")
	map.select_npc(drunk.character_id)
	_check(map.give_to_selected(jar).done() and session.inventory_state().is_direct_child(jar, holder), "he takes the 陶壶")
	drunk.character_state.recovery.water = 0
	var action: NpcDrinkAction = drunk.definition().talk().chat_entries()[0]
	# drunk.c: an empty wineskin he comes to first is dropped (drop.c), then the 陶壶.
	for beat: int in range(6):
		map._act(drunk, action)
		if hud.log_lines().back() == "醉汉拿起陶壶咕噜噜地喝了几口米酒。":
			break
	_check(hud.log_lines().back() == "醉汉拿起陶壶咕噜噜地喝了几口米酒。", "he drinks the 米酒: " + hud.log_lines().back())
	var slumber: DurationConditionPayload = drunk.character_state.conditions.get_condition(ConditionIds.SLUMBER_DRUG) as DurationConditionPayload
	_check(slumber != null and slumber.remaining == 100, "slumber_drug + the liquid's 100")
	var fell: bool = false
	for beat: int in range(30):
		map.advance_npc_heartbeat(2.0)
		if drunk.life_status == CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			fell = true
			break
	_check(fell and hud.log_lines().has("醉汉脚下一个不稳，跌在地上一动也不动了。"), "he falls, and the street sees it")
	_check(drunk.revive_in_ms > 0, "and will come to")
	await tree.process_frame


func _test_save(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var wine: StringName = _new_item(session, WINESKIN)
	var dust: StringName = _new_item(session, DUST)
	_check(map.pour_into(dust, wine), "a drugged wineskin to save")
	_check(_place(map, player, &"snow.mstreet1", map.physical_zone(&"snow.mstreet1").global_rect().get_center()), "in the street")
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "the save captures")
	if snapshot == null:
		return
	var raw: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(snapshot).text)
	var poured: Array = (raw.items.liquid_consumables as Array).filter(func(record: Dictionary) -> bool: return record.item_instance_id == String(wine))
	_check(poured.size() == 1 and poured[0].drink_func == String(DUST) and poured[0].slumber_effect == "100", "the drink's powder is saved: %s" % [poured])
	_check(raw.player.character.marks.has("elder_info") and raw.player.character.marks.has("had_jade") == false, "the chain's flags are saved with the marks")
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, snapshot, "青石村 B")
	_check(walker._failures.is_empty(), "Save/Continue restores it exactly: " + str(walker._failures))


func _beside_npc(map: WorldMapController, session: OldPineWorldSessionController, point: StringName) -> NpcRuntimeState:
	var npc: NpcRuntimeState = null
	for candidate: NpcRuntimeState in map.npc_runtimes():
		if candidate.spawn_point_id == point:
			npc = candidate
	var body: WorldCharacterBody2D = null if npc == null else map.runtime_body_for_character(npc.character_id)
	var at: Vector2 = Vector2.INF if body == null else MapPlaces.spot(map, npc.world_location().zone_id, body.global_position, 90.0)
	_check(at != Vector2.INF and _place(map, session.player_runtime(), npc.world_location().zone_id, at), "TEST-ONLY: beside %s" % point)
	return npc


func _place(map: WorldMapController, player: WorldPlayerRuntimeState, zone_id: StringName, at: Vector2) -> bool:
	map.runtime_player_body().global_position = at
	return player.set_world_location(map.location_for_zone(zone_id))


## TEST-ONLY: a new item in the player's hands, as an NPC's give would make it.
func _new_item(session: OldPineWorldSessionController, definition_id: StringName) -> StringName:
	var id: StringName = (session.active_map() as WorldMapController).give_new_item_to_player(definition_id)
	_check(not id.is_empty(), "TEST-ONLY: a new %s" % definition_id)
	return id if session.inventory_state().is_registered(id) else _carried(session, definition_id)


func _carried(session: OldPineWorldSessionController, definition_id: StringName) -> StringName:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for id: StringName in session.inventory_state().direct_children(holder):
		var item: ItemInstance = session.item_instance_index().resolve(id)
		if item != null and item.item_definition_id == definition_id:
			return id
	return &""


func _count_items(session: OldPineWorldSessionController, definition_id: StringName) -> int:
	var count: int = 0
	for id: StringName in session.item_instance_index().snapshot_ids():
		var item: ItemInstance = session.item_instance_index().resolve(id)
		if item != null and item.item_definition_id == definition_id and session.inventory_state().is_registered(id):
			count += 1
	return count


func _pour_buttons(hud: SharedGameplayUI) -> Array[String]:
	var texts: Array[String] = []
	for button: Node in hud.inventory_panel.find_children("Pour", "Button", true, false):
		texts.append((button as Button).text)
	return texts


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("青石村 B: " + label)
