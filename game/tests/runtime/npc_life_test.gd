extends RefCounted

## NPC 活起来 A (owner, 2026-11-06「按推荐，开工 A」; DECISIONS「街上的人会动」):
## - data: every 雪亭镇 person has an npc_life.json entry; the file's entries parse; a bad one
##   is refused; pacing's npc_idle on.
## - on 雪亭镇's street with the player far off: a farmer (work) strolls about sroad2 and only
##   there, near its own spot, never into a doorway or the street's mouth, keeps its room; the
##   gate's 刘安禄 (post) never leaves his spot but looks about; the player walks up: the farmer
##   stops and turns to them; npc_idle off: nobody moves.

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
## No entry: they never stir (statues, one frozen in ice).
const NOT_STIRRING: Array[StringName] = [&"latemoon.npc.room.fireangel", &"latemoon.npc.upstar.statue", &"native.npc.lihong"]
const FARMER: StringName = &"snow.sroad2.farmer.1.character"
const GUARD: StringName = &"snow.school1.guard.1.character"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	await _test_person(tree)
	var session: WorldSessionController = Work.create_session(tree)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or changes room
	await _test_street(tree, session)
	session.free()
	await tree.process_frame
	_test_night_list()
	session = Work.create_session(tree)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or changes room
	await _test_night(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# Everyone has an entry (B: every region), but those who walk their own way (a patrol, a
	# night watch) and those who never stir (the training dummies, the two spirit statues, 璃虹
	# in her ice pillar).
	var missing: Array[StringName] = []
	for definition: NpcDefinition in catalog.npcs():
		var id: StringName = NpcDefinition.unnamed_id(definition.definition_id)
		if definition.dealings().patrol != null or definition.dealings().watch != null or NOT_STIRRING.has(id) or String(id).begins_with("native.npc.wooden_dummy."):
			_check(NpcLifeBook.entry(id) == null or definition.dealings().patrol == null, "%s keeps its own walk" % id)
			continue
		if NpcLifeBook.entry(id) == null and not missing.has(id):
			missing.append(id)
	_check(missing.is_empty(), "everyone has a life entry (missing %s)" % [missing])
	for id: StringName in NOT_STIRRING:
		_check(NpcLifeBook.entry(id) == null, "%s never stirs" % id)
	_check(NpcLifeBook.entry(&"native.npc.wooden_dummy.1") == null, "a training dummy never stirs")
	_check(NpcLifeBook.entry(&"waterfog.npc.servant").gesture == "chop" and NpcLifeBook.entry(&"temple.npc.guard_taoist1").mode == NpcLifeBook.Mode.POST and NpcLifeBook.entry(&"native.npc.storyteller").pose == "sit_ground", "a few by hand: 柴房's servant chops, 藏经楼's guards keep their post, the old storyteller sits on his felt")
	_check(NpcLifeBook.entry(&"snow.npc.guard").mode == NpcLifeBook.Mode.POST, "the gate's 刘安禄 keeps his post")
	_check(NpcLifeBook.entry(&"snow.npc.herbalist").mode == NpcLifeBook.Mode.STILL, "杨掌柜 stays at his counter")
	_check(NpcLifeBook.entry(&"snow.npc.traveller").mode == NpcLifeBook.Mode.WANDER, "a traveller wanders")
	var smith: NpcLifeBook.Entry = NpcLifeBook.entry(&"snow.npc.smith")
	_check(smith.mode == NpcLifeBook.Mode.WORK and smith.reach(120) == 32 and smith.gesture == "hammer", "王铁匠 hammers by his forge (32 px)")
	_check(NpcLifeBook.entry(&"snow.npc.beggar").pose == "sit_ground", "the beggar sits on the ground")
	for gesture: String in NpcLifeBook.GESTURES:
		_check(Person.GESTURE_SECONDS.has(gesture), "the voxel person plays %s" % gesture)
	_check(NpcLifeBook.parse("work").reach(120) == NpcLifeBook.WORK_RADIUS_PX and NpcLifeBook.parse("wander").reach(120) == 120, "a work entry stays nearer its spot than a wanderer")
	for bad: Variant in ["dance", {"mode": "wander", "radius": -4}, {"mode": "wander", "pace": 3}, 7, {"mode": "post", "gesture": "hoe"}, {"mode": "wander", "pose": "sit"}, {"mode": "work", "gesture": "juggle"}, {"mode": "still", "pose": "lie_down"}]:
		var problem: Array[String] = []
		_check(NpcLifeBook.parse(bad, problem) == null and not problem.is_empty(), "refused: %s" % [bad])
	_check(NpcLifeBook.entry(&"nobody") == null and NpcLifeBook.entry(&"oldpine.npc.nobody") == null, "no entry: stays put")
	var pacing: PacingDefinition = catalog.pacing()
	_check(pacing.npc_idle.enabled and pacing.npc_idle.speed_px > 0 and pacing.npc_idle.stop_reach_px > 0, "people move about (pacing npc_idle on)")
	_check(not PacingDefinition.new(1000).npc_idle.enabled, "left out (ES2): they stand where they were put")
	_check(pacing.copy().npc_idle == pacing.npc_idle, "a copy of the pacing keeps its npc_idle")


## The voxel person: a gesture's tool in an empty hand (not over the look's own), the arms at
## work and still while it attends to the player; a stool under one that sits, gone as it walks.
func _test_person(tree: SceneTree) -> void:
	var smith: Person = Person.new()
	smith.configure({"coat": "5a4a3a"})
	smith.activity("hammer", "stand")
	tree.root.add_child(smith)
	_check(smith.drawn.has("prop:hammer"), "a smith at work holds a hammer")
	var lifted: bool = false
	for frame: int in 40:
		smith._process(0.05)
		lifted = lifted or smith.arms[0].rotation.x < -1.5
	_check(lifted, "the hammer goes up and down")
	smith.working = false
	smith._process(0.05)
	_check(smith.arms[0].rotation.x > -0.2, "attending to the player, the smith puts the hammer down")
	smith.free()
	var carrier: Person = Person.new()
	carrier.configure({"prop": "staff"})
	carrier.activity("hoe", "stand")
	tree.root.add_child(carrier)
	_check(carrier.drawn.has("prop:staff") and not carrier.drawn.has("prop:hoe"), "a look's own prop in the hand stays, no tool")
	carrier.free()
	var gardener: Person = Person.new()
	gardener.configure({"prop": "sword_waist"})
	gardener.activity("hoe", "stand")
	tree.root.add_child(gardener)
	_check(gardener.drawn.has("prop:sword_waist") and gardener.drawn.has("prop:hoe"), "a sword at the waist leaves the hand free for the hoe")
	gardener.at_ease = false
	gardener._process(0.05)
	_check(gardener.arms[0].rotation.x > -0.2, "fighting or senseless, nobody works")
	gardener.free()
	var sitter: Person = Person.new()
	sitter.configure({})
	sitter.activity("", "sit")
	tree.root.add_child(sitter)
	sitter._process(0.05)
	_check(sitter.drawn.has("pose:sit") and sitter._seat != null and sitter._seat.visible and sitter.legs[0].rotation.x < -1.0 and sitter.torso.position.y < -0.1, "one that sits sits low on a stool, legs forward")
	sitter.walking = true
	sitter._process(0.05)
	_check(not sitter._seat.visible and sitter.torso.position.y > -0.1, "walking, it stands up and leaves the stool")
	sitter.walking = false
	sitter.at_ease = false
	sitter._process(0.05)
	_check(not sitter._seat.visible and sitter.torso.position.y > -0.1 and absf(sitter.legs[0].rotation.x) < 0.01, "knocked senseless, it lies as anyone does (no stool, legs straight)")
	sitter.free()


func _test_street(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.square")
	_check(map != null and map.map_id() == &"snow.outdoor", "out on the street (the square)")
	if map == null:
		return
	var farmer: NpcRuntimeState = map.find_resident_npc(FARMER)
	var guard: NpcRuntimeState = map.find_resident_npc(GUARD)
	_check(farmer != null and guard != null, "the farmer and 刘安禄 are out")
	if farmer == null or guard == null:
		return
	var farmer_body: WorldCharacterBody2D = map.runtime_body_for_character(FARMER)
	var guard_body: WorldCharacterBody2D = map.runtime_body_for_character(GUARD)
	var home: Vector2 = farmer_body.global_position
	var post: Vector2 = guard_body.global_position
	var post_facing: Vector2 = guard_body.facing
	var tuning: NpcIdleTuning = GameContent.catalog().pacing().npc_idle
	var reach: float = float(NpcLifeBook.entry(&"snow.npc.farmer").reach(tuning.home_radius_px))
	var sroad2: Rect2 = MapPlaces.zone_rect(map, &"snow.sroad2")
	var farthest: float = 0.0
	var strolled: bool = false
	var guard_still: bool = true
	var guard_looked: bool = false
	var dog: NpcRuntimeState = map.find_resident_npc(&"snow.sroad4.crazy_dog.1.character")
	var dog_body: WorldCharacterBody2D = null if dog == null else map.runtime_body_for_character(dog.character_id)
	var dog_spot: Vector2 = Vector2.INF if dog_body == null else dog_body.global_position
	var dog_facing: Vector2 = Vector2.ZERO if dog_body == null else dog_body.facing
	var dog_still: bool = dog_body != null
	var dog_looked: bool = false
	var in_room: bool = true
	var near_home: bool = true
	var on_spots: bool = true
	var froze_in_place: bool = false
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(farmer.spawn_point_id)
	_check(marker != null and home.distance_to(marker.global_position) < 1.0, "the farmer starts on its spawn marker")
	for second: int in 90:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
		strolled = strolled or map.npc_life.npc_walker().is_strolling(FARMER)
		farthest = maxf(farthest, farmer_body.global_position.distance_to(home))
		in_room = in_room and farmer.world_location().zone_id == &"snow.sroad2" and sroad2.has_point(farmer_body.global_position)
		near_home = near_home and farmer_body.global_position.distance_to(home) <= reach + WorldNpcWalker.CELL
		guard_still = guard_still and guard_body.global_position.distance_to(post) < 1.0
		guard_looked = guard_looked or not guard_body.facing.is_equal_approx(post_facing)
		if dog_body != null:
			dog_still = dog_still and dog_body.global_position.distance_to(dog_spot) < 1.0
			dog_looked = dog_looked or not dog_body.facing.is_equal_approx(dog_facing)
		# Wherever a stroll is stopped, the body may stand there (and a save keep it).
		on_spots = on_spots and _off_seams(map, farmer_body.global_position, &"snow.sroad2") and MapPlacementValidator.is_valid_character_position(map, &"snow.sroad2", farmer_body.global_position)
		if not froze_in_place and second > 40 and map.npc_life.npc_walker().is_strolling(FARMER):
			# A fight begins (freeze_world_gameplay finishes the walks): a stroll stops where it is.
			var at: Vector2 = farmer_body.global_position
			map.npc_life.npc_walker().finish_all()
			froze_in_place = farmer_body.global_position.distance_to(at) < 0.5 and not map.npc_life.npc_walker().is_walking(FARMER)
	_check(strolled and farthest > float(tuning.stroll_min_px) * 0.5, "the farmer strolls about (%.0f px at most)" % farthest)
	_check(in_room, "the farmer stays in sroad2")
	_check(near_home, "the farmer stays near its own spot (%.0f px)" % reach)
	_check(on_spots, "every spot of the farmer's strolls is off the street's mouths and free")
	_check(froze_in_place, "a stroll stopped by finish_all() stays where it is (no jump)")
	_check(guard_still and guard_looked, "刘安禄 keeps his spot and looks about")
	_check(dog_still and dog_looked, "疯狗 attacks on sight: it keeps its spot (the new player's road stays as ES2 put it) and looks about")
	# The player leaves the map: a post faces its own way again; home stays the marker.
	map.npc_idle.clear()
	_check(guard_body.facing.is_equal_approx(post_facing), "刘安禄 faces his own way again when the player is gone")
	# The player walks up to one under way: it finishes its few steps, then turns to them.
	map.npc_life.npc_walker().finish_all()
	var walker: WorldNpcWalker = map.npc_life.npc_walker()
	var started: bool = walker.stroll(FARMER, farmer_body, map.physical_zone(&"snow.sroad2"), home, reach, 16.0, 140.0, 46.0, func() -> float: return 0.5)
	var ends: Vector2 = walker.rest_position(FARMER, farmer_body)
	map.player_body.global_position = MapPlaces.spot(map, &"snow.sroad2", farmer_body.global_position, float(tuning.stop_reach_px) - 8.0) # TEST-ONLY: beside the farmer as it sets off
	await tree.physics_frame
	for second: int in 12:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
	var to_player: Vector2 = (map.player_body.global_position - farmer_body.global_position).normalized()
	_check(started and farmer_body.global_position.distance_to(ends) < 1.0 and not walker.is_strolling(FARMER), "under way, the farmer finishes its steps (stopping half-way could block a narrow way)")
	_check(farmer_body.facing.dot(to_player) > 0.7, "then it turns to the player")
	map.player_body.global_position = MapPlaces.zone_centre(map, &"snow.square") # TEST-ONLY: away again
	await tree.physics_frame
	# The player walks up: the farmer stops and turns to them.
	map.npc_life.npc_walker().finish_all()
	var by: Vector2 = MapPlaces.spot(map, &"snow.sroad2", farmer_body.global_position, float(tuning.stop_reach_px) - 8.0)
	map.player_body.global_position = by # TEST-ONLY: set beside the farmer (the walk there is no part of it)
	await tree.physics_frame
	var stood: Vector2 = farmer_body.global_position
	var stayed: bool = true
	for second: int in 30:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
		stayed = stayed and not map.npc_life.npc_walker().is_strolling(FARMER) and farmer_body.global_position.distance_to(stood) < 1.0
	var toward: Vector2 = (map.player_body.global_position - farmer_body.global_position).normalized()
	_check(stood.distance_to(by) <= float(tuning.stop_reach_px), "the player stands within reach (%.0f px)" % stood.distance_to(by))
	_check(stayed and farmer_body.facing.dot(toward) > 0.7, "the farmer stops and turns to the player")
	# npc_idle off: nobody moves.
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	var kept: NpcIdleTuning = pacing.npc_idle
	pacing.npc_idle = NpcIdleTuning.new() # TEST-ONLY: the knob left out, put back below
	map.player_body.global_position = MapPlaces.zone_centre(map, &"snow.square") # TEST-ONLY: far off again
	# Strolls under way stop (the pacing is read before anyone strolls).
	map.npc_life.npc_walker().finish_all()
	await tree.physics_frame
	var places: Dictionary[StringName, Vector2] = {}
	for npc: NpcRuntimeState in map.npc_runtimes():
		places[npc.character_id] = map.runtime_body_for_character(npc.character_id).global_position
	for second: int in 40:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
	pacing.npc_idle = kept
	var moved: Array[StringName] = []
	for character_id: StringName in places:
		var body: Node2D = map.runtime_body_for_character(character_id)
		if body != null and body.global_position.distance_to(places[character_id]) > 1.0:
			moved.append(character_id)
	_check(moved.is_empty(), "npc_idle off: nobody moves (%s)" % [moved])


## Whether `point` keeps WorldNpcWalker.SEAM_CLEAR from where `zone_id` meets the map's other
## zones (the street's mouths).
func _off_seams(map: WorldMapController, point: Vector2, zone_id: StringName) -> bool:
	var own: Rect2 = MapPlaces.zone_rect(map, zone_id)
	for zone: WorldPhysicalZoneArea2D in map.physical_zones():
		if zone.zone_id != zone_id and zone.global_rect().grow(1.0).intersects(own) and zone.global_rect().grow(WorldNpcWalker.SEAM_CLEAR - 1.0).has_point(point):
			return false
	return true


## D (DECISIONS「夜里冷清」): those who go indoors at night are the street's idle folk only — none
## a player needs at night: no shop, no teacher, no foe or beast, an ordinary spawn, and named in no
## other data at all (a quest, an act, a hook, a family, a bounty: their own records aside).
func _test_night_list() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var pacing: PacingDefinition = catalog.pacing()
	_check(pacing.npc_idle.night_home and pacing.npc_idle.night_phases == [&"night", &"midnight"], "the street empties at 夜晚 and 午夜")
	_check(not PacingDefinition.new(1000).npc_idle.night_home, "left out (ES2): day and night alike")
	var records: Dictionary = {}
	var other_text: String = ""
	for path: String in _data_files("res://data"):
		var text: String = FileAccess.get_file_as_string(path)
		var name: String = path.get_file()
		if name == "npcs.json":
			var parsed: Variant = JSON.parse_string(text)
			if parsed is Dictionary:
				for record: Variant in (parsed as Dictionary).get("npcs", []):
					if record is Dictionary:
						records[String(record.get("id", ""))] = record
		elif not name in ["spawns.json", "appearances.json", "npc_life.json"] and not path.contains("/voxel/"):
			other_text += text
	var homers: Array[StringName] = []
	for definition: NpcDefinition in catalog.npcs():
		var id: StringName = NpcDefinition.unnamed_id(definition.definition_id)
		var entry: NpcLifeBook.Entry = NpcLifeBook.entry(id)
		if entry == null or not entry.night_home or homers.has(id):
			continue
		homers.append(id)
		var record: Dictionary = records.get(String(id), {})
		_check(not record.has("vendor") and definition.teaching() == null, "%s goes home at night: no shop, no teacher" % id)
		_check(definition.race_id != &"beast" and definition.attitude != NpcDefinition.Attitude.AGGRESSIVE and definition.attitude != NpcDefinition.Attitude.KILLER and not definition.dealings().takes_toll(), "%s goes home at night: no foe, no beast" % id)
		_check(not other_text.contains("\"%s\"" % id), "%s goes home at night: named in no quest, act, hook, family or bounty" % id)
		var ordinary: bool = false
		for spawn: NpcSpawnDefinition in catalog.spawns():
			if NpcDefinition.unnamed_id(spawn.npc_definition_id) == id:
				ordinary = not (spawn.staged or spawn.summoned or spawn.starts_absent or spawn.drawn)
		_check(ordinary, "%s goes home at night: an ordinary spawn" % id)
	_check(homers.size() >= 12 and homers.has(&"snow.npc.trav_blade") and not homers.has(&"snow.npc.beggar") and not homers.has(&"snow.npc.drunk"), "the street's idle folk go home (%d); the beggar and the drunk stay out" % homers.size())
	for bad: Variant in [{"mode": "still", "night": "home"}, {"mode": "wander", "night": "inn"}]:
		var problem: Array[String] = []
		_check(NpcLifeBook.parse(bad, problem) == null and not problem.is_empty(), "refused: %s" % [bad])


static func _data_files(root: String) -> Array[String]:
	var found: Array[String] = []
	for dir: String in DirAccess.get_directories_at(root):
		found.append_array(_data_files(root.path_join(dir)))
	for file: String in DirAccess.get_files_at(root):
		if file.ends_with(".json"):
			found.append(root.path_join(file))
	return found


## D on 雪亭镇's square: night falls with the player off to one side, a traveller in sight walks to
## a way out and is gone there, the others are gone; the farmer (named elsewhere) stays; come dawn
## they are back; a map the player comes onto at night is empty of them at once.
func _test_night(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = await MapPlaces.go_to(tree, session, &"snow.square")
	_check(map != null, "out on the square for the night")
	if map == null:
		return
	var travellers: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition().definition_id) == &"snow.npc.trav_blade" and npc.exists_in_map:
			travellers.append(npc)
	_check(travellers.size() >= 2, "travellers on the square (%d)" % travellers.size())
	if travellers.size() < 2:
		return
	var watched: NpcRuntimeState = travellers[0]
	var body: WorldCharacterBody2D = map.runtime_body_for_character(watched.character_id)
	var tuning: NpcIdleTuning = GameContent.catalog().pacing().npc_idle
	var stand: Vector2 = MapPlaces.spot(map, &"snow.square", body.global_position + Vector2(0, 150), 80.0)
	map.player_body.global_position = stand # TEST-ONLY: in sight of one traveller, not beside them
	await tree.physics_frame
	var farmer: NpcRuntimeState = map.find_resident_npc(FARMER)
	_check(session.wait_until_phase([&"night"]) and session.day_phase_id() == &"night", "night falls (%s)" % session.day_phase_id())
	map.player_body.global_position = stand # TEST-ONLY: the time skip set nobody aside
	await tree.physics_frame
	# The skip went by as for one who comes back: the street's idle folk are in already.
	var gone_at_once: bool = true
	for npc: NpcRuntimeState in travellers:
		gone_at_once = gone_at_once and not npc.exists_in_map
	_check(gone_at_once, "hours went by: the travellers are indoors already")
	_check(farmer != null and farmer.exists_in_map, "the farmer (named in a family) stays out")
	# Watched as night falls: back to dusk, then the night's ticks.
	session.wait_until_phase([&"dawn"])
	map.player_body.global_position = stand
	await tree.physics_frame
	_check(watched.exists_in_map, "dawn: the traveller is out again")
	var spot: Vector2 = map.resolve_spawn_marker(watched.spawn_point_id).global_position
	for step: int in 60:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
	var walker: WorldNpcWalker = map.npc_life.npc_walker()
	_check(watched.exists_in_map and not walker.is_walking(watched.character_id), "by day the traveller is about the square")
	var idle: WorldMapNpcIdle = map.npc_idle
	var tuned: NpcIdleTuning = tuning
	var phases: Array[StringName] = tuned.night_phases
	# On the way to a door, a scene takes it (a fight, a talk alike): it stays, and goes later.
	tuned.night_phases = [session.day_phase_id()] # TEST-ONLY: it is night now, without a time skip
	for step: int in 120:
		session.advance_npc_heartbeat(0.25)
		await tree.physics_frame
		if walker.is_walking(watched.character_id):
			break
	map.npc_life.scene_focus_id = watched.character_id # TEST-ONLY: a scene looks at it
	for step: int in 20:
		session.advance_npc_heartbeat(0.25)
		await tree.physics_frame
	_check(watched.exists_in_map and not idle._leaving.has(watched.character_id), "stopped on its way (a scene, a fight): it is not taken off the map")
	map.npc_life.scene_focus_id = &""
	walker.cancel(watched.character_id)
	body.global_position = spot # TEST-ONLY: back on its spot for the walk below
	await tree.physics_frame
	tuned.night_phases = phases
	# Night by the clock alone, the player looking on: the ticks do it.
	tuned.night_phases = [session.day_phase_id()] # TEST-ONLY: it is night now, without a time skip
	var walked: bool = false
	var start: Vector2 = body.global_position
	for step: int in 240:
		session.advance_npc_heartbeat(0.25)
		await tree.physics_frame
		walked = walked or walker.is_walking(watched.character_id)
		if not watched.exists_in_map:
			break
	var near_way: bool = false
	for way: Vector2 in idle._ways_out(body.global_position):
		near_way = near_way or way.distance_to(body.global_position) < 96.0
	_check(not watched.exists_in_map, "night: the traveller goes indoors")
	_check(walked and near_way and body.global_position.distance_to(start) > 32.0, "in sight, it walked to a way out first (%.0f px from where it stood)" % body.global_position.distance_to(start))
	# Coming onto a map at night: indoors at once.
	for npc: NpcRuntimeState in travellers:
		if not npc.exists_in_map:
			map.npcs.appear(npc, GameContent.catalog().spawn(npc.spawn_id)) # TEST-ONLY: out again, as if it were day
	idle.judge_night()
	var all_in: bool = true
	for npc: NpcRuntimeState in travellers:
		all_in = all_in and not npc.exists_in_map
	_check(all_in, "coming onto the map at night: the travellers are indoors at once")
	# Dawn with the player on its spot: it waits till they move on.
	tuned.night_phases = phases
	map.player_body.global_position = spot # TEST-ONLY: on the traveller's spot
	await tree.physics_frame
	for step: int in 12:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
	_check(not watched.exists_in_map, "dawn with the player on its spot: it does not come out on top of them")
	# Dawn in sight: out of a way out and back to the spot.
	map.player_body.global_position = MapPlaces.spot(map, &"snow.square", spot + Vector2(0, 120), 80.0) # TEST-ONLY: the spot in sight
	await tree.physics_frame
	var came_from: Vector2 = Vector2.INF
	for step: int in 240:
		session.advance_npc_heartbeat(0.25)
		await tree.physics_frame
		if watched.exists_in_map and not came_from.is_finite():
			came_from = body.global_position
		if watched.exists_in_map and not walker.is_walking(watched.character_id):
			break
	_check(watched.exists_in_map and body.global_position.distance_to(spot) < 2.0, "dawn in sight: back on its spot")
	_check(came_from.is_finite() and came_from.distance_to(spot) > 32.0, "it came out of a way out, not out of the air (%.0f px off)" % (came_from.distance_to(spot) if came_from.is_finite() else -1.0))
	# night_home off: nobody goes indoors.
	tuned.night_home = false # TEST-ONLY: the knob off; put back below
	tuned.night_phases = [session.day_phase_id()]
	for step: int in 20:
		session.advance_npc_heartbeat(0.5)
		await tree.physics_frame
	var stayed: bool = true
	for npc: NpcRuntimeState in travellers:
		stayed = stayed and npc.exists_in_map
	tuned.night_home = true
	tuned.night_phases = phases
	_check(stayed, "night_home off: nobody goes indoors")


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
