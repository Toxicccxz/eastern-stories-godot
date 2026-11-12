class_name BattleNameplates
extends Control

## 战斗演出 E (DECISIONS「战斗演出 E」): a name plate under each fighter's feet on the raised stage —
## the card that stands with its person (owner 2026-11-08: the cards and the two sides did not
## read). Each plate: the name in its side's colour (the player's side 铜绿, the other 朱漆), a
## thin 气 bar as the person's card shows it, the side's colour down its edge, gold all round on the
## current target; dimmed when it cannot be picked, 倒 / 亡 after the name when fallen. Those in a
## back rank (standing behind another) wear a thin plate over their head instead; plates still on
## one another (a crowd) move to the nearest free place (lay_out()), so no two ever overlap. A click on an enemy's plate makes them the target; the hover is their
## card's. Presentation only.

signal target_requested(participant_id: StringName)

const FRONT_SIZE: Vector2 = Vector2(124, 30)
const BACK_SIZE: Vector2 = Vector2(100, 22)
const MIN_WIDTH: float = 84.0
## At least this far apart (px), plate from plate.
const PLATE_GAP: float = 4.0
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
## The last lay_out(): its boxes and ranks, and where it put them (each frame the same while
## no one and no camera moved).
var _laid_from: Array = []
var _laid: Array[Rect2] = []
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
		plate.mouse_filter = Control.MOUSE_FILTER_STOP if plate.pickable else Control.MOUSE_FILTER_IGNORE
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
	var shown: bool = view != null and is_instance_valid(view) and view.camera != null and view.placing() and (opening == null or not opening.running())
	var placed: Array[Plate] = []
	var boxes: Array[Rect2] = []
	var backs: Array[bool] = []
	for id: StringName in _plates:
		var plate: Plate = _plates[id]
		# Only those standing on the stage (one never seated stands on the map under it).
		if not shown or not view.actors.has(id) or view.placed_at(id) == null:
			plate.visible = false
			continue
		var actor: Node3D = view.actors[id]
		plate.back = opening != null and opening.back_rank(id)
		var plate_size: Vector2 = BACK_SIZE if plate.back else FRONT_SIZE
		var at: Vector2
		if plate.back:
			at = view.camera.unproject_position(actor.global_position + Vector3.UP * HEAD_RISE) - Vector2(plate_size.x * 0.5, plate_size.y)
		else:
			at = view.camera.unproject_position(actor.global_position) + Vector2(-plate_size.x * 0.5, UNDER_PX)
		placed.append(plate)
		# The viewport's own coordinates, as BattleMoveTitles places the names over heads.
		boxes.append(Rect2(at, plate_size))
		backs.append(plate.back)
	var key: Array = [boxes, backs]
	if key != _laid_from:
		_laid_from = key
		_laid = lay_out(boxes, backs)
	var laid: Array[Rect2] = _laid
	for index: int in placed.size():
		var plate: Plate = placed[index]
		plate.position = laid[index].position
		plate.size = laid[index].size
		plate.visible = true
		plate.queue_redraw()


## Where the plates go, from `boxes` (each at its person: under the feet, or over the head when
## `backs` says a back rank): plates of one rank closer than their width narrowed to fit (at
## least MIN_WIDTH, the name cut); then any still on one another moved off, each in turn to the
## nearest free place (a front plate not up over its person, a back one not down onto them), so
## no two plates ever overlap (a crowd of one kind: owner 2026-11-11, five 黑冠巨蟒).
static func lay_out(boxes: Array[Rect2], backs: Array[bool]) -> Array[Rect2]:
	var laid: Array[Rect2] = boxes.duplicate()
	for back: bool in [false, true]:
		var row: Array[int] = []
		for index: int in laid.size():
			if backs[index] == back:
				row.append(index)
		row.sort_custom(func(a: int, b: int) -> bool: return laid[a].get_center().x < laid[b].get_center().x)
		for at: int in range(1, row.size()):
			var before: int = row[at - 1]
			var gap: float = laid[row[at]].get_center().x - laid[before].get_center().x
			var width: float = maxf(MIN_WIDTH, minf(laid[row[at]].size.x, gap - PLATE_GAP))
			for index: int in [before, row[at]]:
				if laid[index].size.x > width:
					var middle: float = laid[index].get_center().x
					laid[index].size.x = width
					laid[index].position.x = middle - width * 0.5
	# Front plates first (left to right), then the back ones: the earlier stay where they are.
	var order: Array[int] = []
	order.assign(range(laid.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		if backs[a] != backs[b]:
			return not backs[a]
		return laid[a].get_center().x < laid[b].get_center().x)
	var settled: Array[Rect2] = []
	for index: int in order:
		laid[index] = _free_place(laid[index], backs[index], settled)
		settled.append(laid[index])
	for index: int in laid.size():
		laid[index].position = laid[index].position.round()
	return laid


## `box` where it is if it is clear of `taken` (with PLATE_GAP between), else the nearest clear
## place made of the edges of those in the way: a front plate moves sideways or down, a back one
## sideways or up (a step the wrong way costs three times as much).
static func _free_place(box: Rect2, back: bool, taken: Array[Rect2]) -> Rect2:
	if _clear(box, taken):
		return box
	var xs: Array[float] = [box.position.x]
	var ys: Array[float] = [box.position.y]
	for other: Rect2 in taken:
		xs.append(other.position.x - box.size.x - PLATE_GAP)
		xs.append(other.end.x + PLATE_GAP)
		ys.append(other.position.y - box.size.y - PLATE_GAP)
		ys.append(other.end.y + PLATE_GAP)
	var best := Rect2()
	var best_cost: float = INF
	for x: float in xs:
		for y: float in ys:
			var dy: float = y - box.position.y
			var wrong_way: bool = dy > 0.0 if back else dy < 0.0
			var cost: float = absf(x - box.position.x) + absf(dy) * (3.0 if wrong_way else 1.0)
			if cost >= best_cost:
				continue
			var candidate := Rect2(Vector2(x, y), box.size)
			if _clear(candidate, taken):
				best = candidate
				best_cost = cost
	# Never empty: straight up over the highest one (or down under the lowest) is always clear.
	return best if best_cost < INF else box


static func _clear(box: Rect2, taken: Array[Rect2]) -> bool:
	var padded: Rect2 = box.grow(PLATE_GAP * 0.5 - 0.01)
	for other: Rect2 in taken:
		if padded.intersects(other.grow(PLATE_GAP * 0.5 - 0.01)):
			return false
	return true


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
