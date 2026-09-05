class_name MemoryState
extends RefCounted

var source_observation_id: String = ""
var first_learned_day_index: int = 0
var core_eligible: bool = false
var id: String = ""
var owner_person_id: String = ""
var linked_event_id: String = ""
var linked_information_id: String = ""
var perceived_action_id: String = ""
var perceived_result_id: String = ""
var related_person_ids: Array[String] = []
var emotion_scores: Dictionary = {}
var importance: int = 0
var occurred_day_index: int = 0
var tier: String = "recent"


func to_data(schema_version: int = WorldState.SCHEMA_VERSION_M1) -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"owner_person_id": owner_person_id,
		"linked_event_id": linked_event_id,
		"linked_information_id": linked_information_id,
		"perceived_action_id": perceived_action_id,
		"perceived_result_id": perceived_result_id,
		"related_person_ids": related_person_ids.duplicate(),
		"emotion_scores": emotion_scores.duplicate(true),
		"importance": importance,
		"occurred_day_index": occurred_day_index,
		"tier": tier,
	}
	if schema_version == WorldState.SCHEMA_VERSION_M5:
		data["source_observation_id"] = source_observation_id
		data["first_learned_day_index"] = first_learned_day_index
		data["core_eligible"] = core_eligible
	return data


static func from_data(data: Dictionary, schema_version: int = WorldState.SCHEMA_VERSION_M1) -> MemoryState:
	var state: MemoryState = MemoryState.new()
	state.id = str(data.get("id", ""))
	state.owner_person_id = str(data.get("owner_person_id", ""))
	state.linked_event_id = str(data.get("linked_event_id", ""))
	state.linked_information_id = str(data.get("linked_information_id", ""))
	state.perceived_action_id = str(data.get("perceived_action_id", ""))
	state.perceived_result_id = str(data.get("perceived_result_id", ""))
	state.related_person_ids = ModelData.copy_string_array(data.get("related_person_ids", []))
	state.emotion_scores = ModelData.copy_string_int_dictionary(data.get("emotion_scores", {}))
	state.importance = int(data.get("importance", 0))
	state.occurred_day_index = int(data.get("occurred_day_index", 0))
	state.tier = str(data.get("tier", "recent"))
	if schema_version == WorldState.SCHEMA_VERSION_M5:
		state.source_observation_id = data["source_observation_id"]
		state.first_learned_day_index = data["first_learned_day_index"]
		state.core_eligible = data["core_eligible"]
	return state
