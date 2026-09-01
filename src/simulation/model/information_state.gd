class_name InformationState
extends RefCounted

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


func to_data() -> Dictionary:
	return {
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


static func from_data(data: Dictionary) -> InformationState:
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
	return state
