class_name AttemptDiagnostic
extends RefCounted

var id: String = ""
var processing_status: String = "REJECTED_AS_MALFORMED"
var stage_id: String = ""
var action_instance_id: String = ""
var reason_id: String = ""


static func create(reason: String, stage: String, action_id: String) -> AttemptDiagnostic:
	var diagnostic: AttemptDiagnostic = AttemptDiagnostic.new()
	diagnostic.reason_id = reason
	diagnostic.stage_id = stage
	diagnostic.action_instance_id = action_id
	diagnostic.id = StateHasher.hash_data({
		"algorithm_id": "m4-attempt-diagnostic-v1",
		"action_instance_id": action_id,
		"reason_id": reason,
		"stage_id": stage,
	})
	return diagnostic


func to_data() -> Dictionary:
	return {
		"id": id,
		"processing_status": processing_status,
		"stage_id": stage_id,
		"action_instance_id": action_instance_id,
		"reason_id": reason_id,
	}
