extends RefCounted

## 绮云镇 3D: the 赌场's 宝官 (u/cloud/npc/judge.c) and the 红娘庄's 媒婆
## (u/cloud/npc/mei_po.c). Money given to the 宝官 is a bet on 小: accept_object() says
## 什么？ 您押小？！好的。, give.c destructs the stake, random(10) < 8 loses and anything
## else pays pay_player(val * 2) in silver and coins; of winnings the player cannot carry
## they take what fits and the rest lands at their feet (owner, 3D; ES2 lost them), and
## picking up a pile too heavy as a whole takes what fits. He takes nothing without a value().
## Marriage needs a second player (find_player), so the 媒婆 offers none (DECISIONS 3D).
## TEST-ONLY fixtures are marked where used.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const SILVER: StringName = &"es2:obj/money/silver"
const COIN: StringName = &"es2:obj/money/coin"
const GOLD: StringName = &"es2:obj/money/gold"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_wager_rules()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_bets(tree, session)
	var piles: Array[StringName] = await _test_winnings_at_feet(tree, session)
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "in the 赌场 with winnings on the floor")
	_check(work._failures.is_empty(), "Save/Continue: " + str(work._failures))
	await _test_pick_up(tree, session, piles)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var judge: NpcDefinition = GameContent.catalog().npc(&"cloud.npc.judge")
	var wager: NpcWager = judge.dealings().wager
	_check(wager != null and wager.lose_below == 8 and wager.out_of == 10 and wager.payout == 2, "judge.c: random(10) < 8 loses, a win pays double")
	var rules: Array[NpcObjectRule] = judge.dealings().object_rules
	_check(rules.size() == 1 and rules[0].effect == NpcObjectRule.EFFECT_WAGER and rules[0].value_at_least == 1 and rules[0].accept, "he takes any money as a bet")
	_check(NpcObjectRule.decide(rules, NpcObjectRule.Offer.new(0)) == null, "value() 0: accept_object() returns 0")
	var mei_po: NpcDefinition = GameContent.catalog().npc(&"cloud.npc.mei_po")
	_check(NpcInquiry.topics(mei_po).has("婚约"), "the 媒婆 answers about 婚约: " + str(NpcInquiry.topics(mei_po)))
	_check(mei_po.dealings().object_rules.is_empty() and mei_po.dealings().wager == null and mei_po.dealings().vendor_id.is_empty(), "and offers nothing else: marriage needs a second player (DECISIONS 3D)")


## NpcWager and its data: the roll, pay_player's amount and what the loader refuses.
func _test_wager_rules() -> void:
	var wager: NpcWager = GameContent.catalog().npc(&"cloud.npc.judge").dealings().wager
	var lost: Array[int] = []
	for draw: int in range(10):
		var random := ScriptedWorldInteractionRandomSource.new([draw])
		if not wager.wins(random):
			lost.append(draw)
		_check(random.requested_bounds() == ([10] as Array[int]), "random(10)")
	_check(lost == ([0, 1, 2, 3, 4, 5, 6, 7] as Array[int]), "0-7 lose, 8 and 9 win: " + str(lost))
	_check(wager.winnings(100) == 200 and wager.winnings(10000) == 20000 and wager.winnings(1) == 2, "val * 2")
	_check(wager.winnings(0) == 1, "pay_player: if( amount < 1 ) amount = 1")
	_check(wager.winnings(CurrencyArithmetic.MAXIMUM) == -1, "an overflow is no payout")
	var bad: Array[Dictionary] = [
		{"lose_below": 11, "out_of": 10, "payout": 2, "lose": {"line": "x"}, "win": {"line": "y"}},
		{"lose_below": 8, "out_of": 0, "payout": 2, "lose": {"line": "x"}, "win": {"line": "y"}},
		{"lose_below": 8, "out_of": 10, "payout": 0, "lose": {"line": "x"}, "win": {"line": "y"}},
		{"lose_below": 8, "out_of": 10, "payout": 2, "win": {"line": "y"}},
		{"lose_below": 8, "out_of": 10, "payout": 2, "lose": {"line": "x"}, "win": {"line": "y"}, "odds": 3},
	]
	for record: Dictionary in bad:
		var errors: Array[String] = []
		NpcWager.from_record(ContentRecordReader.new(record, "test", errors))
		_check(not errors.is_empty(), "refused: " + str(record))
	var errors: Array[String] = []
	NpcDealings.from_record(ContentRecordReader.new({"accept_object": [{"value_at_least": 1, "accept": true, "effect": "wager"}]}, "test", errors))
	_check(not errors.is_empty(), "a wager rule needs a wager record")
	errors.clear()
	NpcDealings.from_record(ContentRecordReader.new({"wager": {"lose_below": 8, "out_of": 10, "payout": 2, "lose": {"line": "x"}, "win": {"line": "y"}}}, "test", errors))
	_check(not errors.is_empty(), "and a wager record a wager rule")
	errors.clear()
	NpcObjectRule.from_record(ContentRecordReader.new({"accept": true, "effect": "wager"}, "test", errors))
	_check(not errors.is_empty(), "a bet is money: value_at_least 1")


## give <money> to judge in the 赌场: lost, won in silver, won in coins, won on gold
## (paid in silver), and something worth nothing (no roll).
func _test_bets(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var judge: NpcRuntimeState = _npc(map, &"cloud.npc.judge")
	session.handoff_to(&"cloud.outdoor", &"cloud.duchang", &"cloud.duchang", &"cloud.duchang.stairs_return")
	await tree.physics_frame
	await tree.physics_frame
	_check(player.world_location().zone_id == &"cloud.duchang" and judge.world_location().zone_id == &"cloud.duchang", "the player and the 宝官 in the 赌场")
	_check(map.select_npc(judge.character_id) and map.selected_npc_takes_gifts(), "he can be given things")
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 10, &"test.casino.silver") # TEST-ONLY
	Finance.add_money(money, CurrencyDenomination.Value.COIN, 150, &"test.casino.coin") # TEST-ONLY
	Finance.add_money(money, CurrencyDenomination.Value.GOLD, 1, &"test.casino.gold") # TEST-ONLY
	var silver: int = Finance.amount(money, CurrencyDenomination.Value.SILVER)
	var coins: int = Finance.amount(money, CurrencyDenomination.Value.COIN)
	var respect: String = RankWords.query_respect(player.state.gender, player.facts.age, player.state.affiliation.class_id)
	var original: WorldInteractionRandomSource = map.world_interaction_random_source()

	var random := ScriptedWorldInteractionRandomSource.new([7]) # TEST-ONLY: random(10) 7 < 8
	map.replace_world_interaction_random_source(random)
	var said: int = session.shared_ui().log_lines().size()
	var bet: ItemHandlingResult = map.give_to_selected(_carried(session, SILVER), 1)
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(bet.done() and bet.destroyed and random.requested_bounds() == ([10] as Array[int]), "one tael bet, the stake destructed, random(10)")
	_check(lines == (["什么？ 您押小？！好的。", "你拿出一两银子给宝官。", "宝官说道：开！押大的赢啦！这位%s，您下次一定好运！" % respect] as Array[String]), "lost: " + str(lines))
	_check(Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver - 1, "the tael is gone")

	random = ScriptedWorldInteractionRandomSource.new([8]) # TEST-ONLY
	map.replace_world_interaction_random_source(random)
	said = session.shared_ui().log_lines().size()
	bet = map.give_to_selected(_carried(session, SILVER), 3)
	lines = session.shared_ui().log_lines().slice(said)
	_check(bet.done() and lines.size() == 3 and lines[0] == "什么？ 您押小？！好的。" and lines[1] == "你拿出三两银子给宝官。" and lines[2] == "宝官说道：开！押小的赢啦！这位%s真是好运道！这是您的赢头。" % respect, "won: " + str(lines))
	_check(Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver - 1 - 3 + 6 and bet.dropped_item_ids.is_empty(), "three taels pay six")

	random = ScriptedWorldInteractionRandomSource.new([9]) # TEST-ONLY
	map.replace_world_interaction_random_source(random)
	bet = map.give_to_selected(_carried(session, COIN), 75)
	_check(bet.done() and Finance.amount(money, CurrencyDenomination.Value.COIN) == coins - 75 + 50 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver + 2 + 1,
		"75 coins pay 150: one tael and 50 coins (pay_player)")

	random = ScriptedWorldInteractionRandomSource.new([9]) # TEST-ONLY
	map.replace_world_interaction_random_source(random)
	bet = map.give_to_selected(_carried(session, GOLD), 1)
	_check(bet.done() and _carried(session, GOLD).is_empty() and Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver + 3 + 200, "a tael of gold pays 200 taels of silver")

	# The whole stack: in ES2 pay_player()'s new silver absorbed the stake still carried
	# (combined.c) and give.c never destructed it, so a win paid three times (DECISIONS 3D).
	var whole: int = Finance.amount(money, CurrencyDenomination.Value.SILVER)
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([9])) # TEST-ONLY
	bet = map.give_to_selected(_carried(session, SILVER), 0)
	_check(bet.done() and Finance.amount(money, CurrencyDenomination.Value.SILVER) == whole * 2, "the whole stack of %d taels pays twice its value, not three times" % whole)
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([0])) # TEST-ONLY
	bet = map.give_to_selected(_carried(session, SILVER), 0)
	_check(bet.done() and _carried(session, SILVER).is_empty(), "and lost, it is gone")
	Finance.add_money(money, CurrencyDenomination.Value.SILVER, 10, &"test.casino.silver.more") # TEST-ONLY

	random = ScriptedWorldInteractionRandomSource.new([9]) # TEST-ONLY
	map.replace_world_interaction_random_source(random)
	var thing: StringName = &"test.casino.book"
	_add_item(session, thing, &"es2:u/cloud/obj/literate_book") # TEST-ONLY
	said = session.shared_ui().log_lines().size()
	bet = map.give_to_selected(thing, 0)
	_check(bet.outcome == ItemHandlingResult.Outcome.REFUSED and _carried_ids(session).has(thing), "a thing without value(): refused, still carried")
	_check(session.shared_ui().log_lines().slice(said) == (["宝官没有收下。"] as Array[String]) and random.call_count() == 0, "宝官没有收下。, no roll: " + str(session.shared_ui().log_lines().slice(said)))
	map.replace_world_interaction_random_source(original)


## Winnings too heavy to carry: the player takes what fits, the rest of each kind lies at
## their feet (a gold tael's 200 taels with room for 10; 99 coins' 1 tael and 98 coins with
## room for the tael and 67 coins), the two piles apart. They stay through Save/Continue.
func _test_winnings_at_feet(tree: SceneTree, session: OldPineWorldSessionController) -> Array[StringName]:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var money: MoneyInventoryContext = Finance.session_context(session)
	Finance.add_money(money, CurrencyDenomination.Value.GOLD, 1, &"test.casino.gold2") # TEST-ONLY
	# TEST-ONLY: room for 10 taels and 5 more once the gold tael (37) is gone.
	Finance.ballast(money, player.maximum_encumbrance - money.checked_contents_weight() - (10 * 37 + 5 - 37))
	var silver: int = Finance.amount(money, CurrencyDenomination.Value.SILVER)
	var coins: int = Finance.amount(money, CurrencyDenomination.Value.COIN)
	var floor_before: Array[StringName] = map.floor_item_ids()
	var original: WorldInteractionRandomSource = map.world_interaction_random_source()
	map.replace_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new([8, 8])) # TEST-ONLY
	var said: int = session.shared_ui().log_lines().size()
	var gold: ItemHandlingResult = map.give_to_selected(_carried(session, GOLD), 1)
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(gold.done() and gold.dropped_item_ids.size() == 1 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver + 10, "200 taels with room for 10: 10 carried")
	_check(lines.size() == 4 and lines[3] == "一百九十两银子对你而言太重了，掉在你的脚边。", "the player reads what fell: " + str(lines))
	said = session.shared_ui().log_lines().size()
	var coin: ItemHandlingResult = map.give_to_selected(_carried(session, COIN), 99)
	lines = session.shared_ui().log_lines().slice(said)
	map.replace_world_interaction_random_source(original)
	_check(coin.done() and coin.dropped_item_ids.size() == 1 and Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver + 11 and Finance.amount(money, CurrencyDenomination.Value.COIN) == coins - 99 + 67,
		"99 coins pay 198: the tael and 67 coins carried (room 104)")
	_check(lines.size() == 4 and lines[3] == "三十一文钱对你而言太重了，掉在你的脚边。", "and 31 coins fell: " + str(lines))
	var piles: Array[StringName] = []
	piles.append_array(gold.dropped_item_ids)
	piles.append_array(coin.dropped_item_ids)
	var views: Array[WorldFloorItemView] = []
	for pile: StringName in piles:
		views.append(map.floor_item_view(pile))
	_check(piles.size() == 2 and not floor_before.has(piles[0]) and not floor_before.has(piles[1]) and not views.has(null), "two piles on the floor")
	if views.size() == 2 and not views.has(null):
		_check(session.stack_collection().stack_state(piles[0]).amount == 190 and session.stack_collection().stack_state(piles[1]).amount == 31, "190 taels and 31 coins")
		for view: WorldFloorItemView in views:
			_check(view.global_position.distance_to(map.runtime_player_body().global_position) < 100.0, "at the player's feet")
		_check(views[0].global_position.distance_to(views[1].global_position) > 8.0, "apart")
	_unballast(money)
	await tree.physics_frame
	return piles


## get.c on the piles: with room for 50 taels the 190 give 50 and 140 stay; then the rest.
func _test_pick_up(tree: SceneTree, session: OldPineWorldSessionController, piles: Array[StringName]) -> void:
	var map: WorldMapController = session.world_map_of(&"cloud.outdoor")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var money: MoneyInventoryContext = Finance.session_context(session)
	if piles.size() != 2:
		_check(false, "no piles to pick up")
		return
	Finance.ballast(money, player.maximum_encumbrance - money.checked_contents_weight() - (50 * 37 + 10)) # TEST-ONLY
	var silver: int = Finance.amount(money, CurrencyDenomination.Value.SILVER)
	_check(map.select_floor_item(piles[0]), "the silver pile selected")
	var said: int = session.shared_ui().log_lines().size()
	var outcome: FloorItemPickup.Outcome = map.take_selected_floor_item()
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(outcome == FloorItemPickup.Outcome.TAKEN_PART and Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver + 50, "too heavy as a whole: the 50 that fit are taken")
	_check(lines == (["你捡起五十两银子。", "一百四十两银子对你而言太重了。"] as Array[String]), "what was taken and what stays: " + str(lines))
	_check(map.floor_item_view(piles[0]) != null and session.stack_collection().stack_state(piles[0]).amount == 140, "140 taels still lie there")
	_check(map.take_selected_floor_item() == FloorItemPickup.Outcome.TOO_HEAVY, "with no room left, nothing more")
	_unballast(money)
	_check(map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN and Finance.amount(money, CurrencyDenomination.Value.SILVER) == silver + 190 and map.floor_item_view(piles[0]) == null, "then the rest")
	var coins: int = Finance.amount(money, CurrencyDenomination.Value.COIN)
	_check(map.select_floor_item(piles[1]) and map.take_selected_floor_item() == FloorItemPickup.Outcome.TAKEN and Finance.amount(money, CurrencyDenomination.Value.COIN) == coins + 31, "and the coins")
	await tree.physics_frame


## TEST-ONLY: takes Finance.ballast() off the player.
func _unballast(money: MoneyInventoryContext) -> void:
	var removal: ItemLifecycleResult = ItemLifecycleService.destroy_item(money.inventory, money.stacks, &"ballast", ItemLifecycleResult.ChildDisposition.REQUIRE_LEAF, money.owner)
	_check(removal.succeeded and money.index.forget_destroyed_snapshots(removal.removed_instance_ids, money.inventory), "ballast removed")


func _npc(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _add_item(session: OldPineWorldSessionController, id: StringName, definition_id: StringName) -> void:
	var context: MoneyInventoryContext = Finance.session_context(session)
	var content: ItemContentDefinition = GameContent.catalog().item(definition_id)
	var item: ItemInstance = ItemInstance.new(id, definition_id)
	_check(context.inventory.register_item(item, content.own_weight) and context.index.register_snapshot(item) and context.inventory._apply_reparent(id, context.endpoint()), "test item %s" % id)


func _carried(session: OldPineWorldSessionController, definition_id: StringName) -> StringName:
	for id: StringName in _carried_ids(session):
		if session.item_instance_index().resolve(id).item_definition_id == definition_id:
			return id
	return &""


func _carried_ids(session: OldPineWorldSessionController) -> Array[StringName]:
	return session.inventory_state().direct_children(ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id))


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append("cloud casino: " + label)
