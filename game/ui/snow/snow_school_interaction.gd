class_name SnowSchoolInteraction
extends CanvasLayer

var _contact: SnowSchoolContact
var _presenter: SafeAreaPresenter
var _layout: ResponsivePanelLayout
var _rows: VBoxContainer
var contact_button: Button
var panel: PanelContainer
var status: Label
var feedback: Label
var apprentice_button: Button
var cancel_button: Button
var learn_button: Button


func configure(contact: SnowSchoolContact) -> void:
	_contact = contact


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	contact_button = Button.new()
	contact_button.name = "Contact"
	contact_button.custom_minimum_size = Vector2(240, 64)
	contact_button.pressed.connect(interact)
	add_child(contact_button)
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
	feedback = _label("馆主传授基本拳脚。每次请教均按当下状态结算。", "Feedback")
	_button("Close", "离开交谈", close_panel)
	_layout = ResponsivePanelLayout.new()
	add_child(_layout)
	_layout.initialize(panel)
	_layout.blocks_touch_gameplay = true
	_layout.dismiss_requested.connect(close_panel)
	panel.add_child(ExplorationPresentationBlocker.new())
	tree_entered.connect(_attach_presenter)
	tree_exiting.connect(_detach_presenter)
	_attach_presenter()
	_process(0.0)


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


func _attach_presenter() -> void:
	_presenter = SafeAreaPresenter.find_or_create(self)
	if not _presenter.metrics_changed.is_connected(_reflow):
		_presenter.metrics_changed.connect(_reflow)
	_reflow(_presenter.current_metrics())


func _detach_presenter() -> void:
	close_panel()
	if is_instance_valid(_presenter) and _presenter.metrics_changed.is_connected(_reflow):
		_presenter.metrics_changed.disconnect(_reflow)
	_presenter = null


func _reflow(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	_layout.apply(metrics, metrics.content_rect(), true, 570)
	contact_button.position = metrics.content_rect().position + Vector2(0, 96)
	contact_button.size = Vector2(minf(330, metrics.content_rect().size.x), 64)


func interact() -> void:
	if ExplorationPresentationBlocker.is_blocked(get_tree()):
		return
	if _contact.can_operate_door():
		if _contact.door_is_open():
			_contact.close_door()
		else:
			_contact.open_door()
	elif _contact.can_teach():
		panel.show()
		refresh()
		apprentice_button.grab_focus()
		_contact.map.player_body.quarantine_current_movement_input()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and not event.is_echo() and contact_button.visible:
		interact()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_instance_valid(panel):
		return
	if panel.visible and not _contact.can_teach():
		close_panel()
	contact_button.visible = not panel.visible and not ExplorationPresentationBlocker.is_blocked(get_tree()) and (_contact.can_operate_door() or _contact.can_teach())
	contact_button.text = ("关闭红漆大门" if _contact.door_is_open() else "打开红漆大门") + " [Enter / A]" if _contact.can_operate_door() else "与柳淳风交谈 [Enter / A]"
	if panel.visible:
		refresh()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(panel) and panel.visible:
		_contact.map.player_body.quarantine_current_movement_input()


func refresh() -> void:
	var player := _contact.session.player_runtime()
	var state := player.state
	var cost_text: String = "无法计算"
	if state.attributes.intelligence != 0:
		@warning_ignore("integer_division")
		var cost: int = 150 / SnowSchoolTeacher.INTELLIGENCE + 150 / state.attributes.intelligence
		if state.skills.raw_level(&"unarmed") == 0:
			cost *= 2
		cost_text = str(cost)
	status.text = "%s\n基本拳脚 %d · 学习进度 %d\n精 %d · 本次耗精 %s（精须大于消耗才可进步）\n可用潜能 %d · 实战经验 %d" % [player.facts.title, state.skills.raw_level(&"unarmed"), state.skills.learned_progress(&"unarmed"), state.essence.current, cost_text, state.progression.potential - state.progression.potential_spent, state.progression.combat_experience]
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
	if not panel.visible:
		return
	var result := _contact.request_learn()
	feedback.text = learn_message(result)
	refresh()


static func learn_message(result: LearnResult) -> String:
	var message: String
	match result.completion:
		LearnResult.Completion.LEVEL_INCREASED: message = "你的基本拳脚进步了！"
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
		message += " 已建立基本拳脚零级记录。"
	return message


func close_panel() -> void:
	if not is_instance_valid(panel):
		return
	var was_open: bool = panel.visible
	panel.hide()
	if was_open and is_instance_valid(_contact.map.player_body):
		_contact.map.player_body.quarantine_current_movement_input()
