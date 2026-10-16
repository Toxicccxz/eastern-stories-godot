extends RefCounted

## 现代化修正 III B「手感」(DECISIONS「手感」): pacing.json's feel knobs change only how a
## thing shows. The view fades round a walked passage under a world-time hold and names
## the place; the walk eases in and out on a round body that slides; the camera keeps
## inside the map; a ring and a prompt mark what A goes to; NPCs' lines show over their
## heads. Suites run with the feel off (TestFeel); this one turns it on.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const GANGSTER: StringName = &"cloud.npc.gangster"
const TOLL_SHOUT: String = "强盗喝道：呔！此山是我开，此树乃我栽。要想从此过，留下 买路财！"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_camera_limits()
	await _test_body(tree)
	TestFeel.use()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_passage(tree, session)
	await _test_toll_bubble(tree, session)
	session.free()
	TestFeel.restore()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var feel: FeelDefinition = TestFeel.production
	_check(
		[feel.map_fade_out_seconds, feel.map_fade_in_seconds, feel.map_banner_seconds, feel.camera_follow_speed, feel.move_accel_seconds, feel.move_stop_seconds, feel.menu_fade_seconds] == [0.15, 0.2, 1.6, 6.0, 0.08, 0.06, 0.12],
		"pacing.json: 0.15 s dark, 0.2 s back, a 1.6 s banner, camera 6, 0.08 s to full speed, 0.06 s to a stop, the menu in 0.12 s",
	)
	_check(is_equal_approx(feel.bubble_seconds("短句"), 2.5) and is_equal_approx(feel.bubble_seconds("字".repeat(34)), 2.5 + 10 * 0.06), "a bubble 2.5 s, 0.06 s more a character past 24")
	var none: FeelDefinition = FeelDefinition.new()
	_check(none.map_fade_out_seconds == 0.0 and none.bubble_seconds("x") == 0.0 and none.camera_follow_speed == 0.0, "left out: 0, the old look (no fade, no bubble, camera stuck)")
	var errors: Array[String] = []
	PacingDefinition.from_record(ContentRecordReader.new({"combat_round_ms": 1000, "feel": {"map_fade_in_ms": -1, "bubbles": 1}}, "pacing", errors))
	_check(errors.size() == 2, "a negative time and an unknown knob are refused: %s" % [errors])


func _test_camera_limits() -> void:
	var small: Rect2 = WorldMapController.camera_limits(Rect2(0, 0, 320, 256), Vector2(1152, 648))
	_check(small == Rect2(-416, -196, 1152, 648), "a map smaller than the view sits in its middle: %s" % [small])
	var wide: Rect2 = WorldMapController.camera_limits(Rect2(0, 0, 3000, 400), Vector2(1152, 648))
	_check(wide == Rect2(0, -124, 3000, 648), "wider than the view: its own edges that way, centred the other: %s" % [wide])


func _test_body(tree: SceneTree) -> void:
	var body: WorldNpcBody2D = (load("res://scenes/world/common/world_npc_body.tscn") as PackedScene).instantiate()
	tree.root.add_child(body)
	var circle: CircleShape2D = (body.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_check(circle != null and circle.radius == 17.0 and body.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "a round body as wide as the square, sliding top-down")
	body._turn_to(Vector2(1.0, 0.1))
	var east: Vector2 = body.facing
	body._turn_to(Vector2(-1.0, 0.9))
	_check(east.is_equal_approx(Vector2.RIGHT) and body.facing.is_equal_approx(Vector2(-1.0, 1.0).normalized()), "it faces the way it went, one of eight: %s" % [body.facing])
	TestFeel.use()
	var step: float = 1.0 / 60.0
	var speeds: Array[int] = []
	for _frame: int in 5:
		body.velocity = body._eased_velocity(Vector2(220.0, 0.0), step)
		speeds.append(roundi(body.velocity.x))
	var stops: int = 0
	while body.velocity != Vector2.ZERO and stops < 10:
		body.velocity = body._eased_velocity(Vector2.ZERO, step)
		stops += 1
	_check(speeds == [46, 92, 138, 183, 220] and stops == 4, "full speed in 0.08 s, a stop in 0.06 s: %s, %d frames" % [speeds, stops])
	TestFeel.restore()
	body.velocity = Vector2.ZERO
	_check(body._eased_velocity(Vector2(220.0, 0.0), step) == Vector2(220.0, 0.0), "the feel off: full speed at once")
	body.free()
	await tree.process_frame


## The view goes dark, the map changes once it is, comes back with the place's name;
## world time and the walk hold meanwhile.
func _test_passage(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var portal: PortalDefinition = null
	var area: WorldPassageArea2D = null
	for candidate: PortalDefinition in GameContent.catalog().portals_for_map(map.map_id()):
		if candidate.destination_map_id == candidate.source_map_id:
			continue
		for node: Node in map.find_children("*", "WorldPassageArea2D", true, false):
			if (node as WorldPassageArea2D)._portal == candidate:
				portal = candidate
				area = node
		if portal != null:
			break
	if not _check(portal != null, "a passage to another map on %s" % map.map_id()):
		return
	player.set_world_location(map.location_for_zone(portal.source_zone_id))
	map.player_body.global_position = area.global_position # TEST-ONLY: standing in the passage
	await tree.physics_frame
	var overlay: WorldViewOverlay = session.shared_ui().view_overlay
	map.passage_requested.emit(portal)
	await tree.process_frame
	_check(session.active_map() == map and session.world_time_held() and map.player_body.walk_paused, "first the view darkens: the same map, world time held, the player standing")
	await tree.create_timer(0.1).timeout
	_check(overlay.shade_alpha() > 0.3 and session.active_map() == map, "going dark: %.2f" % overlay.shade_alpha())
	await tree.create_timer(0.1).timeout
	var arrived: WorldMapController = session.active_map() as WorldMapController
	_check(arrived.map_id() == portal.destination_map_id and session.world_time_held(), "dark: the new map, world time still held while the view comes back")
	await tree.create_timer(0.3).timeout
	var region: String = GameContent.catalog().region(player.world_location().region_id).display_name
	_check(overlay.banner_text().begins_with(region) or overlay.banner_text() == GameContent.catalog().zone(player.world_location().zone_id).display_name, "the place's name: %s" % overlay.banner_text())
	_check(overlay.shade_alpha() == 0.0 and not session.world_time_held() and not arrived.player_body.walk_paused and not map.player_body.walk_paused, "back: world time runs, the player walks")


## The robber's shout: over his head in red, after the ridge's description in the log; the
## ring and the prompt on him.
func _test_toll_bubble(tree: SceneTree, session: WorldSessionController) -> void:
	session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad.snow_entry")
	await tree.create_timer(0.3).timeout
	var map: WorldMapController = session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var robber: NpcRuntimeState = null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == GANGSTER and npc.exists_in_map:
			robber = npc
			break
	if not _check(robber != null, "a robber on the ridge"):
		return
	var said: int = hud.log_lines().size()
	map.player_body.global_position = map.runtime_body_for_character(robber.character_id).global_position + Vector2(0, 60) # TEST-ONLY: in his reach
	session.player_runtime().set_world_location(map.location_for_zone(&"cloud.dragonhill.hummock"))
	await tree.physics_frame
	await tree.physics_frame
	map._process(0.05)
	var lines: Array[String] = hud.log_lines().slice(said)
	var shout: int = lines.find(TOLL_SHOUT)
	_check(shout > 0 and lines.slice(0, shout).any(func(line: String) -> bool: return line.begins_with("【")), "the ridge's description, then the shout: %s" % [lines])
	_check(hud.speech_bubbles.text_of(robber.character_id) == "呔！此山是我开，此树乃我栽。要想从此过，留下 买路财！", "over his head, without his name: %s" % hud.speech_bubbles.text_of(robber.character_id))
	hud.focus_marker._process(0.2)
	var focus: WorldFocus = hud.focus_marker.focus()
	_check(focus != null and focus.thing != null and focus.thing.id == robber.character_id and hud.focus_marker.prompt_text() == robber.short_name(), "the ring and prompt on him: %s" % hud.focus_marker.prompt_text())
	_check(WorldSpeechBubbles.bubble_text("店小二懒洋洋地打了个哈欠。") == "店小二懒洋洋地打了个哈欠。" and WorldSpeechBubbles.bubble_text("店小二说道：客官里边请。") == "客官里边请。", "a said line loses its speaker; something done keeps it")
	TestFeel.restore()
	hud.npc_bubble(robber, ["强盗喝道：站住！"])
	_check(hud.speech_bubbles.text_of(robber.character_id) != "站住！", "the feel off: no new bubble")
	TestFeel.use()
	map.player_body.global_position = map.physical_zone(&"cloud.dragonhill.nroad").global_rect().get_center()
	session.player_runtime().set_world_location(map.location_for_zone(&"cloud.dragonhill.nroad"))
	await tree.physics_frame


func _check(condition: bool, message: String) -> bool:
	_count += 1
	if not condition:
		_failures.append(message)
	return condition
