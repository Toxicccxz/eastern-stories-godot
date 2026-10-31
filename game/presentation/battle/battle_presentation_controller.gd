class_name BattlePresentationController
extends Control

## Session-owned projection/intent adapter. Never executes or advances combat.
signal intent_submitting

# TRANSLATORS: asked before 天邪虎啸 (roar.c) in a fight: everyone here who does not withstand it turns on the player to the death.
const ROAR_QUESTION: String = "天邪虎啸要耗 150 点内力。啸声会震伤这里每一个人的神；没能抵住的人，不管是谁，都会对你下杀手，切磋也会变成生死相搏。\n确定要发出虎啸吗？"
# TRANSLATORS: asked before 压制杀气 (powerfade.c) in a fight; {odds} is how likely the player is to fall unconscious (约有 6 成会昏倒).
const POWERFADE_QUESTION: String = "在战斗中运功压制杀气，可能当场昏倒：以你现在的定力和内功，{odds}。昏倒以后，要杀你的人不会停手。\n确定要压制杀气吗？"
# TRANSLATORS: asked before 召天将 (saveme.c) in a spar: the soldier kills the sparring partner, who kills it back; its kills count as the player's (combatd.c killer_reward()).
const SAVEME_QUESTION: String = "召天将要耗 100 点法力和 60 点神。天将一来就会对你的对手下杀手，对手也会杀它，切磋就变成生死相搏，你的对手可能会死。天将杀的人都算在你头上，杀了师父便是弑师。\n确定要召唤天将吗？"
# TRANSLATORS: asked before 召护法 (invocation.c) in a spar: the 天将 or 阴鬼卒 kills the sparring partner, who kills it back; its kills count as the player's.
const INVOCATION_QUESTION: String = "召护法要耗 100 点法力和 60 点神。来的天将或阴鬼卒会对你的对手下杀手，对手也会杀它，切磋就变成生死相搏，你的对手可能会死。它杀的人都算在你头上，杀了师父便是弑师。\n确定要召护法吗？"
# TRANSLATORS: asked before 召天将/召护法 while fighting the 观想虫 the player's own practice conjured (mind_bug.c die()): {npc} is its name; killed by anyone but the player, the player faints and learns nothing.
const CONJURED_SUMMON_QUESTION: String = "来相助的护法会替你杀{npc}。{npc}不是你亲手杀的，你会昏倒，也悟不到咒术的道理。\n确定要召唤吗？"
signal intent_received(result: CombatTacticalResult)
signal target_submitting
signal target_received(result: CombatTargetResult)

@export var action_catalog: BattleActionPresentationCatalog
@export var visual_theme: Theme
var _session: WorldSessionController
var _intent: BattleIntentAdapter
var _reader := BattleFeedbackReader.new()
var _projection := BattlePresentationProjection.new()
var _displayed_id: StringName = &""
var _reported_completion_id: StringName = &""
## DECISIONS「战斗界面」: each enemy's 战前预判, read once when it first stands in the fight
## and kept until the fight ends (null: nothing could be read).
var _strengths: Dictionary[StringName, BattleStrength] = {}
var _safe: SafeAreaPresenter
var _content: VBoxContainer
var _participants: HBoxContainer
var _cards: Array[BattleParticipantCard] = []
var _shown_participants: Array[StringName] = []
var _title: Label
## kill_ob()'s 看起来X想杀死你！ lines, pinned under the title for the whole fight.
var _warning: Label
## The feel (DECISIONS「手感」): a round's lines are told one after another
## (battle_line_ms), the cards follow once they are, and a fight's end holds the panel
## on its last lines (battle_end_hold_ms) before the result and the world come back.
const END_HOLD: StringName = &"battle_end"
var _line_queue: Array[BattleNarrationLine] = []
var _told: Array[BattleNarrationLine] = []
var _line_wait: float = 0.0
var _line_spacing: float = 0.0
var _hold_left: float = 0.0
var _held_result: String = ""
var _hold_shield: Control
## The cards take the finished fight's last 气 once its last lines are told.
var _final_cards: bool = false
## 战斗决策层 3 (DECISIONS「战斗演出」): whether the fight waited for the player on the last
## refresh (the chosen move bounces when it comes back to waiting); the 胜 / 败 stamp over
## the cards during the end hold.
var _was_waiting: bool = false
var end_stamp: Label
var _stamp_tween: Tween
# TRANSLATORS: the stamp over the battle cards when the fight is won.
const STAMP_WON: String = "胜"
# TRANSLATORS: the stamp over the battle cards when the fight is lost.
const STAMP_LOST: String = "败"
var _fade: Tween
var _recent: VBoxContainer
var _receipt: Label
var _yielded_hud: CanvasLayer
var _hud_was_visible: bool = false
var _saved_focus: WeakRef
var action_panel: BattleActionPanel
var log_panel: BattleLogPanel
var log_button: Button
## [LB][RB] 换目标 while there is more than one to choose (keys and pad).
var target_hints: InputHintRow


func _enter_tree() -> void:
	if is_instance_valid(_content):
		_attach_metrics.call_deferred() # Same UI survives staging -> current Session.


func _ready() -> void:
	_session = get_parent().get_parent() as WorldSessionController
	theme = visual_theme if visual_theme != null else BattleVisualTheme.new()
	if action_catalog == null:
		action_catalog = BattleActionPresentationCatalog.new()
	_reader.catalog = action_catalog
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var blocker := ExplorationPresentationBlocker.new()
	blocker.name = "ExplorationInputContext"
	add_child(blocker)
	_attach_metrics()
	hide()


func _attach_metrics() -> void:
	if not is_inside_tree():
		return
	_safe = SafeAreaPresenter.find_or_create(self)
	if not _safe.metrics_changed.is_connected(_apply_metrics):
		_safe.metrics_changed.connect(_apply_metrics)
	_apply_metrics(_safe.current_metrics())


func _exit_tree() -> void:
	if is_instance_valid(_safe) and _safe.metrics_changed.is_connected(_apply_metrics):
		_safe.metrics_changed.disconnect(_apply_metrics)
	_restore_world_hud()


func _process(delta: float) -> void:
	refresh_projection()
	_tell_lines(delta)
	if _holding():
		_hold_left -= delta
		if _hold_left <= 0.0 and _line_queue.is_empty():
			_end_hold()


## The fight is over and the panel still shows its last lines.
func _holding() -> bool:
	return not _held_result.is_empty()


func _end_hold() -> void:
	var text: String = _held_result
	_held_result = ""
	_hold_left = 0.0
	_final_cards = false
	_hold_shield.visible = false
	end_stamp.visible = false
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()
	if _session != null:
		_session.hold_presentation(END_HOLD, false)
	if not _projection.active:
		hide()
		_restore_world_hud()
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	if hud != null:
		hud.show_combat_result(text)


## The next waiting line joins the recent strip: battle_line_ms apart, closer when more wait
## than a round leaves time for (they are all told before the next round's).
func _tell_lines(delta: float) -> void:
	if _line_queue.is_empty():
		return
	var spacing: float = _line_spacing
	_line_wait -= delta
	while not _line_queue.is_empty() and (spacing <= 0.0 or _line_wait <= 0.0):
		var line: BattleNarrationLine = _line_queue.pop_front()
		_told.append(line)
		_show_line(line)
		if spacing > 0.0:
			_line_wait += spacing
	if _told.size() > BattleFeedbackReader.RECENT_LINES:
		_told = _told.slice(_told.size() - BattleFeedbackReader.RECENT_LINES)
	_present_recent(_told)
	if _line_queue.is_empty():
		_line_wait = 0.0
		if _projection.active:
			_present_participants()
		elif _final_cards:
			_settle_final_cards()


func _settle_final_cards() -> void:
	_final_cards = false
	for index: int in mini(_cards.size(), _shown_participants.size()):
		var vitality: CharacterResourceState = _session.encounter_vitality(_shown_participants[index])
		if vitality != null:
			_cards[index].show_final_vitality(vitality)
		_cards[index].show_final_fall(_final_fallen(_shown_participants[index]))
	_show_end_stamp()


## The 倒 / 亡 stamp for one as the finished fight left them (the fight's last blow felled
## them after the cards' last refresh): "" standing.
func _final_fallen(id: StringName) -> String:
	var life: int = CharacterRuntimeLifeStatus.Value.ACTIVE
	if id == _session.player_runtime().character_id:
		life = _session.player_runtime().life_status
	else:
		var map := _session.active_map() as WorldMapController
		var npc: NpcRuntimeState = null if map == null else map.find_resident_npc(id)
		if npc != null:
			life = npc.life_status
	match life:
		CharacterRuntimeLifeStatus.Value.DEAD:
			return tr(BattleCardStage.STAMP_DEAD)
		CharacterRuntimeLifeStatus.Value.UNCONSCIOUS:
			return tr(BattleCardStage.STAMP_UNCONSCIOUS)
	return ""


## DECISIONS「战斗演出」: the line told now plays on the cards it concerns (the attacker's
## title, the one hit's float, flash, shake and the bar stepping down).
func _show_line(line: BattleNarrationLine) -> void:
	if not line.has_blow and not line.is_special:
		return
	for card: BattleParticipantCard in _cards:
		card.show_line(line)


## The 胜 / 败 stamp over the cards once the finished fight's last lines are told (the end
## hold): won when the other side fell, lost when the player did; nothing for a flight, a
## surrender, a spar that stopped or a fight that just ended.
func _show_end_stamp() -> void:
	var seconds: float = GameContent.catalog().pacing().feel.end_stamp_seconds
	var text: String = _end_stamp_text()
	if seconds <= 0.0 or text.is_empty() or not _holding():
		return
	end_stamp.text = text
	end_stamp.visible = true
	end_stamp.reset_size()
	end_stamp.pivot_offset = end_stamp.size * 0.5
	var area: Rect2 = _participants.get_parent().get_global_rect()
	end_stamp.global_position = area.get_center() - end_stamp.size * 0.5
	end_stamp.modulate = Color(1, 1, 1, 0)
	end_stamp.scale = Vector2.ONE * BattleCardStage.SLAM_FROM
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()
	_stamp_tween = create_tween().set_parallel(true)
	_stamp_tween.tween_property(end_stamp, "modulate:a", 1.0, seconds * 0.4)
	_stamp_tween.tween_property(end_stamp, "scale", Vector2.ONE, seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _end_stamp_text() -> String:
	if _session == null or not _session.is_initialized():
		return ""
	var receipt: CombatEncounterCompletionResult = _session.combat_encounter_coordinator().last_completion()
	if receipt == null or not receipt.succeeded() or receipt.terminal_result == null:
		return ""
	match receipt.terminal_result.kind:
		CombatEncounterResultKind.Value.VICTORY:
			return "" if receipt.terminal_result.losing_side_ids().is_empty() else tr(STAMP_WON)
		CombatEncounterResultKind.Value.DEFEAT:
			return tr(STAMP_LOST)
	return ""


func _queue_lines(lines: Array[BattleNarrationLine]) -> void:
	_line_queue.append_array(lines)
	# Set as they come: what waits is told within nine tenths of a round.
	var round_seconds: float = BattlePace.real_seconds(GameContent.catalog().pacing().combat_round_seconds)
	_line_spacing = minf(GameContent.catalog().pacing().feel.battle_line_seconds, round_seconds * 0.9 / float(_line_queue.size()))
	_tell_lines(0.0)


func current_projection() -> BattlePresentationProjection:
	return _projection


func feedback_reader() -> BattleFeedbackReader:
	return _reader


func refresh_projection() -> void:
	_present_completed_result()
	_projection = BattleProjectionBuilder.build(_session, _strengths)
	var changed: bool = _displayed_id != _projection.encounter_id
	if changed:
		_strengths.clear()
	if _projection.active and _read_strengths():
		_projection = BattleProjectionBuilder.build(_session, _strengths)
	if changed:
		_displayed_id = _projection.encounter_id
		log_panel.close_log()
		_receipt.text = ""
		if _projection.active:
			if _holding():
				# A new fight before the last one's lines were done: its result now.
				_end_hold()
			log_panel.clear_entries()
			_warning.text = ""
			_warning.visible = false
			_line_queue.clear()
			_told.clear()
			_line_wait = 0.0
			if _intent == null:
				_intent = BattleIntentAdapter.new(_session.combat_encounter_coordinator(), _projection.player_id)
			if not visible:
				_yield_world_hud()
				_fade_in()
			show()
		elif not _holding():
			hide()
			_restore_world_hud()
	var entries: Array[BattleFeedbackProjection] = []
	if _session.is_initialized():
		entries = _reader.read_new(_session.combat_encounter_coordinator(), _projection)
	if not _projection.active:
		return
	# The opening's warnings, and those of anyone who turns on the player later (roar.c).
	var warnings: Array[String] = _session.combat_encounter_coordinator().opening_warnings(_projection.encounter_id)
	var warning_text: String = "\n".join(PackedStringArray(warnings))
	if warning_text != _warning.text:
		_warning.text = warning_text
		_warning.visible = not warnings.is_empty()
	var heading: String = _mode_name(_projection.mode)
	if not _receipt.text.is_empty():
		heading += " · " + _receipt.text
	_title.text = heading + "\n" + tr("目标：%s") % tr(_projection.display_name(_projection.current_target_id))
	if _projection.completion_outcome >= 0:
		_title.text = "战斗无法正常结束，不会自动重试。"
	_title.tooltip_text = _title.text
	# The round's lines first: its blows wait on the cards until they are told.
	if not entries.is_empty():
		log_panel.append_entries(entries)
		for entry: BattleFeedbackProjection in entries:
			_queue_lines(entry.lines())
	elif changed:
		_present_recent([BattleNarrationLine.new(tr("战斗描写会显示在这里。"))])
	_present_participants()
	var others: Array[StringName] = _target_ids()
	others.erase(_projection.current_target_id)
	target_hints.set_hints([[[&"battle_target_previous", &"battle_target_next"], tr("换目标")]] if not others.is_empty() else [])
	action_panel.present(_projection)
	# DECISIONS「战斗演出」: back to waiting for the player: the chosen move bounces.
	var waiting: bool = _projection.waiting and _projection.manual
	if waiting and not _was_waiting and not changed:
		action_panel.bounce_chosen(GameContent.catalog().pacing().feel.turn_cue_seconds)
	_was_waiting = waiting
	if changed:
		_focus_battle.call_deferred()
	elif not log_panel.visible:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			_focus_battle()


## The 战前预判 of each enemy not read yet (the fight's first frame, one who joined later):
## the player against that one alone, as the map stands now. True when any was read.
func _read_strengths() -> bool:
	var map := _session.active_map() as WorldMapController
	var read: bool = false
	for value: BattleParticipantProjection in _projection.participants():
		if not value.hostile_to_player or _strengths.has(value.participant_id):
			continue
		var npc: NpcRuntimeState = null if map == null else map.find_resident_npc(value.participant_id)
		_strengths[value.participant_id] = BattleStrength.read(map, npc, tr(Es2CombatMessages.pronoun(value.gender)), _projection.mode == CombatEncounterMode.Value.SPAR)
		read = true
	return read


func _present_completed_result() -> void:
	if _session == null or not _session.is_initialized():
		return
	var receipt: CombatEncounterCompletionResult = _session.combat_encounter_coordinator().last_completion()
	if receipt == null or receipt.encounter_id == _reported_completion_id:
		return
	var coordinator: CombatEncounterCoordinator = _session.combat_encounter_coordinator()
	var text: String = BattleFeedbackReader.completion_text(
		receipt, _session.player_runtime().life_status, coordinator.departed(receipt.encounter_id),
		coordinator.npc_walked_out(receipt.encounter_id), BattleFeedbackReader.left_a_corpse(coordinator.completed_feedback(), receipt.encounter_id, _hostile_to_player),
	)
	if text.is_empty():
		return
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud == null:
		return

	_reported_completion_id = receipt.encounter_id
	# Parent Session finishes before this child processes. Drain the final suffix
	# using the last display names before replacing the now-inactive projection.
	var feedback_projection: BattlePresentationProjection = _projection
	if feedback_projection.encounter_id != receipt.encounter_id:
		# A large first frame can finish before the first UI refresh: take the
		# player, names and genders from the Session instead.
		feedback_projection = BattleProjectionBuilder.completed_cast(_session, receipt.encounter_id)
		log_panel.clear_entries()
	var entries: Array[BattleFeedbackProjection] = _reader.read_new(_session.combat_encounter_coordinator(), feedback_projection)
	log_panel.append_entries(entries)
	for line: BattleNarrationLine in _reader.recent_events():
		text += "\n" + line.text
	var hold: float = GameContent.catalog().pacing().feel.battle_end_hold_seconds
	if _holding():
		# Another fight ended before the last one's result was out: that one first.
		_end_hold()
	if hold <= 0.0 or not visible:
		hud.show_combat_result(text)
		return
	# The panel stays on the fight's last lines, the world held, then the result (the hold
	# is set before the lines: the cards settle and the stamp shows under it).
	_final_cards = true
	_held_result = text
	_hold_left = hold
	_hold_shield.visible = true
	for entry: BattleFeedbackProjection in entries:
		_queue_lines(entry.lines())
	if _line_queue.is_empty():
		_settle_final_cards()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	_session.hold_presentation(END_HOLD, true)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "FrozenWorldShade"
	backdrop.color = Color(0.025, 0.035, 0.045, 0.68)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_content = VBoxContainer.new()
	_content.name = "SafeBattleContent"
	_content.minimum_size_changed.connect(_refit_content.call_deferred)
	add_child(_content)
	var header := HBoxContainer.new()
	_content.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_color_override("font_color", Color("efc77b"))
	header.add_child(_title)
	log_button = Button.new()
	log_button.name = "CombatLogButton"
	log_button.text = "战斗记录"
	log_button.custom_minimum_size = Vector2(144, 64)
	log_button.pressed.connect(_open_log)
	header.add_child(log_button)
	InputGlyphs.decorate(log_button, &"battle_log")
	# Reserve shared Shell TouchPause space, including desktop touch-capability QA.
	var pause_space := Control.new()
	pause_space.custom_minimum_size = Vector2(64, 64)
	pause_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(pause_space)
	# The panel covers the log the warning was printed to, and the first round's
	# lines would push it out of the recent strip: it stays here instead.
	_warning = Label.new()
	_warning.name = "KillWarning"
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.add_theme_color_override("font_color", SharedGameplayUI.ALERT_COLOR)
	_warning.visible = false
	_content.add_child(_warning)
	var participant_scroll := ScrollContainer.new()
	participant_scroll.name = "ParticipantScroll"
	participant_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	participant_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	participant_scroll.follow_focus = true
	participant_scroll.custom_minimum_size.y = 144
	participant_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(participant_scroll)
	_participants = HBoxContainer.new()
	_participants.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_participants.size_flags_vertical = Control.SIZE_EXPAND_FILL
	participant_scroll.add_child(_participants)
	target_hints = InputHintRow.new()
	_content.add_child(target_hints)
	action_panel = BattleActionPanel.new()
	action_panel.name = "QuickActions"
	action_panel.catalog = action_catalog
	action_panel.confirm_text = _question_for
	action_panel.action_requested.connect(_submit_action)
	action_panel.cancel_requested.connect(_cancel_action)
	action_panel.enforce_requested.connect(_enforce)
	action_panel.move_requested.connect(_choose_move)
	action_panel.stance_requested.connect(_set_stance)
	action_panel.manual_toggled.connect(_set_manual)
	_content.add_child(action_panel)
	_receipt = Label.new()
	_receipt.name = "IntentReceipt"
	_receipt.visible = false # Text is projected into the header, not an extra narrow-screen row.
	_receipt.add_theme_font_size_override("font_size", 14)
	_content.add_child(_receipt)
	_recent = VBoxContainer.new()
	_recent.name = "RecentFeedback"
	_recent.add_theme_constant_override("separation", 0)
	_recent.custom_minimum_size.y = 60
	_content.add_child(_recent)
	for index: int in BattleFeedbackReader.RECENT_LINES:
		# One row per line, written as the battle log writes it (BattleNarrationLine
		# rich_text()): the damage small and grey right after the words (owner, modern
		# fixes II), a long line cut at the row's edge.
		var row := HBoxContainer.new()
		_recent.add_child(row)
		var line := RichTextLabel.new()
		line.name = "Text"
		line.bbcode_enabled = true
		# One line high, as wide as the row gives it (fit_content would make a long line
		# as wide as its words); _fitted() cuts a long line before its damage.
		line.fit_content = false
		line.custom_minimum_size.y = 22
		line.scroll_active = false
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_contents = true
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_font_size_override("normal_font_size", 16)
		row.add_child(line)
	end_stamp = Label.new()
	end_stamp.name = "EndStamp"
	end_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_stamp.visible = false
	end_stamp.rotation = deg_to_rad(-8.0)
	end_stamp.add_theme_font_size_override("font_size", 96)
	end_stamp.add_theme_color_override("font_color", BattleCardStage.STAMP_RED)
	end_stamp.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.08, 0.9))
	end_stamp.add_theme_constant_override("outline_size", 8)
	add_child(end_stamp)
	log_panel = BattleLogPanel.new()
	log_panel.name = "CombatLog"
	log_panel.closed.connect(_focus_battle)
	add_child(log_panel)
	# Over the panel while it holds a finished fight's last lines: nothing is pressed then.
	_hold_shield = Control.new()
	_hold_shield.name = "EndHoldShield"
	_hold_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hold_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_hold_shield.visible = false
	add_child(_hold_shield)


func _apply_metrics(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	_content.position = metrics.content_rect().position
	_content.size = metrics.content_rect().size
	log_panel.apply_metrics(metrics)


func _refit_content() -> void:
	# Initial text/container minimums can temporarily grow the Control. Restore the
	# same SafeArea bounds after native layout converges, without a second sampler.
	if not is_inside_tree() or not is_instance_valid(_safe):
		return
	var metrics: SafeAreaMetrics = _safe.current_metrics()
	if metrics != null:
		_content.position = metrics.content_rect().position
		_content.size = metrics.content_rect().size


## The player's card first, then those on the player's side (the soldier they called),
## then the others, each group in the fight's order.
func _present_participants() -> void:
	var values: Array[BattleParticipantProjection] = []
	for group: int in 3:
		for value: BattleParticipantProjection in _projection.participants():
			var rank: int = 0 if value.participant_id == _projection.player_id else 2 if value.hostile_to_player else 1
			if rank == group:
				values.append(value)
	var ids: Array[StringName] = []
	for value: BattleParticipantProjection in values:
		ids.append(value.participant_id)
	if ids != _shown_participants:
		_shown_participants = ids
		for card: BattleParticipantCard in _cards:
			_participants.remove_child(card)
			card.queue_free()
		_cards.clear()
		for id: StringName in ids:
			var card := BattleParticipantCard.new()
			card.name = "Participant%d" % _cards.size()
			card.custom_minimum_size.x = 300
			card.target_requested.connect(_change_target)
			card.finish_requested.connect(_finish_downed)
			card.spare_requested.connect(_spare_downed)
			_participants.add_child(card)
			_cards.append(card)
	# A blow's 气 shows once its line is told (DECISIONS「手感」).
	var told: bool = _line_queue.is_empty()
	for index: int in values.size():
		var queued: CombatQueuedAction = _projection.queued_action()
		_cards[index].present(values[index], _projection.player_id, _projection.current_target_id, &"" if queued == null else queued.resolved_target_id, not told)


func _present_recent(lines: Array[BattleNarrationLine]) -> void:
	for index: int in _recent.get_child_count():
		var row: Node = _recent.get_child(index)
		var line: BattleNarrationLine = lines[index] if index < lines.size() else null
		var text: RichTextLabel = row.get_node("Text")
		if line == null:
			text.text = ""
			text.tooltip_text = ""
			continue
		# DECISIONS「战斗界面」: a blow's short form in the strip, ES2's line on hover.
		var shown: BattleNarrationLine = BattleNarrationLine.new(line.summary, -1, line.color) if line.has_summary else line
		text.text = _fitted(shown, text, text.size.x).rich_text()
		text.tooltip_text = line.text + ((" " + tr("（-%d）") % line.damage) if line.has_damage else "")


## The line cut short with an ellipsis so that it and its damage fit `width` (the row's
## label; 0 before the first layout: the line as it is).
func _fitted(line: BattleNarrationLine, label: RichTextLabel, width: float) -> BattleNarrationLine:
	var font: Font = label.get_theme_font("normal_font")
	if font == null or width <= 0.0:
		return line
	var size: int = label.get_theme_font_size("normal_font_size")
	# TRANSLATORS: the damage behind a battle line, as BattleNarrationLine.rich_text() shows it.
	var damage: String = (" " + tr("（-%d）") % line.damage) if line.has_damage else ""
	var budget: float = width - font.get_string_size(damage, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size - 4, 1)).x - 4.0
	if font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= budget:
		return line
	var words: String = line.text
	while words.length() > 1 and font.get_string_size(words + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > budget:
		words = words.left(words.length() - 1)
	return BattleNarrationLine.new(words + "…", line.damage, line.color)


func _mode_name(mode: int) -> String:
	match mode:
		CombatEncounterMode.Value.SPAR:
			return tr("切磋")
		CombatEncounterMode.Value.LETHAL:
			return tr("厮杀")
	return tr("战斗")


## The battle's keys and pad (owner, gamepad support): LB / RB (Q / E) step the target,
## Y (L) opens or closes the log, B (Backspace) goes back: the log closes, a question is
## answered 取消, else the planned action is dropped. Esc stays the pause.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _projection.active or event.is_echo() or not event.is_pressed() or get_tree().paused:
		if _holding() and is_visible_in_tree() and not event.is_action(&"pause_game"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"battle_log"):
		if log_panel.visible:
			log_panel.close_log()
		else:
			_open_log()
	elif event.is_action_pressed(&"battle_back") and not event.is_action(&"pause_game"):
		if log_panel.visible:
			log_panel.close_log()
		elif action_panel.is_asking():
			action_panel.prompt.cancel()
		else:
			action_panel.cancel_planned()
	elif log_panel.visible:
		return
	elif event.is_action_pressed(&"battle_target_previous"):
		step_target(-1)
	elif event.is_action_pressed(&"battle_target_next"):
		step_target(1)
	else:
		return
	get_viewport().set_input_as_handled()


## The ones the player can target, in the cards' order.
func _target_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _shown_participants:
		var value: BattleParticipantProjection = _projection.participant(id)
		if value != null and value.targetable and id != _projection.player_id:
			ids.append(id)
	return ids


## The next (1) or previous (-1) target after the current one.
func step_target(direction: int) -> void:
	var ids: Array[StringName] = _target_ids()
	if ids.is_empty():
		return
	var index: int = ids.find(_projection.current_target_id)
	var next: StringName = ids[0] if index < 0 else ids[posmod(index + direction, ids.size())]
	if next != _projection.current_target_id:
		_change_target(next)


func _change_target(id: StringName) -> void:
	if _intent == null:
		return
	target_submitting.emit()
	var result: CombatTargetResult = _intent.change_target(_projection.encounter_id, id)
	_receipt.text = tr("换目标：%s") % BattleFeedbackReader.target_reason(result.code)
	target_received.emit(result)


## The 观想虫 the player's practice conjured, standing in this fight; null otherwise.
func _conjured_enemy() -> NpcRuntimeState:
	var player: WorldPlayerRuntimeState = _session.player_runtime()
	var encounter: CombatEncounter = _session.combat_encounter_coordinator().active_encounter()
	var map := _session.active_map() as WorldMapController
	if player.conjured_npc_id.is_empty() or encounter == null or map == null or encounter.participant_for(player.conjured_npc_id) == null:
		return null
	var npc: NpcRuntimeState = map.find_resident_npc(player.conjured_npc_id)
	return npc if npc != null and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD else null


## Owner (2026-10-06): 天邪虎啸 and powerfade in a fight are asked first, when they
## would run now: [question, choice], or empty for an action asked nothing.
func _question_for(id: StringName) -> PackedStringArray:
	if _session == null or not _session.is_initialized() or _session.player_runtime() == null:
		return PackedStringArray()
	var state: CharacterState = _session.player_runtime().state
	# saveme.c's (invocation.c's) soldier kills the sparring partner: the spar goes on to the
	# death. Against the player's own 观想虫 its kill makes the player faint (mind_bug.c die()).
	var spell: StringName = CombatCastTacticalPolicy.function_for(id)
	if (
		(spell == &"saveme" and state.recovery.mana.current >= SavemeSpell.MANA_COST and state.spirit.current >= SavemeSpell.SEN_COST)
		or (spell == &"invocation" and state.recovery.mana.current >= InvocationSpell.MANA_COST and state.spirit.current >= InvocationSpell.SEN_COST)
	):
		var choice: String = "召唤天将" if spell == &"saveme" else "召护法"
		if _projection.mode == CombatEncounterMode.Value.SPAR:
			return PackedStringArray([tr(SAVEME_QUESTION if spell == &"saveme" else INVOCATION_QUESTION), choice])
		var conjured: NpcRuntimeState = _conjured_enemy()
		if conjured != null:
			return PackedStringArray([tr(CONJURED_SUMMON_QUESTION).format({"npc": tr(conjured.definition().display_name)}), choice])
	# A spell at oneself whose sen would knock the player out (astral_vision.c's 5).
	var at_self: CastFunction = SpecialFunctions.cast(spell) if CombatCastTacticalPolicy.is_self(id) else null
	if at_self != null and not _session.martial_arts().forbids_magic() and state.spirit.current < at_self.self_sen_cost(state):
		return PackedStringArray([tr(SharedUiPanels.SPELL_FAINT_WARNING).format({"spell": tr(at_self.self_label), "sen": at_self.self_sen_cost(state)}), "确定施展"])
	# kill.c at the player's own master (beside the zombie a sheet sent): 弑师, as 攻击 asks.
	if id == CombatKillTacticalPolicy.ACTION_ID:
		var map := _session.active_map() as WorldMapController
		var victim: NpcRuntimeState = null if map == null else map.find_resident_npc(_session.combat_encounter_coordinator().kill_target())
		if victim != null and PlayerKillerReward.is_own_master(state, victim.definition()):
			var family: FamilyDefinition = GameContent.catalog().family(victim.definition().teaching().family_id)
			return PackedStringArray([tr(SharedGameplayUI.MASTER_ATTACK_WARNING).format({
				"master": tr(victim.definition().display_name), "family": tr(family.display_name) if family != null else "",
				"score": state.progression.score, "next": state.apprenticeship.betrayer_count + 1,
			}), "确定攻击"])
	match CombatExertTacticalPolicy.function_for(id):
		&"roar":
			if RoarExertFunction.would_run(state, true):
				return PackedStringArray([tr(ROAR_QUESTION), "发出虎啸"])
		&"powerfade":
			var chance: float = PowerfadeExertFunction.faint_chance(_session.martial_arts().force_level(), state.attributes.composure)
			if PowerfadeExertFunction.would_run(state) and chance > 0.0:
				return PackedStringArray([tr(POWERFADE_QUESTION).format({"odds": _faint_odds(chance)}), "压制杀气"])
	return PackedStringArray()


## powerfade.c's random(skill) < cps * 3, in words: 一定, 约 N 成, or 很小.
func _faint_odds(chance: float) -> String:
	if chance >= 1.0:
		return tr("一定会昏倒")
	var tenths: int = mini(roundi(chance * 10.0), 9)
	if tenths <= 0:
		return tr("昏倒的可能很小")
	# TRANSLATORS: the chance that powerfade knocks the player out, in tenths (成): 约有 6 成会昏倒 is about 60%.
	return tr("约有 {tenths} 成会昏倒").format({"tenths": tenths})


func _submit_action(id: StringName) -> void:
	if _intent == null:
		return
	var target: StringName = &""
	for info: CombatTacticalActionInfo in _projection.actions():
		if info.action_id == id and info.target_rule == CombatTacticalRequest.TargetRule.SINGLE_HOSTILE:
			target = _projection.current_target_id # Declared displayed intent, not validity/retargeting.
	intent_submitting.emit()
	var result: CombatTacticalResult = _intent.submit(id, target)
	_receipt.text = tr("下令：%s") % BattleFeedbackReader.reason(result.code)
	intent_received.emit(result)


## Whether `id` fought against the player in the fight the panel last showed (one it never
## showed: anyone but the player).
func _hostile_to_player(id: StringName) -> bool:
	var value: BattleParticipantProjection = _projection.participant(id)
	return value.hostile_to_player if value != null else id != _session.player_runtime().character_id


## DECISIONS「了结 / 放过」: the button is the choice (no second question).
func _finish_downed(id: StringName) -> void:
	if _intent != null and _projection.active:
		_intent.finish_downed(id)


func _spare_downed(id: StringName) -> void:
	if _intent != null and _projection.active:
		_intent.spare_downed(id)


## 战斗决策层 1B: the move for this round (the round runs on it).
func _choose_move(action_id: StringName) -> void:
	if not _projection.active or _session == null or not _session.is_initialized():
		return
	if _session.combat_encounter_coordinator().choose_attack(action_id):
		refresh_projection()


## The stance: set at once; enforce.c's lines (攻's 加力) join the battle log.
func _set_stance(value: int) -> void:
	if not _projection.active or _session == null or not _session.is_initialized():
		return
	var lines: Array[BattleNarrationLine] = []
	for line: ColoredLine in _session.combat_encounter_coordinator().set_stance(value):
		lines.append(BattleNarrationLine.new(line.text, -1, line.color))
	if not lines.is_empty():
		log_panel.append_entries([BattleFeedbackProjection.new(_reader.last_consumed_order, lines)])
		_reader.note(lines)
		_queue_lines(lines)
	refresh_projection()


func _set_manual(on: bool) -> void:
	if _session == null or not _session.is_initialized():
		return
	_session.combat_encounter_coordinator().set_manual_turns(on)
	refresh_projection()


## enforce.c in the fight: set now; its lines join the battle log.
func _enforce(points: int) -> void:
	if not _projection.active or _session == null or not _session.is_initialized():
		return
	var lines: Array[BattleNarrationLine] = []
	for line: ColoredLine in _session.martial_arts().enforce(points):
		lines.append(BattleNarrationLine.new(line.text, -1, line.color))
	if lines.is_empty():
		return
	log_panel.append_entries([BattleFeedbackProjection.new(_reader.last_consumed_order, lines)])
	_reader.note(lines)
	_queue_lines(lines)


func _cancel_action(expected_request_id: StringName) -> void:
	if _intent == null:
		return
	intent_submitting.emit()
	var result: CombatTacticalResult = _intent.cancel(expected_request_id)
	_receipt.text = tr("取消：%s") % BattleFeedbackReader.reason(result.code)
	intent_received.emit(result)


func _open_log() -> void:
	log_panel.open_log()


## The panel fades in over the feel's menu_fade_ms, as the menu does.
func _fade_in() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var seconds: float = GameContent.catalog().pacing().feel.menu_fade_seconds
	modulate.a = 0.0 if seconds > 0.0 else 1.0
	if seconds > 0.0:
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 1.0, seconds)


func _focus_battle() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or get_tree().paused or log_panel.visible:
		return
	# A question stands in for the buttons: the focus goes back to its 取消.
	if action_panel.is_asking():
		action_panel.prompt.focus_default()
		return
	# 等你出招: the first move (DECISIONS「战斗界面」), else the first quick action.
	var move: Button = action_panel.first_move_button() if _projection.waiting and _projection.manual else null
	var first: Button = move if move != null else action_panel.first_action_button()
	(first if first != null else log_button).grab_focus()


func _yield_world_hud() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	_saved_focus = weakref(focus) if focus != null else null
	if focus != null:
		focus.release_focus()
	_yielded_hud = _session.shared_ui()
	if _yielded_hud != null:
		_hud_was_visible = _yielded_hud.visible
		_yielded_hud.hide()


func _restore_world_hud() -> void:
	if is_instance_valid(_yielded_hud):
		_yielded_hud.visible = _session.can_process() and not _session.is_restore_candidate_staged() and _session.application_gameplay_allows_encounter_advance()
	_yielded_hud = null
	if _saved_focus != null:
		FocusNav.give(_saved_focus.get_ref() as Control)
	_saved_focus = null
