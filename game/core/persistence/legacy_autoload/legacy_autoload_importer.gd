class_name LegacyAutoloadImporter
extends RefCounted

const ParserType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parser.gd"
)
const ParseResultType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_parse_result.gd"
)
const EntryType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry.gd"
)
const BindingType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_binding.gd"
)
const BindingsType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_bindings.gd"
)
const PlanType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_import_plan.gd"
)
const EntryResultType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_entry_result.gd"
)
const ResultType := preload(
	"res://core/persistence/legacy_autoload/legacy_autoload_import_result.gd"
)
const BandageStateType := preload(
	"res://core/persistence/legacy_autoload/legacy_bandage_state_import.gd"
)
const MarryStateType := preload(
	"res://core/persistence/legacy_autoload/legacy_marry_card_state_import.gd"
)
const MarryIntentType := preload(
	"res://core/persistence/legacy_autoload/legacy_marry_card_runtime_intent.gd"
)
const StackIntentType := preload(
	"res://core/persistence/legacy_autoload/legacy_stack_destruction_intent.gd"
)
const EndpointType := preload("res://core/inventory/containment_endpoint.gd")
const ItemRecordType := preload("res://core/persistence/native_item_record.gd")
const StackRecordType := preload(
	"res://core/persistence/native_combined_stack_record.gd"
)
const ArmorSlotRecordType := preload(
	"res://core/persistence/native_armor_slot_record.gd"
)
const ArmorRecordType := preload(
	"res://core/persistence/native_character_armor_record.gd"
)
const SnapshotType := preload(
	"res://core/persistence/native_item_state_snapshot.gd"
)
const DefinitionProjectionsType := preload(
	"res://core/persistence/native_item_definition_projections.gd"
)
const ValidatorType := preload(
	"res://core/persistence/native_item_state_validator.gd"
)
const ValidationResultType := preload(
	"res://core/persistence/native_item_state_validation_result.gd"
)
const StackDefinitionType := preload(
	"res://core/items/combined/combined_stack_definition.gd"
)
const ArmorDefinitionType := preload("res://core/armor/armor_definition.gd")

const LEGACY_BANDAGE_SLOT: StringName = &"bandage"


static func import_entries(
	plan: PlanType,
	bindings: BindingsType,
	definitions: DefinitionProjectionsType,
) -> ResultType:
	if plan == null:
		return ResultType.new(ResultType.Outcome.INVALID_INPUT)
	var legacy_entries: Array[String] = plan.legacy_entries
	var instance_ids: Array[StringName] = plan.item_instance_ids
	var plan_failure: int = _validate_plan(
		plan.character_id,
		legacy_entries,
		instance_ids,
		bindings,
		definitions,
	)
	if plan_failure != -1:
		return _invalid_plan_result(
			legacy_entries,
			instance_ids,
			plan_failure,
		)

	var direct_parent: EndpointType = EndpointType.new(
		EndpointType.Kind.CHARACTER,
		plan.character_id,
	)
	var entry_results: Array[EntryResultType] = []
	var item_records: Array[NativeItemRecord] = []
	var stack_records: Array[NativeCombinedStackRecord] = []
	var armor_slots: Array[NativeArmorSlotRecord] = []
	var bandage_states: Array[BandageStateType] = []
	var marry_states: Array[MarryStateType] = []
	var marry_intents: Array[MarryIntentType] = []
	var stack_intents: Array[StackIntentType] = []
	var has_invalid_input: bool = false
	var has_unsupported: bool = false
	var bandage_slot_occupied: bool = false

	for index: int in range(legacy_entries.size()):
		var original: String = legacy_entries[index]
		var instance_id: StringName = instance_ids[index]
		var parsed: ParseResultType = ParserType.parse(original)
		if not parsed.succeeded:
			entry_results.append(_entry_result(
				index,
				original,
				instance_id,
				null,
				EntryResultType.Outcome.INVALID_ENTRY_PARSE,
			))
			has_invalid_input = true
			continue
		var entry: EntryType = parsed.entry
		var binding: BindingType = bindings.binding_for(entry.legacy_program_path)
		if binding == null:
			entry_results.append(_entry_result(
				index,
				original,
				instance_id,
				entry,
				EntryResultType.Outcome.UNKNOWN_LEGACY_PATH,
			))
			has_unsupported = true
			continue

		match binding.decoder_kind:
			BindingType.DecoderKind.MONEY:
				var money_outcome: int = _decode_money(
					entry,
					binding,
					instance_id,
					direct_parent,
					definitions,
					item_records,
					stack_records,
					stack_intents,
				)
				entry_results.append(_entry_result(
					index, original, instance_id, entry, money_outcome, binding
				))
				if (
					money_outcome
					== EntryResultType.Outcome.UNSUPPORTED_MONEY_PARAMETER_DRIVER_AMBIGUITY
				):
					has_unsupported = true
				elif (
					money_outcome != EntryResultType.Outcome.IMPORTED_MONEY
					and money_outcome
					!= EntryResultType.Outcome.IMPORTED_MONEY_ZERO_PENDING_DESTRUCTION
				):
					has_invalid_input = true
			BindingType.DecoderKind.BANDAGE:
				var bandage_outcome: int = _decode_bandage(
					entry,
					binding,
					instance_id,
					direct_parent,
					definitions,
					bandage_slot_occupied,
					item_records,
					armor_slots,
					bandage_states,
				)
				entry_results.append(_entry_result(
					index, original, instance_id, entry, bandage_outcome, binding
				))
				if bandage_outcome == EntryResultType.Outcome.IMPORTED_BANDAGE_WORN:
					bandage_slot_occupied = true
				elif (
					bandage_outcome
					!= EntryResultType.Outcome.IMPORTED_BANDAGE_UNWORN_SLOT_COLLISION
				):
					has_invalid_input = true
			BindingType.DecoderKind.MARRY_CARD:
				var marry_outcome: int = _decode_marry_card(
					entry,
					binding,
					instance_id,
					direct_parent,
					definitions,
					item_records,
					marry_states,
					marry_intents,
				)
				entry_results.append(_entry_result(
					index, original, instance_id, entry, marry_outcome, binding
				))
				if (
					marry_outcome
					!= EntryResultType.Outcome.IMPORTED_MARRY_CARD_WITH_DEFERRED_RUNTIME_EFFECT
				):
					has_invalid_input = true
			BindingType.DecoderKind.TOKEN:
				entry_results.append(_entry_result(
					index,
					original,
					instance_id,
					entry,
					EntryResultType.Outcome.UNSUPPORTED_TOKEN_EXECUTABLE_DEFECT,
					binding,
				))
				has_unsupported = true
			BindingType.DecoderKind.ROOMMAKER:
				entry_results.append(_entry_result(
					index,
					original,
					instance_id,
					entry,
					EntryResultType.Outcome.UNSUPPORTED_ROOMMAKER_DRIVER_AMBIGUITY,
					binding,
				))
				has_unsupported = true

	var armor_records: Array[NativeCharacterArmorRecord] = []
	if not armor_slots.is_empty():
		armor_records.append(ArmorRecordType.new(plan.character_id, armor_slots))
	var snapshot: SnapshotType = SnapshotType.new(
		SnapshotType.CURRENT_SCHEMA_VERSION,
		item_records,
		stack_records,
		[],
		armor_records,
	)
	var validation: ValidationResultType = ValidatorType.validate(snapshot, definitions)
	var outcome: int = ResultType.Outcome.COMPLETE
	if has_invalid_input or not validation.succeeded:
		outcome = ResultType.Outcome.INVALID_INPUT
	elif has_unsupported:
		outcome = ResultType.Outcome.INCOMPLETE_UNSUPPORTED
	return ResultType.new(
		outcome,
		legacy_entries.size(),
		entry_results,
		snapshot,
		bandage_states,
		marry_states,
		marry_intents,
		stack_intents,
		validation,
	)


static func _validate_plan(
	character_id: StringName,
	legacy_entries: Array[String],
	instance_ids: Array[StringName],
	bindings: BindingsType,
	definitions: DefinitionProjectionsType,
) -> int:
	if character_id == &"" or instance_ids.size() != legacy_entries.size():
		return EntryResultType.Outcome.INVALID_INSTANCE_ID_PLAN
	if bindings == null or not bindings.is_valid:
		return EntryResultType.Outcome.MAPPED_DEFINITION_UNAVAILABLE
	if definitions == null or not definitions.is_valid:
		return EntryResultType.Outcome.MAPPED_DEFINITION_UNAVAILABLE
	var ids: Dictionary[StringName, bool] = {}
	for index: int in range(legacy_entries.size()):
		var instance_id: StringName = instance_ids[index]
		if instance_id == &"" or ids.has(instance_id):
			return EntryResultType.Outcome.INVALID_INSTANCE_ID_PLAN
		ids[instance_id] = true
	return -1


static func _invalid_plan_result(
	legacy_entries: Array[String],
	instance_ids: Array[StringName],
	entry_outcome: int,
) -> ResultType:
	var entry_results: Array[EntryResultType] = []
	for index: int in range(legacy_entries.size()):
		entry_results.append(_entry_result(
			index,
			legacy_entries[index],
			&"" if index >= instance_ids.size() else instance_ids[index],
			null,
			entry_outcome,
		))
	return ResultType.new(
		ResultType.Outcome.INVALID_INPUT,
		legacy_entries.size(),
		entry_results,
	)


static func _decode_money(
	entry: EntryType,
	binding: BindingType,
	instance_id: StringName,
	direct_parent: EndpointType,
	definitions: DefinitionProjectionsType,
	item_records: Array[NativeItemRecord],
	stack_records: Array[NativeCombinedStackRecord],
	stack_intents: Array[StackIntentType],
) -> int:
	if not definitions.has_item_definition(binding.item_definition_id):
		return EntryResultType.Outcome.MAPPED_DEFINITION_UNAVAILABLE
	var stack_definition: StackDefinitionType = definitions.stack_definition(
		binding.item_definition_id
	)
	if stack_definition == null:
		return EntryResultType.Outcome.MONEY_DEFINITION_NOT_STACK_CAPABLE
	if not entry.has_parameter or entry.parameter.is_empty():
		return EntryResultType.Outcome.INVALID_MONEY_PARAMETER
	if not entry.parameter.is_valid_int():
		return (
			EntryResultType.Outcome.UNSUPPORTED_MONEY_PARAMETER_DRIVER_AMBIGUITY
			if _contains_decimal_digit(entry.parameter)
			else EntryResultType.Outcome.INVALID_MONEY_PARAMETER
		)
	var requested_amount: int = entry.parameter.to_int()
	if requested_amount < 0:
		return EntryResultType.Outcome.INVALID_MONEY_PARAMETER
	## query_autoload() serializes query_amount() by integer-to-string
	## conversion. A non-canonical numeric spelling cannot be source-produced,
	## while the bundled MudOS sscanf documentation does not fully specify how
	## `%d` treats whitespace, signs, leading zeroes, or trailing characters.
	if str(requested_amount) != entry.parameter:
		return EntryResultType.Outcome.UNSUPPORTED_MONEY_PARAMETER_DRIVER_AMBIGUITY
	## Every concrete money clone calls set_amount(1) in create(). The zero
	## callback only requests delayed destruction and leaves that amount/weight.
	var restored_amount: int = 1 if requested_amount == 0 else requested_amount
	var own_weight: int = stack_definition.own_weight_for_amount(restored_amount)
	item_records.append(ItemRecordType.new(
		instance_id,
		binding.item_definition_id,
		own_weight,
		direct_parent,
	))
	stack_records.append(StackRecordType.new(instance_id, restored_amount))
	if requested_amount == 0:
		stack_intents.append(StackIntentType.new(instance_id, 0))
		return EntryResultType.Outcome.IMPORTED_MONEY_ZERO_PENDING_DESTRUCTION
	return EntryResultType.Outcome.IMPORTED_MONEY


static func _decode_bandage(
	entry: EntryType,
	binding: BindingType,
	instance_id: StringName,
	direct_parent: EndpointType,
	definitions: DefinitionProjectionsType,
	bandage_slot_occupied: bool,
	item_records: Array[NativeItemRecord],
	armor_slots: Array[NativeArmorSlotRecord],
	bandage_states: Array[BandageStateType],
) -> int:
	## A saved bandage name must be truthy: save_autoload() omits the object
	## when query_autoload() returns an empty string.
	if not entry.has_parameter or entry.parameter.is_empty():
		return EntryResultType.Outcome.INVALID_BANDAGE_PARAMETER
	if not definitions.has_item_definition(binding.item_definition_id):
		return EntryResultType.Outcome.MAPPED_DEFINITION_UNAVAILABLE
	var armor_definition: ArmorDefinitionType = definitions.armor_definition(
		binding.item_definition_id
	)
	if (
		armor_definition == null
		or armor_definition.armor_type != LEGACY_BANDAGE_SLOT
	):
		return EntryResultType.Outcome.INVALID_BANDAGE_ARMOR_DEFINITION
	item_records.append(ItemRecordType.new(
		instance_id,
		binding.item_definition_id,
		binding.initial_own_weight,
		direct_parent,
	))
	var wear_established: bool = not bandage_slot_occupied
	if wear_established:
		armor_slots.append(ArmorSlotRecordType.new(LEGACY_BANDAGE_SLOT, instance_id))
	bandage_states.append(BandageStateType.new(
		instance_id,
		entry.parameter,
		wear_established,
	))
	return (
		EntryResultType.Outcome.IMPORTED_BANDAGE_WORN
		if wear_established
		else EntryResultType.Outcome.IMPORTED_BANDAGE_UNWORN_SLOT_COLLISION
	)


static func _decode_marry_card(
	entry: EntryType,
	binding: BindingType,
	instance_id: StringName,
	direct_parent: EndpointType,
	definitions: DefinitionProjectionsType,
	item_records: Array[NativeItemRecord],
	marry_states: Array[MarryStateType],
	marry_intents: Array[MarryIntentType],
) -> int:
	if not entry.has_parameter or entry.parameter.is_empty():
		return EntryResultType.Outcome.INVALID_MARRY_CARD_PARAMETER
	if not definitions.has_item_definition(binding.item_definition_id):
		return EntryResultType.Outcome.MAPPED_DEFINITION_UNAVAILABLE
	item_records.append(ItemRecordType.new(
		instance_id,
		binding.item_definition_id,
		binding.initial_own_weight,
		direct_parent,
	))
	marry_states.append(MarryStateType.new(instance_id, entry.parameter))
	marry_intents.append(MarryIntentType.new(instance_id, entry.parameter))
	return EntryResultType.Outcome.IMPORTED_MARRY_CARD_WITH_DEFERRED_RUNTIME_EFFECT


static func _contains_decimal_digit(value: String) -> bool:
	for index: int in range(value.length()):
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 48 and codepoint <= 57:
			return true
	return false


static func _entry_result(
	index: int,
	original: String,
	instance_id: StringName,
	entry: EntryType,
	outcome: int,
	binding: BindingType = null,
) -> EntryResultType:
	return EntryResultType.new(
		index,
		original,
		instance_id,
		entry,
		outcome,
		&"" if binding == null else binding.item_definition_id,
		-1 if binding == null else binding.decoder_kind,
	)
