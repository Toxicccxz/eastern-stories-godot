extends RefCounted

const Fixture := preload("res://tests/support/game_save_test_fixture.gd")

var _assertion_count: int = 0
var _failures: Array[String] = []


func run_all() -> Dictionary[String, Variant]:
	_test_decimal_int64_contract()
	_test_substantial_round_trip_and_determinism()
	_test_equivalent_input_order_is_canonical()
	_test_strict_shape_and_security_failures()
	_test_finite_position_and_duplicate_failures()
	_test_known_condition_payload_compatibility()
	_test_input_arrays_are_defensive()
	return {"assertions": _assertion_count, "failures": _failures.duplicate()}


func _test_decimal_int64_contract() -> void:
	var valid: Array[int] = [0, 1, -1, 42, 9223372036854775807, -9223372036854775807 - 1]
	for value: int in valid:
		var encoded: String = DecimalInt64Codec.encode(value)
		var decoded: GameSaveResult = DecimalInt64Codec.decode(encoded, "integer")
		_assert_true(decoded.succeeded(), "canonical int64 decodes: %s" % encoded)
		_assert_eq(DecimalInt64Codec.integer_value(decoded), value, "canonical int64 round-trips: %s" % encoded)
	var invalid: Array[Variant] = ["", " ", "\t1", "+1", "01", "-0", "-01", "1.0", "1e3", "0x10", "１２", "١", "9223372036854775808", "-9223372036854775809", 1]
	for value: Variant in invalid:
		var result: GameSaveResult = DecimalInt64Codec.decode(value, "integer")
		_assert_false(result.succeeded(), "invalid decimal rejects: %s" % str(value))
	_assert_eq(DecimalInt64Codec.decode("9223372036854775808").outcome, GameSaveResult.Outcome.INTEGER_OUT_OF_RANGE, "positive overflow is typed")
	_assert_eq(DecimalInt64Codec.decode("-9223372036854775809").outcome, GameSaveResult.Outcome.INTEGER_OUT_OF_RANGE, "negative overflow is typed")


func _test_substantial_round_trip_and_determinism() -> void:
	var source: GameSaveSnapshot = Fixture.substantial()
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(source)
	_assert_true(encoded.succeeded(), "nontrivial typed snapshot encodes")
	_assert_true(encoded.text.contains("\"9223372036854775807\""), "gameplay int64 is encoded as a JSON string")
	_assert_true(encoded.text.contains("\"-9223372036854775808\""), "INT64_MIN is encoded losslessly")
	_assert_false(encoded.text.contains("script"), "save has no serialized script field")
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_assert_true(decoded.succeeded(), "nontrivial JSON decodes to typed snapshot")
	var reencoded: GameSaveResult = GameSaveJsonCodec.encode(decoded.snapshot)
	_assert_eq(reencoded.text, encoded.text, "typed round-trip has canonical deterministic JSON")
	_assert_eq(decoded.snapshot.player.character.kee.current, 82, "player resource value survives")
	_assert_eq(decoded.snapshot.player.character.skills.raw_levels[0].skill_id, &"force", "skill records sort by stable ID")
	_assert_eq(decoded.snapshot.player.character.conditions[1].legacy_message, "毒性仍在。", "typed poison payload survives UTF-8")
	_assert_eq(decoded.snapshot.player.world_location.zone_id, &"zone:pine", "zone survives independently")
	_assert_eq(decoded.snapshot.player.world_location.combat_location_id, &"combat:pine", "combat location survives independently")
	_assert_eq(decoded.snapshot.items.schema_version, 1, "embedded item schema stays independently versioned")
	_assert_eq(decoded.snapshot.items.item_records.size(), 4, "existing native item records are directly embedded")
	_assert_eq(decoded.snapshot.npc_spawn_states.size(), 1, "typed NPC structural record survives")
	_assert_eq(decoded.snapshot.corpses.size(), 1, "typed corpse structural record survives")
	var detached_player = decoded.snapshot.player
	detached_player.character.kee.current = -1
	_assert_eq(decoded.snapshot.player.character.kee.current, 82, "root snapshot returns defensive nested values")
	var detached_items: NativeItemStateSnapshot = decoded.snapshot.items
	detached_items._schema_version = 99
	_assert_eq(decoded.snapshot.items.schema_version, 1, "embedded item snapshot getter is defensive")


func _test_equivalent_input_order_is_canonical() -> void:
	var root: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["skills"]["mappings"].append({"use_id": "unarmed", "skill_id": "unarmed"})
	var second_npc: Dictionary = root["npc_spawn_states"][0].duplicate(true)
	second_npc["spawn_id"] = "spawn:fat"
	second_npc["spawn_point_id"] = "spawn-point:fat"
	second_npc["character_id"] = "character:fat"
	root["npc_spawn_states"].append(second_npc)
	var second_corpse: Dictionary = root["corpses"][0].duplicate(true)
	second_corpse["corpse_item_instance_id"] = "corpse:fat"
	second_corpse["victim_character_id"] = "character:fat"
	root["corpses"].append(second_corpse)
	var second_equipment: Dictionary = root["items"]["equipment"][0].duplicate(true)
	second_equipment["character_id"] = "character:tall"
	root["items"]["equipment"].append(second_equipment)
	var second_armor: Dictionary = root["items"]["armor"][0].duplicate(true)
	second_armor["character_id"] = "character:tall"
	root["items"]["armor"].append(second_armor)
	var canonical: GameSaveResult = _decode_root(root)
	_assert_true(canonical.succeeded(), "multi-record ordering fixture is structurally valid")
	var canonical_text: String = GameSaveJsonCodec.encode(canonical.snapshot).text
	for values: Array in [
		root["player"]["character"]["skills"]["raw_levels"],
		root["player"]["character"]["skills"]["learned_progress"],
		root["player"]["character"]["skills"]["mappings"],
		root["player"]["character"]["conditions"],
		root["npc_spawn_states"],
		root["corpses"],
		root["items"]["records"],
		root["items"]["equipment"],
		root["items"]["armor"],
	]:
		values.reverse()
	var reordered: GameSaveResult = _decode_root(root)
	_assert_true(reordered.succeeded(), "equivalent reversed collections decode")
	_assert_eq(GameSaveJsonCodec.encode(reordered.snapshot).text, canonical_text, "ID-addressed collection ordering is canonical")


func _test_strict_shape_and_security_failures() -> void:
	_assert_eq(GameSaveJsonCodec.decode("").outcome, GameSaveResult.Outcome.MALFORMED_JSON, "empty JSON is malformed")
	_assert_eq(GameSaveJsonCodec.decode("{\"metadata\":").outcome, GameSaveResult.Outcome.MALFORMED_JSON, "truncated JSON is malformed")
	_assert_eq(GameSaveJsonCodec.decode("[]").outcome, GameSaveResult.Outcome.INVALID_ROOT, "wrong root type is typed")
	var root: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root.erase("player")
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.MISSING_FIELD, "missing root field rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["unknown"] = {"script": "res://evil.gd", "callable": "Callable", "node": "NodePath"}
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_ROOT, "unknown object-bearing field rejects without loading")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["metadata"]["format_id"] = "another-format"
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_FORMAT_ID, "wrong format ID rejects distinctly")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["metadata"]["schema_version"] = 2
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.UNSUPPORTED_GAME_SCHEMA, "unsupported game schema rejects distinctly")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["items"]["schema_version"] = 2
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.UNSUPPORTED_ITEM_SCHEMA, "unsupported item schema rejects distinctly")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["resources"]["kee"]["current"] = 82
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_FIELD_TYPE, "numeric gameplay integer rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["attributes"]["strength"] = "01"
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_INTEGER, "noncanonical gameplay integer rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["rng"]["combat"]["adapter_id"] = "future-rng"
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_RANDOM_STREAM, "incompatible RNG adapter rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["conditions"][0]["damage"] = "1"
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_ROOT, "known duration payload rejects poison field")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["resources"]["kee"]["typo"] = "1"
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_ROOT, "nested unknown field rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["resources"]["kee"].erase("effective")
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.MISSING_FIELD, "nested missing field rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["family"]["family_id"] = "res://evil.gd"
	_assert_true(_decode_root(root).succeeded(), "path-like gameplay text remains inert data")


func _test_finite_position_and_duplicate_failures() -> void:
	var invalid_snapshot: GameSaveSnapshot = Fixture.substantial()
	var invalid_player = invalid_snapshot.player
	invalid_player.map_position.x = NAN
	invalid_snapshot = GameSaveSnapshot.new(invalid_snapshot.metadata, invalid_snapshot.session_kind, invalid_snapshot.item_id_allocator, invalid_player, invalid_snapshot.npc_spawn_states, invalid_snapshot.corpses, invalid_snapshot.items, invalid_snapshot.combat_rng, invalid_snapshot.npc_initialization_rng, invalid_snapshot.world_interaction_rng)
	_assert_eq(GameSaveJsonCodec.encode(invalid_snapshot).outcome, GameSaveResult.Outcome.INVALID_FINITE_NUMBER, "NaN position rejects before encode")
	invalid_snapshot = Fixture.substantial()
	invalid_player = invalid_snapshot.player
	invalid_player.map_position.y = INF
	invalid_snapshot = GameSaveSnapshot.new(invalid_snapshot.metadata, invalid_snapshot.session_kind, invalid_snapshot.item_id_allocator, invalid_player, invalid_snapshot.npc_spawn_states, invalid_snapshot.corpses, invalid_snapshot.items, invalid_snapshot.combat_rng, invalid_snapshot.npc_initialization_rng, invalid_snapshot.world_interaction_rng)
	_assert_eq(GameSaveJsonCodec.encode(invalid_snapshot).outcome, GameSaveResult.Outcome.INVALID_FINITE_NUMBER, "infinite position rejects before encode")
	var root: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["map_position"]["x"] = "12.5"
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_FIELD_TYPE, "numeric string position rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["skills"]["raw_levels"].append(root["player"]["character"]["skills"]["raw_levels"][0].duplicate(true))
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "duplicate raw skill ID rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["items"]["records"].append(root["items"]["records"][0].duplicate(true))
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "duplicate item ID rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["npc_spawn_states"].append(root["npc_spawn_states"][0].duplicate(true))
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "duplicate NPC spawn-point ID rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	var same_spawn_slot: Dictionary = root["npc_spawn_states"][0].duplicate(true)
	same_spawn_slot["spawn_point_id"] = "spawn-point:second"
	same_spawn_slot["character_id"] = "character:second"
	root["npc_spawn_states"].append(same_spawn_slot)
	_assert_true(_decode_root(root).succeeded(), "one authored spawn may own multiple stable spawn-point slots")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["npc_spawn_states"][0]["character_id"] = root["player"]["character_id"]
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "player and NPC character IDs must be unique")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	var another_npc: Dictionary = root["npc_spawn_states"][0].duplicate(true)
	another_npc["spawn_id"] = "spawn:second"
	root["npc_spawn_states"].append(another_npc)
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "NPC character IDs must be unique across spawn records")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["conditions"].append(root["player"]["character"]["conditions"][0].duplicate(true))
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "duplicate condition ID rejects")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["items"]["equipment"].append(root["items"]["equipment"][0].duplicate(true))
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.DUPLICATE_ID, "duplicate equipment authority rejects")


func _test_known_condition_payload_compatibility() -> void:
	var root: Dictionary = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["conditions"][0] = {
		"condition_id": "bandaged",
		"payload_kind": "poison",
		"damage": "1",
		"remaining": "2",
		"legacy_message": "",
	}
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_SNAPSHOT, "known duration condition rejects poison payload")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["conditions"][0] = {
		"condition_id": "poison",
		"payload_kind": "duration",
		"remaining": "2",
	}
	_assert_eq(_decode_root(root).outcome, GameSaveResult.Outcome.INVALID_SNAPSHOT, "known poison condition rejects duration payload")
	root = JSON.parse_string(GameSaveJsonCodec.encode(Fixture.substantial()).text)
	root["player"]["character"]["conditions"][0]["condition_id"] = "open-duration"
	_assert_true(_decode_root(root).succeeded(), "open condition ID accepts represented typed duration payload")


func _test_input_arrays_are_defensive() -> void:
	var raw: Array[GameSaveValueTypes.SkillValueSnapshot] = [
		GameSaveValueTypes.SkillValueSnapshot.new(&"force", 9),
	]
	var skills := GameSaveValueTypes.SkillStateSnapshot.new(true, false, raw)
	raw[0].value = 99
	raw.append(GameSaveValueTypes.SkillValueSnapshot.new(&"unarmed", 8))
	_assert_eq(skills.raw_levels.size(), 1, "skill snapshot copies caller array")
	_assert_eq(skills.raw_levels[0].value, 9, "skill snapshot copies caller record")
	var conditions: Array[GameSaveValueTypes.ConditionSnapshot] = [
		GameSaveValueTypes.ConditionSnapshot.duration(&"bandaged", 3),
	]
	var character := GameSaveValueTypes.CharacterStateSnapshot.new(
		&"女性", null, null, null, null, null, null, null, conditions,
	)
	conditions[0].remaining = 99
	conditions.clear()
	_assert_eq(character.conditions.size(), 1, "character snapshot copies caller condition array")
	_assert_eq(character.conditions[0].remaining, 3, "character snapshot copies caller condition payload")


func _decode_root(root: Dictionary) -> GameSaveResult:
	return GameSaveJsonCodec.decode(JSON.stringify(root))


func _assert_true(value: bool, message: String) -> void:
	_assertion_count += 1
	if not value: _failures.append(message)


func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_assertion_count += 1
	if actual != expected: _failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
