class_name CombatSliceCorpseView
extends Node2D

var _corpse_item_instance_id: StringName = &""
var _victim_display_name: String = ""

var corpse_item_instance_id: StringName:
	get: return _corpse_item_instance_id
var victim_display_name: String:
	get: return _victim_display_name


func configure(corpse: CorpseState) -> bool:
	if corpse == null or not corpse.is_valid():
		return false
	_corpse_item_instance_id = corpse.corpse_item_instance_id
	_victim_display_name = corpse.victim_display_name
	queue_redraw()
	return true


func _draw() -> void:
	draw_polygon(
		PackedVector2Array([
			Vector2(-38.0, -9.0), Vector2(30.0, -9.0),
			Vector2(38.0, 9.0), Vector2(-30.0, 9.0),
		]),
		PackedColorArray([Color("665448")]),
	)
	draw_circle(Vector2(-38.0, 0.0), 11.0, Color("8a7461"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-52.0, 31.0),
		"%s's corpse" % _victim_display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color("d8c4aa"),
	)
