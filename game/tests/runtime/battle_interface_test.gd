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


## The player's card: every track, 法力 / 灵力 only with spells (or a mana maximum), no
## 起手 line, nothing about being a target.
func _player_card(tree: SceneTree) -> void:
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	var me: BattleParticipantProjection = _one(&"p", "雪工", false, true, false, 83, 84, 100, 0, 0, 0, 3)
	card.present(me, &"p", &"n")
	check(card._title.text == "雪工 · 你", "the player's card: name · 你: " + card._title.text)
	check(card._primary.text == "气 83/84/100" and card._secondary.visible and card._secondary.text == "精 50/50/50 · 神 50/50/50", "气 on its line, 精 · 神 on the player's: %s | %s" % [card._primary.text, card._secondary.text])
	check(card._powers.visible and card._powers.text == "内力 40/60 (+3)", "no spells, no mana: 内力 alone: " + card._powers.text)
	check(card.status_text().is_empty() and not card._intent.visible, "nothing to tag, no 起手 line: '%s'" % card.status_text())
	check(card.target_button.tooltip_text.is_empty() and card.modulate == Color.WHITE, "not a target, not dimmed, no hover: '%s'" % card.target_button.tooltip_text)
	check(card._vitality.effective == 84.0 and card._vitality.max_value == 100.0 and card.vitality_shown() == 83.0, "the bar: 83 of 100, the crack from 84")
	me.has_spells = true
	card.present(me, &"p", &"n")
	check(card._powers.text == "内力 40/60 (+3) · 法力 0/0 · 灵力 0/0", "with spells mapped: 法力 and 灵力 too: " + card._powers.text)
	me.has_spells = false
	var mana: BattleParticipantProjection = _one(&"p", "雪工", false, true, false, 83, 84, 100, 20)
	card.present(mana, &"p", &"n")
	check(card._powers.text.contains("法力 20/20"), "a mana maximum shows 法力 too: " + card._powers.text)
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
	check(card._title.text == "野狗 · 占优" and card._title.tooltip_text == "占优：你比它强一些。", "the forecast's word after the name, its line on hover: " + card._title.text)
	check(not card._secondary.visible and not card._powers.visible and card._primary.text == "气 40/70/100", "an enemy: only 气: " + card._primary.text)
	check(card.status_text() == "忙 2 · 毒 · 醉", "the tags: " + card.status_text())
	check(card._intent.visible and card._intent.text == "起手：重 · 要出 「封」字诀", "起手 / 要出 on their own line: " + card._intent.text)
	var hover: String = card.target_button.tooltip_text
	check(hover.begins_with("选为目标：野狗\n占优：你比它强一些。") and hover.contains("蛇毒：") and hover.contains("醉了：") and hover.ends_with(CombatMoveTags.description(CombatMoveTags.HEAVY)), "the hover explains the word and every tag: " + hover)
	check(card._status.tooltip_text == "\n".join(BattleConditionTags.descriptions([ConditionIds.SNAKE_POISON, ConditionIds.DRUNK])), "the tags' own hover")
	check((card.get_theme_stylebox("panel") as StyleBoxFlat).border_color == BattleParticipantCard.GOLD and card.modulate == Color.WHITE, "the current target: gold, not dimmed")
	check(card._vitality.fill_color() == BattleVitalityBar.BAND_COLORS[BattleVitalityBar.Band.HEAVY] and is_equal_approx(card._vitality.crack_from(), 0.7), "40 of 100 fills orange, the crack from 70")
	# Not the target: the ordinary border. Not targetable (dead): dimmed, 死亡, no 对手 word.
	var other: BattleParticipantProjection = _one(&"m", "疯狗", true, false, false, 0, 50, 100, 0, 0, CombatSliceLifeStatus.Value.DEAD)
	card.present(other, &"p", &"n")
	check(card._title.text == "疯狗 · 对手" and card._title.tooltip_text == "疯狗 · 对手", "no forecast read: 对手")
	check((card.get_theme_stylebox("panel") as StyleBoxFlat).border_color != BattleParticipantCard.GOLD and card.modulate == BattleParticipantCard.DIM, "not the target, cannot be picked: ordinary border, dimmed")
	check(card.status_text() == "死亡" and card.target_button.tooltip_text.is_empty() and card._intent.visible and card._intent.text.is_empty(), "死亡 alone; nothing to hover; the 起手 line kept (empty) so the card does not jump: '%s'" % card.status_text())
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
	check(lines.size() >= 2 and lines[1].log_rich_text().begins_with(lines[1].summary_rich_text() + "\n[color=#8b959e][font_size=12]") and lines[1].log_rich_text().contains(lines[1].text + "（-%d）" % damage), "the log: the short form, then ES2's line with its damage grey under it")
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
	var evade: Button = panel.stance_buttons[CombatStance.Value.EVADE]
	var flee: Button = panel.first_action_button()
	check(a.tooltip_text == BattleActionPanel.move_tooltip(first) and a.text == "古松挂月 · 快", "the button carries the hover and the tag: " + a.text)
	check(a.get_node_or_null(a.focus_neighbor_right) == b and b.get_node_or_null(b.focus_neighbor_left) == a, "left and right between the moves")
	check(b.get_node_or_null(b.focus_neighbor_right) == attack and attack.get_node_or_null(attack.focus_neighbor_left) == b, "right from the last move to the first stance")
	check(evade.get_node_or_null(evade.focus_neighbor_right) == panel.manual_button and a.focus_neighbor_left.is_empty(), "the 自动 switch ends the row; the first move's left is left to Godot")
	check(a.get_node_or_null(a.focus_neighbor_bottom) == flee and panel.manual_button.get_node_or_null(panel.manual_button.focus_neighbor_bottom) == flee, "down from the row to the first quick action")
	check(flee.get_node_or_null(flee.focus_neighbor_top) == b and panel.first_move_button() == b, "up from a quick action to the chosen move, which is where the focus lands when the fight waits")
	projection.chosen_action_id = &""
	panel.present(projection)
	check(panel.first_move_button() == a, "nothing chosen: the first move")
	panel.free()


## One participant with 气 current/effective/maximum, 精 and 神 50, 内力 40/60, mana `mana`,
## busy `busy` beats, CombatSliceLifeStatus `life`, enforce's `factor`, held for `knockout`.
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
