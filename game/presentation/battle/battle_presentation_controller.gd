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
## 战斗演出 A: the cards' area — one row (_participants), or the two sides (_sides; each
## side's [big row, chip row] in _side_rows) — and what the layout was last made for.
var _card_area: VBoxContainer
var _participants: HBoxContainer
var _sides: HBoxContainer
var _side_rows: Array = []
var _card_layout_key: String = ""
var _compact: bool = false
var _room_width: float = 0.0
var _cards: Array[BattleParticipantCard] = []
var _shown_participants: Array[StringName] = []
## 战斗演出 A: the head — the mode's word, its rule, the line under it — and the shade over
## the scene, all in the mode's look (BattleModeLook); the mode they show now (-1 none yet).
var _title: Label
var _rule: ColorRect
var _motto: Label
var _shade: ColorRect
var _shown_mode: int = -1
## kill_ob()'s 看起来X想杀死你！ lines, pinned under the title for the whole fight.
var _warning: Label
## The recent strip (floating over its slot under the head), whether it shows three lines,
## and how long it stays so without a new line.
var _strip: PanelContainer
var _strip_slot: Control
var _strip_open: bool = false
var _strip_left: float = 0.0
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
## 战斗拍数 C (DECISIONS「战斗拍数 C」): the fight in the scene and its sounds, played from the
## told line as the cards are; the beat the last told blow belonged to ([actor, beat]), so
## the strip pauses between beats (feel.beat_pause_ms) and waits the windup before a 重; the
## line the strip waits on now, so it waits once; whether the first beat won this fight had
## its whole ceremony; whether the round was running on the last refresh (回合间归位).
var scene_show: BattleSceneShow
var sounds: BattleSounds
## 战斗演出 B (DECISIONS「战斗演出 B」): the fight's opening (the stage laid, the camera drawn in, the
## panel slid in) and whether it waits for the panel's first layout (it starts the frame after).
var opening: BattleStageOpening
var move_titles: BattleMoveTitles
var _opening_pending: bool = false
var _head: VBoxContainer
var _strip_row: HBoxContainer
var _shade_tween: Tween
var _last_beat: Array = []
var _paused_for: BattleNarrationLine = null
var _earned_told: bool = false
var _round_was_running: bool = false
var _stamp_tween: Tween
# TRANSLATORS: the stamp over the battle cards when the fight is won.
const STAMP_WON: String = "胜"
# TRANSLATORS: the stamp over the battle cards when the fight is lost.
const STAMP_LOST: String = "败"
var _fade: Tween
## 战斗拍数 C: the pauses between beats scaled to fit the round (1: as the feel says).
var _pause_scale: float = 1.0
var _recent: VBoxContainer
var _receipt: Label
var _yielded_hud: CanvasLayer
var _hud_was_visible: bool = false
var _saved_focus: WeakRef
var action_panel: BattleActionPanel
var log_panel: BattleLogPanel
var log_button: Button
## The gap between the panel's rows. On a short desktop screen (below
## ApplicationShellLayout.SHORT_HEIGHT: a 16:9 screen at the 界面缩放 150% is 480 high) it closes
## up, as the dialogs do, so the densest view (a planned move with its target) still fits.
const ROW_GAP: int = 8
const SHORT_ROW_GAP: int = 4
## [LB][RB] 换目标 while there is more than one to choose (keys and pad).
var target_hints: InputHintRow


func _enter_tree() -> void:
	if is_instance_valid(_content):
		_attach_metrics.call_deferred() # Same UI survives staging -> current Session.


func _ready() -> void:
	_session = get_parent().get_parent() as WorldSessionController
	# 界面重做 4: the interface's one theme (DECISIONS「界面样式」); a scene may still lend its own.
	theme = visual_theme if visual_theme != null else GameTheme.shared()
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
	if _opening_pending and _projection.active:
		_opening_pending = false
		_start_opening()
	refresh_projection()
	_tell_lines(delta)
	# 战斗演出 D: the backdrop darkens the map under the raised stage; the shade keeps a little.
	_shade.modulate.a = opening.shade_share()
	if visible:
		_place_strip()
	if _strip_open:
		_strip_left -= delta
		if _strip_left <= 0.0:
			_set_strip_open(false)
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
	move_titles.clear()
	scene_show.end()
	opening.close()
	_drop_pending_opening()
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
	# 战斗演出 B: the lines wait while the stage is laid and the panel slides in.
	if _line_queue.is_empty() or _opening_pending or (opening.running() and not opening.instant):
		return
	var spacing: float = _line_spacing
	_line_wait -= delta
	while not _line_queue.is_empty() and (spacing <= 0.0 or _line_wait <= 0.0):
		# 战斗拍数 C: a new beat's first blow waits the pause between beats, a 重's the windup
		# too (the attacker crouches meanwhile); the clap of the beat landing comes with it.
		var next: BattleNarrationLine = _line_queue[0]
		if spacing > 0.0 and _paused_for != next and _starts_beat(next):
			_paused_for = next
			var pause: float = _beat_pause(next)
			if pause > 0.0:
				_line_wait += pause
				if next.tag == CombatMoveTags.HEAVY:
					scene_show.windup(next.actor_id)
				if _line_wait > 0.0:
					break
		var line: BattleNarrationLine = _line_queue.pop_front()
		_paused_for = null
		_told.append(line)
		if _strip_open:
			_strip_left = STRIP_OPEN_SECONDS # Open, it stays while lines come.
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
## title, the one hit's float, flash, shake and the bar stepping down). 战斗拍数 C: and in the
## scene (BattleSceneShow) and the sounds (BattleSounds), the same frame; a blow that fells
## its target is told as fatal (the hit-stop, the drum, the camera's last move).
func _show_line(line: BattleNarrationLine) -> void:
	if line.cue == BattleNarrationLine.CUE_EARNED:
		scene_show.play_line(line)
		sounds.play_all(BattleSounds.for_line(line, false, not _earned_told))
		_earned_told = true
		return
	if not line.has_blow and not line.is_special:
		return
	var fatal: bool = _fatal(line)
	if line.has_blow and _starts_beat(line) and not (line.actor_id == _projection.player_id and _projection.manual):
		# The beat landing: the player's own beat clapped when its button was pressed.
		sounds.play(BattleSounds.CLAPPER)
	if line.has_blow:
		_last_beat = [line.actor_id, line.beat_index]
	# 战斗演出 C (DECISIONS「战斗演出 C」): the move's name over the attacker's head — only for the
	# player's own blows, those at them, a felling blow and a special's opening; the card shows
	# it only when the figure is not in a scene. Others' blows sound thinner.
	var mine: bool = BattleSounds.mine(line, _projection.player_id)
	var named: bool = mine or fatal or line.is_special
	var overhead: bool = false
	if named:
		# A special's line (its opening, or its first blow when the blow comes first) carries its
		# name, in gold; any other blow its move's.
		var text: String = line.special_title if line.is_special else line.move
		overhead = move_titles.show_title(_voxel_view(), line, text, line.is_special, mine)
	for card: BattleParticipantCard in _cards:
		card.show_line(line, named and not overhead)
	scene_show.play_line(line, fatal)
	sounds.play_all(BattleSounds.for_line(line, fatal, false, mine), BattleSounds.priority_of(line, fatal, _projection.player_id))


## Whether `line` is the first blow of a beat not told yet (a blow of another actor or
## beat than the last told blow's).
func _starts_beat(line: BattleNarrationLine) -> bool:
	return line.has_blow and (_last_beat.is_empty() or _last_beat[0] != line.actor_id or _last_beat[1] != line.beat_index)


## The pause before a beat's first blow: the pause between beats, and the windup before a
## 重; at the strip's pace, scaled down when a round's lines would not fit before the next.
func _beat_pause(line: BattleNarrationLine) -> float:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var pause: float = feel.beat_pause_seconds
	if line.tag == CombatMoveTags.HEAVY:
		pause += feel.scene_windup_seconds
	return BattlePace.real_seconds(pause) * _pace_share() * _pause_scale


## 自动's share of the feel's seconds (the 快 pace); 1 under 手动.
func _pace_share() -> float:
	if _projection.turns_offered and not _projection.manual:
		return float(BattlePace.percent(BattlePace.Speed.FAST)) / 100.0
	return 1.0


## Whether the blow `line` reports fells its target: they are down in the projection (or the
## finished fight left them so) and no later blow in the queue strikes them.
func _fatal(line: BattleNarrationLine) -> bool:
	if not line.has_blow or line.outcome != CombatAttackResult.Outcome.HIT or line.target_id.is_empty():
		return false
	for later: BattleNarrationLine in _line_queue:
		if later.has_blow and later.target_id == line.target_id:
			return false
	var value: BattleParticipantProjection = _projection.participant(line.target_id)
	if value != null and _projection.active:
		return value.life_status != CombatSliceLifeStatus.Value.ACTIVE or value.threshold == CharacterState.LifeThreshold.DEAD or value.threshold == CharacterState.LifeThreshold.UNCONSCIOUS or value.knockout != null
	return _final_cards and _session != null and _session.is_initialized() and not _final_fallen(line.target_id).is_empty()


## The 胜 / 败 stamp over the cards once the finished fight's last lines are told (the end
## hold): won when the other side fell, lost when the player did; nothing for a flight, a
## surrender, a spar that stopped or a fight that just ended.
func _show_end_stamp() -> void:
	var seconds: float = GameContent.catalog().pacing().feel.end_stamp_seconds
	var text: String = _end_stamp_text()
	if seconds <= 0.0 or text.is_empty() or not _holding():
		return
	# The last lines may have taken the hold's time to drain: the hold keeps the stamp's own
	# time from here (Codex, PR #209).
	_hold_left = maxf(_hold_left, seconds)
	end_stamp.text = text
	end_stamp.visible = true
	sounds.play(BattleSounds.SEAL)
	end_stamp.reset_size()
	end_stamp.pivot_offset = end_stamp.size * 0.5
	# Over the cards the player sees (they keep to the top of their row since 界面重做 4; a
	# row too wide scrolls, so only its visible part counts), else their row.
	var shown: Rect2 = _participants.get_parent().get_global_rect()
	var area := Rect2()
	for card: BattleParticipantCard in _cards:
		if card.visible:
			area = card.get_global_rect() if not area.has_area() else area.merge(card.get_global_rect())
	area = area.intersection(shown)
	if not area.has_area():
		area = shown
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
	_line_queue.append_array(fold_beats(lines, _projection))
	# Set as they come: what waits is told within nine tenths of a round. 战斗拍数 B: under
	# 自动 the lines come at the 快 pace (feel.battle_fast_percent) — the show keeps up with
	# the beats filled in by themselves.
	var round_seconds: float = BattlePace.real_seconds(GameContent.catalog().pacing().combat_round_seconds)
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var line_seconds: float = feel.battle_line_seconds * _pace_share()
	_line_spacing = minf(line_seconds, round_seconds * 0.9 / float(_line_queue.size()))
	# 战斗拍数 C: the pauses between beats fit in the same nine tenths, scaled down when a
	# round's beats would not; the scene plays at the strip's pace.
	scene_show.pace = _pace_share()
	_pause_scale = 1.0
	var pauses: float = 0.0
	var last: Array = _last_beat.duplicate()
	for line: BattleNarrationLine in _line_queue:
		if line.has_blow and (last.is_empty() or last[0] != line.actor_id or last[1] != line.beat_index):
			pauses += BattlePace.real_seconds(feel.beat_pause_seconds + (feel.scene_windup_seconds if line.tag == CombatMoveTags.HEAVY else 0.0)) * _pace_share()
			last = [line.actor_id, line.beat_index]
	var room: float = round_seconds * 0.9 - _line_spacing * float(_line_queue.size())
	if pauses > 0.0 and pauses > room:
		_pause_scale = maxf(0.0, room / pauses)
	_tell_lines(0.0)


## 战斗拍数 B (DECISIONS「战斗拍数」): the strip plays an actor's first beat of the round in
## full; two or more later beats of theirs told together fold into one line, 「野狗又出两招
## −12 −9」, with the lines it stands for on its hover (and in the log, as ever). A single
## later beat is told as it is. The cast gives the names.
static func fold_beats(lines: Array[BattleNarrationLine], cast: BattlePresentationProjection) -> Array[BattleNarrationLine]:
	var result: Array[BattleNarrationLine] = []
	var index: int = 0
	while index < lines.size():
		var line: BattleNarrationLine = lines[index]
		if line.beat_index <= 1 or line.actor_id.is_empty():
			result.append(line)
			index += 1
			continue
		# The run of later-beat lines of this actor (every line of those beats carries the
		# actor): the blows in it decide the fold.
		var run: Array[BattleNarrationLine] = []
		var blows: Array[BattleNarrationLine] = []
		var actor: StringName = line.actor_id
		while index < lines.size() and lines[index].beat_index > 1 and lines[index].actor_id == actor:
			run.append(lines[index])
			if lines[index].has_blow:
				blows.append(lines[index])
			index += 1
		if blows.size() < 2:
			result.append_array(run)
			continue
		var results := PackedStringArray()
		for blow: BattleNarrationLine in blows:
			results.append(_blow_word(blow))
		# TRANSLATORS: the battle strip's folded line for an actor's later beats of the round: {name} who, {count} how many moves (两 / 三), {results} each blow's −N / 闪 / 挡.
		var text: String = TranslationServer.translate("{name}又出{count}招 {results}").format({"name": TranslationServer.translate(cast.display_name(actor)), "count": _count_word(blows.size()), "results": " ".join(results)})
		result.append(BattleNarrationLine.new(text, -1, blows[0].color).with_beat(blows[0].beat_index).with_folded(run))
	return result


static func _blow_word(blow: BattleNarrationLine) -> String:
	match blow.outcome:
		CombatAttackResult.Outcome.DODGE:
			return TranslationServer.translate(BattleCardStage.FLOAT_DODGE)
		CombatAttackResult.Outcome.PARRY:
			return TranslationServer.translate(BattleCardStage.FLOAT_PARRY)
	return ("−%d" % blow.damage) if blow.has_damage else TranslationServer.translate(BattleCardStage.FLOAT_NOTHING)


static func _count_word(count: int) -> String:
	# TRANSLATORS: the count of moves in a folded battle line: 两 / 三 / 四 / 五, digits beyond.
	var words: Dictionary[int, String] = {2: "两", 3: "三", 4: "四", 5: "五"}
	return TranslationServer.translate(words[count]) if words.has(count) else str(count)


static func _lines_of(entries: Array[BattleFeedbackProjection]) -> Array[BattleNarrationLine]:
	var lines: Array[BattleNarrationLine] = []
	for entry: BattleFeedbackProjection in entries:
		lines.append_array(entry.lines())
	return lines


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
			_shown_mode = -1
			_card_layout_key = ""
			_strip_open = false
			_strip_left = 0.0
			# 战斗拍数 C: the scene's show begins with the fight (the camera a little nearer).
			_last_beat = []
			_paused_for = null
			_earned_told = false
			_round_was_running = false
			var stage_view: WorldVoxelView = _voxel_view()
			scene_show.begin(stage_view, stage_view != null)
			# 战斗演出 B: the panel's parts wait hidden; the opening starts once they are laid out
			# (the next frame). 关 lays the stage at once, now.
			if BattleStageOpening.next_instant(_projection.turns_offered and not _projection.manual):
				_present_participants()
				_start_opening()
			else:
				_opening_pending = true
				for part: Array in _slide_parts():
					(part[0] as Control).modulate.a = 0.0
			if _intent == null:
				_intent = BattleIntentAdapter.new(_session.combat_encounter_coordinator(), _projection.player_id)
			if not visible:
				_yield_world_hud()
				_fade_in()
			show()
		elif not _holding():
			hide()
			_restore_world_hud()
			move_titles.clear()
			scene_show.end()
			opening.close()
			_drop_pending_opening()
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
	_show_mode(_projection.mode)
	if _projection.completion_outcome >= 0:
		_title.text = tr("战斗无法正常结束，不会自动重试。")
		_title.add_theme_font_size_override("font_size", GameTheme.text_size(20))
	# The last order's receipt, and the target, on the title's hover (the gold border shows
	# the target; the receipt says why an order was not taken).
	var hover := PackedStringArray([tr("目标：%s") % tr(_projection.display_name(_projection.current_target_id))])
	if not _receipt.text.is_empty():
		hover.append(_receipt.text)
	_title.tooltip_text = "\n".join(hover)
	# The round's lines first: its blows wait on the cards until they are told.
	if not entries.is_empty():
		log_panel.append_entries(entries)
		# 战斗拍数 B: the frame's entries are queued as one, so later beats of one actor told
		# together fold (fold_beats), each entry still whole in the log.
		_queue_lines(_lines_of(entries))
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
		_strengths[value.participant_id] = BattleStrength.read(map, npc, tr(Es2CombatMessages.pronoun(value.gender)), _projection.mode in [CombatEncounterMode.Value.SPAR, CombatEncounterMode.Value.LESSON])
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
	# is set before the lines: the cards settle and the stamp shows under it). An opening still
	# waiting to begin never will: the panel shows as it is.
	_drop_pending_opening()
	if opening.running():
		opening.skip()
	_final_cards = true
	_held_result = text
	_hold_left = hold
	_hold_shield.visible = true
	_queue_lines(_lines_of(entries))
	if _line_queue.is_empty():
		_settle_final_cards()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	_session.hold_presentation(END_HOLD, true)


func _build() -> void:
	_shade = ColorRect.new()
	_shade.name = "FrozenWorldShade"
	_shade.color = UiPalette.SCRIM_LETHAL
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_content = VBoxContainer.new()
	_content.name = "SafeBattleContent"
	_content.add_theme_constant_override("separation", ROW_GAP)
	_content.minimum_size_changed.connect(_refit_content.call_deferred)
	add_child(_content)
	# 战斗演出 C: the names over heads, over the panel (a head near the cards' foot still shows its
	# name; it stays a moment and goes).
	move_titles = BattleMoveTitles.new()
	move_titles.name = "MoveTitles"
	add_child(move_titles)
	# 战斗演出 A (DECISIONS「战斗演出 A」): the mode at the top in the middle — the brush word,
	# a short rule in the mode's colour, the line under it — then kill_ob()'s warning; the
	# corner's 厮杀 / 目标 lines are gone (the gold border shows the target).
	var head := VBoxContainer.new()
	head.name = "ModeHead"
	head.add_theme_constant_override("separation", 2)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(head)
	_head = head
	_title = Label.new()
	_title.name = "ModeTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_override("font", load(GameTheme.BRUSH_FONT_PATH) as Font)
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(_title)
	_rule = ColorRect.new()
	_rule.name = "ModeRule"
	_rule.custom_minimum_size = RULE_SIZE
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_rule)
	_motto = Label.new()
	_motto.name = "ModeMotto"
	_motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_motto.add_theme_color_override("font_color", UiPalette.MUTED)
	_motto.add_theme_font_size_override("font_size", GameTheme.text_size(14))
	head.add_child(_motto)
	# The panel covers the log the warning was printed to, and the first round's
	# lines would push it out of the recent strip: it stays here instead.
	_warning = Label.new()
	_warning.name = "KillWarning"
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.add_theme_color_override("font_color", SharedGameplayUI.ALERT_COLOR)
	_warning.add_theme_font_size_override("font_size", GameTheme.text_size(16))
	_warning.visible = false
	head.add_child(_warning)
	# The recent strip under the head (owner: the bottom lines took room): one line, the
	# newest; a click opens it to three, over the cards, and it closes by itself. The 战斗记录
	# chip at its end. The strip itself floats (built after the content, placed over its slot).
	var strip_row := HBoxContainer.new()
	strip_row.name = "StripRow"
	strip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	strip_row.add_theme_constant_override("separation", 8)
	_content.add_child(strip_row)
	_strip_row = strip_row
	_strip_slot = Control.new()
	_strip_slot.name = "StripSlot"
	_strip_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip_slot.custom_minimum_size = Vector2(STRIP_WIDTH, STRIP_ROW_HEIGHT)
	strip_row.add_child(_strip_slot)
	log_button = Button.new()
	log_button.name = "CombatLogButton"
	log_button.text = "战斗记录"
	log_button.theme_type_variation = &"ChipButton"
	log_button.custom_minimum_size = Vector2(0, STRIP_ROW_HEIGHT)
	log_button.add_theme_font_size_override("font_size", GameTheme.text_size(14))
	log_button.pressed.connect(_open_log)
	strip_row.add_child(log_button)
	InputGlyphs.decorate(log_button, &"battle_log")
	# The cards: one row while they fit (4 at most), else the player's side on the left and
	# the enemies on the right, two big cards a side at most and the rest as chips under them.
	_card_area = VBoxContainer.new()
	_card_area.name = "CardArea"
	_card_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_area.resized.connect(_fit_cards)
	_content.add_child(_card_area)
	_participants = HBoxContainer.new()
	_participants.name = "CardRow"
	_participants.alignment = BoxContainer.ALIGNMENT_CENTER
	_participants.add_theme_constant_override("separation", CARD_GAP)
	_card_area.add_child(_participants)
	_sides = HBoxContainer.new()
	_sides.name = "CardSides"
	_sides.add_theme_constant_override("separation", SIDE_GAP)
	_sides.visible = false
	_card_area.add_child(_sides)
	for side: int in 2:
		var column := VBoxContainer.new()
		column.name = "Ours" if side == 0 else "Theirs"
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", SIDE_CARD_GAP)
		_sides.add_child(column)
		var big := HBoxContainer.new()
		big.name = "Big"
		big.alignment = BoxContainer.ALIGNMENT_BEGIN if side == 0 else BoxContainer.ALIGNMENT_END
		big.add_theme_constant_override("separation", SIDE_CARD_GAP)
		column.add_child(big)
		var chips := HBoxContainer.new()
		chips.name = "Chips"
		chips.alignment = big.alignment
		chips.add_theme_constant_override("separation", SIDE_CARD_GAP)
		column.add_child(chips)
		_side_rows.append([big, chips])
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
	action_panel.yield_requested.connect(_yield_round)
	_content.add_child(action_panel)
	_receipt = Label.new()
	_receipt.name = "IntentReceipt"
	_receipt.visible = false # Its text goes to the title's hover, not an extra narrow-screen row.
	_receipt.add_theme_font_size_override("font_size", GameTheme.text_size(14))
	_content.add_child(_receipt)
	_strip = PanelContainer.new()
	_strip.name = "RecentStrip"
	var strip_style := StyleBoxFlat.new()
	# Open, the strip lies over the cards: nearly opaque so their rows do not read through.
	strip_style.bg_color = UiPalette.SCRIM
	strip_style.content_margin_left = 10
	strip_style.content_margin_right = 10
	strip_style.content_margin_top = 1
	strip_style.content_margin_bottom = 1
	_strip.add_theme_stylebox_override("panel", strip_style)
	_strip.gui_input.connect(_strip_input)
	add_child(_strip)
	_recent = VBoxContainer.new()
	_recent.name = "RecentFeedback"
	_recent.add_theme_constant_override("separation", 0)
	_recent.mouse_filter = Control.MOUSE_FILTER_PASS
	_strip.add_child(_recent)
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
		line.add_theme_font_size_override("normal_font_size", GameTheme.text_size(16))
		# Plain battle text a light grey, so HIW lines stand out.
		line.add_theme_color_override("default_color", SharedGameplayUI.PLAIN_LOG_COLOR)
		# 战斗拍数 B: a folded line opens the log (its hover already lists what it stands for).
		line.gui_input.connect(_recent_input.bind(index))
		row.add_child(line)
	end_stamp = Label.new()
	end_stamp.name = "EndStamp"
	end_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_stamp.visible = false
	end_stamp.rotation = deg_to_rad(-8.0)
	end_stamp.add_theme_font_size_override("font_size", 120)
	# 界面重做 4: 胜 / 败 in the title's brush hand.
	end_stamp.add_theme_font_override("font", load(GameTheme.BRUSH_FONT_PATH) as Font)
	end_stamp.add_theme_color_override("font_color", BattleCardStage.STAMP_RED)
	end_stamp.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.08, 0.9))
	end_stamp.add_theme_constant_override("outline_size", 8)
	add_child(end_stamp)
	scene_show = BattleSceneShow.new()
	scene_show.name = "SceneShow"
	add_child(scene_show)
	opening = BattleStageOpening.new()
	opening.name = "StageOpening"
	opening.finished.connect(_opening_finished)
	add_child(opening)
	sounds = BattleSounds.new()
	sounds.name = "Sounds"
	add_child(sounds)
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
	var short: bool = not metrics.touch_sized() and metrics.content_rect().size.y < ApplicationShellLayout.SHORT_HEIGHT
	_content.add_theme_constant_override("separation", SHORT_ROW_GAP if short else ROW_GAP)
	# 战斗拍数 B: the panel closes up on any screen under SHORT_HEIGHT (a desktop 16:9 at 150%
	# is 480 high and counts as compact for the touch rule), not only a non-touch one.
	var compact: bool = metrics.content_rect().size.y < ApplicationShellLayout.SHORT_HEIGHT
	action_panel.set_compact(compact)
	# 战斗演出 A: a short screen takes a smaller title and lower cards; the motto stays.
	_compact = compact
	_title.add_theme_font_size_override("font_size", SHORT_TITLE_SIZE if compact else TITLE_SIZE)
	# The short screen drops the line under the title (the word and its colour say the mode).
	_motto.visible = not _motto.text.is_empty() and not compact
	_strip_slot.custom_minimum_size.x = minf(STRIP_WIDTH, metrics.content_rect().size.x - 200.0)
	_room_width = metrics.content_rect().size.x
	_content.position = metrics.content_rect().position
	_content.size = metrics.content_rect().size
	log_panel.apply_metrics(metrics)
	_fit_cards()


func _refit_content() -> void:
	# Initial text/container minimums can temporarily grow the Control. Restore the
	# same SafeArea bounds after native layout converges, without a second sampler.
	if not is_inside_tree() or not is_instance_valid(_safe):
		return
	var metrics: SafeAreaMetrics = _safe.current_metrics()
	if metrics != null:
		_content.position = metrics.content_rect().position
		_content.size = metrics.content_rect().size


## 战斗演出 A (DECISIONS「战斗演出 A」): every card is one size — CARD_HEIGHT high (lower on a
## short screen), as wide as the row shares out between CARD_MIN and CARD_MAX. While they fit
## (ROW_CARDS at most) they stand in one row in the middle; past that the player's side stands
## on the left and the enemies on the right, SIDE_BIG big cards a side at most (the current
## target and one held for 了结 / 放过 first) and the rest as chips (name and 气) under them, as
## many as fit; the others have no card (换目标 still reaches them).
const CARD_MIN: float = 300.0
const CARD_MAX: float = 440.0
const CARD_GAP: int = 16
const CARD_HEIGHT: float = 150.0
const SHORT_CARD_HEIGHT: float = 136.0
const ROW_CARDS: int = 4
const SIDE_BIG: int = 2
const SIDE_GAP: int = 16
const SIDE_CARD_GAP: int = 8
## The head: the mode's word (brush), the rule under it.
const TITLE_SIZE: int = 56
const SHORT_TITLE_SIZE: int = 40
const RULE_SIZE: Vector2 = Vector2(120, 3)
## The recent strip: its width at most, its row's height, how long it stays open untouched.
const STRIP_WIDTH: float = 760.0
const STRIP_ROW_HEIGHT: float = 28.0
const STRIP_OPEN_SECONDS: float = 5.0


func _fit_cards() -> void:
	if _cards.is_empty() or _participants == null or _card_area == null:
		return
	# The safe area's width, not the area's own (the cards' minimum widths would hold it wide).
	var room: float = _room_width if _room_width > 0.0 else _card_area.size.x
	if room <= 0.0:
		return
	var height: float = SHORT_CARD_HEIGHT if _compact else CARD_HEIGHT
	var visible_cards: int = _cards.size()
	var in_row: int = mini(ROW_CARDS, int(floorf((room + CARD_GAP) / (CARD_MIN + CARD_GAP))))
	var placement: Array = [] # [card, row, chip] each
	if visible_cards <= in_row:
		_participants.visible = true
		_sides.visible = false
		# Whole units: at a 界面缩放 of 150% two cards would each be 402.5, laid out as 403.
		var each: float = floorf(clampf((room - CARD_GAP * (visible_cards - 1)) / float(visible_cards), CARD_MIN, CARD_MAX))
		for card: BattleParticipantCard in _cards:
			placement.append([card, _participants, false])
			card.custom_minimum_size = Vector2(each, height)
	else:
		_participants.visible = false
		_sides.visible = true
		var side_room: float = floorf((room - SIDE_GAP) / 2.0)
		var big_count: int = clampi(int(floorf((side_room + SIDE_CARD_GAP) / (CARD_MIN + SIDE_CARD_GAP))), 1, SIDE_BIG)
		var chip_count: int = maxi(1, int(floorf((side_room + SIDE_CARD_GAP) / (BattleParticipantCard.CHIP_SIZE.x + SIDE_CARD_GAP))))
		var each: float = floorf(clampf((side_room - SIDE_CARD_GAP * (big_count - 1)) / float(big_count), CARD_MIN, CARD_MAX))
		for side: int in 2:
			var members: Array[BattleParticipantCard] = _side_cards(side)
			var big: Array[BattleParticipantCard] = []
			for card: BattleParticipantCard in _big_first(members):
				if big.size() < big_count:
					big.append(card)
			var chips: int = 0
			for card: BattleParticipantCard in members:
				if big.has(card):
					placement.append([card, _side_rows[side][0], false])
					card.custom_minimum_size = Vector2(each, height)
				elif chips < chip_count:
					chips += 1
					placement.append([card, _side_rows[side][1], true])
					card.custom_minimum_size = BattleParticipantCard.CHIP_SIZE
				else:
					placement.append([card, null, true])
	_place_cards(placement)


## The cards of the player's side (0: the player and those beside them) or the enemies' (1),
## in the cards' order.
func _side_cards(side: int) -> Array[BattleParticipantCard]:
	var members: Array[BattleParticipantCard] = []
	for index: int in mini(_cards.size(), _shown_participants.size()):
		var value: BattleParticipantProjection = _projection.participant(_shown_participants[index])
		var hostile: bool = value != null and value.hostile_to_player
		if (side == 1) == hostile:
			members.append(_cards[index])
	return members


## `members` with the ones a big card goes to first: the current target, one held for 了结 /
## 放过, the player; then the rest in order.
func _big_first(members: Array[BattleParticipantCard]) -> Array[BattleParticipantCard]:
	var first: Array[BattleParticipantCard] = []
	var rest: Array[BattleParticipantCard] = []
	for card: BattleParticipantCard in members:
		var id: StringName = card.participant_id()
		var value: BattleParticipantProjection = _projection.participant(id)
		if id == _projection.current_target_id or id == _projection.player_id or (value != null and value.knockout != null):
			first.append(card)
		else:
			rest.append(card)
	first.append_array(rest)
	return first


## Each card into its row (null: no card shown) in `placement`'s order, as a chip or big; a
## card that moves keeps the focus it had.
func _place_cards(placement: Array) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var counts: Dictionary = {}
	for entry: Array in placement:
		var card: BattleParticipantCard = entry[0]
		var row: Container = entry[1]
		card.set_chip(entry[2])
		if row == null:
			card.visible = false
			continue
		card.visible = true
		var at: int = counts.get(row, 0)
		counts[row] = at + 1
		if card.get_parent() != row:
			var had_focus: bool = focused != null and card.is_ancestor_of(focused)
			if card.get_parent() != null:
				card.get_parent().remove_child(card)
			row.add_child(card)
			if had_focus:
				FocusNav.give(card.target_button)
		if card.get_index() != at:
			row.move_child(card, at)
		card.size_flags_horizontal = Control.SIZE_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


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
		# 战斗演出 D: one who joined gets a place on the raised stage.
		var sides: Array = _fighters(_active_map())
		opening.seat(sides[0], sides[1])
		for card: BattleParticipantCard in _cards:
			if card.get_parent() != null:
				card.get_parent().remove_child(card)
			card.queue_free()
		_cards.clear()
		for id: StringName in ids:
			var card := BattleParticipantCard.new()
			card.name = "Participant%d" % _cards.size()
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
	# Where each card stands (a new target or one held for the choice takes a big card).
	var key: String = "%s|%s|%s" % [ids, _projection.current_target_id, _held_ids(values)]
	if key != _card_layout_key:
		_card_layout_key = key
		_fit_cards()
	# 战斗拍数 C: where the figures stand (close or apart), and home again between rounds.
	var stances: Array = []
	for value: BattleParticipantProjection in values:
		stances.append([value.participant_id, value.current_target_id, value.close])
	scene_show.settle(stances)
	if _projection.round_running:
		_round_was_running = true
	elif _round_was_running and told:
		# Home again once the round's last lines are told, not before.
		_round_was_running = false
		scene_show.round_over()


## The ids of those held for 了结 / 放过 now.
static func _held_ids(values: Array[BattleParticipantProjection]) -> Array[StringName]:
	var held: Array[StringName] = []
	for value: BattleParticipantProjection in values:
		if value.knockout != null:
			held.append(value.participant_id)
	return held


## 战斗演出 A: the strip over its slot under the head, as wide as the slot and as tall as its
## lines; open, it reaches down over the cards. Followed each frame while the panel shows and
## set only when it moved (a signal from the slot's rect fed a layout loop while sessions were
## built off screen).
func _place_strip() -> void:
	if _strip == null or _strip_slot == null or not _strip_slot.is_inside_tree():
		return
	var slot: Rect2 = _strip_slot.get_global_rect()
	var wanted := Rect2(slot.position - get_global_rect().position, Vector2(slot.size.x, _strip.get_combined_minimum_size().y))
	if not _strip.get_rect().is_equal_approx(wanted):
		_strip.position = wanted.position
		_strip.size = wanted.size


## Whether the strip shows its three lines (else the newest alone).
func strip_open() -> bool:
	return _strip_open


func _set_strip_open(open: bool) -> void:
	_strip_open = open
	_strip_left = STRIP_OPEN_SECONDS if open else 0.0
	_present_recent(_told)


## A click on the strip: a folded line opens the log (战斗拍数 B); otherwise the strip opens
## to three lines, or closes.
func _strip_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_set_strip_open(not _strip_open)
	accept_event()


func _present_recent(lines: Array[BattleNarrationLine]) -> void:
	# Closed, the strip shows the newest line alone (the rows keep their lines).
	var newest: int = mini(lines.size(), _recent.get_child_count()) - 1
	for index: int in _recent.get_child_count():
		var row: Control = _recent.get_child(index)
		row.visible = _strip_open or index == maxi(newest, 0)
		var line: BattleNarrationLine = lines[index] if index < lines.size() else null
		var text: RichTextLabel = row.get_node("Text")
		if line == null:
			text.text = ""
			text.tooltip_text = ""
			continue
		# DECISIONS「战斗界面」: a blow's short form in the strip, ES2's line on hover; a folded
		# line's hover lists the lines it stands for.
		var shown: BattleNarrationLine = BattleNarrationLine.new(line.summary, -1, line.color) if line.has_summary else line
		text.text = _fitted(shown, text, text.size.x).rich_text()
		if line.is_folded:
			var texts := PackedStringArray()
			for inner: BattleNarrationLine in line.folded:
				texts.append(inner.text + ((" " + tr("（-%d）") % inner.damage) if inner.has_damage else ""))
			text.tooltip_text = "\n".join(texts)
		else:
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
	var budget: float = width - font.get_string_size(damage, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x - 4.0
	if font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= budget:
		return line
	var words: String = line.text
	while words.length() > 1 and font.get_string_size(words + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > budget:
		words = words.left(words.length() - 1)
	return BattleNarrationLine.new(words + "…", line.damage, line.color)


## A click on a folded strip line opens the log, where every beat's line stands.
func _recent_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if index < _told.size() and _told[index].is_folded:
		_open_log()
	else:
		_set_strip_open(not _strip_open)


## 战斗演出 A (DECISIONS「战斗演出 A」): the head and the shade in `mode`'s look (a 切磋 that
## turns into a 死斗 changes with it).
func _show_mode(mode: int) -> void:
	if mode == _shown_mode and _projection.completion_outcome < 0:
		return
	# A 切磋 that turns 死斗 mid-fight: the stage restained and the shade deepening with it.
	var turned: bool = _shown_mode >= 0 and BattleModeLook.friendly(_shown_mode) and not BattleModeLook.friendly(mode)
	_shown_mode = mode
	var look: BattleModeLook = BattleModeLook.of(mode)
	_title.text = tr(look.title)
	_title.add_theme_font_size_override("font_size", SHORT_TITLE_SIZE if _compact else TITLE_SIZE)
	_title.add_theme_color_override("font_color", look.title_color)
	_title.add_theme_constant_override("outline_size", 6 if look.outlined else 0)
	_rule.color = look.accent
	_motto.text = tr(look.motto)
	_motto.visible = not look.motto.is_empty() and not _compact
	if _shade_tween != null and _shade_tween.is_valid():
		_shade_tween.kill()
	if turned:
		opening.restyle(mode)
		_shade_tween = create_tween()
		_shade_tween.tween_property(_shade, "color", look.scrim, BattlePace.real_seconds(GameContent.catalog().pacing().feel.arena_restyle_seconds) * 0.7)
	else:
		_shade.color = look.scrim


## 战斗演出 B: the panel's parts as the opening slides them in — [part, from offset, delay share]:
## the title from above, then the strip and the cards (down), the hints and the panel (up).
func _slide_parts() -> Array:
	return [
		[_head, Vector2(0, -30), 0.0], [_strip_row, Vector2(0, -24), 0.12], [_strip, Vector2.ZERO, 0.12],
		[_card_area, Vector2(0, -24), 0.18], [target_hints, Vector2(0, 40), 0.3], [action_panel, Vector2(0, 40), 0.3],
	]


## The opening (战斗演出 B), once the panel is laid out: the fighters where their bodies stand,
## the band between the cards and the panel, the parts to slide; under 自动 the short one.
func _start_opening() -> void:
	var map := _active_map()
	var sides: Array = _fighters(map)
	opening.open(_voxel_view(), map, sides[0], _projection.player_id, sides[1], _projection.mode, _stage_band(), _slide_parts(), _projection.turns_offered and not _projection.manual)


func _active_map() -> WorldMapController:
	return _session.active_map() as WorldMapController if _session != null and _session.is_initialized() else null


## 战斗演出 D: [each fighter's 2D point by id, those on the other side (the player's target first)].
func _fighters(map: WorldMapController) -> Array:
	var fighters: Dictionary[StringName, Vector2] = {}
	var foes: Array[StringName] = []
	if map != null:
		for value: BattleParticipantProjection in _projection.participants():
			var body: Node2D = map.player_body if value.participant_id == _projection.player_id else map.runtime_body_for_character(value.participant_id)
			if body == null:
				continue
			fighters[value.participant_id] = body.global_position
			if value.hostile_to_player and value.participant_id != _projection.player_id:
				if value.participant_id == _projection.current_target_id:
					foes.push_front(value.participant_id)
				else:
					foes.append(value.participant_id)
	return [fighters, foes]


## The share of the screen's height between the cards' foot and the panel's top (where the
## fighters should stand), as (top, bottom).
func _stage_band() -> Vector2:
	var height: float = get_viewport_rect().size.y
	if height <= 0.0:
		return DEFAULT_BAND
	var top: float = _card_area.get_global_rect().position.y
	for card: BattleParticipantCard in _cards:
		if card.visible:
			top = maxf(top, card.get_global_rect().end.y)
	var bottom: float = target_hints.get_global_rect().position.y if target_hints.visible else action_panel.get_global_rect().position.y
	# Not laid out yet (关 starts at once): where the band stands on a 16:9 screen.
	if bottom - top < height * 0.1:
		return DEFAULT_BAND
	return Vector2(top / height, bottom / height)


## The band the fighters stand in before the panel is laid out: under the cards, over the panel.
const DEFAULT_BAND: Vector2 = Vector2(0.42, 0.7)


## A fight over before its opening began: the panel's parts shown again (they waited hidden).
func _drop_pending_opening() -> void:
	if not _opening_pending:
		return
	_opening_pending = false
	for part: Array in _slide_parts():
		(part[0] as Control).modulate.a = 1.0


func _opening_finished() -> void:
	if _projection.active:
		_present_participants()
		_tell_lines(0.0)
		_focus_battle()


## The look the head shows now (tests, kits): the mode it was made for.
func shown_mode() -> int:
	return _shown_mode


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


## 战斗决策层 1B: the move for this round (the round runs on it). 战斗拍数 C: the clap of the
## beat as it is pressed.
func _choose_move(action_id: StringName) -> void:
	if not _projection.active or _session == null or not _session.is_initialized():
		return
	if _session.combat_encounter_coordinator().choose_attack(action_id):
		sounds.play(BattleSounds.CLAPPER)
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


## 战斗拍数 B: 收势 — the beats left this round given up; the round goes on.
func _yield_round() -> void:
	if not _projection.active or _session == null or not _session.is_initialized():
		return
	if _session.combat_encounter_coordinator().yield_round():
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
	action_panel.focus_quietly(first if first != null else log_button)


func _yield_world_hud() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	_saved_focus = weakref(focus) if focus != null else null
	if focus != null:
		focus.release_focus()
	_yielded_hud = _session.shared_ui()
	if _yielded_hud != null:
		_hud_was_visible = _yielded_hud.visible
		_yielded_hud.hide()


## The voxel view of the map the fight is on (null: no scene to show the fight in).
func _voxel_view() -> WorldVoxelView:
	if _session == null or not _session.is_initialized():
		return null
	var map := _session.active_map() as WorldMapController
	return null if map == null else map.get_node_or_null("MapView") as WorldVoxelView


func _restore_world_hud() -> void:
	if is_instance_valid(_yielded_hud):
		_yielded_hud.visible = _session.can_process() and not _session.is_restore_candidate_staged() and _session.application_gameplay_allows_encounter_advance()
	_yielded_hud = null
	if _saved_focus != null:
		FocusNav.give(_saved_focus.get_ref() as Control)
	_saved_focus = null
