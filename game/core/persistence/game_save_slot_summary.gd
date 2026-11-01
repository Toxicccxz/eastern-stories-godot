class_name GameSaveSlotSummary
extends RefCounted

## One row of the slot list (现代基线 A; DECISIONS「存档位」): what a slot's file says, read
## and parsed and no more. A full check takes most of a second a file; only a Load makes it, so
## READY means the file looks like a current save, not that it will load.
enum State {
	## No file (`recoverable`: a .bak or .tmp lies beside the missing one).
	EMPTY,
	READY,
	## Not JSON, or not a save.
	UNREADABLE,
	## A save of another format, schema or world revision.
	UNSUPPORTED,
}

var slot_id: StringName
var state: State = State.EMPTY
var recoverable: bool = false
var display_name: String = ""
var zone_id: StringName = &""
var saved_at_utc: String = ""
var played_seconds: int = 0
## The objective at the save, in the source language: shown through tr().
var objective: String = ""
var ghost: bool = false
var pace: StringName = CharacterState.PACE_MODERN


func _init(p_slot_id: StringName = &"", p_state: State = State.EMPTY, p_recoverable: bool = false) -> void:
	slot_id = p_slot_id
	state = p_state
	recoverable = p_recoverable


## What `text` says. `current_public_only`: a save of an older world is UNSUPPORTED.
static func of_text(slot_id: StringName, text: String, current_public_only: bool, recoverable: bool) -> GameSaveSlotSummary:
	var summary := GameSaveSlotSummary.new(slot_id, State.UNREADABLE, recoverable)
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return summary
	var root: Dictionary = parser.data
	var metadata: Variant = root.get("metadata")
	var player: Variant = root.get("player")
	if typeof(metadata) != TYPE_DICTIONARY or typeof(player) != TYPE_DICTIONARY:
		return summary
	if str(metadata.get("format_id")) != GameSaveSnapshot.FORMAT_ID:
		return summary
	var revision: int = WorldContentRevision.parsed(str(root.get("world_content_revision", "")))
	var schema: Variant = metadata.get("schema_version")
	if typeof(schema) != TYPE_FLOAT or int(schema) != GameSaveSnapshot.CURRENT_SCHEMA_VERSION or revision < 0 or (current_public_only and revision != WorldContentRevision.CURRENT_PUBLIC):
		summary.state = State.UNSUPPORTED
		return summary
	var identity: Variant = player.get("identity")
	var location: Variant = player.get("world_location")
	var character: Variant = player.get("character")
	if typeof(identity) != TYPE_DICTIONARY or typeof(location) != TYPE_DICTIONARY or typeof(character) != TYPE_DICTIONARY:
		return summary
	summary.state = State.READY
	summary.display_name = str(identity.get("display_name", ""))
	summary.zone_id = StringName(str(location.get("zone_id", "")))
	summary.saved_at_utc = str(metadata.get("saved_at_utc", ""))
	summary.played_seconds = maxi(int(str(root.get("played_seconds", "0"))), 0)
	summary.objective = str(root.get("objective", ""))
	summary.ghost = typeof(character.get("ghost")) == TYPE_BOOL and bool(character.get("ghost"))
	summary.pace = StringName(str(character.get("pace", CharacterState.PACE_MODERN)))
	return summary


## The slot 继续 reads: the newest save that looks whole; with none, the first that holds
## anything at all, for the shell to say what is wrong with it; with nothing, `fallback`.
static func newest(summaries: Array[GameSaveSlotSummary], fallback: StringName) -> StringName:
	var found: GameSaveSlotSummary = null
	for summary: GameSaveSlotSummary in summaries:
		if summary.state == State.READY and (found == null or summary.saved_at_utc > found.saved_at_utc):
			found = summary
	if found != null:
		return found.slot_id
	for summary: GameSaveSlotSummary in summaries:
		if summary.state != State.EMPTY or summary.recoverable:
			return summary.slot_id
	return fallback
