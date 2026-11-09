class_name BattleNameplates
extends Control

## 战斗演出 E (DECISIONS「战斗演出 E」): a name plate under each fighter's feet on the raised stage —
## the card that stands with its person (owner 2026-11-08: the cards and the two sides did not
## read). Each plate: the name in its side's colour (the player's side 铜绿, the other 朱漆), a
## thin 气 bar as the person's card shows it, the side's colour down its edge, gold all round on the
## current target; dimmed when it cannot be picked, 倒 / 亡 after the name when fallen. Those in a
## back rank (standing behind another) wear a thin plate over their head instead, so no two plates
## ever lie on one another. A click on an enemy's plate makes them the target; the hover is their
## card's. Presentation only.

signal target_requested(participant_id: StringName)

const FRONT_SIZE: Vector2 = Vector2(124, 30)
const BACK_SIZE: Vector2 = Vector2(100, 22)
const MIN_WIDTH: float = 84.0
## Under the feet / over the head (units over the figure's feet).
const UNDER_PX: float = 6.0
const HEAD_RISE: float = 2.15
const BAR_BACK: Color = Color("1a120d")
const BAR_FILL: Color = Color("c9534a")
const BAR_FILL_MINE: Color = Color("6fb89c")
const PLATE: Color = Color(0.09, 0.06, 0.05, 0.88)
const DIMMED: Color = Color(0.6, 0.6, 0.6, 0.75)

## Each plate: id -> Plate.
var _plates: Dictionary[StringName, Plate] = {}
var view: WorldVoxelView
var opening: BattleStageOpening


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The fighters now: [id, name, hostile, current, targetable, fallen text, card] each.
func present(entries: Array, p_view: WorldVoxelView, p_opening: BattleStageOpening) -> void:
	view = p_view
	opening = p_opening
	var seen: Dictionary[StringName, bool] = {}
	var sides: Dictionary = BattleArena.data().get("sides", {})
	for entry: Array in entries:
		var id: StringName = entry[0]
		seen[id] = true
		var plate: Plate = _plates.get(id)
		if plate == null:
			plate = Plate.new()
			plate.name = "Plate_" + String(id)
			plate.participant_id = id
			plate.clicked.connect(func(who: StringName) -> void: target_requested.emit(who))
			add_child(plate)
			_plates[id] = plate
		var hostile: bool = entry[2]
		plate.title = String(entry[1]) + ("" if String(entry[5]).is_empty() else " · " + String(entry[5]))
		plate.hostile = hostile
		plate.current = entry[3]
		plate.pickable = hostile and bool(entry[4])
		plate.edge = Color(String(sides.get("theirs" if hostile else "mine", "c8402a" if hostile else "4f8f78")))
		plate.name_colour = Color(String(sides.get("name_theirs" if hostile else "name_mine", "f39a80" if hostile else "9fdcc4")))
		plate.card = entry[6]
		plate.mouse_filter = Control.MOUSE_FILTER_STOP if plate.pickable else Control.MOUSE_FILTER_PASS
		var card: BattleParticipantCard = entry[6]
		plate.tooltip_text = card.target_button.tooltip_text if card != null else ""
		plate.queue_redraw()
	for id: StringName in _plates.keys():
		if not seen.has(id):
			_plates[id].queue_free()
			_plates.erase(id)
	_place()


## Every plate gone (the fight is over).
func clear() -> void:
	for plate: Plate in _plates.values():
		plate.queue_free()
	_plates.clear()
	view = null


## `id`'s plate, or null (tests).
func plate(id: StringName) -> Control:
	return _plates.get(id)


## The plates shown now (tests): id -> [rect, back rank].
func shown() -> Dictionary:
	var result: Dictionary = {}
	for id: StringName in _plates:
		if _plates[id].visible:
			result[id] = [_plates[id].get_rect(), _plates[id].back]
	return result


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	var ready: bool = view != null and is_instance_valid(view) and view.camera != null and view.placing() and (opening == null or not opening.running())
	for id: StringName in _plates:
		var plate: Plate = _plates[id]
		if not ready or not view.actors.has(id):
			plate.visible = false
			continue
		var actor: Node3D = view.actors[id]
		plate.back = opening != null and opening.back_rank(id)
		var size: Vector2 = BACK_SIZE if plate.back else FRONT_SIZE
		var at: Vector2
		if plate.back:
			at = view.camera.unproject_position(actor.global_position + Vector3.UP * HEAD_RISE) - Vector2(size.x * 0.5, size.y)
		else:
			at = view.camera.unproject_position(actor.global_position) + Vector2(-size.x * 0.5, UNDER_PX)
		# The viewport's own coordinates, as BattleMoveTitles places the names over heads.
		plate.size = size
		plate.position = at.round()
		plate.visible = true
		plate.queue_redraw()
	_spread()


## Plates of one rank closer than their width: narrowed to fit (at least MIN_WIDTH), the name cut.
func _spread() -> void:
	for back: bool in [false, true]:
		var row: Array[Plate] = []
		for plate: Plate in _plates.values():
			if plate.visible and plate.back == back:
				row.append(plate)
		row.sort_custom(func(a: Plate, b: Plate) -> bool: return a.position.x < b.position.x)
		for index: int in range(1, row.size()):
			var before: Plate = row[index - 1]
			var gap: float = (row[index].position.x + row[index].size.x * 0.5) - (before.position.x + before.size.x * 0.5)
			var width: float = maxf(MIN_WIDTH, minf(row[index].size.x, gap - 8.0))
			for plate: Plate in [before, row[index]]:
				if plate.size.x > width:
					var middle: float = plate.position.x + plate.size.x * 0.5
					plate.size.x = width
					plate.position.x = roundf(middle - width * 0.5)


## One plate (drawn, not built of nodes).
class Plate extends Control:
	signal clicked(participant_id: StringName)
	var participant_id: StringName
	var title: String = ""
	var hostile: bool = false
	var current: bool = false
	var pickable: bool = false
	var back: bool = false
	var edge: Color = UiPalette.PATINA
	var name_colour: Color = UiPalette.BONE
	var card: BattleParticipantCard

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if pickable and button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(participant_id)
			accept_event()

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		var tint: Color = Color.WHITE if (pickable or not hostile or current) else DIMMED
		draw_rect(box, Color(PLATE, PLATE.a * tint.a))
		# The side's colour down the edge facing the middle (the player's side: right; theirs: left).
		var x: float = box.end.x - 3.0 if not hostile else 0.0
		draw_rect(Rect2(Vector2(x, 0), Vector2(3, box.size.y)), edge * tint)
		if current:
			draw_rect(box, UiPalette.LANTERN, false, 2.0)
		var font: Font = get_theme_default_font()
		var font_size: int = GameTheme.text_size(12 if back else 14)
		var bar_height: float = 4.0 if back else 6.0
		var text_room: float = box.size.x - 12.0
		var shown: String = _fit(font, title, font_size, text_room)
		draw_string(font, Vector2(6, font.get_ascent(font_size) + 2), shown, HORIZONTAL_ALIGNMENT_LEFT, text_room, font_size, name_colour * tint)
		var bar := Rect2(Vector2(6, box.size.y - bar_height - 4), Vector2(box.size.x - 12, bar_height))
		draw_rect(bar, BAR_BACK)
		var share: float = 0.0
		if card != null and is_instance_valid(card) and card._vitality.max_value > 0.0:
			share = clampf(card.vitality_shown() / card._vitality.max_value, 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), (BAR_FILL if hostile else BAR_FILL_MINE) * tint)

	static func _fit(font: Font, text: String, font_size: int, room: float) -> String:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
			return text
		var cut: String = text
		while cut.length() > 1 and font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
			cut = cut.left(cut.length() - 1)
		return cut + "…"
