class_name LiquidState
extends RefCounted

enum Content { RED_WINE, CLEAR_WATER }

var content: Content
var remaining: int


func _init(p_content: Content, p_remaining: int) -> void:
	content = p_content
	remaining = p_remaining


## The liquid's LPC "liquid/name": 红酒 is what the wineskin is sold with,
## 清水 is what feature/liquid.c do_fill() puts in.
static func content_name(value: Content) -> String:
	return "红酒" if value == Content.RED_WINE else "清水"


func duplicate_state() -> LiquidState:
	return LiquidState.new(content, remaining)
