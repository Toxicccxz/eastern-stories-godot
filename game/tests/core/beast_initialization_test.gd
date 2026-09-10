extends RefCounted

const ScriptedRandom := preload("res://tests/support/scripted_npc_initialization_random_source.gd")

var _assertions: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_defaults()
	_test_presence_skips_each_draw()
	_test_authored_zero_and_resource_presence()
	_test_unrepresentable_tracks_rejected()
	_test_invalid_draws()
	_test_unknown_race_rejected()
	_test_missing_human_defaults_unchanged()
	return {"assertions": _assertions, "failures": _failures.duplicate()}


func _test_defaults() -> void:
	# beast.c order: age, str, cor, int, (spi=0), cps, per, con; kar absent=0.
	var low_rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new([0, 0, 0, 0, 0, 0, 0])
	var low: NpcRuntimeState = _create(_definition(), low_rng)
	_eq(low != null, true, "missing Beast facts initialize")
	if low == null:
		return
	_eq(low_rng.requested_bounds(), [40, 41, 21, 11, 11, 31, 41], "no heartbeat/spi/kar draws")
	_eq(low.age, 5, "default age lower endpoint")
	_eq(_attributes(low), [5, 5, 5, 0, 5, 5, 5, 0], "Beast lower endpoints")
	_eq(low.character_state.gender, &"雄性", "Beast default gender")
	_track(low.character_state.essence, [90, 90, 90], "default age5 gin")
	_track(low.character_state.vitality, [50, 50, 50], "default age5 kee")
	_track(low.character_state.spirit, [50, 50, 50], "default age5 sen")
	_eq(low.body_weight, -8000, "negative formula result not clamped")
	_eq(low.maximum_encumbrance, 25000, "common raw strength capacity")
	var high_rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new([39, 40, 20, 10, 10, 30, 40])
	var high: NpcRuntimeState = _create(_definition(), high_rng)
	_eq(high != null, true, "upper endpoints initialize")
	if high == null:
		return
	_eq(high.age, 44, "default age upper endpoint")
	_eq(_attributes(high), [45, 25, 15, 0, 15, 35, 45, 0], "Beast upper endpoints")
	_track(high.character_state.essence, [304, 304, 304], "age44 gin")
	_track(high.character_state.vitality, [545, 545, 545], "age44 kee")
	_track(high.character_state.spirit, [290, 290, 290], "age44 sen")
	_eq(high_rng.requested_bounds(), low_rng.requested_bounds(), "same ordered bounds at endpoints")


func _test_presence_skips_each_draw() -> void:
	# Each authored zero is present, not a request for a default. Expected bounds
	# below are literal source sequences, independently of factory policy constants.
	var expected_bounds: Array[Array] = [
		[21, 11, 11, 31, 41], [41, 11, 11, 31, 41],
		[41, 21, 11, 31, 41], [41, 21, 11, 11, 31, 41],
		[41, 21, 11, 31, 41], [41, 21, 11, 11, 41],
		[41, 21, 11, 11, 31], [41, 21, 11, 11, 31, 41],
	]
	var expected_values: Array[Array] = [
		[0, 5, 5, 0, 5, 5, 5, 0], [5, 0, 5, 0, 5, 5, 5, 0],
		[5, 5, 0, 0, 5, 5, 5, 0], [5, 5, 5, 0, 5, 5, 5, 0],
		[5, 5, 5, 0, 0, 5, 5, 0], [5, 5, 5, 0, 5, 0, 5, 0],
		[5, 5, 5, 0, 5, 5, 0, 0], [5, 5, 5, 0, 5, 5, 5, 0],
	]
	for index: int in range(8):
		var overrides: NpcBaseAttributeOverrides = NpcBaseAttributeOverrides.new(
			index == 0, 0, index == 1, 0, index == 2, 0, index == 3, 0,
			index == 4, 0, index == 5, 0, index == 6, 0, index == 7, 0,
		)
		var rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new([0, 0, 0, 0, 0, 0])
		var npc: NpcRuntimeState = _create(_definition(overrides, null, true, 0), rng)
		_eq(npc != null, true, "authored field %d accepted" % index)
		if npc == null:
			continue
		_eq(npc.age, 0, "authored age zero skips draw and is not clamped")
		_eq(rng.requested_bounds(), expected_bounds[index], "skip only authored field %d" % index)
		_eq(_attributes(npc), expected_values[index], "authored zero %d retained" % index)


func _test_authored_zero_and_resource_presence() -> void:
	var attributes: NpcBaseAttributeOverrides = NpcBaseAttributeOverrides.new(
		true, 40, true, 70, true, 10, true, 99, true, 7, true, 8, true, 9, true, -5,
	)
	var resources: NpcResourceOverrides = NpcResourceOverrides.new(
		NpcResourceTrackOverride.new(false, 0, false, 0, true, 0),
		NpcResourceTrackOverride.new(true, 0, true, 12, false, 0),
		NpcResourceTrackOverride.new(true, -1, true, -1, true, 17),
	)
	var rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new()
	var npc: NpcRuntimeState = _create(_definition(attributes, resources, true, -4, true, &"雌性"), rng)
	_eq(npc != null, true, "explicit valid fields initialize")
	if npc == null:
		return
	_eq(rng.call_count(), 0, "all authored attributes/age consume zero draws")
	_eq(npc.age, -4, "no authored age floor")
	_eq(npc.character_state.gender, &"雌性", "authored gender retained")
	_eq(_attributes(npc), [40, 70, 10, 99, 7, 8, 9, -5], "including spi/kar authored nondefaults")
	_track(npc.character_state.essence, [0, 0, 0], "explicit maximum zero not formula")
	_track(npc.character_state.vitality, [0, 12, 50], "authored current/effective with derived max")
	_track(npc.character_state.spirit, [-1, -1, 17], "existing negative threshold retained")
	var current_only: NpcRuntimeState = _create(_definition(attributes,
		NpcResourceOverrides.new(NpcResourceTrackOverride.new(true, 3)), true, 400), ScriptedRandom.new())
	_eq(current_only != null, true, "current alone supplied")
	if current_only != null:
		_track(current_only.character_state.essence, [3, 660, 660], "missing effective uses maximum not current")


func _test_unrepresentable_tracks_rejected() -> void:
	# chard.c leaves these unchanged; the closed resource type cannot. Reject,
	# don't silently normalize them or open wolf migration in this slice.
	var invalid_tracks: Array[NpcResourceTrackOverride] = [
		NpcResourceTrackOverride.new(true, 200, true, 200),
		NpcResourceTrackOverride.new(false, 0, true, 20), # missing current -> max, NOT eff
		NpcResourceTrackOverride.new(true, -2),
		NpcResourceTrackOverride.new(true, -1, true, -2),
		NpcResourceTrackOverride.new(false, 0, false, 0, true, -1),
	]
	for invalid: NpcResourceTrackOverride in invalid_tracks:
		for track_index: int in range(3):
			var tracks: Array[NpcResourceTrackOverride] = [null, null, null]
			tracks[track_index] = invalid
			var inventory: InventoryState = InventoryState.new()
			var npc: NpcRuntimeState = _create(_definition(null,
				NpcResourceOverrides.new(tracks[0], tracks[1], tracks[2]), true, 4),
				ScriptedRandom.new([0, 0, 0, 0, 0, 0]), inventory)
			_eq(npc, null, "unrepresentable track %d rejected" % track_index)
			_eq(inventory.registered_item_ids().size(), 0, "rejection before loadout mutation")


func _test_invalid_draws() -> void:
	# Check both invalid edges at every actual Beast draw, not only the first.
	var bounds: Array[int] = [40, 41, 21, 11, 11, 31, 41]
	for index: int in range(bounds.size()):
		for invalid: int in [-1, bounds[index]]:
			var values: Array[int] = [0, 0, 0, 0, 0, 0, 0]
			values[index] = invalid
			var rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new(values)
			_eq(_create(_definition(), rng), null, "invalid draw rejected")
			_eq(rng.call_count(), index + 1, "stop at first invalid draw; no reroll")


func _test_unknown_race_rejected() -> void:
	var rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new()
	var unknown: NpcDefinition = NpcDefinition.new(&"test.unknown", "test.c", "Test", [&"test"], &"unknown")
	_eq(_create(unknown, rng), null, "no generic unknown-race fallback")
	_eq(rng.call_count(), 0, "unknown race draws none")


func _test_missing_human_defaults_unchanged() -> void:
	# human.c remains age random(30)+15 and eight random(21)+10 draws.
	var human: NpcDefinition = NpcDefinition.new(&"test.human", "test/human.c", "Human", [&"human"], &"human")
	var rng: ScriptedNpcInitializationRandomSource = ScriptedRandom.new([29, 0, 20, 1, 19, 2, 18, 3, 17])
	var npc: NpcRuntimeState = _create(human, rng)
	_eq(npc != null, true, "missing human defaults still initialize")
	if npc == null:
		return
	_eq(rng.requested_bounds(), [30, 21, 21, 21, 21, 21, 21, 21, 21], "human draw order unchanged")
	_eq(npc.age, 44, "human maximum default age")
	_eq(_attributes(npc), [10, 30, 11, 29, 12, 28, 13, 27], "human includes randomized spi and karma")
	_eq(npc.character_state.gender, &"男性", "human gender unchanged")
	_track(npc.character_state.essence, [150, 150, 150], "human age44 gin")
	_track(npc.character_state.vitality, [220, 220, 220], "human age44 kee")
	_track(npc.character_state.spirit, [170, 170, 170], "human age44 sen")
	_eq(npc.body_weight, 40000, "human weight unchanged")
	_eq(npc.maximum_encumbrance, 50000, "human capacity unchanged")


func _definition(
	attributes: NpcBaseAttributeOverrides = null,
	resources: NpcResourceOverrides = null,
	has_age: bool = false, age: int = 0,
	has_gender: bool = false, gender: StringName = &"",
) -> NpcDefinition:
	return NpcDefinition.new(&"test.beast", "test/beast.c", "Test Beast", [&"beast"],
		&"beast", has_gender, gender, has_age, age, attributes, resources)


func _create(
	definition: NpcDefinition, rng: ScriptedNpcInitializationRandomSource,
	inventory: InventoryState = null,
) -> NpcRuntimeState:
	return NpcCharacterStateFactory.new().create_one(
		definition, &"test.character", &"test.spawn", &"test.point",
		WorldLocationState.new(&"test.region", &"test.map", &"test.zone", &"test.location"),
		InventoryState.new() if inventory == null else inventory,
		CombinedStackCollection.new(), rng, [],
	)


func _attributes(npc: NpcRuntimeState) -> Array[int]:
	var a: CharacterBaseAttributes = npc.character_state.attributes
	return [a.strength, a.courage, a.intelligence, a.spirituality,
		a.composure, a.personality, a.constitution, a.karma]


func _track(track: CharacterResourceState, expected: Array[int], label: String) -> void:
	_eq([track.current, track.effective, track.maximum], expected, label)
	_eq(track.has_valid_invariants(), true, label + " invariant")


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_assertions += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
