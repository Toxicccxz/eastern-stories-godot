class_name PlayerLifeOverlay
extends CanvasLayer

## Shows the player's unconsciousness and the way back from death. Reads the
## session's PlayerLifeFlow; the only thing it can do is show the next line.
const REVIVED_NOTICE_SECONDS: float = 4.0
## Basic skill names follow cmds/std/enable.c valid_types.
const SKILL_NAMES: Dictionary[StringName, String] = {
	&"unarmed": "基本拳脚", &"sword": "基本剑法", &"parry": "基本招架",
	&"dodge": "基本轻功", &"force": "基本内功", &"liuh-ken": "柳家拳",
}

var _session: OldPineWorldSessionController
var _dim: ColorRect
var _text: Label
var _continue: Button
var _last_phase: PlayerLifeFlow.Phase = PlayerLifeFlow.Phase.NONE
var _notice: String = ""
var _notice_remaining: float = 0.0


func configure(session: OldPineWorldSessionController) -> void:
	_session = session


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.72)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	_text = Label.new()
	_text.name = "LifeText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(300, 0)
	rows.add_child(_text)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = "继续"
	_continue.custom_minimum_size = Vector2(0, 44)
	_continue.pressed.connect(_on_continue)
	rows.add_child(_continue)
	visible = false


func text() -> String:
	return _text.text if visible else ""


func _process(delta: float) -> void:
	if _session == null or not _session.is_initialized():
		visible = false
		return
	var flow: PlayerLifeFlow = _session.player_life_flow()
	if flow.phase == PlayerLifeFlow.Phase.NONE and _last_phase != PlayerLifeFlow.Phase.NONE:
		_notice = "慢慢地你终於又有了知觉...." if _last_phase == PlayerLifeFlow.Phase.UNCONSCIOUS else "一阵浓雾散去，你发现自己站在雪亭镇的城隍庙里。"
		_notice_remaining = REVIVED_NOTICE_SECONDS
		# The defeat heading no longer describes the player.
		if _session.shared_ui() != null:
			_session.shared_ui().show_combat_result(_notice)
	_last_phase = flow.phase
	match flow.phase:
		PlayerLifeFlow.Phase.UNCONSCIOUS:
			_show("你的眼前一黑，接著什麽也不知道了....\n\n（约 %d 秒后醒来）" % ceili(flow.revive_remaining_seconds), false)
		PlayerLifeFlow.Phase.DEATH_SEQUENCE:
			_show(_death_text(flow), true)
		_:
			_notice_remaining -= delta
			if _notice_remaining > 0.0:
				_show(_notice, false)
			else:
				visible = false


func _show(value: String, can_continue: bool) -> void:
	visible = true
	_text.text = value
	_continue.visible = can_continue


func _death_text(flow: PlayerLifeFlow) -> String:
	var lines: Array[String] = ["你死了。"]
	var result: PlayerDeathResult = flow.death_result
	if result != null and result.penalized:
		var losses: Array[String] = []
		if result.combat_experience_lost > 0:
			losses.append("实战经验 -%d" % result.combat_experience_lost)
		if result.potential_lost > 0:
			losses.append("潜能 -%d" % result.potential_lost)
		if result.bellicosity_lost > 0:
			losses.append("杀气清零")
		if not losses.is_empty():
			lines.append(" · ".join(losses))
		var skills: Array[String] = []
		for change: SkillDeathPenaltyChange in result.skill_changes:
			var skill_name: String = SKILL_NAMES.get(change.skill_id, String(change.skill_id))
			if change.progress_cleared:
				skills.append("%s 学习进度清空" % skill_name)
			elif change.level_after < 0:
				skills.append("%s 失传" % skill_name)
			else:
				skills.append("%s %d→%d" % [skill_name, change.level_before, change.level_after])
		if not skills.is_empty():
			lines.append("技能：" + "；".join(skills))
	if not flow.corpse_place.is_empty():
		lines.append("你的尸体和随身物品留在：" + flow.corpse_place)
	lines.append("")
	lines.append("\n\n".join(flow.messages_shown()))
	return "\n".join(lines).strip_edges()


func _on_continue() -> void:
	if _session != null:
		_session.skip_death_message()
