class_name M5Data
extends RefCounted

const MAX_INT: int = 2147483647
const RELATION_FIELDS: Array[String] = ["trust", "affection", "fear", "resentment", "obligation"]
static var _keysets: Dictionary = {}


static func keys(name: String) -> Array:
	if _keysets.is_empty():
		_keysets = JSON.parse_string(FileAccess.get_file_as_string("res://src/simulation/social/m5_keysets.json"))
	return _keysets[name].duplicate()


static func exact(value: Variant, expected: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func rd(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	var magnitude: int = (2 * absi(numerator) + denominator) / (2 * denominator)
	return -magnitude if numerator < 0 else magnitude


static func td(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	var result: int = numerator / denominator
	return result


static func clone(world: WorldState) -> WorldState:
	var payload: Dictionary = StateHasher.state_payload(world)
	return WorldState.from_data(payload, payload.state)


static func identified(prefix: String, value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result["id"] = prefix + ":" + StateHasher.hash_data(value)
	return result


static func observation_id(owner: String, event: String) -> String:
	return "social_observation:" + StateHasher.hash_data({"algorithm_id": "m5-observation-id-v1", "owner_person_id": owner, "event_id": event})


static func receipt_id(owner: String, event: String) -> String:
	return "social_effect:" + StateHasher.hash_data({"algorithm_id": "m5-effect-receipt-id-v1", "owner_person_id": owner, "event_id": event})


static func relation(world: WorldState, owner: String, target: String) -> RelationState:
	for item: RelationState in world.relations:
		if item.from_person_id == owner and item.to_person_id == target:
			return item
	return null


static func score(person: PersonState, group: String, key: String, defaults: Array) -> int:
	var values: Dictionary = person.get(group)
	if not values.has(key):
		var path: String = "persons.%s.%s.%s" % [person.id, group, key]
		if not defaults.has(path):
			defaults.append(path)
	return int(values.get(key, 0))


static func relation_values(world: WorldState, owner: String, target: String, defaults: Array) -> Dictionary:
	var found: RelationState = relation(world, owner, target)
	var values: Dictionary = {}
	for field: String in RELATION_FIELDS:
		values[field] = int(found.get(field)) if found != null else 0
		if found == null:
			var path: String = "relations.%s->%s.%s" % [owner, target, field]
			if not defaults.has(path):
				defaults.append(path)
	return values


static func named_people(payload: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for key: String in ["actor_person_id", "requester_person_id", "responder_person_id"]:
		if payload.has(key) and not ids.has(str(payload[key])):
			ids.append(str(payload[key]))
	ids.sort()
	return ids


static func json_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return value >= -MAX_INT and value <= MAX_INT
		TYPE_ARRAY:
			for item: Variant in value:
				if not json_value(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not json_value(value[key]):
					return false
			return true
	return false
