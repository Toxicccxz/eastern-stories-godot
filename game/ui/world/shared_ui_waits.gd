class_name SharedUiWaits
extends RefCounted
## The status card's waits (DECISIONS「响应性」: what the player waits for is seen): their
## busy (char.c's beats left), what the map holds for them (their steal, a master's test,
## a told sequence with 继续: WorldMapController.player_waits()) and 朱鸿雪's task time.
## Rows are kept and refilled with the card's refresh; A (ui_accept) hurries the first
## that can be hurried when the place offers no action of its own.

var _ui: SharedGameplayUI
## [line, bar, button] per row made so far.
var _rows: Array[Array] = []
## The waits shown now.
var _shown: Array[WorldWait] = []
## The longest busy seen since the player was last free (its bar's whole).
var _busy_total: float = 0.0

var _session: WorldSessionController:
	get: return _ui._session
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout
var _player: WorldPlayerRuntimeState:
	get: return _ui._player


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


## The lines shown now (tests, the walk).
func texts() -> Array[String]:
	var lines: Array[String] = []
	for wait: WorldWait in _shown:
		lines.append(wait.text)
	return lines


## A wait the player can hurry now (继续).
func can_hurry() -> bool:
	for wait: WorldWait in _shown:
		if wait.hurry.is_valid():
			return true
	return false


## 继续: the first wait that can be hurried brings its next step now. False when nothing
## was still to come.
func hurry() -> bool:
	for wait: WorldWait in _shown:
		if wait.hurry.is_valid() and bool(wait.hurry.call()):
			return true
	return false


## Called with the card's refresh.
func refresh() -> void:
	_shown = _collect()
	var box: VBoxContainer = _presentation_layout.waits
	while _rows.size() < _shown.size():
		var index: int = _rows.size()
		_rows.append(_presentation_layout.wait_row(_press.bind(index)))
	for index: int in _rows.size():
		var row: Array = _rows[index]
		var line: Label = row[0]
		var bar: ProgressBar = row[1]
		var button: Button = row[2]
		var shown: bool = index < _shown.size()
		line.get_parent().get_parent().visible = shown
		if not shown:
			continue
		var wait: WorldWait = _shown[index]
		line.text = wait.text
		bar.visible = wait.progress >= 0.0
		bar.value = clampf(wait.progress, 0.0, 1.0)
		button.visible = wait.hurry.is_valid()
	box.visible = not _shown.is_empty()


func _press(index: int) -> void:
	if index < _shown.size() and _shown[index].hurry.is_valid():
		_shown[index].hurry.call()


func _collect() -> Array[WorldWait]:
	var shown: Array[WorldWait] = []
	if _player == null or _session == null or not _session.is_initialized():
		return shown
	var busy: WorldWait = _busy()
	if busy != null:
		shown.append(busy)
	var map: WorldMapController = _session.active_map() as WorldMapController
	if map != null:
		shown.append_array(map.player_waits())
	var task: WorldWait = _task()
	if task != null:
		shown.append(task)
	return shown


## The player's busy: char.c wears one off each heart beat (DECISIONS「Busy wears off on the
## heart beat」); the seconds left are the beats left less the beat already under way.
func _busy() -> WorldWait:
	var cadence: PlayerRecoveryCadence = _session.player_recovery_cadence()
	if not _player.busy.is_busy() or cadence == null or _player.busy.busy_value <= 0:
		_busy_total = 0.0
		return null
	var left: float = maxf(_player.busy.busy_value * cadence.pulse_seconds - cadence.accumulated_seconds, 0.0)
	_busy_total = maxf(_busy_total, left)
	# TRANSLATORS: the HUD while the player is busy (their last action not done, char.c continue_action()): {n} seconds left, rounded up.
	var text: String = tr("忙碌：约 {n} 秒后空下来").format({"n": ceili(left)})
	return WorldWait.new(text, 1.0 - left / _busy_total if _busy_total > 0.0 else 0.0)


## 朱鸿雪's task (quest.c): the time left of the time she gave.
func _task() -> WorldWait:
	var quest: CharacterQuestState = _player.state.quest
	if quest == null or not quest.has_task() or quest.current.time_seconds <= 0:
		return null
	var whole: float = quest.current.time_seconds * 1000.0
	if quest.remaining_ms <= 0:
		# TRANSLATORS: the HUD once 朱鸿雪's task time ran out (quest.c: 但是你已经没有足够的时间来完成它了。).
		return WorldWait.new(tr("朱鸿雪的任务：时间已过"), 1.0)
	# TRANSLATORS: the HUD while 朱鸿雪's task runs: {time} the time left as time_period() writes it (五分零秒).
	var text: String = tr("朱鸿雪的任务：还有{time}").format({"time": QuestStatus.period(QuestStatus.seconds_left(quest))})
	return WorldWait.new(text, 1.0 - quest.remaining_ms / whole)
