class_name DecisionResult
extends RefCounted

var ok: bool = false
var errors: Array[String] = []
var actor_person_id: String = ""
var decision_key: String = ""
var day_index: int = 0
var input_state_hash: String = ""
var ruleset_hash: String = ""
var candidate_evaluations: Array[DecisionCandidateEvaluation] = []
var excluded_candidates: Array[DecisionExclusion] = []
var selected_candidate_id: String = ""
var selection_mode: String = ""
var near_tie_candidate_ids: Array[String] = []
var random_digest_hex: String = ""
var random_draw: int = -1
var random_total_weight: int = 0


static func failure(
	request: DecisionRequest, failure_errors: Array[String]
) -> DecisionResult:
	var result: DecisionResult = DecisionResult.new()
	result.actor_person_id = request.actor_person_id
	result.decision_key = request.decision_key
	result.errors = failure_errors.duplicate()
	return result


func to_data() -> Dictionary:
	var evaluations: Array = []
	for candidate: DecisionCandidateEvaluation in candidate_evaluations:
		evaluations.append(candidate.to_data())
	var exclusions: Array = []
	for exclusion: DecisionExclusion in excluded_candidates:
		exclusions.append(exclusion.to_data())
	return {
		"ok": ok,
		"errors": errors.duplicate(),
		"actor_person_id": actor_person_id,
		"decision_key": decision_key,
		"day_index": day_index,
		"input_state_hash": input_state_hash,
		"ruleset_hash": ruleset_hash,
		"candidate_evaluations": evaluations,
		"excluded_candidates": exclusions,
		"selected_candidate_id": selected_candidate_id,
		"selection_mode": selection_mode,
		"near_tie_candidate_ids": near_tie_candidate_ids.duplicate(),
		"random_digest_hex": random_digest_hex,
		"random_draw": random_draw,
		"random_total_weight": random_total_weight,
	}
