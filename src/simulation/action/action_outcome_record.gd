class_name ActionOutcomeRecord
extends RefCounted

var id: String = ""
var action_instance_id: String = ""
var action_id: String = ""
var actor_person_id: String = ""
var intent_hash: String = ""
var context_id: String = ""
var source_decision_hash: String = ""
var processing_status: String = ""
var objective_outcome: String = ""
var invalidation_reason_ids: Array[String] = []
var resource_transaction_ids: Array[String] = []
var witness_evidence_seed_ids: Array[String] = []
var random_draws: Array[RandomDrawRecord] = []
var details: Dictionary = {}
var semantic_resolution_hash: String = ""


func to_data_without_semantic_resolution_hash() -> Dictionary:
	var draw_data: Array = []
	for draw: RandomDrawRecord in random_draws:
		draw_data.append(draw.to_data())
	return {
		"id": id,
		"action_instance_id": action_instance_id,
		"action_id": action_id,
		"actor_person_id": actor_person_id,
		"intent_hash": intent_hash,
		"context_id": context_id,
		"source_decision_hash": source_decision_hash,
		"processing_status": processing_status,
		"objective_outcome": objective_outcome,
		"invalidation_reason_ids": invalidation_reason_ids.duplicate(),
		"resource_transaction_ids": resource_transaction_ids.duplicate(),
		"witness_evidence_seed_ids": witness_evidence_seed_ids.duplicate(),
		"random_draws": draw_data,
		"details": details.duplicate(true),
	}


func to_data() -> Dictionary:
	var data: Dictionary = to_data_without_semantic_resolution_hash()
	data["semantic_resolution_hash"] = semantic_resolution_hash
	return data


func finalize_hash() -> void:
	semantic_resolution_hash = StateHasher.hash_data({
		"algorithm_id": "m4-semantic-resolution-v1",
		"action_outcome": to_data_without_semantic_resolution_hash(),
	})
