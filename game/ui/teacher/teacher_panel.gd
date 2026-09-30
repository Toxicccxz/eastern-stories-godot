class_name TeacherPanel
extends CanvasLayer

## A teacher's talk panel: apprenticeship, learn, enable. The TeacherService
## owns the rules; this only presents them.
var _contact: TeacherService
var _rows: VBoxContainer
var panel: PanelContainer
var status: Label
var feedback: Label
var apprentice_button: Button
var cancel_button: Button
var learn_button: Button
var learn_liuh_button: Button
var enable_liuh_button: Button
var disable_liuh_button: Button


func configure(contact: TeacherService) -> void:
	_contact = contact


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.hide()
	add_child(panel)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.09, 0.10, 0.085, 1)
	for side: String in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 14.0)
	panel.add_theme_stylebox_override("panel", background)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	panel.add_child(_rows)
	_label("柳淳风 · 封山剑派掌门人", "Title")
	status = _label("", "Status")
	apprentice_button = _button("Apprentice", "拜师 / 向师父请安", request_apprentice)
	cancel_button = _button("CancelApprentice", "取消拜师请求", cancel_apprentice)
	learn_button = _button("Learn", "请教基本拳脚（一次）", request_learn)
	learn_liuh_button = _button("LearnLiuh", "请教柳家拳（一次）", request_learn_liuh)
	enable_liuh_button = _button("EnableLiuh", "启用柳家拳", enable_liuh)
	disable_liuh_button = _button("DisableLiuh", "停用柳家拳", disable_liuh)
	feedback = _label("馆主传授基本拳脚与柳家拳。每次请教均按当下状态结算。", "Feedback")
	_button("Close", "离开交谈", close_panel)


func _label(text: String, node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	return label


func _button(node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	_rows.add_child(button)
	return button


func interact() -> void:
	if ExplorationPresentationBlocker.is_blocked(get_tree()) or not _contact.can_teach():
		return
	_contact.open_panel("柳淳风 · 教学", panel)
	refresh()
	apprentice_button.grab_focus()


func _process(_delta: float) -> void:
	if not is_instance_valid(panel):
		return
	if panel.visible and not _contact.can_teach():
		close_panel()
	if panel.visible:
		refresh()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(panel) and panel.visible:
		_contact.map.player_body.quarantine_current_movement_input()


func refresh() -> void:
	var player := _contact.map.session.player_runtime()
	var state := player.state
	var mapping: StringName = state.skills.mapped_skill(&"unarmed")
	var mapping_name: String = "未启用" if mapping.is_empty() else (LiuhKenDefinition.DISPLAY_NAME if mapping == LiuhKenDefinition.SKILL_ID else String(mapping))
	status.text = "%s\n基本拳脚 %d · 学习进度 %d · 耗精 %s\n柳家拳 %d · 学习进度 %d · 耗精 %s\n拳脚映射：%s · 有效拳脚 %d\n精 %d（须大于消耗才可进步）\n可用潜能 %d · 实战经验 %d" % [
		player.facts.title, state.skills.raw_level(&"unarmed"), state.skills.learned_progress(&"unarmed"), _cost_text(state, &"unarmed"),
		state.skills.raw_level(LiuhKenDefinition.SKILL_ID), state.skills.learned_progress(LiuhKenDefinition.SKILL_ID), _cost_text(state, LiuhKenDefinition.SKILL_ID),
		mapping_name, state.skills.effective_level(&"unarmed", player.armor.aggregate_numeric_modifiers().unarmed),
		state.essence.current, state.progression.potential - state.progression.potential_spent, state.progression.combat_experience]
	cancel_button.visible = player.school_apprenticeship.is_pending()


func request_apprentice() -> void:
	if not panel.visible:
		return
	show_apprenticeship(_contact.request_apprentice())


func cancel_apprentice() -> void:
	if not panel.visible:
		return
	show_apprenticeship(_contact.cancel_apprentice())


func show_apprenticeship(outcome: SwordsmanApprenticeship.Outcome) -> void:
	match outcome:
		SwordsmanApprenticeship.Outcome.RECRUITED: feedback.text = "柳淳风收你为徒。你成为封山剑派第十四代弟子。"
		SwordsmanApprenticeship.Outcome.ACKNOWLEDGED: feedback.text = "你恭恭敬敬地向师父请安。"
		SwordsmanApprenticeship.Outcome.QUALIFICATION_REJECTED: feedback.text = "馆主认为你的胆识或定力不足。拜师请求仍在等待，可取消后再试。"
		SwordsmanApprenticeship.Outcome.PENDING: feedback.text = "馆主尚未答应你的拜师请求。可先取消。"
		SwordsmanApprenticeship.Outcome.CANCELLED: feedback.text = "你取消了拜师请求。"
		SwordsmanApprenticeship.Outcome.NO_PENDING: feedback.text = "你没有等待中的拜师请求。"
		SwordsmanApprenticeship.Outcome.OTHER_RELATIONSHIP_DEFERRED: feedback.text = "你已有师门关系；这里暂不提供改投师门。"
		_: feedback.text = "目前无法与馆主完成交谈。"
	refresh()


func request_learn() -> void:
	_learn(&"unarmed")


func request_learn_liuh() -> void:
	_learn(LiuhKenDefinition.SKILL_ID)


func _learn(skill_id: StringName) -> void:
	if not panel.visible:
		return
	var result := _contact.request_learn(skill_id)
	feedback.text = learn_message(result)
	refresh()


static func learn_message(result: LearnResult) -> String:
	var skill_name: String = LiuhKenDefinition.DISPLAY_NAME if result.skill_id == LiuhKenDefinition.SKILL_ID else "基本拳脚"
	var message: String
	match result.completion:
		LearnResult.Completion.LEVEL_INCREASED: message = "你的%s进步了！" % skill_name
		LearnResult.Completion.PROGRESSED: message = "你有所领悟，学习进度增加，尚未升级。"
		LearnResult.Completion.NO_PROGRESS_INSUFFICIENT_ESSENCE: message = "你太累了，未有进步；已耗尽当前精。"
		LearnResult.Completion.NO_PROGRESS_COMBAT_EXPERIENCE: message = "实战经验不足，未有进步；仍消耗了精。"
		LearnResult.Completion.NO_PROGRESS_TEACHER_FATIGUE: message = "馆主太疲倦，未能授课。"
		LearnResult.Completion.LEGACY_ERROR: message = "学习计算或随机来源异常，请停止操作；此前变化保留。"
		_:
			match result.failure_reason:
				LearnResult.FailureReason.POTENTIAL_EXHAUSTED: message = "你的可用潜能已耗尽。"
				LearnResult.FailureReason.RECOGNITION_POLICY_ABSENT, LearnResult.FailureReason.RECOGNITION_REJECTED: message = "馆主尚未认可你的求教关系。"
				LearnResult.FailureReason.TEACHER_PREVENTED: message = "馆主不愿继续传授这项技能。"
				LearnResult.FailureReason.STUDENT_SKILL_NOT_BELOW_TEACHER: message = "这项技能的程度已不低于馆主。"
				_: message = "本次请教未获准（原因 %d）。" % result.failure_reason
	if result.created_explicit_zero_skill_entry:
		message += " 已建立%s零级记录。" % skill_name
	return message


func close_panel() -> void:
	if not is_instance_valid(panel):
		return
	var was_open: bool = panel.visible
	panel.hide()
	_contact.map.session.shared_ui().close_business(panel)
	if was_open and is_instance_valid(_contact.map.player_body):
		_contact.map.player_body.quarantine_current_movement_input()


static func _cost_text(state: CharacterState, skill_id: StringName) -> String:
	if state.attributes.intelligence == 0:
		return "无法计算"
	@warning_ignore("integer_division")
	var cost: int = 150 / SnowSchoolTeacher.INTELLIGENCE + 150 / state.attributes.intelligence
	return str(cost * 2 if state.skills.raw_level(skill_id) == 0 else cost)


func enable_liuh() -> void:
	if not panel.visible:
		return
	feedback.text = "拳脚已启用柳家拳。" if _contact.enable_liuh() else "无法启用：须在馆主面前，并已学会基本拳脚与柳家拳。"
	refresh()


func disable_liuh() -> void:
	if not panel.visible:
		return
	feedback.text = "拳脚已停用柳家拳；技能与学习进度保留。" if _contact.disable_liuh() else "目前无法停用柳家拳。"
	refresh()
