class_name ExertFunction
extends RefCounted

## One exert function file (exert <id>): exert() returns 1 after its effect, or
## notify_fail() and 0. The exerciser is the target of the files that work on oneself:
## the game offers no `exert <id> <target>` for them, so their "target != me" refusals
## never show. A file that aims at an enemy (`aims`, chillgaze.c) takes the player's
## current target as its <target>, else its own offensive_target(me).
var id: StringName
## The file refuses outside a fight whatever else holds (roar.c): the game offers it
## only in one.
var fight_only: bool = false
## The file works on another: `if( !target || target==me ) target = offensive_target(me)`.
var aims: bool = false
## The file works on the one the command names (lifeheal.c): the game offers it on the
## selected NPC (ExertService.offered_at()), never among the functions used on oneself.
var targets_other: bool = false
## The file refuses in any fight with this line (heal.c): the battle panel shows the
## action greyed with it instead of letting it fail (owner, modern fixes II).
var fight_refusal: String = ""


func exert(_context: ExertContext) -> bool:
	return false


## message_vision() as its actor sees it: $N is 你, and $P (its pronoun) too.
static func _as_actor(template: String) -> String:
	# TRANSLATORS: message_vision(): the actor of an exert line, for its $N.
	var you: String = _t("你")
	return _t(template).replace("$N", you).replace("$P", you)


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
