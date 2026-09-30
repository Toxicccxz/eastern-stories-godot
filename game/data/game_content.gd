class_name GameContent
extends RefCounted

## The game's authored content, read once from the JSON files listed in
## content_manifest.json. Rules in game/core receive definitions as arguments;
## runtime, application and UI code look them up here.
const DATA_ROOT: String = "res://data/"
const MANIFEST_PATH: String = "res://data/content_manifest.json"

static var _catalog: ContentCatalog
static var _errors: Array[String] = []


## Never null. When the data failed to load the catalog is empty, so every
## lookup fails closed; load_errors() says why.
static func catalog() -> ContentCatalog:
	if _catalog == null:
		var errors: Array[String] = []
		_catalog = load_catalog(MANIFEST_PATH, DATA_ROOT, errors)
		_errors = errors
		if _catalog == null:
			_catalog = ContentCatalog.new()
			for error: String in errors:
				push_error("content: " + error)
	return _catalog


static func load_errors() -> Array[String]:
	catalog()
	return _errors.duplicate()


## Reads the manifest's `files` (paths relative to `data_root`) in order.
## Returns null and fills `errors` when anything is wrong.
static func load_catalog(
	manifest_path: String,
	data_root: String,
	errors: Array[String],
) -> ContentCatalog:
	var builder: ContentCatalogBuilder = ContentCatalogBuilder.new()
	var manifest: Variant = _read_json(manifest_path, builder)
	var files: Variant = manifest.get("files") if manifest is Dictionary else null
	if not files is Array or files.is_empty():
		builder.report("%s: expected a non-empty `files` array" % manifest_path)
		files = []
	for file: Variant in files:
		if not file is String or file.is_empty():
			builder.report("%s: `files` entries must be non-empty strings" % manifest_path)
			continue
		var document: Variant = _read_json(data_root.path_join(file), builder)
		if document != null:
			builder.add_document(document, file)
	var result: ContentCatalog = builder.build()
	errors.append_array(builder.errors())
	return result


static func _read_json(path: String, builder: ContentCatalogBuilder) -> Variant:
	if not FileAccess.file_exists(path):
		builder.report("%s: file not found" % path)
		return null
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		builder.report("%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data
