class_name CombatTacticalActionPolicy
extends RefCounted

## Trusted typed policies must be stateless. Both validations are read-only and
## RNG-free. Only execute may mutate the supplied exact authorities/use RNG.
## Production Flee is explicit; authored technique categories remain extension seams.
var _action_id: StringName
var _category: int
var _target_rule: int
var _blocks_when_busy: bool
var action_id: StringName:
	get: return _action_id
var category: int:
	get: return _category
var target_rule: int:
	get: return _target_rule
var blocks_when_busy: bool:
	get: return _blocks_when_busy


func _init(
	p_action_id: StringName = &"",
	p_category: int = -1,
	p_target_rule: int = -1,
	p_item_blocks_when_busy: bool = true,
) -> void:
	_action_id = p_action_id
	_category = p_category
	_target_rule = p_target_rule
	_blocks_when_busy = (
		p_category != CombatTacticalRequest.Category.ITEM or p_item_blocks_when_busy
	)


func is_valid() -> bool:
	return (
		not _action_id.is_empty()
		and _category in CombatTacticalRequest.Category.values()
		and _target_rule in CombatTacticalRequest.TargetRule.values()
	)


func validate_request(_context: CombatTacticalContext) -> int:
	return CombatTacticalResult.Code.POLICY_UNSUPPORTED

func supports_mode(_mode: int) -> bool:
	return true


## Whether the battle panel offers the action to a player in this state (null
## without a Session). Advisory, like the mode: request and execution still validate.
func offered_to(_state: CharacterState) -> bool:
	return true


## A CURRENT_HOSTILE action that may run with no current target (the player picked
## none yet): it then goes without one and chooses for itself.
func accepts_no_target() -> bool:
	return false


## A CURRENT_HOSTILE action that may name the player's unconscious victim in a fight
## to the death (feature/attack.c: a killer keeps it as an enemy).
func reaches_downed_target() -> bool:
	return false


func validate_execution(_context: CombatTacticalContext) -> int:
	return CombatTacticalResult.Code.POLICY_UNSUPPORTED


func execute(
	_context: CombatTacticalContext,
	_random_source: CombatRandomSource,
) -> CombatTacticalExecutionResult:
	return CombatTacticalExecutionResult.new()
