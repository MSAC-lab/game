class_name SocialObservationState
extends RefCounted

var accepted: bool = false
var acquisition_type: String = ""
var confidence: int = 0
var conflicted: bool = false
var current_source_person_id: String = ""
var depth: int = 0
var event_id: String = ""
var first_accepted_day_index: int = -1
var first_learned_day_index: int = 0
var id: String = ""
var importance: int = 0
var is_secret: bool = false
var occurred_day_index: int = 0
var origin_view: String = ""
var original_source_person_id: String = ""
var owner_person_id: String = ""
var payload: Dictionary = {}


func to_data() -> Dictionary:
	return {
		"accepted": accepted,
		"acquisition_type": acquisition_type,
		"confidence": confidence,
		"conflicted": conflicted,
		"current_source_person_id": current_source_person_id,
		"depth": depth,
		"event_id": event_id,
		"first_accepted_day_index": first_accepted_day_index,
		"first_learned_day_index": first_learned_day_index,
		"id": id,
		"importance": importance,
		"is_secret": is_secret,
		"occurred_day_index": occurred_day_index,
		"origin_view": origin_view,
		"original_source_person_id": original_source_person_id,
		"owner_person_id": owner_person_id,
		"payload": payload.duplicate(true),
	}


static func from_data(data: Dictionary) -> SocialObservationState:
	var value: SocialObservationState = SocialObservationState.new()
	value.accepted = data["accepted"]
	value.acquisition_type = data["acquisition_type"]
	value.confidence = data["confidence"]
	value.conflicted = data["conflicted"]
	value.current_source_person_id = data["current_source_person_id"]
	value.depth = data["depth"]
	value.event_id = data["event_id"]
	value.first_accepted_day_index = data["first_accepted_day_index"]
	value.first_learned_day_index = data["first_learned_day_index"]
	value.id = data["id"]
	value.importance = data["importance"]
	value.is_secret = data["is_secret"]
	value.occurred_day_index = data["occurred_day_index"]
	value.origin_view = data["origin_view"]
	value.original_source_person_id = data["original_source_person_id"]
	value.owner_person_id = data["owner_person_id"]
	value.payload = data["payload"].duplicate(true)
	return value
