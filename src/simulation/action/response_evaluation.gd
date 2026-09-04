class_name ResponseEvaluation
extends RefCounted

var responder_person_id: String = ""
var source_store_id: String = ""
var source_stock_units: int = 0
var reserve_need_units: int = 0
var surplus_units: int = 0
var care_score: int = 0
var relation_score: int = 0
var reserve_cost: int = 0
var grant_candidate_present: bool = false
var grant_candidate_decision: String = ""
var grant_authorized_units: int = 0
var grant_utility: int = 0
var reject_utility: int = 0
var tie_break_used: bool = false
var selected_decision: String = ""
var selected_authorized_units: int = 0
var defaulted_inputs: Array[String] = []


func to_data() -> Dictionary:
	return {
		"responder_person_id": responder_person_id,
		"source_store_id": source_store_id,
		"source_stock_units": source_stock_units,
		"reserve_need_units": reserve_need_units,
		"surplus_units": surplus_units,
		"care_score": care_score,
		"relation_score": relation_score,
		"reserve_cost": reserve_cost,
		"grant_candidate_present": grant_candidate_present,
		"grant_candidate_decision": grant_candidate_decision,
		"grant_authorized_units": grant_authorized_units,
		"grant_utility": grant_utility,
		"reject_utility": reject_utility,
		"tie_break_used": tie_break_used,
		"selected_decision": selected_decision,
		"selected_authorized_units": selected_authorized_units,
		"defaulted_inputs": defaulted_inputs.duplicate(),
	}
