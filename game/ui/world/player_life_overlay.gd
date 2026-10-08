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

var _session: WorldSessionController
var _dim: ColorRect
var _text: Label
var _continue: Button
var _last_phase: PlayerLifeFlow.Phase = PlayerLifeFlow.Phase.NONE
var _notice: String = ""
var _notice_remaining: float = 0.0


func configure(session: WorldSessionController) -> void:
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
		_notice = tr("慢慢地你终於又有了知觉....") if _last_phase == PlayerLifeFlow.Phase.UNCONSCIOUS else tr("一阵浓雾散去，你发现自己站在雪亭镇的城隍庙里。")
		_notice_remaining = REVIVED_NOTICE_SECONDS
		# The defeat heading no longer describes the player.
		if _session.shared_ui() != null:
			_session.shared_ui().show_combat_result(_notice)
	_last_phase = flow.phase
	match flow.phase:
		PlayerLifeFlow.Phase.UNCONSCIOUS:
			var wake: String = tr("（约 %d 秒后醒来）") % ceili(flow.revive_remaining_seconds) if flow.revive_remaining_seconds > 0.0 else tr("（仍然昏迷不醒……）")
			# TRANSLATORS: unconsciousness; {wake} says when the player comes to.
			_show(tr("你的眼前一黑，接著什麽也不知道了....\n\n{wake}").format({"wake": wake}), false, true)
		PlayerLifeFlow.Phase.DEATH_SEQUENCE:
			_show(_death_text(flow), true, true)
		_:
			_notice_remaining -= delta
			if _notice_remaining > 0.0:
				_show(_notice, false, false)
			else:
				visible = false


## A blocking screen dims the world and takes its clicks; the short notice
## after coming back does neither.
func _show(value: String, can_continue: bool, blocking: bool) -> void:
	visible = true
	_text.text = value
	_continue.visible = can_continue
	_dim.color.a = 0.72 if blocking else 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE


func _death_text(flow: PlayerLifeFlow) -> String:
	var lines: Array[String] = [tr("你死了。")]
	var result: PlayerDeathResult = flow.death_result
	if result != null and result.penalized:
		var losses: Array[String] = []
		if result.combat_experience_lost > 0:
			losses.append(tr("实战经验 -%d") % result.combat_experience_lost)
		if result.potential_lost > 0:
			losses.append(tr("潜能 -%d") % result.potential_lost)
		if result.bellicosity_lost > 0:
			losses.append(tr("杀气清零"))
		if not losses.is_empty():
			lines.append(" · ".join(losses))
		var skills: Array[String] = []
		for change: SkillDeathPenaltyChange in result.skill_changes:
			var skill_name: String = tr(SKILL_NAMES[change.skill_id]) if SKILL_NAMES.has(change.skill_id) else String(change.skill_id)
			if change.progress_cleared:
				skills.append(tr("%s 学习进度清空") % skill_name)
			elif change.level_after < 0:
				skills.append(tr("%s 失传") % skill_name)
			else:
				skills.append(tr("{skill} {before}→{after}").format({"skill": skill_name, "before": change.level_before, "after": change.level_after}))
		if not skills.is_empty():
			# TRANSLATORS: the skills death changed, joined by the list separator below.
			lines.append(tr("技能：%s") % tr("；").join(skills))
		if result.enabled_skills_cleared > 0:
			lines.append(tr("已启用的特殊武功全部取消启用"))
	if not flow.corpse_place.is_empty():
		var corpse: StringName = flow.corpse_item_instance_id
		if corpse.is_empty() or _session.inventory_state().is_registered(corpse):
			lines.append(tr("你的尸体和随身物品留在：%s") % flow.corpse_place)
		else:
			# The corpse is gone (化尸粉); the dead do not see how.
			lines.append(tr("你的尸体已经不在了。"))
	lines.append("")
	lines.append("\n\n".join(flow.messages_shown().map(func(message: String) -> String: return tr(message))))
	return "\n".join(lines).strip_edges()


func _on_continue() -> void:
	if _session != null:
		_session.skip_death_message()
