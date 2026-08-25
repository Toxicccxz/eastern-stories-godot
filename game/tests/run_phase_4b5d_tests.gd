extends SceneTree

const CombinedStackCurrencyTest := preload(
	"res://tests/core/combined_stack_currency_test.gd"
)
const ArmorFoundationTest := preload(
	"res://tests/core/armor_foundation_test.gd"
)
const NativeItemSaveRestoreTest := preload(
	"res://tests/core/native_item_save_restore_test.gd"
)
const LegacyAutoloadImportTest := preload(
	"res://tests/core/legacy_autoload_import_test.gd"
)


func _init() -> void:
	var results: Array[Dictionary] = []
	print("RUN Phase 4B3 stack regression")
	results.append(CombinedStackCurrencyTest.new().run_all())
	print("RUN Phase 4B4 armor regression")
	results.append(ArmorFoundationTest.new().run_all())
	print("RUN Phase 4B5A persistence regression")
	results.append(NativeItemSaveRestoreTest.new().run_all())
	print("RUN Phase 4B5D legacy autoload")
	results.append(LegacyAutoloadImportTest.new().run_all())
	var assertions: int = 0
	var failures: Array[String] = []
	for result: Dictionary in results:
		assertions += int(result["assertions"])
		failures.append_array(result["failures"])
	if failures.is_empty():
		print("PASS Phase 4B5D targeted: %d assertions" % assertions)
		quit(0)
		return
	for failure: String in failures:
		printerr(failure)
	printerr(
		"FAIL Phase 4B5D targeted: %d failure(s), %d assertions"
		% [failures.size(), assertions]
	)
	quit(1)
