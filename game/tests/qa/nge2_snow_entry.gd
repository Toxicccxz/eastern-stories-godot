extends Node

## QA-only one-map entry fixture, not a second production Session or New Game.
const PLAYER_ID: StringName = &"nge2.fixture.player"

var birth: NewPlayerInventoryComposition = NewPlayerInventoryComposition.new()
var allocator: SessionItemIdAllocator = SessionItemIdAllocator.new(&"nge2-fixture")
var player: WorldPlayerRuntimeState
var npc_random: NpcInitializationRandomSource = GodotNpcInitializationRandomSource.new(21, true)
var combat_random: CombatRandomSource = GodotCombatRandomSource.new(22, true)
var world_random: WorldInteractionRandomSource = GodotWorldInteractionRandomSource.new(23, true)
var gate: WorldSimulationGate = WorldSimulationGate.new()
var inn: SnowInnController
var initialized: bool = false


func _ready() -> void:
	if not birth.initialize(PLAYER_ID, CharacterState.GENDER_MALE, "Player", allocator):
		push_error("NGE2 QA birth failed")
		return
	player = NewPlayerRuntimeComposition.create(PLAYER_ID, birth.player, SnowWorldDefinitions.birth_location())
	var scene: PackedScene = load(SnowWorldDefinitions.INN_SCENE)
	inn = scene.instantiate() as SnowInnController
	if not inn.configure_world_authorities(player, birth.inventory, birth.stacks, birth.item_index,
		npc_random, combat_random, world_random, allocator, gate):
		push_error("NGE2 QA authority configuration failed")
		return
	add_child(inn)
	initialized = inn.is_map_initialized() and inn.complete_activation()
	if not initialized:
		push_error("NGE2 QA Inn activation failed")
