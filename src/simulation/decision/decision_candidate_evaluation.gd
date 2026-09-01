class_name DecisionCandidateEvaluation
extends RefCounted

var candidate_id: String = ""
var action_id: String = ""
var target_kind: String = ""
var target_id: String = ""
var input_fact_ids: Array[String] = []
var defaulted_inputs: Array[String] = []
var need_component: int = 0
var goal_component: int = 0
var value_component: int = 0
var relation_component: int = 0
var expected_benefit_component: int = 0
var risk_component: int = 0
var norm_conflict_component: int = 0
var opportunity_cost_component: int = 0
var utility_scaled: int = 0


func to_data() -> Dictionary:
	return {
		"candidate_id": candidate_id,
		"action_id": action_id,
		"target_kind": target_kind,
		"target_id": target_id,
		"input_fact_ids": input_fact_ids.duplicate(),
		"defaulted_inputs": defaulted_inputs.duplicate(),
		"N": need_component,
		"G": goal_component,
		"V": value_component,
		"R": relation_component,
		"M": expected_benefit_component,
		"K": risk_component,
		"C": norm_conflict_component,
		"T": opportunity_cost_component,
		"utility_scaled": utility_scaled,
	}
