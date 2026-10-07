class_name WorldLandmarkPolicies
extends RefCounted

## WorldLandmarkDefinition.policy → the runtime rule.
const SCRIPTS: Dictionary[StringName, Script] = {
	&"portal": preload("res://runtime/world/landmarks/portal_landmark_policy.gd"),
	&"vine": preload("res://runtime/world/landmarks/vine_landmark_policy.gd"),
	&"hidden_passage": preload("res://runtime/world/landmarks/hidden_passage_landmark_policy.gd"),
	&"bury": preload("res://runtime/world/landmarks/bury_landmark_policy.gd"),
	&"join_class": preload("res://runtime/world/landmarks/join_class_landmark_policy.gd"),
	&"look": preload("res://runtime/world/landmarks/world_landmark_policy.gd"),
	&"push_stone": preload("res://runtime/world/landmarks/push_stone_landmark_policy.gd"),
	&"search": preload("res://runtime/world/landmarks/search_landmark_policy.gd"),
	&"look_spawn": preload("res://runtime/world/landmarks/look_spawn_landmark_policy.gd"),
}


static func create(policy: StringName) -> WorldLandmarkPolicy:
	var script: Script = SCRIPTS.get(policy)
	return null if script == null else script.new() as WorldLandmarkPolicy
