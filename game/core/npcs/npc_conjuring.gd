class_name NpcConjuring
extends RefCounted

## An NPC a practice conjures up against the one practising (obj/npc/mind_bug.c,
## mind_beast.c, made by necromancy.c practice_skill()). create() reads this_player():
## combat_exp is their raw level of `skill` times `combat_exp_per_level`, bellicosity
## theirs. die(): killed by its owner (last_damage_from), the owner improves `skill` by
## random(spi / spi_divisor) + 1 and reads `killed_by_owner`; killed by anyone else, the
## owner reads `killed_by_other` and falls unconscious (tell_object(): wherever they are).
var skill_id: StringName
var combat_exp_per_level: int
var spi_divisor: int
var killed_by_owner: Array[String] = []
var killed_by_other: Array[String] = []


func is_valid() -> bool:
	return not skill_id.is_empty() and combat_exp_per_level > 0 and spi_divisor > 0 and not killed_by_owner.is_empty() and not killed_by_other.is_empty()


## create()'s combat_exp for an owner with `raw_level` of the skill.
func combat_experience(raw_level: int) -> int:
	return raw_level * combat_exp_per_level


## die()'s improve_skill() amount for an owner of spirituality `spi`: random(spi / n) + 1
## (`random` is a legacy_random()).
func improvement(spi: int, random: Callable) -> int:
	@warning_ignore("integer_division")
	return random.call(spi / spi_divisor) + 1


## `conjured` {"skill", "combat_exp_per_level", "spi_divisor", "killed_by_owner": [line],
## "killed_by_other": [line]}.
static func from_record(reader: ContentRecordReader) -> NpcConjuring:
	var conjuring := NpcConjuring.new()
	conjuring.skill_id = StringName(reader.required_text("skill"))
	conjuring.combat_exp_per_level = reader.required_integer("combat_exp_per_level")
	conjuring.spi_divisor = reader.required_integer("spi_divisor")
	conjuring.killed_by_owner = reader.text_list("killed_by_owner")
	conjuring.killed_by_other = reader.text_list("killed_by_other")
	reader.finish()
	if not conjuring.is_valid():
		reader.fail("", "needs its skill, a positive combat_exp_per_level and spi_divisor, and both kinds of lines")
	return conjuring
