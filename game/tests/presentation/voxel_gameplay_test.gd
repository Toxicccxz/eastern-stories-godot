extends RefCounted

const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
var assertions: int = 0
var failures: Array[String] = []

func run_all(tree: SceneTree) -> Dictionary:
	for scene: String in ["snow_inn","snow_inn_upstairs","snow_outdoor"]:
		_check_furnishings(load("res://scenes/world/snow/%s.tscn" % scene) as PackedScene,scene)
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree,4)
	var inn := session.active_map() as WorldMapController
	var view := inn.get_node("MapView") as WorldVoxelView
	_check(inn.map_id()==&"snow.inn" and inn.projected_view and view.camera.current,"New Game uses the live inn's 3D presentation")
	var basis: Basis = view.camera.basis
	var state: WorldPlayerRuntimeState = session.player_runtime()
	var inventory: InventoryState = session.inventory_state()
	var waiter: WorldCharacterBody2D = inn.runtime_body_for_spawn_point(&"snow.inn.main_floor.inn.waiter.1")
	_check(waiter != null and view.actors.has(waiter.character_id),"authored waiter has a 3D body")
	_check(inn.place_player(&"snow.inn.main_floor",Vector2(0,-105)),"place within waiter reach")
	await _frames(tree,20)
	var point: Vector2 = view.camera.unproject_position(view.actors[waiter.character_id].position+Vector3.UP)
	_check(view.pick_at(point)==waiter.character_id,"click projection identifies the actual waiter")
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tree.root.push_input(click,true)
	click.pressed = false
	tree.root.push_input(click,true)
	var hud: SharedGameplayUI = session.shared_ui()
	_check(hud.interaction_open() and inn.selected_character_id()==waiter.character_id,"3D click opens original NPC interaction")
	_check(hud.interaction_panel.press("购买"),"original vendor action still opens")
	_check(hud._presentation_layout.page()!=null,"vendor goods are shown in the original panel")
	hud.dismiss_current_panel()
	hud.dismiss_current_panel()
	await _frames(tree,3)
	var day_night := hud.find_child("DayNight",true,false) as VoxelDayNightButton
	_check(day_night!=null and day_night.is_visible_in_tree(),"3D exploration shows the day/night button")
	click.position = day_night.get_global_rect().get_center()
	click.pressed = true
	tree.root.push_input(click,true)
	click.pressed = false
	tree.root.push_input(click,true)
	await _frames(tree,65)
	_check(day_night.night and view.night and is_equal_approx(view.lighting.amount,1.0),"a real HUD click completes the night lighting transition")
	_check(view.camera.basis.is_equal_approx(basis),"talking never rotates the view")
	_check(await MapPlaces.take_passage(tree,inn,&"snow.inn.up"),"the furnished inn still has a walkable route to its original stairs")
	await _frames(tree,4)
	var upstairs := session.active_map() as WorldMapController
	var up_view := upstairs.get_node("MapView") as WorldVoxelView
	_check(upstairs.map_id()==&"snow.inn_upstairs" and upstairs.projected_view and up_view.camera.current,"upstairs uses its own 3D presentation")
	_check(up_view.camera.basis.is_equal_approx(basis) and up_view.night,"upstairs keeps the fixed angle and the chosen lighting")
	var rats: int = 0
	var quiet_names: int = 0
	var rat_id: StringName = &""
	for npc: NpcRuntimeState in upstairs.npc_runtimes():
		var actor: Node3D = up_view.actors.get(npc.character_id)
		if npc.definition().definition_id==&"snow.npc.rat" and actor!=null and not (actor.get_child(0) is Person) and (actor.get_child(0) as Node3D).scale.x<1.0:
			rats += 1
			# The southern-most rat: the corridor north of it is open floor to stand on.
			var body: WorldCharacterBody2D = upstairs.runtime_body_for_character(npc.character_id)
			if rat_id.is_empty() or body.global_position.y>upstairs.runtime_body_for_character(rat_id).global_position.y:
				rat_id = npc.character_id
			if not up_view.labels[rat_id].visible:
				quiet_names += 1
	_check(rats==6,"the six corridor rats have small animal bodies: %d" % rats)
	_check(quiet_names==6,"distant rats do not fill the arrival view with names")
	var rat_actor: Node3D = up_view.actors[rat_id]
	_check(up_view.pick_at(up_view.camera.unproject_position(rat_actor.position+Vector3.UP*0.30))==rat_id,"a rat with a hidden name is still pickable")
	var arrival: Vector2 = upstairs.player_body.global_position
	var rat_body: WorldCharacterBody2D = upstairs.runtime_body_for_character(rat_id)
	# Original interactions need 96px reach; the name's proximity reveal is only 60px.
	_check(upstairs.place_player(&"snow.inn_2f",rat_body.global_position+Vector2(0,-80)),"approach within interaction reach but outside name proximity")
	await _frames(tree,8)
	_check(rat_body.global_position.distance_to(upstairs.player_body.global_position)<96.0,"the player stands within the rat's reach: %s" % [rat_body.global_position-upstairs.player_body.global_position])
	click.position = up_view.camera.unproject_position(rat_actor.position+Vector3.UP*0.30)
	click.pressed = true
	tree.root.push_input(click,true)
	click.pressed = false
	tree.root.push_input(click,true)
	_check(hud.interaction_open() and upstairs.selected_character_id()==rat_id,"clicking a rat still opens its original interaction")
	await _frames(tree,2)
	_check(up_view.labels[rat_id].visible,"selecting a rat reveals its name outside the proximity range")
	hud.dismiss_current_panel()
	upstairs.selection.selected_target = null
	_check(upstairs.place_player(&"snow.inn_2f",rat_body.global_position+Vector2(0,-48)),"approach a rat without touching its collision")
	await _frames(tree,2)
	_check(up_view.labels[rat_id].visible,"a nearby rat's name is readable without selection")
	_check(upstairs.place_player(&"snow.inn_2f",arrival),"return to the upstairs arrival")
	await _frames(tree,2)
	_check(not up_view.labels[rat_id].visible,"leaving the rat restores the quiet label state")
	_check(view.geometry.unknown_kinds.is_empty() and up_view.geometry.unknown_kinds.is_empty(),"every inn prop kind is drawn: %s" % [view.geometry.unknown_kinds+up_view.geometry.unknown_kinds])
	_check(up_view.geometry.low_wall(Vector2(0,240)) and not up_view.geometry.low_wall(Vector2(0,-464)),"near walls are cut away, the far north wall stands")
	var cut_occludes: bool = false
	for entry: Dictionary in up_view.geometry.occluders:
		cut_occludes = cut_occludes or entry["node"]==up_view.geometry._low_walls
	_check(not cut_occludes,"knee-high cut walls never fade around a nearby actor")
	var north: StringName = &"snow.inn_2f.north_door"
	_check(await MapPlaces.drive(tree,upstairs,MapPlaces.door_spot(upstairs,north,&"snow.inn_2f")),"walk the corridor to the north 房门")
	_check(up_view.shutters[north].visible,"the shut 房门 shows its leaf")
	_check(upstairs.open_door(north),"open the north 房门 within reach")
	await _frames(tree,2)
	_check(not up_view.shutters[north].visible,"an open 房门 leaves only its frame")
	_check(upstairs.close_door(north),"shut it again")
	_check(await MapPlaces.take_passage(tree,upstairs,&"snow.inn_2f.down"),"stairs return to the same furnished inn")
	await _frames(tree,4)
	_check(inn.projected_view and view.night,"returning downstairs keeps the chosen lighting and original view")
	_check(await MapPlaces.drive(tree,inn,Vector2(310,0)),"walk original collision path to east exit")
	_check(await MapPlaces.take_passage(tree,inn,&"snow.inn.east"),"walking out uses the original portal")
	await _frames(tree,4)
	var outdoor := session.active_map() as WorldMapController
	_check(outdoor.map_id()==&"snow.outdoor" and outdoor.projected_view,"street activates its 3D view")
	_check(session.player_runtime()==state and session.inventory_state()==inventory,"crossing keeps exact player and inventory identities")
	var street_view := outdoor.get_node("MapView") as WorldVoxelView
	_check(street_view.geometry.unknown_kinds.is_empty(),"every street prop kind is drawn: %s" % [street_view.geometry.unknown_kinds])
	_check(street_view.geometry._ground_style(Vector2(0,0),"town_ground").get("style","")=="slabs" and street_view.geometry._ground_style(Vector2(0,-1000),"street").get("style","")=="slabs",
		"the square and the streets are laid in big slabs (square.c: 整齐地铺著大石板)")
	_check(street_view.geometry._ground_style(Vector2(-1100,800),"street").get("style","")=="paving","the 官道 west of town stays 青石板 (sroad3.c)")
	_check("maple" in street_view.geometry._flora_at(Vector2(-1760,416)).get("tree_types",[]),"the 官道's stone leaves the first maples of 水烟阁's slopes by sroad5")
	var land: VoxelLandmass = street_view.geometry.landmass
	var supported: bool = land!=null
	for node: Node in outdoor.find_children("*","Area2D",true,false):
		if node is WorldPhysicalZoneArea2D:
			var rect: Rect2 = (node as WorldPhysicalZoneArea2D).global_rect()
			for y: int in range(floori(rect.position.y),ceili(rect.end.y),16):
				for x: int in range(floori(rect.position.x),ceili(rect.end.x),16):
					supported = supported and land.contains(Vector2(x,y))
	for rect: Rect2 in street_view.geometry.footprints:
		for y: int in range(floori(rect.position.y),ceili(rect.end.y),16):
			for x: int in range(floori(rect.position.x),ceili(rect.end.x),16):
				supported = supported and land.contains(Vector2(x,y))
	_check(supported,"every live walkable zone and building remains on the finite landmass")
	_check(not land.contains(outdoor.drawn_rect().end+Vector2(300,300)),"the map no longer fills the 640 pixel perimeter with scenery")
	_check(street_view.night and is_equal_approx(street_view.lighting.amount,1.0),"night selection follows the player from inn to street")
	var before: Vector2 = outdoor.player_body.global_position
	Input.action_press("move_right")
	await _frames(tree,12)
	MapPlaces.release()
	var moved: Vector2 = outdoor.player_body.global_position-before
	var screen_move: Vector2 = outdoor.view_ground.basis_xform(moved)
	_check(screen_move.x>10 and absf(screen_move.y)<2,"D moves right on the screen with fixed angled camera")
	# The mill faces away from the camera. Only local fragments around the player/door
	# fade; every roof and wall remains present and the original portal still works.
	var mill := MapPlaces.passage(outdoor,&"snow.mstreet2.east")
	_check(outdoor.place_player(&"snow.mstreet2",Vector2(32,-1040)),"stand at rear-facing mill approach")
	await _frames(tree,5)
	_check((street_view.entrances[mill.portal_id]["node"] as Node3D).visible,"rear-facing entrance marker is visible near its door")
	var intact: bool = true
	for entry: Dictionary in street_view.geometry.occluders:
		intact = intact and (entry["node"] as Node3D).visible
	_check(intact,"local reveal never hides an entire building or crown")
	_check(not street_view.occlusion.materials.is_empty(),"actual occluders use the fragment reveal material")
	var player_point: Vector3 = VoxelMapGeometry.point(outdoor.player_body.global_position,1.0)
	var player_revealed: bool = false
	for subject: Vector4 in street_view.occlusion.subjects:
		player_revealed = player_revealed or Vector3(subject.x,subject.y,subject.z).distance_to(player_point)<0.1
	_check(street_view.occlusion.subjects[0].w>1.6,"the local subject opening is wider than the original narrow radius")
	_check(player_revealed,"the player has a compact world-space reveal centre")
	_check(street_view.occlusion.subjects.size()>1,"nearby visible NPCs have their own local reveals")
	var people_only: bool = true
	for subject: Vector4 in street_view.occlusion.subjects:
		var actual_person: bool = false
		for actor: Node3D in street_view.actors.values():
			var model := actor.get_child(0) as Node3D
			var centre: Vector3 = model.to_global(Vector3.UP*(1.0 if model is Person else 0.5))
			actual_person = actual_person or (actor.visible and actor.position.distance_squared_to(VoxelMapGeometry.point(outdoor.player_body.global_position))<=196 and centre.distance_to(Vector3(subject.x,subject.y,subject.z))<0.01)
		people_only = people_only and actual_person
	_check(people_only,"local transparency follows only the player and nearby visible actors, never an empty doorway")
	var foliage: VoxelFoliage = street_view.geometry.foliage
	_check(foliage.roots.size()>100 and foliage.flowers.size()>50,"real outdoor grass and flower clusters are instanced")
	# Crossing foliage leaves a short contact trace, then it recovers without a save/state edit.
	var touches := PackedVector3Array([Vector3(0,0,0)])
	foliage.advance(0.01,touches)
	touches[0] = Vector3(0.4,0,0)
	foliage.advance(0.01,touches)
	_check(not foliage.trails.is_empty(),"moving contact leaves a grass recovery trail")
	foliage.advance(1.0,PackedVector3Array())
	_check(foliage.trails.is_empty() and foliage.contacts.is_empty(),"vacated grass recovers after contact fades")
	_check(street_view.camera.basis.is_equal_approx(basis),"same fixed camera angle in the street")
	_check(await MapPlaces.take_passage(tree,outdoor,mill.portal_id),"the revealed mill entrance is physically usable")
	await _frames(tree,4)
	var mill_map := session.active_map() as WorldMapController
	_check(day_night.visible and day_night.night,"the mill retains the session's lighting preference and switch")
	_check(mill_map.map_id()==&"snow.workplace_house" and mill_map.projected_view,"the original mill entrance now activates its voxel interior")
	var mill_view := mill_map.get_node("MapView") as WorldVoxelView
	_check(mill_view.camera.current and mill_view.night,"the mill takes over the 3D camera in the chosen lighting")
	_check(await MapPlaces.take_passage(tree,mill_map,&"snow.workplace.west"),"walk back to the street")
	await _frames(tree,4)
	_check(outdoor.projected_view and street_view.camera.current,"resident 3D street reactivates on return")
	_check(street_view.night and day_night.visible,"returning from the mill restores the selected night view and switch")
	# View state cannot alter saves or consume gameplay RNG. Freeze the world for the comparison.
	session.set_process(false)
	var saved: String = GameSaveJsonCodec.encode(Work.capture(session)).text
	day_night.pressed.emit()
	street_view.lighting.advance(1.0,VoxelMapGeometry.point(outdoor.player_body.global_position))
	_check(not street_view.night and is_zero_approx(street_view.lighting.amount),"the same button switches back to daylight")
	street_view.camera.size += 2.0
	street_view._follow(0.0)
	street_view._update_occlusion()
	_check(GameSaveJsonCodec.encode(Work.capture(session)).text==saved,"day/night, zoom and cutaway change no saved game state")
	var check_restore := Work.new()
	await check_restore.round_trip(tree,session,Work.capture(session),"voxel street")
	assertions += check_restore._count
	failures.append_array(check_restore._failures)
	session.free()
	await _frames(tree,2)
	return {"assertions":assertions,"failures":failures}

## Every furnishing the 3D view draws stands on its own blocked box: one footprint for the
## model and the collision (tools/maps/layouts, painted into the scene's Furnishings).
func _check_furnishings(packed: PackedScene, scene: String) -> void:
	var map: Node2D = packed.instantiate()
	var structures := map.find_child("TerrainStructures",true,false) as TileMapLayer
	# Outside the tree: the layer's place within the map, through its parents.
	var into_layer := Transform2D.IDENTITY
	var parent: Node = structures
	while parent != map:
		into_layer = (parent as Node2D).transform*into_layer
		parent = parent.get_parent()
	into_layer = into_layer.affine_inverse()
	var furnishings: Node = map.get_node_or_null("Furnishings")
	var count: int = 0
	var blocked: bool = true
	for node: Node in ([] if furnishings == null else furnishings.get_children()):
		var spot := node as Node2D
		var box: Vector2 = spot.get_meta("footprint")
		count += 1
		var corner := Vector2i(spot.position-box/2)
		for y: int in range(corner.y+8,corner.y+int(box.y),16):
			for x: int in range(corner.x+8,corner.x+int(box.x),16):
				var tile: TileData = structures.get_cell_tile_data(structures.local_to_map(into_layer*Vector2(x,y)))
				blocked = blocked and tile != null and String(tile.get_custom_data("terrain"))=="blocked"
	_check(count>0 and blocked,"%s: each of its %d furnishings stands on its blocked layout box" % [scene,count])
	map.free()

func _frames(tree: SceneTree, count: int) -> void:
	for frame: int in count:
		await tree.physics_frame
		await tree.process_frame

func _check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
