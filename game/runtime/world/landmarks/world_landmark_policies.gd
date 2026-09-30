class_name WorldLandmarkPolicies
extends RefCounted

## WorldLandmarkDefinition.policy → the runtime rule.
const SCRIPTS: Dictionary[StringName, Script] = {
	&"portal": preload("res://runtime/world/landmarks/portal_landmark_policy.gd"),
	&"vine": preload("res://runtime/world/landmarks/vine_landmark_policy.gd"),
}


static func create(policy: StringName) -> WorldLandmarkPolicy:
	var script: Script = SCRIPTS.get(policy)
	return null if script == null else script.new() as WorldLandmarkPolicy
