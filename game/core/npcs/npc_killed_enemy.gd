class_name NpcKilledEnemy
extends RefCounted

## An NPC's killed_enemy() (combatd.c killer_reward() calls it on the killer, before
## the victim's corpse is made): d/oldpine/npc/spy.c says `say` and, `dissolve_after_ms`
## later (call_out("dissolve", 1)), runs `dissolve corpse` with the 化尸粉 it carries
## (obj/dust.c), which dissolves the newest corpse in the room (MudOS present() finds
## the object moved in last). 0 dissolves nothing.
var say: String
var dissolve_after_ms: int


func _init(p_say: String = "", p_dissolve_after_ms: int = 0) -> void:
	say = p_say
	dissolve_after_ms = p_dissolve_after_ms


func is_valid() -> bool:
	return dissolve_after_ms >= 0 and (not say.strip_edges().is_empty() or dissolve_after_ms > 0)


## `killed_enemy` {"say", "dissolve_after_ms"}.
static func from_record(reader: ContentRecordReader) -> NpcKilledEnemy:
	var hook := NpcKilledEnemy.new(reader.text("say"), reader.integer("dissolve_after_ms"))
	reader.finish()
	if not hook.is_valid():
		reader.fail("", "needs a say or a positive dissolve_after_ms")
	return hook
