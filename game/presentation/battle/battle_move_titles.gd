class_name BattleMoveTitles
extends Control

## 战斗演出 C (DECISIONS「战斗演出 C」): a move's name over the attacker's head in the scene (owner
## 2026-11-08: the names were stiff, the same for every weapon). In the brush hand, coloured by
## the wound the blow deals (an edge's pale gold, a blunt blow's bone, a whip's or a claw's
## green; a special's gold and larger), and brought in by what it was struck with
## (battle_stage.json moves): a sword's name drops in, a blade's drops with a slant, a whip's
## lashes in from the side, a hammer's or an axe's drops bigger and slower, a staff's comes up
## from below, a dagger's is small and quick, a thrown weapon's comes a beat late behind a
## streak, a bare hand's small. It follows the figure (its point over the head, each frame).
## The panel shows only the names that matter to the player — their own moves, those at them,
## a felling blow, a special's opening — and at most `shown` at once (the oldest not the
## player's goes first). Presentation only.

const BRUSH_OUTLINE: Color = Color(0.05, 0.03, 0.02, 0.92)
const SLIDE_PX: float = 40.0
const RISE_PX: float = 20.0
const FADE_SECONDS: float = 0.15

## Each name shown: {label, id, mine, offset, streak}.
var _shown: Array[Dictionary] = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(GameTheme.BRUSH_FONT_PATH) as Font


## The names over heads now (tests): [text, actor id] each.
func shown() -> Array[Array]:
	var result: Array[Array] = []
	for entry: Dictionary in _shown:
		if is_instance_valid(entry["label"]):
			result.append([(entry["label"] as Label).text, entry["id"]])
	return result


## The name `text` over `actor_id`'s figure in `view` (the blow `line`: its weapon and wound;
## `special`: a special's opening, gold and larger; `mine`: the player is in it). False when the
## figure is not in the scene (the card shows the name instead).
func show_title(view: WorldVoxelView, line: BattleNarrationLine, text: String, special: bool, mine: bool) -> bool:
	if view == null or not is_instance_valid(view) or view.camera == null or not view.actors.has(line.actor_id) or text.is_empty():
		return false
	var moves: Dictionary = BattleArena.data().get("moves", {})
	var look: Dictionary = BattleSounds.weapon_look(line.weapon_skill)
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var hold: float = feel.special_title_seconds if special else feel.move_title_seconds
	if hold <= 0.0:
		return true # The names are off: nothing over the head, nor on the card.
	if not _make_room(int(moves.get("shown", 3)), mine):
		return true # Three of the player's own stand: this one, not theirs, is not shown.
	var label := Label.new()
	label.name = "MoveTitle"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _font)
	var size: float = float(look.get("size", 34))
	if special:
		size *= float(moves.get("special_scale", 1.2)) * 1.25
	label.add_theme_font_size_override("font_size", roundi(size))
	var colours: Dictionary = moves.get("colours", {})
	var colour := Color(String(moves.get("special_colour", "e9b84c")))
	if not special and colours.has(line.damage_type):
		colour = Color(String(colours[line.damage_type]))
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", BRUSH_OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	var entry: Dictionary = {"label": label, "id": line.actor_id, "mine": mine, "offset": Vector2.ZERO, "streak": null, "view": view}
	_shown.append(entry)
	_animate(entry, String(look.get("motion", "slam")) if not special else "heavy", hold)
	_place(entry)
	return true


## Room for one more once `limit` stand: the oldest not the player's goes; when all are the
## player's, the oldest goes for another of theirs (`mine`), and one not theirs gets no room.
func _make_room(limit: int, mine: bool) -> bool:
	_shown = _shown.filter(func(entry: Dictionary) -> bool: return is_instance_valid(entry["label"]))
	while _shown.size() >= maxi(1, limit):
		var drop: int = -1
		for index: int in _shown.size():
			if not _shown[index]["mine"]:
				drop = index
				break
		if drop < 0:
			if not mine:
				return false
			drop = 0
		_remove(_shown[drop])
	return true


func _remove(entry: Dictionary) -> void:
	_shown.erase(entry)
	for key: String in ["label", "streak"]:
		var node: Variant = entry.get(key)
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()


## The motion by the weapon, then the hold, then the fade; the entry goes with the label.
func _animate(entry: Dictionary, motion: String, hold: float) -> void:
	var label: Label = entry["label"]
	# The label's own tween: it goes with the label when a newer name takes its place.
	var tween: Tween = label.create_tween().set_parallel(true)
	var lead: float = 0.0
	match motion:
		"slash":
			label.scale = Vector2.ONE * 1.3
			label.rotation = deg_to_rad(-8.0)
			tween.tween_property(label, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tween.tween_property(label, "rotation", 0.0, 0.14).set_delay(0.06).set_ease(Tween.EASE_OUT)
			lead = 0.2
		"whip":
			entry["offset"] = Vector2(-SLIDE_PX, 0)
			tween.tween_method(func(at: Vector2) -> void: entry["offset"] = at, Vector2(-SLIDE_PX, 0), Vector2.ZERO, 0.09).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
			lead = 0.09
		"heavy":
			label.scale = Vector2.ONE * 1.5
			tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			lead = 0.12
		"rise":
			entry["offset"] = Vector2(0, RISE_PX)
			label.modulate.a = 0.0
			tween.tween_method(func(at: Vector2) -> void: entry["offset"] = at, Vector2(0, RISE_PX), Vector2.ZERO, 0.12).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "modulate:a", 1.0, 0.08)
			lead = 0.12
		"quick":
			label.scale = Vector2.ONE * 1.15
			tween.tween_property(label, "scale", Vector2.ONE, 0.06).set_ease(Tween.EASE_OUT)
			lead = 0.06
		"thrown":
			label.modulate.a = 0.0
			var streak := ColorRect.new()
			streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
			streak.color = Color(label.get_theme_color("font_color"), 0.8)
			streak.size = Vector2(70, 2)
			add_child(streak)
			entry["streak"] = streak
			streak.set_meta("from", -120.0)
			tween.tween_method(func(at: float) -> void: streak.set_meta("from", at), -120.0, 0.0, 0.06)
			tween.tween_property(streak, "modulate:a", 0.0, 0.12).set_delay(0.06)
			tween.tween_property(label, "modulate:a", 1.0, 0.04).set_delay(0.06)
			lead = 0.1
		"fist":
			label.scale = Vector2.ONE * 1.15
			tween.tween_property(label, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT)
			lead = 0.08
		_:
			label.scale = Vector2.ONE * 1.3
			tween.tween_property(label, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			lead = 0.08
	tween.chain().tween_interval(hold)
	tween.chain().tween_property(label, "modulate:a", 0.0, FADE_SECONDS)
	tween.chain().tween_callback(_remove.bind(entry))
	entry["lead"] = lead


func _process(_delta: float) -> void:
	for entry: Dictionary in _shown.duplicate():
		if not is_instance_valid(entry["label"]):
			_shown.erase(entry)
			continue
		_place(entry)


## The name over its figure's head (the figure's model, raised on the stage or not), the
## motion's offset on it; each name a little above the one before it over the same figure.
func _place(entry: Dictionary) -> void:
	var view: WorldVoxelView = entry["view"]
	var label: Label = entry["label"]
	if view == null or not is_instance_valid(view) or view.camera == null or not view.actors.has(entry["id"]):
		label.visible = false
		return
	var actor: Node3D = view.actors[entry["id"]]
	var model: Node3D = actor.get_child(0) as Node3D if actor.get_child_count() > 0 else actor
	var rise: float = float(BattleArena.data().get("moves", {}).get("rise", 2.3))
	var head: Vector2 = view.camera.unproject_position(model.global_position + Vector3.UP * rise)
	var stack: int = 0
	for other: Dictionary in _shown:
		if other == entry:
			break
		if other["id"] == entry["id"]:
			stack += 1
	label.visible = true
	label.position = head - Vector2(label.size.x * 0.5, label.size.y) + (entry["offset"] as Vector2) - Vector2(0, float(stack) * label.size.y * 0.8)
	var streak: Variant = entry.get("streak")
	if streak != null and is_instance_valid(streak):
		var bar: ColorRect = streak
		bar.position = Vector2(label.position.x + float(bar.get_meta("from", 0.0)) - bar.size.x, label.position.y + label.size.y * 0.55)


## Every name gone (the fight is over).
func clear() -> void:
	for entry: Dictionary in _shown.duplicate():
		_remove(entry)
	_shown.clear()
