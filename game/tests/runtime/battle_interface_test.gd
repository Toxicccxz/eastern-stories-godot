extends RefCounted

## 战斗决策层 2 (DECISIONS「战斗界面」): the battle cards, the short battle lines and the
## buttons as the player reads them — the 气 bar's four bands and its 裂痕, the one-word tags
## and their hover, what the player's card and an enemy's each show, the forecast's word after
## an enemy's name, a blow's short form over ES2's line, a move's hover line, and the keys
## walking the two rows of buttons. Rules are not touched: every value here is a projection.
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Narration := preload("res://tests/runtime/battle_narration_test.gd")
const Draws := preload("res://tests/support/scripted_combat_random_source.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_bands_and_crack(tree)
	_player_card(tree)
	_enemy_card(tree)
	_summaries()
	_move_hover_and_focus(tree)
	await _beats_panel(tree)
	_stamps_and_style_word(tree)
	_folded_beats()
	await _mode_looks_and_one_size(tree)
	return {"assertions": assertions, "failures": failures}


## status_msg()'s bands: over 80 unhurt, over 60 轻伤, over 20 重伤, 20 and under 濒死.
func _bands_and_crack(tree: SceneTree) -> void:
	var Band := BattleVitalityBar.Band
	check(BattleVitalityBar.band(81, 100) == Band.UNHURT and BattleVitalityBar.band(100, 100) == Band.UNHURT, "81 and 100 of 100: unhurt")
	check(BattleVitalityBar.band(80, 100) == Band.LIGHT and BattleVitalityBar.band(61, 100) == Band.LIGHT, "80 and 61: 轻伤")
	check(BattleVitalityBar.band(60, 100) == Band.HEAVY and BattleVitalityBar.band(21, 100) == Band.HEAVY, "60 and 21: 重伤")
	check(BattleVitalityBar.band(20, 100) == Band.DYING and BattleVitalityBar.band(0, 100) == Band.DYING, "20 and 0: 濒死")
	check(BattleVitalityBar.band(0, 0) == Band.UNHURT, "no maximum (a cast with no numbers): unhurt")
	check(BattleVitalityBar.band_color(81, 100) != BattleVitalityBar.band_color(80, 100) and BattleVitalityBar.band_color(61, 100) != BattleVitalityBar.band_color(60, 100) and BattleVitalityBar.band_color(21, 100) != BattleVitalityBar.band_color(20, 100), "each band its own colour")
	check(BattleVitalityBar.band_word(100) == "无碍" and BattleVitalityBar.band_word(70) == "受伤不轻" and BattleVitalityBar.band_word(50) == "伤势沉重" and BattleVitalityBar.band_word(10) == "濒死", "the four words")
	var bar := BattleVitalityBar.new()
	tree.root.add_child(bar)
	bar.max_value = 100
	bar.effective = 84
	bar.value = 83
	check(is_equal_approx(bar.crack_from(), 0.84), "the crack starts at the effective 气: %.2f" % bar.crack_from())
	check(bar.fill_color() == BattleVitalityBar.BAND_COLORS[Band.UNHURT], "83 of 100 fills in the unhurt colour")
	bar.effective = 100
	check(is_equal_approx(bar.crack_from(), 1.0), "no wound: no crack")
	bar.value = 15
	check(bar.fill_color() == BattleVitalityBar.BAND_COLORS[Band.DYING], "15 of 100 fills red")
	bar.free()


## The player's card: every track, 加力 / 法力 / 灵力 each as the numbers' rule says, no 起手
## line, nothing about being a target; the hover tells the numbers (DECISIONS「数值用到才出现」).
func _player_card(tree: SceneTree) -> void:
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	var me: BattleParticipantProjection = _one(&"p", "雪工", false, true, false, 83, 84, 100, 0, 0, 0, 3)
	card.present(me, &"p", &"n")
	check(card._title.text == "雪工 · 你", "the player's card: name · 你: " + card._title.text)
	check(card._primary.text == "气 83/100" and card._secondary.visible and card._secondary.text == "精 50/50 · 神 50/50", "气 on its line, 精 · 神 on the player's: %s | %s" % [card._primary.text, card._secondary.text])
	check(card._powers.visible and card._powers.text == "内力 40/60", "nothing used: 内力 alone: " + card._powers.text)
	check(card.status_text().is_empty() and not card._intent.visible, "nothing to tag, no 起手 line: '%s'" % card.status_text())
	var hover: String = card.target_button.tooltip_text
	check(not hover.contains("选为目标") and card.modulate == Color.WHITE, "not a target, not dimmed: '%s'" % hover)
	check(hover.begins_with("气 83 / 有效 84 / 最大 100：") and hover.contains("精 50 / 有效 50 / 最大 50：") and hover.contains("神 50 / 有效 50 / 最大 50：") and hover.contains("内力：") and not hover.contains("法力"), "the hover tells each number: " + hover)
	check(card._vitality.effective == 84.0 and card._vitality.max_value == 100.0 and card.vitality_shown() == 83.0, "the bar: 83 of 100, the crack from 84")
	me.show_enforce = true
	card.present(me, &"p", &"n")
	check(card._powers.text == "内力 40/60 · 加力 3" and card.target_button.tooltip_text.contains("加力："), "加力 once it is set: " + card._powers.text)
	me.show_enforce = false
	me.show_mana = true
	card.present(me, &"p", &"n")
	check(card._powers.text == "内力 40/60 · 法力 0/0" and not card.target_button.tooltip_text.contains("灵力："), "法力 and 灵力 are two lines: " + card._powers.text)
	me.show_mana = false
	me.show_atman = true
	card.present(me, &"p", &"n")
	check(card._powers.text == "内力 40/60 · 灵力 0/0", "灵力 alone: " + card._powers.text)
	card.free()


## An enemy's card: the 气 bar and its line, the name with the forecast's word, the tags
## and the 起手 / 要出 line; the gold border is the target, a dimmed card cannot be picked.
func _enemy_card(tree: SceneTree) -> void:
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	var dog: BattleParticipantProjection = _one(&"n", "野狗", true, true, true, 40, 70, 100, 0, 2)
	dog.strength = CombatForecast.Verdict.FAVOURED
	dog.strength_line = "占优：你比它强一些。"
	dog.conditions = [ConditionIds.SNAKE_POISON, ConditionIds.DRUNK]
	dog.next_move_tag = CombatMoveTags.HEAVY
	dog.telegraph = "「封」字诀"
	card.present(dog, &"p", &"n")
	check(card._title.text == "野狗 · 占优", "the forecast's word after the name: " + card._title.text)
	check(not card._secondary.visible and not card._powers.visible and card._primary.text == "气 40/100", "an enemy: only 气: " + card._primary.text)
	check(card.status_text() == "忙 2 · 毒 · …+1", "two tags on the card, the rest folded: " + card.status_text())
	check(card._intent.visible and card._intent.text == "起手：重 · 要出 「封」字诀", "起手 / 要出 on their own line: " + card._intent.text)
	var hover: String = card.target_button.tooltip_text
	check(hover.begins_with("选为目标：野狗\n占优：你比它强一些。\n还有：醉") and hover.contains("蛇毒：") and hover.contains("醉了：") and hover.contains(CombatMoveTags.description(CombatMoveTags.HEAVY)) and hover.contains("破绽：快招可破。\n气 40 / 有效 70 / 最大 100："), "the hover explains the word, every tag, the move's weakness and 气's numbers: " + hover)
	# 识招 (战斗决策层 4): a move not read yet is 「？」; one who will guard says 守势.
	dog.next_move_known = false
	card.present(dog, &"p", &"n")
	check(card._intent.text == "起手：？ · 要出 「封」字诀" and card.target_button.tooltip_text.contains("还没看熟这一招。") and not card.target_button.tooltip_text.contains("破绽"), "not watched enough: 起手：？, no weakness told: " + card._intent.text)
	dog.next_move_guard = true
	card.present(dog, &"p", &"n")
	check(card._intent.text == "起手：守势 · 要出 「封」字诀" and card.target_button.tooltip_text.contains("打空了就反击"), "fight()'s gate failed: 起手：守势, the riposte explained: " + card._intent.text)
	dog.next_move_guard = false
	dog.next_move_known = true
	card.present(dog, &"p", &"n")
	check(card._intent.text == "起手：重 · 要出 「封」字诀", "read again")
	check((card.get_theme_stylebox("panel") as StyleBoxFlat).border_color == BattleParticipantCard.GOLD and card.modulate == Color.WHITE, "the current target: gold, not dimmed")
	check(card._vitality.fill_color() == BattleVitalityBar.BAND_COLORS[BattleVitalityBar.Band.HEAVY] and is_equal_approx(card._vitality.crack_from(), 0.7), "40 of 100 fills orange, the crack from 70")
	# Not the target: the ordinary border. Not targetable (dead): dimmed, 死亡, no 对手 word.
	var other: BattleParticipantProjection = _one(&"m", "疯狗", true, false, false, 0, 50, 100, 0, 0, CombatSliceLifeStatus.Value.DEAD)
	card.present(other, &"p", &"n")
	check(card._title.text == "疯狗 · 对手", "no forecast read: 对手")
	check((card.get_theme_stylebox("panel") as StyleBoxFlat).border_color != BattleParticipantCard.GOLD and card.modulate == BattleParticipantCard.DIM, "not the target, cannot be picked: ordinary border, dimmed")
	check(card.status_text() == "死亡" and card.target_button.tooltip_text.begins_with("气 0 / 有效 50 / 最大 100：") and card._intent.visible and card._intent.text.is_empty(), "死亡 alone; only 气 to hover; the 起手 line kept (empty) so the card does not jump: '%s'" % card.status_text())
	# One who fell and is held: 昏迷 and when they come to; the choice shows, so not dimmed.
	var held: BattleParticipantProjection = _one(&"k", "工匠", true, false, false, 0, 50, 100, 0, 0, CombatSliceLifeStatus.Value.UNCONSCIOUS, 0, BattleKnockoutProjection.new(3, false, false))
	card.present(held, &"p", &"n")
	check(card.status_text() == "昏迷 · 约 3 秒后醒来" and card.modulate == Color.WHITE and card.choice_row.visible, "held: 昏迷 · 约 3 秒后醒来, the choice, not dimmed: " + card.status_text())
	# Cannot act for no tagged reason (a 困 spell): 无法行动.
	var bound: BattleParticipantProjection = _one(&"b", "弟子", true, false, true, 50, 50, 100)
	card.present(bound, &"p", &"n")
	check(card.status_text() == "无法行动", "no tag says why: 无法行动: " + card.status_text())
	# The word and its line: the fight's verdict with its reason; in a 切磋 the spar's (who lands first).
	var forecast := CombatForecast.new()
	forecast.verdict = CombatForecast.Verdict.UNFAVOURED
	forecast.reason = CombatForecast.Reason.WEAPON_PARRY
	forecast.spar_verdict = CombatForecast.Verdict.FAVOURED
	var fight: BattleStrength = BattleStrength.of(forecast, "他")
	var spar: BattleStrength = BattleStrength.of(forecast, "他", true)
	check(fight.verdict == CombatForecast.Verdict.UNFAVOURED and fight.word() == "吃亏" and fight.line == "吃亏：他比你强，打起来要吃亏。他有兵刃在手，你空手难以近身。", "a fight: the verdict, the reason: " + fight.line)
	check(spar.verdict == CombatForecast.Verdict.FAVOURED and spar.word() == "占优" and spar.line == "切磋占优：你多半先打中他。", "a 切磋: the spar's verdict and line: " + spar.line)
	card.present(bound, &"p", &"n", &"b")
	check(card.status_text() == "已排定目标 · 无法行动", "the planned action's target reads a tag: " + card.status_text())
	card.free()


## A blow's short form beside ES2's line: who · move → whom −N · the band's word, or
## 闪开了 / 挡开了; the log prints both, the line's own text is unchanged.
func _summaries() -> void:
	var actor := Martial.binding(&"actor")
	var target := Martial.binding(&"target")
	actor.relationship.add_opponent(&"target")
	target.relationship.add_opponent(&"actor")
	var forward := Martial.execute(actor, target, Narration.Pattern.new(), true)
	var base: CombatAttackResult = forward.ordinary_attack_result.base_result
	check(base.outcome == CombatAttackResult.Outcome.HIT, "fixture hits")
	var cast := Narration._cast(&"actor", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_FEMALE)
	var lines: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(0)).attack_chain(forward, null, cast)
	var damage: int = base.resource_mutation.requested_damage
	var status: CombatStatusReportBoundaryResult = forward.ordinary_attack_result.status_report_result
	var word: String = BattleVitalityBar.band_word(status.ratio)
	check(lines.size() >= 2 and lines[1].summary == "学徒 · 荒山虎吟 → 对手 −%d · %s" % [damage, word], "the hit's short form: " + (lines[1].summary if lines.size() >= 2 else ""))
	check(lines.size() >= 2 and lines[1].text == Es2CombatMessages.damage_message(damage, "瘀伤").replace("$N", "学徒").replace("$p", "她").replace("$n", "对手").replace("$l", "右脚") and lines[1].damage == damage, "ES2's line stays as it was")
	check(lines.size() >= 2 and lines[1].log_rich_text().begins_with(lines[1].summary_rich_text() + "\n[color=#8b959e]") and lines[1].log_rich_text().contains(lines[1].text + "（-%d）" % damage), "the log: the short form, then ES2's line with its damage grey under it")
	check(lines.size() >= 3 and not lines[0].has_summary and not lines[2].has_summary and lines[0].log_rich_text() == lines[0].rich_text(), "the action line and the status line have no short form")
	var dodge := Martial.execute(Martial.binding(&"actor"), Martial.binding(&"target"), Draws.new([0, 0, 0]))
	var dodged: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(1)).attack_chain(dodge, null, cast)
	check(dodged.size() == 2 and dodged[1].summary == "学徒 · 古松挂月 → 对手 · 闪开了", "a dodge: " + (dodged[1].summary if dodged.size() == 2 else ""))
	var armed := Martial.binding(&"actor")
	armed.state.equipment.wield(Martial.sword(), false)
	var parry := Martial.execute(armed, Martial.binding(&"target"), Narration.Pattern.new([0, 0, -1, 0]))
	var parried: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(3)).attack_chain(parry, null, cast)
	check(parried.size() == 2 and parried[1].summary.begins_with("学徒 · ") and parried[1].summary.ends_with(" → 对手 · 挡开了"), "a parry: " + (parried[1].summary if parried.size() == 2 else ""))
	# A beast's verb reads its name; the player's own name stands for the player.
	var beast := Narration._cast(&"p", &"n", "野狗", CharacterState.GENDER_ANIMAL_MALE, &"p", "雪工", CharacterState.GENDER_FEMALE)
	check(BattleNarrator.summary(&"n", &"p", BeastCombatActionDefinitions.bite(), CombatAttackResult.Outcome.HIT, 17, 70, beast) == "野狗 · 咬 → 雪工 −17 · 受伤不轻", "the beast's bite by name, the player by theirs")
	check(BattleNarrator.summary(&"n", &"p", BeastCombatActionDefinitions.bite(), CombatAttackResult.Outcome.HIT, 0, -1, beast) == "野狗 · 咬 → 雪工 · 没伤到", "a hit that took nothing")
	check(BattleNarrator.summary(&"n", &"p", BeastCombatActionDefinitions.bite(), CombatAttackResult.Outcome.HIT, 9, -1, beast) == "野狗 · 咬 → 雪工 −9", "a blow without a status line: the number alone")
	check(BattleNarrator.move_name(BeastCombatActionDefinitions.default_action()) == "default", "a move without a name reads its id's last part")


## A move's hover: its ES2 line as the player would read it, then its tag; the keys walk
## the decision row left and right, down to the quick actions and back up to the chosen move.
func _move_hover_and_focus(tree: SceneTree) -> void:
	var first := CombatActionDefinition.new(&"es2:test/a", 0, 0, &"瘀伤", &"a", "$N使一招「古松挂月」，对准$n的$l「呼」地一拳", "", &"", CombatMoveTags.QUICK, "古松挂月")
	var second := CombatActionDefinition.new(&"es2:test/b", 0, 0, &"瘀伤", &"b", "$N挥动$w，斩向$n的$l", "", &"", CombatMoveTags.HEAVY, "斩")
	check(BattleActionPanel.move_tooltip(first) == "你使一招「古松挂月」，对准对手的要害「呼」地一拳！\n" + CombatMoveTags.description(CombatMoveTags.QUICK), "the hover: ES2's line for 你, then the tag: " + BattleActionPanel.move_tooltip(first))
	check(BattleActionPanel.move_tooltip(second).begins_with("你挥动兵刃，斩向对手的要害！\n"), "$w reads 兵刃 before a weapon is known: " + BattleActionPanel.move_tooltip(second))
	var panel := BattleActionPanel.new()
	tree.root.add_child(panel)
	var actions: Array[CombatTacticalActionInfo] = [
		CombatTacticalActionInfo.new(CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE, CombatTacticalRequest.TargetRule.NONE),
		CombatTacticalActionInfo.new(CombatSurrenderTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE, CombatTacticalRequest.TargetRule.NONE),
	]
	var projection := BattlePresentationProjection.new(&"e", CombatEncounterMode.Value.LETHAL, &"p", &"n", [_one(&"p", "雪工", false, true, false, 80, 80, 100)], actions)
	projection.moves = [first, second]
	projection.turns_offered = true
	projection.manual = true
	projection.waiting = true
	projection.stances_offered = true
	projection.chosen_action_id = &"es2:test/b"
	panel.present(projection)
	var a: Button = panel.move_buttons[&"es2:test/a"]
	var b: Button = panel.move_buttons[&"es2:test/b"]
	var attack: Button = panel.stance_buttons[CombatStance.Value.ATTACK]
	var guard: Button = panel.stance_buttons[CombatStance.Value.GUARD]
	var evade: Button = panel.stance_buttons[CombatStance.Value.EVADE]
	var flee: Button = panel.first_action_button()
	var surrender: Button = panel.action_buttons[CombatSurrenderTacticalPolicy.ACTION_ID]
	check(a.tooltip_text == BattleActionPanel.move_tooltip(first) and panel.move_title(&"es2:test/a") == "古松挂月" and panel.move_sub(&"es2:test/a") == "快", "the button carries the hover, the name over the tag (no beats: the tag alone): %s / %s" % [panel.move_title(&"es2:test/a"), panel.move_sub(&"es2:test/a")])
	check(a.get_node_or_null(a.focus_neighbor_right) == b and b.get_node_or_null(b.focus_neighbor_left) == a and b.focus_neighbor_right.is_empty(), "left and right between the moves; the last move ends the row")
	check(a.get_node_or_null(a.focus_neighbor_left) == attack and attack.get_node_or_null(attack.focus_neighbor_right) == a, "left from the first move to the stance column, right from a stance to the first move")
	check(attack.get_node_or_null(attack.focus_neighbor_bottom) == guard and guard.get_node_or_null(guard.focus_neighbor_bottom) == evade and evade.get_node_or_null(evade.focus_neighbor_top) == guard and attack.focus_neighbor_top.is_empty(), "the stances walk up and down their column")
	check(a.get_node_or_null(a.focus_neighbor_bottom) == flee and b.get_node_or_null(b.focus_neighbor_bottom) == flee, "down from the move row to the first order")
	check(flee.get_node_or_null(flee.focus_neighbor_top) == b and panel.first_move_button() == b, "up from an order to the chosen move, which is where the focus lands when the fight waits")
	check(flee.get_node_or_null(flee.focus_neighbor_right) == surrender and surrender.get_node_or_null(surrender.focus_neighbor_left) == flee and surrender.focus_neighbor_right.is_empty(), "along the orders; no 收势 without the beats")
	check(flee.get_node_or_null(flee.focus_neighbor_bottom) == panel.manual_button and panel.manual_button.get_node_or_null(panel.manual_button.focus_neighbor_top) == flee, "down from the orders to 改为自动 and back up")
	check(not panel.strip_row.visible and not panel.yield_button.visible, "ES2's one beat: no strip, no 收势")
	projection.chosen_action_id = &""
	panel.present(projection)
	check(panel.first_move_button() == a, "nothing chosen: the first move")
	panel.free()


## 战斗拍数 B / 战斗界面第二轮: the panel with the beats — the moves in columns by tag (快 / 重 /
## 虚 / 守), each sub line the tag with its price and never a verdict on the target's move, a
## locked or unaffordable move dimmed with why in the same place (the order never changes),
## the strip (还剩 N 手, the slots as a timeline — spent, won, given up — the dashed slot while a
## beat can be won, the sentence: 他起手, a beat's result, what a pointed move would take), the
## ring (the target's move ringed, the pointed tag lit), the 运功 menu, 收势, the panel's
## height, and the keys' hover (FocusTip) on a dimmed move.
func _beats_panel(tree: SceneTree) -> void:
	var rules: CombatBeatRules = GameContent.catalog().pacing().beat_rules()
	var moves: Array[CombatActionDefinition] = []
	var names: Array[String] = ["峰回路转", "空山鸟语", "御风而行", "旭日东升", "金光泻地", "童子引路", "柳暗花明", "空谷秋鸿"]
	var tags: Array[StringName] = [CombatMoveTags.QUICK, CombatMoveTags.HEAVY, CombatMoveTags.QUICK, CombatMoveTags.HEAVY, CombatMoveTags.FEINT, CombatMoveTags.FEINT, CombatMoveTags.GUARD, CombatMoveTags.GUARD]
	var groups: Array[String] = ["逐", "逐", "逐", "逐", "引", "引", "守", "守"]
	for index: int in names.size():
		moves.append(CombatActionDefinition.new(StringName("es2:test/%d" % index), 0, 0, &"刺伤", StringName("m%d" % index), "$N使一招「%s」" % names[index], "", &"", tags[index], names[index], groups[index]))
	var panel := BattleActionPanel.new()
	tree.root.add_child(panel)
	var recover: StringName = CombatExertTacticalPolicy.action_id_for(&"recover")
	var refresh: StringName = CombatExertTacticalPolicy.action_id_for(&"refresh")
	var actions: Array[CombatTacticalActionInfo] = [
		CombatTacticalActionInfo.new(CombatFleeTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.FLEE, CombatTacticalRequest.TargetRule.NONE),
		CombatTacticalActionInfo.new(CombatSurrenderTacticalPolicy.ACTION_ID, CombatTacticalRequest.Category.TACTICAL_DEFENSE, CombatTacticalRequest.TargetRule.NONE),
		CombatTacticalActionInfo.new(recover, CombatTacticalRequest.Category.INTERNAL_FORCE, CombatTacticalRequest.TargetRule.NONE),
		CombatTacticalActionInfo.new(refresh, CombatTacticalRequest.Category.INTERNAL_FORCE, CombatTacticalRequest.TargetRule.NONE, true, "内力不够"),
		CombatTacticalActionInfo.new(&"perform.counterattack", CombatTacticalRequest.Category.MARTIAL_SPECIAL, CombatTacticalRequest.TargetRule.CURRENT_HOSTILE),
	]
	var foe: BattleParticipantProjection = _one(&"n", "店小二", true, true, true, 80, 80, 100)
	foe.beats = CombatRoundBeats.new(&"n", 2)
	var projection := BattlePresentationProjection.new(&"e", CombatEncounterMode.Value.LETHAL, &"p", &"n", [_one(&"p", "雪工", false, true, false, 80, 80, 100), foe], actions)
	projection.moves = moves
	projection.turns_offered = true
	projection.manual = true
	projection.waiting = true
	projection.stances_offered = true
	projection.beat_rules = rules
	projection.player_beats = CombatRoundBeats.new(&"p", 2)
	projection.round_running = false
	projection.opponent_tag = CombatMoveTags.GUARD
	projection.player_earn = CombatSchoolSkeleton.EARN_OPPONENT_MISSED
	for move: CombatActionDefinition in moves:
		projection.move_costs[move.action_id] = rules.cost_of_tag(move.tag)
	projection.action_costs = {&"perform.counterattack": 2, CombatFleeTacticalPolicy.ACTION_ID: 1, CombatSurrenderTacticalPolicy.ACTION_ID: 0, recover: 1, refresh: 1}
	panel.present(projection)
	var order: Array[StringName] = panel.move_order()
	check(order == ([&"es2:test/0", &"es2:test/2", &"es2:test/1", &"es2:test/3", &"es2:test/4", &"es2:test/5", &"es2:test/6", &"es2:test/7"] as Array[StringName]), "the moves stand in columns by tag (快 / 重 / 虚 / 守), each column in the set's order: %s" % str(order))
	check(panel.column_tags() == ([CombatMoveTags.QUICK, CombatMoveTags.HEAVY, CombatMoveTags.FEINT, CombatMoveTags.GUARD] as Array[StringName]), "four columns, no empty 平")
	var lead: Button = panel.move_buttons[&"es2:test/0"]
	check(lead.get_node_or_null(lead.focus_neighbor_right) == panel.move_buttons[&"es2:test/2"] and panel.move_buttons[&"es2:test/2"].get_node_or_null(panel.move_buttons[&"es2:test/2"].focus_neighbor_right) == panel.move_buttons[&"es2:test/1"] and panel.stance_buttons[CombatStance.Value.ATTACK].get_node_or_null(panel.stance_buttons[CombatStance.Value.ATTACK].focus_neighbor_right) == lead, "the keys walk the columns as laid out, the stances enter at the head")
	check(panel._move_ridges[&"es2:test/0"].color == BattleBeatChips.COLORS[CombatMoveTags.QUICK] and panel._move_ridges[&"es2:test/4"].color == BattleBeatChips.COLORS[CombatMoveTags.FEINT], "each column its tag's colour")
	check(panel.move_sub(&"es2:test/0") == "快 · 1 手" and panel.move_sub(&"es2:test/6") == "守 · 1 手" and panel.move_sub(&"es2:test/1") == "重 · 2 手" and panel.move_sub(&"es2:test/4") == "虚 · 1 手", "the sub lines say the tag and its price, never 克他这招 against the target's 守: %s | %s | %s" % [panel.move_sub(&"es2:test/4"), panel.move_sub(&"es2:test/6"), panel.move_sub(&"es2:test/1")])
	check(BattleActionPanel.sub_line(CombatMoveTags.QUICK, 1, true) == "快 · 1 手" and BattleActionPanel.sub_line(CombatMoveTags.QUICK, 1, false) == "快", "sub_line: the price with the beats, the tag alone without")
	check(panel.strip_row.visible and panel.chips.slots() == ([&"", &""] as Array[StringName]) and panel._left_word.text == "还剩 2 手" and panel.yield_button.visible and not panel.yield_button.disabled, "the strip: 还剩 2 手 and two free slots; 收势 offered while the fight waits")
	check(panel.chips.earnable() and panel.chips.earn_hint() == "对方打空得 1 手", "封山's dashed slot says how a third is won: " + panel.chips.earn_hint())
	check(panel.strip_text.text == "他起手：守" and panel.ring.visible and panel.ring.marked() == CombatMoveTags.GUARD and panel.ring.lit().is_empty(), "the sentence names the target's next move, the ring rings it and lights nothing: " + panel.strip_text.text)
	# Pointing: the ghost over the slots and the sentence; the ring lights the tag's arrows.
	panel._point(&"es2:test/1")
	check(panel.chips.preview() == [2, true] and panel.strip_text.text == "空山鸟语占 2 手，出完你这回合没手了，他连出 2 手" and panel.ring.lit() == CombatMoveTags.HEAVY, "a 重 pointed at: two slots ghosted, what it costs, the ring lights 重: " + panel.strip_text.text)
	panel._unpoint(&"es2:test/1")
	check(panel.chips.preview() == [0, true] and panel.strip_text.text == "他起手：守" and panel.ring.lit().is_empty(), "pointing away clears it")
	panel._point(&"es2:test/4")
	check(panel.strip_text.text == "金光泻地占 1 手，出完还剩 1 手", "a 1-手 move: " + panel.strip_text.text)
	panel._unpoint(&"es2:test/4")
	panel.focus_quietly(panel.move_buttons[&"es2:test/1"])
	check(panel.strip_text.text == "他起手：守" and panel.chips.preview() == [0, true], "the battle's own focus on a move points at nothing: " + panel.strip_text.text)
	panel.move_buttons[&"es2:test/1"].release_focus()
	panel._point(&"es2:test/0")
	panel._move_pressed(&"es2:test/0")
	check(panel.strip_text.text == "他起手：守" and panel.chips.preview() == [0, true], "pressing the move clears the pointing")
	# The orders: the perform with its price, the exerts in one 运功 menu, 逃跑 and 投降 small at the end.
	var row: Array[String] = []
	for child: Node in panel._actions.get_children():
		row.append((child as Button).text)
	check(row == ["封字诀", "运功", "逃跑", "投降"], "the order row: the perform by its own word, 运功, then 逃跑 and 投降: %s" % str(row))
	check(panel.exert_items() == ([recover, refresh] as Array[StringName]) and not panel.exert_menu.disabled and panel.exert_menu.get_popup().is_item_disabled(1) and panel.exert_menu.get_popup().get_item_text(0) == "运功恢复气 · 1 手", "both exerts in the menu, the one that cannot run greyed: %s" % panel.exert_menu.get_popup().get_item_text(0))
	var counter: Label = panel.action_buttons[&"perform.counterattack"].get_node("Cost") as Label
	var surrender: Label = panel.action_buttons[CombatSurrenderTacticalPolicy.ACTION_ID].get_node("Cost") as Label
	check(counter.text == "2手" and surrender.text.is_empty() and panel.action_buttons[CombatSurrenderTacticalPolicy.ACTION_ID].theme_type_variation == &"ChipButton" and panel.first_action_button() == panel.action_buttons[&"perform.counterattack"], "an order's price in its corner; 投降 costs nothing and reads small; the first action is the row's first (the perform), not 逃跑")
	var chosen: Array[StringName] = []
	panel.action_requested.connect(func(id: StringName) -> void: chosen.append(id))
	panel._exert_chosen(0)
	panel._exert_chosen(1)
	check(chosen == ([recover] as Array[StringName]), "a 运功 item asks for its exert; a greyed one does nothing: %s" % str(chosen))
	check(BattleActionPanel.own_busy_of(&"perform.hasten") == 3 and BattleActionPanel.pointed_line("「玄羽乱舞」", 1, 2, -1, 3) == "「玄羽乱舞」占 1 手，出完你这回合没手了；出手后自己要忙 3 手", "玄羽乱舞 is priced 1, its busy 3 takes what is left, and it says so: " + BattleActionPanel.pointed_line("「玄羽乱舞」", 1, 2, -1, 3))
	check(BattleActionPanel.result_line(CombatEncounterScheduler.SPENT_BUSY, CombatMoveTags.GUARD) == "这一手你在忙", "a beat lost to busy reads as such")
	check(BattleActionPanel.pointed_line("「封」字诀", 2, 2, -1, 1) == "「封」字诀占 2 手，出完你这回合没手了", "a busy within the price is not mentioned")
	check(panel._queue.text == "等你出招", "the last row: 等你出招 alone: " + panel._queue.text)
	check(panel.get_combined_minimum_size().y <= 240.0 and panel.get_combined_minimum_size().x <= 1256.0, "eight moves, the orders and the ring fit 1280×720's panel: %s" % panel.get_combined_minimum_size())
	# Mid-round: a 虚 spent against his 守 (被克 on the ring), one beat left, the 重 moves 手不够
	# and a 荒山-style lock 够不着: dimmed in place, the row's order the same.
	projection.round_running = true
	projection.player_beats.spend(CombatMoveTags.FEINT, 1)
	projection.opponent_tag = CombatMoveTags.FEINT
	projection.unaffordable_moves = {&"es2:test/1": "手不够", &"es2:test/3": "手不够"}
	projection.locked_moves = {&"es2:test/2": "够不着"}
	panel.present(projection)
	check(panel.move_order() == order, "the order never changes")
	var heavy: Button = panel.move_buttons[&"es2:test/1"]
	var locked: Button = panel.move_buttons[&"es2:test/2"]
	check(heavy.disabled and panel.move_sub(&"es2:test/1") == "手不够" and heavy.tooltip_text == "手不够" and locked.disabled and panel.move_sub(&"es2:test/2") == "够不着" and not panel.move_buttons[&"es2:test/0"].disabled, "the 重 dimmed 手不够, the locked one 够不着, the 快 bright")
	check(panel.chips.slots() == ([CombatMoveTags.FEINT, &""] as Array[StringName]) and panel._left_word.text == "还剩 1 手", "the first slot took the 虚's colour, one left")
	check(panel.strip_text.text == "你出虚，他起手守 · 被克　他起手：虚", "the beat's result against the move he showed before it, then his next: " + panel.strip_text.text)
	# 战斗拍数 E: his beats spent and one left to the player — the sentence says so.
	foe.beats.spend(CombatMoveTags.QUICK, 1)
	foe.beats.spend(CombatMoveTags.QUICK, 1)
	panel.present(projection)
	check(panel.strip_text.text == "你出虚，他起手守 · 被克　他没手了，你还有 1 手　他起手：虚", "he has no move left this round, the player one: " + panel.strip_text.text)
	foe.beats = CombatRoundBeats.new(&"n", 2)
	panel.present(projection)
	panel._point(&"es2:test/1")
	check(panel.chips.preview() == [2, false] and panel.strip_text.text == "不够：空山鸟语要 2 手，你还剩 1 手", "a 重 with one left: the ghost red, the sentence says why: " + panel.strip_text.text)
	panel._unpoint(&"es2:test/1")
	check(panel.first_move_button() == panel.move_buttons[&"es2:test/0"], "the focus lands on the first move the player may press")
	# A 守 against his 虚 and a beat won: a third slot, gold-edged, from 隙; no dashed slot then.
	projection.player_beats.spend(CombatMoveTags.GUARD, 1)
	projection.player_beats.earn(CombatSchoolSkeleton.EARN_OPPONENT_MISSED, 1)
	projection.opponent_tag = CombatMoveTags.QUICK
	panel.present(projection)
	check(panel.chips.slots() == ([CombatMoveTags.FEINT, CombatMoveTags.GUARD, &""] as Array[StringName]) and panel.chips._earned == ([CombatSchoolSkeleton.EARN_OPPONENT_MISSED] as Array[StringName]) and not panel.chips.sliding() and not panel.chips.earnable(), "the won slot joins the groove (the feel off: no slide), the dashed one goes")
	check(panel.strip_text.text == "你出守，他起手虚 · 克！ · 多一手（隙）　他起手：快", "克 and the beat won: " + panel.strip_text.text)
	projection.player_beats.yield_rest()
	projection.waiting = false
	panel.present(projection)
	check(panel.chips.slots() == ([CombatMoveTags.FEINT, CombatMoveTags.GUARD, BattleBeatChips.YIELDED] as Array[StringName]) and panel.yield_button.disabled and panel._left_word.text == "没手了", "收势: the slot left struck through; nothing to give up while the round plays")
	# Between rounds: fresh slots, the dashed one back.
	projection.round_running = false
	projection.waiting = true
	projection.last_round_beats = projection.player_beats
	projection.player_beats = CombatRoundBeats.new(&"p", 2)
	panel.present(projection)
	check(panel.chips.slots() == ([&"", &""] as Array[StringName]) and panel.chips.earnable() and panel._left_word.text == "还剩 2 手", "a new round: fresh slots, the dashed one back")
	# The keys' hover: a dimmed move walked to tells why (FocusTip).
	projection.round_running = true
	projection.player_beats.spend(CombatMoveTags.QUICK, 1)
	panel.present(projection)
	var support := PadSupport.new()
	tree.root.add_child(support)
	var tip: FocusTip = support.focus_tip
	await tree.process_frame
	panel.move_buttons[&"es2:test/2"].grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await tree.process_frame
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await tree.process_frame
	tip._process(FocusTip.DELAY_SECONDS)
	check(tree.root.gui_get_focus_owner() == heavy and tip.panel.visible and tip._text.text == "手不够", "right from the last 快 lands on the dimmed 重 and the keys' hover says 手不够: '%s'" % tip._text.text)
	support.free()
	panel.free()


## 战斗拍数 B: the strip folds an actor's later beats of the round told together — two or
## more blows beyond the first beat become 「野狗又出两招 −12 闪」 standing for every line of
## those beats; a single later beat, and anyone's first beat, are told as they are.
func _folded_beats() -> void:
	var cast := BattlePresentationProjection.new(&"e", -1, &"p", &"n", [_one(&"p", "雪工", false, true, false, 80, 80, 100), _one(&"n", "野狗", true, true, true, 50, 50, 100)])
	var first := BattleNarrationLine.new("野狗咬了你。", 9, ColoredLine.PLAIN, "野狗 · 咬 → 雪工 −9").with_blow(&"n", &"p", "咬", CombatAttackResult.Outcome.HIT, 0).with_beat(1, &"n")
	var action := BattleNarrationLine.new("野狗张口又咬！").with_beat(2, &"n")
	var second := BattleNarrationLine.new("野狗咬了你。", 12, ColoredLine.PLAIN, "野狗 · 咬 → 雪工 −12").with_blow(&"n", &"p", "咬", CombatAttackResult.Outcome.HIT, 0).with_beat(2, &"n")
	var status := BattleNarrationLine.new("( 你受了点轻伤。 )").with_beat(2, &"n")
	var third := BattleNarrationLine.new("你闪开了。").with_blow(&"n", &"p", "咬", CombatAttackResult.Outcome.DODGE, -1).with_beat(3, &"n")
	var mine := BattleNarrationLine.new("你踢了野狗。", 5, ColoredLine.PLAIN, "雪工 · 踢 → 野狗 −5").with_blow(&"p", &"n", "踢", CombatAttackResult.Outcome.HIT, 0).with_beat(2, &"p")
	var folded: Array[BattleNarrationLine] = BattlePresentationController.fold_beats([first, action, second, status, third, mine], cast)
	check(folded.size() == 3 and folded[0] == first and folded[2] == mine, "the first beat and a single later beat of another stay: %d lines" % folded.size())
	check(folded.size() == 3 and folded[1].is_folded and folded[1].text == "野狗又出两招 −12 闪" and folded[1].folded.size() == 4 and folded[1].beat_index == 2 and not folded[1].has_blow, "the dog's second and third beats fold into one line standing for their four: '%s'" % (folded[1].text if folded.size() == 3 else ""))
	check(action.actor_id == &"n" and not action.has_blow, "a beat's action line carries the actor without becoming a blow")
	var lone: Array[BattleNarrationLine] = BattlePresentationController.fold_beats([first, action, second, status], cast)
	check(lone.size() == 4 and not lone[1].is_folded, "one later beat alone is told as it is")


## An enemy's card with the beats: the plan's seals (the settled beat's word, ？ for each
## read beat; the perform's word, 守 for 守势, ？ unread), the 打法词 after the forecast's word
## once known, the beats left while the round runs.
func _stamps_and_style_word(tree: SceneTree) -> void:
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	var dog: BattleParticipantProjection = _one(&"n", "柳绘心", true, true, true, 90, 100, 100)
	dog.strength = CombatForecast.Verdict.UNFAVOURED
	dog.next_move_tag = CombatMoveTags.HEAVY
	dog.beat_plan_tags = [CombatMoveTags.HEAVY, CombatMoveTags.QUICK]
	dog.beat_plan_confirmed = 1
	card.present(dog, &"p", &"n")
	check(card.stamps.first_text() == "重" and card.stamps.read_count() == 1 and card.stamps.first_settled(), "the first seal 重, solid, one ？ after it: %s / %d" % [card.stamps.first_text(), card.stamps.read_count()])
	dog.beat_plan_confirmed = 0
	card.present(dog, &"p", &"n")
	check(card.stamps.first_text() == "重" and not card.stamps.first_settled(), "the settled beat taken, the read one left: a hollow seal")
	dog.beat_plan_confirmed = 1
	check(card._title.text == "柳绘心 · 吃亏", "no 打法词 before the 见识录 knows it")
	dog.style_word = "候隙"
	dog.round_running = true
	dog.beats = CombatRoundBeats.new(&"n", 2)
	card.present(dog, &"p", &"n")
	check(card._title.text == "柳绘心 · 吃亏 · 候隙" and card.status_text() == "剩 2 手", "the 打法词 after the word; the beats left while the round runs: %s | %s" % [card._title.text, card.status_text()])
	dog.beats.spend(CombatMoveTags.HEAVY, 2)
	card.present(dog, &"p", &"n")
	check(card.status_text().is_empty(), "none left: nothing said")
	dog.next_move_known = false
	card.present(dog, &"p", &"n")
	check(card.stamps.first_text() == "？", "not read: ？ on the first seal")
	dog.next_move_known = true
	dog.next_move_guard = true
	card.present(dog, &"p", &"n")
	check(card.stamps.first_text() == "守", "守势: 守")
	dog.next_move_guard = false
	dog.beat_plan_tags = [&""]
	dog.telegraph = "「封」字诀"
	card.present(dog, &"p", &"n")
	check(card.stamps.first_text() == "封" and card.stamps.read_count() == 0, "a perform planned: its 「」 word, nothing after")
	dog.beat_plan_tags = []
	card.present(dog, &"p", &"n")
	check(card.stamps.first_text().is_empty(), "no plan: no seal")
	check(BattleParticipantCard.stamp_word(dog).is_empty(), "stamp_word of no plan")
	card.free()


## One participant with 气 current/effective/maximum, 精 and 神 50, 内力 40/60, mana `mana`,
## busy `busy` beats, CombatSliceLifeStatus `life`, enforce's `factor`, held for `knockout`.
## 战斗演出 A (DECISIONS「战斗演出 A」): the mode's word, line and shade; every card one
## height — the player's 精 · 神 and 内力 rows are an enemy's 预判 and 起手 — a chip shows the
## name and the bar only, and 了结 / 放过 lie over the lower rows without growing the card.
func _mode_looks_and_one_size(tree: SceneTree) -> void:
	var spar: BattleModeLook = BattleModeLook.of(CombatEncounterMode.Value.SPAR)
	var lethal: BattleModeLook = BattleModeLook.of(CombatEncounterMode.Value.LETHAL)
	var lesson: BattleModeLook = BattleModeLook.of(CombatEncounterMode.Value.LESSON)
	check(spar.title == "切磋" and spar.motto == "点到为止" and spar.scrim == UiPalette.SCRIM_SPAR and spar.accent == UiPalette.PATINA and not spar.outlined, "切磋: 点到为止, the light shade, patina")
	check(lethal.title == "死斗" and lethal.motto == "生死各安天命" and lethal.scrim == UiPalette.SCRIM_LETHAL and lethal.accent == UiPalette.LACQUER and lethal.outlined, "死斗: 生死各安天命, the blood-dark shade, lacquer")
	check(lesson.title == "拆招" and lesson.motto == "三合为限" and lesson.scrim == UiPalette.SCRIM_SPAR and lesson.accent == UiPalette.GOLD, "拆招: 三合为限, gold")
	check(BattleModeLook.of(CombatEncounterMode.Value.SCRIPTED).title == "交手" and BattleModeLook.of(CombatEncounterMode.Value.SCRIPTED).motto.is_empty(), "a story fight: 交手, no line")
	check(UiPalette.SCRIM_SPAR.a < UiPalette.SCRIM_LETHAL.a, "the 切磋 shade is the lighter")
	var row := HBoxContainer.new()
	tree.root.add_child(row)
	var me := BattleParticipantCard.new()
	var dog := BattleParticipantCard.new()
	var held := BattleParticipantCard.new()
	for card: BattleParticipantCard in [me, dog, held]:
		row.add_child(card)
		card.custom_minimum_size = Vector2(300, 150)
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	me.present(_one(&"p", "雪工", false, true, false, 83, 84, 100, 0, 0, 0, 3), &"p", &"n")
	var enemy: BattleParticipantProjection = _one(&"n", "野狗", true, true, true, 40, 70, 100)
	enemy.next_move_tag = CombatMoveTags.HEAVY
	dog.present(enemy, &"p", &"n")
	held.present(_one(&"k", "工匠", true, false, false, 0, 50, 100, 0, 0, CombatSliceLifeStatus.Value.UNCONSCIOUS, 0, BattleKnockoutProjection.new(3, false, false)), &"p", &"n")
	await tree.process_frame
	await tree.process_frame
	check(is_equal_approx(me.size.y, dog.size.y) and is_equal_approx(dog.size.y, held.size.y), "the player's, an enemy's and a held card are one height: %s %s %s" % [me.size.y, dog.size.y, held.size.y])
	check(dog._forecast.visible and dog._forecast.text == "深浅未明" and not dog._secondary.visible and dog._intent.visible, "an enemy's 预判 row: nothing foreseen, 深浅未明; its 起手 row")
	check(me._secondary.visible and me._powers.visible and not me._forecast.visible and not me._intent.visible, "the player's: 精 · 神 and 内力 in those rows")
	check(held.choice_row.visible and is_equal_approx(held._status.modulate.a, BattleParticipantCard.CHOICE_DIM) and is_equal_approx(held._title.modulate.a, 1.0), "了结 / 放过 over the lower rows, which dim; the name stays")
	var helper := BattleParticipantCard.new()
	row.add_child(helper)
	helper.present(_one(&"h", "天将", false, true, false, 90, 90, 100), &"p", &"n")
	check(helper._secondary.visible and helper._powers.visible and helper._title.text == "天将 · 参战", "a helper's card as the player's: 精 · 神 and 内力")
	dog.set_chip(true)
	dog.custom_minimum_size = BattleParticipantCard.CHIP_SIZE
	await tree.process_frame
	await tree.process_frame
	check(dog.is_chip() and dog._title.visible and dog._vitality.visible and not dog._primary.visible and not dog._forecast.visible and not dog._intent.visible and not dog._status.visible and not dog.stamps.visible, "a chip: the name and the bar only")
	check(dog.size.y <= BattleParticipantCard.CHIP_SIZE.y + 0.5, "a chip keeps its size: %s" % dog.size)
	dog.present(enemy, &"p", &"n")
	check(not dog._intent.visible, "a chip stays a chip when presented again")
	dog.set_chip(false)
	check(dog._intent.visible and dog._forecast.visible, "big again: the rows back")
	row.free()


static func _one(
	id: StringName, name: String, hostile: bool, available: bool, targetable: bool, kee: int, eff_kee: int, max_kee: int,
	mana: int = 0, busy: int = 0, life: int = 0, factor: int = 0, knockout: BattleKnockoutProjection = null,
) -> BattleParticipantProjection:
	return BattleParticipantProjection.new(
		id, name, &"side", hostile, &"", BattleResourceProjection.new(kee, eff_kee, max_kee),
		BattleResourceProjection.new(50, 50, 50), BattleResourceProjection.new(50, 50, 50),
		BattleResourceProjection.new(40, 60, 60), BattleResourceProjection.new(mana, mana, mana),
		BattleResourceProjection.new(0, 0, 0), busy, life, 0, available, targetable,
		CharacterState.GENDER_FEMALE if not hostile else CharacterState.GENDER_ANIMAL_MALE, &"", factor, knockout,
	)


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("battle interface: " + label)
