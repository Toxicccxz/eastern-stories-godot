extends RefCounted

## Snow's main path through the real application shell: New Game → work → exchange → buy →
## apprenticeship and learning → spar → ask → death and reincarnation → Old Pine →
## loot → Hockshop sale → Save and Continue. Production entries only: shell requests,
## the setup form, HUD buttons and the service panels' buttons. TEST-ONLY fixtures,
## each declared where used: placements beside far contacts (walking is checked for
## the first legs; the windowed walkthrough walks every room), the combat seed, a
## hurt player before the crazy dog, and the strength to beat the slope bandits.
const ShellTests := preload("res://tests/application/application_shell_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SHELL := preload("res://scenes/application/application_shell.tscn")
const COMBAT_SEED: int = 4242

var assertions: int = 0
var failures: Array[String] = []
var _shell: ApplicationShellController
var _session: OldPineWorldSessionController
var _walker: RefCounted
var _finished: bool = false


func run_all(tree: SceneTree) -> Dictionary:
	_walker = Work.new()
	await _story(tree)
	# A script error ends a step's coroutine without a failed check.
	check(_finished, "the story ran to its end")
	if is_instance_valid(_shell):
		_shell.free()
	await tree.process_frame
	failures.append_array(_walker._failures.map(func(line: String) -> String: return "main path walk: " + line))
	assertions += _walker._count
	return {"assertions": assertions, "failures": failures}


func check(ok: bool, label: String) -> bool:
	assertions += 1
	if not ok:
		failures.append("main path: " + label)
	return ok


func _story(tree: SceneTree) -> void:
	var files := ShellTests.MemoryFiles.new()
	var profile := GameSaveStorageProfile.isolated_test("snow-main-path")
	_shell = SHELL.instantiate()
	_shell.configure_before_start(profile, files, null, ShellTests.MemoryFiles.new())
	tree.root.add_child(_shell)
	await _frames(tree, 3)
	# New Game through the setup form.
	if not check(PublicNewGameTestFixture.request(_shell), "New Game through the setup form"):
		return
	await _frames(tree, 3)
	_session = _shell.runtime_host().current_session()
	if not check(_session != null and _session.is_initialized(), "the journey starts"):
		return
	# Test timing only: world time is passed explicitly below (_pass).
	_session.set_process(false)
	_session.configure_combat_random_source(GodotCombatRandomSource.new(COMBAT_SEED, true))
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var state: CharacterState = player.state
	var hud: SharedGameplayUI = _session.shared_ui()
	check(_session.active_map_id() == &"snow.inn" and player.world_location().zone_id == &"snow.inn.main_floor", "born in the Inn")
	check(player.facts.display_name == "凌雪" and files.files.is_empty(), "the name from the form; birth never saves")
	if not await _work(tree, hud, state):
		return
	if not await _buy(tree, hud, false):
		return
	if not await _exchange(tree, hud):
		return
	if not await _buy(tree, hud, true):
		return
	if not await _learn(tree, hud, state):
		return
	if not await _spar(tree, hud, player):
		return
	if not _ask(hud):
		return
	if not await _die_and_return(tree, player):
		return
	var sword: StringName = await _old_pine_loot(tree, hud, player)
	if sword.is_empty():
		return
	if not await _sell(tree, hud, sword):
		return
	await _save_and_continue(tree, profile, files)


# --- Steps -------------------------------------------------------------------------

## Out of the Inn and up the streets on foot to the mill; 工作 twice on its panel.
func _work(tree: SceneTree, hud: SharedGameplayUI, state: CharacterState) -> bool:
	await _walker.walk(tree, _session, "move_right", 125)
	check(_session.active_map_id() == &"snow.outdoor", "out through the Inn's east door")
	await _walker.walk_to(tree, _session, "move_right", 0, 0)
	await _walker.walk_to(tree, _session, "move_up", -750, 1)
	await _walker.walk_to(tree, _session, "move_right", 325, 0)
	var map: WorldMapController = _map()
	var mill: WorkService = map.service(&"snow.workplace.mill") as WorkService
	if not check(_zone() == &"snow.workplace" and mill.in_reach(), "walked to the workplace's mill"):
		return false
	hud.open_current_context()
	check(mill.panel.visible, "the context button opens the mill")
	for shift: int in 2:
		(mill.panel.get_node("Rows/WorkButton") as Button).pressed.emit()
		check(mill.last_result.succeeded() and mill.silver_amount() == shift + 1, "work.c: a silver a shift")
	check(state.essence.current == 40 and state.spirit.current == 40, "work.c: gin and sen −30 a shift")
	hud.dismiss_current_panel()
	await _settle(tree)
	return true


## Up the street on foot to the bank and 兑换 one of the two silvers.
func _exchange(tree: SceneTree, hud: SharedGameplayUI) -> bool:
	await _to_main_street(tree)
	await _walker.walk_to(tree, _session, "move_up", -400, 1)
	await _walker.walk_to(tree, _session, "move_left", -300, 0)
	var map: WorldMapController = _map()
	var bank: BankService = map.service(&"snow.bank.counter") as BankService
	if not check(_zone() == &"snow.bank" and bank.in_reach(), "walked into the bank: %s at %s" % [_zone(), map.runtime_player_body().global_position]):
		return false
	hud.open_current_context()
	check(bank.panel.visible and bank.panel.quantity.text == "1", "the exchange panel, one silver into coins by default")
	(bank.panel.get_node("Rows/Convert") as Button).pressed.emit()
	check(bank.last_result.conversion != null and Finance.amount(Finance.session_context(_session), CurrencyDenomination.Value.SILVER) == 1 and Finance.amount(Finance.session_context(_session), CurrencyDenomination.Value.COIN) > 0, "bank.c convert: coins for the silver: %s" % bank.panel.feedback.text)
	hud.dismiss_current_panel()
	await _settle(tree)
	return true


## Back to the Inn on foot for a dumpling from 店小二. Two silvers buy none, nor would
## coins alone: feature/finance.c can_afford() wants coins for price % 100 and a silver
## object for the rest (kept as ES2 has it), and buy.c says so.
func _buy(tree: SceneTree, hud: SharedGameplayUI, has_change: bool) -> bool:
	await _to_main_street(tree)
	await _walker.walk_to(tree, _session, "move_down", 0, 1)
	await _walk_until_map(tree, "move_left", &"snow.inn")
	if not check(_session.active_map_id() == &"snow.inn", "back into the Inn through the square's west door"):
		return false
	var inn: WorldMapController = _map()
	check(_beside(inn, &"snow.inn.main_floor", &"snow.inn.main_floor.inn.waiter.1"), "TEST-ONLY placement beside the waiter")
	await _settle(tree)
	var shop: VendorService = inn.service(&"snow.inn.waiter") as VendorService
	check(inn.interaction_title() == "店小二 · 购买", "购买 beside the waiter: " + inn.interaction_title())
	var before: int = _money_value()
	hud.open_current_context()
	check(shop.panel.visible, "his goods open")
	var dumpling: Button = null
	for button: Node in shop.goods_rows.get_children():
		if (button as Button).text.begins_with("包子"):
			dumpling = button as Button
	if not check(dumpling != null, "a 包子 on his list"):
		return false
	dumpling.pressed.emit()
	if has_change:
		check(shop.last_purchase.delivered and _money_value() == before - 15, "vendor.c: a 包子 for 15 coins: %d -> %d (%s)" % [before, _money_value(), shop.feedback.text])
		hud.dismiss_current_panel()
		await _settle(tree)
		hud.open_supplies()
		await _frames(tree, 2)
		hud._food._eat.pressed.emit()
		var eaten: FoodUseResult = hud._food.last_result
		check(eaten != null and eaten.outcome == FoodUseResult.Outcome.TOO_FULL and hud._food._feedback.text == "你已经吃太饱了，再也塞不下任何东西了。", "补给: food.c, too full to eat at birth: " + hud._food._feedback.text)
	else:
		check(not shop.last_purchase.delivered and _money_value() == before and shop.feedback.text == "你没有足够的零钱，而对方也找不开...。", "buy.c: no change for two silvers: " + shop.feedback.text)
	hud.dismiss_current_panel()
	await _settle(tree)
	await _walk_until_map(tree, "move_right", &"snow.outdoor")
	return check(_session.active_map_id() == &"snow.outdoor", "out again")


## 拜师 柳淳风 and 学 basic unarmed, from his panel.
func _learn(tree: SceneTree, hud: SharedGameplayUI, state: CharacterState) -> bool:
	var map: WorldMapController = _map()
	check(_beside(map, &"snow.schoolhall", &"snow.schoolhall.master.1"), "TEST-ONLY placement in the hall")
	await _settle(tree)
	var hall: TeacherService = map.service(&"snow.outdoor.schoolhall.master") as TeacherService
	hud.open_current_context()
	if not check(hall.ui != null and hall.ui.panel.visible, "柳淳风's panel: " + map.interaction_title()):
		return false
	hall.ui.apprentice_button.pressed.emit()
	if not check(state.family.family_id == &"family.fonxan" and state.apprenticeship.master_teacher_id == &"common.npc.swordsman.master", "apprenticed to 柳淳风"):
		return false
	var gin: int = state.essence.current
	var spent: int = state.progression.potential_spent
	hall.ui.learn_buttons[&"unarmed"].pressed.emit()
	check(state.progression.potential_spent == spent + 1 and state.essence.current < gin and hall.last_lines[0].begins_with("你向柳淳风请教"), "learn.c: a lesson in unarmed: %s" % [hall.last_lines])
	hud.dismiss_current_panel()
	await _settle(tree)
	# Beside 李火狮 the school gate is in reach too; the nearer one, he, is the context.
	check(_beside(map, &"snow.school2", &"snow.school2.fist_trainer.1") and map.can_operate_door(&"snow.school.gate"), "TEST-ONLY placement beside 李火狮, by the gate")
	await _settle(tree)
	check(map.interaction_title() == "李火狮 · 请教", "the context button offers his lessons, not the gate: " + map.interaction_title())
	var yard: TeacherService = map.service(&"snow.outdoor.school2.fist_trainer") as TeacherService
	hud.open_current_context()
	if check(yard.ui.panel.visible, "李火狮's panel"):
		yard.ui.learn_buttons[&"unarmed"].pressed.emit()
		check(yard.last_lines[0] == "你向李火狮请教有关「基本拳脚」的疑问。", "李火狮 teaches a 封山剑派 student: %s" % [yard.last_lines])
	hud.dismiss_current_panel()
	await _settle(tree)
	return true


## 切磋 with a trainee through the HUD; the spar ends with both standing.
func _spar(tree: SceneTree, hud: SharedGameplayUI, player: WorldPlayerRuntimeState) -> bool:
	var map: WorldMapController = _map()
	check(_beside(map, &"snow.school2", &"snow.school2.trainee.6"), "TEST-ONLY placement in the practice yard")
	await _settle(tree)
	var trainee: NpcRuntimeState = _npc(map, &"snow.school2.trainee.6")
	map.select_npc(trainee.character_id)
	hud.refresh_live_state()
	if not check(hud.spar_is_enabled(), "切磋 offered on the trainee"):
		return false
	hud.spar_button.pressed.emit()
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	if not check(coordinator.has_active_encounter() and coordinator.active_encounter().mode == CombatEncounterMode.Value.SPAR, "fight.c: the trainee accepts a spar"):
		return false
	check(_fight(), "the spar ends")
	check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and trainee.life_status != CharacterRuntimeLifeStatus.Value.DEAD, "both stand after the spar")
	await _settle(tree)
	_pass(4.0)
	check(not player.busy.is_busy() and OldPineSaveEligibility.inspect(_session).allowed(), "after the fight Save is open")
	# TEST-ONLY: the busy 1 a pickup in a fight leaves (get.c start_busy(1)); no fight
	# here can leave one yet. The heart beat outside the fight wears it off (char.c).
	player.busy.start_busy(1)
	check(not OldPineSaveEligibility.inspect(_session).allowed(), "busy keeps Save closed")
	_pass(2.0)
	check(not player.busy.is_busy() and OldPineSaveEligibility.inspect(_session).allowed(), "one beat later busy is gone and Save is open")
	return true


## 打听 杨掌柜 about 治伤 through the HUD's topic buttons.
func _ask(hud: SharedGameplayUI) -> bool:
	var map: WorldMapController = _map()
	check(_beside(map, &"snow.herbshop", &"snow.herbshop.herbalist.1"), "TEST-ONLY placement in the herbshop")
	map.select_npc(_npc(map, &"snow.herbshop.herbalist.1").character_id)
	hud.refresh_live_state()
	if not check(hud.ask_is_enabled(), "打听 offered on 杨掌柜"):
		return false
	hud.ask_button.pressed.emit()
	check(hud.ask_topics_shown().has("治伤"), "ask.c lists his topics: %s" % [hud.ask_topics_shown()])
	for button: Node in hud._ask_topics.get_children():
		if (button as Button).text == "治伤" and not button.is_queued_for_deletion():
			(button as Button).pressed.emit()
	check(hud.ask_answer_text().contains("杨掌柜说道："), "he answers: " + hud.ask_answer_text())
	hud.dismiss_current_panel()
	return true


## The crazy dog on the west road kills the player; the gargoyle's lines; back at the temple.
func _die_and_return(tree: SceneTree, player: WorldPlayerRuntimeState) -> bool:
	var map: WorldMapController = _map()
	var carried: Array[StringName] = _carried(player)
	var dog: NpcRuntimeState = _npc(map, &"snow.sroad4.crazy_dog.1")
	# TEST-ONLY: already badly hurt, so the dog's first bite decides (a fresh
	# character also loses to it about half the time).
	player.state.vitality.current = 1
	check(_beside(map, &"snow.sroad4", &"snow.sroad4.crazy_dog.1"), "TEST-ONLY placement beside the crazy dog")
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	for frame: int in 60:
		await tree.physics_frame
		if coordinator.has_active_encounter():
			break
	if not check(coordinator.has_active_encounter(), "the crazy dog attacks on sight"):
		return false
	check(_fight(), "the fight ends")
	var flow: PlayerLifeFlow = _session.player_life_flow()
	if not check(player.life_status == CharacterRuntimeLifeStatus.Value.DEAD and flow.is_active(), "killed by the dog"):
		return false
	check(not OldPineSaveEligibility.inspect(_session).allowed(), "no Save while dead")
	var corpse: CorpseState = null
	for candidate: CorpseState in map.corpse_states():
		if candidate.victim_character_id == player.character_id:
			corpse = candidate
	check(corpse != null and _session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.ITEM, corpse.corpse_item_instance_id)) == carried, "everything carried lies in the corpse on the west road")
	for second: int in 60:
		if not flow.is_active():
			break
		_pass(1.0)
	check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and _zone() == &"snow.temple", "reincarnated at the temple")
	check([player.state.vitality.current, player.state.vitality.effective] == [1, player.state.vitality.maximum] and dog.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "with one kee and full effective kee; the dog lives")
	await _settle(tree)
	return check(OldPineSaveEligibility.inspect(_session).allowed(), "Save open again")


## South on foot from the temple to Old Pine; the slope bandits attack and are beaten;
## the short sword taken from a corpse. Returns its item id.
func _old_pine_loot(tree: SceneTree, hud: SharedGameplayUI, player: WorldPlayerRuntimeState) -> StringName:
	await _walker.walk_to(tree, _session, "move_right", 420, 0)
	await _walker.walk_to(tree, _session, "move_down", 550, 1)
	check(_zone() == &"snow.eroad1", "out of the temple's south door")
	await _walker.walk_to(tree, _session, "move_right", 1100, 0)
	check(_zone() == &"snow.eroad3", "along the east road")
	await _walk_until_map(tree, "move_down", OldPineWorldDefinitions.OUTDOOR_MAP_ID)
	if not check(_session.active_map_id() == OldPineWorldDefinitions.OUTDOOR_MAP_ID, "eroad3 south into Old Pine"):
		return &""
	var forest: WorldMapController = _map()
	# TEST-ONLY: the strength to beat three bandits (a new character cannot).
	player.state.progression.combat_experience = 1000000
	player.state.vitality = CharacterResourceState.new(10000, 10000, 10000)
	var bandits: Array[NpcRuntimeState] = forest.npc_runtimes().slice(0, 3)
	var bandit: WorldCharacterBody2D = forest.runtime_body_for_character(bandits[0].character_id)
	forest.player_body.global_position = bandit.global_position + Vector2(0, 40)
	player.set_world_location(forest.location_for_zone(&"oldpine.outdoor.slope"))
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	for frame: int in 60:
		await tree.physics_frame
		if coordinator.has_active_encounter():
			break
	if not check(coordinator.has_active_encounter(), "the bandits attack on sight"):
		return &""
	check(_fight(), "the fight with the bandits ends")
	await _settle(tree)
	var corpse: CorpseState = null
	for candidate: CorpseState in forest.corpse_states():
		if candidate.victim_character_id == bandits[0].character_id:
			corpse = candidate
	if not check(player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and corpse != null, "the bandit lies dead"):
		return &""
	forest.player_body.global_position = forest.corpse_view_for(corpse.corpse_item_instance_id).global_position + Vector2(0, 30)
	await _settle(tree)
	check(forest.select_corpse(corpse.corpse_item_instance_id), "select the corpse")
	hud.refresh_live_state()
	hud.open_loot_button.pressed.emit()
	var sword: StringName = &""
	for row: WorldItemRowProjection in hud.loot_rows():
		if row.display_name == "短剑":
			sword = row.item_instance_id
	if not check(hud.loot_is_open() and not sword.is_empty(), "拾取 lists the short sword: %s" % [hud.loot_rows().map(func(row: WorldItemRowProjection) -> String: return row.display_name)]):
		return &""
	var taken: CorpseLootTransferResult = forest.take_selected_loot_item(sword)
	check(taken.succeeded and _carried(player).has(sword), "get.c: the short sword taken")
	hud.dismiss_current_panel()
	await _settle(tree)
	_pass(4.0)
	return sword


## North back to Snow on foot; 卖断 the short sword at the Hockshop.
func _sell(tree: SceneTree, hud: SharedGameplayUI, sword: StringName) -> bool:
	var forest: WorldMapController = _map()
	check(_place(forest, &"oldpine.outdoor.north_approach", forest.resolve_spawn_marker(SnowOldPineConnectionDefinitions.NORTH_ENTRY_SPAWN_ID).global_position), "TEST-ONLY placement at the north approach")
	await _settle(tree)
	await _walk_until_map(tree, "move_up", &"snow.outdoor")
	if not check(_session.active_map_id() == &"snow.outdoor" and _zone() == &"snow.eroad3", "north from Old Pine back to eroad3"):
		return false
	var map: WorldMapController = _map()
	var counter: HockshopService = map.service(&"snow.hockshop.counter") as HockshopService
	var spot: Vector2 = map.physical_zone(&"snow.hockshop").global_rect().get_center()
	check(_place(map, &"snow.hockshop", spot) and counter.in_reach(), "TEST-ONLY placement at the Hockshop counter")
	await _settle(tree)
	var before: int = _money_value()
	hud.open_current_context()
	check(counter.panel.visible, "丰登当铺's panel")
	counter.select_item(sword)
	check(counter.selection.text == "短剑 · 未装备", "the sword by its name, no item ID: " + counter.selection.text)
	counter.value_button.pressed.emit()
	var price: int = 0 if counter.last_valuation == null else counter.last_valuation.actual_payout
	check(price > 0, "hockshop.c 估价 the short sword: %d coins" % price)
	counter.sell_button.pressed.emit()
	counter.confirm_button.pressed.emit()
	check(counter.last_sell != null and counter.last_sell.outcome == HockshopSellResult.Outcome.SOLD and not _session.inventory_state().is_registered(sword), "卖断: the sword is gone")
	check(_money_value() == before + price, "paid what it was valued at")
	hud.dismiss_current_panel()
	await _settle(tree)
	return true


## Pause → Save; a fresh shell's Continue restores the exact state.
func _save_and_continue(tree: SceneTree, profile: GameSaveStorageProfile, files: ShellTests.MemoryFiles) -> void:
	var hud: SharedGameplayUI = _session.shared_ui()
	hud.open_messages()
	await _frames(tree, 3)
	check(hud.combat_log.is_visible_in_tree() and hud.combat_log.size.y >= 300.0 and hud.combat_log.get_parsed_text().contains(hud.log_lines().back()), "消息 shows the log, up to its last line")
	hud.dismiss_current_panel()
	await _settle(tree)
	check(_shell.request_pause(), "Pause")
	var before: GameSaveSnapshot = Work.capture(_session)
	if not check(before != null, "the whole journey captures"):
		return
	var encoded: String = GameSaveJsonCodec.encode(before).text
	check(_shell.request_save_from_pause(), "Save")
	await _frames(tree, 3)
	check(_shell.last_result().succeeded() and not files.files.is_empty(), "the save is written")
	var old_session: WeakRef = weakref(_session)
	_session = null
	_shell.free()
	await _frames(tree, 3)
	check(old_session.get_ref() == null, "the old session is gone")
	_shell = SHELL.instantiate()
	_shell.configure_before_start(profile, files, null, ShellTests.MemoryFiles.new())
	tree.root.add_child(_shell)
	await _frames(tree, 3)
	check(_shell.request_continue_from_menu(), "Continue from the menu")
	await _frames(tree, 3)
	_session = _shell.runtime_host().current_session()
	if not check(_session != null, "Continue installs the journey"):
		return
	_session.set_process(false)
	var after: GameSaveSnapshot = Work.capture(_session)
	check(after != null and GameSaveJsonCodec.encode(after).text == encoded, "Continue restores the exact state")
	var state: CharacterState = _session.player_runtime().state
	check(state.family.family_id == &"family.fonxan" and state.apprenticeship.master_teacher_id == &"common.npc.swordsman.master", "still 柳淳风's apprentice")
	check(_session.active_map_id() == &"snow.outdoor" and _zone() == &"snow.hockshop", "standing in the Hockshop")
	var corpses: int = 0
	for map: WorldMapController in _session.world_maps():
		corpses += map.corpse_states().size()
	check(corpses >= 2, "the player's corpse on the west road and the bandits' in Old Pine: %d" % corpses)
	_finished = true


# --- Helpers -----------------------------------------------------------------------

## Along the street to the main street's line (x = 0).
func _to_main_street(tree: SceneTree) -> void:
	var x: float = _map().runtime_player_body().global_position.x
	await _walker.walk_to(tree, _session, "move_left" if x > 0.0 else "move_right", 0, 0)


## Passes world time as _process does each frame (one-second steps).
func _pass(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_session._process(minf(1.0, left))
		left -= 1.0


## Runs the active fight on world time; false when it outlives ten minutes or aborts.
func _fight() -> bool:
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	for second: int in 600:
		if not coordinator.has_active_encounter():
			break
		_pass(1.0)
	return not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0


func _walk_until_map(tree: SceneTree, action: String, map_id: StringName) -> void:
	Input.action_press(action)
	for frame: int in 400:
		if _session.active_map_id() == map_id:
			break
		await tree.physics_frame
	Input.action_release(action)
	await _settle(tree)


func _settle(tree: SceneTree) -> void:
	for frame: int in 3:
		await tree.physics_frame


func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.process_frame


func _map() -> WorldMapController:
	return _session.active_map() as WorldMapController


func _zone() -> StringName:
	return _session.player_runtime().world_location().zone_id


## The player's money in coins (std/money.c: a silver is 100 coins, a gold 10000).
func _money_value() -> int:
	var context: MoneyInventoryContext = Finance.session_context(_session)
	return (
		Finance.amount(context, CurrencyDenomination.Value.COIN)
		+ 100 * Finance.amount(context, CurrencyDenomination.Value.SILVER)
		+ 10000 * Finance.amount(context, CurrencyDenomination.Value.GOLD)
	)


func _carried(player: WorldPlayerRuntimeState) -> Array[StringName]:
	return _session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id))


func _npc(map: WorldMapController, point: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_point_id == point:
			return npc
	return null


## Next to the marker `point_id` in `zone_id`, where a save could hold the player.
func _beside(map: WorldMapController, zone_id: StringName, point_id: StringName) -> bool:
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(point_id)
	if marker == null:
		return false
	for offset: Vector2 in [Vector2(0, 48), Vector2(48, 0), Vector2(-48, 0), Vector2(0, -48), Vector2(40, 40), Vector2(-40, 40)]:
		if MapPlacementValidator.is_valid_character_position(map, zone_id, marker.global_position + offset):
			return _place(map, zone_id, marker.global_position + offset)
	return false


func _place(map: WorldMapController, zone_id: StringName, at: Vector2) -> bool:
	map.runtime_player_body().global_position = at
	return _session.player_runtime().set_world_location(map.location_for_zone(zone_id))
