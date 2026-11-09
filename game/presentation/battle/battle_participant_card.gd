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
## The current target's border (界面重做 4: the interface's lantern).
const GOLD: Color = UiPalette.LANTERN

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
## 战斗拍数 C: the busy shown last (the seal's sound when busy takes hold: 封成, 忙).
var _shown_busy: int = 0
var _shown_intent: String = ""
## 气 N/N; 精 · 神 (the player's card); 内力 (· 加力 · 法力 · 灵力) (the player's card).
## 战斗演出 A (DECISIONS「战斗演出 A」): every card has the same six rows, so every card is one
## height — name, 气 bar, 气, then the player's (and a helper's) 精 · 神 and 内力 where an
## enemy's card has its 预判 line and its 起手, then the tags.
var _primary: Label
var _secondary: Label
var _powers: Label
var _forecast: Label
## A chip (many fighters): the name and the 气 bar only, CHIP_SIZE.
const CHIP_SIZE: Vector2 = Vector2(160, 44)
var _chip: bool = false
var _hostile: bool = false
var _is_current: bool = false
var _content: VBoxContainer
var _chip_borders: Array[StyleBoxFlat] = []
var _big_borders: Array[StyleBoxFlat] = []
## 了结 / 放过 lie over the card's lower rows (the card keeps its height); those rows dim.
var _choice_band: Control
const CHOICE_DIM: float = 0.35
# TRANSLATORS: an enemy's battle card, the 预判 row, when nothing could be foreseen.
const FORECAST_NONE: String = "深浅未明"
## 战斗决策层 2: the one-word tags — 忙 N, the conditions, 昏迷 / 死亡 — and nothing when
## there is nothing to say.
var _status: Label
## 战斗决策层 1B: the enemy's 起手 (the tag of its next move) and the special it announced.
var _intent: Label
## 了结 / 放过, shown while the one on the card waits on the player's choice.
var choice_row: HBoxContainer
## 战斗拍数 B: an enemy's beat plan as seals down the card's edge facing the middle.
var stamps: BattleBeatStamps
## The card shows at most this many tags; the rest fold into 「…+N」 and the hover.
const TAGS_SHOWN: int = 2
var finish_button: Button
var spare_button: Button
## 战斗演出 E (DECISIONS「战斗演出 E」): a side panel — the card at the screen's side, its 立绘 bust
## over its rows, on a voxel banner (BattlePanelChrome); "" an ordinary card.
var _panel_style: String = ""
var _panel_side: int = 0
var _portrait: TextureRect
var _chrome: BattlePanelChrome
var _panel_box: StyleBoxEmpty
var _name_colour: Color = UiPalette.GOLD
var _panel_rest: Vector2 = Vector2.ZERO
var _unfurl_rows: Tween
var _choice_pulse: Tween


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 界面重做 4: a square ebony slab, its edge thicker below (the block's side); the target's
	# edge is the lantern, a special's flash pale gold.
	_ordinary_border = StyleBoxFlat.new()
	_ordinary_border.bg_color = Color(UiPalette.EBONY, 0.96)
	_ordinary_border.border_color = UiPalette.EBONY_SIDE
	_ordinary_border.set_border_width_all(2)
	_ordinary_border.border_width_bottom = 6
	_ordinary_border.content_margin_left = 14
	_ordinary_border.content_margin_right = 14
	_ordinary_border.content_margin_top = 10
	_ordinary_border.content_margin_bottom = 10
	_current_border = _ordinary_border.duplicate() as StyleBoxFlat
	_current_border.border_color = GOLD
	_current_border.set_border_width_all(3)
	_current_border.border_width_bottom = 6
	_special_border = _ordinary_border.duplicate() as StyleBoxFlat
	_special_border.border_color = Color("fff3c4")
	_special_border.set_border_width_all(3)
	_special_border.border_width_bottom = 6
	_big_borders = [_ordinary_border, _current_border, _special_border]
	for big: StyleBoxFlat in _big_borders:
		var chip := big.duplicate() as StyleBoxFlat
		chip.content_margin_left = 8
		chip.content_margin_right = 8
		chip.content_margin_top = 3
		chip.content_margin_bottom = 3
		chip.border_width_bottom = 3
		_chip_borders.append(chip)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	add_child(content)
	_content = content
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_portrait.visible = false
	content.add_child(_portrait)
	_title = _label(content)
	_title.add_theme_color_override("font_color", UiPalette.GOLD)
	_title.add_theme_font_size_override("font_size", GameTheme.text_size(20))
	_vitality = BattleVitalityBar.new()
	_vitality.name = "Vitality"
	content.add_child(_vitality)
	_primary = _label(content)
	_secondary = _label(content)
	# An enemy's 预判 in the 精 · 神 row: the forecast's line, small and muted (the hover keeps it whole).
	_forecast = _label(content)
	_forecast.name = "Forecast"
	_forecast.add_theme_color_override("font_color", UiPalette.MUTED)
	_forecast.add_theme_font_size_override("font_size", GameTheme.text_size(14))
	_powers = _label(content)
	_intent = _label(content)
	_intent.add_theme_color_override("font_color", INTENT_COLOR)
	_intent.visible = false
	# The tags last (界面重做 4): their line stays when empty (the card does not jump), and
	# at the foot it reads as the card's margin, not a gap between 气 and 起手.
	_status = _label(content)
	# 了结 / 放过 over the lower rows (a band at the card's foot, not a row of its own).
	_choice_band = Control.new()
	_choice_band.name = "ChoiceBand"
	_choice_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_choice_band)
	choice_row = HBoxContainer.new()
	choice_row.name = "KnockoutChoice"
	choice_row.add_theme_constant_override("separation", 8)
	choice_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	choice_row.offset_top = -48
	choice_row.visible = false
	_choice_band.add_child(choice_row)
	finish_button = _choice_button("FinishButton")
	finish_button.pressed.connect(func() -> void: finish_requested.emit(_participant_id))
	spare_button = _choice_button("SpareButton")
	spare_button.pressed.connect(func() -> void: spare_requested.emit(_participant_id))
	stage = BattleCardStage.new()
	stage.name = "Stage"
	add_child(stage)
	stamps = BattleBeatStamps.new()
	stamps.name = "Stamps"
	add_child(stamps)
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
	_chrome = BattlePanelChrome.new()
	_chrome.name = "Chrome"
	_chrome.visible = false
	add_child(_chrome)
	_panel_box = StyleBoxEmpty.new()
	_panel_box.content_margin_left = 14
	_panel_box.content_margin_right = 14
	_panel_box.content_margin_top = 8
	_panel_box.content_margin_bottom = 10


## `hold_resources`: 气, 精 and 神 stay as shown (the blow's line is not told yet).
## DECISIONS「战斗界面」: the player's card carries every track; an enemy's its 气 bar, its
## name with the forecast's word, its tags and its 起手 / 要出; the current target is the gold
## border, an enemy that cannot be picked is dimmed; the hover explains the tags.
func present(value: BattleParticipantProjection, player_id: StringName, current_id: StringName, queued_id: StringName = &"", hold_resources: bool = false) -> void:
	var newly_shown: bool = value.participant_id != _shown_id
	if newly_shown:
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
	# 战斗拍数 B: the 打法词 after the forecast's word, once the player's 见识录 reads it.
	if not is_player and not value.style_word.is_empty():
		role += " · " + tr(value.style_word)
	_title.text = "%s · %s" % [tr(value.display_name), role]
	_is_current = value.participant_id == current_id
	if not _panel_style.is_empty():
		_chrome.dress(_panel_side, _is_current, _chrome.side_colour)
	var border: StyleBox = _border(1 if _is_current else 0)
	if get_theme_stylebox("panel") != border and (_border_flash == null or not _border_flash.is_valid()):
		add_theme_stylebox_override("panel", border)
	modulate = DIM if value.hostile_to_player and not value.targetable and knockout == null else Color.WHITE
	if not hold_resources or value.participant_id != _shown_id or _shown_resources.is_empty():
		_show_resources(value.participant_id, [value.vitality, value.essence, value.spirit])
	# 战斗演出 A: the player's and a helper's card carry 精 · 神 and 内力; an enemy's its 预判 and 起手.
	_hostile = value.hostile_to_player
	if not _hostile:
		_powers.text = " · ".join(_power_parts(value))
	# TRANSLATORS: keep 深浅未明 short: an enemy's battle card when nothing could be foreseen of them.
	_forecast.text = value.strength_line if not value.strength_line.is_empty() else tr(FORECAST_NONE)
	# The tags: 忙 N, the conditions, then 昏迷 / 死亡 (and when they come to); 无法行动 only
	# when none of those says why.
	var states := PackedStringArray()
	if value.participant_id == queued_id:
		# The planned action's target when it is not the current one (the gold border).
		states.append(tr("已排定目标"))
	if value.busy_value != 0:
		# TRANSLATORS: a battle card's tag: busy for %d more beats.
		states.append(tr("忙 %d") % value.busy_value)
	if value.busy_value != 0 and _shown_busy == 0 and not newly_shown:
		BattleSounds.cue(BattleSounds.SEAL)
	_shown_busy = value.busy_value
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
	# 战斗拍数 B: an enemy's beats left in the round running.
	if value.hostile_to_player and value.round_running and value.beats != null and value.beats.remaining > 0 and not dead and not unconscious:
		# TRANSLATORS: an enemy's card: the beats it still has this round.
		states.append(tr("剩 %d 手") % value.beats.remaining)
	# At most TAGS_SHOWN on the card (纪要 §九: three layers at most); the rest fold.
	var folded := PackedStringArray()
	if states.size() > TAGS_SHOWN:
		folded = states.slice(TAGS_SHOWN)
		states = states.slice(0, TAGS_SHOWN)
		# TRANSLATORS: a battle card's tags line when more tags than fit: {count} more in the hover.
		states.append(tr("…+%d") % folded.size())
	_status.text = " · ".join(states)
	var explained := PackedStringArray()
	if not folded.is_empty():
		# TRANSLATORS: a battle card's hover: the tags that did not fit on the card.
		explained.append(tr("还有：%s") % " · ".join(folded))
	explained.append_array(BattleConditionTags.descriptions(value.conditions))
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
	_show_rows()
	if _hostile and _intent.text != _shown_intent:
		_pulse_intent(not value.telegraph.is_empty())
	_shown_intent = _intent.text if _hostile else ""
	# 战斗拍数 B: the plan's seals — the settled beat's word, then one ？ per beat it reads.
	var first: String = ""
	if value.hostile_to_player and not value.beat_plan_tags.is_empty() and not dead and not unconscious:
		first = stamp_word(value)
	stamps.present(first, maxi(0, value.beat_plan_tags.size() - 1) if not first.is_empty() else 0, value.beat_plan_confirmed > 0)
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
	# the tags' meanings, then the numbers (DECISIONS「数值用到才出现」).
	var hover := PackedStringArray()
	if value.targetable:
		hover.append(tr("选为目标：%s") % tr(value.display_name))
	if not value.strength_line.is_empty():
		hover.append(value.strength_line)
	hover.append_array(explained)
	hover.append_array(_number_lines(value, is_player))
	target_button.tooltip_text = "\n".join(hover)
	_present_choice(value, knockout)


## The word on the first seal: the perform's 「」 word (「封」字诀 → 封) when the settled beat is
## one, 守 for 守势, ？ for a move not read, else the move's tag.
static func stamp_word(value: BattleParticipantProjection) -> String:
	if value.beat_plan_tags.is_empty():
		return ""
	if value.beat_plan_tags[0].is_empty() and not value.telegraph.is_empty():
		var name: String = CombatActionDefinition.name_in(value.telegraph)
		return name.left(1) if not name.is_empty() else TranslationServer.translate("绝")
	if value.next_move_guard:
		return TranslationServer.translate("守")
	if not value.next_move_known:
		return "？"
	return CombatMoveTags.label(value.beat_plan_tags[0])


## 内力, then 加力, 法力 and 灵力 as the numbers' rule shows them.
func _power_parts(value: BattleParticipantProjection) -> PackedStringArray:
	# TRANSLATORS: the player's battle card: 内力, current/maximum.
	var parts := PackedStringArray([tr("内力 {force}/{max_force}").format({"force": value.force.current, "max_force": value.force.maximum})])
	if value.show_enforce:
		# TRANSLATORS: the player's battle card: enforce.c's force_factor, the 内力 put into each blow.
		parts.append(tr("加力 {factor}").format({"factor": value.force_factor}))
	if value.show_mana:
		# TRANSLATORS: the player's battle card: 法力, current/maximum.
		parts.append(tr("法力 {mana}/{max_mana}").format({"mana": value.mana.current, "max_mana": value.mana.maximum}))
	if value.show_atman:
		# TRANSLATORS: the player's battle card: 灵力, current/maximum.
		parts.append(tr("灵力 {atman}/{max_atman}").format({"atman": value.atman.current, "max_atman": value.atman.maximum}))
	return parts


## The hover's numbers: 气 with what it is (with its 有效, which the card's line leaves to the
## bar), and on the player's card 精, 神 and each power too.
func _number_lines(value: BattleParticipantProjection, is_player: bool) -> PackedStringArray:
	var lines := PackedStringArray([_track_line(&"vitality", value.vitality)])
	if not is_player:
		return lines
	lines.append_array([_track_line(&"essence", value.essence), _track_line(&"spirit", value.spirit)])
	lines.append(_power_line(&"force"))
	for shown: Array in [[value.show_enforce, &"enforce"], [value.show_mana, &"mana"], [value.show_atman, &"atman"]]:
		if shown[0]:
			lines.append(_power_line(shown[1]))
	return lines


static func _power_line(stat_id: StringName) -> String:
	# TRANSLATORS: a battle card's hover: {name} 内力 / 加力 / 法力 / 灵力, then what it is.
	return TranslationServer.translate("{name}：{hint}").format({"name": StatCell.stat_name(stat_id), "hint": StatCell.stat_hint(stat_id)})


static func _track_line(stat_id: StringName, track: BattleResourceProjection) -> String:
	# TRANSLATORS: a battle card's hover: {name} 气 / 精 / 神, its three numbers (当前 / 有效 / 最大), then what it is.
	return TranslationServer.translate("{name} {current} / 有效 {effective} / 最大 {maximum}：{hint}").format({
		"name": StatCell.stat_name(stat_id), "current": track.current, "effective": track.effective,
		"maximum": track.maximum, "hint": StatCell.stat_hint(stat_id),
	})


## The card of one held for the player's choice: 了结 (marked when it does 朱鸿雪's task or
## kills the player's master) and 放过 in place of picking the card as a target.
func _present_choice(value: BattleParticipantProjection, knockout: BattleKnockoutProjection) -> void:
	choice_row.visible = knockout != null
	_show_rows()
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


## 战斗演出 A: the rows the card shows — all six on a big card (the player's side: 精 · 神 and
## 内力; an enemy: 预判 and 起手), the name and the bar on a chip; under 了结 / 放过 the rows
## the buttons lie over dim.
func _show_rows() -> void:
	var big: bool = not _chip
	_primary.visible = big
	_secondary.visible = big and not _hostile
	_powers.visible = big and not _hostile
	_forecast.visible = big and _hostile
	_intent.visible = big and _hostile
	_status.visible = big
	stamps.visible = big
	var under: float = CHOICE_DIM if choice_row.visible and _panel_style.is_empty() else 1.0
	for row: Control in [_powers, _intent, _status]:
		row.modulate.a = under


## Big or a chip (CHIP_SIZE: the name and the 气 bar).
func set_chip(chip: bool) -> void:
	if chip == _chip:
		return
	_chip = chip
	_title.add_theme_font_size_override("font_size", GameTheme.text_size(14 if chip else 20))
	_content.add_theme_constant_override("separation", 1 if chip else 2)
	# The target button covers the card (its 64×64 would hold a chip open).
	target_button.custom_minimum_size = Vector2.ZERO if chip else Vector2(64, 64)
	if _border_flash == null or not _border_flash.is_valid():
		add_theme_stylebox_override("panel", _border(1 if _is_current else 0))
	_show_rows()


func is_chip() -> bool:
	return _chip


## Who the card shows.
func participant_id() -> StringName:
	return _participant_id


## The border: 0 ordinary, 1 the current target, 2 a special's flash; a chip's thinner; a side
## panel has none (its chrome dresses it).
func _border(kind: int) -> StyleBox:
	if not _panel_style.is_empty():
		return _panel_box
	return (_chip_borders if _chip else _big_borders)[kind]


## 战斗演出 E: the card as a side panel in `style` ("banner"; "" back to an ordinary card) on
## `side` (0 the player's, on the left; 1 the other, on the right), `picture` its bust at
## `picture_size` (null: none), its cloth's edge `colour`, its name in `name_colour`.
func set_panel(style: String, side: int, picture: Texture2D = null, picture_size: Vector2 = Vector2.ZERO, colour: Color = UiPalette.PATINA, name_colour: Color = UiPalette.GOLD) -> void:
	_panel_style = style
	_panel_side = side
	var panel: bool = not style.is_empty()
	_portrait.texture = picture if panel else null
	_portrait.visible = panel and picture != null
	_portrait.custom_minimum_size = picture_size
	_chrome.visible = panel
	if panel:
		_chrome.dress(side, _is_current, colour)
	_name_colour = name_colour if panel else UiPalette.GOLD
	_title.add_theme_color_override("font_color", _name_colour)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if panel else HORIZONTAL_ALIGNMENT_LEFT
	# 了结 / 放过 on a panel: a row of its own at its foot, drawn over the fall's veil (owner
	# 2026-11-09: laid over the narrow panel's rows under the 倒 stamp they did not read as the
	# fight's question, and the fight waits on them); the stamp high, over the bust.
	var choice_home: Control = _content if panel else _choice_band
	if choice_row.get_parent() != choice_home:
		choice_row.get_parent().remove_child(choice_row)
		choice_home.add_child(choice_row)
		if panel:
			choice_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
			choice_row.custom_minimum_size = Vector2(0, 40)
		else:
			choice_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			choice_row.offset_top = -48
			choice_row.custom_minimum_size = Vector2.ZERO
	choice_row.z_index = 1 if panel else 0
	stage.stamp_centre = Vector2(0.5, 0.24) if panel else Vector2(0.5, 0.5)
	for button: Button in [finish_button, spare_button]:
		# On a panel the row keeps to the panel's width (a long 了结（任务目标、弑师） cut, whole in the hover).
		button.custom_minimum_size = Vector2(0, 40) if panel else Vector2(96, 48)
		button.clip_text = panel
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if panel else TextServer.OVERRUN_NO_TRIMMING
		if panel:
			button.add_theme_color_override("font_color", UiPalette.LANTERN)
			button.add_theme_color_override("font_hover_color", UiPalette.LIGHT_TEXT)
		else:
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_hover_color")
	# A panel is narrower than a card: its rows a size smaller, 精 and 神 without their maximums.
	if not _shown_resources.is_empty():
		_show_resources(_shown_id, _shown_resources)
	for row: Label in [_primary, _secondary, _powers, _intent, _status]:
		row.add_theme_font_size_override("font_size", GameTheme.text_size(14 if panel else 16))
	if not _chip:
		_title.add_theme_font_size_override("font_size", GameTheme.text_size(18 if panel else 20))
	if _border_flash == null or not _border_flash.is_valid():
		add_theme_stylebox_override("panel", _border(1 if _is_current else 0))


## 战斗演出 E: a side panel laid at `at` (its slot's own coordinates), `size` big; a shake or a fall
## comes back here.
func place_panel(at: Vector2, size_now: Vector2) -> void:
	_panel_rest = at
	size = size_now
	if (_shake == null or not _shake.is_valid()) and (_fall == null or not _fall.is_valid()):
		position = at + Vector2(0.0, FALL_SINK if not _fallen_text.is_empty() else 0.0)


## 战斗演出 E: the banner let down from its pole over `seconds` (0: at once), the rows coming up on
## the cloth as it falls.
func unfurl(seconds: float, delay: float = 0.0) -> void:
	if _panel_style.is_empty():
		return
	_chrome.let_down(seconds, delay)
	if _unfurl_rows != null and _unfurl_rows.is_valid():
		_unfurl_rows.kill()
	if seconds <= 0.0:
		_content.modulate.a = 1.0
		return
	_content.modulate.a = 0.0
	_unfurl_rows = create_tween()
	_unfurl_rows.tween_interval(delay + seconds * 0.4)
	_unfurl_rows.tween_property(_content, "modulate:a", 1.0, seconds * 0.6)


## 了结 / 放过 call for the eye (the player pressed a move while the fight waits on them).
func pulse_choice() -> void:
	if not choice_row.visible:
		return
	if _choice_pulse != null and _choice_pulse.is_valid():
		_choice_pulse.kill()
	_choice_pulse = create_tween()
	for step: int in 3:
		_choice_pulse.tween_property(choice_row, "modulate", Color(1.8, 1.6, 1.0), 0.12)
		_choice_pulse.tween_property(choice_row, "modulate", Color.WHITE, 0.18)
	flap(0.6)


## The banner flaps (`amount` 0 .. 1): its side struck.
## 战斗拍数 E: a 重 threw this one off balance — their next beat's seal is struck through.
func strike_next_beat() -> void:
	if stamps != null:
		stamps.strike_first()


func flap(amount: float) -> void:
	if not _panel_style.is_empty():
		_chrome.gust(amount)


## The banner (tests).
func banner() -> BattleVoxelBanner:
	return _chrome.banner


## The bust chosen for the panel (shown or not).
func portrait_texture() -> Texture2D:
	return _portrait.texture


## The bust's size now (zero: none shown).
func portrait_size() -> Vector2:
	return _portrait.custom_minimum_size if _portrait.visible else Vector2.ZERO


## The bust at `size` (zero: not shown — too little room for even one of its pixels a pixel).
func fit_portrait(bust: Vector2) -> void:
	if _portrait.texture == null:
		return
	if _portrait.custom_minimum_size != bust:
		_portrait.custom_minimum_size = bust
	_portrait.visible = bust != Vector2.ZERO


## The side panel's style ("" an ordinary card) and its bust (tests).
func panel_style() -> String:
	return _panel_style


func portrait() -> Texture2D:
	return _portrait.texture if _portrait.visible else null


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
## 战斗演出 C: `title` false — the name shows over the attacker's head in the scene, or not at
## all (a blow between two others): the card leaves it out.
func show_line(line: BattleNarrationLine, title: bool = true) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if line.is_special and line.actor_id == _shown_id:
		if title:
			stage.show_title(line.special_title, true, feel.special_title_seconds)
		_flash_border()
	elif title and line.has_blow and line.actor_id == _shown_id and not line.move.is_empty():
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
	elif not _panel_style.is_empty():
		position = _panel_rest


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
	BattleSounds.cue(BattleSounds.SEAL)
	if seconds <= 0.0:
		rotation = deg_to_rad(FALL_TILT_DEGREES)
		return
	_fall = create_tween().set_parallel(true)
	_fall.tween_property(self, "rotation", deg_to_rad(FALL_TILT_DEGREES), seconds).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var from_y: float = _panel_rest.y if not _panel_style.is_empty() and not get_parent() is Container else position.y
	_fall.tween_property(self, "position:y", from_y + FALL_SINK, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


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
	if not _panel_style.is_empty():
		# A side panel: its chrome flashes pale gold.
		_chrome.modulate = Color(1.6, 1.5, 1.1)
		_border_flash = create_tween()
		_border_flash.tween_property(_chrome, "modulate", Color.WHITE, SPECIAL_BORDER_SECONDS)
		return
	var back: StyleBox = _border(1 if _is_current else 0)
	add_theme_stylebox_override("panel", _border(2))
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
	_shown_busy = 0
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
	# TRANSLATORS: a battle card's 气 line: current/maximum (the bar's crack shows the 有效 between them, the hover the number).
	_primary.text = tr("气 %s") % _track(resources[0])
	# TRANSLATORS: the player's card: 精 and 神, each current/maximum.
	_secondary.text = tr("精 %s · 神 %s") % [_track(resources[1]), _track(resources[2])]
	if not _panel_style.is_empty():
		# TRANSLATORS: a battle side panel (narrower than a card): 精 and 神 now (their maximums in the hover).
		_secondary.text = tr("精 %d　神 %d") % [resources[1].current, resources[2].current]


## The 气 bar's value now (the tween's, while it moves).
func vitality_shown() -> float:
	return _vitality.value


## The tags line as shown (tests).
func status_text() -> String:
	return _status.text


func _request_target() -> void:
	target_requested.emit(_participant_id)


static func _track(value: BattleResourceProjection) -> String:
	return "%d/%d" % [value.current, value.maximum]


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
	label.add_theme_font_size_override("font_size", GameTheme.text_size(16))
	parent.add_child(label)
	return label
