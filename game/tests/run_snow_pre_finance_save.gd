extends SceneTree

## Runs unchanged in exact pre-S3B dc2a07e export. Only calls existing S2 APIs.
const Fixture := preload("res://tests/runtime/snow_work_income_test.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var session: OldPineWorldSessionController = Fixture.create_session(self)
	var work: SnowWorkResult = Fixture.work(session)
	var repository: SourceEntrySaveRepository = SourceEntrySaveRepository.new(GameSaveStorageProfile.isolated_test(args[0]))
	var saved: OldPineRuntimeSaveLoadResult = OldPineSessionLoadCoordinator.new(repository).save_current(session)
	var ok: bool = work.succeeded() and saved.succeeded()
	session.free()
	print("PRE-S3B SOURCE SAVE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
