extends RefCounted

## 战斗决策层 3 (DECISIONS「战斗演出」): the show over the battle cards — the blow behind a
## line, the move's name slammed on the attacker's card, the −N / 闪 / 挡 floating off the one
## hit, the bar stepping down by the blow, the flash and the shake by the band (off with the
## setting), the crack's flare and the gold mend, the 倒 / 亡 fall, the 起手 / 要出 pulse, the
## decision row's dim and the chosen move's bounce — and that with the feel off nothing moves
## and nothing shows. No session: cards, bars, lines and the panel alone. Rules untouched.
const Martial := preload("res://tests/runtime/snow_martial_progression_test.gd")
const Narration := preload("res://tests/runtime/battle_narration_test.gd")
const Interface := preload("res://tests/runtime/battle_interface_test.gd")
const Draws := preload("res://tests/support/scripted_combat_random_source.gd")
const Band := BattleVitalityBar.Band
const Outcome := CombatAttackResult.Outcome

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_feel_keys()
	_blow_behind_a_line()
	_cards_play_a_line(tree)
	_hit_setting_and_feel_off(tree)
	_crack_and_mend(tree)
	_fall(tree)
	_intent_pulse(tree)
	_decision_row(tree)
	BattlePace.hit_flash = true
	TestFeel.restore()
	return {"assertions": assertions, "failures": failures}


## pacing.json carries the ten durations; left out they are 0.
func _feel_keys() -> void:
	var feel: FeelDefinition = TestFeel.production
	var seconds: Array[float] = [
		feel.move_title_seconds, feel.special_title_seconds, feel.damage_float_seconds, feel.hit_shake_seconds, feel.crack_flash_seconds,
		feel.mend_seconds, feel.fall_seconds, feel.end_stamp_seconds, feel.turn_cue_seconds, feel.intent_pulse_seconds,
	]
	check(seconds == [0.7, 1.1, 0.9, 0.18, 0.4, 1.2, 0.35, 0.6, 0.22, 0.5], "pacing.json: the ten durations: %s" % [seconds])
	var off := FeelDefinition.new()
	check(off.move_title_seconds == 0.0 and off.fall_seconds == 0.0 and off.intent_pulse_seconds == 0.0, "left out: 0")


## The narrator marks a blow's own line with who, whom, the move, the outcome and the band;
## the action line and the status line carry none; a special's first line carries its name.
func _blow_behind_a_line() -> void:
	var actor := Martial.binding(&"actor")
	var target := Martial.binding(&"target")
	actor.relationship.add_opponent(&"target")
	target.relationship.add_opponent(&"actor")
	var forward := Martial.execute(actor, target, Narration.Pattern.new(), true)
	var cast := Narration._cast(&"actor", &"actor", "学徒", CharacterState.GENDER_MALE, &"target", "对手", CharacterState.GENDER_FEMALE)
	var lines: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(0)).attack_chain(forward, null, cast)
	var status: CombatStatusReportBoundaryResult = forward.ordinary_attack_result.status_report_result
	check(lines.size() >= 3 and not lines[0].has_blow and not lines[2].has_blow, "the action line and the status line are no blow")
	var hit: BattleNarrationLine = lines[1] if lines.size() >= 2 else BattleNarrationLine.new()
	check(hit.has_blow and hit.actor_id == &"actor" and hit.target_id == &"target" and hit.move == "荒山虎吟" and hit.outcome == Outcome.HIT, "the hit: who, whom, the move, HIT: %s %s %s %d" % [hit.actor_id, hit.target_id, hit.move, hit.outcome])
	check(hit.band == BattleVitalityBar.band_of_ratio(status.ratio) and hit.has_damage, "the band of the status line, the damage")
	check(not hit.is_special and hit.special_title.is_empty(), "an ordinary blow opens no special")
	var dodge := Martial.execute(Martial.binding(&"actor"), Martial.binding(&"target"), Draws.new([0, 0, 0]))
	var dodged: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(1)).attack_chain(dodge, null, cast)
	check(dodged.size() == 2 and dodged[1].has_blow and dodged[1].outcome == Outcome.DODGE and dodged[1].band == -1 and not dodged[1].has_damage, "a dodge: DODGE, no band, no damage")
	# A special: its first line names it — the caller's label, else the 「」 in the line, else 绝招.
	var report := SpecialReport.new(&"actor", [VisionLine.new("$N使出「封」字诀，剑光如网！", &"actor", &"target"), VisionLine.new("$n退了一步。", &"actor", &"target")])
	var special: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(2)).special(report, cast)
	check(special.size() == 2 and special[0].is_special and special[0].actor_id == &"actor" and special[0].special_title == "「封」" and not special[1].is_special, "the special's first line: its 「」 name: '%s'" % (special[0].special_title if not special.is_empty() else ""))
	var labelled: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(2)).special(report, cast, "傲雪冬梅")
	check(labelled[0].special_title == "傲雪冬梅", "the caller's label wins: " + labelled[0].special_title)
	var unnamed: Array[BattleNarrationLine] = BattleNarrator.new(Narration._seeded(2)).special(SpecialReport.new(&"actor", [VisionLine.new("$N运起内力。", &"actor")]), cast)
	check(unnamed[0].special_title == "绝招", "no name anywhere: 绝招")
	check(BattleNarrator.special_title("", "「封」字诀 and 「网」") == "「封」" and BattleNarrator.special_title("", "「」") == "绝招", "the first 「」, never an empty one")


## A line told plays on the cards: the attacker's title, the one hit's float, bar step, flash
## and shake; a special's title gold with the border's flash; the round's end settles the bar.
func _cards_play_a_line(tree: SceneTree) -> void:
	TestFeel.use()
	BattlePace.hit_flash = true
	var me := _card(tree)
	var dog := _card(tree)
	me.present(Interface._one(&"p", "雪工", false, true, false, 80, 80, 100), &"p", &"n")
	dog.present(Interface._one(&"n", "野狗", true, true, true, 40, 50, 50), &"p", &"n")
	check(me.stage.get_combined_minimum_size() == Vector2.ZERO and not me.stage.title.visible and not me.stage.floater.visible, "the stage takes no room and shows nothing yet")
	var bite := BattleNarrationLine.new("野狗咬了你一口。", 17, ColoredLine.PLAIN, "野狗 · 咬 → 雪工 −17 · 受伤不轻").with_blow(&"n", &"p", "咬", Outcome.HIT, Band.LIGHT)
	me.show_line(bite)
	dog.show_line(bite)
	check(dog.stage.title.visible and dog.stage.title.text == "咬" and dog.stage.title.get_theme_font_size("font_size") == BattleCardStage.TITLE_SIZE and dog.stage.title.get_theme_color("font_color") == BattleCardStage.INK, "the attacker's card: 咬 in ink: '%s'" % dog.stage.title.text)
	check(not me.stage.title.visible and not dog.stage.floater.visible, "the one hit shows no title, the attacker no float")
	check(me.stage.floater.visible and me.stage.floater.text == "−17" and me.stage.floater.get_theme_color("font_color") == BattleVitalityBar.BAND_COLORS[Band.LIGHT], "the one hit: −17 in the band's colour: '%s'" % me.stage.floater.text)
	check(me._shown_vitality == 63 and me.vitality_shown() > 63.0 and me._primary.text == "气 63/80/100", "the bar steps down by the blow (on its way), the line with it: %s %.1f" % [me._primary.text, me.vitality_shown()])
	check(me.self_modulate != Color.WHITE and me._shake != null and me._shake.is_valid(), "the flash and the shake")
	# The round's end: the projection's 气 (the same number): nothing moves again.
	me._shake.kill()
	me.self_modulate = Color.WHITE
	me.present(Interface._one(&"p", "雪工", false, true, false, 63, 80, 100), &"p", &"n")
	check(me._shown_vitality == 63 and me.self_modulate == Color.WHITE and not me._shake.is_valid(), "settled to the projection: no second flash or shake")
	# A dodge, a parry, a hit that drew nothing: grey words, no bar step.
	me.show_line(BattleNarrationLine.new("你闪开了。").with_blow(&"n", &"p", "咬", Outcome.DODGE, -1))
	check(me.stage.floater.visible and me.stage.floater.text == "闪" and me.stage.floater.get_theme_color("font_color") == BattleCardStage.GREY and me._shown_vitality == 63, "a dodge: 闪 in grey, the bar as it was")
	me.show_line(BattleNarrationLine.new("你挡开了。").with_blow(&"n", &"p", "咬", Outcome.PARRY, -1))
	check(me.stage.floater.text == "挡", "a parry: 挡")
	me.show_line(BattleNarrationLine.new("没伤到。").with_blow(&"n", &"p", "咬", Outcome.HIT, -1))
	check(me.stage.floater.text == "无伤" and me._shown_vitality == 63, "a hit without 气 drawn: 无伤, no step")
	# A blow without a band (the felling blow): the band of what the bar would show.
	me.show_line(BattleNarrationLine.new("野狗咬了你一口。", 50).with_blow(&"n", &"p", "咬", Outcome.HIT, -1))
	check(me.stage.floater.text == "−50" and me.stage.floater.get_theme_color("font_color") == BattleVitalityBar.BAND_COLORS[Band.DYING] and me._shown_vitality == 13, "no band: the one the bar reaches (13 of 100: 濒死)")
	# A special: gold, larger, the border flashes; the one it hit floats as for any blow.
	var special := BattleNarrationLine.new("野狗使出「封」字诀！").with_special(&"n", "「封」字诀")
	dog.show_line(special)
	check(dog.stage.title.visible and dog.stage.title.text == "「封」字诀" and dog.stage.title.get_theme_font_size("font_size") == BattleCardStage.SPECIAL_SIZE and dog.stage.title.get_theme_color("font_color") == BattleCardStage.GOLD, "a special: its name in gold, larger")
	check(dog.get_theme_stylebox("panel") == dog._special_border, "the border flashes pale gold")
	dog._border_flash.kill()
	dog.present(Interface._one(&"n", "野狗", true, true, true, 40, 50, 50), &"p", &"n")
	check(dog.get_theme_stylebox("panel") == dog._current_border, "then the target's gold border again")
	# A line about others: nothing on this card.
	me.stage.clear()
	me.show_line(BattleNarrationLine.new("x").with_blow(&"n", &"z", "咬", Outcome.HIT, Band.LIGHT))
	check(not me.stage.title.visible and not me.stage.floater.visible and me._shown_vitality == 13, "someone else hit: nothing here")
	me.free()
	dog.free()
	TestFeel.restore()


## 受击闪红 off: no flash, no shake, the float still (it is information); the feel off: no
## title, no float, the bar at once, nothing tweens.
func _hit_setting_and_feel_off(tree: SceneTree) -> void:
	TestFeel.use()
	var me := _card(tree)
	me.present(Interface._one(&"p", "雪工", false, true, false, 80, 80, 100), &"p", &"n")
	BattlePace.hit_flash = false
	me.show_line(BattleNarrationLine.new("野狗咬了你一口。", 17).with_blow(&"n", &"p", "咬", Outcome.HIT, Band.LIGHT))
	check(me.self_modulate == Color.WHITE and me._shake == null and me.stage.floater.visible and me._shown_vitality == 63, "受击闪红 off: no flash, no shake; the −17 and the bar step stay")
	BattlePace.hit_flash = true
	TestFeel.restore()
	var dog := _card(tree)
	dog.present(Interface._one(&"n", "野狗", true, true, true, 40, 50, 50), &"p", &"n")
	var bite := BattleNarrationLine.new("野狗咬了你一口。", 10).with_blow(&"n", &"p", "咬", Outcome.HIT, Band.LIGHT)
	dog.show_line(bite)
	me.show_line(bite)
	check(not dog.stage.title.visible and not me.stage.floater.visible and me.vitality_shown() == 53.0 and me._shake == null, "the feel off: no title, no float, the bar at once, no shake")
	me.free()
	dog.free()


## The bar: a new wound's stretch flares and settles; a healed stretch carries a gold line
## that fades; the crack itself is where it was; the feel off: nothing.
func _crack_and_mend(tree: SceneTree) -> void:
	TestFeel.use()
	var bar := BattleVitalityBar.new()
	tree.root.add_child(bar)
	bar.max_value = 100
	bar.effective = 100
	bar.value = 100
	check(bar.flash_alpha == 0.0 and bar.mend_alpha == 0.0, "whole: nothing flares")
	bar.effective = 80
	check(bar.flash_alpha == 1.0 and is_equal_approx(bar._flash_from, 0.8) and is_equal_approx(bar._flash_to, 1.0) and is_equal_approx(bar.crack_from(), 0.8), "a wound: the stretch 80–100 flares, the crack from 80")
	check(bar._flash_tween != null and bar._flash_tween.is_valid() and bar.mend_alpha == 0.0, "settling over crack_flash_ms; no mend")
	bar.effective = 90
	check(bar.mend_alpha == 1.0 and is_equal_approx(bar._mend_from, 0.8) and is_equal_approx(bar._mend_to, 0.9) and is_equal_approx(bar.crack_from(), 0.9), "healed to 90: the gold line over 80–90, the crack from 90")
	bar.free()
	TestFeel.restore()
	var still := BattleVitalityBar.new()
	tree.root.add_child(still)
	still.max_value = 100
	still.effective = 100
	still.effective = 70
	still.effective = 80
	check(still.flash_alpha == 0.0 and still.mend_alpha == 0.0 and is_equal_approx(still.crack_from(), 0.8), "the feel off: the crack moves, nothing flares or mends")
	still.free()


## The fall: 倒 for one unconscious or held, 亡 for one dead, the card tilted; up again: no
## stamp, straight; someone else on the card: cleared.
func _fall(tree: SceneTree) -> void:
	TestFeel.use()
	var card := _card(tree)
	card.present(Interface._one(&"n", "野狗", true, true, true, 40, 50, 50), &"p", &"n")
	check(card.fallen_text().is_empty() and not card.stage.stamp.visible and card.rotation == 0.0, "standing: no stamp")
	card.present(Interface._one(&"n", "野狗", true, false, false, 0, 50, 50, 0, 0, CombatSliceLifeStatus.Value.UNCONSCIOUS), &"p", &"n")
	check(card.fallen_text() == "倒" and card.stage.stamp.visible and card.stage.stamp.text == "倒" and card._fall != null and card._fall.is_valid(), "unconscious: 倒, the card falling")
	card.present(Interface._one(&"n", "野狗", true, false, false, 0, 50, 50, 0, 0, CombatSliceLifeStatus.Value.DEAD), &"p", &"n")
	check(card.fallen_text() == "亡" and card.stage.stamp.text == "亡", "dead: 亡")
	card.present(Interface._one(&"n", "野狗", true, true, true, 20, 50, 50), &"p", &"n")
	check(card.fallen_text().is_empty() and not card.stage.stamp.visible and card.rotation == 0.0 and card.stage.veil_alpha == 0.0, "up again: no stamp, straight, no veil")
	var held: BattleParticipantProjection = Interface._one(&"k", "工匠", true, false, false, 0, 50, 100, 0, 0, CombatSliceLifeStatus.Value.UNCONSCIOUS, 0, BattleKnockoutProjection.new(3, false, false))
	card.present(held, &"p", &"n")
	check(card.fallen_text() == "倒" and card.choice_row.visible and card.stage.stamp.visible, "one held for 了结 / 放过: 倒 under the choice")
	card.show_final_fall("亡")
	check(card.fallen_text() == "亡", "a finished fight's last blow: the stamp without a refresh")
	card.present(Interface._one(&"m", "疯狗", true, true, true, 40, 50, 50), &"p", &"n")
	check(card.fallen_text().is_empty() and not card.stage.stamp.visible, "someone else on the card: cleared")
	TestFeel.restore()
	card.present(Interface._one(&"m", "疯狗", true, false, false, 0, 50, 50, 0, 0, CombatSliceLifeStatus.Value.DEAD), &"p", &"n")
	check(card.fallen_text() == "亡" and card.stage.stamp.visible and card.stage.veil_alpha == 1.0 and card.rotation > 0.0 and (card._fall == null or not card._fall.is_valid()), "the feel off: the stamp and the tilt at once, no tween")
	card.free()


## The 起手 / 要出 line flashes when its text changes (white for a 要出), not when it stays.
func _intent_pulse(tree: SceneTree) -> void:
	TestFeel.use()
	var card := _card(tree)
	var dog: BattleParticipantProjection = Interface._one(&"n", "野狗", true, true, true, 40, 50, 50)
	dog.next_move_tag = CombatMoveTags.HEAVY
	card.present(dog, &"p", &"n")
	check(card.intent_color() == BattleParticipantCard.INTENT_FLASH and card._intent_pulse != null and card._intent_pulse.is_valid(), "a new 起手: the line flashes pale gold")
	card._intent_pulse.kill()
	card._intent.add_theme_color_override("font_color", BattleParticipantCard.INTENT_COLOR)
	card.present(dog, &"p", &"n")
	check(card.intent_color() == BattleParticipantCard.INTENT_COLOR, "the same 起手 again: no flash")
	dog.telegraph = "「封」字诀"
	card.present(dog, &"p", &"n")
	check(card.intent_color() == BattleParticipantCard.TELEGRAPH_FLASH, "a 要出: white")
	TestFeel.restore()
	dog.telegraph = ""
	dog.next_move_tag = CombatMoveTags.QUICK
	card.present(dog, &"p", &"n")
	check(card.intent_color() == BattleParticipantCard.INTENT_COLOR and (card._intent_pulse == null or not card._intent_pulse.is_valid()), "the feel off: gold at once")
	card.free()


## The decision row dims while the round plays and is bright while the fight waits; the
## chosen move bounces when asked (not with 0).
func _decision_row(tree: SceneTree) -> void:
	var panel := BattleActionPanel.new()
	tree.root.add_child(panel)
	var move := CombatActionDefinition.new(&"es2:test/a", 0, 0, &"瘀伤", &"a", "$N一拳", "", &"", CombatMoveTags.QUICK, "挥拳")
	var projection := BattlePresentationProjection.new(&"e", CombatEncounterMode.Value.LETHAL, &"p", &"n", [Interface._one(&"p", "雪工", false, true, false, 80, 80, 100)], [])
	projection.moves = [move]
	projection.turns_offered = true
	projection.manual = true
	projection.waiting = false
	panel.present(projection)
	check(is_equal_approx(panel.stance_row.modulate.r, BattleActionPanel.PLAYING_DIM), "the round plays: the row dimmed")
	projection.waiting = true
	panel.present(projection)
	check(panel.stance_row.modulate == Color.WHITE, "waiting: bright")
	panel.bounce_chosen(0.0)
	check(panel._bounce == null, "0: no bounce")
	panel.bounce_chosen(0.22)
	check(panel._bounce != null and panel._bounce.is_valid() and panel.first_move_button().pivot_offset != Vector2.ZERO, "the chosen move bounces about its centre")
	projection.manual = false
	projection.waiting = false
	panel.present(projection)
	check(panel.stance_row.modulate == Color.WHITE, "自动: never dimmed")
	panel.free()


func _card(tree: SceneTree) -> BattleParticipantCard:
	var card := BattleParticipantCard.new()
	tree.root.add_child(card)
	card.size = Vector2(300, 160)
	return card


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("battle stagecraft: " + label)
