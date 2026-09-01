class_name M3DecisionRules
extends RefCounted

const RULESET_ID: String = "drought-prototype-rules-v3"
const DECISION_ALGORITHM_ID: String = "m3-near-tie-v1"
const NEAR_TIE_THRESHOLD: int = 500
const RANDOM_DIGEST_HEX_DIGITS: int = 15
const GOAL_SECURE_HOUSEHOLD_FOOD: String = "goal:secure_household_food"
const POSITIVE_ACTION_THRESHOLD: int = 0
const FOOD_PRESSURE_THRESHOLD: int = 0
const BENEFIT_COMPONENT_MIN: int = -100
const BENEFIT_COMPONENT_MAX: int = 100
const COST_COMPONENT_MIN: int = 0
const COST_COMPONENT_MAX: int = 100
const FULL_GOAL_COMPONENT: int = 100
const NO_NORM_CONFLICT: int = 0

const ACTION_WAIT: String = "A00"
const ACTION_REQUEST_FOOD: String = "A04"
const ACTION_THEFT: String = "A11"

const FACT_VILLAGE_AUTHORITY: String = "village_authority"
const FACT_REQUEST_FOOD_ACCESS: String = "request_food_access"
const FACT_REQUEST_FOOD_CAPACITY: String = "request_food_capacity"
const FACT_REQUEST_SUCCESS_EXPECTATION: String = "request_success_expectation"
const FACT_REQUEST_SOCIAL_RISK: String = "request_social_risk"
const FACT_FOOD_STOCK_LEVEL: String = "food_stock_level"
const FACT_THEFT_ACCESS: String = "theft_access"
const FACT_THEFT_OPPORTUNITY: String = "theft_opportunity"
const FACT_DETECTION_RISK: String = "detection_risk"
const FACT_SANCTION_SEVERITY: String = "sanction_severity"
const REQUEST_ACCESS_THRESHOLD: int = 50
const THEFT_STOCK_THRESHOLD: int = 1
const THEFT_ACCESS_THRESHOLD: int = 50
const THEFT_OPPORTUNITY_THRESHOLD: int = 50
const AUTHORITY_BELIEF_THRESHOLD: int = 50

const FOOD_HORIZON_DAYS: int = 10
const PERCENT_SCALE: int = 100
const FOOD_PRESSURE_SQUARE_SCALE: int = 10000
const CARE_PERCENT_PER_DEPENDENT: int = 10
const CARE_DEPENDENT_CAP: int = 4

const RELATION_PAIR_DIVISOR: int = 2
const TARGET_RELATION_DIVISOR: int = 3

const RISK_BASE_SCALE: int = 1000
const RISK_TAKING_COEFFICIENT: int = 6
const FEAR_COEFFICIENT: int = 5
const RISK_ADJUSTMENT_SCALE: int = 1000000

const THEFT_NORM_VIOLATION: int = 100
const THEFT_DUTY_VIOLATION: int = 100
const NORM_WEIGHT: int = 3
const NORM_ADHERENCE_COEFFICIENT: int = 3
const NORM_CONFLICT_SCALE: int = 2000
const DUTY_WEIGHT: int = 2
const DUTY_CONFLICT_SCALE: int = 500
const DUTY_ROLE_IDS: Array[String] = ["granary_staff", "village_guard"]

const WAIT_OPPORTUNITY_COST: int = 0
const REQUEST_OPPORTUNITY_COST: int = 25
const THEFT_OPPORTUNITY_COST: int = 50

const NEED_HUNGER_KEY: String = "hunger"
const TRAIT_RISK_TAKING_KEY: String = "risk_taking"
const TRAIT_NORM_ADHERENCE_KEY: String = "norm_adherence"
const EMOTION_FEAR_KEY: String = "fear"
const VALUE_LEGITIMATE_ORDER_KEY: String = "legitimate_order"

const UTILITY_WEIGHT_N: int = 30
const UTILITY_WEIGHT_G: int = 20
const UTILITY_WEIGHT_V: int = 20
const UTILITY_WEIGHT_R: int = 10
const UTILITY_WEIGHT_M: int = 10
const UTILITY_WEIGHT_K: int = -15
const UTILITY_WEIGHT_C: int = -15
const UTILITY_WEIGHT_T: int = -5

const REQUEST_FACT_TYPES: Array[String] = [
	FACT_REQUEST_FOOD_ACCESS,
	FACT_REQUEST_FOOD_CAPACITY,
	FACT_REQUEST_SUCCESS_EXPECTATION,
	FACT_REQUEST_SOCIAL_RISK,
]
const THEFT_FACT_TYPES: Array[String] = [
	FACT_FOOD_STOCK_LEVEL,
	FACT_THEFT_ACCESS,
	FACT_THEFT_OPPORTUNITY,
	FACT_DETECTION_RISK,
	FACT_SANCTION_SEVERITY,
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
		"authority": {
			"belief_threshold": AUTHORITY_BELIEF_THRESHOLD,
			"fact_type_id": FACT_VILLAGE_AUTHORITY,
		},
		"candidate_thresholds": {
			"food_pressure": FOOD_PRESSURE_THRESHOLD,
			"positive_action": POSITIVE_ACTION_THRESHOLD,
			"request_access": REQUEST_ACCESS_THRESHOLD,
			"theft_access": THEFT_ACCESS_THRESHOLD,
			"theft_opportunity": THEFT_OPPORTUNITY_THRESHOLD,
			"theft_stock": THEFT_STOCK_THRESHOLD,
		},
		"component_bounds": {
			"benefit_max": BENEFIT_COMPONENT_MAX,
			"benefit_min": BENEFIT_COMPONENT_MIN,
			"cost_max": COST_COMPONENT_MAX,
			"cost_min": COST_COMPONENT_MIN,
			"full_goal": FULL_GOAL_COMPONENT,
			"no_norm_conflict": NO_NORM_CONFLICT,
		},
		"food_pressure": {
			"care_dependent_cap": CARE_DEPENDENT_CAP,
			"care_percent_per_dependent": CARE_PERCENT_PER_DEPENDENT,
			"horizon_days": FOOD_HORIZON_DAYS,
			"percent_scale": PERCENT_SCALE,
			"square_scale": FOOD_PRESSURE_SQUARE_SCALE,
		},
		"goal_id": GOAL_SECURE_HOUSEHOLD_FOOD,
		"input_score_keys": {
			"emotion_fear": EMOTION_FEAR_KEY,
			"need_hunger": NEED_HUNGER_KEY,
			"trait_norm_adherence": TRAIT_NORM_ADHERENCE_KEY,
			"trait_risk_taking": TRAIT_RISK_TAKING_KEY,
			"value_legitimate_order": VALUE_LEGITIMATE_ORDER_KEY,
		},
		"near_tie_threshold": NEAR_TIE_THRESHOLD,
		"norm_conflict": {
			"duty_conflict_scale": DUTY_CONFLICT_SCALE,
			"duty_role_ids": DUTY_ROLE_IDS.duplicate(),
			"duty_violation": THEFT_DUTY_VIOLATION,
			"duty_weight": DUTY_WEIGHT,
			"norm_adherence_coefficient": NORM_ADHERENCE_COEFFICIENT,
			"norm_conflict_scale": NORM_CONFLICT_SCALE,
			"norm_violation": THEFT_NORM_VIOLATION,
			"norm_weight": NORM_WEIGHT,
		},
		"opportunity_cost": {
			ACTION_WAIT: WAIT_OPPORTUNITY_COST,
			ACTION_REQUEST_FOOD: REQUEST_OPPORTUNITY_COST,
			ACTION_THEFT: THEFT_OPPORTUNITY_COST,
		},
		"relation": {
			"authority_positive_fields": ["trust", "obligation"],
			"dependent_positive_fields": ["affection", "obligation"],
			"pair_divisor": RELATION_PAIR_DIVISOR,
			"percent_scale": PERCENT_SCALE,
			"target_negative_fields": ["fear", "resentment"],
			"target_positive_fields": ["trust", "affection", "obligation"],
			"target_divisor": TARGET_RELATION_DIVISOR,
		},
		"request_fact_types": REQUEST_FACT_TYPES.duplicate(),
		"request_value_profile": REQUEST_VALUE_PROFILE.duplicate(),
		"theft_fact_types": THEFT_FACT_TYPES.duplicate(),
		"theft_value_profile": THEFT_VALUE_PROFILE.duplicate(),
		"risk_adjustment": {
			"base_scale": RISK_BASE_SCALE,
			"fear_coefficient": FEAR_COEFFICIENT,
			"result_scale": RISK_ADJUSTMENT_SCALE,
			"risk_taking_coefficient": RISK_TAKING_COEFFICIENT,
		},
		"stateless_random": {
			"digest_hex_digits": RANDOM_DIGEST_HEX_DIGITS,
			"hash_algorithm": "SHA-256",
			"weight_formula": "near_tie_threshold_minus_top_gap",
		},
		"utility_weights": {
			"N": UTILITY_WEIGHT_N,
			"G": UTILITY_WEIGHT_G,
			"V": UTILITY_WEIGHT_V,
			"R": UTILITY_WEIGHT_R,
			"M": UTILITY_WEIGHT_M,
			"K": UTILITY_WEIGHT_K,
			"C": UTILITY_WEIGHT_C,
			"T": UTILITY_WEIGHT_T,
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
		UTILITY_WEIGHT_N * candidate.need_component
		+ UTILITY_WEIGHT_G * candidate.goal_component
		+ UTILITY_WEIGHT_V * candidate.value_component
		+ UTILITY_WEIGHT_R * candidate.relation_component
		+ UTILITY_WEIGHT_M * candidate.expected_benefit_component
		+ UTILITY_WEIGHT_K * candidate.risk_component
		+ UTILITY_WEIGHT_C * candidate.norm_conflict_component
		+ UTILITY_WEIGHT_T * candidate.opportunity_cost_component
	)
