class_name SceneBars
extends Control

## 过场黑边 (过场演出 A; DECISIONS「过场黑边」): while a scene holds the player
## (WorldSessionController.scene_held()) two black bars slide in from the top and the foot of the
## screen and the HUD steps away (SharedGameplayUI.scene_cover()), so a scene reads as one; they
## slide out when it ends. The picture only: nothing here holds or frees anyone. A fight hides the
## whole HUD, these with it, so the bars give way to the fight's opening at once.
## Data: FeelDefinition.scene_bars_seconds() and scene_bars_share() (0: no bars, the HUD stays).

var _ui: SharedGameplayUI
## How far the bars are in: 0 away, 1 whole.
var progress: float = 0.0
## A scene began and its last lines are still being read: the scene's steps are done before the
## dialogue box has read out the last of them, and the bars stay for those lines.
var _reading_on: bool = false


func configure(ui: SharedGameplayUI) -> void:
	_ui = ui


func _ready() -> void:
	name = "SceneBars"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Each bar's height now, in pixels.
func bar_height() -> float:
	return roundf(get_viewport_rect().size.y * GameContent.catalog().pacing().feel.scene_bars_share() * _eased())


func _process(delta: float) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var seconds: float = feel.scene_bars_seconds()
	var session: WorldSessionController = null if _ui == null else _ui.session()
	var held: bool = session != null and session.is_initialized() and session.scene_held()
	_reading_on = held or (_reading_on and _ui.dialogue_box.is_open())
	var wanted: float = 1.0 if seconds > 0.0 and _reading_on else 0.0
	# 系统 over a scene holds the bars where they are.
	if is_equal_approx(progress, wanted) or get_tree().paused:
		return
	progress = wanted if seconds <= 0.0 else move_toward(progress, wanted, delta / seconds)
	if _ui != null:
		_ui.scene_cover(_eased())
	queue_redraw()


func _eased() -> float:
	return ease(progress, 0.4) if progress < 1.0 else 1.0


func _draw() -> void:
	var height: float = bar_height()
	if height <= 0.0:
		return
	# The viewport's own size: a control under a CanvasLayer has none to anchor to.
	var view: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(0.0, 0.0, view.x, height), Color.BLACK)
	draw_rect(Rect2(0.0, view.y - height, view.x, height), Color.BLACK)
