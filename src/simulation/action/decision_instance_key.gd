class_name DecisionInstanceKey
extends RefCounted

const PHASE_ID: String = "DAY_ACTION_RESOLUTION"
const ATTEMPT_ORDINAL: int = 0

var day_index: int = 0
var phase_id: String = PHASE_ID
var actor_person_id: String = ""
var decision_key: String = "daily_food_strategy"
var attempt_ordinal: int = ATTEMPT_ORDINAL


static func create(actor_id: String, day: int) -> DecisionInstanceKey:
	var key: DecisionInstanceKey = DecisionInstanceKey.new()
	key.actor_person_id = actor_id
	key.day_index = day
	return key


static func from_data(data: Dictionary) -> DecisionInstanceKey:
	var key: DecisionInstanceKey = DecisionInstanceKey.new()
	key.day_index = int(data.get("day_index", 0))
	key.phase_id = str(data.get("phase_id", ""))
	key.actor_person_id = str(data.get("actor_person_id", ""))
	key.decision_key = str(data.get("decision_key", ""))
	key.attempt_ordinal = int(data.get("attempt_ordinal", -1))
	return key


func to_data() -> Dictionary:
	return {
		"day_index": day_index,
		"phase_id": phase_id,
		"actor_person_id": actor_person_id,
		"decision_key": decision_key,
		"attempt_ordinal": attempt_ordinal,
	}


func decision_slot_id() -> String:
	return StateHasher.hash_data({
		"algorithm_id": "m4-decision-slot-v1",
		"actor_person_id": actor_person_id,
		"day_index": day_index,
		"decision_key": decision_key,
		"phase_id": phase_id,
	})
