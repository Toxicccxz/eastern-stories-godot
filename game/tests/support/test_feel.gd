class_name TestFeel
extends RefCounted

## Suites run with the feel off (run_suite.gd, DECISIONS「手感」): a fade, an eased walk or
## a bubble changes only how a thing looks, and a suite that walks through a passage
## expects the new map at once. A suite about the feel turns pacing.json's on with use()
## and restore() when it is done. The loading screen stays off there: a world not yet built
## would hold what such a suite times in seconds, and so does a journey's start in slices.
## map_loading_test and session_start_slices_test set their own; use_shipped() keeps them on.

static var production: FeelDefinition = FeelDefinition.new()


## The suite runner, once: keeps pacing.json's feel and turns it off.
static func turn_off() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	production = pacing.feel
	pacing.feel = FeelDefinition.new()


static func use() -> void:
	GameContent.catalog().pacing().feel = production.but({"map_loading_slice_ms": 0, "session_start_slice_ms": 0})


## pacing.json's feel whole, the slices kept: New Game and Continue start over frames and each
## map's world goes up over frames behind the loading screen, as the player gets them
## (factory_settings_test walks the shell's way so once more). A suite using it waits for a
## world to be shown before it walks (MapPlaces.go_to() does).
static func use_shipped() -> void:
	GameContent.catalog().pacing().feel = production


## A cold process (a script run without run_suite) keeps pacing.json's feel; its journeys start
## in one frame as a suite's do, so a Continue's world is there a frame later (DECISIONS「加载画面」).
static func start_in_one_frame() -> void:
	var pacing: PacingDefinition = GameContent.catalog().pacing()
	pacing.feel = pacing.feel.but({"session_start_slice_ms": 0})


static func restore() -> void:
	GameContent.catalog().pacing().feel = FeelDefinition.new()
