extends RefCounted

## Old Pine remainder A: the keep (keep1-3) with keep2.c's gate trap and 常老大's
## 竹管, the secret passage (secrectpath1, path3) up the stone and down into the
## caves (cave1-4 one fixed maze, cave5 with 南危水's bones and do_bury()), cliff2
## between cliffdown and epath3, and the NPCs that live there: 土匪喽罗, 土匪首领,
## 常老大 (apply/defense), 疯老头子 (berserk, three bolts), 狼狗, six 蝴蝶.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const GATE: StringName = &"oldpine.keep.gate"
const TRAP: StringName = &"oldpine.keep2.gate_trap"
const TRAP_GUARDS: StringName = &"oldpine.outdoor.keep2.trap_guards"
const YARD: StringName = &"oldpine.outdoor.keep_yard"
const HALL: StringName = &"oldpine.outdoor.keep_hall"
const WALL: StringName = &"oldpine.caves.landmark.wall"
const SKELETON: StringName = &"es2:d/oldpine/npc/skeleton"
const PARRYBOOK: StringName = &"es2:d/oldpine/npc/obj/parrybook"
const PIPE: StringName = &"es2:d/oldpine/obj/bamboo_pipe"
const NEW_ZONES: Dictionary[StringName, Array] = {
	&"oldpine.cave.secret_path": [&"oldpine.cave", ["secrectpath1"]],
	&"oldpine.cave.inner_path": [&"oldpine.cave", ["path3"]],
	&"oldpine.stone.top": [&"oldpine.stone", ["stone"]],
	&"oldpine.caves.maze": [&"oldpine.caves", ["cave1", "cave2", "cave3", "cave4"]],
	&"oldpine.caves.mouth": [&"oldpine.caves", ["cave5"]],
	&"oldpine.outdoor.keep_gate": [&"oldpine.outdoor", ["keep1"]],
	&"oldpine.outdoor.keep_yard": [&"oldpine.outdoor", ["keep2"]],
	&"oldpine.outdoor.keep_hall": [&"oldpine.outdoor", ["keep3"]],
	&"oldpine.cliff2.niche": [&"oldpine.cliff2", ["cliff2"]],
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	_test_record_rules()
	_test_bury_roll()
	_test_berserk_roll()
	_test_netherbolt()
	var session: OldPineWorldSessionController = Work.create_session(tree)
	await tree.process_frame
	_test_tiles(session)
	_test_new_world(session)
	var work: RefCounted = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "a new world with the trap's guards absent")
	_check(work._failures.is_empty(), "Save/Continue keeps absent summoned guards: " + str(work._failures))
	await _test_trap(tree, session)
	work = Work.new()
	await work.round_trip(tree, session, Work.capture(session), "the trap's guards in keep2")
	_check(work._failures.is_empty(), "Save/Continue keeps the guards that came: " + str(work._failures))
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	await tree.process_frame
	await _test_climbs(tree, session)
	await _test_bury(tree, session)
	session.free()
	await tree.process_frame
	session = Work.create_session(tree)
	await tree.process_frame
	await _test_maniac(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	for zone_id: StringName in NEW_ZONES:
		var zone: ZoneDefinition = catalog.zone(zone_id)
		var rooms: Array[StringName] = []
		for room: String in NEW_ZONES[zone_id][1]:
			rooms.append(StringName("es2:d/oldpine/" + room))
		_check(zone != null and zone.map_id == NEW_ZONES[zone_id][0] and zone.room_ids() == rooms, "%s holds %s on %s" % [zone_id, rooms, NEW_ZONES[zone_id][0]])
	var missing: Array[String] = []
	for room: String in ["cave1", "cave2", "cave3", "cave4", "cave5", "cliff2", "keep1", "keep2", "keep3", "secrectpath1"]:
		if catalog.room(StringName("es2:d/oldpine/" + room)) == null:
			missing.append(room)
	_check(missing.is_empty(), "the ten remaining Old Pine rooms are there: missing " + str(missing))
	_check(catalog.room(&"es2:d/oldpine/keep1").short == "老松寨秘密入口" and catalog.room(&"es2:d/oldpine/cave5").long.contains("石壁(wall)"), "room text verbatim")
	_check(catalog.zones_adjacent(&"oldpine.outdoor.pine_entrance", &"oldpine.outdoor.keep_gate") and catalog.zones_adjacent(&"oldpine.outdoor.keep_gate", YARD) and catalog.zones_adjacent(YARD, HALL), "pine2 east → keep1 → keep2 → keep3")
	_check(catalog.zones_adjacent(&"oldpine.cave.waterfall_passage", &"oldpine.cave.secret_path") and catalog.zones_adjacent(&"oldpine.cave.secret_path", &"oldpine.cave.inner_path"), "passage north → secrectpath1 → path3")
	_check(catalog.zones_adjacent(&"oldpine.caves.maze", &"oldpine.caves.mouth"), "the caves' fixed maze leads to cave5")
	var counts: Dictionary[StringName, int] = {}
	for spawn_id: StringName in [&"oldpine.outdoor.keep1.bandit_guards", &"oldpine.outdoor.keep2.bandit_guards", &"oldpine.outdoor.keep2.bandit_leader",
			&"oldpine.outdoor.keep3.bandit_leaders", &"oldpine.outdoor.keep3.bandit_commander", TRAP_GUARDS,
			&"oldpine.outdoor.epath3.maniac", &"oldpine.outdoor.pine7.wolf_dog", &"oldpine.tree.tree2.butterflys"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		counts[spawn_id] = 0 if spawn == null else spawn.quantity
	_check(counts.values() == [4, 2, 1, 3, 1, 5, 1, 1, 6], "keep1 four guards, keep2 two and a leader, keep3 three leaders and 常老大, five trap guards, the maniac, the wolf dog, six butterflies: %s" % counts)
	_check(catalog.spawn(TRAP_GUARDS).summoned and not catalog.spawn(&"oldpine.outdoor.keep2.bandit_guards").summoned, "only the trap's guards are summoned")
	var boss: NpcDefinition = catalog.npc(&"oldpine.npc.bandit_commander")
	_check(boss.authored_combat_facts().apply_value(&"defense") == 60 and boss.authored_combat_facts().apply_value(&"attack") == 100, "常老大: apply/attack 100, apply/defense 60")
	_check(boss.short_name() == "老松寨寨主「泼风刀王」常老大" and boss.bellicosity() == 6000, "常老大's title, nickname and bellicosity: " + boss.short_name())
	var maniac: NpcDefinition = catalog.npc(&"oldpine.npc.maniac")
	_check(maniac.bellicosity() == 10000 and maniac.score == 8000 and NpcBerserk.applies_to(maniac), "疯老头子: not aggressive, bellicosity 10000 over score 8000")
	_check(not NpcBerserk.applies_to(catalog.npc(&"oldpine.npc.bandit_guard")) and not NpcBerserk.applies_to(catalog.npc(&"oldpine.npc.butterfly")), "aggressive guards and peaceful butterflies never go berserk")
	_check(maniac.talk().combat_chat_chance == 60 and maniac.talk().combat_chat_entries().size() == 3, "疯老头子 casts in 60% of his fight beats")
	_check(catalog.skill(&"necromancy").cast_functions == [&"drainerbolt", &"feeblebolt", &"netherbolt"] and SpecialFunctions.cast(&"netherbolt") != null, "necromancy casts netherbolt too")
	var skeleton: ItemContentDefinition = catalog.item(SKELETON)
	_check(skeleton != null and skeleton.no_get and catalog.item_spawn(&"oldpine.caves.cave5.skeleton") != null, "a skeleton lies in cave5, not to be picked up")
	var book: ItemContentDefinition = catalog.item(PARRYBOOK)
	_check(book != null and book.study != null and book.study.skill_id == &"parry" and book.study.exp_required == 15000 and book.study.max_skill == 50, "过招要旨 teaches parry up to 50 from 15000 exp")
	_check(catalog.item(PIPE).play == &"pipe", "竹管 can be played")
	var gate: DoorDefinition = catalog.door(GATE)
	_check(gate.starts_open and not gate.operable and gate.map_id == &"oldpine.outdoor", "the keep's gate starts open; only its trap shuts it")
	var trap: RoomTrapDefinition = null
	for candidate: RoomTrapDefinition in catalog.traps():
		if candidate.trap_id == TRAP:
			trap = candidate
	_check(trap != null and trap.from_zone_id == YARD and trap.to_zone_id == HALL and trap.summon_spawn_id == TRAP_GUARDS and trap.opens_on == &"pipe", "keep2.c: leaving east shuts the gate; the pipe opens it")
	var wall: WorldLandmarkDefinition = catalog.landmark(WALL)
	_check(wall.policy == &"bury" and wall.item("buried") == SKELETON and wall.item("reward") == PARRYBOOK and wall.description.begins_with("老夫南危水"), "the wall tells to bury the bones; the bury landmark")


func _test_record_rules() -> void:
	var errors: Array[String] = []
	var record: Dictionary = {"id": "t", "room": "r", "door": "d", "from_zone": "a", "to_zone": "b", "messages": {"shout": "1", "shut": "2"}, "legacy_source": "s"}
	RoomTrapDefinition.from_record(ContentRecordReader.new(record, "test", errors))
	_check(not errors.is_empty(), "a trap needs shout, shut and open")
	errors.clear()
	record["messages"] = {"shout": "1", "shut": "2", "open": "3"}
	RoomTrapDefinition.from_record(ContentRecordReader.new(record, "test", errors))
	_check(errors.is_empty(), "a complete trap reads: " + str(errors))
	errors.clear()
	var landmark: Dictionary = {"id": "x", "zone": "z", "name": "n", "long": "l", "action": "a", "policy": "bury", "portals": ["p"],
		"messages": {"bury": "1", "book": "2", "paper": "3", "fall": "4"}, "legacy_source": "s"}
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(landmark, "test", errors))
	_check(not errors.is_empty(), "bury needs its buried and reward items")
	errors.clear()
	landmark["items"] = {"buried": "i", "reward": "j"}
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(landmark, "test", errors))
	_check(errors.is_empty(), "a complete bury landmark reads: " + str(errors))
	errors.clear()
	var portal: Dictionary = {"id": "y", "zone": "z", "name": "n", "long": "l", "action": "a", "portals": ["p"], "messages": {"use": "u"}, "legacy_source": "s"}
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(portal, "test", errors))
	_check(errors.is_empty(), "a portal landmark may carry its use line: " + str(errors))
	errors.clear()
	portal["messages"] = {"hold": "h"}
	WorldLandmarkDefinition.from_record(ContentRecordReader.new(portal, "test", errors))
	_check(not errors.is_empty(), "but no other message")
	errors.clear()
	var npc: Dictionary = {"id": "n", "legacy_source": "s", "name": "某人", "aliases": ["someone"], "gender": "男性", "age": 30, "combat_exp": 10, "score": 100, "bellicosity": 100}
	NpcContentRecords.npc_from_record(ContentRecordReader.new(npc, "test", errors))
	_check(not errors.is_empty(), "a berserk NPC whose bellicosity is not above its score would spar: refused")
	errors.clear()
	npc["bellicosity"] = 101
	NpcContentRecords.npc_from_record(ContentRecordReader.new(npc, "test", errors))
	_check(errors.is_empty(), "one above its score kills: " + str(errors))


## cave5.c: ikar = random(kar + 10); > 25 the book, > 20 paper (and the fall), else the fall.
func _test_bury_roll() -> void:
	var cases: Array = [[26, BuryRoll.Outcome.BOOK], [25, BuryRoll.Outcome.PAPER], [21, BuryRoll.Outcome.PAPER], [20, BuryRoll.Outcome.FALL], [0, BuryRoll.Outcome.FALL]]
	for case: Array in cases:
		var draws: Array[int] = [case[0]]
		var source: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new(draws)
		_check(BuryRoll.roll(30, source) == case[1] and source.requested_bounds() == [40], "random(kar + 10) = %d → %s" % [case[0], case[1]])


## attack.c init(): random(bellicosity / 40) > cps; start_berserk(): force > (random(b) + b) / 2
## calms it, else bellicosity > score kills.
func _test_berserk_roll() -> void:
	var state: CharacterState = CharacterState.new()
	state.attributes.bellicosity = 10000
	state.attributes.composure = 20
	state.recovery.inner_force = CharacterInternalResourceState.new(600, 600)
	var calm: Array[int] = [20]
	var source: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new(calm)
	_check(NpcBerserk.roll(state, 8000, source) == NpcBerserk.Outcome.NONE and source.requested_bounds() == [250], "random(250) not above cps 20: nothing")
	var wild: Array[int] = [21, 0]
	source = ScriptedWorldInteractionRandomSource.new(wild)
	_check(NpcBerserk.roll(state, 8000, source) == NpcBerserk.Outcome.KILL and source.requested_bounds() == [250, 10000], "above cps; force 600 under 5000: bellicosity 10000 over score 8000 kills")
	state.recovery.inner_force = CharacterInternalResourceState.new(6000, 6000)
	var strong: Array[int] = [100, 0]
	source = ScriptedWorldInteractionRandomSource.new(strong)
	_check(NpcBerserk.roll(state, 8000, source) == NpcBerserk.Outcome.STARE, "force above (random(b) + b) / 2: he only stares")


func _test_netherbolt() -> void:
	var nether: BoltSpell = SpecialFunctions.cast(&"netherbolt") as BoltSpell
	var drainer: BoltSpell = SpecialFunctions.cast(&"drainerbolt") as BoltSpell
	_check(nether != null and nether.track == BoltSpell.Track.KEE and nether.mana_divisor == 10 and nether.sen_cost == 10 and nether.flash_color == ColoredLine.HIC, "netherbolt.c: kee, max_mana / 10, 10 sen, a cyan bolt")
	_check(drainer.mana_divisor == 20, "the other bolts keep max_mana / 20")
	_check(nether.hit == "结果「嗤」地一声，青光从$p身上透体而过，拖出一条长长的血箭直射到两三丈外的地下！", "its hit line verbatim")


## Painted walkable tiles join every zone of each new map to its entry; the keep is
## reached from the forest.
func _test_tiles(session: OldPineWorldSessionController) -> void:
	for map_id: StringName in [&"oldpine.outdoor", &"oldpine.cave", &"oldpine.stone", &"oldpine.caves", &"oldpine.cliff2"]:
		var map: WorldMapController = session.world_map_of(map_id)
		var layers: Array[TileMapLayer] = TerrainProbe.layers(map)
		var walkable: Dictionary[Vector2i, bool] = {}
		for layer: TileMapLayer in layers:
			for cell: Vector2i in layer.get_used_cells():
				if layer.get_cell_tile_data(cell).get_collision_polygons_count(0) == 0:
					walkable[cell] = true
		var entry: Vector2 = map.resolve_spawn_marker(GameContent.catalog().map(map_id).entry_spawn_id).position
		var start: Vector2i = layers[0].local_to_map(entry)
		var reached: Dictionary[Vector2i, bool] = {start: true}
		var frontier: Array[Vector2i] = [start]
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if walkable.has(cell + step) and not reached.has(cell + step):
					reached[cell + step] = true
					frontier.append(cell + step)
		for zone: WorldPhysicalZoneArea2D in map.find_children("*", "WorldPhysicalZoneArea2D", true, false):
			if map_id == &"oldpine.outdoor" and zone.zone_id not in [&"oldpine.outdoor.keep_gate", YARD, HALL]:
				continue
			var rect: Rect2 = _zone_rect(map, zone.zone_id)
			var joined: bool = false
			for cell: Vector2i in reached:
				if rect.has_point(layers[0].map_to_local(cell)):
					joined = true
					break
			_check(joined, "%s is joined to %s's entry on the tiles" % [zone.zone_id, map_id])


## A new world: the keep's NPCs stand in place, the trap's guards are not there yet,
## the gate is open and the bones lie in cave5.
func _test_new_world(session: OldPineWorldSessionController) -> void:
	var outdoor: WorldMapController = session.world_map_of(&"oldpine.outdoor")
	var present: Dictionary[StringName, int] = {}
	var absent: int = 0
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.spawn_id == TRAP_GUARDS:
			absent += 0 if npc.exists_in_map else 1
		elif npc.exists_in_map and String(npc.world_location().zone_id).contains("keep"):
			present[npc.definition().definition_id] = present.get(npc.definition().definition_id, 0) + 1
	_check(absent == 5, "five trap guards made but absent")
	_check(present == {&"oldpine.npc.bandit_guard": 6, &"oldpine.npc.bandit_leader": 4, &"oldpine.npc.bandit_commander": 1}, "the keep's people: %s" % present)
	_check(outdoor.door(GATE).is_open() and not outdoor.can_operate_door(GATE), "the gate stands open and the player cannot shut it")
	var caves: WorldMapController = session.world_map_of(&"oldpine.caves")
	_check(not caves.floor_item_of(SKELETON, &"oldpine.caves.mouth").is_empty(), "the bones lie in cave5")
	var maniac: NpcRuntimeState = null
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.definition().definition_id == &"oldpine.npc.maniac":
			maniac = npc
	_check(maniac != null and maniac.character_state.attributes.bellicosity == 10000 and maniac.world_location().zone_id == &"oldpine.outdoor.east_bridge", "疯老头子 at epath3, bellicosity 10000")


## keep2.c valid_leave(): leaving east while the gate is open shuts it with a shout and
## calls in five guards; the pipe in keep2 opens it (pipe_notify), as does keep2's reset.
## The guards that came stay through a Save.
func _test_trap(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var outdoor: WorldMapController = session.world_map_of(&"oldpine.outdoor")
	var clearing: StringName = &"oldpine.outdoor.central_clearing"
	var moved: OldPineMapHandoffResult = session.handoff_to(&"oldpine.outdoor", clearing, clearing, &"oldpine.outdoor.central_clearing.player_start")
	_check(moved.succeeded(), "to the clearing")
	await tree.physics_frame
	# Zone by zone through the zone tracker's own rule (accept_zone_presence), in one frame.
	for step: Array in [[Vector2(450, 850), &"oldpine.outdoor.pine_entrance"], [Vector2(1100, 864), &"oldpine.outdoor.keep_gate"], [Vector2(1480, 864), YARD]]:
		outdoor.player_body.global_position = step[0]
		outdoor.accept_zone_presence(outdoor.physical_zone(step[1]))
	_check(session.player_runtime().world_location().zone_id == YARD, "pine2 east to keep1, through the open gate into keep2")
	var hud: SharedGameplayUI = session.shared_ui()
	var traps: WorldRoomTraps = session.room_traps()
	outdoor.player_body.global_position = Vector2(1780, 864)
	outdoor.accept_zone_presence(outdoor.physical_zone(HALL))
	_check(session.player_runtime().world_location().zone_id == HALL, "on east into the hall")
	_check(traps.is_shut(TRAP) and not outdoor.door(GATE).is_open(), "east into the hall: the gate is shut")
	var lines: PackedStringArray = hud.log_lines()
	_check(lines[lines.size() - 2] == "你听到你身后有几个声音大叫：把门关上！把门关上！一个也不许让他们溜走！" and lines[lines.size() - 1] == "接著「轰」地一声，通往外面的大门已经被一块大石堵死了。", "the shout and the boulder")
	var came: int = 0
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.spawn_id == TRAP_GUARDS and npc.exists_in_map and npc.world_location().zone_id == YARD:
			came += 1
	_check(came == 5, "five guards come into keep2: %d" % came)
	var snapshot: GameSaveSnapshot = Work.capture(session)
	var saved_present: int = 0
	if snapshot != null:
		for entry: GameSaveValueTypes.NpcSpawnStateSnapshot in snapshot.npc_spawn_states:
			if entry.spawn_id == TRAP_GUARDS and entry.exists_in_world:
				saved_present += 1
	_check(saved_present == 5, "the save keeps them there: %d" % saved_present)
	outdoor.player_body.global_position = Vector2(1450, 864)
	outdoor.accept_zone_presence(outdoor.physical_zone(YARD))
	outdoor.player_body.global_position = Vector2(1780, 864)
	outdoor.accept_zone_presence(outdoor.physical_zone(HALL))
	_check(hud.log_lines().size() == lines.size(), "back and east again with the gate shut: nothing more happens")
	outdoor.player_body.global_position = Vector2(1450, 864)
	outdoor.accept_zone_presence(outdoor.physical_zone(YARD))
	var pipe: StringName = outdoor.place_new_floor_item(PIPE)
	_check(not pipe.is_empty() and outdoor.select_floor_item(pipe), "a 竹管 at the player's feet")
	outdoor.take_selected_floor_item()
	_check(outdoor.play_item(pipe), "吹奏 the pipe")
	lines = hud.log_lines()
	_check(lines[lines.size() - 2] == "你拿起一根竹管呜嘟嘟地吹了起来。" and lines[lines.size() - 1] == "你听到一阵轧轧的轮盘绞动声，堵住门口的大石慢慢地被移开了。", "pipe_notify(): the stone rolls away")
	_check(not traps.is_shut(TRAP) and outdoor.door(GATE).is_open(), "the gate is open again")
	outdoor.player_body.global_position = Vector2(1780, 864)
	outdoor.accept_zone_presence(outdoor.physical_zone(HALL))
	_check(traps.is_shut(TRAP), "it shuts again on the way east")
	came = 0
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.spawn_id == TRAP_GUARDS and npc.exists_in_map:
			came += 1
	_check(came == 5, "the five still alive stay; none is added")
	var said: int = hud.log_lines().size()
	session.reset_room("d/oldpine/keep2.c")
	_check(not traps.is_shut(TRAP) and outdoor.door(GATE).is_open() and hud.log_lines().size() == said, "keep2's reset opens it without a word")


## path3's stone up and down into the caves; cliffdown down to cliff2, and down to epath3.
func _test_climbs(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var inner: ZoneDefinition = GameContent.catalog().zone(&"oldpine.cave.inner_path")
	var cave: WorldMapController = session.world_map_of(&"oldpine.cave")
	_check(session.handoff_to(&"oldpine.cave", &"oldpine.cave.waterfall_passage", &"oldpine.cave.waterfall_passage", &"oldpine.cave.waterfall_passage.vine_landing").succeeded(), "into the passage")
	await tree.physics_frame
	for spot: Vector2 in [Vector2(0, -40), Vector2(0, -360)]:
		cave.player_body.global_position = spot
		for _frame: int in range(4):
			await tree.physics_frame
	_check(player.world_location().zone_id == inner.zone_id, "north through secrectpath1 into path3")
	_check(cave.select_landmark(&"oldpine.cave.landmark.stone") and hud.portal_action_text() == "往上爬", "the big stone: 往上爬")
	cave.traverse_selected_portal()
	await tree.physics_frame
	_check(session.active_map_id() == &"oldpine.stone" and player.world_location().zone_id == &"oldpine.stone.top" and hud.log_lines().has("你慢慢地攀上大青石。"), "up onto the stone, with path3.c's line")
	var stone: WorldMapController = session.active_map() as WorldMapController
	_check(stone.select_landmark(&"oldpine.stone.landmark.climb_down"), "the stone: 往下爬")
	stone.traverse_selected_portal()
	await tree.physics_frame
	_check(session.active_map_id() == &"oldpine.caves" and player.world_location().zone_id == &"oldpine.caves.maze" and hud.log_lines().has("你迅速地爬下大青石。"), "down into the caves (cave1)")
	var outdoor: WorldMapController = session.world_map_of(&"oldpine.outdoor")
	_check(session.handoff_to(&"oldpine.outdoor", &"oldpine.outdoor.pine_cliff_edge", &"oldpine.outdoor.pine_cliff_edge", &"oldpine.outdoor.pine_cliff_edge.cliff2_return").succeeded(), "to the cliff edge (cliffdown)")
	await tree.physics_frame
	_check(outdoor.select_landmark(&"oldpine.outdoor.landmark.cliffdown_cliff"), "the cliff: 往下爬")
	outdoor.traverse_selected_portal()
	await tree.physics_frame
	_check(session.active_map_id() == &"oldpine.cliff2" and player.world_location().zone_id == &"oldpine.cliff2.niche", "down to the narrow niche (cliff2)")
	var niche: WorldMapController = session.active_map() as WorldMapController
	niche.player_body.global_position = Vector2(240, 480)
	await tree.physics_frame
	_check(niche.select_landmark(&"oldpine.cliff2.landmark.down"), "the niche: 往下爬")
	niche.traverse_selected_portal()
	await tree.physics_frame
	_check(session.active_map_id() == &"oldpine.outdoor" and player.world_location().zone_id == &"oldpine.outdoor.east_bridge" and hud.log_lines().has("你试了试脚边的岩石稳不稳，开始小心翼翼地往山涧中攀了下去。"), "down the cliff to epath3")


## cave5.c do_bury(): the bones are gone either way; the book falls (the player stays), or
## the floor gives way (after the paper, or without it); the room's reset lays new bones.
func _test_bury(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var caves: WorldMapController = session.world_map_of(&"oldpine.caves")
	var original: WorldInteractionRandomSource = session.world_interaction_random_source()
	for case: Array in [[26, true, ""], [21, false, "你只看见山洞顶部纷纷扬扬飘下几张纸片来。"], [3, false, ""]]:
		if session.active_map_id() == &"oldpine.caves":
			_check(caves.relocate_player(&"oldpine.caves.maze", &"oldpine.caves.maze.cave1_landing"), "back to cave1")
		else:
			_check(session.handoff_to(&"oldpine.caves", &"oldpine.caves.maze", &"oldpine.caves.maze", &"oldpine.caves.maze.cave1_landing").succeeded(), "into the caves")
		await tree.physics_frame
		for spot: Vector2 in [Vector2(740, 408), Vector2(888, 340)]:
			caves.player_body.global_position = spot
			for _frame: int in range(4):
				await tree.physics_frame
		_check(player.world_location().zone_id == &"oldpine.caves.mouth", "into cave5")
		if caves.floor_item_of(SKELETON, &"oldpine.caves.mouth").is_empty():
			session.reset_room("d/oldpine/cave5.c")
		var bones: StringName = caves.floor_item_of(SKELETON, &"oldpine.caves.mouth")
		_check(not bones.is_empty(), "the bones lie there")
		player.state.attributes.karma = 30
		var draws: Array[int] = [case[0]]
		var source: ScriptedWorldInteractionRandomSource = ScriptedWorldInteractionRandomSource.new(draws)
		session.configure_world_interaction_random_source(source)
		_check(caves.select_landmark(WALL) and hud.portal_action_text() == "埋葬骸骨", "the wall: 埋葬骸骨")
		var before: int = hud.log_lines().size()
		var result: BuryLandmarkPolicy.Result = caves.traverse_selected_portal() as BuryLandmarkPolicy.Result
		await tree.physics_frame
		var said: PackedStringArray = hud.log_lines().slice(before)
		_check(result != null and result.buried and caves.floor_item_of(SKELETON, &"oldpine.caves.mouth").is_empty(), "random %d: the bones are buried" % case[0])
		_check(said[0] == "你小心翼翼地埋好了那具骸骨。" and source.requested_bounds() == [40], "do_bury()'s first line; random(kar + 10) with kar 30")
		if case[1]:
			_check(said.has("你听见山洞顶部的石壁「喀喇」地一声响，一本书坠落下来。") and session.active_map_id() == &"oldpine.caves" and not caves.floor_item_of(PARRYBOOK, &"oldpine.caves.mouth").is_empty(), "the book falls and the player stays")
			session.configure_world_interaction_random_source(original)
			var work: RefCounted = Work.new()
			await work.round_trip(tree, session, Work.capture(session), "the bones buried, the book on the floor")
			_check(work._failures.is_empty(), "Save/Continue keeps the book and not the bones: " + str(work._failures))
		else:
			_check(said.has("你听得「轰」的一声响，已经从这摔了下去") and session.active_map_id() == &"oldpine.gorge" and player.world_location().zone_id == &"oldpine.gorge.waterfall", "the floor gives way to the waterfall")
			_check(case[2].is_empty() != said.has(case[2]), "the paper only above 20")
	session.reset_room("d/oldpine/cave5.c")
	_check(not caves.floor_item_of(SKELETON, &"oldpine.caves.mouth").is_empty(), "the room's reset lays the bones again")


## attack.c's berserk: 疯老头子 stares and attacks a player who comes near (bellicosity
## 10000 over score 8000), with combatd.c start_berserk()'s lines.
func _test_maniac(tree: SceneTree, session: OldPineWorldSessionController) -> void:
	var outdoor: WorldMapController = session.world_map_of(&"oldpine.outdoor")
	_check(session.handoff_to(&"oldpine.outdoor", &"oldpine.outdoor.east_bridge", &"oldpine.outdoor.east_bridge", &"oldpine.outdoor.east_bridge.cliff2_landing").succeeded(), "to epath3")
	await tree.physics_frame
	var maniac: NpcRuntimeState = null
	for npc: NpcRuntimeState in outdoor.npc_runtimes():
		if npc.definition().definition_id == &"oldpine.npc.maniac":
			maniac = npc
	var draws: Array[int] = [200, 0]
	session.configure_world_interaction_random_source(ScriptedWorldInteractionRandomSource.new(draws))
	outdoor.aggression_adapter().enter_player_presence(maniac, session.player_runtime(), true)
	var started: Array[CombatSliceInitiationResult] = outdoor.process_pending_aggression()
	_check(started.size() == 1 and started[0].outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "he attacks")
	var lines: PackedStringArray = session.shared_ui().log_lines()
	_check(lines.has("疯老头子用一种异样的眼神扫视著在场的每一个人。") and lines.has("疯老头子对著你喝道：老子看你实在很不顺眼，去死吧。") and lines.has("看起来疯老头子想杀死你！"), "start_berserk()'s lines and kill_ob()'s warning")
	await tree.process_frame


func _zone_rect(map: WorldMapController, zone_id: StringName) -> Rect2:
	var zone: WorldPhysicalZoneArea2D = map.physical_zone(zone_id)
	var shape: RectangleShape2D = (zone.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	return Rect2(zone.position - shape.size / 2.0, shape.size)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
