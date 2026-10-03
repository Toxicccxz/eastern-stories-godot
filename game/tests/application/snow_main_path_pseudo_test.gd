extends RefCounted

## Snow's main path once more, switching to the test pseudo-locale (PseudoLocale) in
## Settings after the first leg: from then on, at every check, each text on screen must
## have gone through a translation with a message the template (POT) knows.
const MainPath := preload("res://tests/application/snow_main_path_test.gd")


func run_all(tree: SceneTree) -> Dictionary:
	var story: RefCounted = MainPath.new()
	story.pseudo = true
	return await story.run_all(tree)
