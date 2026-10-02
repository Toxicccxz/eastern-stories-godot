class_name WorldNpcBody2D
extends WorldCharacterBody2D

## The body a map gives each spawned NPC (scenes/world/common/world_npc_body.tscn).
## Its AggressionPresence circle is the native stand-in for "in the same room".


func configure_npc(spawn: NpcSpawnDefinition, definition: NpcDefinition) -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = float(spawn.presence_radius)
	(get_node("AggressionPresence/CollisionShape2D") as CollisionShape2D).shape = circle
	var beast: bool = definition.race_id == &"beast"
	(get_node("HumanVisual") as CanvasItem).visible = not beast
	(get_node("BeastVisual") as CanvasItem).visible = beast


func presence() -> Area2D:
	return get_node("AggressionPresence") as Area2D


## A walking NPC goes through the player instead of shoving them aside, and
## notices nobody on the way: ES2 moved it in one step, and its init() met who was
## where it arrived. Its presence comes back on there.
func set_walking(value: bool) -> void:
	(get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", value)
	(get_node("AggressionPresence/CollisionShape2D") as CollisionShape2D).set_deferred("disabled", value)
