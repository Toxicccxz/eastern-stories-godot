class_name PersonPortraits
extends RefCounted

## The people's 立绘 (DECISIONS「人物外观」): flat-colour pixel pictures without outlines, one set
## per person by NPC definition id (the player's `player.male` / `player.female`), under
## res://assets/portraits/: `<id>_full.png` (128×256, the 查看 popup) and `<id>_bust.png`
## (128×128, the dialogue box; an NPC's turned to the left, the player's to the right), some with
## `<id>_bust_smile.png` and `<id>_bust_angry.png`. Someone without one shows none.

const DIR: String = "res://assets/portraits/"
const FULL: String = "full"
const BUST: String = "bust"
## The pictures' own sizes: shown at whole multiples only, so every pixel stays square.
const FULL_SIZE := Vector2i(128, 256)
const BUST_SIZE := Vector2i(128, 128)

static var _cache: Dictionary = {}


## `<id>_<kind>`'s picture, or null.
static func texture(id: String, kind: String) -> Texture2D:
	var path: String = "%s%s_%s.png" % [DIR, id, kind]
	if _cache.has(path):
		return _cache[path]
	var found: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[path] = found
	return found


static func full(id: String) -> Texture2D:
	return texture(id, FULL)


## The bust with `expression` ("smile", "angry"), else the plain one.
static func bust(id: String, expression: String = "") -> Texture2D:
	if not expression.is_empty():
		var face: Texture2D = texture(id, "%s_%s" % [BUST, expression])
		if face != null:
			return face
	return texture(id, BUST)


## The player's pictures' id by their gender (CharacterState's).
static func player_id(gender: String) -> String:
	return "player.female" if gender == CharacterState.GENDER_FEMALE else "player.male"


## The id an NPC's pictures go by: its definition's, without a spawn's number.
static func npc_id(npc: NpcRuntimeState) -> String:
	return "" if npc == null else String(NpcDefinition.unnamed_id(npc.definition().definition_id))


## The face an NPC talks with: smiling when friendly (ES2 attitude "friendly"), angry when it
## attacks on sight ("aggressive", "killer"), else its plain one.
static func expression(npc: NpcRuntimeState) -> String:
	if npc == null:
		return ""
	match npc.definition().attitude:
		NpcDefinition.Attitude.FRIENDLY:
			return "smile"
		NpcDefinition.Attitude.AGGRESSIVE, NpcDefinition.Attitude.KILLER:
			return "angry"
	return ""


## The largest whole multiple of `native` (picture pixels) that fits `room` (screen pixels) at
## the canvas's `scale` (screen pixels per canvas unit), at least 1; returned in canvas units.
static func fitted(native: Vector2i, room: Vector2, scale: float) -> Vector2:
	var times: int = maxi(1, floori(minf(room.x / native.x, room.y / native.y) + 0.001))
	return Vector2(native) * times / maxf(scale, 0.001)
