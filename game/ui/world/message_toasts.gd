class_name MessageToasts
extends Control

## The scene's messages at the HUD's bottom left (owner, 2026-10-06): a new one rises
## from below and pushes the older one up; with more than two the oldest drifts up and
## fades out. Each fades out the same way once it has been read for a while. The host
## suppresses them while a panel or a fight shows its own lines (dialogue stays in its
## panel); what comes then is not toasted, and every line stays in 消息. The toasts
## are a fixed pool of nodes, so reflows and messages never add or free any.

## How many toasts show at once.
const SHOWN: int = 2
## One more than SHOWN: the one fading out while a new one rises.
const POOL: int = SHOWN + 1
const GAP: float = 8.0
## How far a toast rises as it comes in and as it fades out.
const RISE: float = 18.0
## How quickly positions and alpha follow their targets (1/s).
const EASE: float = 14.0
## Messages that come together still come in one after another.
const SPACING_SECONDS: float = 0.3
## A shown toast is read at least this long before a newer one pushes it out.
const MIN_SHOWN_SECONDS: float = 1.2
## Waiting messages beyond this are dropped, oldest first (消息 keeps them).
const MAX_WAITING: int = 4
## How long a toast stays: a short line LINGER_MIN, longer by length up to LINGER_MAX.
const LINGER_MIN: float = 6.0
const LINGER_MAX: float = 14.0
const LINGER_PER_CHARACTER: float = 0.08
const PLAIN_TEXT: Color = Color(0.93, 0.94, 0.9)
const ACCENT: Color = Color(0.86, 0.72, 0.42)


## One message: its text and colour (`colored`: an ES2 colour, not the plain text one).
class Entry:
	extends RefCounted
	var text: String = ""
	var color: Color = PLAIN_TEXT
	var colored: bool = false


class Toast:
	extends RefCounted
	var panel: PanelContainer
	var label: Label
	var style: StyleBoxFlat
	var entry: Entry
	var y: float = 0.0
	var alpha: float = 0.0
	var age: float = 0.0
	var linger: float = 0.0
	var leaving: bool = false
	## Where it rises to as it fades out.
	var leave_to: float = INF


var _pool: Array[Toast] = []
## Oldest first; a leaving one stays here until it has faded.
var _shown: Array[Toast] = []
var _waiting: Array[Entry] = []
var _cooldown: float = 0.0
var _suppressed: bool = false
var _max_lines: int = 3
var _width: float = 420.0
var _latest: Entry


func _init() -> void:
	name = "MessageToasts"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in POOL:
		var toast := Toast.new()
		toast.panel = PanelContainer.new()
		toast.panel.name = "Toast%d" % index
		toast.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toast.style = StyleBoxFlat.new()
		toast.style.bg_color = Color(0.045, 0.06, 0.07, 0.84)
		toast.style.border_color = ACCENT
		toast.style.border_width_left = 3
		toast.style.set_corner_radius_all(10)
		toast.style.shadow_color = Color(0, 0, 0, 0.3)
		toast.style.shadow_size = 6
		toast.style.content_margin_left = 14.0
		toast.style.content_margin_right = 14.0
		toast.style.content_margin_top = 8.0
		toast.style.content_margin_bottom = 8.0
		toast.panel.add_theme_stylebox_override("panel", toast.style)
		toast.label = Label.new()
		toast.label.name = "Text"
		toast.label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toast.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		toast.label.add_theme_font_size_override("font_size", 15)
		# The lines come in the shown language already.
		toast.label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		toast.panel.add_child(toast.label)
		toast.panel.hide()
		add_child(toast.panel)
		_pool.append(toast)


## Where the toasts sit: `area` is the safe content rect in the parent's coordinates;
## they keep to its left edge and bottom, `width` wide, at most `max_lines` lines each.
func place(area: Rect2, width: float, max_lines: int) -> void:
	position = area.position
	size = area.size
	_max_lines = maxi(1, max_lines)
	_width = minf(width, area.size.x)
	for toast: Toast in _pool:
		toast.panel.custom_minimum_size.x = _width
		toast.panel.size.x = _width
		toast.label.max_lines_visible = _max_lines
		_fit_label(toast)
	_layout(0.0, true)


## A message for the toasts; dropped while they are suppressed.
func push(text: String, color: Color = PLAIN_TEXT, colored: bool = false) -> void:
	if _suppressed or text.strip_edges().is_empty():
		return
	var entry := Entry.new()
	entry.text = text
	entry.color = color
	entry.colored = colored
	_latest = entry
	_waiting.append(entry)
	while _waiting.size() > MAX_WAITING:
		_waiting.pop_front()


## While a panel or a fight shows its own lines: no toasts, and the ones showing go.
func set_suppressed(on: bool) -> void:
	if on == _suppressed:
		return
	_suppressed = on
	visible = not on
	if on:
		clear()


func is_suppressed() -> bool:
	return _suppressed


func clear() -> void:
	_waiting.clear()
	for toast: Toast in _shown:
		toast.panel.hide()
	_shown.clear()
	_latest = null


## The newest message taken (showing or still waiting), or null.
func latest() -> Entry:
	return _latest


func latest_text() -> String:
	return "" if _latest == null else _latest.text


## The texts showing now, oldest first, without the one fading out.
func shown_texts() -> Array[String]:
	var texts: Array[String] = []
	for toast: Toast in _shown:
		if not toast.leaving:
			texts.append(toast.entry.text)
	return texts


func _process(delta: float) -> void:
	if _suppressed:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	for toast: Toast in _shown:
		toast.age += delta
	if not _waiting.is_empty() and _cooldown <= 0.0 and _room_for_next():
		_show(_waiting.pop_front())
		_cooldown = SPACING_SECONDS
	# They go in order: only the oldest standing one fades out by time.
	var oldest: Toast = _oldest_standing()
	if oldest != null and oldest.age >= oldest.linger:
		oldest.leaving = true
	_layout(delta, false)


## A new toast may come in: fewer than SHOWN stand, or the oldest has been read long enough.
func _room_for_next() -> bool:
	var standing: int = 0
	for toast: Toast in _shown:
		if not toast.leaving:
			standing += 1
	var oldest: Toast = _oldest_standing()
	return standing < SHOWN or oldest == null or oldest.age >= MIN_SHOWN_SECONDS


func _oldest_standing() -> Toast:
	for toast: Toast in _shown:
		if not toast.leaving:
			return toast
	return null


func _show(entry: Entry) -> void:
	var toast: Toast = _free_toast()
	if toast == null:
		return
	toast.entry = entry
	toast.label.text = entry.text
	_fit_label(toast)
	if entry.colored:
		toast.label.add_theme_color_override("font_color", entry.color)
		toast.style.border_color = entry.color
	else:
		toast.label.add_theme_color_override("font_color", PLAIN_TEXT)
		toast.style.border_color = ACCENT
	toast.age = 0.0
	toast.linger = clampf(LINGER_MIN + entry.text.length() * LINGER_PER_CHARACTER, LINGER_MIN, LINGER_MAX)
	toast.leaving = false
	toast.leave_to = INF
	toast.alpha = 0.0
	toast.panel.size.y = 0
	toast.panel.modulate.a = 0.0
	toast.panel.show()
	# It comes in from below its place (the stack rests RISE above the bottom).
	toast.y = size.y - _height(toast)
	_shown.append(toast)
	# Past SHOWN, the oldest still standing makes way.
	var standing: int = 0
	for index: int in range(_shown.size() - 1, -1, -1):
		if _shown[index].leaving:
			continue
		standing += 1
		if standing > SHOWN:
			_shown[index].leaving = true


## A pooled toast not in use; the oldest leaving one when all are.
func _free_toast() -> Toast:
	for toast: Toast in _pool:
		if not _shown.has(toast):
			return toast
	for toast: Toast in _shown:
		if toast.leaving:
			_shown.erase(toast)
			toast.panel.hide()
			return toast
	return null


## The label wraps at the toast's width at once, not a frame later.
func _fit_label(toast: Toast) -> void:
	toast.label.size = Vector2(maxf(1.0, _width - toast.style.content_margin_left - toast.style.content_margin_right), 0.0)


func _height(toast: Toast) -> float:
	return toast.panel.get_combined_minimum_size().y


## Stacks the standing toasts up from RISE above the bottom, newest lowest; a leaving
## one rises RISE from where it was and fades. `snap` jumps to the targets (a reflow).
func _layout(delta: float, snap: bool) -> void:
	var weight: float = 1.0 if snap else 1.0 - exp(-EASE * delta)
	var bottom: float = size.y - RISE
	var done: Array[Toast] = []
	for index: int in range(_shown.size() - 1, -1, -1):
		var toast: Toast = _shown[index]
		var height: float = _height(toast)
		toast.panel.size.y = height
		if toast.leaving:
			if toast.leave_to == INF:
				toast.leave_to = toast.y - RISE
			toast.y = lerpf(toast.y, toast.leave_to, weight)
			toast.alpha = 0.0 if snap else lerpf(toast.alpha, 0.0, weight)
		else:
			toast.leave_to = INF
			toast.y = lerpf(toast.y, bottom - height, weight)
			toast.alpha = lerpf(toast.alpha, 1.0, weight)
			bottom -= height + GAP
		# Always inside the area: the top of the stack is as far as a toast goes.
		toast.panel.position = Vector2(0.0, clampf(toast.y, 0.0, maxf(0.0, size.y - height)))
		toast.panel.modulate.a = toast.alpha
		if toast.leaving and toast.alpha < 0.02:
			done.append(toast)
	for toast: Toast in done:
		toast.panel.hide()
		_shown.erase(toast)
