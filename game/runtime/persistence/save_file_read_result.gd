class_name SaveFileReadResult
extends RefCounted

const ERROR_FILE_TOO_LARGE: int = 1001

var error: int
var bytes: PackedByteArray
var file_size: int


func _init(p_error: int = OK, p_bytes: PackedByteArray = PackedByteArray(), p_file_size: int = 0) -> void:
	error = p_error
	bytes = p_bytes.duplicate()
	file_size = p_file_size
