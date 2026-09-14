class_name CharacterAffiliationState
extends RefCounted

## Additional persistent source fields, distinct from family identity/master.
## Missing historical values are not reconstructed from a load timestamp.
enum EntryTime { ABSENT, UNKNOWN, RECORDED }

var class_id: StringName = &""
var has_family_rank: bool = false
var family_title: String = ""
var family_privileges: int = 0
var entry_time_status: EntryTime = EntryTime.ABSENT
var entry_time_utc: int = 0


static func legacy(has_relationship: bool) -> CharacterAffiliationState:
	var value := CharacterAffiliationState.new()
	if has_relationship:
		value.entry_time_status = EntryTime.UNKNOWN
	return value


func duplicate_snapshot() -> CharacterAffiliationState:
	var value := CharacterAffiliationState.new()
	value.class_id = class_id
	value.has_family_rank = has_family_rank
	value.family_title = family_title
	value.family_privileges = family_privileges
	value.entry_time_status = entry_time_status
	value.entry_time_utc = entry_time_utc
	return value


func is_valid() -> bool:
	if not has_family_rank and (not family_title.is_empty() or family_privileges != 0):
		return false
	if entry_time_status not in [EntryTime.ABSENT, EntryTime.UNKNOWN, EntryTime.RECORDED]:
		return false
	return entry_time_utc >= 0 if entry_time_status == EntryTime.RECORDED else entry_time_utc == 0
