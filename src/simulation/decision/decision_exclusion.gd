class_name DecisionExclusion
extends RefCounted

var candidate_id: String = ""
var action_id: String = ""
var target_kind: String = ""
var target_id: String = ""
var reason_ids: Array[String] = []


func to_data() -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"action_id": action_id,
		"target_kind": target_kind,
		"target_id": target_id,
		"reason_ids": reason_ids.duplicate(),
	}
