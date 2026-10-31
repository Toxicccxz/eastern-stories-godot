class_name CombatDecisionRules
extends RefCounted

## 战斗决策层 1B's knobs (DECISIONS「战斗决策」), each with ES2's value as its 经典 value: a
## record without them is ES2's auto-fight.
## - player_turns: the fight's clock waits for the player's order each round (the
##   BattlePace 自动 switch lets it roll as ES2); false (ES2): every beat on the clock.
## - npc_telegraph: an NPC's next ordinary move is drawn one beat early and its tag shown
##   (「起手」); a special it draws (perform / cast / exert) is announced one round before it
##   runs and can be interrupted. false (ES2): drawn and run on the beat.
## - stance_percent: 攻 / 守 / 游走 (CombatStance); 0 (ES2): no stances, the 加力 SpinBox.
## - stance_enforce_percent: 攻 sets enforce.c's factor to this much of its limit; 0: none.
## - perform_cooldown_rounds: the player's perform waits this many rounds before the same
##   one again; 0 (ES2): none.

var player_turns: bool = false
var npc_telegraph: bool = false
var stance_percent: int = 0
var stance_enforce_percent: int = 0
var perform_cooldown_rounds: int = 0


func _init(p_player_turns: bool = false, p_npc_telegraph: bool = false, p_stance_percent: int = 0, p_stance_enforce_percent: int = 0, p_perform_cooldown_rounds: int = 0) -> void:
	player_turns = p_player_turns
	npc_telegraph = p_npc_telegraph
	stance_percent = p_stance_percent
	stance_enforce_percent = p_stance_enforce_percent
	perform_cooldown_rounds = p_perform_cooldown_rounds


static func classic() -> CombatDecisionRules:
	return CombatDecisionRules.new()


func is_valid() -> bool:
	return stance_percent >= 0 and stance_enforce_percent >= 0 and stance_enforce_percent <= 100 and perform_cooldown_rounds >= 0


func has_stances() -> bool:
	return stance_percent > 0


func duplicate_snapshot() -> CombatDecisionRules:
	return CombatDecisionRules.new(player_turns, npc_telegraph, stance_percent, stance_enforce_percent, perform_cooldown_rounds)


static func from_record(reader: ContentRecordReader) -> CombatDecisionRules:
	var rules := CombatDecisionRules.new(
		reader.boolean("player_turns", false), reader.boolean("npc_telegraph", false),
		reader.integer("stance_percent", 0), reader.integer("stance_enforce_percent", 0),
		reader.integer("perform_cooldown_rounds", 0),
	)
	if not rules.is_valid():
		reader.fail("stance_percent", "the decision knobs must not be negative (stance_enforce_percent up to 100)")
	return rules
