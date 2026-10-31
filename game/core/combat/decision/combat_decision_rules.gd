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
## 战斗决策层 4 (DECISIONS「战斗内容」):
## - npc_special_cooldown_rounds: after an NPC's special ran, a special its chat() draws
##   within this many rounds is not announced or run (the draw itself is taken as npc.c
##   does); an NPC's fight style (CombatStyle) may set its own. 0 (ES2): none.
## - recognise_after: the player reads an enemy move's tag (起手) once it has been used this
##   many times in fights the player was in (MoveRecognition); the player's own schools'
##   moves are known. 0 (ES2): every tag is known.

var player_turns: bool = false
var npc_telegraph: bool = false
var stance_percent: int = 0
var stance_enforce_percent: int = 0
var perform_cooldown_rounds: int = 0
var npc_special_cooldown_rounds: int = 0
var recognise_after: int = 0


func _init(p_player_turns: bool = false, p_npc_telegraph: bool = false, p_stance_percent: int = 0, p_stance_enforce_percent: int = 0, p_perform_cooldown_rounds: int = 0, p_npc_special_cooldown_rounds: int = 0, p_recognise_after: int = 0) -> void:
	player_turns = p_player_turns
	npc_telegraph = p_npc_telegraph
	stance_percent = p_stance_percent
	stance_enforce_percent = p_stance_enforce_percent
	perform_cooldown_rounds = p_perform_cooldown_rounds
	npc_special_cooldown_rounds = p_npc_special_cooldown_rounds
	recognise_after = p_recognise_after


static func classic() -> CombatDecisionRules:
	return CombatDecisionRules.new()


func is_valid() -> bool:
	return stance_percent >= 0 and stance_enforce_percent >= 0 and stance_enforce_percent <= 100 and perform_cooldown_rounds >= 0 and npc_special_cooldown_rounds >= 0 and recognise_after >= 0


func has_stances() -> bool:
	return stance_percent > 0


## Whether the NPCs' fight styles (weights, cooldowns) are read: the modern decision layer
## (the telegraph draws the move they weigh).
func uses_styles() -> bool:
	return npc_telegraph


func duplicate_snapshot() -> CombatDecisionRules:
	return CombatDecisionRules.new(player_turns, npc_telegraph, stance_percent, stance_enforce_percent, perform_cooldown_rounds, npc_special_cooldown_rounds, recognise_after)


static func from_record(reader: ContentRecordReader) -> CombatDecisionRules:
	var rules := CombatDecisionRules.new(
		reader.boolean("player_turns", false), reader.boolean("npc_telegraph", false),
		reader.integer("stance_percent", 0), reader.integer("stance_enforce_percent", 0),
		reader.integer("perform_cooldown_rounds", 0), reader.integer("npc_special_cooldown_rounds", 0),
		reader.integer("recognise_after", 0),
	)
	if not rules.is_valid():
		reader.fail("stance_percent", "the decision knobs must not be negative (stance_enforce_percent up to 100)")
	return rules
