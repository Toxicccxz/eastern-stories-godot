class_name InputDevices
extends RefCounted
## Which input the player uses now (ROADMAP "After the grey box" step 2, gamepad support):
## the keyboard and mouse, a gamepad, or touch. The last input that clearly came from one
## of them decides; button hints (InputGlyphTexture, InputHintRow) follow it at once.
## PadSupport feeds every input event in; tests set the kind directly.

signal changed

enum Kind { KEYBOARD_MOUSE, GAMEPAD, TOUCH }
## How the pad's face buttons are labelled (by position, as Godot numbers them).
enum PadStyle { XBOX, PLAYSTATION, NINTENDO }

## The device id of the pointer events MobileTouchAdapter makes from touches (it reads it
## from here: the HUD must not load the shell's scripts, which load the Session scene).
const TOUCH_POINTER_DEVICE: int = 10_202
## A stick or trigger counts as used past this (a resting stick drifts below it).
const MOTION_THRESHOLD: float = 0.5
## A mouse counts as used once it moves this far in one event (a desk bump does not).
const MOUSE_THRESHOLD: float = 4.0

static var _shared: InputDevices

var kind: int = Kind.KEYBOARD_MOUSE
var pad_style: int = PadStyle.XBOX


## The one instance the game's hints follow.
static func shared() -> InputDevices:
	if _shared == null:
		_shared = InputDevices.new()
		if MobileTouchCapability.new().enabled():
			_shared.kind = Kind.TOUCH
	return _shared


## Notes `event`: a kind change emits `changed`.
func observe(event: InputEvent) -> void:
	var seen: int = kind_of(event)
	if seen < 0:
		return
	var style: int = pad_style
	if seen == Kind.GAMEPAD:
		style = style_for(Input.get_joy_name(event.device))
	set_kind(seen, style)


func set_kind(value: int, style: int = pad_style) -> void:
	if value == kind and style == pad_style:
		return
	kind = value
	pad_style = style
	changed.emit()


func is_gamepad() -> bool:
	return kind == Kind.GAMEPAD


func is_touch() -> bool:
	return kind == Kind.TOUCH


## The kind `event` shows the player is using, or -1 when it says nothing (a resting stick,
## a released key, a tiny mouse move, an event the game made itself).
static func kind_of(event: InputEvent) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return Kind.TOUCH
	if event is InputEventJoypadButton:
		return Kind.GAMEPAD if event.pressed else -1
	if event is InputEventJoypadMotion:
		return Kind.GAMEPAD if absf(event.axis_value) >= MOTION_THRESHOLD else -1
	if event is InputEventKey:
		return Kind.KEYBOARD_MOUSE if event.pressed and not event.echo else -1
	if event is InputEventMouseButton:
		# The touch adapter's own pointer events stand for touches.
		if event.device == TOUCH_POINTER_DEVICE or event.device == InputEvent.DEVICE_ID_EMULATION:
			return -1
		return Kind.KEYBOARD_MOUSE if event.pressed else -1
	if event is InputEventMouseMotion:
		if event.device == TOUCH_POINTER_DEVICE or event.device == InputEvent.DEVICE_ID_EMULATION:
			return -1
		return Kind.KEYBOARD_MOUSE if event.relative.length() >= MOUSE_THRESHOLD else -1
	return -1


## The label style for a pad named `joy_name` (SDL's controller names).
static func style_for(joy_name: String) -> int:
	var lowered: String = joy_name.to_lower()
	for word: String in ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]:
		if lowered.contains(word):
			return PadStyle.PLAYSTATION
	for word: String in ["nintendo", "switch", "joy-con", "pro controller"]:
		if lowered.contains(word):
			return PadStyle.NINTENDO
	return PadStyle.XBOX
