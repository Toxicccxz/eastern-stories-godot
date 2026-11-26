class_name TrainingProgress
extends VBoxContainer

## A continuous 请教 / 练习 / 打坐 under way (PlayerTrainingRun; DECISIONS「连续修炼」): what
## it does and the count, a bar (the skill's progress to its next level, or the internal
## power to twice its maximum), and 停止. It takes a step each pacing.json
## `training_step_ms` (`training_auto_step_ms` for a run that rests by itself; all at once
## with 0, as in the suites). While such a run rests (自动歇) the count says so and how long,
## the page staying open; the world runs behind it. B / Esc and 停止 stop it (and the rest),
## and so does the page going away (the menu closed, another tab); the pause holds it. Once
## it stops, the run's lines stay in its place while the page shows. It scrolls itself
## into view. The host greys its own buttons while running() and gets `finished` with
## the run's lines.
## 练功演出 (DECISIONS「练功演出」): with the feel's training_stage_ms the window the run was begun
## in stands aside once its first step is taken or its first rest begun (faded out, still open:
## nothing under it takes a click) and the player's figure is seen at it on the map
## (TrainingShow), sitting out a rest the run takes by itself (自动歇); a band at the foot of the
## screen carries the count, the bar and 停止. The run over, the stage
## holds a moment (the figure is given the time for a stroke, a gain the time of its 成长时刻:
## a run of a few steps is over in half a second), then the window is back
## with the run's lines as before. Only what is shown changes: the steps and their timing are
## the run's own.
signal finished(lines: Array[ColoredLine])

## The band's layer: above the menu (60) and the shared frame's dialogs (61).
const BAND_LAYER: int = 62

var status: Label
var bar: ProgressBar
var stop_button: Button
var _run: PlayerTrainingRun
var _what: String = ""
var _waited: float = 0.0
## 练功演出: the figure's show, the band, and what stands aside: the window this is in (the
## menu's, the shared frame's) and the scrim behind it; the HUD's card stays.
var show_stage: TrainingShow
var band: CanvasLayer
var band_status: Label
var band_bar: ProgressBar
var band_stop: Button
var _aside: Array[Control] = []
var _aside_tween: Tween
var _staged: bool = false
## The run is over and the stage holds before the window is back: its lines, and the wait.
var _leaving: bool = false
var _leaving_lines: Array[ColoredLine] = []
var _leave_left: float = 0.0
## How long the stage has stood (the least it stands: growth.json training.min_seconds).
var _staged_for: float = 0.0


func _init() -> void:
	name = "TrainingProgress"
	add_theme_constant_override("separation", 6)
	status = Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(status)
	bar = ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	# The theme draws no bar: the interface's square one, in gold.
	GameTheme.dress_bar(bar, UiPalette.GOLD)
	add_child(bar)
	stop_button = Button.new()
	stop_button.name = "Stop"
	stop_button.text = "停止"
	stop_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stop_button.custom_minimum_size = Vector2(120, 40)
	stop_button.pressed.connect(stop)
	add_child(stop_button)
	InputGlyphs.decorate(stop_button, &"ui_cancel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	visibility_changed.connect(_on_visibility_changed)


func running() -> bool:
	return _run != null or _leaving


## The window stands aside now (the run shown on the map, or its last moment held).
func staged() -> bool:
	return _staged


## Starts `run`; `what` names it (连续请教「基本剑法」). Shown under `after` (the row of the
## button that started it) when given.
func start(run: PlayerTrainingRun, what: String, after: Control = null) -> void:
	if running():
		return
	if after != null and after.get_parent() != null:
		# Out first: moving within the parent would count this among the rows above.
		if get_parent() != null:
			get_parent().remove_child(self)
		after.add_sibling(self)
	_run = run
	_what = what
	_waited = 0.0
	if run.step_seconds() <= 0.0:
		_burst()
		if not running():
			return
	_show()
	bar.show()
	stop_button.show()
	show()
	stop_button.grab_focus()
	_reveal()


## 停止 (B / Esc): the run stops before its next step; the stage's last moment is cut short.
func stop() -> void:
	if _run != null:
		_run.cancel()
		_end()
	elif _leaving:
		_leave_stage()


func _process(delta: float) -> void:
	# The pause (系统, Start) holds the run until the game goes on.
	if not running() or get_tree().paused:
		return
	_staged_for += delta
	if _leaving:
		_leave_left -= delta
		if _leave_left <= 0.0:
			_leave_stage()
		return
	# 自动歇: the run's rest goes on in the world; the rest's end takes it on (or ends it), the next
	# step at once (the line said 歇息中 until then). The figure sits the rest out (练功演出).
	if _run.resting():
		# A run that began by resting (精 or 气 short at its first step) is under way all the same.
		if not _staged:
			_enter_stage()
		if show_stage != null:
			show_stage.rest(true)
		_show()
		_waited = INF
		return
	if show_stage != null:
		show_stage.rest(false)
	var every: float = _run.step_seconds()
	if every <= 0.0:
		_burst()
		if running():
			_show()
		return
	_waited += delta
	if _waited < every:
		return
	_waited = 0.0
	var goes_on: bool = _run.step()
	# 练功演出: once a step is taken (a run refused at its first step shows nothing, nor one that
	# step cut short: a fight it began has the screen).
	if not _staged and _run.training.steps > 0 and (goes_on or not _run.training.stop in [TrainingRun.Stop.CANCELLED, TrainingRun.Stop.INTERRUPTED]):
		_enter_stage()
	if not goes_on:
		_end()
		return
	_show()


## Steps all at once (no pacing between them) until the run stops, or rests by itself.
func _burst() -> void:
	while _run.step():
		if _run.resting():
			return
	_end()


func _input(event: InputEvent) -> void:
	if running() and is_visible_in_tree() and not get_tree().paused and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		stop()
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		return
	if running():
		stop()
	else:
		hide() # The last run's lines go with the page.


## Why the last run stopped (TrainingRun.Stop; NONE before any).
var last_stop: TrainingRun.Stop = TrainingRun.Stop.NONE


func _end() -> void:
	var run: PlayerTrainingRun = _run
	_run = null
	var lines: Array[ColoredLine] = run.finish()
	last_stop = run.training.stop
	# Stopped by the player, or cut short (a fight, the window gone): the window is back at once.
	var abrupt: bool = last_stop in [TrainingRun.Stop.CANCELLED, TrainingRun.Stop.INTERRUPTED]
	if _staged and is_visible_in_tree() and not abrupt:
		# The stage holds: a gain's moment plays on the figure before the window is back.
		var hold: Dictionary = GrowthFx.training().get("hold", {})
		var gained: bool = last_stop in [TrainingRun.Stop.LEVEL_UP, TrainingRun.Stop.MAXIMUM_UP]
		_leave_left = float(hold.get("moment", 1.0)) * GameContent.catalog().pacing().feel.growth_moment_seconds if gained else float(hold.get("plain", 0.2))
		# A run of a few steps is over in a blink: the figure is given the time for a stroke.
		_leave_left = maxf(_leave_left, float(GrowthFx.training().get("min_seconds", 0.0)) - _staged_for)
		_leaving = true
		_leaving_lines = lines
		if show_stage != null:
			show_stage.closing = true
		if gained:
			var moments: GrowthMoments = _moments(run.session())
			if moments != null:
				moments.look_now()
		if band_stop != null:
			band_stop.hide()
		if _leave_left > 0.0:
			return
	_leaving_lines = lines
	_leave_stage()


## The stage is left (at once when it was never entered): the window back, then the run's lines
## in the bar's place as ever.
func _leave_stage() -> void:
	var lines: Array[ColoredLine] = _leaving_lines
	_leaving = false
	_leaving_lines = []
	_exit_stage()
	_present(lines)


func _present(lines: Array[ColoredLine]) -> void:
	status.text = ShownText.of("\n".join(ColoredLine.texts(lines)))
	bar.hide()
	stop_button.hide()
	var parent := get_parent() as CanvasItem
	visible = parent != null and parent.is_visible_in_tree() and not lines.is_empty()
	if visible:
		_reveal()
	finished.emit(lines)


## Scrolls the page to this once its layout follows (the next frame).
func _reveal() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var scroll: Node = get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).ensure_control_visible(self)


## 练功演出: the window stands aside and the figure's show begins, where the feel asks for it and
## there is a map to show it on. Nothing otherwise (the suites: the bar in the page, as ever).
func _enter_stage() -> void:
	var seconds: float = GameContent.catalog().pacing().feel.training_stage_seconds
	var session: WorldSessionController = _run.session() if _run != null else null
	if seconds <= 0.0 or session == null or not is_visible_in_tree():
		return
	var map: Node = session.active_map()
	var view: WorldVoxelView = map.get_node_or_null(^"MapView") as WorldVoxelView if map != null else null
	if view == null:
		return
	var state: CharacterState = _run.state()
	var wielded: StringName = state.equipment.primary_weapon_skill_type() if state != null else &""
	var shown: Dictionary = TrainingShow.form_for(_run.training.kind, _run.skill(), _run.use_id(), wielded)
	if show_stage == null:
		show_stage = TrainingShow.new()
		show_stage.name = "TrainingShow"
		add_child(show_stage)
	if not show_stage.begin(view, session.player_runtime().character_id, _run.teacher_id(), shown):
		return
	_staged = true
	_staged_for = 0.0
	_build_band()
	band.visible = true
	band_stop.show()
	_show()
	band_stop.grab_focus()
	_aside = _window_parts()
	_fade_aside(0.0, seconds)


func _exit_stage() -> void:
	if not _staged:
		return
	_staged = false
	if show_stage != null:
		show_stage.end()
	if band != null:
		band.visible = false
	_fade_aside(1.0, GameContent.catalog().pacing().feel.training_stage_seconds if is_visible_in_tree() else 0.0)
	_aside = []


## The window this is in — the outermost panel over it (the menu's window, the shared frame) —
## and the scrim drawn behind it (a ColorRect beside it), if it has one.
func _window_parts() -> Array[Control]:
	var window: Control = null
	var top: Control = self
	while top.get_parent() is Control:
		top = top.get_parent() as Control
		if top is PanelContainer:
			window = top
	if window == null:
		return [top]
	var parts: Array[Control] = [window]
	for beside: Node in window.get_parent().get_children():
		if beside is ColorRect:
			parts.append(beside as Control)
	return parts


func _fade_aside(alpha: float, seconds: float) -> void:
	if _aside_tween != null and _aside_tween.is_valid():
		_aside_tween.kill()
	var parts: Array[Control] = []
	for index: int in _aside.size():
		var part: Variant = _aside[index]
		if is_instance_valid(part):
			parts.append(part)
	if parts.is_empty():
		return
	if seconds <= 0.0 or not is_inside_tree():
		for part: Control in parts:
			part.modulate.a = alpha
		return
	_aside_tween = create_tween().set_parallel(true)
	for part: Control in parts:
		_aside_tween.tween_property(part, "modulate:a", alpha, seconds)


## The band at the foot of the screen, on its own layer over the window that stands aside: the
## count, the bar, 停止; and under them a sheet that takes every click, so nothing of the unseen
## window is pressed.
func _build_band() -> void:
	if band != null:
		return
	band = CanvasLayer.new()
	band.name = "TrainingBand"
	band.layer = BAND_LAYER
	band.visible = false
	add_child(band)
	var sheet := Control.new()
	sheet.name = "Sheet"
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.theme = GameTheme.shared()
	band.add_child(sheet)
	var foot := CenterContainer.new()
	foot.anchor_left = 0.0
	foot.anchor_right = 1.0
	foot.anchor_top = 0.84
	foot.anchor_bottom = 0.84
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(foot)
	var panel := PanelContainer.new()
	panel.name = "Band"
	panel.theme_type_variation = &"MenuWindow"
	foot.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = 360
	row.add_child(column)
	band_status = Label.new()
	band_status.name = "Status"
	band_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(band_status)
	band_bar = ProgressBar.new()
	band_bar.name = "Bar"
	band_bar.custom_minimum_size.y = 12
	band_bar.show_percentage = false
	GameTheme.dress_bar(band_bar, UiPalette.GOLD)
	column.add_child(band_bar)
	band_stop = Button.new()
	band_stop.name = "Stop"
	band_stop.text = "停止"
	band_stop.custom_minimum_size = Vector2(120, 44)
	band_stop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band_stop.pressed.connect(stop)
	# The keys stay on it: nothing of the unseen window takes the focus.
	for side: String in ["focus_neighbor_left", "focus_neighbor_top", "focus_neighbor_right", "focus_neighbor_bottom", "focus_next", "focus_previous"]:
		band_stop.set(side, NodePath("."))
	row.add_child(band_stop)
	InputGlyphs.decorate(band_stop, &"ui_cancel")


## The session's 成长时刻 (GrowthMoments), if it has them.
static func _moments(session: WorldSessionController) -> GrowthMoments:
	var hud: SharedGameplayUI = session.shared_ui() if session != null else null
	return hud.growth_moments if hud != null and is_instance_valid(hud.growth_moments) else null


func _show() -> void:
	var training: TrainingRun = _run.training
	if not _run.resting():
		# TRANSLATORS: a continuous run under way: {what} 连续请教「基本剑法」 …, {count} the times done so far.
		status.text = ShownText.of(tr("{what}：已做 {count} 次").format({"what": _what, "count": training.steps}))
	else:
		# TRANSLATORS: a continuous run resting by itself on the way (自动歇): {what} and {count} as above, {rest} the rest's line (歇息中……已歇一盏茶的工夫).
		status.text = ShownText.of(tr("{what}：已做 {count} 次，{rest}").format({
			"what": _what, "count": training.steps, "rest": RestLines.under_way(_run.rest_minutes()),
		}))
	var state: CharacterState = _run.state()
	if state == null:
		return
	if training.skill_id.is_empty():
		var power: CharacterInternalResourceState = _internal_power(state, training.kind)
		if training.target_maximum > 0:
			# TRANSLATORS: a continuous 打坐 towards a maximum (前两小时 A): the maximum now {maximum}, the one aimed at {target}, and what is left {left}.
			status.text += ShownText.of(tr("，上限 {maximum} → {target}，还差 {left}").format({
				"maximum": power.maximum, "target": training.target_maximum, "left": maxi(0, training.target_maximum - power.maximum),
			}))
		bar.max_value = maxi(1, power.maximum * 2)
		bar.value = power.current
	else:
		var next_level: int = state.skills.raw_level(training.skill_id) + 1
		bar.max_value = next_level * next_level + 1
		bar.value = state.skills.learned_progress(training.skill_id)
	if _staged and band_status != null:
		band_status.text = status.text
		band_bar.max_value = bar.max_value
		band_bar.value = bar.value


static func _internal_power(state: CharacterState, kind: TrainingRun.Kind) -> CharacterInternalResourceState:
	match kind:
		TrainingRun.Kind.MEDITATE:
			return state.recovery.mana
		TrainingRun.Kind.RESPIRATE:
			return state.recovery.atman
	return state.recovery.inner_force
