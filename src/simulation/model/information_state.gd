class_name InformationState
extends RefCounted

var source_observation_id: String = ""
var id: String = ""
var claim: String = ""
var owner_person_id: String = ""
var linked_event_id: String = ""
var acquisition_type: String = ""
var original_source_person_id: String = ""
var current_source_person_id: String = ""
var confidence: int = 0
var is_secret: bool = false
var learned_day_index: int = 0
var fact_type_id: String = ""
var subject_kind: String = ""
var subject_id: String = ""
var belief_value: int = 0


func to_data(schema_version: int = WorldState.SCHEMA_VERSION_M1) -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"claim": claim,
		"owner_person_id": owner_person_id,
		"linked_event_id": linked_event_id,
		"acquisition_type": acquisition_type,
		"original_source_person_id": original_source_person_id,
		"current_source_person_id": current_source_person_id,
		"confidence": confidence,
		"is_secret": is_secret,
		"learned_day_index": learned_day_index,
	}
	if schema_version in [WorldState.SCHEMA_VERSION_M3, WorldState.SCHEMA_VERSION_M4, WorldState.SCHEMA_VERSION_M5]:
		data["fact_type_id"] = fact_type_id
		data["subject_kind"] = subject_kind
		data["subject_id"] = subject_id
		data["belief_value"] = belief_value
	if schema_version == WorldState.SCHEMA_VERSION_M5:
		data["source_observation_id"] = source_observation_id
	return data


static func from_data(
	data: Dictionary, schema_version: int = WorldState.SCHEMA_VERSION_M1
) -> InformationState:
	var state: InformationState = InformationState.new()
	state.id = str(data.get("id", ""))
	state.claim = str(data.get("claim", ""))
	state.owner_person_id = str(data.get("owner_person_id", ""))
	state.linked_event_id = str(data.get("linked_event_id", ""))
	state.acquisition_type = str(data.get("acquisition_type", ""))
	state.original_source_person_id = str(data.get("original_source_person_id", ""))
	state.current_source_person_id = str(data.get("current_source_person_id", ""))
	state.confidence = int(data.get("confidence", 0))
	state.is_secret = bool(data.get("is_secret", false))
	state.learned_day_index = int(data.get("learned_day_index", 0))
	if schema_version in [WorldState.SCHEMA_VERSION_M3, WorldState.SCHEMA_VERSION_M4, WorldState.SCHEMA_VERSION_M5]:
		state.fact_type_id = str(data.get("fact_type_id", ""))
		state.subject_kind = str(data.get("subject_kind", ""))
		state.subject_id = str(data.get("subject_id", ""))
		state.belief_value = int(data.get("belief_value", 0))
	if schema_version == WorldState.SCHEMA_VERSION_M5:
		state.source_observation_id = str(data.get("source_observation_id", ""))
	return state
