class_name NpcSparConsent
extends RefCounted

## Whether an NPC accepts a spar (cmds/std/fight.c asks obj->accept_fight(me)) and
## what it says. NPCs with their own accept_fight() carry it as rules in their
## definition; the rest follow std/char/npc.c accept_fight(). The runtime turns
## the lines into sentences; $RESPECT and $SELF stand for rankd.c's words.
var accepted: bool = false
## Accepted with kill_ob(): the NPC fights to kill (NpcFightRule.kill).
var kill: bool = false
var lines: Array[Line] = []
## How the NPC addresses the challenger (query_respect) and calls itself (query_self).
var respect: String = ""
var npc_self: String = ""


## The NPC says `text` (say.c), or does the emote `text` after its name.
class Line:
	extends RefCounted
	var emote: bool
	var text: String

	func _init(p_emote: bool = false, p_text: String = "") -> void:
		emote = p_emote
		text = p_text


## Who asks: gender, age and class give the words rankd.c picks; family and gender
## are what per-NPC rules test.
class Challenger:
	extends RefCounted
	var gender: StringName
	var age: int
	var class_id: StringName
	var family_id: StringName

	func _init(p_gender: StringName = &"", p_age: int = 0, p_class_id: StringName = &"", p_family_id: StringName = &"") -> void:
		gender = p_gender
		age = p_age
		class_id = p_class_id
		family_id = p_family_id


## `attitude`: query("attitude") as asked now, for an NPC whose attitude is a function
## drawn each time (kid2.c); -1 takes the definition's.
static func decide(npc: NpcRuntimeState, challenger: Challenger, attitude: int = -1) -> NpcSparConsent:
	var result := NpcSparConsent.new()
	var definition: NpcDefinition = npc.definition()
	var att: int = definition.attitude if attitude < 0 else attitude
	var state: CharacterState = npc.character_state
	result.npc_self = RankWords.query_self(state.gender, npc.age, &"")
	result.respect = RankWords.query_respect(challenger.gender, challenger.age, challenger.class_id)
	var rules: Array[NpcFightRule] = definition.fight_rules()
	if not rules.is_empty():
		for rule: NpcFightRule in rules:
			if not rule.matches(challenger.family_id, challenger.gender):
				continue
			if not rule.emote.is_empty():
				result.lines.append(Line.new(true, rule.emote))
			if not rule.say.is_empty():
				result.lines.append(Line.new(false, rule.say))
			result.accepted = rule.accept
			result.kill = rule.accept and rule.kill
			return result
		return result # accept_fight() fell through: it returns 0.

	var fighting: bool = npc.relationship.is_fighting()
	if fighting:
		if att != NpcDefinition.Attitude.HEROISM:
			result.lines.append(Line.new(false, "想倚多为胜，这不是欺人太甚吗！"))
			return result
		result.lines.append(Line.new(false, "哼！出招吧！"))
	if not (_healthy(state.essence) and _healthy(state.vitality) and _healthy(state.spirit)):
		return result
	match att:
		NpcDefinition.Attitude.FRIENDLY:
			result.lines.append(Line.new(false, "$SELF怎麽可能是$RESPECT的对手？"))
			return result
		NpcDefinition.Attitude.AGGRESSIVE:
			result.lines.append(Line.new(false, "哼！出招吧！"))
		_:
			if not fighting:
				result.lines.append(Line.new(false, "既然$RESPECT赐教，$SELF只好奉陪。"))
	result.accepted = true
	return result


## npc.c: query(x) * 100 / query("max_x") >= 90.
static func _healthy(resource: CharacterResourceState) -> bool:
	@warning_ignore("integer_division")
	return resource.maximum > 0 and resource.current * 100 / resource.maximum >= 90
