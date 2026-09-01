class_name DecisionRecord
extends RefCounted

var id: String = ""
var actor_person_id: String = ""
var day_index: int = 0
var candidate_action_ids: Array[String] = []
var unavailable_reasons: Dictionary = {}
var evaluation_reasons: Array[String] = []
var selected_intent: String = ""
var selected_action_id: String = ""
var result_event_id: String = ""
var change_pressure: Dictionary = {}


func to_data() -> Dictionary:
	return {
		"id": id,
		"actor_person_id": actor_person_id,
		"day_index": day_index,
		"candidate_action_ids": candidate_action_ids.duplicate(),
		"unavailable_reasons": unavailable_reasons.duplicate(true),
		"evaluation_reasons": evaluation_reasons.duplicate(),
		"selected_intent": selected_intent,
		"selected_action_id": selected_action_id,
		"result_event_id": result_event_id,
		"change_pressure": change_pressure.duplicate(true),
	}


static func from_data(data: Dictionary) -> DecisionRecord:
	var record: DecisionRecord = DecisionRecord.new()
	record.id = str(data.get("id", ""))
	record.actor_person_id = str(data.get("actor_person_id", ""))
	record.day_index = int(data.get("day_index", 0))
	record.candidate_action_ids = ModelData.copy_string_array(data.get("candidate_action_ids", []))
	record.unavailable_reasons = ModelData.copy_string_string_dictionary(
		data.get("unavailable_reasons", {})
	)
	record.evaluation_reasons = ModelData.copy_string_array(data.get("evaluation_reasons", []))
	record.selected_intent = str(data.get("selected_intent", ""))
	record.selected_action_id = str(data.get("selected_action_id", ""))
	record.result_event_id = str(data.get("result_event_id", ""))
	record.change_pressure = ModelData.copy_string_int_dictionary(data.get("change_pressure", {}))
	return record
