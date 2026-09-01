class_name StatelessNearTie
extends RefCounted


static func select(
	world: WorldState,
	request: DecisionRequest,
	candidates: Array[DecisionCandidateEvaluation]
) -> Dictionary:
	assert(not candidates.is_empty())
	var payload_candidates: Array = []
	var total_weight: int = 0
	var top_utility: int = candidates[0].utility_scaled
	for candidate: DecisionCandidateEvaluation in candidates:
		top_utility = maxi(top_utility, candidate.utility_scaled)
	var by_id: Array[DecisionCandidateEvaluation] = candidates.duplicate()
	by_id.sort_custom(_candidate_id_less)
	var weights: Dictionary = {}
	for candidate: DecisionCandidateEvaluation in by_id:
		var weight: int = M3DecisionRules.NEAR_TIE_THRESHOLD - (
			top_utility - candidate.utility_scaled
		)
		assert(weight > 0)
		weights[candidate.candidate_id] = weight
		total_weight += weight
		payload_candidates.append({
			"candidate_id": candidate.candidate_id,
			"utility_scaled": candidate.utility_scaled,
			"weight": weight,
		})
	var payload: Dictionary = {
		"algorithm": M3DecisionRules.DECISION_ALGORITHM_ID,
		"rng_seed_hex": world.rng_seed_hex,
		"day_index": world.day_index,
		"actor_person_id": request.actor_person_id,
		"decision_key": request.decision_key,
		"candidates": payload_candidates,
	}
	var digest: String = StateHasher.hash_data(payload)
	var source_value: int = digest.substr(
		0, M3DecisionRules.RANDOM_DIGEST_HEX_DIGITS
	).hex_to_int()
	var draw: int = source_value % total_weight
	var cursor: int = 0
	var selected_id: String = ""
	for candidate: DecisionCandidateEvaluation in by_id:
		var weight: int = int(weights[candidate.candidate_id])
		cursor += weight
		if draw < cursor:
			selected_id = candidate.candidate_id
			break
	return {
		"selected_candidate_id": selected_id,
		"random_digest_hex": digest,
		"random_draw": draw,
		"random_total_weight": total_weight,
	}


static func _candidate_id_less(
	left: DecisionCandidateEvaluation, right: DecisionCandidateEvaluation
) -> bool:
	return left.candidate_id < right.candidate_id
