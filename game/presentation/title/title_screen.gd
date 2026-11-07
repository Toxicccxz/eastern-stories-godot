class_name TitleScreen
extends CanvasLayer

## The title (界面重做, DECISIONS「标题画面」), behind the main menu and the dialogs opened from
## it while no journey runs: the living 沙盘 (TitleSand), the sky that parts from the sun
## (TitleSky, 拨云见日), the brush-stroke voxel logo (TitleLogo) and what the menu's choices
## do (TitleMenuFx). Choosing an option flies the camera to its place (title_screen.json) and
## names it; starting a journey burns the logo into embers while the camera dives at where
## it begins, the clouds close and the light floods the screen — then the world shows.
## It only shows things: the shell's state decides, and a start goes ahead at once whatever
## the title is still playing (it plays over the world as it is built, then fades).

signal entered

## Below the shell's dialogs; above them while a journey starts (it covers the busy note).
const LAYER: int = 99
const ENTERING_LAYER: int = 101
## When the menu's letters come up in the first opening (seconds, at its pace): the clouds have
## mostly parted. The place's name waits for it.
const MENU_UP_SECONDS: float = 2.2
## How long the white holds before the voxel animation comes onto it.
const LOADER_AFTER_SECONDS: float = 0.2

var definition: TitleScreenDefinition
var sand: TitleSand
var sky: TitleSky
var logo: TitleLogo
var menu_fx: TitleMenuFx
var caption: Label
var whiteout: ColorRect
## On the white while a journey is still being set up (the voxel animation every wait shows).
var loader: VoxelLoader
var _shell: ApplicationShellController
var _root: Control
var _fly: Tween
var _intro_tween: Tween
## The place name's fade in: one at a time, so an earlier choice's never shows a later name early.
var _caption_fade: Tween
var _entering: bool = false
var _shown_once: bool = false
## Seconds until the opening brings the menu up (0 once it has).
var _menu_up_in: float = 0.0


func _init() -> void:
	name = "TitleScreen"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	definition = GameContent.catalog().title_screen()
	if definition == null:
		definition = TitleScreenDefinition.new()
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameTheme.shared()
	add_child(_root)
	sand = TitleSand.new()
	_root.add_child(sand)
	sky = TitleSky.new()
	sky.sun = Vector2(definition.sun_percent[0], definition.sun_percent[1]) / 100.0
	_root.add_child(sky)
	logo = TitleLogo.new()
	logo.at = Vector2(definition.logo_percent[0], definition.logo_percent[1]) / 100.0
	logo.width_px = definition.logo_width_px
	_root.add_child(logo)
	sky.set_logo_texture(logo.texture())
	_root.add_child(sky.front())
	menu_fx = TitleMenuFx.new()
	menu_fx.chosen.connect(_on_chosen)
	_root.add_child(menu_fx)
	caption = Label.new()
	caption.name = "Caption"
	caption.theme_type_variation = &"TitleCaption"
	caption.modulate.a = 0.0
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(caption)
	whiteout = ColorRect.new()
	whiteout.name = "Whiteout"
	whiteout.color = Color(1.0, 0.96, 0.88, 0.0)
	whiteout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	whiteout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(whiteout)
	loader = VoxelLoader.new()
	loader.modulate.a = 0.0
	_root.add_child(loader)
	loader.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	visible = false


func _ready() -> void:
	var shell: ApplicationShellController = get_parent() as ApplicationShellController
	if shell == null:
		return
	var buttons: Array[Button] = []
	for button_name: String in ["NewGameButton", "ContinueButton", "LoadButton", "RecoveryButton", "MenuSettingsButton", "QuitButton"]:
		var button: Button = shell.get_node_or_null("%" + button_name) as Button
		if button != null:
			buttons.append(button)
	bind(shell, buttons)


## Follows `shell`: dresses its main-menu buttons and shows, enters or hides with its state.
func bind(shell: ApplicationShellController, buttons: Array[Button]) -> void:
	_shell = shell
	for button: Button in buttons:
		menu_fx.decorate(button)
	_build_logo()
	shell.state_changed.connect(_on_state)


func entering() -> bool:
	return _entering


func _build_logo() -> void:
	var language: String = TranslationServer.get_locale()
	logo.build(definition.logo_for(language), definition.seal_for(language))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _shell != null and not _entering:
		_build_logo()


func _process(delta: float) -> void:
	_menu_up_in = maxf(0.0, _menu_up_in - delta)
	if caption.modulate.a > 0.0:
		var spot: Vector2 = sand.centre_on_screen()
		caption.position = (spot + Vector2(-caption.size.x / 2.0, -caption.size.y - 26.0 + sin(sand.clock * 1.6) * 3.0)).round()


func _on_state(state: ApplicationShellState) -> void:
	var mode: int = state.mode()
	var starting: bool = mode == ApplicationShellState.Mode.STARTING_SESSION and state.operation() in [
		ApplicationShellState.Operation.NEW_GAME, ApplicationShellState.Operation.CONTINUE,
		ApplicationShellState.Operation.LOAD, ApplicationShellState.Operation.RECOVER,
	]
	if starting and visible and not _entering:
		_enter(_shell.starting_place())
		return
	if _entering:
		return
	var wanted: bool = not _shell.session_running() and mode != ApplicationShellState.Mode.PLAYING
	if wanted and not visible:
		_show()
	elif not wanted and visible:
		_hide()


## 拨云见日: cloud; light grows behind it; the clouds part from the sun; the stroke is laid and
## the characters written; the menu comes up (it is usable at once).
func _show() -> void:
	visible = true
	layer = LAYER
	_reset()
	var quick: bool = _shown_once
	_shown_once = true
	var pace: float = 0.6 if quick else 1.0
	if _intro_tween != null:
		_intro_tween.kill()
	var t := create_tween().set_parallel()
	_intro_tween = t
	t.tween_property(sky, "dawn", 0.9, 1.0 * pace).set_trans(Tween.TRANS_SINE)
	t.tween_property(sky, "glow", 0.8, 1.2 * pace).set_delay(0.6 * pace)
	t.tween_property(sky, "cover", 0.0, 2.2 * pace).set_delay(0.7 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sky, "open_r", 2.0, 2.8 * pace).set_delay(0.7 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(sky, "push", 0.6, 3.0 * pace).set_delay(0.7 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(sky, "residual", 1.0, 1.6 * pace).set_delay(2.0 * pace)
	t.tween_property(sky, "dawn", 0.0, 1.6 * pace).set_delay(1.6 * pace)
	t.tween_property(sky, "rays", 1.8, 1.0 * pace).set_delay(1.1 * pace).set_trans(Tween.TRANS_SINE)
	t.tween_property(sky, "rays", 0.85, 2.0 * pace).set_delay(2.3 * pace)
	t.tween_property(sand, "zoom", 0.66, 3.4 * pace).set_delay(0.4 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(logo, "write", 1.05, 2.0 * pace).set_delay(1.2 * pace)
	# The menu is usable at once; its letters come up as the clouds part.
	menu_fx.menu_alpha = 0.0
	_menu_up_in = MENU_UP_SECONDS * pace
	t.tween_property(menu_fx, "menu_alpha", 1.0, 0.6).set_delay(MENU_UP_SECONDS * pace)
	var focused: Control = _root.get_viewport().gui_get_focus_owner()
	if focused is Button and menu_fx.buttons().has(focused):
		_on_chosen(focused as Button)


func _hide() -> void:
	visible = false
	layer = LAYER
	menu_fx.weather(&"")


func _reset() -> void:
	sky.cover = 1.0
	sky.open_r = 0.0
	sky.push = 0.0
	sky.residual = 0.0
	sky.dawn = 0.25
	sky.rays = 0.0
	sky.glow = 0.3
	sky.flare = 0.0
	sky.wisp_close = 0.0
	logo.write = 0.0
	logo.burn = -0.2
	logo.charge = 0.0
	sand.drift_on = 1.0
	sand.zoom = 0.58
	whiteout.color.a = 0.0
	if _caption_fade != null:
		_caption_fade.kill()
	caption.modulate.a = 0.0
	sand.marker.modulate.a = 0.0
	menu_fx.modulate.a = 1.0


## An option was chosen: the camera pulls back, glides to its place and settles; the place's
## name rises over it (in the opening, not before the clouds have parted and the menu is up);
## its weather drifts out of the option; a glint passes over the logo.
func _on_chosen(button: Button) -> void:
	if _entering or not visible:
		return
	var choice: TitleScreenDefinition.Choice = definition.choice(StringName(button.name))
	if choice == null:
		return
	var place: StringName = choice.place
	if place == &"" and _shell != null:
		place = _shell.continue_place()
	var target: Vector2 = sand.place_of(place)
	if _fly != null:
		_fly.kill()
	_fly = create_tween().set_parallel()
	_fly.tween_property(sand, "centre", target, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var dip := create_tween()
	dip.tween_property(sand, "zoom", 0.46, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	dip.tween_property(sand, "zoom", choice.zoom_percent / 100.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	caption.text = TitleSand.place_name(place)
	caption.modulate.a = 0.0
	sand.marker.modulate.a = 0.0
	if _caption_fade != null:
		_caption_fade.kill()
	var fade := create_tween()
	_caption_fade = fade
	fade.tween_interval(maxf(1.0, _menu_up_in))
	fade.tween_property(caption, "modulate:a", 1.0, 0.5)
	fade.parallel().tween_property(sand.marker, "modulate:a", 0.9, 0.5)
	menu_fx.weather(choice.weather, button)
	logo.glint = logo.glint_at(-0.1)
	create_tween().tween_property(logo, "glint", logo.glint_at(1.1), 1.1).set_trans(Tween.TRANS_SINE)


## A journey starts: a glint, the logo burns left to right into embers, the camera dives at
## `place`, the clouds close and the light floods the screen; held white until the world is
## there, then faded.
func _enter(place: StringName) -> void:
	_entering = true
	if place == &"":
		place = definition.new_game_place
	layer = ENTERING_LAYER
	menu_fx.weather(&"")
	if _fly != null:
		_fly.kill()
	if _intro_tween != null:
		_intro_tween.kill()
	if _caption_fade != null:
		_caption_fade.kill()
	sky.cover = minf(sky.cover, 0.0)
	logo.write = 1.05
	logo.glint = logo.glint_at(-0.1)
	var t := create_tween().set_parallel()
	t.tween_property(logo, "glint", logo.glint_at(1.1), 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(sky, "rays", 1.1, 0.5)
	t.tween_property(sky, "glow", 0.85, 0.5)
	t.tween_property(logo, "charge", 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(menu_fx, "modulate:a", 0.0, 0.4)
	t.tween_property(caption, "modulate:a", 0.0, 0.3)
	t.tween_property(sand.marker, "modulate:a", 0.0, 0.3)
	t.tween_property(logo, "burn", 1.15, 1.7).set_delay(0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(logo, "charge", 0.0, 0.5).set_delay(0.65)
	t.tween_property(sand, "centre", sand.place_of(place), 0.6).set_delay(0.45)
	t.tween_property(sand, "zoom", 2.6, 2.4).set_delay(0.65).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		sand.drift_on = 0.0
		sky.wisp_close = 1.0).set_delay(0.45)
	t.tween_property(sky, "cover", 1.0, 1.2).set_delay(1.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(sky, "push", -0.5, 1.2).set_delay(1.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(sky, "flare", 2.6, 0.8).set_delay(2.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(whiteout, "color:a", 1.0, 0.5).set_delay(2.8)
	t.chain().tween_callback(_entered)


func _entered() -> void:
	entered.emit()
	_finish_when_ready()


## Held white until the journey has begun (or failed), then faded away from over the world.
## A hold longer than LOADER_AFTER_SECONDS shows the voxel animation on the white.
func _finish_when_ready() -> void:
	var tree: SceneTree = get_tree()
	var held_from: int = Time.get_ticks_msec()
	var loader_up: bool = false
	while tree != null and _shell != null and _shell.shell_state().mode() == ApplicationShellState.Mode.STARTING_SESSION:
		if not loader_up and Time.get_ticks_msec() - held_from >= int(LOADER_AFTER_SECONDS * 1000.0):
			loader_up = true
			loader.restart()
			create_tween().tween_property(loader, "modulate:a", 1.0, 0.2)
		await tree.process_frame
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.6)
	await t.finished
	_entering = false
	_root.modulate.a = 1.0
	loader.modulate.a = 0.0
	_hide()
	_on_state(_shell.shell_state())
