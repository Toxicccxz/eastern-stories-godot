class_name InteractionOption
extends RefCounted

## One thing the interaction popup offers on what the player stands by (DECISIONS「说话和交互」):
## its label (source text), what pressing it does, its hover, and, when the rules refuse it
## now, why (the popup shows it greyed with that line).

var label: String
var action: Callable
var hint: String
## A service's verb (购买, 请教): drawn as the accent button.
var accent: bool
## "" while it can be done; otherwise the line saying why not (shown language).
var reason: String


func _init(p_label: String, p_action: Callable, p_hint: String = "", p_accent: bool = false, p_reason: String = "") -> void:
	label = p_label
	action = p_action
	hint = p_hint
	accent = p_accent
	reason = p_reason


func available() -> bool:
	return reason.is_empty()
