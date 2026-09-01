class_name DecisionEngine
extends RefCounted


static func evaluate(world: WorldState, request: DecisionRequest) -> DecisionResult:
	var request_errors: Array[String] = _validate_request(world, request)
	if not request_errors.is_empty():
		return DecisionResult.failure(request, request_errors)
	var world_errors: Array[String] = StateValidator.validate_world(world)
	if not world_errors.is_empty():
		return DecisionResult.failure(request, world_errors)

	var result: DecisionResult = DecisionResult.new()
	result.ok = true
	result.actor_person_id = request.actor_person_id
	result.decision_key = request.decision_key
	result.day_index = world.day_index
	result.input_state_hash = StateHasher.hash_world(world)
	result.ruleset_hash = M3DecisionRules.ruleset_hash()

	var actor: PersonState = world.find_person(request.actor_person_id)
	var household: HouseholdState = world.find_household(actor.household_id)
	var facts: SubjectiveFactIndex = SubjectiveFactIndex.build(world, actor.id)
	var food_pressure: int = _food_pressure(world, household)
	result.candidate_evaluations.append(_wait_candidate())
	_evaluate_request_candidates(
		world, actor, household, facts, food_pressure, result
	)
	_evaluate_theft_candidates(
		world, actor, household, facts, food_pressure, result
	)
	result.candidate_evaluations.sort_custom(_candidate_id_less)
	result.excluded_candidates.sort_custom(_exclusion_id_less)
	_select(world, request, result)
	return result


static func _validate_request(world: WorldState, request: DecisionRequest) -> Array[String]:
	var errors: Array[String] = []
	if request.actor_person_id.is_empty():
		errors.append("actor_person_id must not be empty")
	elif world.find_person(request.actor_person_id) == null:
		errors.append("actor_person_id references missing person: %s" % request.actor_person_id)
	if request.decision_key.is_empty():
		errors.append("decision_key must not be empty")
	if world.schema_version != WorldState.SCHEMA_VERSION_M3:
		errors.append("M3 decision engine requires schema 3")
	if world.ruleset_id != M3DecisionRules.RULESET_ID:
		errors.append("M3 decision engine requires ruleset %s" % M3DecisionRules.RULESET_ID)
	if world.ruleset_hash != M3DecisionRules.ruleset_hash():
		errors.append("M3 decision engine ruleset_hash mismatch")
	return errors


static func _wait_candidate() -> DecisionCandidateEvaluation:
	var candidate: DecisionCandidateEvaluation = DecisionCandidateEvaluation.new()
	candidate.candidate_id = _candidate_id(M3DecisionRules.ACTION_WAIT, "", "")
	candidate.action_id = M3DecisionRules.ACTION_WAIT
	return candidate


static func _evaluate_request_candidates(
	world: WorldState,
	actor: PersonState,
	household: HouseholdState,
	facts: SubjectiveFactIndex,
	food_pressure: int,
	result: DecisionResult
) -> void:
	for target_id: String in facts.subject_ids("person"):
		var relevant: bool = false
		for fact_type_id: String in M3DecisionRules.REQUEST_FACT_TYPES:
			if facts.get_fact("person", target_id, fact_type_id) != null:
				relevant = true
				break
		if not relevant:
			continue
		var exclusion: DecisionExclusion = _base_exclusion(
			M3DecisionRules.ACTION_REQUEST_FOOD, "person", target_id
		)
		if target_id == actor.id:
			exclusion.reason_ids.append("target_is_actor")
		if food_pressure <= M3DecisionRules.FOOD_PRESSURE_THRESHOLD:
			exclusion.reason_ids.append("food_pressure_not_positive")
		if not actor.goal_ids.has(M3DecisionRules.GOAL_SECURE_HOUSEHOLD_FOOD):
			exclusion.reason_ids.append("required_goal_missing")
		var missing: Array[String] = facts.missing_fact_types(
			"person", target_id, M3DecisionRules.REQUEST_FACT_TYPES
		)
		for fact_type_id: String in missing:
			exclusion.reason_ids.append("missing_fact:%s" % fact_type_id)
		if missing.is_empty() and facts.effective_value(
			"person", target_id, M3DecisionRules.FACT_REQUEST_FOOD_ACCESS
		) < M3DecisionRules.REQUEST_ACCESS_THRESHOLD:
			exclusion.reason_ids.append("request_food_access_below_50")
		if not exclusion.reason_ids.is_empty():
			exclusion.reason_ids.sort()
			result.excluded_candidates.append(exclusion)
			continue
		result.candidate_evaluations.append(
			_evaluate_request(world, actor, household, facts, target_id, food_pressure)
		)


static func _evaluate_theft_candidates(
	world: WorldState,
	actor: PersonState,
	household: HouseholdState,
	facts: SubjectiveFactIndex,
	food_pressure: int,
	result: DecisionResult
) -> void:
	for store_id: String in facts.subject_ids("resource_store"):
		var exclusion: DecisionExclusion = _base_exclusion(
			M3DecisionRules.ACTION_THEFT, "resource_store", store_id
		)
		if store_id == household.resource_store_id:
			exclusion.reason_ids.append("target_is_actor_household_store")
		if food_pressure <= M3DecisionRules.FOOD_PRESSURE_THRESHOLD:
			exclusion.reason_ids.append("food_pressure_not_positive")
		if not actor.goal_ids.has(M3DecisionRules.GOAL_SECURE_HOUSEHOLD_FOOD):
			exclusion.reason_ids.append("required_goal_missing")
		var missing: Array[String] = facts.missing_fact_types(
			"resource_store", store_id, M3DecisionRules.THEFT_FACT_TYPES
		)
		for fact_type_id: String in missing:
			exclusion.reason_ids.append("missing_fact:%s" % fact_type_id)
		if missing.is_empty():
			if facts.effective_value(
				"resource_store", store_id, M3DecisionRules.FACT_FOOD_STOCK_LEVEL
			) < M3DecisionRules.THEFT_STOCK_THRESHOLD:
				exclusion.reason_ids.append("food_stock_level_below_1")
			if facts.effective_value(
				"resource_store", store_id, M3DecisionRules.FACT_THEFT_ACCESS
			) < M3DecisionRules.THEFT_ACCESS_THRESHOLD:
				exclusion.reason_ids.append("theft_access_below_50")
			if facts.effective_value(
				"resource_store", store_id, M3DecisionRules.FACT_THEFT_OPPORTUNITY
			) < M3DecisionRules.THEFT_OPPORTUNITY_THRESHOLD:
				exclusion.reason_ids.append("theft_opportunity_below_50")
		if not exclusion.reason_ids.is_empty():
			exclusion.reason_ids.sort()
			result.excluded_candidates.append(exclusion)
			continue
		result.candidate_evaluations.append(
			_evaluate_theft(world, actor, household, facts, store_id, food_pressure)
		)


static func _evaluate_request(
	world: WorldState,
	actor: PersonState,
	household: HouseholdState,
	facts: SubjectiveFactIndex,
	target_id: String,
	food_pressure: int
) -> DecisionCandidateEvaluation:
	var candidate: DecisionCandidateEvaluation = _base_candidate(
		M3DecisionRules.ACTION_REQUEST_FOOD, "person", target_id
	)
	candidate.input_fact_ids = facts.fact_ids(
		"person", target_id, M3DecisionRules.REQUEST_FACT_TYPES
	)
	candidate.need_component = food_pressure
	candidate.goal_component = M3DecisionRules.FULL_GOAL_COMPONENT
	candidate.value_component = _value_component(
		actor, M3DecisionRules.REQUEST_VALUE_PROFILE, candidate.defaulted_inputs
	)
	candidate.relation_component = M3DecisionRules.round_div(
		_dependent_bond(world, actor, household)
		+ _target_relation(world, actor.id, target_id),
		M3DecisionRules.RELATION_PAIR_DIVISOR
	)
	candidate.expected_benefit_component = mini(
		facts.effective_value(
			"person", target_id, M3DecisionRules.FACT_REQUEST_FOOD_CAPACITY
		),
		facts.effective_value(
			"person", target_id, M3DecisionRules.FACT_REQUEST_SUCCESS_EXPECTATION
		)
	)
	candidate.risk_component = _adjusted_risk(
		actor,
		facts.effective_value(
			"person", target_id, M3DecisionRules.FACT_REQUEST_SOCIAL_RISK
		),
		candidate.defaulted_inputs
	)
	candidate.norm_conflict_component = M3DecisionRules.NO_NORM_CONFLICT
	candidate.opportunity_cost_component = M3DecisionRules.REQUEST_OPPORTUNITY_COST
	candidate.utility_scaled = M3DecisionRules.utility_scaled(candidate)
	candidate.defaulted_inputs.sort()
	return candidate


static func _evaluate_theft(
	world: WorldState,
	actor: PersonState,
	household: HouseholdState,
	facts: SubjectiveFactIndex,
	store_id: String,
	food_pressure: int
) -> DecisionCandidateEvaluation:
	var candidate: DecisionCandidateEvaluation = _base_candidate(
		M3DecisionRules.ACTION_THEFT, "resource_store", store_id
	)
	candidate.input_fact_ids = facts.fact_ids(
		"resource_store", store_id, M3DecisionRules.THEFT_FACT_TYPES
	)
	candidate.need_component = food_pressure
	candidate.goal_component = M3DecisionRules.FULL_GOAL_COMPONENT
	candidate.value_component = _value_component(
		actor, M3DecisionRules.THEFT_VALUE_PROFILE, candidate.defaulted_inputs
	)
	var detection_risk: int = facts.effective_value(
		"resource_store", store_id, M3DecisionRules.FACT_DETECTION_RISK
	)
	var authority_data: Dictionary = _authority_bond(world, actor, facts)
	var authority_fact_ids: Array[String] = authority_data.get("fact_ids", [])
	for fact_id: String in authority_fact_ids:
		candidate.input_fact_ids.append(fact_id)
	candidate.input_fact_ids.sort()
	var exposure_loss: int = M3DecisionRules.round_div(
		int(authority_data.get("bond", 0)) * detection_risk,
		M3DecisionRules.PERCENT_SCALE
	)
	candidate.relation_component = clampi(
		_dependent_bond(world, actor, household) - exposure_loss,
		M3DecisionRules.BENEFIT_COMPONENT_MIN,
		M3DecisionRules.BENEFIT_COMPONENT_MAX
	)
	candidate.expected_benefit_component = mini(
		facts.effective_value(
			"resource_store", store_id, M3DecisionRules.FACT_FOOD_STOCK_LEVEL
		),
		mini(
			facts.effective_value(
				"resource_store", store_id, M3DecisionRules.FACT_THEFT_ACCESS
			),
			facts.effective_value(
				"resource_store", store_id, M3DecisionRules.FACT_THEFT_OPPORTUNITY
			)
		)
	)
	var base_risk: int = M3DecisionRules.round_div(
		detection_risk
		* facts.effective_value(
			"resource_store", store_id, M3DecisionRules.FACT_SANCTION_SEVERITY
		),
		M3DecisionRules.PERCENT_SCALE
	)
	candidate.risk_component = _adjusted_risk(
		actor, base_risk, candidate.defaulted_inputs
	)
	candidate.norm_conflict_component = _theft_norm_conflict(
		actor, candidate.defaulted_inputs
	)
	candidate.opportunity_cost_component = M3DecisionRules.THEFT_OPPORTUNITY_COST
	candidate.utility_scaled = M3DecisionRules.utility_scaled(candidate)
	candidate.defaulted_inputs.sort()
	return candidate


static func _food_pressure(world: WorldState, household: HouseholdState) -> int:
	var daily_need: int = 0
	var hunger_pressure: int = 0
	for person_id: String in household.member_ids:
		var member: PersonState = world.find_person(person_id)
		if member == null or not member.alive:
			continue
		daily_need += member.daily_food_need_units
		hunger_pressure = maxi(
			hunger_pressure, int(member.need_scores.get(M3DecisionRules.NEED_HUNGER_KEY, 0))
		)
	var ten_day_need: int = daily_need * M3DecisionRules.FOOD_HORIZON_DAYS
	var stock_pressure: int = 0
	if ten_day_need > 0:
		var own_store: ResourceStoreState = world.find_resource_store(household.resource_store_id)
		var own_food: int = own_store.quantity if own_store != null else 0
		stock_pressure = M3DecisionRules.round_div(
			maxi(0, ten_day_need - own_food) * M3DecisionRules.PERCENT_SCALE,
			ten_day_need
		)
	var base_pressure: int = maxi(stock_pressure, hunger_pressure)
	var care_multiplier: int = M3DecisionRules.PERCENT_SCALE + (
		M3DecisionRules.CARE_PERCENT_PER_DEPENDENT
		* mini(household.dependent_person_ids.size(), M3DecisionRules.CARE_DEPENDENT_CAP)
	)
	return clampi(
		M3DecisionRules.round_div(
			base_pressure * base_pressure * care_multiplier,
			M3DecisionRules.FOOD_PRESSURE_SQUARE_SCALE
		),
		M3DecisionRules.COST_COMPONENT_MIN,
		M3DecisionRules.COST_COMPONENT_MAX
	)


static func _value_component(
	actor: PersonState, profile: Array[int], defaults: Array[String]
) -> int:
	var numerator: int = 0
	var denominator: int = 0
	for index: int in M3DecisionRules.VALUE_KEYS.size():
		var key: String = M3DecisionRules.VALUE_KEYS[index]
		if not actor.value_scores.has(key):
			defaults.append("value_scores.%s=0" % key)
		var semantic: int = profile[index]
		numerator += int(actor.value_scores.get(key, 0)) * semantic
		denominator += absi(semantic)
	return M3DecisionRules.round_div(numerator, denominator)


static func _dependent_bond(
	world: WorldState, actor: PersonState, household: HouseholdState
) -> int:
	var strongest: int = 0
	for dependent_id: String in household.dependent_person_ids:
		var relation: RelationState = _find_outgoing_relation(world, actor.id, dependent_id)
		if relation != null:
			strongest = maxi(
				strongest,
				M3DecisionRules.round_div(
					_sum_relation_fields(
						relation, M3DecisionRules.DEPENDENT_RELATION_POSITIVE_FIELDS
					),
					M3DecisionRules.RELATION_PAIR_DIVISOR
				)
			)
	return strongest


static func _target_relation(world: WorldState, actor_id: String, target_id: String) -> int:
	var relation: RelationState = _find_outgoing_relation(world, actor_id, target_id)
	if relation == null:
		return 0
	return M3DecisionRules.round_div(
		_sum_relation_fields(relation, M3DecisionRules.TARGET_RELATION_POSITIVE_FIELDS)
		- _sum_relation_fields(
			relation, M3DecisionRules.TARGET_RELATION_NEGATIVE_FIELDS
		),
		M3DecisionRules.TARGET_RELATION_DIVISOR
	)


static func _authority_bond(
	world: WorldState, actor: PersonState, facts: SubjectiveFactIndex
) -> Dictionary:
	var strongest: int = 0
	var used_fact_ids: Array[String] = []
	for target_id: String in facts.subject_ids("person"):
		var fact: InformationState = facts.get_fact(
			"person", target_id, M3DecisionRules.FACT_VILLAGE_AUTHORITY
		)
		if fact == null or facts.effective_value(
			"person", target_id, M3DecisionRules.FACT_VILLAGE_AUTHORITY
		) < M3DecisionRules.AUTHORITY_BELIEF_THRESHOLD:
			continue
		used_fact_ids.append(fact.id)
		var relation: RelationState = _find_outgoing_relation(world, actor.id, target_id)
		if relation != null:
			strongest = maxi(
				strongest,
				M3DecisionRules.round_div(
					_sum_relation_fields(
						relation, M3DecisionRules.AUTHORITY_RELATION_POSITIVE_FIELDS
					),
					M3DecisionRules.RELATION_PAIR_DIVISOR
				)
			)
	used_fact_ids.sort()
	return {"bond": strongest, "fact_ids": used_fact_ids}


static func _sum_relation_fields(
	relation: RelationState, field_names: Array[String]
) -> int:
	var total: int = 0
	for field_name: String in field_names:
		total += int(relation.get(field_name))
	return total


static func _adjusted_risk(
	actor: PersonState, base_risk: int, defaults: Array[String]
) -> int:
	if not actor.trait_scores.has(M3DecisionRules.TRAIT_RISK_TAKING_KEY):
		defaults.append("trait_scores.%s=0" % M3DecisionRules.TRAIT_RISK_TAKING_KEY)
	if not actor.emotion_scores.has(M3DecisionRules.EMOTION_FEAR_KEY):
		defaults.append("emotion_scores.%s=0" % M3DecisionRules.EMOTION_FEAR_KEY)
	var risk_taking: int = int(actor.trait_scores.get(M3DecisionRules.TRAIT_RISK_TAKING_KEY, 0))
	var fear: int = int(actor.emotion_scores.get(M3DecisionRules.EMOTION_FEAR_KEY, 0))
	return clampi(
		M3DecisionRules.round_div(
			base_risk
			* (M3DecisionRules.RISK_BASE_SCALE - M3DecisionRules.RISK_TAKING_COEFFICIENT * risk_taking)
			* (M3DecisionRules.RISK_BASE_SCALE + M3DecisionRules.FEAR_COEFFICIENT * fear),
			M3DecisionRules.RISK_ADJUSTMENT_SCALE
		),
		M3DecisionRules.COST_COMPONENT_MIN,
		M3DecisionRules.COST_COMPONENT_MAX
	)


static func _theft_norm_conflict(actor: PersonState, defaults: Array[String]) -> int:
	if not actor.trait_scores.has(M3DecisionRules.TRAIT_NORM_ADHERENCE_KEY):
		defaults.append("trait_scores.%s=0" % M3DecisionRules.TRAIT_NORM_ADHERENCE_KEY)
	if not actor.value_scores.has(M3DecisionRules.VALUE_LEGITIMATE_ORDER_KEY):
		defaults.append("value_scores.%s=0" % M3DecisionRules.VALUE_LEGITIMATE_ORDER_KEY)
	var norm_adherence: int = int(
		actor.trait_scores.get(M3DecisionRules.TRAIT_NORM_ADHERENCE_KEY, 0)
	)
	var legitimate_order: int = int(
		actor.value_scores.get(M3DecisionRules.VALUE_LEGITIMATE_ORDER_KEY, 0)
	)
	var norm_term: int = M3DecisionRules.round_div(
		M3DecisionRules.THEFT_NORM_VIOLATION
		* M3DecisionRules.NORM_WEIGHT
		* (M3DecisionRules.PERCENT_SCALE + M3DecisionRules.NORM_ADHERENCE_COEFFICIENT * norm_adherence),
		M3DecisionRules.NORM_CONFLICT_SCALE
	)
	var duty_violation: int = 0
	for role_id: String in M3DecisionRules.DUTY_ROLE_IDS:
		if actor.role_ids.has(role_id):
			duty_violation = M3DecisionRules.THEFT_DUTY_VIOLATION
			break
	var duty_term: int = M3DecisionRules.round_div(
		duty_violation * M3DecisionRules.DUTY_WEIGHT * legitimate_order,
		M3DecisionRules.DUTY_CONFLICT_SCALE
	)
	return clampi(
		norm_term + duty_term,
		M3DecisionRules.COST_COMPONENT_MIN,
		M3DecisionRules.COST_COMPONENT_MAX
	)


static func _find_outgoing_relation(
	world: WorldState, actor_id: String, target_id: String
) -> RelationState:
	var relation_id: String = IdAllocator.relation_id(actor_id, target_id)
	for relation: RelationState in world.relations:
		if relation.id == relation_id:
			return relation
	return null


static func _base_candidate(
	action_id: String, target_kind: String, target_id: String
) -> DecisionCandidateEvaluation:
	var candidate: DecisionCandidateEvaluation = DecisionCandidateEvaluation.new()
	candidate.candidate_id = _candidate_id(action_id, target_kind, target_id)
	candidate.action_id = action_id
	candidate.target_kind = target_kind
	candidate.target_id = target_id
	return candidate


static func _base_exclusion(
	action_id: String, target_kind: String, target_id: String
) -> DecisionExclusion:
	var exclusion: DecisionExclusion = DecisionExclusion.new()
	exclusion.candidate_id = _candidate_id(action_id, target_kind, target_id)
	exclusion.action_id = action_id
	exclusion.target_kind = target_kind
	exclusion.target_id = target_id
	return exclusion


static func _candidate_id(action_id: String, target_kind: String, target_id: String) -> String:
	return "%s|%s|%s" % [action_id, target_kind, target_id]


static func _select(
	world: WorldState, request: DecisionRequest, result: DecisionResult
) -> void:
	var ranked: Array[DecisionCandidateEvaluation] = result.candidate_evaluations.duplicate()
	ranked.sort_custom(_ranked_less)
	var has_positive_action: bool = false
	for candidate: DecisionCandidateEvaluation in ranked:
		if _is_positive_action_eligible(candidate):
			has_positive_action = true
			break
	if not has_positive_action:
		result.selected_candidate_id = _candidate_id(M3DecisionRules.ACTION_WAIT, "", "")
		result.selection_mode = "fallback_wait"
		return
	var top: DecisionCandidateEvaluation = ranked[0]
	var runner: DecisionCandidateEvaluation = ranked[1]
	if top.utility_scaled - runner.utility_scaled >= M3DecisionRules.NEAR_TIE_THRESHOLD:
		result.selected_candidate_id = top.candidate_id
		result.selection_mode = "deterministic_margin"
		return
	var near_tie: Array[DecisionCandidateEvaluation] = []
	for candidate: DecisionCandidateEvaluation in ranked:
		if top.utility_scaled - candidate.utility_scaled >= M3DecisionRules.NEAR_TIE_THRESHOLD:
			continue
		if (
			candidate.action_id != M3DecisionRules.ACTION_WAIT
			and not _is_positive_action_eligible(candidate)
		):
			continue
		near_tie.append(candidate)
		result.near_tie_candidate_ids.append(candidate.candidate_id)
	result.near_tie_candidate_ids.sort()
	var random_result: Dictionary = StatelessNearTie.select(world, request, near_tie)
	result.selected_candidate_id = str(random_result.get("selected_candidate_id", ""))
	result.selection_mode = "stateless_near_tie"
	result.random_digest_hex = str(random_result.get("random_digest_hex", ""))
	result.random_draw = int(random_result.get("random_draw", -1))
	result.random_total_weight = int(random_result.get("random_total_weight", 0))


static func _is_positive_action_eligible(candidate: DecisionCandidateEvaluation) -> bool:
	return (
		candidate.action_id != M3DecisionRules.ACTION_WAIT
		and candidate.utility_scaled > M3DecisionRules.POSITIVE_ACTION_THRESHOLD
	)


static func _candidate_id_less(
	left: DecisionCandidateEvaluation, right: DecisionCandidateEvaluation
) -> bool:
	return left.candidate_id < right.candidate_id


static func _exclusion_id_less(left: DecisionExclusion, right: DecisionExclusion) -> bool:
	return left.candidate_id < right.candidate_id


static func _ranked_less(
	left: DecisionCandidateEvaluation, right: DecisionCandidateEvaluation
) -> bool:
	if left.utility_scaled != right.utility_scaled:
		return left.utility_scaled > right.utility_scaled
	return left.candidate_id < right.candidate_id
