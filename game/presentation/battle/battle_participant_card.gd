class_name BattleParticipantCard
extends PanelContainer

signal target_requested(participant_id: StringName)
## DECISIONS「了结 / 放过」: the player's choice for one who fell.
signal finish_requested(participant_id: StringName)
signal spare_requested(participant_id: StringName)

# TRANSLATORS: the battle card of one who fell while the player was killing them: the button that kills them with the next blow.
const FINISH_LABEL: String = "了结"
# TRANSLATORS: the battle card of one who fell: the button that lets them live (the player's side strikes them no more).
const SPARE_LABEL: String = "放过"
## An enemy the player cannot pick now (DECISIONS「战斗界面」): the whole card dimmed.
const DIM: Color = Color(0.55, 0.55, 0.55)
const GOLD: Color = Color("efc77b")

var target_button: Button
var _participant_id: StringName
var _ordinary_border: StyleBoxFlat
var _current_border: StyleBoxFlat

var _title: Label
var _vitality: BattleVitalityBar
## Who the card showed and their 气 then: the bar moves and the card flashes from it
## (DECISIONS「手感」: bar_tween_ms, hit_flash_ms, the setting 受击闪红).
var _shown_id: StringName = &""
var _shown_vitality: int = -1
## 气, 精 and 神 as last shown (held while a blow's line waits to be told).
var _shown_resources: Array[BattleResourceProjection] = []
var _bar: Tween
var _flash: Tween
const HIT_COLOR: Color = Color(1.0, 0.45, 0.42)
## 战斗决策层 3 (DECISIONS「战斗演出」): the show over the card (BattleCardStage), the
## sideways shake by the band of the blow (px), the fall (the card sinks and tilts), the
## 起手 / 要出 line's flash when it changes, the border's gold flash for a special.
var stage: BattleCardStage
const SHAKE_PX: Dictionary[int, float] = {
	BattleVitalityBar.Band.UNHURT: 2.0, BattleVitalityBar.Band.LIGHT: 4.0,
	BattleVitalityBar.Band.HEAVY: 6.0, BattleVitalityBar.Band.DYING: 8.0,
}
const FALL_SINK: float = 10.0
const FALL_TILT_DEGREES: float = 3.0
const INTENT_COLOR: Color = Color("f2d27a")
const INTENT_FLASH: Color = Color("fff3c4")
const TELEGRAPH_FLASH: Color = Color("ffffff")
const SPECIAL_BORDER_SECONDS: float = 0.3
var _shake: Tween
var _fall: Tween
var _intent_pulse: Tween
var _border_flash: Tween
var _special_border: StyleBoxFlat
var _rest_x: float = 0.0
## The 倒 / 亡 stamp on the card as last presented ("" while its fighter stands).
var _fallen_text: String = ""
var _shown_intent: String = ""
## 气 N/N/N; 精 · 神 (the player's card); 内力 (· 法力 · 灵力) (the player's card).
var _primary: Label
var _secondary: Label
var _powers: Label
## 战斗决策层 2: the one-word tags — 忙 N, the conditions, 昏迷 / 死亡 — and nothing when
## there is nothing to say.
var _status: Label
## 战斗决策层 1B: the enemy's 起手 (the tag of its next move) and the special it announced.
var _intent: Label
## 了结 / 放过, shown while the one on the card waits on the player's choice.
var choice_row: HBoxContainer
var finish_button: Button
var spare_button: Button


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ordinary_border = StyleBoxFlat.new()
	_ordinary_border.bg_color = Color("182833")
	_ordinary_border.border_color = Color("405563")
	_ordinary_border.set_border_width_all(1)
	_ordinary_border.content_margin_left = 10
	_ordinary_border.content_margin_right = 10
	_current_border = _ordinary_border.duplicate() as StyleBoxFlat
	_current_border.border_color = GOLD
	_current_border.set_border_width_all(3)
	_special_border = _ordinary_border.duplicate() as StyleBoxFlat
	_special_border.border_color = Color("fff3c4")
	_special_border.set_border_width_all(3)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	add_child(content)
	_title = _label(content)
	_title.add_theme_color_override("font_color", GOLD)
	_vitality = BattleVitalityBar.new()
	_vitality.name = "Vitality"
	content.add_child(_vitality)
	_primary = _label(content)
	_secondary = _label(content)
	_powers = _label(content)
	_status = _label(content)
	_intent = _label(content)
	_intent.add_theme_color_override("font_color", Color("f2d27a"))
	_intent.visible = false
	choice_row = HBoxContainer.new()
	choice_row.name = "KnockoutChoice"
	choice_row.add_theme_constant_override("separation", 8)
	choice_row.visible = false
	content.add_child(choice_row)
	finish_button = _choice_button("FinishButton")
	finish_button.pressed.connect(func() -> void: finish_requested.emit(_participant_id))
	spare_button = _choice_button("SpareButton")
	spare_button.pressed.connect(func() -> void: spare_requested.emit(_participant_id))
	stage = BattleCardStage.new()
	stage.name = "Stage"
	add_child(stage)
	target_button = Button.new()
	target_button.name = "SelectTarget"
	target_button.custom_minimum_size = Vector2(64, 64)
	for style: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		target_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("75d9ee") # Cyan input focus != gold authoritative target.
	focus.set_border_width_all(2)
	target_button.add_theme_stylebox_override("focus", focus)
	target_button.pressed.connect(_request_target)
	add_child(target_button) # Native focus/touch overlay; no extra narrow-screen row.


## `hold_resources`: 气, 精 and 神 stay as shown (the blow's line is not told yet).
## DECISIONS「战斗界面」: the player's card carries every track; an enemy's its 气 bar, its
## name with the forecast's word, its tags and its 起手 / 要出; the current target is the gold
## border, an enemy that cannot be picked is dimmed; the hover explains the tags.
func present(value: BattleParticipantProjection, player_id: StringName, current_id: StringName, queued_id: StringName = &"", hold_resources: bool = false) -> void:
	if value.participant_id != _shown_id:
		_reset_show()
	_participant_id = value.participant_id
	var is_player: bool = value.participant_id == player_id
	var knockout: BattleKnockoutProjection = value.knockout
	target_button.disabled = not value.targetable
	var role: String
	if is_player:
		# TRANSLATORS: the player's own battle card, after the name.
		role = tr("你")
	elif value.hostile_to_player:
		# An enemy: the forecast's word (稳赢 … 必败) when the panel read one, else 对手.
		role = CombatForecast.verdict_word(value.strength) if value.strength >= 0 else tr("对手")
	else:
		# TRANSLATORS: the battle card of one fighting beside the player (a 天将, a follower).
		role = tr("参战")
	_title.text = "%s · %s" % [tr(value.display_name), role]
	_title.tooltip_text = value.strength_line if not value.strength_line.is_empty() else _title.text
	var border: StyleBoxFlat = _current_border if value.participant_id == current_id else _ordinary_border
	if get_theme_stylebox("panel") != border and (_border_flash == null or not _border_flash.is_valid()):
		add_theme_stylebox_override("panel", border)
	modulate = DIM if value.hostile_to_player and not value.targetable and knockout == null else Color.WHITE
	if not hold_resources or value.participant_id != _shown_id or _shown_resources.is_empty():
		_show_resources(value.participant_id, [value.vitality, value.essence, value.spirit])
	_primary.tooltip_text = "当前／有效／上限"
	_secondary.visible = is_player
	_powers.visible = is_player
	if is_player:
		var powers: Dictionary = {
			"force": value.force.current, "max_force": value.force.maximum, "factor": value.force_factor,
			"mana": value.mana.current, "max_mana": value.mana.maximum,
			"atman": value.atman.current, "max_atman": value.atman.maximum,
		}
		if value.has_spells or value.mana.maximum > 0:
			# TRANSLATORS: the player's card; (+{factor}) is enforce.c's force_factor, as hp.c shows it; 法力 and 灵力 only with spells.
			_powers.text = tr("内力 {force}/{max_force} (+{factor}) · 法力 {mana}/{max_mana} · 灵力 {atman}/{max_atman}").format(powers)
		else:
			# TRANSLATORS: the player's card without spells: 内力 alone; (+{factor}) is enforce.c's force_factor.
			_powers.text = tr("内力 {force}/{max_force} (+{factor})").format(powers)
		_powers.tooltip_text = _powers.text
	# The tags: 忙 N, the conditions, then 昏迷 / 死亡 (and when they come to); 无法行动 only
	# when none of those says why.
	var states := PackedStringArray()
	if value.participant_id == queued_id:
		# The planned action's target when it is not the current one (the gold border).
		states.append(tr("已排定目标"))
	if value.busy_value != 0:
		# TRANSLATORS: a battle card's tag: busy for %d more beats.
		states.append(tr("忙 %d") % value.busy_value)
	states.append_array(BattleConditionTags.labels(value.conditions))
	var dead: bool = value.life_status == CombatSliceLifeStatus.Value.DEAD or value.threshold == CharacterState.LifeThreshold.DEAD
	var unconscious: bool = value.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS or value.threshold == CharacterState.LifeThreshold.UNCONSCIOUS
	if dead:
		states.append(tr("死亡"))
	elif unconscious:
		states.append(tr("昏迷"))
	if knockout != null:
		states.append(tr("约 {n} 秒后醒来").format({"n": knockout.revive_seconds}))
	if not value.available and value.busy_value == 0 and not dead and not unconscious:
		states.append(tr("无法行动"))
	_status.text = " · ".join(states)
	var explained := PackedStringArray(BattleConditionTags.descriptions(value.conditions))
	_status.tooltip_text = "\n".join(explained)
	var intents := PackedStringArray()
	if value.next_move_guard:
		# TRANSLATORS: an enemy's card: it will guard on its next beat (combatd.c fight()'s courage gate) instead of a move.
		intents.append(tr("起手：守势"))
		# TRANSLATORS: hover of 起手：守势: a guarding fighter ripostes when the other misses.
		explained.append(tr("守势：它在等你打空，打空了就反击。"))
	elif not value.next_move_tag.is_empty() and not value.next_move_known:
		# TRANSLATORS: an enemy's card: its next move's tag is not read yet (识招: not watched enough).
		intents.append(tr("起手：？"))
		# TRANSLATORS: hover of 起手：？.
		explained.append(tr("还没看熟这一招。"))
	elif not value.next_move_tag.is_empty():
		# TRANSLATORS: an enemy's card: the tag of the move it will use next (起手式): 快 / 重 / 虚 / 守.
		intents.append(tr("起手：%s") % CombatMoveTags.label(value.next_move_tag))
		explained.append(CombatMoveTags.description(value.next_move_tag))
		var weakness: StringName = MoveRecognition.weakness(value.next_move_tag)
		if not weakness.is_empty():
			# TRANSLATORS: hover of 起手：<tag>: the tag on the counter ring that beats it ({tag} 快 / 重 / 虚 / 守).
			explained.append(tr("破绽：{tag}招可破。").format({"tag": CombatMoveTags.label(weakness)}))
	if not value.telegraph.is_empty():
		# TRANSLATORS: an enemy's card: the special it announced for its next move ({move} carries its own 「」 when it has one).
		intents.append(tr("要出 {move}").format({"move": value.telegraph}))
	_intent.text = " · ".join(intents)
	_intent.visible = value.hostile_to_player
	if _intent.visible and _intent.text != _shown_intent:
		_pulse_intent(not value.telegraph.is_empty())
	_shown_intent = _intent.text if _intent.visible else ""
	# The fall: 倒 for one unconscious (or held for the choice), 亡 for one dead; lifted when
	# they are up again.
	var fallen: String = ""
	if dead:
		fallen = tr(BattleCardStage.STAMP_DEAD)
	elif unconscious or knockout != null:
		fallen = tr(BattleCardStage.STAMP_UNCONSCIOUS)
	if fallen != _fallen_text:
		_show_fallen(fallen)
	# The card's one hover (the target button covers it): what picking it does, the forecast,
	# the tags' meanings.
	var hover := PackedStringArray()
	if value.targetable:
		hover.append(tr("选为目标：%s") % tr(value.display_name))
	if not value.strength_line.is_empty():
		hover.append(value.strength_line)
	hover.append_array(explained)
	target_button.tooltip_text = "\n".join(hover)
	_present_choice(value, knockout)


## The card of one held for the player's choice: 了结 (marked when it does 朱鸿雪's task or
## kills the player's master) and 放过 in place of picking the card as a target.
func _present_choice(value: BattleParticipantProjection, knockout: BattleKnockoutProjection) -> void:
	choice_row.visible = knockout != null
	# The card's own button covers it: away while the choice shows (one held is no target).
	target_button.visible = knockout == null
	if knockout == null:
		return
	var name: String = tr(value.display_name)
	var marks := PackedStringArray()
	if knockout.quest_target:
		# TRANSLATORS: on the 了结 button: killing them does the task 朱鸿雪 gave.
		marks.append(tr("任务目标"))
	if knockout.own_master:
		# TRANSLATORS: on the 了结 button: they are the player's own master (killing them leaves the family).
		marks.append(tr("弑师"))
	# TRANSLATORS: the 了结 button with what killing them means: {marks} is 任务目标 and/or 弑师.
	finish_button.text = tr(FINISH_LABEL) if marks.is_empty() else tr("了结（{marks}）").format({"marks": tr("、").join(marks)})
	# TRANSLATORS: hover on 了结: {name} lies unconscious; the next blow of the player's side (theirs or what they called) kills them.
	finish_button.tooltip_text = tr("了结{name}：下一招就会要了{name}的命。").format({"name": name})
	spare_button.text = tr(SPARE_LABEL)
	# TRANSLATORS: hover on 放过: nobody on the player's side strikes {name} again; they lie there and come to on their own.
	spare_button.tooltip_text = tr("放{name}一条生路：你这一方不再出手，{name}昏在原地，到时自己醒来。").format({"name": name})


## `band`: the blow's band for the shake (-1: the band of the value shown).
func _show_vitality(id: StringName, current: int, band: int = -1) -> void:
	var same: bool = id == _shown_id
	var lost: bool = same and current < _shown_vitality
	var moved: bool = not same or current != _shown_vitality
	_shown_id = id
	_shown_vitality = current
	if not moved:
		return
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if _bar != null and _bar.is_valid():
		_bar.kill()
	if same and feel.bar_tween_seconds > 0.0:
		_bar = create_tween()
		_bar.tween_property(_vitality, "value", float(current), feel.bar_tween_seconds)
	else:
		_vitality.value = current
	if not lost:
		return
	if BattlePace.hit_flash and feel.hit_flash_seconds > 0.0:
		if _flash != null and _flash.is_valid():
			_flash.kill()
		self_modulate = HIT_COLOR
		_flash = create_tween()
		_flash.tween_property(self, "self_modulate", Color.WHITE, feel.hit_flash_seconds)
	_shake_by(band if band >= 0 else BattleVitalityBar.band(current, roundi(_vitality.max_value)))


## DECISIONS「战斗演出」: one line told, as it concerns this card — the attacker's: the
## move's name (a special's in gold, larger); the one hit's: the bar stepping down by the
## blow (a presentation estimate, settled to the projection once the round's lines are told),
## the −N / 闪 / 挡 float, the flash and the shake by the band.
func show_line(line: BattleNarrationLine) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if line.is_special and line.actor_id == _shown_id:
		stage.show_title(line.special_title, true, feel.special_title_seconds)
		_flash_border()
	elif line.has_blow and line.actor_id == _shown_id and not line.move.is_empty():
		stage.show_title(line.move, false, feel.move_title_seconds)
	if not line.has_blow or line.target_id != _shown_id:
		return
	var from_y: float = _vitality.position.y + _vitality.size.y
	match line.outcome:
		CombatAttackResult.Outcome.DODGE:
			stage.show_float(tr(BattleCardStage.FLOAT_DODGE), BattleCardStage.GREY, from_y, false, feel.damage_float_seconds)
		CombatAttackResult.Outcome.PARRY:
			stage.show_float(tr(BattleCardStage.FLOAT_PARRY), BattleCardStage.GREY, from_y, false, feel.damage_float_seconds)
		CombatAttackResult.Outcome.HIT:
			if not line.has_damage:
				stage.show_float(tr(BattleCardStage.FLOAT_NOTHING), BattleCardStage.GREY, from_y, false, feel.damage_float_seconds)
				return
			var band: int = line.band if line.band >= 0 else BattleVitalityBar.band(maxi(0, _shown_vitality - line.damage), roundi(_vitality.max_value))
			stage.show_float("−%d" % line.damage, BattleVitalityBar.BAND_COLORS[band], from_y, true, feel.damage_float_seconds)
			preview_loss(line.damage, band)


## The bar steps down by `damage` before the projection says so (the blow's line is told
## now; the round's end settles the bar to the true value), with the flash and the shake.
func preview_loss(damage: int, band: int) -> void:
	if damage <= 0 or _shown_id.is_empty():
		return
	_show_vitality(_shown_id, maxi(0, _shown_vitality - damage), band)
	if _shown_resources.size() == 3:
		var shown: BattleResourceProjection = _shown_resources[0]
		_shown_resources[0] = BattleResourceProjection.new(maxi(0, shown.current - damage), shown.effective, shown.maximum)
		_primary.text = tr("气 %s") % _track(_shown_resources[0])


## The sideways shake, SHAKE_PX[band] wide, over hit_shake_ms (with the flash: the setting
## 受击闪红 turns both off).
func _shake_by(band: int) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if not BattlePace.hit_flash or feel.hit_shake_seconds <= 0.0:
		return
	if _shake != null and _shake.is_valid():
		_shake.kill()
		position.x = _rest_x
	_rest_x = position.x
	var width: float = SHAKE_PX.get(band, SHAKE_PX[BattleVitalityBar.Band.UNHURT])
	var steps: int = 4
	_shake = create_tween()
	for step: int in steps:
		var way: float = 1.0 if step % 2 == 0 else -1.0
		_shake.tween_property(self, "position:x", _rest_x + way * width * (1.0 - float(step) / float(steps)), feel.hit_shake_seconds / float(steps + 1))
	_shake.tween_property(self, "position:x", _rest_x, feel.hit_shake_seconds / float(steps + 1))
	_shake.tween_callback(_resort)


## The card's container lays it out again after a shake or a fall (the tween's x and y were
## only the show's).
func _resort() -> void:
	var parent := get_parent() as Container
	if parent != null:
		parent.queue_sort()


## The fall: the card sinks FALL_SINK px, tilts FALL_TILT_DEGREES, and the stage veils it
## under the 倒 / 亡 stamp over fall_ms; up again (empty): back at once.
func _show_fallen(text: String) -> void:
	_fallen_text = text
	if _fall != null and _fall.is_valid():
		_fall.kill()
	var seconds: float = GameContent.catalog().pacing().feel.fall_seconds
	pivot_offset = size * 0.5
	if text.is_empty():
		rotation = 0.0
		stage.show_fallen("", 0.0)
		_resort()
		return
	stage.show_fallen(text, seconds)
	if seconds <= 0.0:
		rotation = deg_to_rad(FALL_TILT_DEGREES)
		return
	_fall = create_tween().set_parallel(true)
	_fall.tween_property(self, "rotation", deg_to_rad(FALL_TILT_DEGREES), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_fall.tween_property(self, "position:y", position.y + FALL_SINK, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## The 起手 / 要出 line flashes (white for a 要出, pale gold for a 起手) and settles to its
## gold over intent_pulse_ms.
func _pulse_intent(telegraph: bool) -> void:
	var seconds: float = GameContent.catalog().pacing().feel.intent_pulse_seconds
	if _intent_pulse != null and _intent_pulse.is_valid():
		_intent_pulse.kill()
	if seconds <= 0.0:
		_intent.add_theme_color_override("font_color", INTENT_COLOR)
		return
	var from: Color = TELEGRAPH_FLASH if telegraph else INTENT_FLASH
	_intent.add_theme_color_override("font_color", from)
	_intent_pulse = create_tween()
	_intent_pulse.tween_method(func(color: Color) -> void: _intent.add_theme_color_override("font_color", color), from, INTENT_COLOR, seconds)


## The border flashes pale gold for a special, then goes back to what present() shows.
func _flash_border() -> void:
	if GameContent.catalog().pacing().feel.special_title_seconds <= 0.0:
		return
	if _border_flash != null and _border_flash.is_valid():
		_border_flash.kill()
	var back: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if back == _special_border:
		back = _ordinary_border
	add_theme_stylebox_override("panel", _special_border)
	_border_flash = create_tween()
	_border_flash.tween_interval(SPECIAL_BORDER_SECONDS)
	_border_flash.tween_callback(func() -> void: add_theme_stylebox_override("panel", back))


## Someone else on the card: no show carries over.
func _reset_show() -> void:
	for tween: Tween in [_shake, _fall, _intent_pulse, _border_flash]:
		if tween != null and tween.is_valid():
			tween.kill()
	rotation = 0.0
	_fallen_text = ""
	_shown_intent = ""
	_intent.add_theme_color_override("font_color", INTENT_COLOR)
	stage.clear()
	_resort()


## A finished fight's last blow felled the one on the card (no refresh follows): the stamp.
func show_final_fall(text: String) -> void:
	if text != _fallen_text:
		_show_fallen(text)


## The 倒 / 亡 stamp as shown (tests).
func fallen_text() -> String:
	return _fallen_text


## The 起手 / 要出 line's colour now (tests: the pulse).
func intent_color() -> Color:
	return _intent.get_theme_color("font_color")


## A finished fight's last blow on the card.
func show_final_vitality(vitality: CharacterResourceState) -> void:
	if _shown_resources.size() == 3:
		_show_resources(_shown_id, [BattleResourceProjection.new(vitality.current, vitality.effective, vitality.maximum), _shown_resources[1], _shown_resources[2]])


func _show_resources(id: StringName, resources: Array[BattleResourceProjection]) -> void:
	_vitality.max_value = maxf(1, resources[0].maximum) # Visual scale only; text retains exact values.
	_vitality.effective = resources[0].effective
	_show_vitality(id, resources[0].current)
	_shown_resources = resources
	# TRANSLATORS: a battle card's 气 line: current/effective/maximum.
	_primary.text = tr("气 %s") % _track(resources[0])
	# TRANSLATORS: the player's card: 精 and 神, each current/effective/maximum.
	_secondary.text = tr("精 %s · 神 %s") % [_track(resources[1]), _track(resources[2])]


## The 气 bar's value now (the tween's, while it moves).
func vitality_shown() -> float:
	return _vitality.value


## The tags line as shown (tests).
func status_text() -> String:
	return _status.text


func _request_target() -> void:
	target_requested.emit(_participant_id)


static func _track(value: BattleResourceProjection) -> String:
	return "%d/%d/%d" % [value.current, value.effective, value.maximum]


func _choice_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(96, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_row.add_child(button)
	return button


static func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label
