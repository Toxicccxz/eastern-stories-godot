class_name MapPage
extends Control

## The menu's 地图 page (现代基线 B; DECISIONS「总图」): the 沙盘, every place reached standing on
## it as its own miniature (AtlasPictures), an ordinary way's far end as a 「？」, and a card
## beside it with what the chosen place holds. A line on the card sets 指路: the world's marker
## walks the player there. What the player knows comes from MapAtlas.
##
## Each place is a button: direction keys and the pad walk between them, the view follows,
## confirm goes to the card, left comes back. Mouse: drag to move, wheel to zoom.

## The zoom the page opens at, and from which the chosen place's pins show.
const CLOSE_ZOOM: float = 0.62
const PIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 1.2
const CARD_WIDTH: float = 290.0
const MOVE_SECONDS: float = 0.22
const PIN_COLOURS: Dictionary[StringName, Color] = {
	MapAtlas.TARGET: Color("c8351f"), MapAtlas.MASTER: Color("c98a2e"), MapAtlas.SHOP: Color("3f8a6a"), MapAtlas.BANK: Color("b8862e"),
	MapAtlas.HOCKSHOP: Color("8a6a9a"), MapAtlas.BOUNTY: Color("b0432e"), MapAtlas.ERRAND: Color("3f6a9a"),
}
const GROUND: Color = Color("20282a")

## Asks the menu to refit after the card changed its rows.
var rows_changed: Callable
var sand: Control
var stage: Node2D
var overlay: Control
var card: PanelContainer
var rows: VBoxContainer
var status: Label
var zoom_button: Button
## The places shown, by map ID.
var cell_buttons: Dictionary[StringName, Button] = {}
## The card's lines that set 指路.
var row_buttons: Array[Button] = []
var arrow: TextureRect
var _pictures: AtlasPictures
var _pins: Array[Control] = []
var _state: CharacterState
var _here_map: StringName
var _here_zone: StringName
var _selected: StringName
var _marks: Array[MapAtlas.Mark] = []
var _zoom: float = CLOSE_ZOOM
var _centre: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _move: Tween
## The stage sprites by map ID.
var _sprites: Dictionary[StringName, Sprite2D] = {}


func _init() -> void:
	name = "MapPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 320)
	sand = Control.new()
	sand.name = "Sand"
	sand.clip_contents = true
	sand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sand.mouse_filter = Control.MOUSE_FILTER_STOP
	sand.gui_input.connect(_sand_input)
	sand.resized.connect(_apply_view)
	add_child(sand)
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.color = GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sand.add_child(ground)
	stage = Node2D.new()
	stage.name = "Stage"
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sand.add_child(stage)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sand.add_child(overlay)
	arrow = TextureRect.new()
	arrow.name = "Arrow"
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.size = Vector2(26, 42)
	arrow.hide()
	overlay.add_child(arrow)
	_build_card()


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -CARD_WIDTH
	card.add_theme_stylebox_override("panel", _card_style())
	add_child(card)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)
	status = _text(column, "", SharedGameplayLayout.ACCENT_COLOR)
	status.name = "Status"
	zoom_button = Button.new()
	zoom_button.name = "Zoom"
	zoom_button.pressed.connect(_toggle_zoom)
	column.add_child(zoom_button)


## Shows the world as `state` knows it, the view on the player, who stands in `map_id`.
func fill(state: CharacterState, map_id: StringName, zone_id: StringName) -> void:
	if state == null:
		return
	if _pictures == null:
		_pictures = AtlasPictures.read()
	_state = state
	_here_map = map_id
	_here_zone = zone_id
	_clear_cells()
	var catalog: ContentCatalog = GameContent.catalog()
	var shown: Array[AtlasCell] = catalog.atlas().cells()
	shown.sort_custom(func(a: AtlasCell, b: AtlasCell) -> bool: return a.at.x + a.at.y < b.at.x + b.at.y)
	for cell: AtlasCell in shown:
		var seen: MapAtlas.Seen = MapAtlas.seen(catalog, state, cell.map_id)
		if seen == MapAtlas.Seen.REACHED and _pictures.has_picture(cell.map_id):
			_show_picture(cell)
		if seen != MapAtlas.Seen.UNSEEN:
			_add_cell_button(cell, seen)
	_link_cells()
	var home: StringName = catalog.atlas().home_of(catalog, map_id)
	if not cell_buttons.has(home) and not cell_buttons.is_empty():
		home = cell_buttons.keys()[0]
	_zoom = clampf(_zoom, _fit_zoom(), MAX_ZOOM)
	if cell_buttons.has(home):
		_centre = _middle(home)
		_select(home)
	_show_goal()
	_apply_view()


## Keys and pad start on the chosen place (GameMenu.focus_page()).
func focus_target() -> Control:
	return cell_buttons.get(_selected)


func _clear_cells() -> void:
	for button: Button in cell_buttons.values():
		overlay.remove_child(button)
		button.queue_free()
	cell_buttons.clear()
	for sprite: Sprite2D in _sprites.values():
		sprite.hide()


func _show_picture(cell: AtlasCell) -> void:
	var sprite: Sprite2D = _sprites.get(cell.map_id)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = String(cell.map_id).replace(".", "_")
		sprite.texture = _pictures.texture(cell.map_id)
		sprite.centered = false
		sprite.position = _pictures.corner(cell.map_id, cell.at)
		_sprites[cell.map_id] = sprite
		stage.add_child(sprite)
	sprite.show()
	stage.move_child(sprite, -1)


func _add_cell_button(cell: AtlasCell, seen: MapAtlas.Seen) -> void:
	var button := Button.new()
	button.name = "Cell_" + String(cell.map_id).replace(".", "_")
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = "？" if seen == MapAtlas.Seen.ROAD else tr(cell.name)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _plate_style(Color("2a1c10", 0.82), Color("d8b070", 0.6)))
	button.add_theme_stylebox_override("hover", _plate_style(Color("4a3018", 0.92), Color("f0d090", 0.9)))
	button.add_theme_stylebox_override("pressed", _plate_style(Color("4a3018", 0.92), Color("f0d090", 0.9)))
	button.add_theme_stylebox_override("focus", _plate_style(Color(0, 0, 0, 0), Color("ffe6a8"), 2))
	button.focus_entered.connect(_select.bind(cell.map_id))
	button.pressed.connect(_enter_card.bind(cell.map_id))
	overlay.add_child(button)
	cell_buttons[cell.map_id] = button


## The neighbours of each place on the 沙盘: the nearest one within a quarter turn of the way
## pressed, none when none lies that way.
func _link_cells() -> void:
	var ways: Dictionary[StringName, Vector2] = {&"focus_neighbor_left": Vector2.LEFT, &"focus_neighbor_right": Vector2.RIGHT, &"focus_neighbor_top": Vector2.UP, &"focus_neighbor_bottom": Vector2.DOWN}
	for map_id: StringName in cell_buttons:
		var button: Button = cell_buttons[map_id]
		for property: StringName in ways:
			var best: StringName = map_id
			var nearest: float = INF
			for other: StringName in cell_buttons:
				var gap: Vector2 = _middle(other) - _middle(map_id)
				if other == map_id or gap.normalized().dot(ways[property]) < 0.6:
					continue
				var cost: float = gap.length() * (2.0 - gap.normalized().dot(ways[property]))
				if cost < nearest:
					nearest = cost
					best = other
			button.set(property, button.get_path_to(cell_buttons[best]))


func _cell(map_id: StringName) -> AtlasCell:
	return GameContent.catalog().atlas().cell(map_id)


## The middle of a place on the 沙盘.
func _middle(map_id: StringName) -> Vector2:
	return _pictures.to_stage(_cell(map_id).at)


func _select(map_id: StringName) -> void:
	_selected = map_id
	status.text = ""
	_fill_card()
	_show_pins()
	if _zoom > _fit_zoom():
		_move_to(_middle(map_id))


func _move_to(place: Vector2) -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = create_tween()
	_move.tween_method(func(at: Vector2) -> void:
		_centre = at
		_apply_view(), _centre, place, MOVE_SECONDS)


func _enter_card(map_id: StringName) -> void:
	if _selected != map_id:
		_select(map_id)
	if not row_buttons.is_empty():
		FocusNav.give(row_buttons[0])


# --- the card ---


func _fill_card() -> void:
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	row_buttons.clear()
	_marks.clear()
	var catalog: ContentCatalog = GameContent.catalog()
	var seen: MapAtlas.Seen = MapAtlas.seen(catalog, _state, _selected)
	if seen == MapAtlas.Seen.ROAD:
		# TRANSLATORS: the 地图 page's card for a place a road leads to that the player has not reached.
		_text(rows, tr("这条路通向哪里，走了才知道。"), SharedGameplayLayout.MUTED_COLOR)
		_finish_rows()
		return
	var cell: AtlasCell = _cell(_selected)
	var title: Label = _text(rows, tr(cell.name), SharedGameplayLayout.ACCENT_COLOR)
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 20)
	var region: RegionDefinition = catalog.region(catalog.map(_selected).region_id)
	if region != null and region.recommended_exp > 0:
		# TRANSLATORS: the 地图 page's card: the combat experience the place is meant for.
		_text(rows, tr("适合经验 {exp} 上下").format({"exp": region.recommended_exp}), SharedGameplayLayout.MUTED_COLOR)
	# TRANSLATORS: the 地图 page's card: shows the way to this place.
	_row(tr("指路到这里"), _point.bind(_selected, &"", tr(cell.name)))
	_marks = MapAtlas.marks(catalog, _state, _selected)
	for mark: MapAtlas.Mark in _marks:
		var place: String = tr(catalog.zone(mark.zone_id).display_name)
		if mark.kind == MapAtlas.TARGET:
			_objective_line(tr(mark.who))
			_row("%s  %s" % [_pin_word(mark.kind), place], _point.bind(mark.map_id, mark.zone_id, place))
		elif tr(mark.who) == place:
			_row("%s  %s" % [_pin_word(mark.kind), place], _point.bind(mark.map_id, mark.zone_id, place))
		else:
			# TRANSLATORS: a line on the 地图 page's card: {word} the mark, {who} the person, {place} the room they are in.
			_row(tr("{word}  {who} · {place}").format({"word": _pin_word(mark.kind), "who": tr(mark.who), "place": place}), _point.bind(mark.map_id, mark.zone_id, place))
	for map_id: StringName in MapAtlas.known_maps(catalog, _state, _selected):
		if map_id != _selected and _state.visited_maps.has(String(map_id)):
			var place: String = tr(_map_name(catalog, map_id))
			_row("· " + place, _point.bind(map_id, &"", place))
	var goal: MapAtlas.Goal = MapAtlas.goal(catalog, _state)
	if goal != null and not goal.waypoint and MapAtlas.arrow_cell(catalog, _state, _here_map, goal.map_id) == _selected and not _has_target_mark():
		_objective_line(tr(StoryQuestLog.objective(_state, catalog.story_quests())))
	if not _state.waypoint_map.is_empty():
		# TRANSLATORS: the 地图 page's card: takes back the 指路 the player set.
		_row(tr("取消指路"), _clear_waypoint)
	var left: int = MapAtlas.unvisited(catalog, _state, _selected)
	if left > 0:
		# TRANSLATORS: the 地图 page's card: {count} buildings or places here the player has not been in.
		_text(rows, tr("还有 {count} 处没进去过").format({"count": left}), SharedGameplayLayout.MUTED_COLOR)
	_finish_rows()


func _objective_line(objective: String) -> void:
	# TRANSLATORS: the 地图 page's card: {objective} the tracked quest's next step.
	_text(rows, tr("目标  {objective}").format({"objective": objective}), PIN_COLOURS[MapAtlas.TARGET].lightened(0.3))


func _has_target_mark() -> bool:
	for mark: MapAtlas.Mark in _marks:
		if mark.kind == MapAtlas.TARGET:
			return true
	return false


## A map has no name of its own: the room the way in leads to names it.
func _map_name(catalog: ContentCatalog, map_id: StringName) -> String:
	var zones: Array[ZoneDefinition] = catalog.zones_for_map(map_id)
	return "" if zones.is_empty() else zones[0].display_name


func _finish_rows() -> void:
	# Left comes back to the place; up and down stay on the card; nothing lies to its right.
	var place: Button = cell_buttons.get(_selected)
	var column: Array[Button] = row_buttons.duplicate()
	column.append(zoom_button)
	for index: int in column.size():
		var row: Button = column[index]
		if place != null:
			row.focus_neighbor_left = row.get_path_to(place)
		row.focus_neighbor_right = row.get_path_to(row)
		row.focus_neighbor_top = row.get_path_to(column[maxi(index - 1, 0)])
		row.focus_neighbor_bottom = row.get_path_to(column[mini(index + 1, column.size() - 1)])
	if rows_changed.is_valid():
		rows_changed.call()
	_show_zoom_label()


func _row(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.tooltip_text = text
	button.pressed.connect(pressed)
	rows.add_child(button)
	row_buttons.append(button)
	return button


func _text(parent: Node, text: String, color: Color) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## The way to a place: the player's choice stands until they get there or take it back.
func _point(map_id: StringName, zone_id: StringName, place: String) -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	if _here_map == map_id and (zone_id.is_empty() or zone_id == _here_zone):
		# TRANSLATORS: 指路 to where the player already stands.
		status.text = tr("你就在这里。")
		return
	if not MapAtlas.can_walk(catalog, _state, _here_map, map_id):
		# TRANSLATORS: 指路 to a place the roads the player has walked do not join to where they stand.
		status.text = tr("从这里认不得路。")
		return
	MapAtlas.point_to(_state, map_id, zone_id)
	_show_goal()
	_refill_card()
	# TRANSLATORS: 指路 set: {place} where the marker in the world now leads.
	status.text = tr("已指路：{place}").format({"place": place})


func _clear_waypoint() -> void:
	MapAtlas.point_to(_state, &"")
	_show_goal()
	_refill_card()
	# TRANSLATORS: 指路 taken back.
	status.text = tr("已取消指路。")


## The card again, the focus kept on its place in the list.
func _refill_card() -> void:
	var at: int = row_buttons.find(get_viewport().gui_get_focus_owner() as Button)
	_fill_card()
	if at >= 0 and not row_buttons.is_empty():
		FocusNav.give(row_buttons[mini(at, row_buttons.size() - 1)])


## The one-word mark of a kind.
func _pin_word(kind: StringName) -> String:
	match kind:
		MapAtlas.TARGET:
			# TRANSLATORS: one-word mark on the 地图 page: the tracked quest's place.
			return tr("标")
		MapAtlas.MASTER:
			# TRANSLATORS: one-word mark on the 地图 page: someone who teaches.
			return tr("师")
		MapAtlas.SHOP:
			# TRANSLATORS: one-word mark on the 地图 page: someone who sells.
			return tr("店")
		MapAtlas.BANK:
			# TRANSLATORS: one-word mark on the 地图 page: a bank.
			return tr("钱")
		MapAtlas.HOCKSHOP:
			# TRANSLATORS: one-word mark on the 地图 page: a pawn shop.
			return tr("当")
		MapAtlas.BOUNTY:
			# TRANSLATORS: one-word mark on the 地图 page: the bounty board.
			return tr("榜")
	# TRANSLATORS: one-word mark on the 地图 page: someone who gives errands.
	return tr("差")


# --- on the 沙盘 ---


func _show_pins() -> void:
	for pin: Control in _pins:
		overlay.remove_child(pin)
		pin.queue_free()
	_pins.clear()
	if _zoom < PIN_ZOOM or _selected.is_empty() or not _pictures.has_picture(_selected):
		return
	var catalog: ContentCatalog = GameContent.catalog()
	for mark: MapAtlas.Mark in _marks:
		var key: String = "zone:%s" % mark.zone_id
		if mark.map_id != _selected:
			var step: WorldRoute.Step = WorldRoute.next_step(catalog, _selected, mark.map_id)
			if step == null:
				continue
			key = "door:%s" % step.to_map
		var inside: Vector2 = _pictures.pin(_selected, key)
		if inside != Vector2.INF:
			_add_pin(mark, _pictures.corner(_selected, _cell(_selected).at) + inside)
	_place_overlays()


func _add_pin(mark: MapAtlas.Mark, at: Vector2) -> void:
	var pin := Label.new()
	pin.name = "Pin"
	pin.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pin.text = _pin_word(mark.kind)
	pin.tooltip_text = tr(mark.who)
	pin.mouse_filter = Control.MOUSE_FILTER_PASS
	pin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pin.custom_minimum_size = Vector2(24, 24)
	pin.add_theme_font_size_override("font_size", 13)
	pin.add_theme_color_override("font_color", Color("fff6e6"))
	var style := StyleBoxFlat.new()
	style.bg_color = PIN_COLOURS[mark.kind]
	style.border_color = Color("fff0d0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	pin.add_theme_stylebox_override("normal", style)
	pin.set_meta("at", at)
	overlay.add_child(pin)
	_pins.append(pin)


func _show_goal() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var goal: MapAtlas.Goal = MapAtlas.goal(catalog, _state)
	var cell: StringName = &"" if goal == null else MapAtlas.arrow_cell(catalog, _state, _here_map, goal.map_id)
	arrow.visible = cell_buttons.has(cell)
	if arrow.visible:
		if arrow.texture == null:
			arrow.texture = load(AtlasPictures.DIRECTORY + "arrow.png") as Texture2D
		arrow.set_meta("cell", cell)
		_place_overlays()


## The part of the 沙盘's view the card leaves free: the view centres in it.
func _free_view() -> Vector2:
	return Vector2(maxf(sand.size.x - CARD_WIDTH, 1.0), sand.size.y)


func _apply_view() -> void:
	if _pictures == null:
		return
	var view: Vector2 = _free_view()
	var half: Vector2 = view / 2.0 / _zoom
	var whole: Vector2 = _pictures.stage_size()
	var room: Vector2 = (whole / 2.0 - half).max(Vector2.ZERO)
	_centre = _centre.clamp(whole / 2.0 - room, whole / 2.0 + room)
	stage.scale = Vector2(_zoom, _zoom)
	stage.position = view / 2.0 - _centre * _zoom
	_place_overlays()


func _to_view(at: Vector2) -> Vector2:
	return stage.position + at * _zoom


func _place_overlays() -> void:
	for map_id: StringName in cell_buttons:
		var button: Button = cell_buttons[map_id]
		var under: float = 0.0
		if _pictures.has_picture(map_id) and button.text != "？":
			under = _pictures.below(map_id) * _zoom + 12.0
		button.reset_size()
		button.position = _to_view(_middle(map_id)) + Vector2(-button.size.x / 2.0, under - button.size.y / 2.0)
	for pin: Control in _pins:
		pin.reset_size()
		pin.position = _to_view(pin.get_meta("at")) - Vector2(pin.size.x / 2.0, pin.size.y + 8.0)
	if arrow.visible:
		arrow.position = _to_view(_middle(arrow.get_meta("cell"))) - Vector2(arrow.size.x / 2.0, arrow.size.y + 26.0)


## The whole 沙盘 just fits the view.
func _fit_zoom() -> float:
	var whole: Vector2 = _pictures.stage_size()
	var view: Vector2 = _free_view()
	if whole.x <= 0.0 or whole.y <= 0.0 or view.y <= 0.0:
		return CLOSE_ZOOM
	return minf(minf(view.x / whole.x, view.y / whole.y), CLOSE_ZOOM)


func _toggle_zoom() -> void:
	_set_zoom(CLOSE_ZOOM if _zoom <= _fit_zoom() else _fit_zoom(), _to_view(_middle(_selected)))
	_centre = _middle(_selected)
	_apply_view()


func _set_zoom(zoom: float, around: Vector2) -> void:
	var fixed: Vector2 = (around - stage.position) / _zoom
	var was: bool = _zoom >= PIN_ZOOM
	_zoom = clampf(zoom, _fit_zoom(), MAX_ZOOM)
	_centre = fixed - (around - _free_view() / 2.0) / _zoom
	_apply_view()
	if was != (_zoom >= PIN_ZOOM):
		_show_pins()
	_show_zoom_label()


func _show_zoom_label() -> void:
	# TRANSLATORS: the 地图 page's button: the whole 沙盘, or back close to the chosen place.
	zoom_button.text = tr("近看") if _pictures != null and _zoom <= _fit_zoom() else tr("全图")


func _sand_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * 1.15, button.position)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom / 1.15, button.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging and motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
		_centre -= motion.relative / _zoom
		_apply_view()


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("14181c", 0.92)
	style.border_color = Color("d8b070", 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	return style


func _plate_style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	return style


## Every text the page shows on its card, one per line (tests).
func shown_text() -> String:
	var lines: Array[String] = []
	for node: Node in rows.get_children():
		if node is Label:
			lines.append((node as Label).text)
		elif node is Button:
			lines.append((node as Button).text)
	if not status.text.is_empty():
		lines.append(status.text)
	return "\n".join(lines)
