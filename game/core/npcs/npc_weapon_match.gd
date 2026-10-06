class_name NpcWeaponMatch
extends RefCounted

## 萧辟尘's consider() (daemon/class/fighter/master.c), one of his chat_msg_combat
## functions: when an enemy still standing (living()) holds a weapon and he holds
## none, he says so to the first such enemy, wields his own (command("wield sword"))
## and invites the attack; when no standing enemy holds one and he does, he says he
## will fight bare-handed too and puts it away (command("unwield sword")). The lines
## are say()s: {respect} is RANK_D->query_respect() of that first armed enemy, or of
## the first enemy when he puts his weapon away; {count} is chinese_number() of all
## his enemies (query_enemy(), those lying down too).
enum Change { NONE, WIELD, UNWIELD }

## The weapon he takes up or puts away: a carried one of this skill type ("sword").
var weapon_type: StringName
var armed_says: Array[String] = []
var unarmed_say: String = ""
var unarmed_many_say: String = ""


class Enemy:
	extends RefCounted
	var standing: bool
	var armed: bool
	var respect: String

	func _init(p_standing: bool, p_armed: bool, p_respect: String) -> void:
		standing = p_standing
		armed = p_armed
		respect = p_respect


class Decision:
	extends RefCounted
	var change: Change = Change.NONE
	## The say() lines, filled in.
	var says: Array[String] = []


func is_valid() -> bool:
	return SkillUseIds.is_enable_command_use(weapon_type) and not armed_says.is_empty() and not unarmed_say.is_empty() and not unarmed_many_say.is_empty()


## `enemies` in query_enemy() order, their `respect` in the shown language; the
## lines come back in it too.
func decide(enemies: Array[Enemy], holds_weapon: bool) -> Decision:
	var decision := Decision.new()
	var armed: int = 0
	for enemy: Enemy in enemies:
		if not enemy.standing or not enemy.armed:
			continue
		armed += 1
		if not holds_weapon:
			for line: String in armed_says:
				decision.says.append(_t(line).format({"respect": enemy.respect}))
			decision.change = Change.WIELD
			return decision
	if armed == 0 and holds_weapon and not enemies.is_empty():
		if enemies.size() > 1:
			decision.says.append(_t(unarmed_many_say).format({"count": ChineseNumber.of(enemies.size())}))
		else:
			decision.says.append(_t(unarmed_say).format({"respect": enemies[0].respect}))
		decision.change = Change.UNWIELD
	return decision


## {"action": "match_weapon", "weapon": skill type, "armed": [lines], "unarmed": [line],
## "unarmed_many": [line]} (each line list holds what the source says, in order).
static func from_record(reader: ContentRecordReader) -> NpcWeaponMatch:
	var value := NpcWeaponMatch.new()
	value.weapon_type = StringName(reader.required_text("weapon"))
	if not SkillUseIds.is_enable_command_use(value.weapon_type):
		reader.fail("weapon", "not a skill_type enable.c knows")
	value.armed_says.assign(reader.text_list("armed"))
	var unarmed: Array[String] = reader.text_list("unarmed")
	var many: Array[String] = reader.text_list("unarmed_many")
	if value.armed_says.is_empty() or unarmed.size() != 1 or many.size() != 1:
		reader.fail("", "needs its armed lines and one unarmed and one unarmed_many line")
	else:
		value.unarmed_say = unarmed[0]
		value.unarmed_many_say = many[0]
	return value


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
