class_name DeathInventoryService
extends RefCounted

const ContextType := preload("res://core/death/death_context.gd")
const FactsType := preload("res://core/death/death_item_facts.gd")
const RewearRegistryType := preload(
	"res://core/death/death_rewear_policy_registry.gd"
)
const RewearResultType := preload("res://core/death/death_rewear_result.gd")
const ResultType := preload("res://core/death/death_inventory_result.gd")
const CorpseStateType := preload("res://core/corpses/corpse_state.gd")
const CorpseDecayServiceType := preload(
	"res://core/corpses/corpse_decay_service.gd"
)
const DecayIntentType := preload(
	"res://core/corpses/corpse_decay_schedule_intent.gd"
)
const ArmorServiceType := preload("res://core/armor/armor_service.gd")
const ArmorTransitionResultType := preload(
	"res://core/armor/armor_transition_result.gd"
)
const EndpointType := preload("res://core/inventory/containment_endpoint.gd")
const DestinationType := preload(
	"res://core/inventory/inventory_transfer_destination.gd"
)
const TransferResultType := preload(
	"res://core/inventory/inventory_transfer_result.gd"
)
const TransferServiceType := preload(
	"res://core/inventory/inventory_transfer_service.gd"
)
const ItemInstanceType := preload("res://core/items/item_instance.gd")
const ItemDefinitionType := preload("res://core/items/item_definition.gd")

const LEGACY_FEMALE: StringName = &"女性"


## chard.c make_corpse() of `context`'s victim: every item they carry directly survives (the
## game has no item that dies with its owner here: 风泉's sword answers its owner's death through
## its item data, ItemContentDefinition.owner_killed_npc(), WorldMapCombatLifecycle), into the
## corpse (worn armour worn again) or, for a ghost, onto the floor.
static func process(
	context: ContextType,
	inventory: InventoryState,
	stacks: CombinedStackCollection,
	item_facts: Array[FactsType],
	rewear_registry: RewearRegistryType,
	corpse_item: ItemInstanceType = null,
	corpse_definition: ItemDefinitionType = null,
) -> ResultType:
	if inventory == null or stacks == null or rewear_registry == null:
		return ResultType.new(ResultType.Outcome.INVALID_DOMAIN_STATE)
	if context == null or not context.is_valid():
		return ResultType.new(ResultType.Outcome.INVALID_CONTEXT)
	var victim_endpoint: EndpointType = context.victim_endpoint()

	## chard.c checks ghosts before corpse creation and before wizardp().
	if context.victim_is_ghost:
		var ghost_snapshot: Array[StringName] = inventory.direct_children(
			victim_endpoint
		)
		var ghost_facts: Dictionary[StringName, FactsType] = _build_facts_map(
			item_facts
		)
		if not _facts_cover_snapshot(item_facts, ghost_facts, ghost_snapshot):
			return ResultType.new(
				ResultType.Outcome.INVALID_ITEM_FACTS,
				ResultType.Branch.GHOST,
				ghost_snapshot,
			)
		return _process_ghost(context, inventory, ghost_snapshot)

	if (
		corpse_item == null
		or corpse_definition == null
		or corpse_item.item_instance_id == &""
		or corpse_item.item_definition_id == &""
		or corpse_definition.item_definition_id == &""
		or corpse_item.item_definition_id != corpse_definition.item_definition_id
	):
		return ResultType.new(
			ResultType.Outcome.INVALID_CORPSE_IDENTITY,
			ResultType.Branch.WIZARD if context.victim_is_wizard else ResultType.Branch.NORMAL,
		)
	if not inventory.register_item(corpse_item, context.victim_body_own_weight):
		return ResultType.new(
			ResultType.Outcome.CORPSE_REGISTRATION_FAILED,
			ResultType.Branch.WIZARD if context.victim_is_wizard else ResultType.Branch.NORMAL,
		)
	var corpse: CorpseStateType = CorpseStateType.new(
		corpse_item.item_instance_id,
		context.victim_character_id,
		context.victim_display_name,
		context.victim_gender,
		context.victim_age,
		context.victim_maximum_encumbrance,
	)
	var placement: TransferResultType = TransferServiceType.new().transfer(
		inventory,
		corpse_item.item_instance_id,
		context.victim_environment,
	)
	var initial_intent: DecayIntentType = CorpseDecayServiceType.initial_intent(corpse)
	## The wizard check is deliberately after corpse creation and placement.
	if context.victim_is_wizard:
		return ResultType.new(
			ResultType.Outcome.COMPLETED,
			ResultType.Branch.WIZARD,
			[],
			[],
			[],
			corpse_item.item_instance_id,
			corpse,
			placement,
			initial_intent,
		)
	## The source takes the non-wizard direct inventory snapshot only after
	## corpse construction/placement and the wizard branch.
	var direct_snapshot: Array[StringName] = inventory.direct_children(victim_endpoint)
	var facts_by_id: Dictionary[StringName, FactsType] = _build_facts_map(item_facts)
	if not _facts_cover_snapshot(item_facts, facts_by_id, direct_snapshot):
		return _normal_result(
			ResultType.Outcome.INVALID_ITEM_FACTS,
			direct_snapshot,
			[],
			[],
			corpse,
			placement,
			initial_intent,
		)
	return _process_normal(
		context,
		inventory,
		direct_snapshot,
		facts_by_id,
		rewear_registry,
		corpse,
		placement,
		initial_intent,
	)


static func _build_facts_map(
	item_facts: Array[FactsType],
) -> Dictionary[StringName, FactsType]:
	var result: Dictionary[StringName, FactsType] = {}
	for facts: FactsType in item_facts:
		if (
			facts == null
			or not facts.has_valid_identity()
			or result.has(facts.item_instance_id)
		):
			return {}
		result[facts.item_instance_id] = facts
	return result


static func _facts_cover_snapshot(
	item_facts: Array[FactsType],
	facts_by_id: Dictionary[StringName, FactsType],
	direct_snapshot: Array[StringName],
) -> bool:
	if facts_by_id.size() != item_facts.size():
		return false
	for item_instance_id: StringName in direct_snapshot:
		if not facts_by_id.has(item_instance_id):
			return false
	return true


## chard.c of a ghost: no corpse; what it carried falls where it stood, last first.
static func _process_ghost(
	context: ContextType,
	inventory: InventoryState,
	direct_snapshot: Array[StringName],
) -> ResultType:
	var transfers: Array[TransferResultType] = []
	var survivors: Array[StringName] = direct_snapshot.duplicate()
	survivors.reverse()
	for item_instance_id: StringName in survivors:
		transfers.append(
			TransferServiceType.new().transfer(
				inventory,
				item_instance_id,
				context.victim_environment,
				context.victim_owner.equipment_state,
				context.victim_owner.armor_state,
			)
		)
	return _result(
		ResultType.Outcome.COMPLETED,
		ResultType.Branch.GHOST,
		direct_snapshot,
		transfers,
		[],
	)


static func _process_normal(
	context: ContextType,
	inventory: InventoryState,
	direct_snapshot: Array[StringName],
	facts_by_id: Dictionary[StringName, FactsType],
	rewear_registry: RewearRegistryType,
	corpse: CorpseStateType,
	placement: TransferResultType,
	initial_intent: DecayIntentType,
) -> ResultType:
	var survivors: Array[StringName] = direct_snapshot.duplicate()
	var corpse_destination: DestinationType = DestinationType.new(
		EndpointType.new(EndpointType.Kind.ITEM, corpse.corpse_item_instance_id),
		true,
		true,
		corpse.maximum_contents_encumbrance,
	)
	var transfers: Array[TransferResultType] = []
	var rewear_results: Array[RewearResultType] = []
	survivors.reverse()
	for item_instance_id: StringName in survivors:
		## chard.c reads query("equipped") inside the reverse survivor loop,
		## immediately before moving this exact object.
		var worn_slot: StringName = (
			context.victim_owner.armor_state.slot_for_instance(item_instance_id)
		)
		## Native (owner 2026-11-19; DECISIONS「死后留在身上」): what the player wields and
		## wears stays on them; the rest goes into the corpse as chard.c moves it.
		if context.victim_keeps_equipped and (
			worn_slot != &""
			or context.victim_owner.equipment_state.has_weapon_instance(item_instance_id)
		):
			continue
		if worn_slot != &"":
			var worn_facts: FactsType = facts_by_id[item_instance_id]
			if (
				not worn_facts.has_aligned_armor_definition()
				or worn_facts.armor_definition.armor_type != worn_slot
			):
				return _normal_result(
					ResultType.Outcome.INVALID_ITEM_FACTS,
					direct_snapshot,
					transfers,
					rewear_results,
					corpse,
					placement,
					initial_intent,
					item_instance_id,
				)
		var transfer: TransferResultType = TransferServiceType.new().transfer(
			inventory,
			item_instance_id,
			corpse_destination,
			context.victim_owner.equipment_state,
			context.victim_owner.armor_state,
		)
		transfers.append(transfer)
		if worn_slot != &"":
			var rewear: RewearResultType = _attempt_rewear(
				context,
				inventory,
				corpse,
				facts_by_id[item_instance_id],
				rewear_registry,
			)
			rewear_results.append(rewear)
			if rewear.outcome == RewearResultType.Outcome.DEPENDENCY_UNAVAILABLE:
				return _normal_result(
					ResultType.Outcome.REWEAR_DEPENDENCY_UNAVAILABLE,
					direct_snapshot,
					transfers,
					rewear_results,
					corpse,
					placement,
					initial_intent,
					item_instance_id,
				)
	return _normal_result(
		ResultType.Outcome.COMPLETED,
		direct_snapshot,
		transfers,
		rewear_results,
		corpse,
		placement,
		initial_intent,
	)


static func _attempt_rewear(
	context: ContextType,
	inventory: InventoryState,
	corpse: CorpseStateType,
	facts: FactsType,
	rewear_registry: RewearRegistryType,
) -> RewearResultType:
	var policy: int = rewear_registry.policy_for(facts.item_definition_id)
	if policy == RewearRegistryType.Policy.LATEMOON_SKIRT:
		if context.legacy_rewear_actor_gender == &"":
			return RewearResultType.new(
				RewearResultType.Outcome.DEPENDENCY_UNAVAILABLE,
				facts.item_instance_id,
				policy,
			)
		if context.legacy_rewear_actor_gender != LEGACY_FEMALE:
			return _fallback_after_failed_wear(context, inventory, facts, policy)
		var skirt_worn_location: int = _base_rewear(context, inventory, corpse, facts)
		return RewearResultType.new(
			(
				RewearResultType.Outcome.CUSTOM_SUCCESS_WITHOUT_WEAR
				if skirt_worn_location == RewearResultType.WornLocation.NONE
				else (
					RewearResultType.Outcome.WORN_ON_CORPSE
					if skirt_worn_location == RewearResultType.WornLocation.CORPSE
					else RewearResultType.Outcome.REWORN_ON_VICTIM
				)
			),
			facts.item_instance_id,
			policy,
			true,
			skirt_worn_location,
		)
	if policy == RewearRegistryType.Policy.BANDAGE_ALWAYS_FAILS:
		return _fallback_after_failed_wear(context, inventory, facts, policy)
	var worn_location: int = _base_rewear(context, inventory, corpse, facts)
	if worn_location == RewearResultType.WornLocation.NONE:
		return _fallback_after_failed_wear(context, inventory, facts, policy)
	return RewearResultType.new(
		(
			RewearResultType.Outcome.WORN_ON_CORPSE
			if worn_location == RewearResultType.WornLocation.CORPSE
			else (
				RewearResultType.Outcome.ALREADY_WORN_ON_VICTIM
				if not context.victim_owner.armor_state.is_worn(facts.item_instance_id)
				else RewearResultType.Outcome.REWORN_ON_VICTIM
			)
		),
		facts.item_instance_id,
		policy,
		true,
		worn_location,
	)


static func _base_rewear(
	context: ContextType,
	inventory: InventoryState,
	corpse: CorpseStateType,
	facts: FactsType,
) -> int:
	var parent: EndpointType = inventory.direct_parent(facts.item_instance_id)
	if parent == null:
		return RewearResultType.WornLocation.NONE
	var corpse_endpoint: EndpointType = EndpointType.new(
		EndpointType.Kind.ITEM,
		corpse.corpse_item_instance_id,
	)
	if parent.same_identity(corpse_endpoint):
		if corpse._try_wear(
			facts.armor_definition.armor_type,
			facts.item_instance_id,
			inventory,
		):
			return RewearResultType.WornLocation.CORPSE
		return RewearResultType.WornLocation.NONE
	var victim_endpoint: EndpointType = context.victim_endpoint()
	if parent.same_identity(victim_endpoint):
		var item: ItemInstanceType = ItemInstanceType.new(
			facts.item_instance_id,
			facts.item_definition_id,
		)
		var armor_result: ArmorTransitionResultType = ArmorServiceType.wear(
			context.victim_owner.armor_state,
			inventory,
			victim_endpoint,
			item,
			facts.armor_definition,
		)
		if armor_result.succeeded:
			return RewearResultType.WornLocation.VICTIM
	return RewearResultType.WornLocation.NONE


static func _fallback_after_failed_wear(
	context: ContextType,
	inventory: InventoryState,
	facts: FactsType,
	policy: int,
) -> RewearResultType:
	var parent: EndpointType = inventory.direct_parent(facts.item_instance_id)
	var equipment: EquipmentState = null
	var armor: ArmorState = null
	if parent != null and parent.same_identity(context.victim_endpoint()):
		equipment = context.victim_owner.equipment_state
		armor = context.victim_owner.armor_state
	var fallback: TransferResultType = TransferServiceType.new().transfer(
		inventory,
		facts.item_instance_id,
		context.victim_environment,
		equipment,
		armor,
	)
	return RewearResultType.new(
		(
			RewearResultType.Outcome.FALLBACK_TRANSFERRED
			if fallback.succeeded
			else RewearResultType.Outcome.FALLBACK_TRANSFER_FAILED
		),
		facts.item_instance_id,
		policy,
		false,
		RewearResultType.WornLocation.NONE,
		fallback,
	)


static func _normal_result(
	outcome: int,
	direct_snapshot: Array[StringName],
	transfers: Array[TransferResultType],
	rewear_results: Array[RewearResultType],
	corpse: CorpseStateType,
	placement: TransferResultType,
	initial_intent: DecayIntentType,
	stopped_item_id: StringName = &"",
) -> ResultType:
	return ResultType.new(
		outcome,
		ResultType.Branch.NORMAL,
		direct_snapshot,
		transfers,
		rewear_results,
		corpse.corpse_item_instance_id,
		corpse,
		placement,
		initial_intent,
		stopped_item_id,
	)


static func _result(
	outcome: int,
	branch: int,
	direct_snapshot: Array[StringName],
	transfers: Array[TransferResultType],
	rewear_results: Array[RewearResultType],
) -> ResultType:
	return ResultType.new(outcome, branch, direct_snapshot, transfers, rewear_results)
