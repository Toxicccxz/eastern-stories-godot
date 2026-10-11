class_name WorldMapDebts
extends RefCounted
## The thieves NPCs of this map caught and how they square it (NpcSettle: d/village/npc/
## meloner.c do_return(), return melon cost). The NPC who caught the player and the player
## both hold its set_temp() flag (melonfarm.c's pick: WorldMapActs' npc_flag and set_temp);
## while it stands where the player stands, the player may pay it off, on the HUD or in the
## fight (CombatSettleTacticalPolicy). Paid, it says its line, both flags go and it goes home;
## short of money, buy.c's line and nothing else (the fight goes on).

var _map: WorldMapController
## What the last settle() printed.
var last_lines: Array[String] = []

var _player: WorldPlayerRuntimeState:
	get: return _map.player_runtime()


func _init(controller: WorldMapController) -> void:
	_map = controller


## Whether the player can square it with `npc` now: it caught them (both hold its flag), it
## stands where they stand and both are awake (do_return() is its add_action(), there for one
## in its room; command() from one lying unconscious says nothing).
func can_settle(npc: NpcRuntimeState) -> bool:
	var settle: NpcSettle = null if npc == null else npc.definition().dealings().settle
	return (
		settle != null and _player != null and int(_player.temp_marks.get(settle.temp, 0)) != 0
		and npc.has_flag(StringName(settle.temp)) and npc.exists_in_map
		and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
		and _map.npc_life.player_shares_zone(npc)
	)


## The NPC of `definition_id` the player can square it with now, or null.
func creditor(definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in _map.npcs.residents:
		if npc.definition().definition_id == definition_id and can_settle(npc):
			return npc
	return null


## do_return(): pays `npc` its price as buying from it is paid (buy.c can_afford(),
## pay_money()); paid, its say, both flags go and it is home at once (move(): it is no longer
## where the player is; its body walks there, without a word). True when it was settled;
## last_lines holds what was printed either way.
func settle(npc: NpcRuntimeState) -> bool:
	last_lines = []
	if not can_settle(npc):
		return false
	var terms: NpcSettle = npc.definition().dealings().settle
	var player: WorldPlayerRuntimeState = _player
	var context := MoneyInventoryContext.new(ItemLifecycleOwnerContext.new(player.character_id, player.state.equipment, player.armor), _map.inventory_state(), _map.stack_collection(), _map.item_instance_index())
	var price: int = terms.price(GameContent.catalog())
	var afford: MoneyAffordabilityResult = MoneyPaymentService.can_afford(context, price)
	if afford.outcome != MoneyAffordabilityResult.Outcome.AFFORDABLE:
		# buy.c: can_afford() 0 and 2.
		last_lines.append(tr("你没有足够的零钱，而对方也找不开...。") if afford.outcome == MoneyAffordabilityResult.Outcome.DENOMINATION_REJECTED else tr("你的钱不够。"))
		return false
	if not MoneyPaymentService.pay(context, price).succeeded():
		last_lines.append(tr("交易未完成，状态异常；已发生的扣款不会退回。"))
		return false
	# TRANSLATORS: an NPC's say() out of a fight: {npc} its name, {line} what it says.
	last_lines.append(tr("{npc}说道：{line}").format({"npc": tr(npc.definition().display_name), "line": NpcTalk.line(terms.say)}))
	npc.clear_flag(StringName(terms.temp))
	player.temp_marks.erase(terms.temp)
	return true


## After a settle() out of a fight: it goes home (in a fight the fight walks it out).
func send_home(npc: NpcRuntimeState) -> void:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(npc.spawn_id)
	if spawn != null and spawn.zone_id != npc.world_location().zone_id:
		_map.npc_life.walk_out(npc.character_id, spawn.zone_id)


## The HUD's button: settle() with `npc`, its lines in the log, home it goes when paid.
func settle_here(npc: NpcRuntimeState) -> bool:
	var settled: bool = settle(npc)
	if settled:
		send_home(npc)
	if _map.hud() != null and not last_lines.is_empty():
		_map.hud().append_log_lines(last_lines)
		if _map.hud().inventory_is_open():
			_map.hud().show_inventory(_map.session.player_inventory_rows())
	return settled
