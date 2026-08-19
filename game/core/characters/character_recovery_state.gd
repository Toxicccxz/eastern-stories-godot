class_name CharacterRecoveryState
extends RefCounted

const CharacterInternalResourceStateType := preload(
	"res://core/characters/character_internal_resource_state.gd"
)

## Legacy field mappings:
## inner_force -> force / max_force
## mana        -> mana / max_mana
## atman       -> atman / max_atman
## food        -> food
## water       -> water
var inner_force: CharacterInternalResourceStateType
var mana: CharacterInternalResourceStateType
var atman: CharacterInternalResourceStateType
var food: int
var water: int


func _init(
	p_inner_force: CharacterInternalResourceStateType = null,
	p_mana: CharacterInternalResourceStateType = null,
	p_atman: CharacterInternalResourceStateType = null,
	p_food: int = 0,
	p_water: int = 0,
) -> void:
	inner_force = (
		p_inner_force
		if p_inner_force != null
		else CharacterInternalResourceStateType.new()
	)
	mana = p_mana if p_mana != null else CharacterInternalResourceStateType.new()
	atman = p_atman if p_atman != null else CharacterInternalResourceStateType.new()
	food = p_food
	water = p_water
