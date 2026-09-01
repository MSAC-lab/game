class_name StateValidator
extends RefCounted

const HEX_64_PATTERN: String = "^[0-9a-fA-F]{16}$"
const HASH_PATTERN: String = "^[0-9a-fA-F]{64}$"


static func validate_envelope(envelope: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema_version: int = 0
	if not _is_integer(envelope.get("schema_version")):
		errors.append("schema_version must be an integer")
	else:
		schema_version = int(envelope.get("schema_version"))
		if schema_version not in [WorldState.SCHEMA_VERSION_M1, WorldState.SCHEMA_VERSION_M2]:
			errors.append("unsupported schema_version: %s" % str(schema_version))
	_require_nonempty_string(envelope, "ruleset_id", "envelope", errors)
	_require_pattern(envelope, "ruleset_hash", HASH_PATTERN, "envelope", errors)
	if typeof(envelope.get("state")) != TYPE_DICTIONARY:
		errors.append("state must be a dictionary")
		return errors
	if schema_version in [WorldState.SCHEMA_VERSION_M1, WorldState.SCHEMA_VERSION_M2]:
		_validate_state(envelope.get("state"), schema_version, errors)
	return errors


static func validate_world(world: WorldState) -> Array[String]:
	return validate_envelope(StateHasher.state_payload(world))


static func _validate_state(
	state: Dictionary, schema_version: int, errors: Array[String]
) -> void:
	_require_nonempty_string(state, "scenario_id", "state", errors)
	_require_nonempty_string(state, "season_id", "state", errors)
	_require_pattern(state, "rng_seed_hex", HEX_64_PATTERN, "state", errors)
	_require_pattern(state, "rng_state_hex", HEX_64_PATTERN, "state", errors)
	_require_integer(state, "day_index", 0, 2147483647, "state", errors)
	if schema_version == WorldState.SCHEMA_VERSION_M1:
		_forbid_key(state, "day_phase", "schema 1 state", errors)
		_forbid_key(state, "resource_stores", "schema 1 state", errors)
	else:
		_require_exact_string(state, "day_phase", WorldState.DAY_END_PHASE, "state", errors)
	if typeof(state.get("next_ids")) != TYPE_DICTIONARY:
		errors.append("state.next_ids must be a dictionary")
	else:
		var next_ids: Dictionary = state.get("next_ids")
		for key: Variant in next_ids.keys():
			if not _is_integer(next_ids[key]) or int(next_ids[key]) < 1:
				errors.append("state.next_ids.%s must be a positive integer" % str(key))

	var persons: Dictionary = _index_collection(state, "persons", errors)
	var households: Dictionary = _index_collection(state, "households", errors)
	var relations: Dictionary = _index_collection(state, "relations", errors)
	var events: Dictionary = _index_collection(state, "events", errors)
	var information: Dictionary = _index_collection(state, "information", errors)
	var memories: Dictionary = _index_collection(state, "memories", errors)
	var resource_stores: Dictionary = {}
	if schema_version == WorldState.SCHEMA_VERSION_M2:
		resource_stores = _index_collection(state, "resource_stores", errors)

	var player_id: String = str(state.get("player_person_id", ""))
	if not persons.has(player_id):
		errors.append("state.player_person_id references missing person: %s" % player_id)

	_validate_resource_stores(resource_stores, households, schema_version, errors)
	_validate_households(households, persons, resource_stores, schema_version, errors)
	_validate_relations(relations, persons, errors)
	_validate_events(events, persons, errors)
	_validate_information(information, persons, events, errors)
	_validate_memories(memories, persons, events, information, errors)
	_validate_persons(
		persons, households, relations, information, memories, schema_version, errors
	)


static func _index_collection(
	state: Dictionary, key: String, errors: Array[String]
) -> Dictionary:
	var result: Dictionary = {}
	var value: Variant = state.get(key)
	if typeof(value) != TYPE_ARRAY:
		errors.append("state.%s must be an array" % key)
		return result
	var collection: Array = value
	for index: int in collection.size():
		var item: Variant = collection[index]
		if typeof(item) != TYPE_DICTIONARY:
			errors.append("state.%s[%d] must be a dictionary" % [key, index])
			continue
		var item_data: Dictionary = item
		var id: String = str(item_data.get("id", ""))
		if id.is_empty():
			errors.append("state.%s[%d].id must not be empty" % [key, index])
		elif result.has(id):
			errors.append("duplicate ID in state.%s: %s" % [key, id])
		else:
			result[id] = item_data
	return result


static func _validate_persons(
	persons: Dictionary,
	households: Dictionary,
	relations: Dictionary,
	information: Dictionary,
	memories: Dictionary,
	schema_version: int,
	errors: Array[String]
) -> void:
	for person_id: Variant in persons.keys():
		var person: Dictionary = persons[person_id]
		_require_string(person, "display_name", "person %s" % person_id, errors)
		_require_string(person, "occupation_id", "person %s" % person_id, errors)
		_require_bool(person, "alive", "person %s" % person_id, errors)
		_require_string_array(person, "role_ids", "person %s" % person_id, errors)
		_require_string_array(person, "goal_ids", "person %s" % person_id, errors)
		_require_reference(person, "household_id", households, "person %s" % person_id, errors)
		var minimum_health: int = 0 if schema_version == WorldState.SCHEMA_VERSION_M1 else 1
		_require_integer(person, "health", minimum_health, 100, "person %s" % person_id, errors)
		_validate_score_dictionary(person, "trait_scores", "person %s" % person_id, errors)
		_validate_score_dictionary(person, "value_scores", "person %s" % person_id, errors)
		_validate_score_dictionary(person, "emotion_scores", "person %s" % person_id, errors)
		_validate_score_dictionary(person, "need_scores", "person %s" % person_id, errors)
		if schema_version == WorldState.SCHEMA_VERSION_M1:
			_forbid_key(person, "daily_food_need_units", "schema 1 person %s" % person_id, errors)
			_forbid_key(person, "severe_hunger_days", "schema 1 person %s" % person_id, errors)
		else:
			_require_integer(
				person, "daily_food_need_units", 0, 10, "person %s" % person_id, errors
			)
			_require_integer(
				person, "severe_hunger_days", 0, 365, "person %s" % person_id, errors
			)
			var need_scores: Variant = person.get("need_scores")
			if typeof(need_scores) != TYPE_DICTIONARY or not need_scores.has("hunger"):
				errors.append("person %s.need_scores.hunger is required by schema 2" % person_id)
		_validate_reference_array(person, "relation_ids", relations, "person %s" % person_id, errors)
		_validate_reference_array(person, "information_ids", information, "person %s" % person_id, errors)
		_validate_reference_array(person, "memory_ids", memories, "person %s" % person_id, errors)


static func _validate_households(
	households: Dictionary,
	persons: Dictionary,
	resource_stores: Dictionary,
	schema_version: int,
	errors: Array[String]
) -> void:
	for household_id: Variant in households.keys():
		var household: Dictionary = households[household_id]
		_require_string(household, "livelihood_id", "household %s" % household_id, errors)
		_require_string(household, "residence_id", "household %s" % household_id, errors)
		_validate_reference_array(
			household, "member_ids", persons, "household %s" % household_id, errors
		)
		for key: String in ["wealth_units", "dependency_load"]:
			_require_integer(household, key, 0, 2147483647, "household %s" % household_id, errors)
		if schema_version == WorldState.SCHEMA_VERSION_M1:
			for key: String in ["food_units", "daily_food_need_units"]:
				_require_integer(
					household, key, 0, 2147483647, "household %s" % household_id, errors
				)
			_forbid_key(
				household, "resource_store_id", "schema 1 household %s" % household_id, errors
			)
		else:
			_forbid_key(household, "food_units", "schema 2 household %s" % household_id, errors)
			_forbid_key(
				household, "daily_food_need_units", "schema 2 household %s" % household_id, errors
			)
			_require_reference(
				household,
				"resource_store_id",
				resource_stores,
				"household %s" % household_id,
				errors
			)
			var store_id: String = str(household.get("resource_store_id", ""))
			if resource_stores.has(store_id):
				var store: Dictionary = resource_stores[store_id]
				if str(store.get("owner_kind", "")) != "household" or str(
					store.get("owner_id", "")
				) != str(household_id):
					errors.append(
					"household %s.resource_store_id must reference its own household store"
					% household_id
				)


static func _validate_resource_stores(
	stores: Dictionary,
	households: Dictionary,
	schema_version: int,
	errors: Array[String]
) -> void:
	if schema_version != WorldState.SCHEMA_VERSION_M2:
		return
	for store_id: Variant in stores.keys():
		var store: Dictionary = stores[store_id]
		_require_string(store, "owner_kind", "store %s" % store_id, errors)
		_require_string(store, "owner_id", "store %s" % store_id, errors)
		_require_exact_string(store, "resource_type_id", "food", "store %s" % store_id, errors)
		_require_integer(store, "quantity", 0, 2147483647, "store %s" % store_id, errors)
		var owner_kind: String = str(store.get("owner_kind", ""))
		var owner_id: String = str(store.get("owner_id", ""))
		if owner_kind == "household":
			if not households.has(owner_id):
				errors.append("store %s.owner_id references missing household: %s" % [store_id, owner_id])
			if str(store_id) != "resource_store:%s" % owner_id:
				errors.append("household store has non-canonical ID: %s" % store_id)
		elif owner_kind == "village":
			if owner_id != "village:main":
				errors.append("store %s village owner_id must be village:main" % store_id)
			if str(store_id) != "resource_store:village_granary":
				errors.append("village store has non-canonical ID: %s" % store_id)
		else:
			errors.append("store %s.owner_kind must be village or household" % store_id)


static func _validate_relations(
	relations: Dictionary, persons: Dictionary, errors: Array[String]
) -> void:
	for relation_id: Variant in relations.keys():
		var relation: Dictionary = relations[relation_id]
		_require_reference(relation, "from_person_id", persons, "relation %s" % relation_id, errors)
		_require_reference(relation, "to_person_id", persons, "relation %s" % relation_id, errors)
		var expected_id: String = IdAllocator.relation_id(
			str(relation.get("from_person_id", "")), str(relation.get("to_person_id", ""))
		)
		if str(relation_id) != expected_id:
			errors.append("relation ID is not directional canonical ID: %s" % relation_id)
		for key: String in ["trust", "affection", "fear", "resentment", "obligation"]:
			_require_integer(relation, key, 0, 100, "relation %s" % relation_id, errors)


static func _validate_events(events: Dictionary, persons: Dictionary, errors: Array[String]) -> void:
	for event_id: Variant in events.keys():
		var event: Dictionary = events[event_id]
		for key: String in ["event_type", "action_id", "result_id", "location_id"]:
			_require_string(event, key, "event %s" % event_id, errors)
		_require_bool(event, "is_public", "event %s" % event_id, errors)
		_require_integer(event, "day_index", 0, 2147483647, "event %s" % event_id, errors)
		_validate_reference_array(event, "actor_ids", persons, "event %s" % event_id, errors)
		_validate_reference_array(event, "target_ids", persons, "event %s" % event_id, errors)
		_validate_reference_array(event, "witness_ids", persons, "event %s" % event_id, errors)


static func _validate_information(
	information: Dictionary, persons: Dictionary, events: Dictionary, errors: Array[String]
) -> void:
	for info_id: Variant in information.keys():
		var info: Dictionary = information[info_id]
		for key: String in ["claim", "acquisition_type"]:
			_require_string(info, key, "information %s" % info_id, errors)
		_require_bool(info, "is_secret", "information %s" % info_id, errors)
		_require_reference(info, "owner_person_id", persons, "information %s" % info_id, errors)
		_require_reference(info, "linked_event_id", events, "information %s" % info_id, errors)
		for key: String in ["original_source_person_id", "current_source_person_id"]:
			_require_optional_reference(info, key, persons, "information %s" % info_id, errors)
		_require_integer(info, "confidence", 0, 100, "information %s" % info_id, errors)
		_require_integer(
			info, "learned_day_index", 0, 2147483647, "information %s" % info_id, errors
		)


static func _validate_memories(
	memories: Dictionary,
	persons: Dictionary,
	events: Dictionary,
	information: Dictionary,
	errors: Array[String]
) -> void:
	for memory_id: Variant in memories.keys():
		var memory: Dictionary = memories[memory_id]
		for key: String in ["perceived_action_id", "perceived_result_id", "tier"]:
			_require_string(memory, key, "memory %s" % memory_id, errors)
		_require_reference(memory, "owner_person_id", persons, "memory %s" % memory_id, errors)
		_require_reference(memory, "linked_event_id", events, "memory %s" % memory_id, errors)
		_require_reference(
			memory, "linked_information_id", information, "memory %s" % memory_id, errors
		)
		_validate_reference_array(
			memory, "related_person_ids", persons, "memory %s" % memory_id, errors
		)
		_validate_score_dictionary(memory, "emotion_scores", "memory %s" % memory_id, errors)
		_require_integer(memory, "importance", 0, 100, "memory %s" % memory_id, errors)
		_require_integer(
			memory, "occurred_day_index", 0, 2147483647, "memory %s" % memory_id, errors
		)


static func _validate_reference_array(
	data: Dictionary,
	key: String,
	targets: Dictionary,
	context: String,
	errors: Array[String]
) -> void:
	var value: Variant = data.get(key)
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s.%s must be an array" % [context, key])
		return
	var references: Array = value
	for reference: Variant in references:
		if typeof(reference) != TYPE_STRING:
			errors.append("%s.%s contains a non-string ID" % [context, key])
		elif not targets.has(str(reference)):
			errors.append("%s.%s references missing ID: %s" % [context, key, str(reference)])


static func _require_reference(
	data: Dictionary,
	key: String,
	targets: Dictionary,
	context: String,
	errors: Array[String]
) -> void:
	if typeof(data.get(key)) != TYPE_STRING:
		errors.append("%s.%s must be a string ID" % [context, key])
		return
	var reference: String = str(data.get(key, ""))
	if not targets.has(reference):
		errors.append("%s.%s references missing ID: %s" % [context, key, reference])


static func _require_optional_reference(
	data: Dictionary,
	key: String,
	targets: Dictionary,
	context: String,
	errors: Array[String]
) -> void:
	if typeof(data.get(key)) != TYPE_STRING:
		errors.append("%s.%s must be a string ID" % [context, key])
		return
	var reference: String = str(data.get(key, ""))
	if not reference.is_empty() and not targets.has(reference):
		errors.append("%s.%s references missing ID: %s" % [context, key, reference])


static func _validate_score_dictionary(
	data: Dictionary, key: String, context: String, errors: Array[String]
) -> void:
	var value: Variant = data.get(key)
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("%s.%s must be a dictionary" % [context, key])
		return
	var scores: Dictionary = value
	for score_key: Variant in scores.keys():
		if not _is_integer(scores[score_key]) or int(scores[score_key]) < 0 or int(scores[score_key]) > 100:
			errors.append("%s.%s.%s must be an integer from 0 to 100" % [context, key, score_key])


static func _require_nonempty_string(
	data: Dictionary, key: String, context: String, errors: Array[String]
) -> void:
	if typeof(data.get(key)) != TYPE_STRING or str(data.get(key)).is_empty():
		errors.append("%s.%s must be a non-empty string" % [context, key])


static func _require_string(
	data: Dictionary, key: String, context: String, errors: Array[String]
) -> void:
	if typeof(data.get(key)) != TYPE_STRING:
		errors.append("%s.%s must be a string" % [context, key])


static func _require_exact_string(
	data: Dictionary,
	key: String,
	expected: String,
	context: String,
	errors: Array[String]
) -> void:
	if typeof(data.get(key)) != TYPE_STRING or str(data.get(key)) != expected:
		errors.append("%s.%s must be %s" % [context, key, expected])


static func _forbid_key(
	data: Dictionary, key: String, context: String, errors: Array[String]
) -> void:
	if data.has(key):
		errors.append("%s forbids field %s" % [context, key])


static func _require_bool(
	data: Dictionary, key: String, context: String, errors: Array[String]
) -> void:
	if typeof(data.get(key)) != TYPE_BOOL:
		errors.append("%s.%s must be a bool" % [context, key])


static func _require_string_array(
	data: Dictionary, key: String, context: String, errors: Array[String]
) -> void:
	var value: Variant = data.get(key)
	if typeof(value) != TYPE_ARRAY:
		errors.append("%s.%s must be an array" % [context, key])
		return
	var values: Array = value
	for item: Variant in values:
		if typeof(item) != TYPE_STRING:
			errors.append("%s.%s contains a non-string value" % [context, key])
			return


static func _require_pattern(
	data: Dictionary, key: String, pattern: String, context: String, errors: Array[String]
) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile(pattern)
	var value: String = str(data.get(key, ""))
	if regex.search(value) == null:
		errors.append("%s.%s has invalid format" % [context, key])


static func _require_integer(
	data: Dictionary,
	key: String,
	minimum: int,
	maximum: int,
	context: String,
	errors: Array[String]
) -> void:
	var value: Variant = data.get(key)
	if not _is_integer(value) or int(value) < minimum or int(value) > maximum:
		errors.append("%s.%s must be an integer from %d to %d" % [context, key, minimum, maximum])


static func _is_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(value, floor(value))
