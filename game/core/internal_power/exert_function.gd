class_name ExertFunction
extends RefCounted

## One exert function file (exert <id>): exert() returns 1 after its effect, or
## notify_fail() and 0. The exerciser is always the target: the game offers no
## `exert <id> <target>`, so the files' "target != me" refusals never show.
var id: StringName
## The file refuses outside a fight whatever else holds (roar.c): the game offers it
## only in one.
var fight_only: bool = false
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
