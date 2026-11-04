class_name SharedUiQuestions
extends RefCounted
## The shared frame's question before an important or deadly choice (owner, 2026-10-06):
## ConfirmPrompt's 确定 runs the choice, 取消 goes back where it came from. Code moved
## from SharedGameplayUI as it was; the HUD is `_ui`.
##
## Seam for gamepad input (not built yet): this is the HUD's only modal question; A/B map
## to its confirm/cancel, and it already gives 取消 the focus.


var _ui: SharedGameplayUI
var _confirmed_action: Callable = Callable()
var _cancelled_action: Callable = Callable()

# The HUD's authorities, read as SharedGameplayUI reads them.
var _presentation_layout: SharedGameplayLayout:
	get: return _ui._presentation_layout


func _init(ui: SharedGameplayUI) -> void:
	_ui = ui


## Asks in the shared frame before an important or deadly choice (owner,
## 2026-10-06): `action` runs on the choice; 取消, 关闭 or Back drop it, and 取消 then
## runs `on_cancel` (back where the question came from). While `still_valid` returns
## false the question closes, as any panel does. `about` (in the shown language) says above
## the question what the choice is about.
func ask_first(text: String, choice: String, action: Callable, still_valid: Callable = Callable(), on_cancel: Callable = Callable(), about: String = "", danger: bool = false) -> void:
	_confirmed_action = action
	_cancelled_action = on_cancel
	_ui.confirm_prompt.ask(text, choice, "取消", about, danger)
	_presentation_layout.open_panel(tr("请确认"), _ui.confirm_prompt, still_valid)
	if _presentation_layout._content == _ui.confirm_prompt:
		# A question that wraps is taller than the frame's first layout.
		_presentation_layout.refresh_rows()
		_ui.confirm_prompt.focus_default()
	else:
		_ui.confirm_prompt.cancel()


## ask_first() for a choice that can cost the player their life, their senses or what they
## own (攻击, a risky 切磋, 偷窃, 上吊, a spell that knocks them out): its button is dark
## lacquer, not vermilion (界面重做 3; DECISIONS「界面样式」).
func ask_danger(text: String, choice: String, action: Callable, still_valid: Callable = Callable(), on_cancel: Callable = Callable(), about: String = "") -> void:
	ask_first(text, choice, action, still_valid, on_cancel, about, true)


## Whether the shared frame is asking (ask_first()).
func is_asking() -> bool:
	return _ui.confirm_prompt.is_asking() and _presentation_layout._content == _ui.confirm_prompt


func on_prompt_confirmed() -> void:
	var action: Callable = _confirmed_action
	_confirmed_action = Callable()
	_cancelled_action = Callable()
	# Asked in the interaction popup (its page): a choice that opens nothing more (攻击
	# begun) is done there, and the popup closes as after a row that opens nothing.
	var in_popup: bool = _ui.interaction_open()
	_presentation_layout.close_panel()
	if action.is_valid():
		action.call()
	if in_popup and _ui.interaction_open() and _presentation_layout.page() == null:
		_presentation_layout.close_frame()


func on_prompt_cancelled() -> void:
	var back: Callable = _cancelled_action
	_confirmed_action = Callable()
	_cancelled_action = Callable()
	# Hidden along with the HUD (a fight starts), _process() closes the frame itself;
	# closing it here would reparent the prompt while its visibility propagates.
	if _presentation_layout._content == _ui.confirm_prompt and _ui.confirm_prompt.is_visible_in_tree():
		_presentation_layout.close_panel()
		if back.is_valid():
			back.call()
