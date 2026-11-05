extends RefCounted

## 人物外观 (DECISIONS「人物外观」): a card per person drives their voxel figure; their flat-colour
## 立绘 show in the dialogue box (the NPC right, the player left) and on 查看.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const Still := preload("res://tests/runtime/snow_south_road_test.gd")
const Person := preload("res://presentation/voxel/actors/voxel_person.gd")
## Keys a card may carry, and which of them are colours.
const COLOURS: Array[String] = ["coat", "pants", "skin", "hair", "hair_tie", "accent", "collar_color", "collar_shade", "headwear_color", "apron_color", "prop_color", "metal", "wood", "towel", "shoe_color", "nose", "bracer_color", "wrap_color"]
const WORDS: Dictionary = {
	"hair_style": Person.HAIR_STYLES, "headwear": Person.HEADWEAR, "beard": Person.BEARDS,
	"waist": Person.WAISTS, "prop": Person.PROPS, "shoes": ["dark", "straw", "white"],
}
const OTHER_KEYS: Array[String] = ["note", "height", "build", "extras", "pouch", "collar", "hat", "scale"]
const KINDS: Array[String] = ["full", "bust", "bust_smile", "bust_angry"]
var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary:
	_check_cards()
	_check_portrait_files()
	_check_resolve()
	await _check_figures(tree)
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
			_check(known.has(id) or id in ["player.male", "player.female"], "%s is someone" % id)
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
	var her: Dictionary = PersonLooks.region_cards("common").get("player.female", {})
	_check(not her.is_empty() and PersonLooks.resolve({}, "", PersonLooks.player(String(CharacterState.GENDER_FEMALE))) == her, "the player's card by their gender")


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
	_check(bare.torso != null and bare.get_child_count() > 2, "the collar and pouch switches and the collar's colour build")
	for key: String in WORDS:
		for word: Variant in WORDS[key]:
			var figure: Node3D = Person.new()
			figure.configure({key: word})
			stage.add_child(figure)
			_check(figure.torso != null and figure.get_child_count() > 0, "%s %s builds" % [key, word])
	for extra: String in Person.EXTRAS:
		var figure: Node3D = Person.new()
		figure.configure({"extras": [extra]})
		stage.add_child(figure)
		_check(figure.drawn == PackedStringArray([extra]), "the extra %s, and nothing else: %s" % [extra, figure.drawn])
	var tail: Node3D = Person.new()
	tail.configure({"hair_style": "ponytail", "headwear": "cloth_cap"})
	stage.add_child(tail)
	_check(tail.drawn.has("ponytail"), "a ponytail still hangs below a cap: %s" % [tail.drawn])
	await tree.process_frame
	stage.queue_free()
	await tree.process_frame


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
	box.close()
	await _frames(tree, 2)
	_check(not box.bust_shown(false) and not box.bust_shown(true), "no busts with the box shut")
	box.say("", ["一阵风吹过。"])
	await _frames(tree, 2)
	_check(box.is_open() and not box.bust_shown(false) and not box.bust_shown(true), "a line nobody says shows nobody")
	box.close()
	var plain: NpcRuntimeState = null
	for npc: NpcRuntimeState in inn.npc_runtimes():
		if PersonPortraits.bust(PersonPortraits.npc_id(npc)) == null:
			plain = npc
	_check(plain != null, "someone in the inn without a picture")
	if plain != null:
		inn.npc_life.teller = plain.character_id
		hud.npc_says(plain, said, ["%s说道：嗯。" % plain.definition().display_name])
		inn.npc_life.teller = &""
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
	var plain: NpcRuntimeState = null
	for npc: NpcRuntimeState in inn.npc_runtimes():
		if PersonPortraits.bust(PersonPortraits.npc_id(npc)) == null:
			plain = npc
	var content := Control.new()
	hud.add_child(content)
	box.host("店小二", content, waiter)
	_check(box.bust_shown(false) and box.bust_shown(true), "hosting the waiter: both busts at once")
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
