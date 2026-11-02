extends RefCounted

## 总图 (现代基线 B; DECISIONS「总图」): atlas.json has every place once and every map belongs to
## one; the 沙盘 agrees with the ways' compass; a new player knows only where they stand and
## what an ordinary way off it leads to; hidden ways show nothing; marks come from the
## definitions; 指路 keeps to walked roads, follows the player and folds up on arrival; the
## page shows all this, the pad reaches every button, and the 经典 pace has no page.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_table()
	_test_compass()
	_test_pictures()
	_test_knowing()
	_test_hidden_ways()
	_test_marks()
	_test_routes()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.create_timer(0.5).timeout
	await _test_page(tree, session)
	await _test_waypoint_in_the_world(tree, session)
	await _test_stubs(tree, session)
	await _test_classic(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _player(visited: Array[String]) -> CharacterState:
	var state := CharacterState.new()
	for map_id: String in visited:
		MapAtlas.note_visit(state, StringName(map_id))
	return state


func _test_table() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var table: AtlasTable = catalog.atlas()
	_check(table.cells().size() == 34, "34 places: %d" % table.cells().size())
	var spots: Dictionary[Vector2, bool] = {}
	for cell: AtlasCell in table.cells():
		_check(catalog.map(cell.map_id) != null, "%s is a map" % cell.map_id)
		_check(not cell.name.is_empty() and not spots.has(cell.at), "%s has a name and a spot of its own" % cell.map_id)
		spots[cell.at] = true
	var orphans: Array[StringName] = []
	for map: MapDefinition in catalog.maps():
		if table.home_of(catalog, map.map_id).is_empty():
			orphans.append(map.map_id)
	_check(orphans.is_empty(), "every map belongs to a place: %s" % [orphans])
	_check(table.home_of(catalog, &"snow.inn") == &"snow.outdoor", "the inn is in 雪亭镇")
	var errors: Array[String] = []
	AtlasTable.new().add(AtlasCell.from_record(ContentRecordReader.new({"map": "x", "name": "x", "x": 1}, "test", errors)))
	_check(not errors.is_empty(), "a row without its place is refused")


## A way written `north` goes to a place further north on the 沙盘, and so on.
func _test_compass() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var table: AtlasTable = catalog.atlas()
	var checked: int = 0
	var words: Dictionary[String, Vector2] = {"north": Vector2.UP, "south": Vector2.DOWN, "east": Vector2.RIGHT, "west": Vector2.LEFT}
	for portal: PortalDefinition in catalog.portals():
		var from: AtlasCell = table.cell(portal.source_map_id)
		var to: AtlasCell = table.cell(portal.destination_map_id)
		if from == null or to == null or from == to or not MapAtlas.plain(catalog, portal):
			continue
		var gap: Vector2 = to.at - from.at
		for word: String in words:
			if portal.legacy_command.contains(word):
				checked += 1
				_check(gap.dot(words[word]) > 0.0, "%s from %s to %s: %s" % [word, from.map_id, to.map_id, gap])
	_check(checked >= 40, "the ways between places were looked at: %d" % checked)


func _test_pictures() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var pictures: AtlasPictures = AtlasPictures.read()
	var plates: Array[StringName] = []
	for cell: AtlasCell in catalog.atlas().cells():
		if not pictures.has_picture(cell.map_id):
			plates.append(cell.map_id)
			continue
		_check(pictures.texture(cell.map_id) != null, "%s has its picture" % cell.map_id)
	_check(plates.size() == 4 and plates.has(&"chuenyu.main") and plates.has(&"city.main") and plates.has(&"death.realm") and plates.has(&"village.main"), "only the four without a voxel view are plates: %s" % [plates])
	var door: Vector2 = pictures.pin(&"snow.outdoor", "door:snow.inn")
	_check(door != Vector2.INF and pictures.pin(&"snow.outdoor", "door:nowhere") == Vector2.INF, "a door's pin is in the bake")
	_check(load(AtlasPictures.DIRECTORY + "arrow.png") != null, "the arrow is baked")
	for file: String in ["land", "mist", "shade", "clouds"]:
		_check(pictures.layer(file) != null, "the %s layer is baked" % file)
	_check(pictures.roads.size() == 31, "a road for each pair of places an ordinary way joins: %d" % pictures.roads.size())
	for road: AtlasPictures.Road in pictures.roads:
		_check(catalog.atlas().cell(road.a) != null and catalog.atlas().cell(road.b) != null, "%s joins places" % road.file)
		_check(pictures.layer(road.file) != null and road.line.size() >= 2, "%s has its layer and its line" % road.file)
		if road.stub_a != Vector2.INF:
			_check(pictures.layer(road.file + "_a") != null, "%s has its stub" % road.file)
		var joined: bool = false
		for portal: PortalDefinition in catalog.portals():
			var ends: Array[StringName] = [catalog.atlas().home_of(catalog, portal.source_map_id), catalog.atlas().home_of(catalog, portal.destination_map_id)]
			if ends.has(road.a) and ends.has(road.b) and MapAtlas.plain(catalog, portal):
				joined = true
		_check(joined, "%s stands for a real ordinary way: %s to %s" % [road.file, road.a, road.b])
	_check(pictures.road_between(&"snow.outdoor", &"cloud.outdoor") != null and pictures.road_between(&"cloud.outdoor", &"snow.outdoor") != null, "either way round")
	_check(pictures.road_between(&"snow.outdoor", &"green.maze") == null, "the 迷阵's hidden way has no road")
	for portal: PortalDefinition in catalog.portals():
		var from: StringName = catalog.atlas().home_of(catalog, portal.source_map_id)
		var to: StringName = catalog.atlas().home_of(catalog, portal.destination_map_id)
		if from != to and not from.is_empty() and not to.is_empty() and MapAtlas.plain(catalog, portal):
			_check(pictures.road_between(from, to) != null, "%s to %s is an ordinary way with no road: run tools.maps.atlas.bake --land" % [from, to])


func _test_knowing() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = _player(["snow.outdoor"])
	_check(MapAtlas.seen(catalog, state, &"snow.outdoor") == MapAtlas.Seen.REACHED, "the first place is reached")
	_check(MapAtlas.seen(catalog, state, &"cloud.outdoor") == MapAtlas.Seen.ROAD, "a road leads to 绮云镇: a ？")
	_check(MapAtlas.seen(catalog, state, &"guanbei.town") == MapAtlas.Seen.UNSEEN, "关北 is nothing yet")
	_check(MapAtlas.seen(catalog, state, &"death.realm") == MapAtlas.Seen.UNSEEN, "阴间 is nothing while alive")
	MapAtlas.note_visit(state, &"snow.inn")
	MapAtlas.note_visit(state, &"snow.inn")
	_check(state.visited_maps == ({"snow.outdoor": 1, "snow.inn": 2} as Dictionary[String, int]), "the first arrival counts, in order: %s" % [state.visited_maps])
	state = _player(["snow.inn"])
	_check(MapAtlas.seen(catalog, state, &"snow.outdoor") == MapAtlas.Seen.REACHED, "a room reaches its place")
	state = _player(["death.realm"])
	_check(MapAtlas.seen(catalog, state, &"death.realm") == MapAtlas.Seen.REACHED, "阴间 once there")


## Every way a player has to find stays off the 沙盘 until it has been walked.
func _test_hidden_ways() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var landmark_ways: int = 0
	for map: MapDefinition in catalog.maps():
		for landmark: WorldLandmarkDefinition in catalog.landmarks_for_map(map.map_id):
			for portal_id: StringName in landmark.portal_ids():
				landmark_ways += 1
				_check(not MapAtlas.plain(catalog, catalog.portal(portal_id)), "%s is hidden" % portal_id)
	_check(landmark_ways >= 30, "landmark ways were looked at: %d" % landmark_ways)
	var clued: int = 0
	for portal: PortalDefinition in catalog.portals():
		for door: DoorDefinition in catalog.doors_for_map(portal.source_map_id):
			if not door.found_by.is_empty() and door.zone_ids().has(portal.source_zone_id) and door.zone_ids().has(portal.destination_zone_id):
				clued += 1
				_check(not MapAtlas.plain(catalog, portal), "%s waits behind its door's clue" % portal.portal_id)
	_check(clued > 0, "a door a clue finds was looked at")
	var state: CharacterState = _player(["canyon.clifftop"])
	var known: Array[StringName] = MapAtlas.known_maps(catalog, state, &"canyon.pass")
	_check(known.is_empty(), "铁链崖's 铁索 (a room command) shows no way down: %s" % [known])
	state = _player(["oldpine.outdoor"])
	_check(not MapAtlas.known_maps(catalog, state, &"oldpine.outdoor").has(&"oldpine.keep_hall"), "what lies behind the 灌木丛 is not counted before the clue")


func _kinds(found: Array[MapAtlas.Mark]) -> Dictionary[StringName, Array]:
	var result: Dictionary[StringName, Array] = {}
	for mark: MapAtlas.Mark in found:
		if not result.has(mark.kind):
			result[mark.kind] = []
		result[mark.kind].append(mark.who)
	return result


## A stub leads only to a ？: a place reached with nothing known beyond it shows no road.
func _test_stubs(tree: SceneTree, session: WorldSessionController) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var page: MapPage = session.shared_ui().map_page
	var state: CharacterState = _player(["niling.slope"])
	_check(MapAtlas.seen(catalog, state, &"niling.backhill") == MapAtlas.Seen.UNSEEN, "the back hill is unknown from the slope")
	page.fill(state, &"niling.slope", &"")
	await tree.process_frame
	var pictures: AtlasPictures = AtlasPictures.read()
	var road: AtlasPictures.Road = pictures.road_between(&"niling.slope", &"niling.backhill")
	var shown: Array[String] = []
	for sprite: Node in page._road_layer.get_children():
		shown.append((sprite as Sprite2D).texture.resource_path)
	_check(road != null and not shown.has(AtlasPictures.DIRECTORY + road.file + "_a.png") and not shown.has(AtlasPictures.DIRECTORY + road.file + "_b.png"), "no stub towards what the player has no road to: %s" % [shown])
	_check(page._way.is_empty() or page._way_length > 0.0, "a way has a length")


func _test_marks() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = _player(["snow.outdoor"])
	var kinds: Dictionary[StringName, Array] = _kinds(MapAtlas.marks(catalog, state, &"snow.outdoor"))
	_check(kinds.get(MapAtlas.BOUNTY, []).size() == 1, "雪亭镇's 悬赏榜: %s" % [kinds])
	_check(kinds.get(MapAtlas.BANK, []).size() >= 1 and kinds.get(MapAtlas.HOCKSHOP, []).size() >= 1, "its 钱庄 and 当铺: %s" % [kinds])
	_check(kinds.get(MapAtlas.SHOP, []).size() >= 3, "its shops: %s" % [kinds])
	_check(kinds.get(MapAtlas.MASTER, []).size() >= 1, "its 武馆: %s" % [kinds])
	var everywhere: Array[String] = []
	for cell: AtlasCell in catalog.atlas().cells():
		var all_maps := CharacterState.new()
		for map_id: StringName in catalog.atlas().maps_of(catalog, cell.map_id):
			MapAtlas.note_visit(all_maps, map_id)
		for mark: MapAtlas.Mark in MapAtlas.marks(catalog, all_maps, cell.map_id):
			_check(catalog.zone(mark.zone_id) != null, "%s stands in a room" % mark.who)
			if mark.kind == MapAtlas.ERRAND:
				everywhere.append(mark.who)
	_check(everywhere.size() == 1, "one 差事 giver in the world, 朱鸿雪: %s" % [everywhere])
	var refusing: int = 0
	for npc: NpcDefinition in catalog.npcs():
		var teaching: NpcTeaching = npc.teaching()
		if teaching != null and teaching.apprentice != null and teaching.apprentice.kind == NpcTeaching.Kind.REFUSES and teaching.recognize_rules.is_empty():
			refusing += 1
			_check(not MapAtlas.takes_students(npc), "%s takes no one: no 师 mark" % npc.display_name)
	_check(refusing > 0, "a master who refuses was looked at")


func _test_routes() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var state: CharacterState = _player(["snow.outdoor"])
	_check(not MapAtlas.can_walk(catalog, state, &"snow.outdoor", &"choyin.town"), "no walked road to 乔阴")
	_check(MapAtlas.can_walk(catalog, state, &"snow.outdoor", &"snow.inn"), "a door on the street is one step, unwalked or not")
	_check(WorldRoute.chain(catalog, &"snow.outdoor", &"choyin.town").size() > 0, "without `known` the chain still goes everywhere")
	var town: CharacterState = _player(["snow.inn", "snow.outdoor", "cloud.outdoor", "sunhill.mountain", "choyin.town", "choyin.taolin"])
	var back: Array[WorldRoute.Step] = MapAtlas.route(catalog, town, &"choyin.town", &"snow.inn")
	_check(not back.is_empty() and back[0].portal != null and MapAtlas.plain(catalog, back[0].portal), "the 桃林's way out is not the way home: %s" % ("" if back.is_empty() or back[0].portal == null else String(back[0].portal.portal_id)))
	var down: Array[WorldRoute.Step] = WorldRoute.guided(catalog, &"canyon.clifftop", &"canyon.pass")
	_check(down.size() > 0 and down[0].service != null, "a room command serves when no plain way joins them")
	var past: Array[WorldRoute.Step] = WorldRoute.guided(catalog, &"choyin.town", &"canyon.pass")
	var hidden: int = 0
	for step: WorldRoute.Step in past:
		if step.portal == null or not MapAtlas.plain(catalog, step.portal):
			hidden += 1
	_check(not past.is_empty() and hidden == 1, "past the 铁索 from 乔阴: that hop alone is hidden, not the 桃林's way home: %d" % hidden)
	state = _player(["snow.outdoor", "cloud.outdoor"])
	var steps: Array[WorldRoute.Step] = MapAtlas.route(catalog, state, &"cloud.outdoor", &"snow.outdoor")
	_check(steps.size() == 1 and steps[0].from_map == &"cloud.outdoor", "walked roads join them: %d" % steps.size())
	MapAtlas.point_to(state, &"snow.inn", &"snow.inn")
	_check(MapAtlas.arrived(state, &"snow.inn", &"snow.inn") and not MapAtlas.arrived(state, &"snow.outdoor", &"snow.inn"), "arrival is on the map")
	var goal: MapAtlas.Goal = MapAtlas.goal(catalog, state)
	_check(goal != null and goal.waypoint and goal.map_id == &"snow.inn", "指路 leads before any quest")
	MapAtlas.point_to(state, &"")
	_check(state.waypoint_map.is_empty() and state.waypoint_zone.is_empty() and MapAtlas.goal(catalog, state) == null, "taken back: nothing leads")
	state.waypoint_map = &"gone.map"
	_check(MapAtlas.goal(catalog, state) == null, "a map no longer in the game leads nowhere")
	state.waypoint_map = &""


func _test_page(tree: SceneTree, session: WorldSessionController) -> void:
	var hud: SharedGameplayUI = session.shared_ui()
	var state: CharacterState = session.player_runtime().state
	_check(state.visited_maps.has(String(session.active_map_id())), "the player's first map is recorded")
	hud.menu.present(GameMenu.Tab.MAP)
	await tree.process_frame
	await tree.process_frame
	var page: MapPage = hud.map_page
	_check(page.is_visible_in_tree(), "地图 shows")
	var here: StringName = GameContent.catalog().atlas().home_of(GameContent.catalog(), session.active_map_id())
	_check(page.cell_buttons.has(here) and tree.root.gui_get_focus_owner() == page.cell_buttons[here], "the focus starts on where the player stands")
	_check(page.shown_text().contains("雪亭镇"), "its card: %s" % page.shown_text())
	_check(hud.menu.window.size.x > GameMenu.WINDOW_SIZE.x, "地图 takes the screen: %s" % hud.menu.window.size)
	for map_id: StringName in page.cell_buttons:
		for property: StringName in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
			var button: Button = page.cell_buttons[map_id]
			_check(button.get_node_or_null(button.get(property)) != null, "%s's %s leads somewhere" % [map_id, property])
	# Every place reached and every ？ by walking the neighbours, as a pad does.
	var reached: Dictionary[Button, bool] = {page.cell_buttons[here]: true}
	var frontier: Array[Button] = [page.cell_buttons[here]]
	while not frontier.is_empty():
		var button: Button = frontier.pop_back()
		for property: StringName in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
			var next: Button = button.get_node(button.get(property)) as Button
			if not reached.has(next):
				reached[next] = true
				frontier.append(next)
	_check(reached.size() == page.cell_buttons.size(), "the pad reaches every place: %d of %d" % [reached.size(), page.cell_buttons.size()])
	page.cell_buttons[here].pressed.emit()
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == page.row_buttons[0], "confirm goes to the card")
	var row: Button = page.row_buttons[0]
	_check(row.get_node(row.focus_neighbor_left) == page.cell_buttons[here], "left comes back")
	_check(row.get_node(row.focus_neighbor_top) == row, "up stays on the card")
	var last: Button = page.row_buttons[-1]
	_check(last.get_node(last.focus_neighbor_bottom) == page.zoom_button and page.zoom_button.get_node(page.zoom_button.focus_neighbor_bottom) == page.zoom_button, "down ends on 全图")
	# A second press on the line pressed stays on it: 取消指路 joins at the end.
	var line: int = page.row_buttons.size() - 1
	page.row_buttons[line].grab_focus()
	var before: String = page.row_buttons[line].text
	page.row_buttons[line].pressed.emit()
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == page.row_buttons[line] and page.row_buttons[line].text == before, "the focus stays on the line pressed")
	MapAtlas.point_to(state, &"")
	MapAtlas.note_visit(state, &"snow.outdoor")
	page.fill(state, session.active_map_id(), &"")
	var road: StringName = &""
	for map_id: StringName in page.cell_buttons:
		if page.cell_buttons[map_id].text == "？":
			road = map_id
	_check(not road.is_empty(), "a ？ stands on the 沙盘")
	page._select(road)
	_check(page._pins.is_empty(), "a ？ has no pins")
	_check(page._road_layer.get_child_count() > 0 and page._road_layer.get_child(0).texture.resource_path.ends_with("_a.png") or page._road_layer.get_child(0).texture.resource_path.ends_with("_b.png"), "from a place reached only stubs lead off")
	MapAtlas.note_visit(state, &"cloud.outdoor")
	MapAtlas.point_to(state, &"cloud.outdoor")
	page.fill(state, &"snow.outdoor", &"")
	var whole_roads: int = 0
	for sprite: Node in page._road_layer.get_children():
		if not (sprite as Sprite2D).texture.resource_path.ends_with("_a.png") and not (sprite as Sprite2D).texture.resource_path.ends_with("_b.png"):
			whole_roads += 1
	_check(whole_roads == 1, "the road between two places reached shows whole: %d" % whole_roads)
	_check(page._way_layer.get_child_count() >= 2 and not page._way.is_empty() and page._glows.size() >= 1, "the way to the 指路 lights up: %d" % page._way_layer.get_child_count())
	page._process(1.0)
	_check(page._glows[0].position != Vector2.ZERO, "the light runs along it")
	MapAtlas.point_to(state, &"")
	state.visited_maps.erase("cloud.outdoor")
	hud.menu.close()
	await tree.process_frame


func _test_waypoint_in_the_world(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var hud: SharedGameplayUI = session.shared_ui()
	var here: StringName = session.active_map_id()
	hud.menu.present(GameMenu.Tab.MAP)
	await tree.process_frame
	var page: MapPage = hud.map_page
	var way: PortalDefinition = GameContent.catalog().portals_for_map(here)[0]
	page._point(way.destination_map_id, way.destination_zone_id, "there")
	_check(state.waypoint_map == way.destination_map_id, "a line on the card sets 指路: %s" % state.waypoint_map)
	_check(page.status.text.contains("there"), "and says so: %s" % page.status.text)
	var unknown: StringName = &"choyin.guye"
	page._point(unknown, &"", "far")
	_check(state.waypoint_map == way.destination_map_id and not page.status.text.is_empty(), "no walked road: the 指路 stands, the page says so")
	hud.menu.close()
	await tree.process_frame
	await _test_marker(tree, session, way)
	state.waypoint_map = here
	state.waypoint_zone = &""
	session.record_journal()
	_check(state.waypoint_map.is_empty(), "standing there folds it up")


## The world's marker: a 指路 stands over the way out, labelled so; with none it is the quest's.
func _test_marker(tree: SceneTree, session: WorldSessionController, way: PortalDefinition) -> void:
	var state: CharacterState = session.player_runtime().state
	var view: WorldVoxelView = (session.active_map() as Node).get_node_or_null("MapView") as WorldVoxelView
	if view == null:
		return
	view._sync_quest_marker()
	await tree.process_frame
	_check(view.quest_marker != null, "the 指路 has its marker")
	var labels: Array[Node] = [] if view.quest_marker == null else view.quest_marker.find_children("*", "Label3D", true, false)
	_check(labels.size() == 1 and (labels[0] as Label3D).text == "指路", "written 指路")
	_check(view.quest_marker != null and view.quest_marker.get_meta("way", &"") == way.portal_id, "over the way out: %s" % way.portal_id)
	MapAtlas.point_to(state, &"")
	view._sync_quest_marker()
	await tree.process_frame
	var goal: MapAtlas.Goal = MapAtlas.goal(GameContent.catalog(), state)
	_check(goal == null or view.quest_marker != null, "the quest's marker comes back on its own")
	MapAtlas.point_to(state, way.destination_map_id, way.destination_zone_id)


func _test_classic(tree: SceneTree, session: WorldSessionController) -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	_check(pacing.map_page and not PacePresets.of(pacing, CharacterState.PACE_CLASSIC).map_page, "现代 has the page, 经典 not")
	pacing.with_map_page(false)
	var hud: SharedGameplayUI = session.shared_ui()
	var menu: GameMenu = hud.menu
	menu.present(GameMenu.Tab.JOURNAL)
	await tree.process_frame
	_check(not menu.tab_buttons[GameMenu.Tab.MAP].visible, "no 地图 tab")
	menu.step_tab(1)
	_check(menu.current_tab() == GameMenu.Tab.STANDING, "Q/E step over it")
	menu.show_tab(GameMenu.Tab.MAP)
	_check(menu.current_tab() == GameMenu.Tab.STANDING, "nothing opens it")
	pacing.with_map_page(true)
	menu.close()
	await tree.process_frame


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures.append(label)
