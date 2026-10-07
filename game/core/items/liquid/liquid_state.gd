class_name LiquidState
extends RefCounted

enum Content { RED_WINE, CLEAR_WATER }

## feature/liquid.c liquid/type of each content.
const LEGACY_TYPES: Dictionary[StringName, Content] = { &"alcohol": Content.RED_WINE, &"water": Content.CLEAR_WATER }

var content: Content
var remaining: int
## liquid/drink_func: the item definition of the powder poured in (std/medicine/powder.c,
## obj/toy/poison_dust.c do_pour()), whose PourDefinition runs on every drink until
## the container is filled again; empty when nothing was poured in.
var drink_func: StringName = &""
## liquid/slumber_effect: what poison_dust.c's pours added (100 each); fill keeps it.
var slumber_effect: int = 0


func _init(p_content: Content, p_remaining: int, p_drink_func: StringName = &"", p_slumber_effect: int = 0) -> void:
	content = p_content
	remaining = p_remaining
	drink_func = p_drink_func
	slumber_effect = p_slumber_effect


## The liquid's LPC "liquid/name": 红酒 is what the wineskin is sold with,
## 清水 is what feature/liquid.c do_fill() puts in. A container's own alcohol has
## its authored name (陶壶's 米酒): ItemContentDefinition.liquid_name().
static func content_name(value: Content) -> String:
	return "红酒" if value == Content.RED_WINE else "清水"


static func legacy_type(value: Content) -> StringName:
	return LEGACY_TYPES.find_key(value)


func duplicate_state() -> LiquidState:
	return LiquidState.new(content, remaining, drink_func, slumber_effect)
