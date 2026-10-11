class_name WorldNearbyThing
extends RefCounted

## One thing within the player's reach, as the HUD lists them (owner, 2026-10-11: the
## actions show for what is near, one group per thing, nearest first).

enum Kind { NPC, CORPSE, ITEM, LANDMARK, DOOR, SERVICE }

var kind: Kind
## The NPC's character id, the corpse's or floor item's instance id, the landmark's,
## door's or service's id.
var id: StringName
## As authored (the HUD translates it); a corpse's is its victim's name.
var display_name: String = ""
var distance: float = 0.0
var npc: NpcRuntimeState
## A door's or a room's service, or the services the NPC offers from its body.
var services: Array[WorldService] = []
## The constable leading the player, listed beyond reach or in another room for his 行贿
## alone: nothing else is offered on him until he is near.
var bribe_only: bool = false


func _init(p_kind: Kind, p_id: StringName, p_name: String, p_distance: float) -> void:
	kind = p_kind
	id = p_id
	display_name = p_name
	distance = p_distance
