class_name M1StateModelTest
extends RefCounted

const FIXTURE_JSON_PATH: String = "res://tests/fixtures/m1_canonical.json"
const FIXTURE_HASH_PATH: String = "res://tests/fixtures/m1_canonical.sha256"

var _failures: Array[String] = []


func run_all() -> Array[String]:
	_test_t01_round_trip()
	_test_t02_collection_order_independence()
	_test_t03_meaningful_mutation_changes_hash()
	_test_t04_duplicate_id_rejected()
	_test_t05_broken_reference_rejected()
	_test_t06_unknown_schema_rejected()
	_test_t07_player_is_ordinary_person()
	_test_t08_models_are_engine_independent()
	_test_t09_rng_and_id_counters_restore_exactly()
	_test_t10_frozen_fixture()
	_test_action_definition_round_trip()
	_test_malformed_primitive_types_are_rejected()
	_test_audit_is_excluded_from_state_hash()
	return _failures


func fixture_artifacts() -> Dictionary:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var audit: Array[DecisionRecord] = fixture["audit"]
	return {
		"json": StateCodec.encode(world, audit),
		"hash": StateHasher.hash_world(world) + "\n",
	}


func _test_t01_round_trip() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var encoded: String = StateCodec.encode(fixture["world"], fixture["audit"])
	var decoded: Dictionary = StateCodec.decode(encoded)
	_expect(bool(decoded["ok"]), "M1-T01 decode succeeds: %s" % str(decoded["errors"]))
	if not bool(decoded["ok"]):
		return
	var reencoded: String = StateCodec.encode(decoded["world"], decoded["audit"])
	_expect(encoded == reencoded, "M1-T01 save/restore preserves state and audit exactly")


func _test_t02_collection_order_independence() -> void:
	var first: Dictionary = M1FixtureFactory.create()
	var second: Dictionary = M1FixtureFactory.create()
	var first_world: WorldState = first["world"]
	var second_world: WorldState = second["world"]
	second_world.persons.reverse()
	second_world.households.reverse()
	second_world.relations.reverse()
	second_world.events.reverse()
	second_world.information.reverse()
	second_world.memories.reverse()
	for person: PersonState in second_world.persons:
		person.role_ids.reverse()
		person.goal_ids.reverse()
		person.information_ids.reverse()
		person.memory_ids.reverse()
		person.relation_ids.reverse()
	for household: HouseholdState in second_world.households:
		household.member_ids.reverse()
	_expect(
		StateHasher.hash_world(first_world) == StateHasher.hash_world(second_world),
		"M1-T02 unordered collection order does not affect state hash"
	)


func _test_t03_meaningful_mutation_changes_hash() -> void:
	var first: Dictionary = M1FixtureFactory.create()
	var second: Dictionary = M1FixtureFactory.create()
	var first_world: WorldState = first["world"]
	var second_world: WorldState = second["world"]
	var before: String = StateHasher.hash_world(first_world)
	second_world.relations[0].trust += 1
	_expect(before != StateHasher.hash_world(second_world), "M1-T03 relation change affects state hash")


func _test_t04_duplicate_id_rejected() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var envelope: Dictionary = StateHasher.state_payload(world)
	var state: Dictionary = envelope["state"]
	var persons: Array = state["persons"]
	persons.append(persons[0].duplicate(true))
	var errors: Array[String] = StateValidator.validate_envelope(envelope)
	_expect(_contains(errors, "duplicate ID"), "M1-T04 duplicate ID is rejected")


func _test_t05_broken_reference_rejected() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var envelope: Dictionary = StateHasher.state_payload(world)
	var state: Dictionary = envelope["state"]
	var persons: Array = state["persons"]
	var person: Dictionary = persons[0]
	person["household_id"] = "household:999999"
	var errors: Array[String] = StateValidator.validate_envelope(envelope)
	_expect(_contains(errors, "references missing ID"), "M1-T05 broken reference is rejected")


func _test_t06_unknown_schema_rejected() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var envelope: Dictionary = StateHasher.state_payload(world)
	envelope["schema_version"] = 999
	var errors: Array[String] = StateValidator.validate_envelope(envelope)
	_expect(_contains(errors, "unsupported schema_version"), "M1-T06 unknown schema is rejected explicitly")


func _test_t07_player_is_ordinary_person() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	_expect(world.find_person(world.player_person_id) != null, "M1-T07 player ID selects a PersonState")
	_expect(
		not FileAccess.file_exists("res://src/simulation/model/player_state.gd"),
		"M1-T07 no separate PlayerState model exists"
	)


func _test_t08_models_are_engine_independent() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var models: Array[Variant] = [world]
	models.append_array(world.persons)
	models.append_array(world.households)
	models.append_array(world.relations)
	models.append_array(world.events)
	models.append_array(world.information)
	models.append_array(world.memories)
	models.append_array(fixture["audit"])
	models.append_array(fixture["actions"])
	var independent: bool = true
	for model: Variant in models:
		independent = independent and model is RefCounted and not model is Node
	_expect(independent, "M1-T08 simulation models are RefCounted and not Nodes")


func _test_t09_rng_and_id_counters_restore_exactly() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var decoded: Dictionary = StateCodec.decode(StateCodec.encode(world, fixture["audit"]))
	_expect(bool(decoded["ok"]), "M1-T09 fixture decodes")
	if not bool(decoded["ok"]):
		return
	var restored: WorldState = decoded["world"]
	_expect(restored.rng_seed_hex == world.rng_seed_hex, "M1-T09 RNG seed restores exactly")
	_expect(restored.rng_state_hex == world.rng_state_hex, "M1-T09 RNG state restores exactly")
	_expect(restored.next_ids == world.next_ids, "M1-T09 ID counters restore exactly")
	var expected_id: String = IdAllocator.next_id(world, "person")
	var restored_id: String = IdAllocator.next_id(restored, "person")
	_expect(expected_id == restored_id, "M1-T09 restored allocator emits the same next ID")


func _test_t10_frozen_fixture() -> void:
	if not FileAccess.file_exists(FIXTURE_JSON_PATH) or not FileAccess.file_exists(FIXTURE_HASH_PATH):
		_failures.append("M1-T10 frozen fixture files are missing")
		return
	var artifacts: Dictionary = fixture_artifacts()
	var expected_json: String = FileAccess.get_file_as_string(FIXTURE_JSON_PATH)
	var expected_hash: String = FileAccess.get_file_as_string(FIXTURE_HASH_PATH)
	_expect(artifacts["json"] == expected_json, "M1-T10 canonical JSON matches frozen fixture")
	_expect(artifacts["hash"] == expected_hash, "M1-T10 SHA-256 matches frozen fixture")


func _test_action_definition_round_trip() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var actions: Array[ActionDefinition] = fixture["actions"]
	var action: ActionDefinition = actions[0]
	var restored: ActionDefinition = ActionDefinition.from_data(action.to_data())
	_expect(
		StateCanonicalizer.canonical_json(action.to_data())
		== StateCanonicalizer.canonical_json(restored.to_data()),
		"ActionDefinition round-trip preserves static ruleset data"
	)


func _test_malformed_primitive_types_are_rejected() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var envelope: Dictionary = StateHasher.state_payload(world)
	var state: Dictionary = envelope["state"]
	var persons: Array = state["persons"]
	var person: Dictionary = persons[0]
	person["health"] = 12.5
	person["alive"] = "true"
	var errors: Array[String] = StateValidator.validate_envelope(envelope)
	_expect(_contains(errors, "health must be an integer"), "non-integral state number is rejected")
	_expect(_contains(errors, "alive must be a bool"), "non-bool state value is rejected")


func _test_audit_is_excluded_from_state_hash() -> void:
	var fixture: Dictionary = M1FixtureFactory.create()
	var world: WorldState = fixture["world"]
	var audit: Array[DecisionRecord] = fixture["audit"]
	var before: String = StateHasher.hash_world(world)
	audit[0].evaluation_reasons.append("audit-only explanation")
	var after: String = StateHasher.hash_world(world)
	_expect(before == after, "audit-only DecisionRecord does not affect future state hash")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _contains(messages: Array[String], needle: String) -> bool:
	for message: String in messages:
		if message.contains(needle):
			return true
	return false
