class_name ClassGuild
extends RefCounted

## std/room/class_guild.c do_join(): a character who has a class already is refused
## (你已经参加了其他公会。); one without takes the guild's class (fighter). Its startroom
## has no use here: Continue starts where the player saved.
enum Outcome { JOINED, REFUSED, INVALID }


static func join(state: CharacterState, class_id: StringName) -> Outcome:
	if state == null or class_id.is_empty():
		return Outcome.INVALID
	if not state.affiliation.class_id.is_empty():
		return Outcome.REFUSED
	state.affiliation.class_id = class_id
	return Outcome.JOINED
