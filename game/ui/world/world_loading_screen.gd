class_name WorldLoadingScreen
extends Control

## The picture over the view while a map's world is built (DECISIONS「加载画面」), as
## LoadingScreenDefinition says. It stays out of sight for the feel's map_loading_delay_ms, so
## a small room's build is only the dark of a door; once in sight it stays at least
## map_loading_min_ms. Its frames follow the clock: a long frame of the build skips them,
## never slows them. WorldViewOverlay says when it begins and ends.

var _sheet: AtlasTexture
var _definition: LoadingScreenDefinition
var _sprite: TextureRect
var _caption: Label
var _began_ms: int = 0
var _shown_ms: int = -1
## The build is under way: past the delay the picture may still come.
var _waiting: bool = false
var _frame: int = 0
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	set_process(false)
	_definition = GameContent.catalog().loading_screen()
	if _definition == null:
		_definition = LoadingScreenDefinition.new()
	var colour := ColorRect.new()
	colour.name = "Background"
	colour.color = Color(_definition.background)
	colour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	colour.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(colour)
	if not _definition.backdrop.is_empty():
		var backdrop := TextureRect.new()
		backdrop.name = "Backdrop"
		backdrop.texture = load(_definition.backdrop) as Texture2D
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
	var middle := Control.new()
	middle.name = "Middle"
	var center: Vector2 = Vector2(_definition.center_percent[0], _definition.center_percent[1]) / 100.0
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	# Right and bottom first: a left or top anchor past them would be pulled back.
	middle.set_anchor_and_offset(SIDE_RIGHT, center.x, 0.0)
	middle.set_anchor_and_offset(SIDE_BOTTOM, center.y, 0.0)
	middle.set_anchor_and_offset(SIDE_LEFT, center.x, 0.0)
	middle.set_anchor_and_offset(SIDE_TOP, center.y, 0.0)
	var half: float = float(_definition.side_px) / 2.0
	if not _definition.sheet.is_empty():
		_sheet = AtlasTexture.new()
		_sheet.atlas = load(_definition.sheet) as Texture2D
		_sprite = TextureRect.new()
		_sprite.name = "Sheet"
		_sprite.texture = _sheet
		_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_sprite.position = Vector2(-half, -half)
		_sprite.size = Vector2.ONE * float(_definition.side_px)
		_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		middle.add_child(_sprite)
		_show_frame(0)
	if _definition.caption:
		_caption = Label.new()
		_caption.name = "Caption"
		_caption.add_theme_font_size_override("font_size", 16)
		_caption.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_caption.position = Vector2(-120.0, half + 10.0)
		_caption.size = Vector2(240.0, 24.0)
		middle.add_child(_caption)


## A build began: out of sight until the delay has passed.
func begin() -> void:
	_kill_tween()
	_began_ms = Time.get_ticks_msec()
	_shown_ms = -1
	_waiting = true
	modulate.a = 0.0
	visible = true
	set_process(true)
	if _caption != null:
		# TRANSLATORS: under the animation while a map's world is being built.
		_caption.text = tr("载入中")


## The build is done: a picture that has not come by now does not come.
func settle() -> void:
	_waiting = false


## Whether the picture came.
func shown() -> bool:
	return _shown_ms >= 0


## Seconds it must still stay in sight (0: none).
func seconds_left() -> float:
	if not shown():
		return 0.0
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	return maxf(0.0, feel.map_loading_min_seconds - float(Time.get_ticks_msec() - _shown_ms) / 1000.0)


## Fades away in `seconds`.
func end(seconds: float) -> void:
	_waiting = false
	_kill_tween()
	if not shown() or seconds <= 0.0:
		_put_away()
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, seconds)
	_tween.tween_callback(_put_away)


## The cell of the sheet showing now.
func frame_shown() -> int:
	return _frame


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if _waiting and not shown() and float(now - _began_ms) / 1000.0 >= feel.map_loading_delay_seconds:
		_shown_ms = now
		_kill_tween()
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, feel.map_loading_fade_seconds)
	if shown():
		_show_frame(int(float(now - _shown_ms) / 1000.0 * float(_definition.fps)))


func _show_frame(frame: int) -> void:
	if _sheet == null or _sheet.atlas == null:
		return
	_frame = posmod(frame, _definition.frames)
	var size := Vector2(_sheet.atlas.get_size()) / Vector2(_definition.columns, _definition.rows)
	_sheet.region = Rect2(Vector2(_frame % _definition.columns, _frame / _definition.columns) * size, size)


func _put_away() -> void:
	visible = false
	modulate.a = 0.0
	set_process(false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
