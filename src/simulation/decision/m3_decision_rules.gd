class_name M3DecisionRules
extends RefCounted

const RULESET_ID: String = "drought-prototype-rules-v3"
const DECISION_ALGORITHM_ID: String = "m3-near-tie-v1"
const NEAR_TIE_THRESHOLD: int = 500
const GOAL_SECURE_HOUSEHOLD_FOOD: String = "goal:secure_household_food"

const ACTION_WAIT: String = "A00"
const ACTION_REQUEST_FOOD: String = "A04"
const ACTION_THEFT: String = "A11"

const REQUEST_FACT_TYPES: Array[String] = [
	"request_food_access",
	"request_food_capacity",
	"request_success_expectation",
	"request_social_risk",
]
const THEFT_FACT_TYPES: Array[String] = [
	"food_stock_level",
	"theft_access",
	"theft_opportunity",
	"detection_risk",
	"sanction_severity",
]
const VALUE_KEYS: Array[String] = [
	"family_protection",
	"community_survival",
	"legitimate_order",
	"fairness_reciprocity",
	"property_autonomy",
	"life_protection",
]
const REQUEST_VALUE_PROFILE: Array[int] = [100, 0, 100, 100, 0, 100]
const THEFT_VALUE_PROFILE: Array[int] = [100, -100, -100, -100, -100, 100]


static func to_data() -> Dictionary:
	return {
		"actions": [ACTION_WAIT, ACTION_REQUEST_FOOD, ACTION_THEFT],
		"algorithm_id": DECISION_ALGORITHM_ID,
		"near_tie_threshold": NEAR_TIE_THRESHOLD,
		"request_fact_types": REQUEST_FACT_TYPES.duplicate(),
		"request_value_profile": REQUEST_VALUE_PROFILE.duplicate(),
		"theft_fact_types": THEFT_FACT_TYPES.duplicate(),
		"theft_value_profile": THEFT_VALUE_PROFILE.duplicate(),
		"utility_weights": {
			"N": 30,
			"G": 20,
			"V": 20,
			"R": 10,
			"M": 10,
			"K": -15,
			"C": -15,
			"T": -5,
		},
		"value_keys": VALUE_KEYS.duplicate(),
	}


static func ruleset_hash() -> String:
	return StateHasher.hash_data({"m3_decision_rules": to_data()})


static func round_div(numerator: int, denominator: int) -> int:
	assert(denominator > 0)
	if numerator == 0:
		return 0
	var sign_value: int = 1 if numerator > 0 else -1
	return sign_value * ((2 * absi(numerator) + denominator) / (2 * denominator))


static func utility_scaled(candidate: DecisionCandidateEvaluation) -> int:
	return (
		30 * candidate.need_component
		+ 20 * candidate.goal_component
		+ 20 * candidate.value_component
		+ 10 * candidate.relation_component
		+ 10 * candidate.expected_benefit_component
		- 15 * candidate.risk_component
		- 15 * candidate.norm_conflict_component
		- 5 * candidate.opportunity_cost_component
	)
