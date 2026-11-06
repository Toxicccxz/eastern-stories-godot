extends RefCounted

## project.godot as Godot itself writes it, and the three settings the game depends on
## (BUILD.md「project.godot」). The editor and the Godot AI plugin save the whole file from
## memory: comments go, settings at Godot's own default are left out. A file kept in that form
## stays the same when they save it.
const SCRATCH := "user://project_settings_test/project.godot"

var assertions: int = 0
var failures: Array[String] = []


func run_all() -> Dictionary:
	_settings()
	_written_by_godot()
	return {"assertions": assertions, "failures": failures}


func _settings() -> void:
	# Vulkan, not D3D12: Godot's D3D12 driver reserves at least 64 KB of GPU memory per buffer and a
	# voxel map holds thousands of small MultiMesh buffers (乔阴县城 1.2 GB under D3D12, 0.1 GB
	# under Vulkan), so a long session ran the GPU out of memory. Vulkan is 4.7.2's own default, so
	# the file does not list it; if an upgrade changes the default, write
	# `rendering_device/driver.windows="vulkan"` back under [rendering].
	var driver: String = ProjectSettings.get_setting("rendering/rendering_device/driver.windows")
	_check(driver == "vulkan", "Windows renders with Vulkan: %s" % driver)
	var method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	_check(method == "mobile", "the mobile renderer: %s" % method)
	# 像素界面: pixel text and frames are drawn nearest, so a font pixel stays a sharp square.
	var filter: int = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")
	_check(filter == 0, "canvas textures drawn nearest: %d" % filter)


func _written_by_godot() -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH.get_base_dir())
	var saved: Error = ProjectSettings.save_custom(SCRATCH)
	_check(saved == OK, "Godot writes the settings out: %s" % error_string(saved))
	var ours: String = FileAccess.get_file_as_string("res://project.godot").replace("\r\n", "\n")
	var godots: String = FileAccess.get_file_as_string(SCRATCH).replace("\r\n", "\n")
	DirAccess.remove_absolute(SCRATCH)
	_check(not ours.is_empty() and ours == godots, "project.godot is as Godot writes it (no comments, no settings at their default); first difference: %s" % _first_difference(ours, godots))


func _first_difference(ours: String, godots: String) -> String:
	var a: PackedStringArray = ours.split("\n")
	var b: PackedStringArray = godots.split("\n")
	for i: int in maxi(a.size(), b.size()):
		var left: String = a[i] if i < a.size() else "<end>"
		var right: String = b[i] if i < b.size() else "<end>"
		if left != right:
			return "line %d: ours「%s」, Godot's「%s」" % [i + 1, left, right]
	return "none"


func _check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append("project_settings: " + label)
