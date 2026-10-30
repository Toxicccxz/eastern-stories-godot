class_name DanceDefinition
extends RefCounted

## A room's do_dancing() (d/latemoon/latemoon8.c, miroom.c): the dancer's gender sets the
## sen it needs and spends before anything else (too little: `tired`, nothing spent); then a
## dance the room knows plays its line, may spend more sen and moves the dancer through
## its portal; any other dance is `clumsy` (the sen stays spent). The game offers the
## dances the player heard named (a mark each) and one dance of their own (the clumsy one);
## a dance that is its room's only way out (miroom.c's 西出阳关) is offered `always`.

class Cost:
	extends RefCounted
	var gender: String
	var at_least: int
	var sen: int


class Step:
	extends RefCounted
	## The dance's name as the room's dancing <name> (曲名), shown on its button.
	var name: String
	## The mark that makes the player know it (who taught it set it).
	var mark: String
	## Offered without the mark: the room's only way out (owner's default: no trap).
	var always: bool = false
	## receive_damage("sen") after the line (有凤来仪's 50).
	var sen: int
	var portal_id: StringName
	## message_vision(): $N dances.
	var line: String
	## Native (主线 第四章; DECISIONS「第四章 宝衣」): only a dancer of this gender dances it
	## (the 玄天玉女's steps in the second 密室); anyone else is `clumsy`, their sen spent as
	## for any dance they do not know. "" for anyone, as ES2's.
	var gender: String = ""
	## Native (第四章): not offered once the player holds this mark (the 冰匣 opened).
	var unless_mark: String = ""
	## Native (第四章): what the dance does where the player stands instead of moving them
	## (the 冰匣's lid slides open, the 宝衣 falls at their feet); null for a dance with a portal.
	var act: ScriptedAct = null


## What one dance did: refused (`tired`), the lines as the dancer reads them, the portal it
## moves them through (none for the clumsy dance) and the sen it took.
class Result:
	extends RefCounted
	var refused: bool = false
	var lines: Array[String] = []
	var portal_id: StringName = &""
	var sen_spent: int = 0
	## The dance's own act to run where the dancer stands (null: none).
	var act: ScriptedAct = null


var costs: Array[Cost] = []
var tired: String
var clumsy: String
var steps: Array[Step] = []


## The cost for a dancer of `gender`, or null (do_dancing() checks only 男性 and 女性).
func cost_for(gender: String) -> Cost:
	for cost: Cost in costs:
		if cost.gender == gender:
			return cost
	return null


## The dances `marks` know, and those offered `always`, in the room's order.
func known_steps(marks: Dictionary[String, int]) -> Array[Step]:
	var known: Array[Step] = []
	for step: Step in steps:
		if not step.unless_mark.is_empty() and marks.get(step.unless_mark, 0) != 0:
			continue
		if step.always or marks.get(step.mark, 0) != 0:
			known.append(step)
	return known


## The sen a dance would leave the dancer with (`step` null: the clumsy one); above the
## current sen when the gender's check refuses it.
func sen_after(state: CharacterState, step: Step) -> int:
	var cost: Cost = cost_for(String(state.gender))
	if cost != null and state.spirit.current < cost.at_least:
		return state.spirit.current
	return state.spirit.current - (0 if cost == null else cost.sen) - (0 if step == null else step.sen)


## do_dancing(): spends the sen and says the lines; the caller moves the dancer.
func dance(state: CharacterState, step: Step) -> Result:
	var result := Result.new()
	var cost: Cost = cost_for(String(state.gender))
	if cost != null:
		if state.spirit.current < cost.at_least:
			result.refused = true
			result.lines.append(TranslationServer.translate(tired))
			return result
		state.spirit.apply_damage(cost.sen)
		result.sen_spent += cost.sen
	# A dance of the other sex's steps is as unknown to the dancer (第四章: 不得要领).
	if step == null or (not step.gender.is_empty() and String(state.gender) != step.gender):
		result.lines.append(TranslationServer.translate(clumsy))
		return result
	# TRANSLATORS: message_vision(): the dancer ($N) as they read it.
	result.lines.append(TranslationServer.translate(step.line).replace("$N", TranslationServer.translate("你")))
	if step.sen > 0:
		state.spirit.apply_damage(step.sen)
		result.sen_spent += step.sen
	result.portal_id = step.portal_id
	result.act = step.act
	return result


## `dance`: {costs: [{gender, at_least, sen}], tired, clumsy, steps: [{name, mark, sen?,
## always?, gender?, unless_mark?, portal | act, line}]}.
static func from_record(reader: ContentRecordReader) -> DanceDefinition:
	var definition := DanceDefinition.new()
	for entry: ContentRecordReader in reader.children("costs"):
		var cost := Cost.new()
		cost.gender = entry.required_text("gender")
		cost.at_least = entry.required_integer("at_least")
		cost.sen = entry.required_integer("sen")
		entry.finish()
		definition.costs.append(cost)
	definition.tired = reader.required_text("tired")
	definition.clumsy = reader.required_text("clumsy")
	for entry: ContentRecordReader in reader.children("steps"):
		var step := Step.new()
		step.name = entry.required_text("name")
		step.mark = entry.required_text("mark")
		step.sen = entry.integer("sen")
		step.always = entry.boolean("always", false)
		step.gender = entry.text("gender")
		step.unless_mark = entry.text("unless_mark")
		var act: ContentRecordReader = entry.child("act")
		if act != null:
			step.act = ScriptedAct.from_record(act)
			if entry.has("portal"):
				entry.fail("portal", "a dance moves the dancer or acts where they stand, not both")
		else:
			step.portal_id = StringName(entry.required_text("portal"))
		step.line = entry.required_text("line")
		entry.finish()
		if step.sen < 0:
			reader.fail("steps", "a step's sen must not be negative")
		definition.steps.append(step)
	reader.finish()
	if definition.steps.is_empty():
		reader.fail("steps", "a dance floor knows at least one dance")
	return definition
