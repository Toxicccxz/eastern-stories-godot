class_name EquipmentState
extends RefCounted

const EquippedWeaponRefType := preload("res://core/equipment/equipped_weapon_ref.gd")
const TransitionResultType := preload(
	"res://core/equipment/equipment_transition_result.gd"
)

## Typed equivalents of owner query_temp("weapon") and
## query_temp("secondary_weapon"). Armor slots and modifiers are not modeled.
var _primary_weapon: EquippedWeaponRefType
var _secondary_weapon: EquippedWeaponRefType


func is_primary_hand_empty() -> bool:
	return _primary_weapon == null


func is_secondary_hand_empty() -> bool:
	return _secondary_weapon == null


## This intentionally means both legacy weapon references are absent. LPC
## valid_learn() hooks do not inspect armor/shield when requiring empty hands.
func are_both_hands_empty() -> bool:
	return is_primary_hand_empty() and is_secondary_hand_empty()


func primary_weapon() -> EquippedWeaponRefType:
	return null if _primary_weapon == null else _primary_weapon.duplicate_snapshot()


func secondary_weapon() -> EquippedWeaponRefType:
	return null if _secondary_weapon == null else _secondary_weapon.duplicate_snapshot()


func primary_weapon_skill_type() -> StringName:
	return &"" if _primary_weapon == null else _primary_weapon.skill_type


func has_weapon_instance(instance_id: StringName) -> bool:
	return (
		(_primary_weapon != null and _primary_weapon.instance_id == instance_id)
		or (_secondary_weapon != null and _secondary_weapon.instance_id == instance_id)
	)


## Deterministic translation of feature/equip.c::wield(). shield_equipped is a
## narrow attempt-time projection of owner query_temp("armor/shield"); Phase
## 4A1 deliberately does not create an armor collection.
func wield(
	weapon: EquippedWeaponRefType,
	shield_equipped: bool,
) -> TransitionResultType:
	if weapon == null or not weapon.is_valid():
		return TransitionResultType.new(
			TransitionResultType.Outcome.INVALID_WEAPON_REFERENCE,
			false,
			false,
			&"" if weapon == null else weapon.instance_id,
		)
	## feature/equip.c returns success without mutation when the object already
	## has an equipped marker. cmds/std/wield.c rejects it before this call.
	if has_weapon_instance(weapon.instance_id):
		var existing_slot: int = (
			TransitionResultType.Slot.PRIMARY
			if _primary_weapon != null and _primary_weapon.instance_id == weapon.instance_id
			else TransitionResultType.Slot.SECONDARY
		)
		return TransitionResultType.new(
			TransitionResultType.Outcome.ALREADY_WIELDED,
			true,
			false,
			weapon.instance_id,
			existing_slot,
		)

	if weapon.is_two_handed:
		if not are_both_hands_empty() or shield_equipped:
			return TransitionResultType.new(
				TransitionResultType.Outcome.TWO_HANDED_REQUIRES_EMPTY_HANDS,
				false,
				false,
				weapon.instance_id,
			)
		_primary_weapon = weapon.duplicate_snapshot()
		return TransitionResultType.new(
			TransitionResultType.Outcome.WIELDED_PRIMARY,
			true,
			true,
			weapon.instance_id,
			TransitionResultType.Slot.PRIMARY,
		)

	## LPC always puts the first one-handed weapon in primary, even if it has
	## SECONDARY and even if a shield is worn.
	if _primary_weapon == null:
		_primary_weapon = weapon.duplicate_snapshot()
		return TransitionResultType.new(
			TransitionResultType.Outcome.WIELDED_PRIMARY,
			true,
			true,
			weapon.instance_id,
			TransitionResultType.Slot.PRIMARY,
		)

	if _secondary_weapon != null or shield_equipped:
		return TransitionResultType.new(
			TransitionResultType.Outcome.NO_FREE_HAND,
			false,
			false,
			weapon.instance_id,
		)

	if weapon.can_wield_as_secondary:
		_secondary_weapon = weapon.duplicate_snapshot()
		return TransitionResultType.new(
			TransitionResultType.Outcome.WIELDED_SECONDARY,
			true,
			true,
			weapon.instance_id,
			TransitionResultType.Slot.SECONDARY,
		)

	## A new non-secondary weapon displaces a SECONDARY-capable primary into the
	## secondary slot. This is the old unequip -> set primary -> re-wield order.
	if _primary_weapon.can_wield_as_secondary:
		var previous_primary_instance_id: StringName = _primary_weapon.instance_id
		## A legacy object may combine TWO_HANDED and SECONDARY. Its re-wield
		## then fails because the new primary already occupies weapon, and the
		## outer wield() ignores that failure: the old object remains unequipped.
		if _primary_weapon.is_two_handed:
			_primary_weapon = weapon.duplicate_snapshot()
			return TransitionResultType.new(
				TransitionResultType.Outcome.REPLACED_TWO_HANDED_PRIMARY,
				true,
				true,
				weapon.instance_id,
				TransitionResultType.Slot.PRIMARY,
				previous_primary_instance_id,
			)
		_secondary_weapon = _primary_weapon.duplicate_snapshot()
		_primary_weapon = weapon.duplicate_snapshot()
		return TransitionResultType.new(
			TransitionResultType.Outcome.SWAPPED_PRIMARY_TO_SECONDARY,
			true,
			true,
			weapon.instance_id,
			TransitionResultType.Slot.PRIMARY_AND_SECONDARY,
			previous_primary_instance_id,
		)

	return TransitionResultType.new(
		TransitionResultType.Outcome.PRIMARY_MUST_BE_UNWIELDED,
		false,
		false,
		weapon.instance_id,
	)


## Object identity in feature/equip.c is represented by stable runtime
## instance ID. Removing primary never promotes an existing secondary weapon.
func unwield(instance_id: StringName) -> TransitionResultType:
	if _primary_weapon != null and _primary_weapon.instance_id == instance_id:
		_primary_weapon = null
		return TransitionResultType.new(
			TransitionResultType.Outcome.UNWIELDED_PRIMARY,
			true,
			true,
			instance_id,
			TransitionResultType.Slot.PRIMARY,
		)
	if _secondary_weapon != null and _secondary_weapon.instance_id == instance_id:
		_secondary_weapon = null
		return TransitionResultType.new(
			TransitionResultType.Outcome.UNWIELDED_SECONDARY,
			true,
			true,
			instance_id,
			TransitionResultType.Slot.SECONDARY,
		)
	return TransitionResultType.new(
		TransitionResultType.Outcome.NOT_WIELDED,
		false,
		false,
		instance_id,
	)
