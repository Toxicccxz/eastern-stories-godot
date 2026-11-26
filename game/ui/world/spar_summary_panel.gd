class_name SparSummaryPanel
extends CanvasLayer
## The card after a 切磋 (native, owner 2026-11-22「切磋结束后给一个总结界面，显示输赢等等」): the
## outcome as a title (胜 / 负 / 平手), the opponent and the rounds, who landed the blow, and what
## the player gained in it (实战经验, 潜能, the skills that rose or moved on; CombatSparSummary).
## World time stands still under it (like the game's cards) until 继续, A / Enter / E, or B / Esc.
## It changes nothing: the fight's rules have already decided.

## Over the life overlay's cards (20), under the menu (60) and the growth moments (63).
const LAYER: int = 22
const HOLD: StringName = &"spar_summary"
const WIDTH: float = 420.0
const SCREEN_MARGIN: float = 24.0

## The suites turn it off (run_suite.gd): a spar in a suite goes on without the card; its own
## suite turns it on.
static var shown_in_play: bool = true

var title: Label
var opponent_line: Label
var blow_line: Label
var gains: VBoxContainer
var continue_button: Button
var _dim: ColorRect
var _panel: PanelContainer
var _session: WorldSessionController
var _summary: CombatSparSummary


func configure(session: WorldSessionController) -> void:
	_session = session


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = UiPalette.SCRIM_LIGHT
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.theme = GameTheme.shared()
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.theme_type_variation = &"MenuWindow"
	center.add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	_panel.add_child(rows)
	title = Label.new()
	title.name = "Title"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rows.add_child(title)
	opponent_line = _line(rows, &"MutedLabel")
	opponent_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blow_line = _line(rows, &"")
	blow_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var well := PanelContainer.new()
	well.theme_type_variation = &"WellPanel"
	rows.add_child(well)
	gains = VBoxContainer.new()
	gains.name = "Gains"
	gains.add_theme_constant_override("separation", 4)
	well.add_child(gains)
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = "继续"
	continue_button.theme_type_variation = &"PrimaryButton"
	continue_button.custom_minimum_size = Vector2(160, 44)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(close)
	InputGlyphs.decorate(continue_button, &"ui_accept")
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		continue_button.set_focus_neighbor(side, NodePath("."))
	rows.add_child(continue_button)
	visible = false


func _line(parent: Node, variation: StringName) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not variation.is_empty():
		label.theme_type_variation = variation
	parent.add_child(label)
	return label


## Puts `summary` up (the last spar's: one that comes while another shows takes its place).
func present(summary: CombatSparSummary) -> void:
	# A fight that began meanwhile has the screen: its card would sit over that fight's.
	var coordinator: CombatEncounterCoordinator = null if _session == null else _session.combat_encounter_coordinator()
	if summary == null or not shown_in_play or _session == null or (coordinator != null and coordinator.has_active_encounter()):
		return
	_summary = summary
	title.text = title_text(summary.outcome)
	title.add_theme_color_override("font_color", _title_colour(summary.outcome))
	opponent_line.text = ShownText.of(_opponent_text(summary))
	blow_line.text = _blow_text(summary.outcome)
	for child: Node in gains.get_children():
		gains.remove_child(child)
		child.queue_free()
	for line: String in gain_lines(summary):
		var label := _line(gains, &"")
		label.text = ShownText.of(line)
	var screen: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var width: float = minf(WIDTH, screen.x - SCREEN_MARGIN * 2.0 - 40.0)
	for label: Label in [opponent_line, blow_line]:
		label.custom_minimum_size.x = width
	visible = true
	_session.hold_world_time(HOLD)
	continue_button.grab_focus.call_deferred()


func shown() -> bool:
	return visible


func summary() -> CombatSparSummary:
	return _summary if visible else null


func close() -> void:
	if not visible:
		return
	visible = false
	_summary = null
	if continue_button.has_focus():
		continue_button.release_focus()
	if _session != null:
		_session.release_world_time(HOLD)


func _exit_tree() -> void:
	if visible and _session != null:
		_session.release_world_time(HOLD)


## E (the interact key) and B / Esc close it too; Enter / Space / A press 继续. Not while the
## menu or the shell (系统, a question) is over it: those keys are theirs.
func _input(event: InputEvent) -> void:
	if not visible or event.is_echo() or not event.is_pressed() or _covered():
		return
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.is_action_pressed(&"interact") and not event.is_action_pressed(&"ui_accept")):
		get_viewport().set_input_as_handled()
		close()


func _covered() -> bool:
	var ui: SharedGameplayUI = null if _session == null else _session.shared_ui()
	if ui != null and ui.menu != null and ui.menu.is_presented():
		return true
	var shell: Node = get_tree().get_first_node_in_group(GameMenu.HOST_GROUP) if is_inside_tree() else null
	return shell != null and shell.has_method(&"world_has_focus") and not shell.world_has_focus()


# TRANSLATORS: the card after a 切磋: its title when the player won / lost / nobody landed the blow.
static func title_text(outcome: int) -> String:
	match outcome:
		CombatSparSummary.Outcome.WON:
			return TranslationServer.translate("切磋 · 胜")
		CombatSparSummary.Outcome.LOST:
			return TranslationServer.translate("切磋 · 负")
	return TranslationServer.translate("切磋 · 平手")


static func _title_colour(outcome: int) -> Color:
	match outcome:
		CombatSparSummary.Outcome.WON:
			return UiPalette.GOLD
		CombatSparSummary.Outcome.LOST:
			return UiPalette.WARNING
	return UiPalette.BONE


func _opponent_text(summary: CombatSparSummary) -> String:
	var names: PackedStringArray = []
	var map := _session.active_map() as WorldMapController if _session != null else null
	for id: StringName in summary.opponent_ids:
		var npc: NpcRuntimeState = null if map == null else map.find_resident_npc(id)
		if npc != null:
			names.append(TranslationServer.translate(npc.definition().display_name))
	# TRANSLATORS: the card after a 切磋: {who} the opponent(s), joined by 、; {rounds} how many rounds it ran.
	var line: String = TranslationServer.translate("对手：{who}　共 {rounds} 回合") if not names.is_empty() else TranslationServer.translate("共 {rounds} 回合")
	return line.format({"who": TranslationServer.translate("、").join(names), "rounds": maxi(summary.rounds, 1)})


static func _blow_text(outcome: int) -> String:
	match outcome:
		CombatSparSummary.Outcome.WON:
			# TRANSLATORS: the card after a 切磋 the player won (it ends on the first blow that lands).
			return TranslationServer.translate("你先打中了对方，这一场是你赢了。")
		CombatSparSummary.Outcome.LOST:
			# TRANSLATORS: the card after a 切磋 the player lost: a spar costs nothing but the bout; it can be tried again.
			return TranslationServer.translate("对方先打中了你。切磋点到为止，随时可以再来。")
	# TRANSLATORS: the card after a 切磋 that ended before either landed a blow.
	return TranslationServer.translate("谁也没打中谁，双方停了手。")


## The gains, one line each ("这一场没有长进。" when none).
static func gain_lines(summary: CombatSparSummary) -> Array[String]:
	var lines: Array[String] = []
	# TRANSLATORS: the card after a 切磋, its gains: {n} how much.
	if summary.combat_experience_gained > 0:
		lines.append(TranslationServer.translate("实战经验 +{n}").format({"n": summary.combat_experience_gained}))
	if summary.potential_gained > 0:
		lines.append(TranslationServer.translate("潜能 +{n}").format({"n": summary.potential_gained}))
	for gain: CombatSparSummary.SkillGain in summary.skills:
		var skill: SkillDefinition = GameContent.catalog().skill(gain.skill_id)
		var name: String = TranslationServer.translate(skill.display_name) if skill != null else String(gain.skill_id)
		if gain.levelled():
			# TRANSLATORS: the card after a 切磋: a skill rose {before} → {after} levels.
			lines.append(TranslationServer.translate("{skill} {before} → {after} 级").format({"skill": name, "before": gain.level_before, "after": gain.level_after}))
		else:
			# TRANSLATORS: the card after a 切磋: a skill moved on without a level.
			lines.append(TranslationServer.translate("{skill} 有所长进").format({"skill": name}))
	if lines.is_empty():
		# TRANSLATORS: the card after a 切磋 that gave nothing.
		lines.append(TranslationServer.translate("这一场没有长进。"))
	return lines
