class_name LiquidState
extends RefCounted

enum Content { RED_WINE, CLEAR_WATER }

var content: Content
var remaining: int


func _init(p_content: Content, p_remaining: int) -> void:
	content = p_content
	remaining = p_remaining


func duplicate_state() -> LiquidState:
	return LiquidState.new(content, remaining)
