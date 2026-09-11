extends WorldResidentMapCoordinator

## Isolated QA composition, not ApplicationShell or a second production Session.
var birth: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(&"nge3-fixture")
var npc_random: NpcInitializationRandomSource = GodotNpcInitializationRandomSource.new(21, true)
var combat_random: CombatRandomSource = GodotCombatRandomSource.new(22, true)
var world_random: WorldInteractionRandomSource = GodotWorldInteractionRandomSource.new(23, true)
var inn: SnowInnController
var outdoor: SnowOutdoorController
var zone_history: Array[StringName] = []


func _ready() -> void:
	if not birth.initialize(&"nge3.fixture.player", CharacterState.GENDER_MALE, "Player", allocator):
		push_error("NGE3 QA birth failed")
		return
	_player = NewPlayerRuntimeComposition.create(&"nge3.fixture.player", birth.player, SnowWorldDefinitions.birth_location())
	_world_simulation_gate = WorldSimulationGate.new()
	inn = (load(SnowWorldDefinitions.INN_SCENE) as PackedScene).instantiate() as SnowInnController
	outdoor = (load(SnowWorldDefinitions.OUTDOOR_SCENE) as PackedScene).instantiate() as SnowOutdoorController
	for map: WorldResidentMapController in [inn, outdoor]:
		if not map.configure_world_authorities(_player, birth.inventory, birth.stacks, birth.item_index, npc_random, combat_random, world_random, allocator, _world_simulation_gate) or not register_resident_map(map):
			push_error("NGE3 QA map binding failed")
			return
		map.set_restore_staging(true)
		active_map_slot.add_child(map)
		if not map.initialize_map():
			push_error("NGE3 QA map initialization failed")
			return
		map.prepare_for_deactivation()
		active_map_slot.remove_child(map)
	_active_map_id = inn.map_id()
	inn.set_restore_staging(false)
	active_map_slot.add_child(inn)
	_initialized = inn.complete_activation()
	if not _initialized:
		push_error("NGE3 QA activation failed")


func _process(_delta: float) -> void:
	if _initialized:
		var zone: StringName = _player.world_location().zone_id
		if zone_history.is_empty() or zone_history.back() != zone:
			zone_history.append(zone)


func _exit_tree() -> void:
	for map: WorldResidentMapController in _resident_maps.values():
		if is_instance_valid(map) and map.get_parent() == null:
			map.free()
	_resident_maps.clear()
