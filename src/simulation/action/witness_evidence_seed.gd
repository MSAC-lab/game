class_name WitnessEvidenceSeed
extends RefCounted

var id: String = ""
var action_instance_id: String = ""
var context_id: String = ""
var witness_person_id: String = ""
var actor_person_id: String = ""
var action_id: String = ""
var notice_score: int = 0
var notice_threshold: int = 0
var actual_units: int = 0
var trace_created: bool = false
var day_index: int = 0
var phase_id: String = ""


func to_data() -> Dictionary:
	return {
		"id": id,
		"action_instance_id": action_instance_id,
		"context_id": context_id,
		"witness_person_id": witness_person_id,
		"actor_person_id": actor_person_id,
		"action_id": action_id,
		"notice_score": notice_score,
		"notice_threshold": notice_threshold,
		"actual_units": actual_units,
		"trace_created": trace_created,
		"day_index": day_index,
		"phase_id": phase_id,
	}
