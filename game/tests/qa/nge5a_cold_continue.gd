extends Node

func _ready() -> void:
	Engine.max_fps = 60
	var shell: ApplicationShellController = (load("res://scenes/application/application_shell.tscn") as PackedScene).instantiate()
	shell.configure_before_start(GameSaveStorageProfile.isolated_test("nge5a-live-source"))
	add_child(shell)
