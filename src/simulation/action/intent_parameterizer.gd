class_name IntentParameterizer
extends RefCounted

const ALLOWED_DECISION_KEY: String = "daily_food_strategy"
const FOOD_HORIZON_DAYS: int = 10
const REQUEST_CAP_UNITS: int = 10
const THEFT_CAP_UNITS: int = 10
const THEFT_BELIEF_SCALE_UNITS: int = 10


static func parameterize(
	world: WorldState,
	decision_request: DecisionRequest,
	submitted_decision_result: DecisionResult
) -> ParameterizationResult:
	if decision_request == null or decision_request.decision_key != ALLOWED_DECISION_KEY:
		return ParameterizationResult.failure("unsupported_decision_key")
	if not _has_valid_provenance(world, decision_request, submitted_decision_result):
		return ParameterizationResult.failure("decision_provenance_mismatch")

	var selected: DecisionCandidateEvaluation = _selected_candidate(
		submitted_decision_result
	)
	var actor: PersonState = world.find_person(submitted_decision_result.actor_person_id)
	var household: HouseholdState = world.find_household(actor.household_id)
	var own_store: ResourceStoreState = world.find_resource_store(household.resource_store_id)
	var decision_key: DecisionInstanceKey = DecisionInstanceKey.create(actor.id, world.day_index)
	var intent: ActionIntent = ActionIntent.new()
	intent.decision_instance_key = decision_key
	intent.decision_slot_id = decision_key.decision_slot_id()
	intent.input_resolution_epoch = world.resolution_epoch
	intent.actor_person_id = actor.id
	intent.action_id = selected.action_id
	intent.source_decision_hash = DecisionArtifactCodec.hash_result(submitted_decision_result)
	intent.source_decision_input_state_hash = submitted_decision_result.input_state_hash
	intent.source_decision_ruleset_hash = submitted_decision_result.ruleset_hash
	intent.source_selected_candidate_id = selected.candidate_id
	intent.parameterization_ruleset_hash = M4ParameterizationRules.EXPECTED_HASH
	intent.action_instance_id = intent.compute_action_instance_id()

	var need_basis_units: int = calculate_need_basis(world, household, own_store)
	if selected.action_id in ["A04", "A11"] and need_basis_units == 0:
		return ParameterizationResult.failure(
			"selected_positive_action_has_zero_need_basis", intent.action_instance_id
		)

	if selected.action_id == "A04":
		var responder: PersonState = world.find_person(selected.target_id)
		if responder == null:
			return ParameterizationResult.failure(
				"decision_provenance_mismatch", intent.action_instance_id
			)
		var responder_household: HouseholdState = world.find_household(responder.household_id)
		if responder_household == null:
			return ParameterizationResult.failure(
				"decision_provenance_mismatch", intent.action_instance_id
			)
		if responder_household.resource_store_id == household.resource_store_id:
			return ParameterizationResult.failure(
				"request_source_equals_recipient", intent.action_instance_id
			)
		intent.target_person_id = selected.target_id
		intent.requested_resource_type_id = "food"
		intent.requested_units = mini(need_basis_units, REQUEST_CAP_UNITS)
		intent.recipient_store_id = household.resource_store_id
	elif selected.action_id == "A11":
		if selected.target_id == household.resource_store_id:
			return ParameterizationResult.failure(
				"theft_target_equals_recipient", intent.action_instance_id
			)
		var food_fact: InformationState = _find_food_stock_fact(
			world, actor.id, selected.target_id
		)
		if food_fact == null:
			return ParameterizationResult.failure(
				"decision_provenance_mismatch", intent.action_instance_id
			)
		var effective_food_stock_level: int = M4Math.round_div(
			food_fact.belief_value * food_fact.confidence, 100
		)
		var belief_cap_units: int = maxi(
			1,
			M4Math.ceil_div_nonnegative(
				effective_food_stock_level * THEFT_BELIEF_SCALE_UNITS, 100
			)
		)
		intent.parameterization_input_fact_ids = [food_fact.id]
		intent.target_store_id = selected.target_id
		intent.desired_units = mini(
			need_basis_units, mini(THEFT_CAP_UNITS, belief_cap_units)
		)
		intent.recipient_store_id = household.resource_store_id
	elif selected.action_id != "A00":
		return ParameterizationResult.failure("decision_provenance_mismatch")

	intent.parameterization_input_fact_ids.sort()
	intent.intent_hash = intent.compute_intent_hash()
	return ParameterizationResult.success(intent)


static func calculate_need_basis(
	world: WorldState, household: HouseholdState, own_store: ResourceStoreState
) -> int:
	var daily_need_units: Array[int] = []
	var hunger_scores: Array[int] = []
	for person_id: String in household.member_ids:
		var member: PersonState = world.find_person(person_id)
		if member == null or not member.alive:
			continue
		daily_need_units.append(member.daily_food_need_units)
		hunger_scores.append(int(member.need_scores.get("hunger", 0)))
	return calculate_need_basis_from_values(
		daily_need_units, hunger_scores, own_store.quantity
	)


static func calculate_need_basis_from_values(
	alive_member_daily_food_need_units: Array[int],
	alive_member_hunger_scores: Array[int],
	own_food_units: int
) -> int:
	var daily_need: int = 0
	for value: int in alive_member_daily_food_need_units:
		daily_need += value
	var maximum_hunger: int = 0
	for value: int in alive_member_hunger_scores:
		maximum_hunger = maxi(maximum_hunger, value)
	var household_need_10d: int = daily_need * FOOD_HORIZON_DAYS
	var food_shortfall: int = maxi(0, household_need_10d - own_food_units)
	var hunger_relief_floor: int = 1 if maximum_hunger > 0 else 0
	return maxi(food_shortfall, hunger_relief_floor)


static func _has_valid_provenance(
	world: WorldState, request: DecisionRequest, submitted: DecisionResult
) -> bool:
	if world == null or submitted == null:
		return false
	if not M4Rules.validate_world_manifest(world, ["parameterization", "decision"]).is_empty():
		return false
	if not submitted.ok:
		return false
	if submitted.actor_person_id != request.actor_person_id:
		return false
	if submitted.decision_key != request.decision_key:
		return false
	if submitted.day_index != world.day_index:
		return false
	if submitted.input_state_hash != StateHasher.hash_world(world):
		return false
	if submitted.ruleset_hash != M4Rules.DECISION_RULESET_HASH:
		return false
	var expected: DecisionResult = DecisionEngine.evaluate(world, request)
	if not expected.ok:
		return false
	if DecisionArtifactCodec.hash_result(expected) != DecisionArtifactCodec.hash_result(submitted):
		return false
	return _selected_candidate_count(submitted) == 1


static func _selected_candidate_count(result: DecisionResult) -> int:
	var count: int = 0
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		if candidate.candidate_id == result.selected_candidate_id:
			count += 1
	return count


static func _selected_candidate(result: DecisionResult) -> DecisionCandidateEvaluation:
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		if candidate.candidate_id == result.selected_candidate_id:
			return candidate
	return null


static func _find_food_stock_fact(
	world: WorldState, owner_person_id: String, target_store_id: String
) -> InformationState:
	for fact: InformationState in world.information:
		if (
			fact.owner_person_id == owner_person_id
			and fact.subject_kind == "resource_store"
			and fact.subject_id == target_store_id
			and fact.fact_type_id == "food_stock_level"
		):
			return fact
	return null
