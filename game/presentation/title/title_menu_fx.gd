class_name TitleMenuFx
extends Control

## What the main menu's choices do on the title (DECISIONS「标题画面」): each button's text is
## drawn as voxel letters (the pixel face over two darker side layers); the chosen one lifts a
## pixel and a vermilion brush stroke sweeps in under it; the weather of the place it flies to
## spurts out of it and drifts over the screen; pressed, ink splashes and the letters sink.
## It holds the weather and the splash; the stroke and the letters are children of the buttons.

signal chosen(button: Button)

const SWASH: Shader = preload("res://presentation/title/shaders/title_swash.gdshader")
const SPLASH: Shader = preload("res://presentation/title/shaders/title_splash.gdshader")
## The meta a decorated button carries: no arrow beside it (the stroke shows the choice).
const NO_ARROW: StringName = &"no_focus_arrow"

## The menu's letters and strokes come up with the title's first opening (0 → 1).
var menu_alpha: float = 1.0
var _buttons: Array[Button] = []
var _faces: Dictionary[Button, Label] = {}
var _swashes: Dictionary[Button, ShaderMaterial] = {}
## Each button's running stroke and letter lift: a new one stops the old and goes on from where
## it stood, so a quick pass over a choice never leaves its stroke out or its letters raised.
var _strokes: Dictionary[Button, Tween] = {}
var _lifts: Dictionary[Button, Tween] = {}
var _weather: Dictionary[StringName, CPUParticles2D] = {}
var _spurt: CPUParticles2D
var _splash: ColorRect
var _splash_mat: ShaderMaterial


func _init() -> void:
	name = "TitleMenuFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for kind: StringName in TitleScreenDefinition.WEATHERS:
		var emitter: CPUParticles2D = _emitter(kind)
		_weather[kind] = emitter
		add_child(emitter)
	_spurt = CPUParticles2D.new()
	_spurt.name = "Spurt"
	_spurt.one_shot = true
	_spurt.explosiveness = 0.85
	_spurt.amount = 26
	_spurt.lifetime = 2.2
	_spurt.emitting = false
	_spurt.local_coords = false
	_spurt.direction = Vector2(1, -0.15)
	_spurt.spread = 28
	_spurt.initial_velocity_min = 90
	_spurt.initial_velocity_max = 230
	_spurt.damping_min = 40
	_spurt.damping_max = 80
	_spurt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_spurt.emission_rect_extents = Vector2(90, 14)
	_spurt.color_ramp = _fade_ramp()
	add_child(_spurt)
	_splash_mat = ShaderMaterial.new()
	_splash_mat.shader = SPLASH
	_splash = ColorRect.new()
	_splash.name = "Splash"
	_splash.material = _splash_mat
	_splash.size = Vector2(340, 340)
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.visible = false
	add_child(_splash)


## Dresses a main-menu button: voxel letters, the stroke, the lift on choosing.
func decorate(button: Button) -> void:
	if _buttons.has(button):
		return
	_buttons.append(button)
	button.theme_type_variation = &"TitleMenuItem"
	button.set_meta(NO_ARROW, true)
	var swash := ColorRect.new()
	swash.name = "Swash"
	swash.show_behind_parent = true
	swash.position = Vector2(-26, 0)
	swash.size = Vector2(300, 46)
	swash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SWASH
	mat.set_shader_parameter("seed", float(_buttons.size()) * 7.3)
	swash.material = mat
	button.add_child(swash)
	_swashes[button] = mat
	_faces[button] = _letters(button)
	button.focus_entered.connect(_on_chosen.bind(button))
	button.pressed.connect(press.bind(button))
	button.focus_exited.connect(_on_left.bind(button))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus())


func buttons() -> Array[Button]:
	return _buttons


## The weather that drifts over the screen ("" stops it); a spurt of it from `button`.
func weather(kind: StringName, button: Button = null) -> void:
	for name: StringName in _weather:
		_weather[name].emitting = name == kind
	if button == null or not _weather.has(kind):
		return
	var model: CPUParticles2D = _weather[kind]
	_spurt.texture = model.texture
	_spurt.gravity = model.gravity * 0.6
	_spurt.angular_velocity_min = model.angular_velocity_min
	_spurt.angular_velocity_max = model.angular_velocity_max
	_spurt.angle_max = model.angle_max
	_spurt.scale_amount_min = model.scale_amount_min
	_spurt.scale_amount_max = model.scale_amount_max * 1.2
	_spurt.position = button.global_position - global_position + Vector2(120, button.size.y / 2.0)
	_spurt.restart()


## Ink splashes at `button` and its letters sink, then rise again.
func press(button: Button) -> void:
	_splash.visible = true
	_splash.position = button.global_position - global_position + Vector2(70, button.size.y / 2.0) - _splash.size / 2.0
	var t := create_tween()
	t.tween_method(func(v: float) -> void: _splash_mat.set_shader_parameter("t", v), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: _splash.visible = false)
	if _swashes.has(button):
		var mat: ShaderMaterial = _swashes[button]
		create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 0.8, 0.0, 0.45)
	if _faces.has(button):
		var face: Label = _faces[button]
		var sink: Tween = _restart(_lifts, button)
		sink.tween_property(face, "position:y", float(GameTheme.PIXEL_STEP), 0.05)
		sink.tween_property(face, "position:y", -float(GameTheme.PIXEL_STEP), 0.18).set_delay(0.08)


func _process(_delta: float) -> void:
	# A choice that cannot be made now is dim; its letters follow.
	for button: Button in _buttons:
		var face: Label = _faces[button]
		var holder: Control = face.get_parent() as Control
		holder.modulate.a = (0.4 if button.disabled else (1.0 if button.has_focus() else 0.78)) * menu_alpha
		(button.get_node("Swash") as CanvasItem).modulate.a = menu_alpha


func _on_chosen(button: Button) -> void:
	_sweep(button, 1.0, 0.32, Tween.TRANS_QUART)
	_lift(button, -float(GameTheme.PIXEL_STEP))
	_faces[button].add_theme_color_override("font_color", Color("fff6dc"))
	chosen.emit(button)


func _on_left(button: Button) -> void:
	_sweep(button, 0.0, 0.18, Tween.TRANS_LINEAR)
	_lift(button, 0.0)
	_faces[button].add_theme_color_override("font_color", UiPalette.LETTER)


## How far `button`'s stroke is drawn out (0 none, 1 whole).
func stroke_reveal(button: Button) -> float:
	var reveal: Variant = _swashes[button].get_shader_parameter("reveal")
	return 0.0 if reveal == null else float(reveal)


## The stroke sweeps in (1) or out (0) from where it stands.
func _sweep(button: Button, to: float, seconds: float, trans: Tween.TransitionType) -> void:
	var mat: ShaderMaterial = _swashes[button]
	var t: Tween = _restart(_strokes, button)
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("reveal", v), stroke_reveal(button), to, seconds).set_trans(trans).set_ease(Tween.EASE_OUT)


func _lift(button: Button, y: float) -> void:
	_restart(_lifts, button).tween_property(_faces[button], "position:y", y, 0.12)


## A new tween in `running`'s slot for `button`; the one there stops where it is.
func _restart(running: Dictionary[Button, Tween], button: Button) -> Tween:
	var old: Tween = running.get(button)
	if old != null:
		old.kill()
	var t := create_tween()
	running[button] = t
	return t


## Voxel letters over the button (its own text is clear): a soft shadow, two side layers, the
## face. Returns the face.
func _letters(button: Button) -> Label:
	var holder := Control.new()
	holder.name = "Letters"
	holder.position = Vector2(14, GameTheme.TITLE_MENU_PAD_TOP)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(holder)
	var step: float = float(GameTheme.PIXEL_STEP)
	var face: Label
	for layer: Array in [[Color(0.03, 0.02, 0.02, 0.55), Vector2(step, step * 3)], [UiPalette.SIDE_DARK, Vector2(0, step * 2)], [UiPalette.SIDE_LIGHT, Vector2(0, step)], [UiPalette.LETTER, Vector2.ZERO]]:
		var label := Label.new()
		label.text = button.text
		label.theme_type_variation = &"TitleMenuLetters"
		label.add_theme_color_override("font_color", layer[0])
		label.position = layer[1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The menu's panel lays out its labels to wrap; these stay one line.
		label.set_meta(ResponsivePanelLayout.KEEPS_WIDTH, true)
		holder.add_child(label)
		face = label
	return face


func _emitter(kind: StringName) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Weather_%s" % kind
	p.texture = _shape(kind)
	p.amount = 110 if kind == &"dust" else 70
	p.emitting = false
	p.local_coords = false
	p.color_ramp = _fade_ramp()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Weather comes from the top, the bottom (mist rises) or the left (wind-blown dust).
	match kind:
		&"snow":
			_motion(p, 9.0, Vector2(0.3, 1), 20, Vector2(6, 22), 20, 50, 0, 0, 0.5, 1.4)
		&"petal":
			_motion(p, 9.0, Vector2(1, 0.4), 25, Vector2(10, 14), 30, 70, 120, 360, 0.8, 1.5)
		&"mote":
			_motion(p, 8.0, Vector2(0.4, -1), 40, Vector2(4, -6), 8, 26, 0, 0, 0.5, 1.6)
		&"needle":
			_motion(p, 8.0, Vector2(0.6, 1), 30, Vector2(14, 26), 25, 60, 200, 360, 0.9, 1.5)
		&"dust":
			_motion(p, 5.0, Vector2(1, -0.1), 12, Vector2(30, 4), 120, 260, 0, 0, 0.6, 1.8)
	if kind == &"mote":
		p.position = Vector2(700, 760)
		p.emission_rect_extents = Vector2(700, 20)
	elif kind == &"dust":
		p.position = Vector2(-20, 420)
		p.emission_rect_extents = Vector2(20, 320)
	else:
		p.position = Vector2(560, -20)
		p.emission_rect_extents = Vector2(760, 20)
	return p


static func _motion(p: CPUParticles2D, lifetime: float, direction: Vector2, spread: float, gravity: Vector2, speed_min: float, speed_max: float, spin: float, angle: float, scale_min: float, scale_max: float) -> void:
	p.lifetime = lifetime
	p.direction = direction
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.angle_max = angle
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max


static func _fade_ramp() -> Gradient:
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	return fade


static func _shape(kind: StringName) -> ImageTexture:
	match kind:
		&"snow":
			return TitleSand._soft_dot(10, Color(1, 1, 1))
		&"mote":
			return TitleSand._soft_dot(14, Color(0.8, 0.95, 1.0))
		&"dust":
			return TitleSand._soft_dot(6, Color(0.95, 0.8, 0.55))
	var image := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	for y: int in 12:
		for x: int in 12:
			var p := Vector2(x + 0.5 - 6.0, y + 0.5 - 6.0)
			if kind == &"petal":
				var on: float = 1.0 - Vector2(p.x / 5.5, p.y / 3.2).length()
				image.set_pixel(x, y, Color(Color("f4b6c2").lerp(Color("fff0f2"), clampf(on, 0, 1)), clampf(on * 3.0, 0, 1)))
			else:
				var line: float = (1.0 - absf(p.x - p.y * 0.25) / 0.9) if absf(p.y) < 5.5 else 0.0
				image.set_pixel(x, y, Color(Color("4f5e33"), clampf(line, 0, 1)))
	return ImageTexture.create_from_image(image)
