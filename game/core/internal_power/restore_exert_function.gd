class_name RestoreExertFunction
extends ExertFunction

## d/force/recover.c, refresh.c and regenerate.c: 20 force bring kee, sen or gin
## back by up to query_skill("force") / 3 + 10, as far as its effective value; in a
## fight the character is then busy for 1. refresh.c and regenerate.c pick the
## amount with `(heal1 - heal2) ? heal2 : heal1`, which receive_heal() caps to the
## same result as recover.c's min.
const COST: int = 20

enum Track { GIN, KEE, SEN }

var _track: Track
var _full_line: String
var _done_line: String


func _init(p_id: StringName, p_track: Track, full_line: String, done_line: String) -> void:
	id = p_id
	_track = p_track
	_full_line = full_line
	_done_line = done_line


func exert(context: ExertContext) -> bool:
	var force: CharacterInternalResourceState = context.character.recovery.inner_force
	if force.current < COST:
		context.fail_line = _t("你的内力不够。")
		return false
	var track: CharacterResourceState = _resource(context.character)
	var missing: int = track.effective - track.current
	if missing < 1:
		context.fail_line = _t(_full_line)
		return false
	@warning_ignore("integer_division")
	var most: int = context.force_level / 3 + 10
	force.current -= COST
	track.heal(mini(missing, most))
	context.lines.append(ColoredLine.new(_as_actor(_done_line)))
	if context.is_fighting:
		context.busy.start_busy(1)
	return true


func _resource(character: CharacterState) -> CharacterResourceState:
	match _track:
		Track.GIN:
			return character.essence
		Track.SEN:
			return character.spirit
	return character.vitality
