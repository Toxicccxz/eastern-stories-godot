class_name NpcSparConsent
extends RefCounted

## Whether an NPC accepts a spar (cmds/std/fight.c asks obj->accept_fight(me)) and
## what it says. NPCs with their own accept_fight() carry it as rules in their
## definition; the rest follow std/char/npc.c accept_fight().
var accepted: bool = false
## Display lines in order: "<name>说道：..." or "<name><emote>".
var lines: Array[String] = []


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


static func decide(npc: NpcRuntimeState, challenger: Challenger) -> NpcSparConsent:
	var result := NpcSparConsent.new()
	var definition: NpcDefinition = npc.definition()
	var state: CharacterState = npc.character_state
	var name: String = definition.display_name
	var npc_self: String = RankWords.query_self(state.gender, npc.age, &"")
	var respect: String = RankWords.query_respect(challenger.gender, challenger.age, challenger.class_id)
	var rules: Array[NpcFightRule] = definition.fight_rules()
	if not rules.is_empty():
		for rule: NpcFightRule in rules:
			if not rule.matches(challenger.family_id, challenger.gender):
				continue
			if not rule.emote.is_empty():
				result.lines.append(name + rule.emote)
			if not rule.say.is_empty():
				result.lines.append(_say(name, rule.say.replace("$RESPECT", respect).replace("$SELF", npc_self)))
			result.accepted = rule.accept
			return result
		return result # accept_fight() fell through: it returns 0.

	var fighting: bool = npc.relationship.is_fighting()
	if fighting:
		if definition.attitude != NpcDefinition.Attitude.HEROISM:
			result.lines.append(_say(name, "想倚多为胜，这不是欺人太甚吗！"))
			return result
		result.lines.append(_say(name, "哼！出招吧！"))
	if not (_healthy(state.essence) and _healthy(state.vitality) and _healthy(state.spirit)):
		return result
	match definition.attitude:
		NpcDefinition.Attitude.FRIENDLY:
			result.lines.append(_say(name, "%s怎麽可能是%s的对手？" % [npc_self, respect]))
			return result
		NpcDefinition.Attitude.AGGRESSIVE:
			result.lines.append(_say(name, "哼！出招吧！"))
		_:
			if not fighting:
				result.lines.append(_say(name, "既然%s赐教，%s只好奉陪。" % [respect, npc_self]))
	result.accepted = true
	return result


## npc.c: query(x) * 100 / query("max_x") >= 90.
static func _healthy(resource: CharacterResourceState) -> bool:
	@warning_ignore("integer_division")
	return resource.maximum > 0 and resource.current * 100 / resource.maximum >= 90


## cmds/std/say.c as others hear it.
static func _say(name: String, text: String) -> String:
	return "%s说道：%s" % [name, text]
