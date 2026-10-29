class_name DeedLog
extends RefCounted

## Native (任务系统, 剧情总纲 §7「事迹记录」; DECISIONS「任务系统」): the thinnest record of
## what the player did: who did what, where, and who saw it. One place reports
## (WorldDeeds.report); reputation, titles and the ending's telling grow from here later.
## Kept in CharacterState.deeds in the order they happened; saved.


class Deed:
	extends RefCounted
	## What was done, as authored (StoryQuestDefinition.Reward.deed).
	var did: String = ""
	## The zone it happened in; "" when nowhere in particular.
	var where: StringName = &""
	## The NPC definitions that stood there awake, in a stable order.
	var seen_by: Array[StringName] = []

	func _init(p_did: String = "", p_where: StringName = &"", p_seen_by: Array[StringName] = []) -> void:
		did = p_did
		where = p_where
		seen_by = p_seen_by.duplicate()
		seen_by.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	func duplicate_deed() -> Deed:
		return Deed.new(did, where, seen_by)

	func equals(other: Deed) -> bool:
		return other != null and other.did == did and other.where == where and other.seen_by == seen_by

	func is_valid() -> bool:
		if did.is_empty():
			return false
		for npc_id: StringName in seen_by:
			if npc_id.is_empty():
				return false
		return true


## Writes the deed down. Null when `did` says nothing.
static func record(state: CharacterState, did: String, where: StringName, seen_by: Array[StringName]) -> Deed:
	if state == null or did.is_empty():
		return null
	var deed := Deed.new(did, where, seen_by)
	state.deeds.append(deed)
	return deed


## Whether `did` was ever done.
static func done(state: CharacterState, did: String) -> bool:
	if state == null:
		return false
	for deed: Deed in state.deeds:
		if deed.did == did:
			return true
	return false


## The deeds `npc_id` saw, in the order they happened.
static func witnessed_by(state: CharacterState, npc_id: StringName) -> Array[Deed]:
	var result: Array[Deed] = []
	if state == null:
		return result
	for deed: Deed in state.deeds:
		if deed.seen_by.has(npc_id):
			result.append(deed)
	return result


## The line that tells the deed was written down: 【事迹】 and what, then where and who saw.
## `place` is the zone's shown name ("" for none), `witnesses` the NPCs' shown names.
static func told_line(deed: Deed, place: String, witnesses: Array[String]) -> String:
	# TRANSLATORS: native (任务系统): a deed was written down: {did} what the player did.
	var text: String = _t("【事迹】{did}").format({"did": _t(deed.did)})
	if not place.is_empty() and witnesses.is_empty():
		# TRANSLATORS: native (任务系统): after a deed: {place} where it happened, nobody saw.
		text += _t("（在{place}，无人看见）").format({"place": place})
	elif not place.is_empty():
		# TRANSLATORS: native (任务系统): after a deed: {place} where, {who} the people who saw it.
		text += _t("（在{place}，{who}看见了）").format({"place": place, "who": _t("、").join(witnesses)})
	return text


static func _t(text: String) -> String:
	return TranslationServer.translate(text)
