class_name WindspringDeathItemPolicy
extends "res://core/death/death_item_policy.gd"

const SpawnIntentType := preload(
	"res://core/death/deferred_npc_spawn_intent.gd"
)
const LEGACY_SWORD_SOUL_SOURCE := (
	"reference/es2/mudlib/daemon/class/scholar/sword_soul.c"
)


func evaluate(context: ContextType, item: FactsType) -> ResultType:
	if context.victim_matches_sword_soul_alias:
		return ResultType.new(ResultType.Outcome.KEEP, item.item_instance_id)
	var target: ContainmentEndpoint = null
	if context.killer_was_present:
		target = context.killer_world_endpoint
	else:
		target = context.victim_environment.endpoint
	if target == null or not target.is_valid():
		return ResultType.new(
			ResultType.Outcome.DEPENDENCY_UNAVAILABLE,
			item.item_instance_id,
		)
	return ResultType.new(
		ResultType.Outcome.DEFERRED_RUNTIME_EFFECT,
		item.item_instance_id,
		SpawnIntentType.new(
			item.item_instance_id,
			&"",
			LEGACY_SWORD_SOUL_SOURCE,
			target,
		),
	)
