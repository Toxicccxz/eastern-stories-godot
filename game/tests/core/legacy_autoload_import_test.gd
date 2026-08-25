extends RefCounted

const ItemDefinitionScript := preload("res://core/items/item_definition.gd")
const StackDefinitionScript := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const ArmorDefinitionScript := preload("res://core/armor/armor_definition.gd")
const ArmorModifiersScript := preload(
	"res://core/armor/armor_numeric_modifiers.gd"
)
const DefinitionProjectionsScript := preload(
	"res://core/persistence/native_item_definition_projections.gd"
)
const RestorerScript := preload(
	"res://core/persistence/native_item_state_restorer.gd"
)
const CaptureScript := preload(
	"res://core/persistence/native_item_state_capture.gd"
)
const ArmorSourceScript := preload(
	"res://core/persistence/native_character_armor_source.gd"
)
const ParserScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parser.gd"
)
const ParseResultScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parse_result.gd"
)
const BindingScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_binding.gd"
)
const BindingsScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_bindings.gd"
)
const PlanScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_import_plan.gd"
)
const EntryResultScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry_result.gd"
)
const ImportResultScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_import_result.gd"
)
const ImporterScript := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_importer.gd"
)

const CHARACTER_ID: StringName = &"character:legacy_import"
const COIN_DEF: StringName = &"money:coin_fixture"
const GOLD_DEF: StringName = &"money:gold_fixture"
const SILVER_DEF: StringName = &"money:silver_fixture"
const CASH_DEF: StringName = &"money:thousand_cash_fixture"
const BANDAGE_DEF: StringName = &"armor:bandage_fixture"
const MARRY_DEF: StringName = &"item:marry_card_fixture"
const TOKEN_DEF: StringName = &"item:token_fixture"
const ROOMMAKER_DEF: StringName = &"item:roommaker_fixture"
const PLAIN_DEF: StringName = &"item:plain_fixture"

const COIN_PATH: String = "/obj/money/coin"
const GOLD_PATH: String = "/obj/money/gold"
const SILVER_PATH: String = "/obj/money/silver"
const CASH_PATH: String = "/obj/money/thousand-cash"
const BANDAGE_PATH: String = "/obj/bandage"
const MARRY_PATH: String = "/obj/marry_card"
const TOKEN_PATH: String = "/obj/token"
const ROOMMAKER_PATH: String = "/obj/roommaker"

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_parser_first_colon_and_malformed_path()
	_test_exact_path_binding_and_instance_plan()
	_test_money_denominations_positive_zero_and_failures()
	_test_bandage_authored_state_and_sequential_wear()
	_test_marry_token_roommaker_and_unknown_boundaries()
	_test_batch_order_canonical_snapshot_and_validator_restore()
	_test_result_defensive_immutability()
	return {
		"assertions": _assertion_count,
		"failures": _failures.duplicate(),
	}


func _test_parser_first_colon_and_malformed_path() -> void:
	var path_only: ParseResultScript = ParserScript.parse("/obj/x")
	_assert_true(path_only.succeeded, "path-only entry parses")
	_assert_eq(path_only.entry.legacy_program_path, "/obj/x", "path is exact")
	_assert_false(path_only.entry.has_parameter, "path-only has no parameter")

	var empty_parameter: ParseResultScript = ParserScript.parse("/obj/x:")
	_assert_true(empty_parameter.entry.has_parameter, "colon records parameter presence")
	_assert_eq(empty_parameter.entry.parameter, "", "empty parameter is preserved")

	var colons: ParseResultScript = ParserScript.parse("/obj/x:a:b:c")
	_assert_eq(colons.entry.legacy_program_path, "/obj/x", "first colon ends path")
	_assert_eq(colons.entry.parameter, "a:b:c", "later colons remain in parameter")
	_assert_eq(ParserScript.parse(":bad").outcome, ParseResultScript.Outcome.MALFORMED_PATH, "empty path rejected")
	_assert_eq(ParserScript.parse("obj/x").outcome, ParseResultScript.Outcome.MALFORMED_PATH, "non-absolute path rejected without normalization")


func _test_exact_path_binding_and_instance_plan() -> void:
	var bindings: BindingsScript = _bindings()
	_assert_eq(bindings.binding_for(COIN_PATH).item_definition_id, COIN_DEF, "exact concrete coin path maps")
	_assert_eq(bindings.binding_for("/OBJ/money/coin"), null, "path case is not normalized")
	_assert_eq(bindings.binding_for("/std/money"), null, "inherited std path is not concrete money identity")
	_assert_eq(bindings.binding_for(COIN_PATH + ".c"), null, "runtime base_name has no source extension")
	_assert_eq(bindings.binding_for(COIN_PATH + "#42"), null, "runtime base_name has no clone suffix")

	var invalid_path: BindingsScript = BindingsScript.new([
		BindingScript.new("/", COIN_DEF, BindingScript.DecoderKind.MONEY),
	])
	_assert_false(invalid_path.is_valid, "root path is not a legacy program binding")
	var empty_definition: BindingsScript = BindingsScript.new([
		BindingScript.new(COIN_PATH, &"", BindingScript.DecoderKind.MONEY),
	])
	_assert_false(empty_definition.is_valid, "empty native definition binding rejects")
	var bad_decoder: BindingsScript = BindingsScript.new([
		BindingScript.new(COIN_PATH, COIN_DEF, 999),
	])
	_assert_false(bad_decoder.is_valid, "unknown decoder kind rejects")
	var duplicate_path: BindingsScript = BindingsScript.new([
		BindingScript.new(COIN_PATH, COIN_DEF, BindingScript.DecoderKind.MONEY),
		BindingScript.new(COIN_PATH, GOLD_DEF, BindingScript.DecoderKind.MONEY),
	])
	_assert_false(duplicate_path.is_valid, "conflicting duplicate legacy path rejects")
	var negative_weight: BindingsScript = BindingsScript.new([
		BindingScript.new(BANDAGE_PATH, BANDAGE_DEF, BindingScript.DecoderKind.BANDAGE, -1),
	])
	_assert_false(negative_weight.is_valid, "negative source weight binding rejects")

	var duplicate_ids: ImportResultScript = ImporterScript.import_entries(
		PlanScript.new(CHARACTER_ID, [COIN_PATH + ":2", GOLD_PATH + ":3"], [&"same", &"same"]),
		bindings,
		_definitions(),
	)
	_assert_eq(duplicate_ids.outcome, ImportResultScript.Outcome.INVALID_INPUT, "duplicate supplied IDs reject before decode")
	_assert_eq(duplicate_ids.entry_results.size(), 2, "invalid plan retains index-aligned evidence")
	_assert_eq(duplicate_ids.entry_results[0].outcome, EntryResultScript.Outcome.INVALID_INSTANCE_ID_PLAN, "plan failure is typed")
	_assert_eq(duplicate_ids.snapshot_candidate, null, "invalid ID plan builds no candidate")

	var insufficient: ImportResultScript = ImporterScript.import_entries(
		PlanScript.new(CHARACTER_ID, [COIN_PATH + ":2"], []),
		bindings,
		_definitions(),
	)
	_assert_eq(insufficient.outcome, ImportResultScript.Outcome.INVALID_INPUT, "insufficient IDs reject")
	var excessive: ImportResultScript = ImporterScript.import_entries(
		PlanScript.new(CHARACTER_ID, [COIN_PATH + ":2"], [&"coin", &"unused"]),
		bindings,
		_definitions(),
	)
	_assert_eq(excessive.outcome, ImportResultScript.Outcome.INVALID_INPUT, "extra IDs reject instead of being silently ignored")
	var empty_id: ImportResultScript = ImporterScript.import_entries(
		PlanScript.new(CHARACTER_ID, [COIN_PATH + ":2"], [&""]),
		bindings,
		_definitions(),
	)
	_assert_eq(empty_id.outcome, ImportResultScript.Outcome.INVALID_INPUT, "empty aligned ID rejects")


func _test_money_denominations_positive_zero_and_failures() -> void:
	var result: ImportResultScript = _import(
		[
			GOLD_PATH + ":2",
			COIN_PATH + ":3",
			SILVER_PATH + ":4",
			CASH_PATH + ":5",
		],
		[&"z_gold", &"a_coin", &"m_silver", &"b_cash"],
	)
	_assert_eq(result.outcome, ImportResultScript.Outcome.COMPLETE, "four concrete money paths import")
	_assert_eq(_item_ids(result), [&"a_coin", &"b_cash", &"m_silver", &"z_gold"], "snapshot canonicalizes instance IDs")
	_assert_eq(_item_weight(result, &"z_gold"), 74, "gold weight is 2 * 37")
	_assert_eq(_item_weight(result, &"a_coin"), 3, "coin weight is 3 * 1")
	_assert_eq(_item_weight(result, &"m_silver"), 148, "silver weight is 4 * 37")
	_assert_eq(_item_weight(result, &"b_cash"), 15, "thousand-cash weight is 5 * 3")
	_assert_eq(result.snapshot_candidate.combined_stack_records[0].item_instance_id, &"a_coin", "stack records use same canonical ID")

	var zero: ImportResultScript = _import([SILVER_PATH + ":0"], [&"zero"])
	_assert_eq(zero.entry_results[0].outcome, EntryResultScript.Outcome.IMPORTED_MONEY_ZERO_PENDING_DESTRUCTION, "zero has explicit legacy outcome")
	_assert_eq(zero.snapshot_candidate.combined_stack_records[0].amount, 1, "new silver clone retains create-time amount one")
	_assert_eq(zero.snapshot_candidate.item_records[0].own_weight, 37, "zero callback retains create-time weight")
	_assert_eq(zero.stack_destruction_intents.size(), 1, "zero emits schema-external destruction intent")
	_assert_eq(zero.stack_destruction_intents[0].requested_amount, 0, "zero intent records requested amount")
	_assert_eq(zero.stack_destruction_intents[0].delay_seconds, 1, "combined.c delay is exact")
	_assert_eq(zero.snapshot_candidate.schema_version, 1, "zero intent does not alter schema")

	for malformed_entry: String in [
		COIN_PATH + ":abc",
		COIN_PATH,
		COIN_PATH + ":",
		COIN_PATH + ":-1",
	]:
		var bad: ImportResultScript = _import([malformed_entry], [&"bad"])
		_assert_eq(bad.outcome, ImportResultScript.Outcome.INVALID_INPUT, "malformed money is invalid: %s" % malformed_entry)
		_assert_eq(bad.entry_results[0].outcome, EntryResultScript.Outcome.INVALID_MONEY_PARAMETER, "money failure evidence is exact")
	for ambiguous_entry: String in [
		COIN_PATH + ":12abc",
		COIN_PATH + ": 12",
		COIN_PATH + ":+12",
		COIN_PATH + ":0012",
	]:
		var ambiguous: ImportResultScript = _import([ambiguous_entry], [&"ambiguous"])
		_assert_eq(ambiguous.outcome, ImportResultScript.Outcome.INCOMPLETE_UNSUPPORTED, "undocumented MudOS integer edge remains incomplete")
		_assert_eq(ambiguous.entry_results[0].outcome, EntryResultScript.Outcome.UNSUPPORTED_MONEY_PARAMETER_DRIVER_AMBIGUITY, "noncanonical numeric evidence is typed")
		_assert_eq(ambiguous.snapshot_candidate.item_records, [], "ambiguous money is not guessed into candidate")

	var valid_then_invalid: ImportResultScript = _import(
		[COIN_PATH + ":2", GOLD_PATH + ":abc"],
		[&"kept_coin", &"bad_gold"],
	)
	_assert_eq(valid_then_invalid.outcome, ImportResultScript.Outcome.INVALID_INPUT, "later invalid entry forbids complete")
	_assert_eq(_item_ids(valid_then_invalid), [&"kept_coin"], "earlier valid candidate data remains inspectable")
	_assert_eq(valid_then_invalid.entry_results[1].item_instance_id, &"bad_gold", "invalid entry retains aligned ID")

	var mismatch_binding: BindingsScript = BindingsScript.new([
		BindingScript.new(COIN_PATH, PLAIN_DEF, BindingScript.DecoderKind.MONEY),
	])
	var mismatch: ImportResultScript = ImporterScript.import_entries(
		PlanScript.new(CHARACTER_ID, [COIN_PATH + ":2"], [&"plain_money"]),
		mismatch_binding,
		_definitions(),
	)
	_assert_eq(mismatch.entry_results[0].outcome, EntryResultScript.Outcome.MONEY_DEFINITION_NOT_STACK_CAPABLE, "money requires mapped stack definition")


func _test_bandage_authored_state_and_sequential_wear() -> void:
	var result: ImportResultScript = _import(
		[BANDAGE_PATH + ":旧布条", BANDAGE_PATH + ":第二条"],
		[&"z_bandage", &"a_bandage"],
	)
	_assert_eq(result.outcome, ImportResultScript.Outcome.COMPLETE, "two bandages are supported")
	_assert_eq(result.entry_results[0].outcome, EntryResultScript.Outcome.IMPORTED_BANDAGE_WORN, "first legacy entry establishes bandage slot")
	_assert_eq(result.entry_results[1].outcome, EntryResultScript.Outcome.IMPORTED_BANDAGE_UNWORN_SLOT_COLLISION, "later wear failure is ignored but recorded")
	_assert_eq(result.snapshot_candidate.item_records.size(), 2, "both bandage items remain direct inventory")
	for record: NativeItemRecord in result.snapshot_candidate.item_records:
		_assert_eq(record.direct_parent.kind, ContainmentEndpoint.Kind.CHARACTER, "bandage parent is character")
		_assert_eq(record.direct_parent.endpoint_id, CHARACTER_ID, "bandage direct owner is exact")
		_assert_eq(record.own_weight, 200, "bandage source own weight")
	_assert_eq(result.bandage_states[0].legacy_name, "旧布条", "saved name preserved")
	_assert_eq(result.bandage_states[0].blood_soaked, 3, "autoload forces blood_soaked three")
	_assert_true(result.bandage_states[0].native_wear_established, "first authored state records wear")
	_assert_false(result.bandage_states[1].native_wear_established, "collision authored state records no wear")
	_assert_eq(result.snapshot_candidate.character_armor_records.size(), 1, "only source-proven armor record exists")
	_assert_eq(result.snapshot_candidate.character_armor_records[0].slots.size(), 1, "first bandage owns sole slot")
	_assert_eq(result.snapshot_candidate.character_armor_records[0].slots[0].item_instance_id, &"z_bandage", "legacy entry order wins despite canonical item sort")
	_assert_eq(result.snapshot_candidate.character_equipment_records, [], "no generic weapon state imported")
	_assert_eq(result.marry_card_states, [], "bandage import emits no unrelated authored state")
	for malformed_bandage: String in [BANDAGE_PATH, BANDAGE_PATH + ":"]:
		var invalid_bandage: ImportResultScript = _import([malformed_bandage], [&"bad_bandage"])
		_assert_eq(invalid_bandage.entry_results[0].outcome, EntryResultScript.Outcome.INVALID_BANDAGE_PARAMETER, "source-impossible bandage parameter is invalid")


func _test_marry_token_roommaker_and_unknown_boundaries() -> void:
	var marry: ImportResultScript = _import([MARRY_PATH + ":partner:id"], [&"marry"])
	_assert_eq(marry.outcome, ImportResultScript.Outcome.COMPLETE, "marry persistent state decodes completely")
	_assert_eq(marry.marry_card_states[0].legacy_partner_parameter, "partner:id", "partner parameter exact")
	_assert_eq(marry.marry_card_runtime_intents.size(), 1, "online notification is deferred")
	_assert_eq(marry.marry_card_runtime_intents[0].legacy_partner_parameter, "partner:id", "runtime intent uses no player lookup")
	var empty_marry: ImportResultScript = _import([MARRY_PATH + ":"], [&"empty_marry"])
	_assert_eq(empty_marry.entry_results[0].outcome, EntryResultScript.Outcome.INVALID_MARRY_CARD_PARAMETER, "source-impossible empty partner is invalid")

	var token: ImportResultScript = _import([TOKEN_PATH + ":guild_x"], [&"token"])
	_assert_eq(token.outcome, ImportResultScript.Outcome.INCOMPLETE_UNSUPPORTED, "token defect cannot report complete")
	_assert_eq(token.entry_results[0].outcome, EntryResultScript.Outcome.UNSUPPORTED_TOKEN_EXECUTABLE_DEFECT, "token defect is distinct")
	_assert_eq(token.entry_results[0].entry.parameter, "guild_x", "unused guild parameter preserved for diagnostics")
	_assert_eq(token.snapshot_candidate.item_records, [], "token is not guessed into native state")
	_assert_eq(token.stack_destruction_intents, [], "token emits no guessed native destruction")

	var roommaker: ImportResultScript = _import([ROOMMAKER_PATH], [&"roommaker"])
	_assert_false(roommaker.entry_results[0].entry.has_parameter, "roommaker active save is path-only")
	_assert_eq(roommaker.entry_results[0].outcome, EntryResultScript.Outcome.UNSUPPORTED_ROOMMAKER_DRIVER_AMBIGUITY, "missing callback ambiguity remains explicit")
	_assert_eq(roommaker.snapshot_candidate.item_records, [], "wizard tool is not executed or materialized")

	var unknown: ImportResultScript = _import(["/obj/not_mapped:value"], [&"unknown"])
	_assert_eq(unknown.outcome, ImportResultScript.Outcome.INCOMPLETE_UNSUPPORTED, "unknown path makes batch incomplete")
	_assert_eq(unknown.entry_results[0].outcome, EntryResultScript.Outcome.UNKNOWN_LEGACY_PATH, "unknown path evidence is typed")
	_assert_eq(unknown.entry_results[0].entry.legacy_program_path, "/obj/not_mapped", "unknown path is not inferred")


func _test_batch_order_canonical_snapshot_and_validator_restore() -> void:
	var result: ImportResultScript = _import(
		[COIN_PATH + ":2", TOKEN_PATH + ":guild", BANDAGE_PATH + ":布条"],
		[&"z_coin", &"m_token", &"a_bandage"],
	)
	_assert_eq(result.outcome, ImportResultScript.Outcome.INCOMPLETE_UNSUPPORTED, "mixed batch retains supported candidate")
	_assert_eq(result.original_entry_count, 3, "original count retained")
	_assert_eq(result.entry_results[0].legacy_index, 0, "diagnostic order index zero")
	_assert_eq(result.entry_results[1].outcome, EntryResultScript.Outcome.UNSUPPORTED_TOKEN_EXECUTABLE_DEFECT, "middle token remains middle")
	_assert_eq(result.entry_results[2].legacy_index, 2, "diagnostic order index two")
	_assert_eq(result.entry_results[2].item_instance_id, &"a_bandage", "unsupported middle entry does not shift later identity")
	_assert_eq(_item_ids(result), [&"a_bandage", &"z_coin"], "candidate independently canonicalizes records")
	_assert_true(result.validation_result.succeeded, "existing Phase4B5A validator accepts partial candidate")

	var complete: ImportResultScript = _import(
		[COIN_PATH + ":7", BANDAGE_PATH + ":布条", MARRY_PATH + ":伴侣"],
		[&"coin", &"bandage", &"marry"],
	)
	_assert_eq(complete.outcome, ImportResultScript.Outcome.COMPLETE, "supported-only batch is complete")
	_assert_true(complete.validation_result.succeeded, "complete candidate passes Phase4B5A validator")
	var restored: NativeItemStateRestoreResult = RestorerScript.restore(
		complete.snapshot_candidate,
		_definitions(),
	)
	_assert_true(restored.succeeded, "candidate remains consumable only through explicit restore")
	_assert_eq(restored.reconstructed_state.item_instance_ids(), [&"bandage", &"coin", &"marry"], "restore reconstructs all supported items")
	_assert_eq(restored.reconstructed_state.combined_stacks.stack_state(&"coin").amount, 7, "restored money amount exact")
	_assert_true(restored.reconstructed_state.armor_state(CHARACTER_ID).is_worn(&"bandage"), "restore reconstructs source-proven bandage slot")

	var restored_items: Array[ItemInstance] = []
	for item_instance_id: StringName in restored.reconstructed_state.item_instance_ids():
		restored_items.append(restored.reconstructed_state.item_instance(item_instance_id))
	var armor_sources: Array[NativeCharacterArmorSource] = []
	for character_id: StringName in restored.reconstructed_state.armor_character_ids():
		armor_sources.append(ArmorSourceScript.new(
			character_id,
			restored.reconstructed_state.armor_state(character_id),
		))
	var recapture: NativeItemSnapshotCaptureResult = CaptureScript.capture(
		restored_items,
		restored.reconstructed_state.inventory,
		restored.reconstructed_state.combined_stacks,
		[],
		armor_sources,
		_definitions(),
	)
	_assert_true(recapture.succeeded, "import restore capture succeeds")
	_assert_eq(
		_snapshot_facts(recapture.snapshot),
		_snapshot_facts(complete.snapshot_candidate),
		"import restore capture preserves every schema-v1 fact canonically",
	)
	_assert_eq(recapture.snapshot.character_equipment_records, [], "recapture invents no generic equipment")


func _test_result_defensive_immutability() -> void:
	var result: ImportResultScript = _import(
		[COIN_PATH + ":2", BANDAGE_PATH + ":布条", MARRY_PATH + ":伴侣"],
		[&"coin", &"bandage", &"marry"],
	)
	var entry_results: Array[LegacyAutoloadEntryResult] = result.entry_results
	entry_results.clear()
	_assert_eq(result.entry_results.size(), 3, "entry result array is defensively copied")
	var bandage_states: Array[LegacyBandageStateImport] = result.bandage_states
	bandage_states.clear()
	_assert_eq(result.bandage_states.size(), 1, "bandage authored array is defensively copied")
	var marry_intents: Array[LegacyMarryCardRuntimeIntent] = (
		result.marry_card_runtime_intents
	)
	marry_intents.clear()
	_assert_eq(result.marry_card_runtime_intents.size(), 1, "runtime intent array is defensively copied")
	var item_records: Array[NativeItemRecord] = result.snapshot_candidate.item_records
	item_records.clear()
	_assert_eq(result.snapshot_candidate.item_records.size(), 3, "candidate snapshot is defensively copied")
	var paths: Array[String] = _bindings().legacy_program_paths()
	paths.clear()
	_assert_eq(_bindings().legacy_program_paths().size(), 8, "binding path collection is not aliased")


func _import(entries: Array[String], ids: Array[StringName]) -> ImportResultScript:
	return ImporterScript.import_entries(
		PlanScript.new(CHARACTER_ID, entries, ids),
		_bindings(),
		_definitions(),
	)


func _bindings() -> BindingsScript:
	return BindingsScript.new([
		BindingScript.new(COIN_PATH, COIN_DEF, BindingScript.DecoderKind.MONEY),
		BindingScript.new(GOLD_PATH, GOLD_DEF, BindingScript.DecoderKind.MONEY),
		BindingScript.new(SILVER_PATH, SILVER_DEF, BindingScript.DecoderKind.MONEY),
		BindingScript.new(CASH_PATH, CASH_DEF, BindingScript.DecoderKind.MONEY),
		BindingScript.new(BANDAGE_PATH, BANDAGE_DEF, BindingScript.DecoderKind.BANDAGE, 200),
		BindingScript.new(MARRY_PATH, MARRY_DEF, BindingScript.DecoderKind.MARRY_CARD, 10),
		BindingScript.new(TOKEN_PATH, TOKEN_DEF, BindingScript.DecoderKind.TOKEN),
		BindingScript.new(ROOMMAKER_PATH, ROOMMAKER_DEF, BindingScript.DecoderKind.ROOMMAKER, 100),
	])


func _definitions() -> DefinitionProjectionsScript:
	return DefinitionProjectionsScript.new(
		[
			ItemDefinitionScript.new(COIN_DEF, COIN_PATH),
			ItemDefinitionScript.new(GOLD_DEF, GOLD_PATH),
			ItemDefinitionScript.new(SILVER_DEF, SILVER_PATH),
			ItemDefinitionScript.new(CASH_DEF, CASH_PATH),
			ItemDefinitionScript.new(BANDAGE_DEF, BANDAGE_PATH),
			ItemDefinitionScript.new(MARRY_DEF, MARRY_PATH),
			ItemDefinitionScript.new(TOKEN_DEF, TOKEN_PATH),
			ItemDefinitionScript.new(ROOMMAKER_DEF, ROOMMAKER_PATH),
			ItemDefinitionScript.new(PLAIN_DEF),
		],
		[],
		[ArmorDefinitionScript.new(BANDAGE_DEF, &"bandage", ArmorModifiersScript.new())],
		[
			StackDefinitionScript.new(COIN_DEF, &"legacy:/obj/money/coin", 1),
			StackDefinitionScript.new(GOLD_DEF, &"legacy:/obj/money/gold", 37),
			StackDefinitionScript.new(SILVER_DEF, &"legacy:/obj/money/silver", 37),
			StackDefinitionScript.new(CASH_DEF, &"legacy:/obj/money/thousand-cash", 3),
		],
	)


func _item_ids(result: ImportResultScript) -> Array[StringName]:
	var ids: Array[StringName] = []
	for record: NativeItemRecord in result.snapshot_candidate.item_records:
		ids.append(record.item_instance_id)
	return ids


func _item_weight(result: ImportResultScript, instance_id: StringName) -> int:
	for record: NativeItemRecord in result.snapshot_candidate.item_records:
		if record.item_instance_id == instance_id:
			return record.own_weight
	return -999999


func _snapshot_facts(snapshot: NativeItemStateSnapshot) -> Array[String]:
	var facts: Array[String] = []
	for record: NativeItemRecord in snapshot.item_records:
		facts.append("item|%s|%s|%d|%d|%s" % [
			record.item_instance_id,
			record.item_definition_id,
			record.own_weight,
			record.direct_parent.kind,
			record.direct_parent.endpoint_id,
		])
	for record: NativeCombinedStackRecord in snapshot.combined_stack_records:
		facts.append("stack|%s|%d" % [record.item_instance_id, record.amount])
	for record: NativeCharacterEquipmentRecord in snapshot.character_equipment_records:
		facts.append("equipment|%s|%s|%s" % [
			record.character_id,
			record.primary_item_instance_id,
			record.secondary_item_instance_id,
		])
	for record: NativeCharacterArmorRecord in snapshot.character_armor_records:
		facts.append("armor|%s" % record.character_id)
		for slot: NativeArmorSlotRecord in record.slots:
			facts.append("armor_slot|%s|%s" % [
				slot.armor_type,
				slot.item_instance_id,
			])
	return facts


func _assert_true(value: bool, label: String) -> void:
	_assertion_count += 1
	if not value:
		_failures.append("%s: expected true" % label)


func _assert_false(value: bool, label: String) -> void:
	_assertion_count += 1
	if value:
		_failures.append("%s: expected false" % label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertion_count += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
