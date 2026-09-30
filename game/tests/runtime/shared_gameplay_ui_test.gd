extends RefCounted

var assertions: int = 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)

func run_all(tree: SceneTree) -> Dictionary:
	var session: OldPineWorldSessionController = load("res://scenes/world/oldpine/oldpine_world_session.tscn").instantiate()
	check(session.configure_source_entry("Shared UI", CharacterState.GENDER_FEMALE), "source setup")
	tree.root.add_child(session)
	await tree.process_frame
	await tree.process_frame
	check(session.is_initialized(), "public session initialized")
	var ui: SharedGameplayUI = session.shared_ui()
	check(ui != null and ui.visible and ui.get_parent() == session, "one session HUD visible at Inn")
	check(not ui._presentation_layout.frame.visible, "clean exploration by default")
	check(session.player_inventory_rows().size() == 1, "source cloth represented in inventory")
	ui.open_character()
	check(ui._presentation_layout.frame.visible and ExplorationPresentationBlocker.is_blocked(tree), "character shares blocking frame")
	check(not tree.paused and session.world_simulation_gate().is_open(), "panel does not pause simulation")
	ui._presentation_layout.close_panel()
	await tree.process_frame
	check(not ui._presentation_layout.frame.visible, "explicit close stays closed")
	ui.open_inventory()
	check(ui.inventory_rows().size() == 1, "shared inventory uses same player")
	ui._presentation_layout.close_panel()
	var before: int = ui.get_instance_id()
	var moved := session.handoff_to(SnowWorldDefinitions.OUTDOOR_MAP_ID, &"snow.square", &"snow.square", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID)
	check(moved.succeeded(), "typed map handoff")
	await tree.process_frame
	check(session.shared_ui().get_instance_id() == before and ui.visible, "Snow retains exact UI")
	check(not session.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID).is_inside_tree(), "Outdoor is inactive during Snow inventory use")
	var id: StringName = session.player_inventory_rows()[0].item_instance_id
	check(session.player_runtime().armor.is_worn(id), "cloth initially worn")
	session.remove_player_item(id)
	check(not session.player_runtime().armor.is_worn(id), "Snow removes cloth through Session service")
	session.wear_player_item(id)
	check(session.player_runtime().armor.is_worn(id), "Snow wears same cloth through Session service")
	check(session.player_inventory_rows()[0].item_instance_id == id, "stable held ID")
	for cycle: int in 3:
		ui.open_character()
		var cave := session.handoff_to(OldPineWorldDefinitions.CAVE_MAP_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID, OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID)
		check(cave.succeeded(), "Cave handoff")
		await tree.process_frame
		check(session.shared_ui() == ui and ui.visible and not ui._presentation_layout.frame.visible and ui.context_title().is_empty(), "Cave retains UI, clears old context/panel")
		check(session.handoff_to(SnowWorldDefinitions.OUTDOOR_MAP_ID, &"snow.square", &"snow.square", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID).succeeded(), "return Snow")
		await tree.process_frame
		check(ui.inventory_button.pressed.get_connections().size() == 1, "no repeated action subscription")
	ui.append_log_lines(["one"])
	for index: int in 70: ui.append_log_lines([str(index)])
	check(ui.log_lines().size() == SharedGameplayUI.MAX_LOG_LINES, "bounded presentation log")
	session.queue_free()
	await tree.process_frame
	check(not is_instance_valid(ui), "Session disposal frees shared UI")
	return {"assertions": assertions, "failures": failures}
