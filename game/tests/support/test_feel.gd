class_name TestFeel
extends RefCounted

## Suites run with the feel off (run_suite.gd, DECISIONS「手感」): a fade, an eased walk or
## a bubble changes only how a thing looks, and a suite that walks through a passage
## expects the new map at once. A suite about the feel turns pacing.json's on with use()
## and restore() when it is done. The loading screen stays off there: a world not yet built
## would hold what such a suite times in seconds, and so does a journey's start in slices.
## map_loading_test and session_start_slices_test set their own.

static var production: FeelDefinition = FeelDefinition.new()


## The suite runner, once: keeps pacing.json's feel and turns it off.
static func turn_off() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	production = pacing.feel
	pacing.feel = FeelDefinition.new()


static func use() -> void:
	GameContent.catalog().pacing().feel = production.but({"map_loading_slice_ms": 0, "session_start_slice_ms": 0})


static func restore() -> void:
	GameContent.catalog().pacing().feel = FeelDefinition.new()
