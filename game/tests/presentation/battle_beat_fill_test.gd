extends RefCounted

## 节拍填格 (DECISIONS「节拍填格」): a move pressed sends its beat from its button into the strip
## and fills its slot. The feel's duration (left out = 0); the fill's phases (the bar flies, then
## the slot fills from the left, then flashes) and its end; no time = nothing shown; clear() stops
## it; the strip holding a pressed move's slots until the round's record has them, a new round
## comes or a while passes. Rules, numbers and the fight's draws are untouched.

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_feel_key()
	_phases()
	await _fill(tree)
	await _hold(tree)
	return {"assertions": assertions, "failures": failures}


## pacing.json: 0.45 s, short enough that the slot is full before the beat's lines are told.
func _feel_key() -> void:
	check(is_equal_approx(TestFeel.production.beat_fill_seconds, 0.45), "pacing.json: %s s" % TestFeel.production.beat_fill_seconds)
	check(FeelDefinition.new().beat_fill_seconds == 0.0, "left out: 0")
	check(TestFeel.production.beat_fill_seconds <= 0.5, "short")


## The bar flies first (nothing filled), then the slot fills from the left to full; the bar starts
## on the button and ends in the slot, as tall as it.
func _phases() -> void:
	check(BattleBeatFill.fill_share(0.0) == 0.0 and BattleBeatFill.fill_share(BattleBeatFill.TRAVEL) == 0.0, "while the bar flies nothing is filled")
	check(BattleBeatFill.fill_share(0.6) > 0.0 and BattleBeatFill.fill_share(0.6) < 1.0, "then it fills: %s" % BattleBeatFill.fill_share(0.6))
	check(BattleBeatFill.fill_share(BattleBeatFill.FLASH) == 1.0 and BattleBeatFill.fill_share(1.0) == 1.0, "full before the flash")
	check(BattleBeatFill.fill_share(0.55) < BattleBeatFill.fill_share(0.7), "it only grows")
	var button := Rect2(300, 600, 150, 60)
	var slot := Rect2(120, 400, 96, 44)
	var start: Rect2 = BattleBeatFill.bar_at(button, slot, 0.0)
	var end: Rect2 = BattleBeatFill.bar_at(button, slot, BattleBeatFill.TRAVEL)
	check(button.encloses(start), "the bar lifts off the button: %s" % start)
	check(end.position == slot.position and end.size.y == slot.size.y, "and lands at the slot's left, as tall as it: %s" % end)


## No time: nothing shown. A fill plays, says `finished` once at its end and is gone; clear() stops
## one under way without a word.
func _fill(tree: SceneTree) -> void:
	var fill := BattleBeatFill.new()
	tree.root.add_child(fill)
	var done: Array[int] = []
	fill.finished.connect(func() -> void: done.append(1))
	check(not fill.play(Rect2(0, 100, 150, 60), Rect2(0, 0, 96, 44), Color.RED, "重", 0.0) and not fill.playing(), "the feel off: no fill")
	check(fill.play(Rect2(0, 100, 150, 60), Rect2(0, 0, 202, 44), Color.RED, "重", 0.4) and fill.playing() and fill.is_processing(), "a fill plays")
	fill.advance(0.2)
	check(fill.playing() and is_equal_approx(fill.progress(), 0.5) and done.is_empty(), "half way")
	fill.advance(0.25)
	check(not fill.playing() and done == [1] and not fill.is_processing(), "full, finished once, nothing ticking")
	fill.play(Rect2(0, 100, 150, 60), Rect2(0, 0, 96, 44), Color.BLUE, "快", 0.4)
	fill.clear()
	check(not fill.playing() and done == [1], "cleared: gone, no word")
	fill.queue_free()
	await tree.process_frame


## The strip holds a pressed move's slots (a 重 two) from the press; the record catching up lets them
## go, so does a new round or PENDING_SECONDS; a second press waits for the first.
func _hold(tree: SceneTree) -> void:
	var chips := BattleBeatChips.new()
	tree.root.add_child(chips)
	var rules: CombatBeatRules = GameContent.catalog().pacing().beat_rules()
	var beats := CombatRoundBeats.new(&"p", 2)
	chips.present(beats, rules, 0.0)
	check(chips.hold(CombatMoveTags.HEAVY, 2) == ([0, 2] as Array[int]) and chips.pending_count() == 2, "a 重 pressed: two slots held from the first")
	check(chips._shown_slots() == ([CombatMoveTags.HEAVY, CombatMoveTags.HEAVY] as Array[StringName]) and chips.slots() == ([&"", &""] as Array[StringName]), "drawn spent while the record still has them free")
	check(chips.hold(CombatMoveTags.QUICK, 1).is_empty(), "a second press waits for the first")
	beats.spend(CombatMoveTags.HEAVY, 2)
	chips.present(beats, rules, 0.0)
	check(chips.pending_count() == 0 and not chips.is_processing(), "the record has them: the hold goes")
	var next := CombatRoundBeats.new(&"p", 2)
	chips.present(next, rules, 0.0)
	check(chips.hold(CombatMoveTags.QUICK, 1) == ([0, 1] as Array[int]), "a 快 in the new round: the first slot")
	next.spend(CombatMoveTags.FEINT, 1)
	chips.present(next, rules, 0.0)
	check(chips.pending_count() == 0, "the record has a beat there: the hold goes")
	check(chips.hold(CombatMoveTags.QUICK, 1) == ([1, 1] as Array[int]), "the next press takes the slot after")
	chips.present(CombatRoundBeats.new(&"p", 2), rules, 0.0)
	check(chips.pending_count() == 0, "a new round: the hold goes")
	chips.hold(CombatMoveTags.QUICK, 1)
	chips._process(BattleBeatChips.PENDING_SECONDS + 0.1)
	check(chips.pending_count() == 0 and not chips.is_processing(), "a hold the record never shows goes after %s s" % BattleBeatChips.PENDING_SECONDS)
	check(chips.slot_rect(1).position.x > chips.slot_rect(0).end.x and chips.slot_rect(0, 2).end.x == chips.slot_rect(1).end.x, "slot rects: one after another, a run of two as wide as both")
	chips.queue_free()
	await tree.process_frame


func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
