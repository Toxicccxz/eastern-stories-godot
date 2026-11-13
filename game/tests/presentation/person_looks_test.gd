extends RefCounted

## 人物外观 (DECISIONS「人物外观」): a card per person drives their voxel figure; their flat-colour
## 立绘 show in the dialogue box (the NPC right, the player left) and on 查看.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
## Keys a card may carry, and which of them are colours.
const COLOURS: Array[String] = ["coat", "pants", "skin", "hair", "hair_tie", "accent", "collar_color", "collar_shade", "headwear_color", "apron_color", "prop_color", "metal", "wood", "towel", "shoe_color", "nose", "bracer_color", "wrap_color", "pouch_color", "tassel_color", "armor_color", "bundle_color", "shield_color", "lantern_color"]
const WORDS: Dictionary = {
	"hair_style": Person.HAIR_STYLES, "headwear": Person.HEADWEAR, "beard": Person.BEARDS,
	"waist": Person.WAISTS, "prop": Person.PROPS, "shoes": ["dark", "straw", "white"],
}
const OTHER_KEYS: Array[String] = ["note", "height", "build", "extras", "pouch", "collar", "hat", "scale", "name_alpha"]
const KINDS: Array[String] = ["full", "bust", "bust_smile", "bust_angry"]
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_cards()
	_check_portrait_files()
	_check_resolve()
	_check_spawned_looks()
	await _check_figures(tree)
	await _check_light_figures(tree)
	await _check_in_the_inn(tree)
	await _check_big_screen(tree)
	return {"assertions": assertions, "failures": failures}


## Every card uses the closed list the figure draws, its colours are colours, and it belongs to
## someone: an NPC definition or the player.
func _check_cards() -> void:
	var known: Dictionary = {}
	for region: String in DirAccess.get_directories_at("res://data"):
		var path: String = "res://data/%s/npcs.json" % region
		if FileAccess.file_exists(path):
			for npc: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary).get("npcs", []):
				known[String(npc.get("id", ""))] = true
	var cards: int = 0
	for region: String in DirAccess.get_directories_at("res://data"):
		if not FileAccess.file_exists("res://data/%s/appearances.json" % region):
			continue
		var people: Dictionary = PersonLooks.region_cards(region)
		_check(not people.is_empty(), "%s/appearances.json reads" % region)
		for id: String in people:
			cards += 1
			_check(id.get_slice(".", 0) == region or (region == "common" and id.begins_with("player.")), "%s's card is in its region's file (%s)" % [id, region])
			# A role whose gender is drawn (旅客) has a card per gender: `<id>.male` / `<id>.female`.
			var base: String = id.trim_suffix(".male").trim_suffix(".female")
			_check(known.has(id) or (base != id and known.has(base)) or id in ["player.male", "player.female"], "%s is someone" % id)
			var card: Dictionary = people[id]
			for key: String in card:
				if COLOURS.has(key):
					_check(String(card[key]).is_valid_html_color() and not String(card[key]).begins_with("#") and String(card[key]).length() == 6, "%s's %s is a colour: %s" % [id, key, card[key]])
				elif WORDS.has(key):
					_check((WORDS[key] as Array).has(String(card[key])), "%s's %s is one the figure draws: %s" % [id, key, card[key]])
				elif key == "height":
					_check(Person.HEIGHTS.has(String(card[key])), "%s's height: %s" % [id, card[key]])
				elif key == "build":
					_check(Person.BUILDS.has(String(card[key])), "%s's build: %s" % [id, card[key]])
				elif key == "extras":
					for extra: Variant in card[key]:
						_check(Person.EXTRAS.has(String(extra)), "%s's extra: %s" % [id, extra])
				elif key in ["pouch", "collar", "hat"]:
					_check(card[key] is bool, "%s's %s is a switch: %s" % [id, key, card[key]])
				elif key == PersonLooks.SAME_AS:
					var target: String = String(card[key])
					var theirs: Dictionary = PersonLooks.region_cards(target.get_slice(".", 0)).get(target, {})
					_check(card.size() == 1 and not theirs.is_empty() and not theirs.has(PersonLooks.SAME_AS), "%s is the same person as %s, who has a card of their own" % [id, target])
				else:
					_check(OTHER_KEYS.has(key), "%s's card key %s is read" % [id, key])
	_check(cards >= 4, "the first cards are there: %d" % cards)
	_check(not PersonLooks.player(String(CharacterState.GENDER_MALE)).is_empty() and PersonLooks.player(String(CharacterState.GENDER_FEMALE)) != PersonLooks.player(String(CharacterState.GENDER_MALE)), "a card for each player")


## Every picture is `<id>_<kind>.png` at its own size, of someone with a card, the whole body and
## the bust both there.
func _check_portrait_files() -> void:
	var ids: Dictionary = {}
	for file: String in DirAccess.get_files_at(PersonPortraits.DIR):
		if not file.ends_with(".png"):
			continue
		var stem: String = file.get_basename()
		var kind: String = ""
		for candidate: String in KINDS:
			if stem.ends_with("_" + candidate) and candidate.length() > kind.length():
				kind = candidate
		_check(not kind.is_empty(), "%s is a full, bust or face" % file)
		if kind.is_empty():
			continue
		var id: String = stem.trim_suffix("_" + kind)
		ids[id] = true
		var picture: Texture2D = PersonPortraits.texture(id, kind)
		var size: Vector2i = PersonPortraits.FULL_SIZE if kind == "full" else PersonPortraits.BUST_SIZE
		_check(picture != null and Vector2i(picture.get_size()) == size, "%s is %s: %s" % [file, size, picture.get_size() if picture != null else Vector2.ZERO])
		var image: Image = picture.get_image() if picture != null else null
		if image != null:
			# Clean edges: no half-seen pixels left from the cut-out, and no ring of the magenta
			# key's colour round the outline (a key-like colour found almost only there; a real
			# plum or rose shade lies mostly inside the body).
			var soft: int = 0
			var keyish: Dictionary = {}
			for y: int in image.get_height():
				for x: int in image.get_width():
					var colour: Color = image.get_pixel(x, y)
					if colour.a > 0.02 and colour.a < 0.98:
						soft += 1
					if colour.a > 0.5 and colour.r > colour.g + 0.12 and colour.b > colour.g + 0.12 and absf(colour.r - colour.b) < 0.24 and colour.g < 0.32:
						var count: Vector2i = keyish.get(colour, Vector2i.ZERO)
						keyish[colour] = count + Vector2i(1, 1 if _on_outline(image, x, y) else 0)
			_check(soft == 0, "%s has hard edges: %d soft pixels" % [file, soft])
			var ring: int = 0
			for colour: Color in keyish:
				var count: Vector2i = keyish[colour]
				if count.x >= 3 and count.y >= count.x * 0.8:
					ring += count.y
			_check(ring == 0, "%s has no key-colour ring round it: %d pixels" % [file, ring])
	for id: String in ids:
		_check(PersonPortraits.full(id) != null and PersonPortraits.bust(id) != null, "%s has a whole picture and a bust" % id)
		_check(not PersonLooks.card(id).is_empty(), "%s has a card for the map" % id)
		# The face their attitude talks with is drawn: a friendly one's smile, an attacker's anger.
		var definition: NpcDefinition = null if id.begins_with("player.") else GameContent.catalog().npc(StringName(id.trim_suffix(".male").trim_suffix(".female")))
		if definition != null:
			var face: String = PersonPortraits.expression(NpcRuntimeState.new(&"test.face", definition, &"", &"", CharacterState.new()))
			_check(face.is_empty() or PersonPortraits.texture(id, "bust_" + face) != null, "%s has the %s face their attitude talks with" % [id, face])
	_check(ids.has("snow.npc.waiter") and ids.has("player.male") and ids.has("player.female"), "the inn's waiter and both players have pictures")
	_check(PersonPortraits.bust("snow.npc.waiter", "smile") == PersonPortraits.texture("snow.npc.waiter", "bust_smile"), "a face when there is one")
	_check(PersonPortraits.bust("snow.npc.waiter", "sleepy") == PersonPortraits.texture("snow.npc.waiter", "bust"), "the plain bust otherwise")
	_check(PersonPortraits.full("nobody.npc.at_all") == null, "someone without a picture shows none")
	_check(PersonPortraits.fitted(PersonPortraits.BUST_SIZE, Vector2(300, 300), 1.5) == Vector2(128, 128) * 2 / 1.5, "two whole multiples in 300 screen pixels")
	_check(PersonPortraits.fitted(PersonPortraits.FULL_SIZE, Vector2(1000, 100), 1.0) == Vector2(128, 256), "never under one")


## A card with the map's own entry over it; without a card the entry alone (as before cards);
## with neither the map's default.
func _check_resolve() -> void:
	var actors: Dictionary = {"default": {"coat": "111111", "hat": true}, "snow.npc.waiter": {"scale": 1.2}, "x.npc.plain": {"coat": "222222"}}
	var waiter: Dictionary = PersonLooks.resolve(actors, "snow.npc.waiter")
	_check(waiter.get("waist") == "apron" and is_equal_approx(float(waiter.get("scale", 0.0)), 1.2) and not waiter.has("hat"), "the waiter's card, the map's scale over it, not the map's default: %s" % [waiter])
	_check(PersonLooks.resolve(actors, "x.npc.plain") == {"coat": "222222"}, "no card: the map's entry alone")
	_check(PersonLooks.resolve(actors, "x.npc.nobody") == actors["default"], "neither: the map's default")
	# A drawn gender picks `<id>.female` / `<id>.male` when there is one, else `<id>`.
	var people: Dictionary = PersonLooks.region_cards("snow")
	_check(PersonLooks.card("snow.npc.waiter", String(CharacterState.GENDER_MALE)) == people["snow.npc.waiter"], "no card for his gender: his own")
	for sex: StringName in [CharacterState.GENDER_MALE, CharacterState.GENDER_FEMALE]:
		var id: String = PersonLooks.with_sex("snow.npc.traveller", String(sex))
		_check(people.has(id) and PersonLooks.card("snow.npc.traveller", String(sex)) == people[id], "a %s traveller's own card: %s" % [sex, id])
	# The same person under two definitions: 隘口's 黑衣道士 wears the cave's card and pictures.
	_check(PersonLooks.shown_id("native.npc.black_taoist_pass") == "native.npc.black_taoist" and not PersonLooks.card("native.npc.black_taoist_pass").is_empty() and PersonLooks.card("native.npc.black_taoist_pass") == PersonLooks.card("native.npc.black_taoist"), "隘口's 黑衣道士 is the cave's")
	var pass_taoist := NpcRuntimeState.new(&"test.pass", GameContent.catalog().npc(&"native.npc.black_taoist_pass"), &"", &"", CharacterState.new())
	_check(PersonPortraits.npc_id(pass_taoist) == "native.npc.black_taoist" and PersonPortraits.full(PersonPortraits.npc_id(pass_taoist)) != null, "and his pictures")
	var her: Dictionary = PersonLooks.region_cards("common").get("player.female", {})
	_check(not her.is_empty() and PersonLooks.resolve({}, "", PersonLooks.player(String(CharacterState.GENDER_FEMALE))) == her, "the player's card by their gender")


## Everyone a spawn puts on a map looks like someone there: a card of their own (or one per drawn
## gender), or an entry in that map's voxel `actors`; never the map's default figure alone. A beast
## (race beast) resolves to an animal (`animal`) or a body (crawler, flyer, snake …), never a person.
func _check_spawned_looks() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var configs: Dictionary = {}
	var missing: Array[String] = []
	var people_beasts: Array[String] = []
	for spawn: NpcSpawnDefinition in catalog.spawns():
		var id: String = String(NpcDefinition.unnamed_id(spawn.npc_definition_id))
		var map: MapDefinition = catalog.map(spawn.map_id)
		if map == null:
			continue
		if not configs.has(map.map_id):
			configs[map.map_id] = _voxel_actors(map.scene_path)
		var actors: Dictionary = configs[map.map_id]
		var carded: bool = not PersonLooks.card(id).is_empty() or not PersonLooks.card(id, String(CharacterState.GENDER_MALE)).is_empty() or not PersonLooks.card(id, String(CharacterState.GENDER_FEMALE)).is_empty()
		if not carded and not actors.has(id):
			missing.append("%s on %s" % [id, map.map_id])
			continue
		var npc: NpcDefinition = catalog.npc(StringName(id))
		if npc != null and npc.race_id == &"beast":
			var look: Dictionary = PersonLooks.resolve(actors, id)
			if not look.get("animal", false) and not look.has("body"):
				people_beasts.append("%s on %s" % [id, map.map_id])
	_check(missing.is_empty(), "every spawned NPC has a card or an entry on its map: missing %s" % [missing])
	_check(people_beasts.is_empty(), "every spawned beast is an animal or a body, not a person: %s" % [people_beasts])


## The `actors` of the voxel config a painted map's scene names (its WorldVoxelView's layout_path).
func _voxel_actors(scene_path: String) -> Dictionary:
	var scene: String = FileAccess.get_file_as_string(scene_path)
	var found: RegExMatch = RegEx.create_from_string("layout_path = \"([^\"]+)\"").search(scene)
	if found == null:
		return {}
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(found.get_string(1)))
	return (config as Dictionary).get("actors", {}) if config is Dictionary else {}


## The figure draws what its look names and nothing more; every word on the list builds.
func _check_figures(tree: SceneTree) -> void:
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var plain: Node3D = Person.new()
	stage.add_child(plain)
	_check(plain.drawn.is_empty() and plain.coat == "397c87", "a figure without a look is the plain townsperson")
	var waiter: Node3D = Person.new()
	waiter.configure(PersonLooks.card("snow.npc.waiter"))
	stage.add_child(waiter)
	for part: String in ["apron", "prop:teapot", "headwear:cloth_cap", "short_hair", "towel_neck"]:
		_check(waiter.drawn.has(part), "the waiter's figure has %s: %s" % [part, waiter.drawn])
	var girl: Node3D = Person.new()
	girl.configure(PersonLooks.card("snow.npc.girl"))
	stage.add_child(girl)
	_check(girl.drawn.has("double_bun") and girl.drawn.has("prop:sword_waist") and girl.drawn.has("sash"), "柳绘心's twin buns, sash and sword: %s" % [girl.drawn])
	var child: Node3D = Person.new()
	child.configure({"height": "child"})
	stage.add_child(child)
	var tall: Node3D = Person.new()
	tall.configure({"height": "tall", "build": "heavy"})
	stage.add_child(tall)
	_check(child.legs[0].position.y < plain.legs[0].position.y and tall.legs[0].position.y > plain.legs[0].position.y, "height lengthens the legs: %.2f %.2f %.2f" % [child.legs[0].position.y, plain.legs[0].position.y, tall.legs[0].position.y])
	_check(absf(tall.arms[0].position.x) > absf(plain.arms[0].position.x), "a heavy build sets the arms wider")
	var bare: Node3D = Person.new()
	bare.configure({"collar": false, "pouch": false, "collar_color": "e0d0b0"})
	stage.add_child(bare)
	_check(bare.torso != null and bare.frame.get_child_count() > 2, "the collar and pouch switches and the collar's colour build")
	for key: String in WORDS:
		for word: Variant in WORDS[key]:
			var figure: Node3D = Person.new()
			figure.configure({key: word})
			stage.add_child(figure)
			_check(figure.torso != null and figure.frame.get_child_count() > 0, "%s %s builds" % [key, word])
	for extra: String in Person.EXTRAS:
		var figure: Node3D = Person.new()
		figure.configure({"extras": [extra]})
		stage.add_child(figure)
		_check(figure.drawn == PackedStringArray([extra]), "the extra %s, and nothing else: %s" % [extra, figure.drawn])
	var tail: Node3D = Person.new()
	tail.configure({"hair_style": "ponytail", "headwear": "cloth_cap"})
	stage.add_child(tail)
	_check(tail.drawn.has("ponytail") and not tail.drawn.has("ponytail_tie"), "under a cap the tail still hangs, the tie on the crown is hidden: %s" % [tail.drawn])
	var bare_tail: Node3D = Person.new()
	bare_tail.configure({"hair_style": "ponytail"})
	stage.add_child(bare_tail)
	_check(bare_tail.drawn.has("ponytail") and bare_tail.drawn.has("ponytail_tie"), "without one, the tie and the tail: %s" % [bare_tail.drawn])
	await tree.process_frame
	stage.queue_free()
	await tree.process_frame


## A figure costs little to draw and nothing to stand: a limb's plain colours are one batch
## (their colours kept, on the instances), and a part is written only when it moves — one set
## to the place it has is still sent to the renderer with everything on it, every frame.
func _check_light_figures(tree: SceneTree) -> void:
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var waiter: Node3D = Person.new()
	waiter.configure(PersonLooks.card("snow.npc.waiter"))
	stage.add_child(waiter)
	var batches: int = 0
	var boxes: int = 0
	var colours: Dictionary[String, bool] = {}
	for node: Node in waiter.find_children("*", "MultiMeshInstance3D", true, false):
		var batch: MultiMesh = (node as MultiMeshInstance3D).multimesh
		batches += 1
		boxes += batch.instance_count
		for index: int in batch.instance_count:
			if batch.use_colors:
				colours[batch.get_instance_color(index).linear_to_srgb().to_html(false)] = true
	_check(batches <= 12 and boxes >= 30, "the waiter is %d boxes in %d batches: a limb's plain colours are one" % [boxes, batches])
	# The headless dummy renderer keeps no instance colours: the windowed pass reads them.
	if DisplayServer.get_name() != "headless":
		for key: String in ["coat", "pants", "skin", "hair"]:
			var hex: String = Color(String(PersonLooks.card("snow.npc.waiter").get(key, ""))).to_html(false)
			_check(colours.has(hex), "the waiter's %s (%s) is still on him: %s" % [key, hex, str(colours.keys())])
	# Standing: nothing is written but the breath's few steps and a blink. A counter under a
	# part hears of each frame in which the part was written, changed or not.
	var plain: Node3D = Person.new()
	stage.add_child(plain)
	var watch: Dictionary[String, MoveCount] = {}
	for part: Array in [["leg", plain.legs[0]], ["arm", plain.arms[0]], ["torso", plain.torso]]:
		var counter := MoveCount.new()
		(part[1] as Node3D).add_child(counter)
		counter.set_notify_transform(true)
		watch[part[0]] = counter
	await _frames(tree, 2)
	plain.clock = 0.2
	for counter: MoveCount in watch.values():
		counter.moves = 0
	await _frames(tree, 120)
	# An arm hangs from the torso: it moves with the breath, never by itself.
	_check(watch["leg"].moves == 0 and watch["arm"].moves <= watch["torso"].moves, "two seconds standing: the legs are not written once, the left arm only with the torso (%d, %d, %d)" % [watch["leg"].moves, watch["arm"].moves, watch["torso"].moves])
	_check(watch["torso"].moves > 0 and watch["torso"].moves <= 20, "the breath goes in steps, a few a second: written in %d frames of 120" % watch["torso"].moves)
	# Walking writes every frame, as it must; standing again stops.
	plain.walking = true
	await _frames(tree, 2)
	for counter: MoveCount in watch.values():
		counter.moves = 0
	await _frames(tree, 30)
	_check(watch["leg"].moves >= 28 and watch["arm"].moves >= 28, "walking: the limbs swing every frame (%d, %d of 30)" % [watch["leg"].moves, watch["arm"].moves])
	plain.walking = false
	await _frames(tree, 2)
	plain.clock = 0.2
	for counter: MoveCount in watch.values():
		counter.moves = 0
	await _frames(tree, 30)
	_check(watch["leg"].moves == 0 and watch["arm"].moves <= watch["torso"].moves and is_zero_approx(plain.legs[0].rotation.x) and is_zero_approx(plain.arms[0].rotation.x), "stopped: back at rest, and still (%d, %d, %d)" % [watch["leg"].moves, watch["arm"].moves, watch["torso"].moves])
	# One at work goes on moving; one sitting keeps the seat and the sunk hip.
	var smith: Node3D = Person.new()
	smith.activity("hammer", "stand")
	stage.add_child(smith)
	var swing := MoveCount.new()
	smith.arms[0].add_child(swing)
	swing.set_notify_transform(true)
	await _frames(tree, 2)
	swing.moves = 0
	var before: float = smith.arms[0].rotation.x
	var moved: bool = false
	for _frame: int in 60:
		await tree.process_frame
		moved = moved or not is_equal_approx(smith.arms[0].rotation.x, before)
	_check(moved and swing.moves >= 56, "one at the anvil goes on hammering: written in %d frames of 60" % swing.moves)
	var sitter: Node3D = Person.new()
	sitter.activity("", "sit")
	stage.add_child(sitter)
	await _frames(tree, 2)
	_check(is_equal_approx(sitter.legs[0].rotation.x, Person.POSE_LEGS["sit"]) and is_equal_approx(sitter.legs[1].rotation.x, Person.POSE_LEGS["sit"]) and sitter.legs[0].position.y < plain.legs[0].position.y, "one sitting: both legs forward, the hip sunk")
	stage.queue_free()
	await tree.process_frame


## Counts the times the part above it is written (its transform set, changed or not).
class MoveCount:
	extends Node3D
	var moves: int = 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			moves += 1


## In the inn: the waiter's figure wears his card, the player hers; talking with him shows both
## busts, 查看 shows his whole picture, a page hides it.
func _check_in_the_inn(tree: SceneTree) -> void:
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var inn := session.active_map() as WorldMapController
	var view := inn.get_node("MapView") as WorldVoxelView
	var waiter_body: WorldCharacterBody2D = inn.runtime_body_for_spawn_point(&"snow.inn.main_floor.inn.waiter.1")
	_check(waiter_body != null and view.actors.has(waiter_body.character_id), "the waiter stands in the inn")
	if waiter_body == null:
		session.free()
		return
	var figure: Node3D = view.actors[waiter_body.character_id].get_child(0) as Node3D
	_check(figure is Person and (figure as Person).drawn.has("apron") and (figure as Person).coat == "e9dcc3", "the waiter's figure wears his card")
	var player_figure: Node3D = view.actors[inn.player_body.character_id].get_child(0) as Node3D
	_check(player_figure is Person and (player_figure as Person).coat == String(PersonLooks.player(String(CharacterState.GENDER_FEMALE)).get("coat")), "the player wears the female player's card")
	var waiter: NpcRuntimeState = inn.npcs.find_resident_npc(waiter_body.character_id)
	# 旅客 draw their gender (traveller.c): each wears the card and shows the pictures of the one
	# it drew.
	var travellers: int = 0
	for npc: NpcRuntimeState in inn.npc_runtimes():
		if String(NpcDefinition.unnamed_id(npc.definition().definition_id)) != "snow.npc.traveller" or not view.actors.has(npc.character_id):
			continue
		travellers += 1
		var gender: String = String(npc.character_state.gender)
		var worn: Node3D = view.actors[npc.character_id].get_child(0) as Node3D
		_check(worn is Person and (worn as Person).coat == String(PersonLooks.card("snow.npc.traveller", gender).get("coat", "")), "a %s 旅客 wears that card" % gender)
		_check(PersonPortraits.npc_id(npc) == PersonLooks.with_sex("snow.npc.traveller", gender), "and has those pictures: %s" % PersonPortraits.npc_id(npc))
	_check(travellers > 0, "旅客 in the inn")
	var hud: SharedGameplayUI = session.shared_ui()
	var box: WorldDialogueBox = hud.dialogue_box
	TestFeel.use()
	inn.npc_life.teller = waiter.character_id
	var said: Array[ColoredLine] = [ColoredLine.new("店小二说道：客官里面请。")]
	hud.npc_says(waiter, said, ["店小二说道：客官里面请。"])
	inn.npc_life.teller = &""
	await _frames(tree, 2)
	_check(box.is_open() and box.who() == waiter, "the waiter's line is read in the box")
	_check(box.bust_texture(false) == PersonPortraits.bust("snow.npc.waiter", "smile"), "his smiling bust on the right (a friendly man)")
	_check(box.bust_texture(true) == PersonPortraits.bust("player.female"), "the player's bust on the left")
	_check(box.bust_lit(false) and not box.bust_lit(true), "the speaker lit, the listener dimmed")
	var lifted: float = hud._presentation_layout.toasts.lift
	box.close()
	await _frames(tree, 2)
	_check(not box.bust_shown(false) and not box.bust_shown(true), "no busts with the box shut")
	box.say("", ["一阵风吹过。"])
	await _frames(tree, 2)
	_check(box.is_open() and not box.bust_shown(false) and not box.bust_shown(true), "a line nobody says shows nobody")
	_check(lifted >= hud._presentation_layout.toasts.lift + 100.0, "the toasts stand on the player's bust, not over the face: %.0f, %.0f with no bust" % [lifted, hud._presentation_layout.toasts.lift])
	box.close()
	# Everyone in 雪亭镇 has pictures now: a stranger from 京师 (no pictures yet) speaks.
	var plain := _stranger()
	_check(PersonPortraits.bust(PersonPortraits.npc_id(plain)) == null, "a stranger without a picture")
	box.say(plain.definition().display_name, ["%s说道：嗯。" % plain.definition().display_name], &"", plain)
	await _frames(tree, 2)
	_check(box.is_open() and not box.bust_shown(false) and not box.bust_shown(true), "someone without a picture: no busts, not the player alone")
	box.close()
	TestFeel.restore()
	_check(inn.place_player(&"snow.inn.main_floor", Vector2(0, -105)), "beside the waiter")
	await _frames(tree, 20)
	_check(hud.interact_with(waiter_body.character_id), "the waiter can be looked at")
	await _frames(tree, 3)
	_check(hud.interaction_open() and hud.interaction_panel.portrait() == PersonPortraits.full("snow.npc.waiter"), "查看 shows his whole picture")
	var shown: Vector2 = hud.interaction_panel.portrait_size()
	_check(shown.y > 0.0 and is_equal_approx(fmod(shown.y * hud.get_viewport().get_final_transform().get_scale().x, 256.0), 0.0), "at a whole multiple of its pixels: %s" % shown)
	_check(hud.interaction_panel.press("购买"), "his shop opens")
	await _frames(tree, 2)
	_check(hud.interaction_panel.portrait() == null, "a page has the column to itself")
	hud.dismiss_current_panel()
	await _frames(tree, 2)
	if hud.interaction_open():
		_check(hud.interaction_panel.portrait() != null, "back on 查看, the picture again")
	hud.dismiss_current_panel()
	# ES2's long text keeps the MUD's hard line breaks (herbalist.c: three); the narrower
	# column beside the picture wraps it as one paragraph.
	var herbalist: NpcDefinition = TestContent.npc(&"snow.npc.herbalist")
	hud.selection.show_inspection(herbalist)
	_check(herbalist.description.strip_edges().count("\n") >= 2 and hud.inspection_text.text.get_slice_count("\n") == 2, "杨掌柜's description reads as one paragraph: %s" % hud.inspection_text.text)
	session.free()
	await _frames(tree, 2)


## On a 2560×1440 screen (two screen pixels a canvas unit): 查看's picture keeps its size after a
## page and 返回 (the layout rewrites minimum sizes as it first saw them); hosting someone
## without a picture after the waiter shows no bust and puts the plate back on the left.
func _check_big_screen(tree: SceneTree) -> void:
	var before: Vector2i = tree.root.size
	tree.root.size = Vector2i(2560, 1440)
	var session: WorldSessionController = Work.create_session(tree)
	session.configure_npc_ambience_random_source(Still.Still.new())
	await _frames(tree, 4)
	var inn := session.active_map() as WorldMapController
	var hud: SharedGameplayUI = session.shared_ui()
	var waiter_body: WorldCharacterBody2D = inn.runtime_body_for_spawn_point(&"snow.inn.main_floor.inn.waiter.1")
	_check(waiter_body != null and inn.place_player(&"snow.inn.main_floor", Vector2(0, -105)), "beside the waiter on a big screen")
	if waiter_body == null:
		session.free()
		tree.root.size = before
		return
	await _frames(tree, 20)
	_check(hud.interact_with(waiter_body.character_id), "looked at")
	await _frames(tree, 5)
	var portrait: Control = hud.interaction_panel.get_node("Portrait")
	var first: Vector2 = portrait.size
	_check(first.y >= 256.0, "a big screen shows the picture at least twice its pixels: %s" % first)
	_check(hud.interaction_panel.press("购买"), "his shop")
	await _frames(tree, 3)
	hud.dismiss_current_panel()
	await _frames(tree, 5)
	if hud.interaction_open():
		_check(portrait.visible and portrait.size == first, "back on 查看, the same size: %s then %s" % [first, portrait.size])
	hud.dismiss_current_panel()
	await _frames(tree, 3)
	var box: WorldDialogueBox = hud.dialogue_box
	var waiter: NpcRuntimeState = inn.npcs.find_resident_npc(waiter_body.character_id)
	var plain := _stranger()
	var content := Control.new()
	hud.add_child(content)
	box.host("店小二", content, waiter)
	_check(box.bust_shown(false) and box.bust_shown(true), "hosting the waiter: both busts at once")
	# 打听 takes turns: the player's to choose, the NPC's to answer, the player's own line again.
	_check(box.bust_lit(true) and not box.bust_lit(false), "the topics: the player's turn")
	box.answer(["店小二说道：客官里面请。"])
	_check(box.bust_lit(false) and not box.bust_lit(true), "his answer: he is lit, the player dimmed")
	box.answer_as_written(["你向店小二打听有关「这里」的消息。"])
	_check(box.bust_lit(true) and not box.bust_lit(false), "the player's own line: the player lit")
	var plate: Control = box.get_node("NamePlate")
	_check(plate.position.x > box.get_node("Box").position.x + box.get_node("Box").size.x / 2.0, "the plate beside his bust on the right")
	box.host("旁人", content, plain)
	_check(not box.bust_shown(false) and not box.bust_shown(true), "then someone without a picture: no busts at once")
	_check(plate.position.x < box.get_node("Box").position.x + box.get_node("Box").size.x / 2.0, "the plate back on the left")
	box.close()
	content.queue_free()
	session.free()
	await _frames(tree, 2)
	tree.root.size = before


## Someone from a region whose people have no pictures yet (乔阴's old man).
## Someone made up here, so no region's pictures ever reach them.
func _stranger() -> NpcRuntimeState:
	return NpcRuntimeState.new(&"test.stranger", NpcDefinition.new(&"test.npc.stranger", "", "路人"), &"", &"", CharacterState.new())


## Whether the pixel touches a see-through one or the picture's edge.
func _on_outline(image: Image, x: int, y: int) -> bool:
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var at: Vector2i = Vector2i(x, y) + step
		if at.x < 0 or at.y < 0 or at.x >= image.get_width() or at.y >= image.get_height() or image.get_pixelv(at).a < 0.5:
			return true
	return false


func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in count:
		await tree.process_frame


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
