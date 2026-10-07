class_name MartialArtsPage
extends VBoxContainer

## The character panel's 武学 page: cmds/usr/skills.c's list, enable.c's uses with
## their enable, disable and practice buttons, exercise, enforce, meditate, respirate,
## exert, self-learning and study.
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
var force_text: Label
var bellicosity_text: Label
var no_uses: Label
var uses_box: VBoxContainer
var exercise_amount: SpinBox
var exercise_button: Button
var enforce_amount: SpinBox
var enforce_button: Button
var mana_text: Label
var meditate_amount: SpinBox
var meditate_button: Button
var atman_text: Label
var respirate_amount: SpinBox
var respirate_button: Button
var exert_title: Label
var exert_row: HFlowContainer
var self_learn_title: Label
var self_learn_row: HFlowContainer
var study_title: Label
var study_row: HFlowContainer
var feedback: Label
## Action -> its button: enable:<use>:<skill>, disable:<use>, practice:<use>,
## exert:<function>, self_learn:<skill>, study:<item instance>.
var buttons: Dictionary[String, Button] = {}
var _session: OldPineWorldSessionController
var _layout_key: String = "-"
var _use_texts: Dictionary[StringName, RichTextLabel] = {}
var _shown_factor: int = -1


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
	force_text = _label("Force")
	bellicosity_text = _label("Bellicosity")
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
	_title("冥思")
	mana_text = _label("Mana")
	_label("MeditateCost").text = "每次花费的神"
	meditate_amount = _cost_box("Meditate")
	meditate_button = _button(meditate_amount.get_parent(), "MeditateButton", "冥思")
	meditate_button.pressed.connect(_meditate)
	_title("修行")
	atman_text = _label("Atman")
	_label("RespirateCost").text = "每次花费的精"
	respirate_amount = _cost_box("Respirate")
	respirate_button = _button(respirate_amount.get_parent(), "RespirateButton", "修行")
	respirate_button.pressed.connect(_respirate)
	exert_title = _title("运功")
	exert_row = _flow("Exert")
	self_learn_title = _title("自学")
	self_learn_row = _flow("SelfLearn")
	study_title = _title("研读")
	study_row = _flow("Study")
	# Not "Feedback": SharedGameplayUI copies a panel's Feedback label into the log,
	# and these lines are there already.
	feedback = _label("LastLines")


func configure(session: OldPineWorldSessionController) -> void:
	_session = session


## Fills the page from the current state, in the shown language.
func refresh() -> void:
	if _session == null or not _session.is_initialized() or _session.player_runtime() == null:
		return
	var arts: PlayerMartialArts = _session.martial_arts()
	var state: CharacterState = _session.player_runtime().state
	var catalog: ContentCatalog = GameContent.catalog()
	skills_text.text = _skills_list(state, catalog)
	# TRANSLATORS: hp.c: internal power, its maximum and enforce.c's force_factor.
	force_text.text = tr("内力 {force} / {max_force} (+{factor})").format({
		"force": state.recovery.inner_force.current, "max_force": state.recovery.inner_force.maximum,
		"factor": state.attributes.force_factor,
	})
	# TRANSLATORS: score.c: mana (法力) and its maximum, what meditate (冥思) builds.
	mana_text.text = tr("法力 {mana} / {max_mana}").format({
		"mana": state.recovery.mana.current, "max_mana": state.recovery.mana.maximum,
	})
	# TRANSLATORS: score.c: atman (灵力) and its maximum, what respirate (修行) builds.
	atman_text.text = tr("灵力 {atman} / {max_atman}").format({
		"atman": state.recovery.atman.current, "max_atman": state.recovery.atman.maximum,
	})
	# TRANSLATORS: the 武学 page: score.c's 杀气 (bellicosity) and 定力 (cps), which decide whether the player can lose control.
	bellicosity_text.text = tr("杀气 {bellicosity} · 定力 {cps}").format({
		"bellicosity": state.attributes.bellicosity, "cps": state.attributes.composure,
	})
	enforce_amount.max_value = arts.enforce_limit()
	# The amount follows the factor whenever the factor changes.
	if state.attributes.force_factor != _shown_factor:
		_shown_factor = state.attributes.force_factor
		enforce_amount.set_value_no_signal(mini(_shown_factor, arts.enforce_limit()))
	var functions: Array[StringName] = arts.exert_functions()
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
	for skill_id: StringName in learnable:
		keys.append("self_learn:%s" % skill_id)
	for book: PlayerInventoryRowProjection in books:
		keys.append("study:%s" % book.item_instance_id)
	var key: String = "|".join(keys)
	if key != _layout_key:
		_layout_key = key
		_rebuild(rows, functions, learnable, books)
	for row: Dictionary in rows:
		_use_texts[row.use].text = row.text
	# enable.c with nothing enabled.
	no_uses.visible = state.skills.enabled_use_ids().is_empty()
	_label_buttons(rows, learnable, books, catalog)
	feedback.text = "\n".join(ColoredLine.texts(arts.last_lines))


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
		rows.append({"use": use_id, "text": text, "actions": actions})
	return rows


func _rebuild(rows: Array[Dictionary], functions: Array[StringName], learnable: Array[StringName], books: Array[PlayerInventoryRowProjection]) -> void:
	buttons.clear()
	_use_texts.clear()
	for container: Node in [uses_box, exert_row, self_learn_row, study_row]:
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
				"disable":
					buttons[action].text = tr("停用")
	for key: String in buttons:
		if key.begins_with("exert:"):
			buttons[key].text = tr(ExertFunctions.LABELS[StringName(key.get_slice(":", 1))])
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
	match kind:
		"enable":
			arts.enable(StringName(subject.get_slice(":", 0)), StringName(subject.get_slice(":", 1)))
		"disable":
			arts.disable(StringName(subject))
		"practice":
			arts.practice(StringName(subject))
		"exert":
			arts.exert(StringName(subject))
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


func _exercise() -> void:
	if _session != null:
		_session.martial_arts().exercise(int(exercise_amount.value))
		refresh()


func _enforce() -> void:
	if _session != null:
		_session.martial_arts().enforce(int(enforce_amount.value))
		refresh()


func _meditate() -> void:
	if _session != null:
		_session.martial_arts().meditate(int(meditate_amount.value))
		refresh()


func _respirate() -> void:
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
