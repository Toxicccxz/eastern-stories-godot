class_name MartialArtsPage
extends VBoxContainer

## The character panel's 武学 page: cmds/usr/skills.c's list, enable.c's uses with
## their enable, disable and practice buttons, exercise, enforce, meditate, respirate,
## exert, the 神通 conjured at oneself (conjure.c: 空识, 游识), the spells cast at oneself
## (cast.c: 阴阳眼), self-learning and study. 练习, 打坐, 冥思 and 修行 also go on and on
## (连续练习 …, TrainingProgress) until something stops them.
## PlayerMartialArts owns the rules; the page shows the state and repeats the lines
## the log received last. Buttons are rebuilt only when the set of actions changes.

# TRANSLATORS: cmds/usr/skills.c: the rank of a martial skill, one per ten levels.
const SKILL_RANKS: Array[String] = [
	"初学乍练", "粗通皮毛", "半生不熟", "马马虎虎", "驾轻就熟", "出类拔萃",
	"神乎其技", "出神入化", "登峰造极", "一代宗师", "深不可测",
]
# TRANSLATORS: cmds/usr/skills.c: the rank of a knowledge skill (读书识字), one per ten levels.
const KNOWLEDGE_RANKS: Array[String] = [
	"新学乍用", "初窥门径", "略知一二", "马马虎虎", "已有小成", "心领神会",
	"了然於胸", "豁然贯通", "举世无双", "震古铄今", "深不可测",
]
## skills.c marks a skill that is enabled for some use with □.
const MAPPED_MARK: String = "□"
## skills.c leaves two spaces for the others.
const UNMAPPED_MARK: String = "  "

var skills_text: Label
var force_text: StatCell
## How far 打坐 / 冥思 / 修行 can raise their maximum (CultivationService's caps).
var force_cap_text: Label
var mana_cap_text: Label
var atman_cap_text: Label
var bellicosity_text: StatCell
var no_uses: Label
var uses_box: VBoxContainer
var exercise_amount: SpinBox
var exercise_button: Button
var exercise_run_button: Button
## 练到 N 再停 (前两小时 A): the max_force a 连续打坐 runs on to; the id is the number, 0 不限.
var exercise_target: OptionButton
const EXERCISE_TARGETS: Array[int] = [0, 10, 25, 50, 100]
var enforce_amount: SpinBox
var enforce_button: Button
var mana_text: StatCell
var meditate_amount: SpinBox
var meditate_button: Button
var meditate_run_button: Button
var atman_text: StatCell
var respirate_amount: SpinBox
var respirate_button: Button
var respirate_run_button: Button
## DECISIONS「数值用到才出现」: the 冥思 and 修行 sections, there once 法力 and 灵力 are.
var meditate_rows: Array[Control] = []
var respirate_rows: Array[Control] = []
var exert_title: Label
var exert_row: HFlowContainer
var conjure_title: Label
var conjure_row: HFlowContainer
var spell_title: Label
var spell_row: HFlowContainer
var self_learn_title: Label
var self_learn_row: HFlowContainer
var study_title: Label
var study_row: HFlowContainer
var feedback: Label
## The continuous 练习 / 打坐 / 冥思 / 修行 under way, under the row that started it.
var progress: TrainingProgress
## Action -> its button: enable:<use>:<skill>, disable:<use>, practice:<use>,
## practice_run:<use>, exert:<function>, conjure:<function>, cast:<function>,
## self_learn:<skill>, study:<item instance>.
var buttons: Dictionary[String, Button] = {}
var _session: WorldSessionController
var _layout_key: String = "-"
var _use_texts: Dictionary[StringName, RichTextLabel] = {}
var _shown_factor: int = -1
## The 神通's lines after a 神通 button, else null (the page repeats PlayerMartialArts').
var _last_lines: Variant = null
## The button that started the run under way (it takes the focus back).
var _run_button: Button

# TRANSLATORS: the 武学 page's 神通 buttons' tooltips (daemon/class/bonze/essencemagic/): their costs and what may come of them.
const CONJURE_HINTS: Dictionary[StringName, String] = {
	&"void_sense": "施展「空识神通」：静思入定，有机会把灵力化为潜能（50 灵力、50 精）；也可能潜能降低，或一无所获。",
	&"drift_sense": "施展「游识神通」：去到一个你见过的人身边，可以跨地图（75 灵力、30 精）。对方的灵力越强，越难感应得到。",
}
# TRANSLATORS: the 武学 page's 法术 buttons' tooltips (daemon/class/taoist/necromancy/): their costs and what they do.
const SPELL_HINTS: Dictionary[StringName, String] = {
	&"astral_vision": "施展「阴阳眼」：看得见鬼魂，持续的秒数等于你的有效咒文等级（30 法力、5 神）。",
}


func _init() -> void:
	name = "MartialArts"
	add_theme_constant_override("separation", 8)
	_title("技能")
	skills_text = _label("Skills")
	_title("使用中的特殊技能")
	no_uses = _label("NoUses")
	no_uses.text = "你现在没有使用任何特殊技能。"
	uses_box = VBoxContainer.new()
	uses_box.name = "Uses"
	uses_box.add_theme_constant_override("separation", 6)
	add_child(uses_box)
	_title("打坐")
	force_text = _stat_line("Force")
	force_cap_text = _label("ForceCap")
	bellicosity_text = _stat_line("Bellicosity")
	_label("ExerciseCost").text = "每次花费的气"
	var exercise := HBoxContainer.new()
	exercise.name = "Exercise"
	exercise.add_theme_constant_override("separation", 8)
	add_child(exercise)
	exercise_amount = SpinBox.new()
	exercise_amount.name = "ExerciseAmount"
	# exercise.c's minimum; its help gives 30 as the usual amount.
	exercise_amount.min_value = 10
	exercise_amount.max_value = 100000
	exercise_amount.step = 1
	exercise_amount.value = 30
	exercise.add_child(exercise_amount)
	exercise_button = _button(exercise, "ExerciseButton", "打坐")
	exercise_button.pressed.connect(_exercise)
	# TRANSLATORS: the 武学 page's button that does 打坐 again and again until something stops it (DECISIONS「连续修炼」).
	exercise_run_button = _button(exercise, "ExerciseRunButton", "连续打坐")
	exercise_run_button.pressed.connect(_cultivate.bind(TrainingRun.Kind.EXERCISE))
	exercise_target = OptionButton.new()
	exercise_target.name = "ExerciseTarget"
	exercise_target.custom_minimum_size = Vector2(120, 40)
	# TRANSLATORS: the 武学 page beside 连续打坐: how far it runs (前两小时 A); 不限 stops at the first raised maximum.
	exercise_target.tooltip_text = tr("连续打坐练到这个内力上限再停；不限则上限每涨一点就停")
	for target: int in EXERCISE_TARGETS:
		# TRANSLATORS: 连续打坐's target: 不限 (stop at the first raise) or 练到 {target} (a max_force number).
		exercise_target.add_item(tr("不限") if target == 0 else tr("练到 {target}").format({"target": target}), target)
	exercise.add_child(exercise_target)
	_title("加力")
	var enforce := HBoxContainer.new()
	enforce.name = "Enforce"
	enforce.add_theme_constant_override("separation", 8)
	add_child(enforce)
	enforce_amount = SpinBox.new()
	enforce_amount.name = "EnforceAmount"
	# enforce.c: 0 (none) to query_skill("force") / 2 points of force a hit.
	enforce_amount.min_value = 0
	enforce_amount.step = 1
	enforce.add_child(enforce_amount)
	enforce_button = _button(enforce, "EnforceButton", "加力")
	enforce_button.pressed.connect(_enforce)
	meditate_rows.append(_title("冥思"))
	mana_text = _stat_line("Mana")
	mana_cap_text = _label("ManaCap")
	var meditate_cost: Label = _label("MeditateCost")
	meditate_cost.text = "每次花费的神"
	meditate_amount = _cost_box("Meditate")
	meditate_rows.append_array([mana_text, mana_cap_text, meditate_cost, meditate_amount.get_parent()])
	meditate_button = _button(meditate_amount.get_parent(), "MeditateButton", "冥思")
	meditate_button.pressed.connect(_meditate)
	# TRANSLATORS: the 武学 page's button that does 冥思 again and again until something stops it.
	meditate_run_button = _button(meditate_amount.get_parent(), "MeditateRunButton", "连续冥思")
	meditate_run_button.pressed.connect(_cultivate.bind(TrainingRun.Kind.MEDITATE))
	respirate_rows.append(_title("修行"))
	atman_text = _stat_line("Atman")
	atman_cap_text = _label("AtmanCap")
	var respirate_cost: Label = _label("RespirateCost")
	respirate_cost.text = "每次花费的精"
	respirate_amount = _cost_box("Respirate")
	respirate_rows.append_array([atman_text, atman_cap_text, respirate_cost, respirate_amount.get_parent()])
	respirate_button = _button(respirate_amount.get_parent(), "RespirateButton", "修行")
	respirate_button.pressed.connect(_respirate)
	# TRANSLATORS: the 武学 page's button that does 修行 again and again until something stops it.
	respirate_run_button = _button(respirate_amount.get_parent(), "RespirateRunButton", "连续修行")
	respirate_run_button.pressed.connect(_cultivate.bind(TrainingRun.Kind.RESPIRATE))
	exert_title = _title("运功")
	exert_row = _flow("Exert")
	conjure_title = _title("神通")
	conjure_row = _flow("Conjure")
	spell_title = _title("法术")
	spell_row = _flow("Spell")
	self_learn_title = _title("自学")
	self_learn_row = _flow("SelfLearn")
	study_title = _title("研读")
	study_row = _flow("Study")
	# Not "Feedback": SharedGameplayUI copies a panel's Feedback label into the log,
	# and these lines are there already.
	feedback = _label("LastLines")
	progress = TrainingProgress.new()
	add_child(progress)
	progress.finished.connect(_run_finished)


func configure(session: WorldSessionController) -> void:
	_session = session


## Fills the page from the current state, in the shown language.
func refresh() -> void:
	if _session == null or not _session.is_initialized() or _session.player_runtime() == null:
		return
	var arts: PlayerMartialArts = _session.martial_arts()
	var state: CharacterState = _session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	skills_text.text = _skills_list(state, catalog)
	_show_numbers(state, catalog)
	var caps: Array = [
		[force_cap_text, TrainingRun.Kind.EXERCISE, state.recovery.inner_force.maximum, CultivationService.exercise_cap(state, arts.apply_modifier(&"force")), SkillIds.FORCE],
		[mana_cap_text, TrainingRun.Kind.MEDITATE, state.recovery.mana.maximum, CultivationService.meditate_cap(state), SkillIds.SPELLS],
		[atman_cap_text, TrainingRun.Kind.RESPIRATE, state.recovery.atman.maximum, CultivationService.respirate_cap(state), SkillIds.MAGIC],
	]
	for cap: Array in caps:
		(cap[0] as Label).text = _cap_line(cap[1], cap[2], cap[3], catalog.skill(cap[4]))
	# Native hint (owner, modern fixes II): what 冥思 and 修行 need before they grow anything.
	meditate_button.tooltip_text = arts.cultivation_hint(SkillIds.SPELLS)
	respirate_button.tooltip_text = arts.cultivation_hint(SkillIds.MAGIC)
	enforce_amount.max_value = arts.enforce_limit()
	# The amount follows the factor whenever the factor changes.
	if state.attributes.force_factor != _shown_factor:
		_shown_factor = state.attributes.force_factor
		enforce_amount.set_value_no_signal(mini(_shown_factor, arts.enforce_limit()))
	var functions: Array[StringName] = arts.exert_functions()
	var conjures: Array[StringName] = _session.essence_magic().self_conjures()
	var spells: Array[StringName] = arts.self_spells()
	var rows: Array[Dictionary] = _use_rows(arts, state, catalog)
	var learnable: Array[StringName] = []
	for skill_id: StringName in SelfLearningService.SELF_LEARNABLE:
		if state.skills.raw_level(skill_id) > 0 and catalog.skill(skill_id) != null:
			learnable.append(skill_id)
	var books: Array[PlayerInventoryRowProjection] = arts.study_items()
	var keys: PackedStringArray = []
	for row: Dictionary in rows:
		keys.append("use:%s" % row.use)
		keys.append_array(row.actions)
	for function_id: StringName in functions:
		keys.append("exert:%s" % function_id)
	for function_id: StringName in conjures:
		keys.append("conjure:%s" % function_id)
	for function_id: StringName in spells:
		keys.append("cast:%s" % function_id)
	for skill_id: StringName in learnable:
		keys.append("self_learn:%s" % skill_id)
	for book: PlayerInventoryRowProjection in books:
		keys.append("study:%s" % book.item_instance_id)
	var key: String = "|".join(keys)
	if key != _layout_key:
		_layout_key = key
		_rebuild(rows, functions, conjures, spells, learnable, books)
	for row: Dictionary in rows:
		_use_texts[row.use].text = row.text
	# enable.c with nothing enabled.
	no_uses.visible = state.skills.enabled_use_ids().is_empty()
	_label_buttons(rows, learnable, books, catalog)
	for row: Dictionary in rows:
		var practice: String = "practice:%s" % row.use
		if buttons.has(practice):
			buttons[practice].tooltip_text = arts.practice_hint(row.use)
			buttons["practice_run:%s" % row.use].tooltip_text = arts.practice_hint(row.use)
	# While a run goes on, only its 停止 can be pressed.
	var running: bool = progress.running()
	for button: Button in buttons.values() + [exercise_button, exercise_run_button, enforce_button, meditate_button, meditate_run_button, respirate_button, respirate_run_button]:
		button.disabled = running
	for amount: SpinBox in [exercise_amount, enforce_amount, meditate_amount, respirate_amount]:
		amount.editable = not running
	exercise_target.disabled = running
	feedback.text = "\n".join(ColoredLine.texts(_last_lines if _last_lines != null else arts.last_lines))


## The page's numbers (DECISIONS「数值用到才出现」): 内力 (and 加力), 杀气 and 定力, 法力 with
## its 冥思 section and 灵力 with its 修行 section. Two on a line share its hover.
func _show_numbers(state: CharacterState, catalog: ContentCatalog) -> void:
	var force_line := PackedStringArray([tr("内力 {force} / {max_force}").format({"force": state.recovery.inner_force.current, "max_force": state.recovery.inner_force.maximum})])
	var force_hints := PackedStringArray([StatCell.stat_hint(&"force")])
	if catalog.stat_shown(&"enforce", state):
		force_line.append("%s %d" % [StatCell.stat_name(&"enforce"), state.attributes.force_factor])
		force_hints.append(StatCell.stat_hint(&"enforce"))
	force_text.show_stat(" · ".join(force_line), "\n".join(force_hints))
	var calm_line := PackedStringArray()
	var calm_hints := PackedStringArray()
	if catalog.stat_shown(&"bellicosity", state):
		calm_line.append("%s %d" % [StatCell.stat_name(&"bellicosity"), state.attributes.bellicosity])
		calm_hints.append(StatCell.stat_hint(&"bellicosity"))
	calm_line.append("%s %d" % [StatCell.stat_name(&"composure"), state.attributes.composure])
	calm_hints.append(StatCell.stat_hint(&"composure"))
	bellicosity_text.show_stat(" · ".join(calm_line), "\n".join(calm_hints))
	# TRANSLATORS: score.c: mana (法力) and its maximum, what meditate (冥思) builds.
	mana_text.show_stat(tr("法力 {mana} / {max_mana}").format({"mana": state.recovery.mana.current, "max_mana": state.recovery.mana.maximum}), StatCell.stat_hint(&"mana"))
	# TRANSLATORS: score.c: atman (灵力) and its maximum, what respirate (修行) builds.
	atman_text.show_stat(tr("灵力 {atman} / {max_atman}").format({"atman": state.recovery.atman.current, "max_atman": state.recovery.atman.maximum}), StatCell.stat_hint(&"atman"))
	var mana_shown: bool = catalog.stat_shown(&"mana", state)
	for row: Control in meditate_rows:
		row.visible = mana_shown
	var atman_shown: bool = catalog.stat_shown(&"atman", state)
	for row: Control in respirate_rows:
		row.visible = atman_shown


## skills.c: every skill, its rank and level / learning progress; □ marks an enabled one.
func _skills_list(state: CharacterState, catalog: ContentCatalog) -> String:
	var mapped: Array[StringName] = []
	for use_id: StringName in state.skills.enabled_use_ids():
		mapped.append(state.skills.mapped_skill(use_id))
	var lines: PackedStringArray = []
	for skill_id: StringName in state.skills.raw_skill_ids():
		var skill: SkillDefinition = catalog.skill(skill_id)
		var level: int = state.skills.raw_level(skill_id)
		var ranks: Array[String] = KNOWLEDGE_RANKS if skill != null and skill.skill_type == SkillDefinition.Type.KNOWLEDGE else SKILL_RANKS
		@warning_ignore("integer_division")
		var rank: String = ranks[clampi(level / 10, 0, ranks.size() - 1)]
		# TRANSLATORS: skills.c: {mark} is □ for an enabled skill, {rank} its rank, {level}/{progress} level and learning progress.
		lines.append(tr("{mark}{skill} - {rank} {level}/{progress}").format({
			"mark": MAPPED_MARK if mapped.has(skill_id) else UNMAPPED_MARK,
			"skill": tr(skill.display_name) if skill != null else String(skill_id),
			"rank": tr(rank), "level": level, "progress": state.skills.learned_progress(skill_id),
		}))
	if lines.is_empty():
		return tr("你目前并没有学会任何技能。")
	return "\n".join(lines)


## enable.c's uses: one row per use with an effective level or a special skill the
## player knows for it; {use, text, actions}.
func _use_rows(arts: PlayerMartialArts, state: CharacterState, catalog: ContentCatalog) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for use_id: StringName in SkillUseIds.KINDS:
		var basic: SkillDefinition = catalog.skill(use_id)
		if basic == null:
			continue # a use the game does not model as a skill yet (move)
		var candidates: Array[StringName] = []
		for skill_id: StringName in state.skills.raw_skill_ids():
			var skill: SkillDefinition = catalog.skill(skill_id)
			if skill != null and skill.kind == SkillDefinition.Kind.SPECIALIZED and skill.can_enable_for(use_id) and state.skills.raw_level(skill_id) > 0:
				candidates.append(skill_id)
		var effective: int = arts.effective_level(use_id)
		if effective == 0 and candidates.is_empty():
			continue
		var mapped: StringName = state.skills.mapped_skill(use_id)
		var actions: PackedStringArray = []
		for skill_id: StringName in candidates:
			if skill_id != mapped:
				actions.append("enable:%s:%s" % [use_id, skill_id])
		if not mapped.is_empty():
			actions.append("practice:%s" % use_id)
			actions.append("practice_run:%s" % use_id)
			actions.append("disable:%s" % use_id)
		var modifier: int = arts.apply_modifier(use_id)
		var level: String = str(effective)
		if modifier != 0:
			# enable.c colours an effective level that apply/* changes: HIC up, HIR down.
			var color: Color = SharedGameplayUI.ES2_COLORS[ColoredLine.HIC if modifier > 0 else ColoredLine.HIR]
			level = "[color=#%s]%d[/color]" % [color.to_html(false), effective]
		var mapped_skill: SkillDefinition = catalog.skill(mapped)
		# TRANSLATORS: enable.c: a use (拳脚, 剑法 …), the skill enabled for it (or 无) and the effective level.
		var text: String = tr("{use}：{skill} · 有效等级 {level}").format({
			"use": tr(SkillUseIds.KINDS[use_id]),
			"skill": tr(mapped_skill.display_name) if mapped_skill != null else tr("无"),
			"level": level,
		})
		var practice: String = _practice_line(state, basic, mapped_skill)
		if not practice.is_empty():
			text += "\n" + practice
		rows.append({"use": use_id, "text": text, "actions": actions})
	return rows


## How far 练习 takes the skill enabled for `basic`'s use (practice.c: no level once
## the basic skill is not above it, feature/skill.c: progress past (level + 1)^2 is lost);
## "" for a skill practice refuses whatever (a force style).
func _practice_line(state: CharacterState, basic: SkillDefinition, special: SkillDefinition) -> String:
	if special == null or special.practice_policy() == null or special.practice_policy() is UnpracticeablePracticePolicy:
		return ""
	var basic_level: int = state.skills.raw_level(basic.skill_id)
	var special_level: int = state.skills.raw_level(special.skill_id)
	if basic_level < 1 or special_level < 1:
		return "" # practice.c refuses (一窍不通): nothing to reach.
	var values: Dictionary = {"basic": tr(basic.display_name), "level": basic_level if basic_level > special_level else special_level + 1}
	if basic_level > special_level:
		return tr(PRACTICE_UP_TO).format(values)
	if PracticeService.weak_progress_full(state, basic.skill_id):
		return tr(PRACTICE_FULL).format(values)
	return tr(PRACTICE_BANKING).format(values)


## How far the maximum `kind` builds can grow (`cap`, the bottleneck) and what moves it.
func _cap_line(kind: TrainingRun.Kind, maximum: int, cap: int, basic: SkillDefinition) -> String:
	var values: Dictionary = {
		"resource": tr(TrainingLines.RUN_RESOURCES[kind]), "cap": cap, "basic": tr(basic.display_name) if basic != null else "",
	}
	return tr(CAP_UP_TO if maximum < cap else CAP_REACHED).format(values)


# TRANSLATORS: the 武学 page under 打坐 / 冥思 / 修行: the maximum {resource} (内力 …) can grow to {cap} (the bottleneck).
const CAP_UP_TO: String = "最大{resource}可练到 {cap}"
# TRANSLATORS: the same at the bottleneck {cap}: {basic} (基本内功 …) must grow first.
const CAP_REACHED: String = "最大{resource}已到瓶颈（{cap}），先提高{basic}"
# TRANSLATORS: the 武学 page under an enabled skill: 练习 raises it to {level}, the level of {basic} (practice.c).
const PRACTICE_UP_TO: String = "练习可练到 {level} 级（{basic}的等级）"
# TRANSLATORS: the same once it is not below {basic}: practice only adds progress, the level comes when {basic} reaches {level}.
const PRACTICE_BANKING: String = "练习只攒进度，{basic}到 {level} 级才会升级"
# TRANSLATORS: the same with this level's progress full: {basic} must reach {level} first.
const PRACTICE_FULL: String = "这一级的进度已攒满，先把{basic}提高到 {level} 级"


func _rebuild(rows: Array[Dictionary], functions: Array[StringName], conjures: Array[StringName], spells: Array[StringName], learnable: Array[StringName], books: Array[PlayerInventoryRowProjection]) -> void:
	buttons.clear()
	_use_texts.clear()
	for container: Node in [uses_box, exert_row, conjure_row, spell_row, self_learn_row, study_row]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for row: Dictionary in rows:
		var use_id: StringName = row.use
		var text := RichTextLabel.new()
		text.name = "Use_" + String(use_id)
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		uses_box.add_child(text)
		_use_texts[use_id] = text
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		uses_box.add_child(flow)
		for action: String in row.actions:
			buttons[action] = _button(flow, action.replace(":", "_"), "")
			buttons[action].pressed.connect(_act.bind(action))
	for function_id: StringName in functions:
		var action: String = "exert:%s" % function_id
		buttons[action] = _button(exert_row, action.replace(":", "_"), "")
		buttons[action].pressed.connect(_act.bind(action))
	exert_title.visible = not functions.is_empty()
	exert_row.visible = not functions.is_empty()
	for function_id: StringName in conjures:
		var action: String = "conjure:%s" % function_id
		buttons[action] = _button(conjure_row, action.replace(":", "_"), "")
		buttons[action].pressed.connect(_act.bind(action))
	conjure_title.visible = not conjures.is_empty()
	conjure_row.visible = not conjures.is_empty()
	for function_id: StringName in spells:
		var action: String = "cast:%s" % function_id
		buttons[action] = _button(spell_row, action.replace(":", "_"), "")
		buttons[action].pressed.connect(_act.bind(action))
	spell_title.visible = not spells.is_empty()
	spell_row.visible = not spells.is_empty()
	for skill_id: StringName in learnable:
		var action: String = "self_learn:%s" % skill_id
		buttons[action] = _button(self_learn_row, action.replace(":", "_"), "")
		buttons[action].pressed.connect(_act.bind(action))
	for book: PlayerInventoryRowProjection in books:
		var action: String = "study:%s" % book.item_instance_id
		buttons[action] = _button(study_row, action.replace(":", "_"), "")
		buttons[action].pressed.connect(_act.bind(action))
	self_learn_title.visible = not learnable.is_empty()
	self_learn_row.visible = not learnable.is_empty()
	study_title.visible = not books.is_empty()
	study_row.visible = not books.is_empty()
	# New buttons get the frame's touch-sized targets too.
	if _session != null and _session.shared_ui() != null and is_visible_in_tree():
		_session.shared_ui().refresh_panel_rows()


func _label_buttons(rows: Array[Dictionary], learnable: Array[StringName], books: Array[PlayerInventoryRowProjection], catalog: ContentCatalog) -> void:
	for row: Dictionary in rows:
		for action: String in row.actions:
			var parts: PackedStringArray = action.split(":")
			match parts[0]:
				"enable":
					buttons[action].text = tr("激发%s") % tr(catalog.skill(StringName(parts[2])).display_name)
				"practice":
					buttons[action].text = tr("练习")
				"practice_run":
					# TRANSLATORS: the 武学 page's button that practises again and again until something stops it (DECISIONS「连续修炼」).
					buttons[action].text = tr("连续练习")
				"disable":
					buttons[action].text = tr("停用")
	for key: String in buttons:
		if key.begins_with("exert:"):
			buttons[key].text = tr(ExertFunctions.LABELS[StringName(key.get_slice(":", 1))])
		elif key.begins_with("conjure:"):
			var conjure: ConjureFunction = SpecialFunctions.conjure(StringName(key.get_slice(":", 1)))
			buttons[key].text = tr(conjure.label)
			buttons[key].tooltip_text = tr(CONJURE_HINTS.get(conjure.id, ""))
		elif key.begins_with("cast:"):
			var spell: CastFunction = SpecialFunctions.cast(StringName(key.get_slice(":", 1)))
			buttons[key].text = tr(spell.self_label)
			buttons[key].tooltip_text = tr(SPELL_HINTS.get(spell.id, ""))
	for skill_id: StringName in learnable:
		buttons["self_learn:%s" % skill_id].text = tr("自学%s") % tr(catalog.skill(skill_id).display_name)
	for book: PlayerInventoryRowProjection in books:
		buttons["study:%s" % book.item_instance_id].text = tr("研读%s") % tr(book.display_name)


func _act(action: String) -> void:
	if _session == null:
		return
	var arts: PlayerMartialArts = _session.martial_arts()
	var kind: String = action.get_slice(":", 0)
	# What follows the kind; an item instance ID may itself contain colons.
	var subject: String = action.substr(kind.length() + 1)
	_last_lines = null
	match kind:
		"enable":
			arts.enable(StringName(subject.get_slice(":", 0)), StringName(subject.get_slice(":", 1)))
		"disable":
			arts.disable(StringName(subject))
		"practice":
			arts.practice(StringName(subject))
		"practice_run":
			var special: SkillDefinition = GameContent.catalog().skill(_session.player_runtime().state.skills.mapped_skill(StringName(subject)))
			# TRANSLATORS: a continuous 练习 under way: %s the skill practised.
			_start_run(PlayerTrainingRun.practice(_session, StringName(subject)), tr("连续练习%s") % (tr(special.display_name) if special != null else ""), buttons[action], uses_box)
			return
		"exert":
			arts.exert(StringName(subject))
		"conjure":
			_conjure(StringName(subject))
			return
		"cast":
			_session.shared_ui().cast_self(StringName(subject))
		"self_learn":
			arts.self_learn(StringName(subject))
		"study":
			arts.study(StringName(subject))
	refresh()
	_refocus(action)


## After a rebuild the pressed button may be gone (激发 becomes 停用): focus the same
## action, else the use's other buttons, else 打坐.
func _refocus(action: String) -> void:
	var use: String = action.get_slice(":", 1)
	var wanted: Array[String] = [action, "disable:" + use, "practice:" + use]
	for key: String in buttons:
		if key.begins_with("enable:%s:" % use):
			wanted.append(key)
	for key: String in wanted:
		if buttons.has(key) and buttons[key].is_visible_in_tree():
			buttons[key].grab_focus()
			return
	if exercise_button.is_visible_in_tree():
		exercise_button.grab_focus()


## 空识 asks first when it would knock the player out; 游识 asks whom to go to. Both
## run through the HUD (its questions); the page shows their lines while it stays open.
func _conjure(function_id: StringName) -> void:
	var magic: PlayerEssenceMagic = _session.essence_magic()
	magic.last_lines = []
	match function_id:
		PlayerEssenceMagic.VOID_SENSE:
			_session.shared_ui().conjure_void_sense()
		PlayerEssenceMagic.DRIFT_SENSE:
			_session.shared_ui().open_drift_sense()
	_last_lines = magic.last_lines
	if is_visible_in_tree():
		refresh()
		_refocus("conjure:%s" % function_id)


## 连续打坐 / 冥思 / 修行 with the amount in its box.
func _cultivate(kind: TrainingRun.Kind) -> void:
	if _session == null:
		return
	var rows: Dictionary[TrainingRun.Kind, Array] = {
		# TRANSLATORS: a continuous 打坐 / 冥思 / 修行 under way.
		TrainingRun.Kind.EXERCISE: [exercise_amount, exercise_run_button, "连续打坐"],
		TrainingRun.Kind.MEDITATE: [meditate_amount, meditate_run_button, "连续冥思"],
		TrainingRun.Kind.RESPIRATE: [respirate_amount, respirate_run_button, "连续修行"],
	}
	var row: Array = rows[kind]
	var amount: SpinBox = row[0]
	var run: PlayerTrainingRun = PlayerTrainingRun.cultivate(_session, kind, int(amount.value))
	if kind == TrainingRun.Kind.EXERCISE:
		run.training.target_maximum = exercise_target.get_selected_id()
	_start_run(run, tr(row[2]), row[1], amount.get_parent() as Control)


func _start_run(run: PlayerTrainingRun, what: String, button: Button, after: Control) -> void:
	if progress.running():
		return
	_last_lines = null
	_run_button = button
	progress.start(run, what, after)
	if is_visible_in_tree():
		refresh()


func _run_finished(_lines: Array[ColoredLine]) -> void:
	_last_lines = null
	if not is_visible_in_tree():
		return
	refresh()
	if is_instance_valid(_run_button) and _run_button.is_visible_in_tree():
		_run_button.grab_focus()


func _exercise() -> void:
	_last_lines = null
	if _session != null:
		_session.martial_arts().exercise(int(exercise_amount.value))
		refresh()


func _enforce() -> void:
	_last_lines = null
	if _session != null:
		_session.martial_arts().enforce(int(enforce_amount.value))
		refresh()


func _meditate() -> void:
	_last_lines = null
	if _session != null:
		_session.martial_arts().meditate(int(meditate_amount.value))
		refresh()


func _respirate() -> void:
	_last_lines = null
	if _session != null:
		_session.martial_arts().respirate(int(respirate_amount.value))
		refresh()


## A row with the amount meditate.c and respirate.c spend: at least 10, 30 as their help gives.
func _cost_box(node_name: String) -> SpinBox:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var amount := SpinBox.new()
	amount.name = node_name + "Amount"
	amount.min_value = 10
	amount.max_value = 100000
	amount.step = 1
	amount.value = 30
	row.add_child(amount)
	return amount


func _title(text: String) -> Label:
	var label := _label("")
	label.text = text
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	return label


func _stat_line(node_name: String) -> StatCell:
	var cell := StatCell.new(node_name)
	cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(cell)
	return cell


func _label(node_name: String) -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _flow(node_name: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.name = node_name
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	add_child(flow)
	return flow


func _button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(80, 40)
	parent.add_child(button)
	return button
