class_name GodotSaveFileOperations
extends SaveFileOperations


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func make_directory_recursive(path: String) -> int:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func read_bytes(path: String, maximum_bytes: int) -> SaveFileReadResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return SaveFileReadResult.new(FileAccess.get_open_error())
	var length: int = file.get_length()
	if length > maximum_bytes:
		return SaveFileReadResult.new(SaveFileReadResult.ERROR_FILE_TOO_LARGE, PackedByteArray(), length)
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: int = file.get_error()
	if error == ERR_FILE_EOF and bytes.size() == length:
		error = OK
	return SaveFileReadResult.new(error, bytes, length)


func write_bytes(path: String, bytes: PackedByteArray) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	return file.get_error()


func rename_file(from_path: String, to_path: String) -> int:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path),
	)


func remove_file(path: String) -> int:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
