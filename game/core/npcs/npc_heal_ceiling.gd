class_name NpcHealCeiling
extends RefCounted

## How far time away from the player heals an NPC (DECISIONS「别的地图时间补算」): to what
## create() made it, no further. ES2's std/room.c clean_up() reloaded a room nobody had been
## in with its NPCs as made, so one made weak (小娟 只剩一口气, chen.c's force 2000 of 3200)
## was found so; an NPC made whole heals whole. Values create() leaves to setup() (or draws)
## are the maximum. On the player's map the heart beat heals as ES2's did.

## [current, effective] caps of gin, kee and sen (-1: the maximum), then atman, force, mana.
var _primary: Array[Array] = []
var _internal: Array[int] = []


static func of(definition: NpcDefinition) -> NpcHealCeiling:
	var ceiling: NpcHealCeiling = NpcHealCeiling.new()
	var overrides: NpcResourceOverrides = definition.resource_overrides()
	for track: NpcResourceTrackOverride in [overrides.essence(), overrides.vitality(), overrides.spirit()]:
		var effective: int = track.effective() if track != null and track.has_effective() else -1
		var current: int = track.current() if track != null and track.has_current() else effective
		ceiling._primary.append([current, effective])
	for key: StringName in [&"atman", &"force", &"mana"]:
		ceiling._internal.append(definition.internal_power(key) if definition.has_internal_power(key) else -1)
	return ceiling


## Whether create() made it short of a maximum (else time away heals it whole).
func caps_anything() -> bool:
	for caps: Array in _primary:
		if caps[0] >= 0 or caps[1] >= 0:
			return true
	for cap: int in _internal:
		if cap >= 0:
			return true
	return false


## Whether `character` is healed as far as time away takes it: gin/kee/sen and their
## effective values, atman/force/mana at their caps or not growing (raw skill / 2 is 0).
func reached(character: CharacterState, skills: RecoverySkillLevels) -> bool:
	var primaries: Array[CharacterResourceState] = _primaries(character)
	for index: int in 3:
		var resource: CharacterResourceState = primaries[index]
		if resource.effective < _cap(_primary[index][1], resource.maximum) or resource.current < _cap(_primary[index][0], resource.effective):
			return false
	var internals: Array[CharacterInternalResourceState] = _internals(character)
	var raw: Array[int] = [skills.raw_magic, skills.raw_force, skills.raw_spells]
	for index: int in 3:
		var resource: CharacterInternalResourceState = internals[index]
		if resource.maximum > 0 and raw[index] / 2 > 0 and resource.current < _cap(_internal[index], resource.maximum):
			return false
	return true


## What heal_up() comes to given time enough, no further than the caps: none is lowered.
func fill(character: CharacterState, skills: RecoverySkillLevels) -> void:
	var primaries: Array[CharacterResourceState] = _primaries(character)
	for index: int in 3:
		var resource: CharacterResourceState = primaries[index]
		resource.effective = maxi(resource.effective, _cap(_primary[index][1], resource.maximum))
		resource.current = maxi(resource.current, _cap(_primary[index][0], resource.effective))
	var internals: Array[CharacterInternalResourceState] = _internals(character)
	var raw: Array[int] = [skills.raw_magic, skills.raw_force, skills.raw_spells]
	for index: int in 3:
		var resource: CharacterInternalResourceState = internals[index]
		if resource.maximum > 0 and raw[index] / 2 > 0:
			resource.current = maxi(resource.current, _cap(_internal[index], resource.maximum))


## The values heal_up() may raise, as they stand (before a catch-up, for hold()).
func snapshot(character: CharacterState) -> Array[int]:
	var values: Array[int] = []
	for resource: CharacterResourceState in _primaries(character):
		values.append_array([resource.current, resource.effective])
	for resource: CharacterInternalResourceState in _internals(character):
		values.append(resource.current)
	return values


## After a catch-up: what it healed past a cap (and past what it stood at before) is taken
## back; nothing it took away (a condition's wound) is given back.
func hold(character: CharacterState, before: Array[int]) -> void:
	var primaries: Array[CharacterResourceState] = _primaries(character)
	for index: int in 3:
		var resource: CharacterResourceState = primaries[index]
		var effective_cap: int = maxi(before[index * 2 + 1], _cap(_primary[index][1], resource.maximum))
		if resource.effective > effective_cap:
			resource.effective = effective_cap
		var current_cap: int = maxi(before[index * 2], _cap(_primary[index][0], resource.effective))
		if resource.current > current_cap:
			resource.current = current_cap
	var internals: Array[CharacterInternalResourceState] = _internals(character)
	for index: int in 3:
		var resource: CharacterInternalResourceState = internals[index]
		var cap: int = maxi(before[6 + index], _cap(_internal[index], resource.maximum))
		if resource.current > cap:
			resource.current = cap


static func _cap(authored: int, limit: int) -> int:
	return limit if authored < 0 else mini(authored, limit)


static func _primaries(character: CharacterState) -> Array[CharacterResourceState]:
	return [character.essence, character.vitality, character.spirit]


static func _internals(character: CharacterState) -> Array[CharacterInternalResourceState]:
	return [character.recovery.atman, character.recovery.inner_force, character.recovery.mana]
