extends RefCounted

## TEST-ONLY (DECISIONS「势力线的仗」): a story suite's fight fought with real numbers — the player
## grown to a story arrival's combat_exp (grown_character.gd, the sword build with a sword in hand),
## the foe as the data makes it, the fight run through the real coordinator and scheduler until it is
## over, the player choosing each beat as MainlineFightSim's plain policy does (the move with the best
## expected damage per beat, never 守; the game's turns, not 自动 — the numbers are tuned for it). No foe's 气 lowered, no
## player made unbeatable: a suite that walks a line from its first order to its end meets the
## fight a player meets.

const Grown := preload("res://tests/support/grown_character.gd")
const Finance := preload("res://tests/runtime/snow_finance_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")

## Scheduler steps (a second of the fight's clock each) before a fight is called stuck.
const MAX_STEPS: int = 3000


## The player grown to `experience` (the sword build, whole), `weapon` in hand (none: bare-handed),
## the fights' random source seeded.
static func ready_player(session: WorldSessionController, experience: int, weapon: StringName = &"es2:obj/longsword", seed: int = 7) -> void:
	var state: CharacterState = session.player_runtime().state
	Grown.grow(state, experience, 50, not weapon.is_empty())
	Grown.heal(state)
	session.configure_combat_random_source(Specials.Seeded.new(seed))
	if weapon.is_empty():
		return
	var context: MoneyInventoryContext = Finance.session_context(session)
	var item := ItemInstance.new(StringName("test:real_fight:%d" % Time.get_ticks_usec()), weapon)
	context.inventory.register_item(item, GameContent.catalog().item(weapon).own_weight)
	context.index.register_snapshot(item)
	context.inventory._apply_reparent(item.item_instance_id, context.endpoint())
	OldPineEquipmentInteractionAdapter.new().wield(session.player_runtime(), item.item_instance_id, session._inventory, session._item_index)


## The fight under way run to its end on the scheduler's clock, each foe held down 放过 (or 了结 with
## `finish`, where the story lets it); the steps it took, MAX_STEPS when it did not end.
static func fight_out(session: WorldSessionController, finish: bool = false) -> int:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var manual: bool = BattlePace.manual_turns
	BattlePace.manual_turns = true
	var steps: int = 0
	while coordinator.has_active_encounter() and steps < MAX_STEPS:
		for victim: StringName in coordinator.held_victims():
			if not finish or not coordinator.finish_downed(victim):
				coordinator.spare_downed(victim)
		if coordinator.waiting_for_player():
			_order(coordinator)
		coordinator.advance_scheduler(1.0)
		steps += 1
	BattlePace.manual_turns = manual
	session.shared_ui().dismiss_current_panel()
	return steps


## MainlineFightSim's plain policy for this beat, at the target the fight gave the player.
static func _order(coordinator: CombatEncounterCoordinator) -> void:
	var unaffordable: Dictionary[StringName, String] = coordinator.unaffordable_moves()
	var locked: Dictionary[StringName, String] = coordinator.locked_moves()
	var rules: CombatPowerRules = GameContent.catalog().pacing().combat_rules()
	var moves: Array[CombatActionDefinition] = []
	for move: CombatActionDefinition in coordinator.player_moves():
		if move.tag != CombatMoveTags.GUARD and not unaffordable.has(move.action_id) and not locked.has(move.action_id):
			moves.append(move)
	moves.sort_custom(func(a: CombatActionDefinition, b: CombatActionDefinition) -> bool: return MainlineFightSim._per_beat(a, coordinator, rules) > MainlineFightSim._per_beat(b, coordinator, rules))
	for move: CombatActionDefinition in moves:
		if coordinator.choose_attack(move.action_id):
			return
	coordinator.yield_round()


## The player still standing (not fallen, not dead) once a fight is over.
static func player_stands(session: WorldSessionController) -> bool:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE and player.state.vitality.current > 0
