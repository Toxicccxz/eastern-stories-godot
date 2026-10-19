extends Theme
## The project's theme: the lacquer surface of the skin (UiSkin), so whatever names no theme of
## its own (the map's labels, the overlays) keeps light text on dark.

## Loaded before the global class names are known: the skin by path.
const SkinScript := preload("res://ui/theme/ui_skin.gd")


func _init() -> void:
	merge_with(SkinScript.lacquer_theme())
