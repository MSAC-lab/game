class_name EventRecord
extends RefCounted

var id: String = ""
var day_index: int = 0
var event_type: String = ""
var actor_ids: Array[String] = []
var target_ids: Array[String] = []
var action_id: String = ""
var result_id: String = ""
var location_id: String = ""
var witness_ids: Array[String] = []
var is_public: bool = false


func to_data() -> Dictionary:
	return {
		"id": id,
		"day_index": day_index,
		"event_type": event_type,
		"actor_ids": actor_ids.duplicate(),
		"target_ids": target_ids.duplicate(),
		"action_id": action_id,
		"result_id": result_id,
		"location_id": location_id,
		"witness_ids": witness_ids.duplicate(),
		"is_public": is_public,
	}


static func from_data(data: Dictionary) -> EventRecord:
	var record: EventRecord = EventRecord.new()
	record.id = str(data.get("id", ""))
	record.day_index = int(data.get("day_index", 0))
	record.event_type = str(data.get("event_type", ""))
	record.actor_ids = ModelData.copy_string_array(data.get("actor_ids", []))
	record.target_ids = ModelData.copy_string_array(data.get("target_ids", []))
	record.action_id = str(data.get("action_id", ""))
	record.result_id = str(data.get("result_id", ""))
	record.location_id = str(data.get("location_id", ""))
	record.witness_ids = ModelData.copy_string_array(data.get("witness_ids", []))
	record.is_public = bool(data.get("is_public", false))
	return record
