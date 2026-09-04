class_name M4FixtureFactory
extends RefCounted

const ANNEX_PATH: String = "res://tests/fixtures/m4_exact_artifacts.json"
const DECISION_KEY: String = "daily_food_strategy"


static func load_annex() -> Dictionary:
	var json: JSON = JSON.new()
	var error: Error = json.parse(FileAccess.get_file_as_string(ANNEX_PATH))
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Unable to parse M4 exact artifact annex")
		return {}
	return _normalize_json_numbers(json.data)


static func world_from_payload(payload: Dictionary) -> WorldState:
	return WorldState.from_data(payload, payload.get("state", {}))


static func clone_world(world: WorldState) -> WorldState:
	var payload: Dictionary = StateHasher.state_payload(world)
	return world_from_payload(payload)


static func request(actor_person_id: String, key: String = DECISION_KEY) -> DecisionRequest:
	return DecisionRequest.create(actor_person_id, key)


static func issuer_for_contexts(context_values: Array) -> TestResolutionContextIssuer:
	var issuer: TestResolutionContextIssuer = TestResolutionContextIssuer.new()
	for value: Variant in context_values:
		var context: Dictionary = value
		issuer.set_presence(
			str(context.get("action_instance_id", "")),
			ModelData.copy_string_array(context.get("present_person_ids", [])),
			ModelData.copy_string_array(context.get("present_store_ids", []))
		)
	return issuer


static func _normalize_json_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, floor(value)):
		return int(value)
	if typeof(value) == TYPE_ARRAY:
		var array: Array = []
		for item: Variant in value:
			array.append(_normalize_json_numbers(item))
		return array
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = {}
		for key: Variant in value.keys():
			dictionary[key] = _normalize_json_numbers(value[key])
		return dictionary
	return value
