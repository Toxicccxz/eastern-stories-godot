class_name ExertFunction
extends RefCounted

## One exert function file (exert <id>): exert() returns 1 after its effect, or
## notify_fail() and 0. The exerciser is always the target: the game offers no
## `exert <id> <target>`, so the files' "target != me" refusals never show.
var id: StringName


func exert(_context: ExertContext) -> bool:
	return false


## message_vision() as its actor sees it: $N is 你.
static func _as_actor(template: String) -> String:
	# TRANSLATORS: message_vision(): the actor of an exert line, for its $N.
	return _t(template).replace("$N", _t("你"))


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
