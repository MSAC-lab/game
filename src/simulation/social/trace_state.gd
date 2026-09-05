class_name TraceState
extends RefCounted

var event_id: String = ""
var exists: bool = false
var id: String = ""
var occurred_day_index: int = 0
var source_action_instance_id: String = ""
var store_id: String = ""
var trace_type: String = ""


func to_data() -> Dictionary:
	return {
		"event_id": event_id,
		"exists": exists,
		"id": id,
		"occurred_day_index": occurred_day_index,
		"source_action_instance_id": source_action_instance_id,
		"store_id": store_id,
		"trace_type": trace_type,
	}


static func from_data(data: Dictionary) -> TraceState:
	var value: TraceState = TraceState.new()
	value.event_id = data["event_id"]
	value.exists = data["exists"]
	value.id = data["id"]
	value.occurred_day_index = data["occurred_day_index"]
	value.source_action_instance_id = data["source_action_instance_id"]
	value.store_id = data["store_id"]
	value.trace_type = data["trace_type"]
	return value
