class_name TrainingProgress
extends VBoxContainer

## A continuous 请教 / 练习 / 打坐 under way (PlayerTrainingRun; DECISIONS「连续修炼」): what
## it does and the count, a bar (the skill's progress to its next level, or the internal
## power to twice its maximum), and 停止. It takes a step each pacing.json
## `training_step_ms` (all at once with 0, as in the suites). B / Esc and 停止 stop it, and
## so does the page going away (the menu closed, another tab); the pause holds it. Once
## it stops, the run's lines stay in its place while the page shows. It scrolls itself
## into view. The host greys its own buttons while running() and gets `finished` with
## the run's lines.
signal finished(lines: Array[ColoredLine])

var status: Label
var bar: ProgressBar
var stop_button: Button
var _run: PlayerTrainingRun
var _what: String = ""
var _waited: float = 0.0


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
	# The theme draws no bar: a dark track, the page titles' gold fill.
	for part: Array in [["background", Color(0.22, 0.22, 0.2)], ["fill", Color(0.85, 0.8, 0.6)]]:
		var style := StyleBoxFlat.new()
		style.bg_color = part[1]
		style.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(part[0], style)
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
	return _run != null


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
	if GameContent.catalog().pacing().feel.training_step_seconds <= 0.0:
		run.run_to_end()
		_end()
		return
	_show()
	bar.show()
	stop_button.show()
	show()
	stop_button.grab_focus()
	_reveal()


## 停止 (B / Esc): the run stops before its next step.
func stop() -> void:
	if running():
		_run.cancel()
		_end()


func _process(delta: float) -> void:
	# The pause (系统, Start) holds the run until the game goes on.
	if not running() or get_tree().paused:
		return
	_waited += delta
	var every: float = GameContent.catalog().pacing().feel.training_step_seconds
	if _waited < every:
		return
	_waited = 0.0
	if not _run.step():
		_end()
		return
	_show()


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


func _end() -> void:
	var run: PlayerTrainingRun = _run
	_run = null
	var lines: Array[ColoredLine] = run.finish()
	status.text = "\n".join(ColoredLine.texts(lines))
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


func _show() -> void:
	var training: TrainingRun = _run.training
	# TRANSLATORS: a continuous run under way: {what} 连续请教「基本剑法」 …, {count} the times done so far.
	status.text = tr("{what}：已做 {count} 次").format({"what": _what, "count": training.steps})
	var state: CharacterState = _run.state()
	if state == null:
		return
	if training.skill_id.is_empty():
		var power: CharacterInternalResourceState = _internal_power(state, training.kind)
		bar.max_value = maxi(1, power.maximum * 2)
		bar.value = power.current
	else:
		var next_level: int = state.skills.raw_level(training.skill_id) + 1
		bar.max_value = next_level * next_level + 1
		bar.value = state.skills.learned_progress(training.skill_id)


static func _internal_power(state: CharacterState, kind: TrainingRun.Kind) -> CharacterInternalResourceState:
	match kind:
		TrainingRun.Kind.MEDITATE:
			return state.recovery.mana
		TrainingRun.Kind.RESPIRATE:
			return state.recovery.atman
	return state.recovery.inner_force
