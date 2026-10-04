class_name VisionLine
extends RefCounted

## One line as message_vision() (adm/simul_efun/message.c) has it, before anyone reads
## it: the source text (`template`, untranslated), $N being `actor_id`, $n `target_id`
## and $P/$p their pronouns, in its ES2 colour. `slots` fill {name} slots with authored
## words (rankd.c's), translated when shown. Presentation shows it as the player sees
## it (BattleNarrator.vision()). A line with `status_ratio` >= 0 is combatd.c
## report_status() for `actor_id`: kee * 100 / max_kee, worded when shown.
var template: String
var actor_id: StringName
var target_id: StringName
var color: StringName
var slots: Dictionary[String, String] = {}
var status_ratio: int = -1


func _init(
	p_template: String = "", p_actor_id: StringName = &"", p_target_id: StringName = &"",
	p_color: StringName = ColoredLine.PLAIN,
) -> void:
	template = p_template
	actor_id = p_actor_id
	target_id = p_target_id
	color = p_color


## combatd.c report_status(ob): how `character` looks now (kee against max kee).
static func status(character_id: StringName, kee: int, max_kee: int) -> VisionLine:
	var line := VisionLine.new("", character_id)
	@warning_ignore("integer_division")
	line.status_ratio = 0 if max_kee <= 0 else kee * 100 / max_kee
	return line


func is_status() -> bool:
	return status_ratio >= 0
