class_name SaveFileOperations
extends RefCounted


func file_exists(_path: String) -> bool:
	return false


func make_directory_recursive(_path: String) -> int:
	return ERR_UNAVAILABLE


func read_bytes(_path: String, _maximum_bytes: int) -> SaveFileReadResult:
	return SaveFileReadResult.new(ERR_UNAVAILABLE)


func write_bytes(_path: String, _bytes: PackedByteArray) -> int:
	return ERR_UNAVAILABLE


func rename_file(_from_path: String, _to_path: String) -> int:
	return ERR_UNAVAILABLE


func remove_file(_path: String) -> int:
	return ERR_UNAVAILABLE
