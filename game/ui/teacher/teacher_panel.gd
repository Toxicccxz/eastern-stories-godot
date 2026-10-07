class_name TeacherPanel
extends CanvasLayer

## A teacher's panel: apprenticeship when the NPC takes apprentices, one learn
## button per skill it teaches. The TeacherService owns the rules; this only
## presents them and repeats the last lines the log received. Enabling a skill is
## on the character panel's 武学 page.
var _contact: TeacherService
var _rows: VBoxContainer
var _title: Label
var panel: PanelContainer
var status: Label
var feedback: Label
## The last 拜师, oath or test's lines, right above their buttons (the test's blows read at once).
var apprentice_feedback: Label
var apprentice_button: Button
var cancel_button: Button
## 萧辟尘's oath (owner: a fixed button, no typing) while he waits for it.
var oath_button: Button
## 於兰天武's accept test, asked first (owner).
var trial_button: Button
## Asked before 拜师 makes the player betray their family (owner, DECISIONS 3B) or
## takes their first master (owner, 2026-10-06): the shared ConfirmPrompt.
var confirm_box: ConfirmPrompt
var confirm_text: Label
var confirm_button: Button
var keep_button: Button
## Skill ID -> its learn button.
var learn_buttons: Dictionary[StringName, Button] = {}
## What 确定 does for the question showing.
var _on_confirm: Callable = Callable()

# TRANSLATORS: asked before 拜师 makes the player leave their family (recruit.c's betrayal): {title} is the player's title now (封山剑派第十四代弟子), {master} the new master, {family} the new family, {score} the player's 综合评价 now, {next} how many times they will have betrayed a family.
const BETRAYAL_WARNING: String = "你现在是{title}。改投{master}门下，就是背叛师门：\n· 综合评价清零（现在是 {score}）。\n· 背叛师门的次数变成 {next} 次。以后能收徒的师父教你武功，只教到他自己的等级减去 20 × 背叛次数为止。\n· 门派、师父和称号都换成{family}的；已经学会的武功保留。\n· 日后再改投别派，又算一次背叛。\n确定要改投吗？"
# TRANSLATORS: asked before the player, who has no family yet, takes their first master: changing family later is a betrayal (recruit.c, master.c). {master} the new master, {family} the new family.
const FIRST_MASTER_WARNING: String = "拜{master}为师，便成为{family}的弟子。日后若再改投别派，就是背叛师门：\n· 综合评价清零。\n· 背叛师门的次数加一。以后能收徒的师父教你武功，只教到他自己的等级减去 20 × 背叛次数为止。\n确定要拜师吗？"
# TRANSLATORS: asked before 拜师 or an oath that makes the player change master inside their family: {current} the master now, {master} the new one, {teach} what {current} teaches them after (one of the CHANGE_TEACHES_* lines, or nothing).
const CHANGE_MASTER_WARNING: String = "你现在是{current}的嫡传弟子。改拜{master}为师，{current}就不再是你的师父：\n· 门派不变，辈分随{master}。\n{teach}确定要改拜{master}为师吗？"
# TRANSLATORS: what the old master teaches a member of the family who is not their apprentice (master.c prevent_learn()): {current}.
const CHANGE_TEACHES_LESS: String = "· 以后{current}只教你他的等级超过你三倍的武功。\n"
# TRANSLATORS: the old master teaches only his own apprentices (privs 0, learn.c): {current}.
const CHANGE_TEACHES_NONE: String = "· {current}只教嫡传弟子，以后不再教你。\n"
# TRANSLATORS: the accept test's last point when passing it makes the player change master inside their family: {current} the master now, {master} the new one, {teach} as above.
const TRIAL_CHANGES_MASTER: String = "· 你现在是{current}的嫡传弟子；三招都接住，便改拜{master}为师，{current}就不再是你的师父。\n{teach}"
# TRANSLATORS: asked before 於兰天武's accept test (champion.c: three real blows; owner: asked first). {master} the master, {after} what passing it does (one of the TRIAL_* lines).
const TRIAL_WARNING: String = "{master}的三招是真打：\n· 每一招都实打实地落在你身上，挨中了会受伤。\n· 哪一招接不住，测试就算失败，你随后会昏倒。\n· 伤得太重会死。\n{after}\n确定接受测试吗？"
# TRANSLATORS: the accept test's last point when passing it makes the player the master's apprentice at once: {master}, {family}.
const TRIAL_RECRUITS: String = "· 三招都接住，便拜入{master}门下，成为{family}的弟子。"
# TRANSLATORS: added when that would be the player's first master: changing family later is a betrayal.
const TRIAL_FIRST_MASTER: String = "· 这是你第一次拜师；日后再改投别派，就是背叛师门。"
# TRANSLATORS: the accept test's last point when passing it makes a member of another family betray it (recruit.c): {title} the player's title now, {master}, {family} the new family, {score} the player's 综合评价 now, {next} the betrayals counted after it.
const TRIAL_BETRAYS: String = "· 你现在是{title}；三招都接住，就改投{master}门下，等于背叛师门：综合评价清零（现在是 {score}），背叛师门的次数变成 {next} 次；门派、师父和称号都换成{family}的，已经学会的武功保留。"
# TRANSLATORS: the accept test's last point when the player has not asked the master to take them (recruit.c then only offers): {master}.
const TRIAL_OFFERS: String = "· 三招都接住，{master}便愿意收你为徒，再向他拜师即可。"
# TRANSLATORS: asked before 拜师 with 绝尘子, who takes only commoners (juechen/master.c): one with a family's title is taken for a traitor and killed. {master} the master, {title} the player's title now.
const TRAITOR_WARNING: String = "{master}只收没有门派的普通百姓为徒。你现在是{title}，向他拜师：\n· 他会当你要背叛师门，在闲聊频道上喊出来。\n· 然后当场出手要杀你，这是一场生死之战。\n确定要向他拜师吗？"


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
	_title = _label("", "Title")
	status = _label("", "Status")
	if _contact.takes_apprentices():
		# Above their buttons: the focus stays on the button, so the lines just above show.
		# Not "Feedback" either (see below).
		apprentice_feedback = _label("", "ApprenticeLines")
		apprentice_button = _button("Apprentice", "拜师 / 向师父请安", request_apprentice)
		if _contact.teaching().apprentice.kind == NpcTeaching.Kind.OATH:
			oath_button = _button("Swear", "发誓恪守门规", swear_oath)
		if _contact.teaching().apprentice.kind == NpcTeaching.Kind.TRIAL:
			trial_button = _button("AcceptTest", "接受测试", take_trial)
		cancel_button = _button("CancelApprentice", "取消拜师请求", cancel_apprentice)
		confirm_box = ConfirmPrompt.new()
		confirm_box.name = "ApprenticeConfirm"
		confirm_box.hide()
		_rows.add_child(confirm_box)
		confirm_text = confirm_box.message
		confirm_button = confirm_box.confirm_button
		keep_button = confirm_box.cancel_button
		confirm_box.confirmed.connect(_confirmed)
		confirm_box.cancelled.connect(_keep_family)
	for skill_id: StringName in _contact.teachable_skills():
		learn_buttons[skill_id] = _button("Learn_" + String(skill_id), "", _learn.bind(skill_id))
	# Not "Feedback": SharedGameplayUI copies a panel's Feedback label into the log, and
	# TeacherService has logged these lines already.
	feedback = _label("", "LastLines")
	_button("Close", "离开", close_panel)
	_present()


## The title and the skill buttons in the shown language, put together again on each opening.
func _present() -> void:
	_title.text = _contact.npc.definition().short_name()
	var catalog: ContentCatalog = GameContent.catalog()
	for skill_id: StringName in learn_buttons:
		var skill: String = tr(catalog.skill(skill_id).display_name)
		learn_buttons[skill_id].text = tr("请教%s（一次）") % skill


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
	_set_confirming(false)
	feedback.text = ""
	if apprentice_feedback != null:
		apprentice_feedback.text = ""
	_present()
	_contact.open_panel(_contact.context_title(), panel)
	refresh()
	var first: Button = apprentice_button if apprentice_button != null else (learn_buttons.values()[0] if not learn_buttons.is_empty() else null)
	if first != null:
		first.grab_focus()


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
	var player: WorldPlayerRuntimeState = _contact.map.session.player_runtime()
	var state: CharacterState = player.state
	var catalog: ContentCatalog = GameContent.catalog()
	var lines: Array[String] = [player.shown_title()]
	for skill_id: StringName in _contact.teachable_skills():
		var skill: SkillDefinition = catalog.skill(skill_id)
		var line: String = tr("{skill} {level} · 学习进度 {progress} · 耗精 {cost}").format({
			"skill": tr(skill.display_name), "level": state.skills.raw_level(skill_id),
			"progress": state.skills.learned_progress(skill_id), "cost": _cost_text(state, skill_id),
		})
		lines.append(line)
	var uses: Array[StringName] = []
	for skill_id: StringName in _contact.teachable_skills():
		for use_id: StringName in catalog.skill(skill_id).valid_enabled_uses():
			if not uses.has(use_id):
				uses.append(use_id)
	for use_id: StringName in uses:
		var use_skill: SkillDefinition = catalog.skill(use_id)
		if use_skill == null:
			continue # a use the game does not model as a skill yet (move)
		lines.append(tr("有效{skill} {level}").format({
			"skill": tr(use_skill.display_name),
			"level": _contact.map.session.martial_arts().effective_level(use_id),
		}))
	lines.append(tr("精 {gin}（须大于消耗才可进步） · 可用潜能 {potential} · 实战经验 {exp}").format({
		"gin": state.essence.current, "potential": state.progression.potential - state.progression.potential_spent,
		"exp": state.progression.combat_experience,
	}))
	status.text = "\n".join(lines)
	if cancel_button != null:
		cancel_button.visible = player.apprenticeship_request.is_pending() and not is_confirming()
	if oath_button != null:
		oath_button.visible = _contact.awaits_oath() and not is_confirming()
	if trial_button != null:
		trial_button.visible = _contact.offers_trial() and not is_confirming()


## 拜师: a member of another family is told what betraying it costs, and one
## without a family what changing it later would cost; both are asked first. A master
## who would take the player for a traitor and attack them asks first too.
func request_apprentice() -> void:
	if not panel.visible:
		return
	var player: WorldPlayerRuntimeState = _contact.map.session.player_runtime()
	var master: NpcDefinition = _contact.npc.definition()
	var family: FamilyDefinition = GameContent.catalog().family(_contact.teaching().family_id)
	var family_name: String = tr(family.display_name) if family != null else ""
	# Asked only when 拜师 will take place: the master takes the player (it has offered,
	# or its requirements hold) and no request already waits on him (apprentice.c then
	# only says he has not answered).
	var awake: bool = _contact.npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	# juechen/master.c: a family's member is attacked for it; asked first (owner).
	if awake and player.would_be_attacked_by(master):
		_ask(tr(TRAITOR_WARNING).format({"master": tr(master.display_name), "title": player.shown_title()}), "确定拜师", "不拜了", _request_apprentice_now)
		return
	var takes: bool = awake and player.would_be_taken_by(master)
	if takes and _ask_family_change(player, master, family_name, "确定改投", "确定拜师", _request_apprentice_now):
		return
	_request_apprentice_now()


## Asks before a step that makes the player `master`'s apprentice when that changes
## their family (betrayal) or gives them their first master; true when it asked.
func _ask_family_change(player: WorldPlayerRuntimeState, master: NpcDefinition, family_name: String, betray_choice: String, first_choice: String, action: Callable) -> bool:
	if NpcApprenticeship.would_betray(player.state, master):
		_ask(tr(BETRAYAL_WARNING).format({
			"title": player.shown_title(), "master": tr(master.display_name),
			"family": family_name, "score": player.state.progression.score,
			"next": player.state.apprenticeship.betrayer_count + 1,
		}), betray_choice, "不改投了", action)
		return true
	if NpcApprenticeship.would_join_first(player.state, master):
		_ask(tr(FIRST_MASTER_WARNING).format({"master": tr(master.display_name), "family": family_name}), first_choice, "再想想", action)
		return true
	if NpcApprenticeship.would_change_master(player.state, master):
		var current: String = _current_master_name(player)
		_ask(tr(CHANGE_MASTER_WARNING).format({
			"current": current, "master": tr(master.display_name), "teach": _old_master_teaches(player, current),
		}), first_choice, "再想想", action)
		return true
	return false


func _current_master_name(player: WorldPlayerRuntimeState) -> String:
	return tr(player.state.apprenticeship.legacy_master_name)


## What the master the player leaves teaches them afterwards: nothing (privs 0), or only
## what he knows three times as well (an F_MASTER's prevent_learn()).
func _old_master_teaches(player: WorldPlayerRuntimeState, current: String) -> String:
	var old: NpcDefinition = GameContent.catalog().npc(player.state.apprenticeship.master_teacher_id)
	var teaching: NpcTeaching = null if old == null else old.teaching()
	if teaching == null:
		return ""
	if teaching.family_privileges != -1:
		return tr(CHANGE_TEACHES_NONE).format({"current": current})
	if teaching.f_master:
		return tr(CHANGE_TEACHES_LESS).format({"current": current})
	return ""


func _request_apprentice_now() -> void:
	_contact.request_apprentice()
	_show_apprentice_last()


## The oath: asked first when it will make the player his apprentice and that
## changes their family or is their first master (the 拜师 that waits on him).
func swear_oath() -> void:
	if not panel.visible or not _contact.awaits_oath():
		return
	var player: WorldPlayerRuntimeState = _contact.map.session.player_runtime()
	var master: NpcDefinition = _contact.npc.definition()
	if player.apprenticeship_request.recruit_takes_at_once(player.state, master) and _ask_family_change(player, master, _family_name(), "确定发誓", "确定发誓", _swear_now):
		return
	_swear_now()


func _swear_now() -> void:
	_contact.swear_oath()
	_show_apprentice_last()


## The accept test: always asked first (owner): three real blows, a fall, maybe death,
## and what passing it does.
func take_trial() -> void:
	if not panel.visible or not _contact.offers_trial():
		return
	var player: WorldPlayerRuntimeState = _contact.map.session.player_runtime()
	var master: NpcDefinition = _contact.npc.definition()
	var npc_name: String = tr(master.display_name)
	var after: String = tr(TRIAL_OFFERS).format({"master": npc_name})
	if player.apprenticeship_request.recruit_takes_at_once(player.state, master):
		if NpcApprenticeship.would_betray(player.state, master):
			after = tr(TRIAL_BETRAYS).format({
				"title": player.shown_title(), "master": npc_name, "family": _family_name(),
				"score": player.state.progression.score, "next": player.state.apprenticeship.betrayer_count + 1,
			})
		elif NpcApprenticeship.would_change_master(player.state, master):
			var current: String = _current_master_name(player)
			after = tr(TRIAL_CHANGES_MASTER).format({"current": current, "master": npc_name, "teach": _old_master_teaches(player, current)}).strip_edges()
		else:
			after = tr(TRIAL_RECRUITS).format({"master": npc_name, "family": _family_name()})
			if NpcApprenticeship.would_join_first(player.state, master):
				after += "\n" + tr(TRIAL_FIRST_MASTER)
	_ask(tr(TRIAL_WARNING).format({"master": npc_name, "after": after}), "接受测试", "不试了", _take_trial_now)


func _take_trial_now() -> void:
	_contact.take_trial()
	_show_apprentice_last()


func _family_name() -> String:
	var family: FamilyDefinition = GameContent.catalog().family(_contact.teaching().family_id)
	return tr(family.display_name) if family != null else ""


func _ask(text: String, choice: String, cancel: String, action: Callable) -> void:
	_on_confirm = action
	_set_confirming(true)
	confirm_box.ask(text, choice, cancel)
	confirm_box.focus_default()


func is_confirming() -> bool:
	return confirm_box != null and confirm_box.is_asking() and confirm_box.visible


func _confirmed() -> void:
	_set_confirming(false)
	var action: Callable = _on_confirm
	_on_confirm = Callable()
	if not panel.visible or not action.is_valid():
		return
	action.call()
	if panel.visible and apprentice_button.is_visible_in_tree():
		apprentice_button.grab_focus()


func _keep_family() -> void:
	_set_confirming(false)
	_on_confirm = Callable()
	if panel.visible:
		apprentice_button.grab_focus()


## While asking, only the title and the question show.
func _set_confirming(on: bool) -> void:
	if confirm_box == null:
		return
	for child: Node in _rows.get_children():
		if child == confirm_box:
			if not on:
				confirm_box.hide()
		elif child != _title and child is CanvasItem:
			(child as CanvasItem).visible = not on
	refresh()


func cancel_apprentice() -> void:
	if panel.visible:
		_contact.cancel_apprentice()
		_show_apprentice_last()


func _learn(skill_id: StringName) -> void:
	if panel.visible:
		_contact.request_learn(skill_id)
		_show_last()


func _show_last() -> void:
	feedback.text = "\n".join(_contact.last_lines)
	refresh()


func _show_apprentice_last() -> void:
	apprentice_feedback.text = "\n".join(_contact.last_lines)
	refresh()


func close_panel() -> void:
	if not is_instance_valid(panel):
		return
	var was_open: bool = panel.visible
	panel.hide()
	_contact.map.session.shared_ui().close_business(panel)
	if was_open and is_instance_valid(_contact.map.player_body):
		_contact.map.player_body.quarantine_current_movement_input()


## learn.c's gin cost with the teacher's own int: 150/int + 150/int, doubled for a new skill.
@warning_ignore("integer_division")
func _cost_text(state: CharacterState, skill_id: StringName) -> String:
	var teacher_int: int = _contact.npc.character_state.attributes.intelligence
	if state.attributes.intelligence == 0 or teacher_int == 0:
		return tr("无法计算")
	var cost: int = 150 / teacher_int + 150 / state.attributes.intelligence
	return str(cost * 2 if state.skills.raw_level(skill_id) == 0 else cost)
