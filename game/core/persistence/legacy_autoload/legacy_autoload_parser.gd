class_name LegacyAutoloadParser
extends RefCounted

const EntryType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry.gd"
)
const ResultType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parse_result.gd"
)


static func parse(original_entry: String) -> ResultType:
	var first_colon: int = original_entry.find(":")
	var path: String = (
		original_entry if first_colon < 0 else original_entry.substr(0, first_colon)
	)
	if path.is_empty() or not path.begins_with("/"):
		return ResultType.new(ResultType.Outcome.MALFORMED_PATH, original_entry)
	var has_parameter: bool = first_colon >= 0
	var parameter: String = (
		"" if not has_parameter else original_entry.substr(first_colon + 1)
	)
	return ResultType.new(
		ResultType.Outcome.PARSED,
		original_entry,
		EntryType.new(path, has_parameter, parameter),
	)
