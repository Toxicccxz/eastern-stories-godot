class_name GameSaveStorageProfile
extends RefCounted

const SAVE_ROOT: String = "user://save-data"
const TEST_ROOT: String = "user://save-data/tests"
## A slot's file: slot-1-v1.json ... slot-3-v1.json, auto-v1.json; each has its own .bak and .tmp.
const SLOT_FILE_SUFFIX: String = "-v1.json"

const DEVELOPMENT: StringName = &"development"
const RELEASE: StringName = &"release"
const TEST: StringName = &"test"

var profile_id: StringName
var directory_path: String
var slot_id: StringName = GameSaveSnapshot.DEFAULT_SLOT_ID


func _init(p_profile_id: StringName = &"", p_directory_path: String = "") -> void:
	profile_id = p_profile_id
	directory_path = p_directory_path


## The same storage, on `p_slot_id`'s files.
func for_slot(p_slot_id: StringName) -> GameSaveStorageProfile:
	var profile := GameSaveStorageProfile.new(profile_id, directory_path)
	profile.slot_id = p_slot_id
	return profile


static func development() -> GameSaveStorageProfile:
	return GameSaveStorageProfile.new(DEVELOPMENT, SAVE_ROOT + "/development")


static func release() -> GameSaveStorageProfile:
	return GameSaveStorageProfile.new(RELEASE, SAVE_ROOT + "/release")


static func isolated_test(suite_run_id: String) -> GameSaveStorageProfile:
	if not _is_safe_child_name(suite_run_id):
		return GameSaveStorageProfile.new()
	return GameSaveStorageProfile.new(TEST, TEST_ROOT + "/" + suite_run_id)


func is_valid() -> bool:
	if not GameSaveSnapshot.is_slot_id(slot_id):
		return false
	if profile_id == DEVELOPMENT:
		return directory_path == SAVE_ROOT + "/development"
	if profile_id == RELEASE:
		return directory_path == SAVE_ROOT + "/release"
	if profile_id == TEST:
		return is_safe_test_directory()
	return false


func is_safe_test_directory() -> bool:
	if not directory_path.begins_with(TEST_ROOT + "/"):
		return false
	var suffix: String = directory_path.substr((TEST_ROOT + "/").length())
	return _is_safe_child_name(suffix)


func canonical_path() -> String:
	return directory_path + "/" + String(slot_id) + SLOT_FILE_SUFFIX


func temp_path() -> String:
	return canonical_path() + ".tmp"


func backup_path() -> String:
	return canonical_path() + ".bak"


static func _is_safe_child_name(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var valid: bool = (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 45 or code == 95
		if not valid: return false
	return true
