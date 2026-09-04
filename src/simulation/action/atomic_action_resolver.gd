class_name AtomicActionResolver
extends RefCounted

const MAX_STORED_INT: int = 2147483647
const SUPPORTED_ACTION_IDS: Array[String] = ["A00", "A04", "A11"]


static func resolve_trusted_v1(
	world_value: Variant,
	batch_request_value: Variant,
	trusted_context_issuer: ResolutionContextIssuer
) -> BatchResolutionRecord:
	if not world_value is WorldState:
		return BatchResolutionRecord.rejected(null, "invalid_world")
	var world: WorldState = world_value
	var candidates: Array[Dictionary] = _world_rejection_candidates(world)
	if not batch_request_value is ResolutionBatchRequest:
		candidates.append(_candidate("field_contract_violation"))
		return reject_candidate(world, select_rejection_candidate(candidates))
	var batch_request: ResolutionBatchRequest = batch_request_value
	if batch_request.intents.is_empty():
		candidates.append(_candidate("field_contract_violation"))

	var intents: Array[ActionIntent] = batch_request.intents.duplicate()
	var contexts: Array[ResolutionContext] = batch_request.execution_contexts.duplicate()
	intents.sort_custom(_intent_less)
	contexts.sort_custom(_context_less)
	candidates.append_array(_intent_rejection_candidates(world, intents))
	candidates.append_array(
		_context_rejection_candidates(world, contexts, trusted_context_issuer)
	)
	candidates.append_array(_binding_rejection_candidates(intents, contexts))
	if not candidates.is_empty():
		return reject_candidate(world, select_rejection_candidate(candidates))

	var preliminary_result: Dictionary = _build_preliminary(world, intents, contexts)
	if not bool(preliminary_result.get("ok", false)):
		return BatchResolutionRecord.rejected(
			world,
			str(preliminary_result.get("reason_id", "component_ruleset_mismatch")),
			str(preliminary_result.get("action_instance_id", ""))
		)
	var preliminary: Dictionary = preliminary_result.get("preliminary", {})
	var claims: Array[Dictionary] = preliminary_result.get("claims", [])
	var actual_units: Dictionary = _resolve_conflicts(world, claims)
	var preflight: Dictionary = _sequence_preflight(world, intents, preliminary, actual_units)
	if not bool(preflight.get("ok", false)):
		return BatchResolutionRecord.rejected(
			world,
			str(preflight.get("reason_id", "arithmetic_overflow")),
			str(preflight.get("action_instance_id", ""))
		)
	return _commit(world, intents, contexts, preliminary, actual_units)


static func select_rejection_candidate(candidates: Array) -> Dictionary:
	var precedence: Dictionary = M4ResolutionRules.validation_precedence()
	var selected: Dictionary = {}
	var selected_rank: int = MAX_STORED_INT
	var selected_action_id: String = ""
	for candidate_value: Variant in candidates:
		var candidate: Dictionary = candidate_value
		var reason_id: String = str(candidate.get("reason_id", "invalid_world"))
		var action_id: String = str(candidate.get("action_instance_id", ""))
		var rank: int = int(precedence.get(reason_id, MAX_STORED_INT))
		if (
			selected.is_empty()
			or rank < selected_rank
			or (rank == selected_rank and action_id < selected_action_id)
		):
			selected = {
				"reason_id": reason_id,
				"action_instance_id": action_id,
			}
			selected_rank = rank
			selected_action_id = action_id
	return selected


static func reject_candidate(world: WorldState, selected: Dictionary) -> BatchResolutionRecord:
	return BatchResolutionRecord.rejected(
		world,
		str(selected.get("reason_id", "invalid_world")),
		str(selected.get("action_instance_id", ""))
	)


static func world_rejection_candidates(world: WorldState) -> Array[Dictionary]:
	return _world_rejection_candidates(world)


static func _world_rejection_candidates(world: WorldState) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if world.schema_version != WorldState.SCHEMA_VERSION_M4:
		candidates.append(_candidate("invalid_world"))
		return candidates
	for error: String in StateValidator.validate_world(world):
		if "exact keyset" in error:
			candidates.append(_candidate("field_contract_violation"))
		elif "simulation_ruleset_hash mismatch" in error:
			candidates.append(_candidate("simulation_ruleset_hash_mismatch"))
		else:
			candidates.append(_candidate("invalid_world"))
	for error: String in M4Rules.validate_world_manifest(world, ["resolution", "resource"]):
		if "simulation" in error:
			candidates.append(_candidate("simulation_ruleset_hash_mismatch"))
		else:
			candidates.append(_candidate("component_ruleset_mismatch"))
	return candidates


static func _intent_rejection_candidates(
	world: WorldState, intents: Array[ActionIntent]
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var state_hash: String = StateHasher.hash_world(world)
	var slot_ids: Dictionary = {}
	var action_ids: Dictionary = {}
	for intent: ActionIntent in intents:
		var action_instance_id: String = intent.action_instance_id if intent != null else ""
		if not _valid_intent_contract(intent):
			candidates.append(_candidate("field_contract_violation", action_instance_id))
			continue
		var key: DecisionInstanceKey = intent.decision_instance_key
		if key.decision_key != "daily_food_strategy":
			candidates.append(_candidate("unsupported_decision_key", action_instance_id))
		if world.resolved_decision_slot_ids.has(intent.decision_slot_id):
			candidates.append(_candidate("decision_slot_already_resolved", action_instance_id))
		if slot_ids.has(intent.decision_slot_id):
			candidates.append(_candidate("duplicate_decision_slot_id", action_instance_id))
		else:
			slot_ids[intent.decision_slot_id] = action_instance_id
		if intent.source_decision_input_state_hash != state_hash:
			candidates.append(_candidate("stale_input_state_hash", action_instance_id))
		if not _valid_intent_provenance(world, intent):
			candidates.append(_candidate("decision_provenance_mismatch", action_instance_id))
		if intent.action_id in ["A04", "A11"]:
			var actor: PersonState = world.find_person(intent.actor_person_id)
			if actor != null:
				var household: HouseholdState = world.find_household(actor.household_id)
				var own_store: ResourceStoreState = (
					world.find_resource_store(household.resource_store_id)
					if household != null
					else null
				)
				if (
					household != null
					and own_store != null
					and IntentParameterizer.calculate_need_basis(world, household, own_store) == 0
				):
					candidates.append(
						_candidate(
							"selected_positive_action_has_zero_need_basis",
							action_instance_id
						)
					)
		if intent.action_id == "A04":
			var target: PersonState = world.find_person(intent.target_person_id)
			if target != null:
				var target_household: HouseholdState = world.find_household(target.household_id)
				if (
					target_household != null
					and target_household.resource_store_id == intent.recipient_store_id
				):
					candidates.append(
						_candidate("request_source_equals_recipient", action_instance_id)
					)
		elif intent.action_id == "A11" and intent.target_store_id == intent.recipient_store_id:
			candidates.append(_candidate("theft_target_equals_recipient", action_instance_id))
		if action_ids.has(action_instance_id):
			candidates.append(_candidate("duplicate_action_instance_id", action_instance_id))
		else:
			action_ids[action_instance_id] = true
		if intent.intent_hash != intent.compute_intent_hash():
			candidates.append(_candidate("intent_hash_mismatch", action_instance_id))
		if intent.action_instance_id != intent.compute_action_instance_id():
			candidates.append(_candidate("action_instance_id_mismatch", action_instance_id))
		if not SUPPORTED_ACTION_IDS.has(intent.action_id):
			candidates.append(_candidate("unsupported_action_id", action_instance_id))
		if intent.input_resolution_epoch != world.resolution_epoch:
			candidates.append(_candidate("stale_resolution_epoch", action_instance_id))
	return candidates


static func _context_rejection_candidates(
	world: WorldState,
	contexts: Array[ResolutionContext],
	trusted_context_issuer: ResolutionContextIssuer
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var context_actions: Dictionary = {}
	var state_hash: String = StateHasher.hash_world(world)
	for context: ResolutionContext in contexts:
		var action_id: String = context.action_instance_id if context != null else ""
		if not _valid_context_contract(context):
			candidates.append(_candidate("field_contract_violation", action_id))
			continue
		if context.resolution_epoch != world.resolution_epoch:
			candidates.append(_candidate("stale_resolution_epoch", action_id))
		if context.input_state_hash != state_hash:
			candidates.append(_candidate("stale_input_state_hash", action_id))
		if context.day_index != world.day_index:
			candidates.append(_candidate("stale_day_index", action_id))
		if context.phase_id != DecisionInstanceKey.PHASE_ID:
			candidates.append(_candidate("invalid_phase", action_id))
		if context_actions.has(action_id):
			candidates.append(_candidate("duplicate_context", action_id))
		else:
			context_actions[action_id] = true
		if context.context_id != context.compute_context_id():
			candidates.append(_candidate("context_id_mismatch", action_id))
		if (
			trusted_context_issuer == null
			or not trusted_context_issuer.owns_context(context)
		):
			candidates.append(_candidate("untrusted_context_issuer", action_id))
		if not _is_sorted_unique(context.present_person_ids):
			candidates.append(
				_candidate("context_person_ids_not_sorted_unique", action_id)
			)
		if not _is_sorted_unique(context.present_store_ids):
			candidates.append(
				_candidate("context_store_ids_not_sorted_unique", action_id)
			)
		for person_id: String in context.present_person_ids:
			if world.find_person(person_id) == null:
				candidates.append(_candidate("context_missing_person_id", action_id))
		for store_id: String in context.present_store_ids:
			if world.find_resource_store(store_id) == null:
				candidates.append(_candidate("context_missing_store_id", action_id))
	return candidates


static func _binding_rejection_candidates(
	intents: Array[ActionIntent], contexts: Array[ResolutionContext]
) -> Array[Dictionary]:
	var intent_ids: Array[String] = []
	for intent: ActionIntent in intents:
		if intent != null:
			intent_ids.append(intent.action_instance_id)
	var context_ids: Array[String] = []
	for context: ResolutionContext in contexts:
		if context != null:
			context_ids.append(context.action_instance_id)
	intent_ids.sort()
	context_ids.sort()
	if intent_ids != context_ids:
		return [_candidate("action_context_set_mismatch")]
	return [] as Array[Dictionary]


static func _valid_intent_contract(intent: ActionIntent) -> bool:
	if intent == null or intent.decision_instance_key == null:
		return false
	if intent.action_id in SUPPORTED_ACTION_IDS:
		var expected_keys: Array[String] = [
			"action_instance_id",
			"decision_instance_key",
			"decision_slot_id",
			"input_resolution_epoch",
			"actor_person_id",
			"action_id",
			"source_decision_hash",
			"source_decision_input_state_hash",
			"source_decision_ruleset_hash",
			"source_selected_candidate_id",
			"parameterization_ruleset_hash",
			"parameterization_input_fact_ids",
			"intent_hash",
		]
		if intent.action_id == "A04":
			expected_keys.append_array([
				"target_person_id",
				"requested_resource_type_id",
				"requested_units",
				"recipient_store_id",
			])
		elif intent.action_id == "A11":
			expected_keys.append_array([
				"target_store_id",
				"desired_units",
				"recipient_store_id",
			])
		if not _has_exact_keys(intent.to_data(), expected_keys):
			return false
	if not _is_lower_hash(intent.action_instance_id):
		return false
	if not _is_lower_hash(intent.decision_slot_id):
		return false
	if not _is_lower_hash(intent.source_decision_hash):
		return false
	if not _is_lower_hash(intent.source_decision_input_state_hash):
		return false
	if not _is_lower_hash(intent.source_decision_ruleset_hash):
		return false
	if not _is_lower_hash(intent.parameterization_ruleset_hash):
		return false
	if not _is_lower_hash(intent.intent_hash):
		return false
	if intent.input_resolution_epoch < 0 or intent.input_resolution_epoch > MAX_STORED_INT:
		return false
	if intent.action_id == "A04":
		return (
			not intent.target_person_id.is_empty()
			and intent.requested_resource_type_id == "food"
			and intent.requested_units > 0
			and intent.requested_units <= 10
			and not intent.recipient_store_id.is_empty()
		)
	if intent.action_id == "A11":
		return (
			not intent.target_store_id.is_empty()
			and intent.desired_units > 0
			and intent.desired_units <= 10
			and not intent.recipient_store_id.is_empty()
		)
	return true


static func _valid_intent_provenance(world: WorldState, intent: ActionIntent) -> bool:
	var key: DecisionInstanceKey = intent.decision_instance_key
	if key.actor_person_id != intent.actor_person_id:
		return false
	if key.day_index != world.day_index:
		return false
	if key.phase_id != DecisionInstanceKey.PHASE_ID:
		return false
	if key.attempt_ordinal != DecisionInstanceKey.ATTEMPT_ORDINAL:
		return false
	if key.decision_key != "daily_food_strategy":
		return false
	if key.decision_slot_id() != intent.decision_slot_id:
		return false
	if intent.source_decision_ruleset_hash != M4Rules.DECISION_RULESET_HASH:
		return false
	if intent.parameterization_ruleset_hash != M4ParameterizationRules.EXPECTED_HASH:
		return false
	var expected_candidate_id: String = "A00||"
	if intent.action_id == "A04":
		expected_candidate_id = "A04|person|%s" % intent.target_person_id
	elif intent.action_id == "A11":
		expected_candidate_id = "A11|resource_store|%s" % intent.target_store_id
	return intent.source_selected_candidate_id == expected_candidate_id


static func _valid_context_contract(context: ResolutionContext) -> bool:
	if context == null:
		return false
	return (
		_is_lower_hash(context.context_id)
		and _is_lower_hash(context.action_instance_id)
		and _is_lower_hash(context.input_state_hash)
		and not context.issuer_id.is_empty()
		and context.resolution_epoch >= 0
		and context.resolution_epoch <= MAX_STORED_INT
		and context.day_index >= 0
		and context.day_index <= MAX_STORED_INT
		and _has_exact_keys(context.to_data(), [
			"context_id",
			"issuer_id",
			"action_instance_id",
			"input_state_hash",
			"resolution_epoch",
			"day_index",
			"phase_id",
			"present_person_ids",
			"present_store_ids",
		])
	)


static func _candidate(reason_id: String, action_instance_id: String = "") -> Dictionary:
	return {
		"reason_id": reason_id,
		"action_instance_id": action_instance_id,
	}


static func _is_lower_hash(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	var regex: RegEx = RegEx.new()
	regex.compile("^[0-9a-f]{64}$")
	return regex.search(value) != null


static func _has_exact_keys(data: Dictionary, expected_keys: Array[String]) -> bool:
	if data.size() != expected_keys.size():
		return false
	for key: String in expected_keys:
		if not data.has(key):
			return false
	return true


static func _is_sorted_unique(values: Array[String]) -> bool:
	for index: int in range(1, values.size()):
		if values[index] <= values[index - 1]:
			return false
	return true


static func _intent_less(left: ActionIntent, right: ActionIntent) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return left.action_instance_id < right.action_instance_id


static func _context_less(left: ResolutionContext, right: ResolutionContext) -> bool:
	if left == null:
		return right != null
	if right == null:
		return false
	return left.action_instance_id < right.action_instance_id


static func _build_preliminary(
	world: WorldState,
	intents: Array[ActionIntent],
	contexts: Array[ResolutionContext]
) -> Dictionary:
	var preliminary: Dictionary = {}
	var claims: Array[Dictionary] = []
	for intent: ActionIntent in intents:
		var context: ResolutionContext = _context_for(contexts, intent.action_instance_id)
		var invalidation_reasons: Array[String] = _invalidation_reasons(
			world, intent, context
		)
		if not invalidation_reasons.is_empty():
			preliminary[intent.action_instance_id] = {
				"invalidation_reasons": invalidation_reasons,
				"proposed_units": 0,
				"source_store_id": "",
				"random_draws": [] as Array[RandomDrawRecord],
			}
			continue
		if intent.action_id == "A00":
			preliminary[intent.action_instance_id] = {
				"invalidation_reasons": [] as Array[String],
				"proposed_units": 0,
				"source_store_id": "",
				"random_draws": [] as Array[RandomDrawRecord],
			}
		elif intent.action_id == "A04":
			var response_result: Dictionary = ResponseEvaluator.evaluate(world, intent)
			if not bool(response_result.get("ok", false)):
				return {
					"ok": false,
					"reason_id": "component_ruleset_mismatch",
					"action_instance_id": intent.action_instance_id,
				}
			var evaluation: ResponseEvaluation = response_result.get("evaluation")
			var draws: Array[RandomDrawRecord] = response_result.get("random_draws", [])
			preliminary[intent.action_instance_id] = {
				"invalidation_reasons": [] as Array[String],
				"proposed_units": evaluation.selected_authorized_units,
				"source_store_id": evaluation.source_store_id,
				"response_evaluation": evaluation,
				"random_draws": draws,
			}
			claims.append({
				"action_instance_id": intent.action_instance_id,
				"action_id": intent.action_id,
				"source_store_id": evaluation.source_store_id,
				"proposed_units": evaluation.selected_authorized_units,
				"surplus_units": evaluation.surplus_units,
			})
		elif intent.action_id == "A11":
			var actor: PersonState = world.find_person(intent.actor_person_id)
			var target: ResourceStoreState = world.find_resource_store(intent.target_store_id)
			var base_capability: int = M4Math.round_div(
				4 * int(actor.aptitude_scores.get("dexterity", 0))
				+ 4 * int(actor.skill_scores.get("intrigue.theft", 0))
				+ 2 * int(actor.skill_scores.get("intrigue.stealth", 0)),
				10
			)
			var hunger_penalty: int = M4Math.round_div(
				int(actor.need_scores.get("hunger", 0)) * 20, 100
			)
			var health_penalty: int = M4Math.round_div(
				(100 - actor.health) * 20, 100
			)
			var performance_score: int = clampi(
				base_capability - hunger_penalty - health_penalty, 0, 100
			)
			var performance_draw: RandomDrawRecord = M4StatelessRng.draw(
				world,
				intent.action_instance_id,
				"A11_PERFORMANCE",
				actor.id
			)
			var exposure_draw: RandomDrawRecord = M4StatelessRng.draw(
				world,
				intent.action_instance_id,
				"A11_EXPOSURE",
				actor.id
			)
			var attempted_units: int = mini(intent.desired_units, 6)
			var performance_margin: int = (
				performance_score - target.security_level + performance_draw.mapped_value
			)
			var performance_scale: int = clampi(50 + performance_margin, 0, 100)
			var proposed_units: int = M4Math.round_div(
				attempted_units * performance_scale, 100
			)
			var stealth_capability: int = M4Math.round_div(
				3 * int(actor.aptitude_scores.get("dexterity", 0))
				+ 7 * int(actor.skill_scores.get("intrigue.stealth", 0)),
				10
			)
			var action_draws: Array[RandomDrawRecord] = [performance_draw, exposure_draw]
			preliminary[intent.action_instance_id] = {
				"invalidation_reasons": [] as Array[String],
				"proposed_units": proposed_units,
				"source_store_id": target.id,
				"random_draws": action_draws,
				"details_base": {
					"desired_units": intent.desired_units,
					"attempted_units": attempted_units,
					"performance_score": performance_score,
					"performance_offset": performance_draw.mapped_value,
					"actual_security": target.security_level,
					"performance_margin": performance_margin,
					"performance_scale": performance_scale,
					"proposed_units": proposed_units,
					"stealth_capability": stealth_capability,
					"exposure_offset": exposure_draw.mapped_value,
				},
			}
			claims.append({
				"action_instance_id": intent.action_instance_id,
				"action_id": intent.action_id,
				"source_store_id": target.id,
				"proposed_units": proposed_units,
				"surplus_units": 0,
			})
	return {
		"ok": true,
		"preliminary": preliminary,
		"claims": claims,
	}


static func _invalidation_reasons(
	world: WorldState, intent: ActionIntent, context: ResolutionContext
) -> Array[String]:
	var reasons: Array[String] = []
	var actor: PersonState = world.find_person(intent.actor_person_id)
	if actor == null or not actor.alive:
		reasons.append("actor_not_alive")
	if not context.present_person_ids.has(intent.actor_person_id):
		reasons.append("actor_not_present")
	if intent.action_id == "A04":
		var target_person: PersonState = world.find_person(intent.target_person_id)
		if target_person == null:
			reasons.append("target_person_missing")
		else:
			if not target_person.alive:
				reasons.append("target_person_not_alive")
			if not context.present_person_ids.has(target_person.id):
				reasons.append("target_person_not_present")
	elif intent.action_id == "A11":
		var target_store: ResourceStoreState = world.find_resource_store(intent.target_store_id)
		if target_store == null:
			reasons.append("target_store_missing")
		elif not context.present_store_ids.has(target_store.id):
			reasons.append("target_store_not_present")
	return _sorted_unique(reasons)


static func _resolve_conflicts(
	world: WorldState, claims: Array[Dictionary]
) -> Dictionary:
	var result: Dictionary = {}
	var source_ids: Array[String] = []
	for claim: Dictionary in claims:
		var source_id: String = str(claim.get("source_store_id", ""))
		if not source_ids.has(source_id):
			source_ids.append(source_id)
	source_ids.sort()
	for source_id: String in source_ids:
		var source_claims: Array[Dictionary] = []
		for claim: Dictionary in claims:
			if str(claim.get("source_store_id", "")) == source_id:
				source_claims.append(claim)
		var source: ResourceStoreState = world.find_resource_store(source_id)
		var allocation: Dictionary = _allocate_proportional(source_claims, source.quantity)
		var grant_claims: Array[Dictionary] = []
		var theft_claims: Array[Dictionary] = []
		var grant_surplus: int = MAX_STORED_INT
		var allocated_grants: int = 0
		for claim: Dictionary in source_claims:
			var action_id: String = str(claim.get("action_id", ""))
			var action_instance_id: String = str(claim.get("action_instance_id", ""))
			if action_id == "A04":
				grant_claims.append(claim)
				grant_surplus = mini(grant_surplus, int(claim.get("surplus_units", 0)))
				allocated_grants += int(allocation.get(action_instance_id, 0))
			elif action_id == "A11":
				theft_claims.append(claim)
		if not grant_claims.is_empty() and allocated_grants > grant_surplus:
			var grant_allocation: Dictionary = _allocate_proportional(
				grant_claims, grant_surplus
			)
			var grant_total: int = _dictionary_int_sum(grant_allocation)
			var theft_allocation: Dictionary = _allocate_proportional(
				theft_claims, source.quantity - grant_total
			)
			allocation = grant_allocation
			for action_key: Variant in theft_allocation.keys():
				allocation[action_key] = theft_allocation[action_key]
		for action_key: Variant in allocation.keys():
			result[action_key] = allocation[action_key]
	return result


static func _allocate_proportional(
	claims: Array[Dictionary], capacity: int
) -> Dictionary:
	var positive_claims: Array[Dictionary] = []
	var total_claimed: int = 0
	for claim: Dictionary in claims:
		var proposed: int = int(claim.get("proposed_units", 0))
		if proposed <= 0:
			continue
		positive_claims.append(claim)
		total_claimed += proposed
	if total_claimed <= capacity:
		var full: Dictionary = {}
		for claim: Dictionary in positive_claims:
			full[str(claim.get("action_instance_id", ""))] = int(
				claim.get("proposed_units", 0)
			)
		return full
	var allocation: Dictionary = {}
	var allocated_total: int = 0
	for claim: Dictionary in positive_claims:
		@warning_ignore("integer_division")
		var base: int = capacity * int(claim.get("proposed_units", 0)) / total_claimed
		var action_instance_id: String = str(claim.get("action_instance_id", ""))
		allocation[action_instance_id] = base
		allocated_total += base
	var remainder: int = capacity - allocated_total
	positive_claims.sort_custom(_claim_less)
	for claim: Dictionary in positive_claims:
		if remainder == 0:
			break
		var action_instance_id: String = str(claim.get("action_instance_id", ""))
		if int(allocation.get(action_instance_id, 0)) < int(claim.get("proposed_units", 0)):
			allocation[action_instance_id] = int(allocation.get(action_instance_id, 0)) + 1
			remainder -= 1
	return allocation


static func _sequence_preflight(
	world: WorldState,
	intents: Array[ActionIntent],
	preliminary: Dictionary,
	actual_units: Dictionary
) -> Dictionary:
	if world.resolution_epoch >= MAX_STORED_INT:
		return {"ok": false, "reason_id": "arithmetic_overflow", "action_instance_id": ""}
	var transaction_count: int = 0
	var destination_additions: Dictionary = {}
	for intent: ActionIntent in intents:
		var data: Dictionary = preliminary[intent.action_instance_id]
		if not (data.get("invalidation_reasons", []) as Array).is_empty():
			continue
		var actual: int = int(actual_units.get(intent.action_instance_id, 0))
		if actual <= 0:
			continue
		transaction_count += 1
		destination_additions[intent.recipient_store_id] = (
			int(destination_additions.get(intent.recipient_store_id, 0)) + actual
		)
	if transaction_count > 0 and world.day_index >= MAX_STORED_INT:
		return {"ok": false, "reason_id": "arithmetic_overflow", "action_instance_id": ""}
	if transaction_count > MAX_STORED_INT - world.next_resource_sequence_index:
		return {
			"ok": false,
			"reason_id": "resource_sequence_overflow",
			"action_instance_id": "",
		}
	for destination_id: Variant in destination_additions.keys():
		var destination: ResourceStoreState = world.find_resource_store(str(destination_id))
		if destination == null or int(destination_additions[destination_id]) > MAX_STORED_INT - destination.quantity:
			return {
				"ok": false,
				"reason_id": "arithmetic_overflow",
				"action_instance_id": "",
			}
	return {"ok": true}


static func _commit(
	world: WorldState,
	intents: Array[ActionIntent],
	contexts: Array[ResolutionContext],
	preliminary: Dictionary,
	actual_units: Dictionary
) -> BatchResolutionRecord:
	var transactions: Array[ResourceTransactionRecord] = []
	var outcomes: Array[ActionOutcomeRecord] = []
	var witness_seeds: Array[WitnessEvidenceSeed] = []
	var sequence_index: int = world.next_resource_sequence_index
	for intent: ActionIntent in intents:
		var context: ResolutionContext = _context_for(contexts, intent.action_instance_id)
		var preliminary_action: Dictionary = preliminary[intent.action_instance_id]
		var amount: int = int(actual_units.get(intent.action_instance_id, 0))
		var outcome_result: Dictionary = _build_outcome(
			world, intent, context, preliminary_action, amount
		)
		var outcome: ActionOutcomeRecord = outcome_result.get("outcome")
		var action_seeds: Array[WitnessEvidenceSeed] = outcome_result.get("witness_seeds", [])
		for seed: WitnessEvidenceSeed in action_seeds:
			witness_seeds.append(seed)

		var invalidation_reasons: Array = preliminary_action.get("invalidation_reasons", [])
		if amount > 0 and invalidation_reasons.is_empty():
			var transaction: ResourceTransactionRecord = _build_transaction(
				world, intent, amount, sequence_index
			)
			sequence_index += 1
			transactions.append(transaction)
			outcome.resource_transaction_ids.append(transaction.id)
		outcome.resource_transaction_ids.sort()
		outcome.witness_evidence_seed_ids.sort()
		outcome.random_draws.sort_custom(_draw_less)
		outcome.finalize_hash()
		outcomes.append(outcome)

	var metadata: Dictionary = {
		"schema_version": world.schema_version,
		"ruleset_manifest": world.ruleset_manifest.duplicate(true),
		"simulation_ruleset_hash": world.simulation_ruleset_hash,
	}
	var next_world: WorldState = WorldState.from_data(metadata, world.to_state_data())
	var transaction_errors: Array[String] = ResourceService.apply_transactions(
		next_world, transactions
	)
	if not transaction_errors.is_empty():
		return BatchResolutionRecord.rejected(world, "post_apply_invariant_failure")
	next_world.next_resource_sequence_index = sequence_index
	next_world.resolution_epoch += 1
	for intent: ActionIntent in intents:
		if not next_world.resolved_decision_slot_ids.has(intent.decision_slot_id):
			next_world.resolved_decision_slot_ids.append(intent.decision_slot_id)
	next_world.resolved_decision_slot_ids.sort()

	var reconciliation: Dictionary = ResourceService.reconcile(
		world, next_world, transactions
	)
	var final_errors: Array[String] = reconciliation.get("errors", [])
	if ResourceService.total_quantity(world) != ResourceService.total_quantity(next_world):
		final_errors.append("M4 transfer conservation failed")
	final_errors.append_array(StateValidator.validate_world(next_world))
	var output_hash: String = StateHasher.hash_world(next_world)
	if output_hash.is_empty():
		final_errors.append("failed to hash committed schema 4 world")
	if not final_errors.is_empty():
		return BatchResolutionRecord.rejected(world, "post_apply_invariant_failure")

	outcomes.sort_custom(_outcome_less)
	transactions.sort_custom(_transaction_artifact_less)
	witness_seeds.sort_custom(_witness_seed_less)
	var result: BatchResolutionRecord = BatchResolutionRecord.new()
	result.batch_status = "COMMITTED"
	result.input_state_hash = StateHasher.hash_world(world)
	result.output_state_hash = output_hash
	result.input_resolution_epoch = world.resolution_epoch
	result.output_resolution_epoch = next_world.resolution_epoch
	result.committed_outcomes = outcomes
	result.resource_transactions = transactions
	result.witness_evidence_seeds = witness_seeds
	result.next_world = next_world
	result.finalize_hash()
	return result


static func _build_outcome(
	world: WorldState,
	intent: ActionIntent,
	context: ResolutionContext,
	preliminary: Dictionary,
	actual_units: int
) -> Dictionary:
	var outcome: ActionOutcomeRecord = ActionOutcomeRecord.new()
	outcome.id = intent.action_instance_id
	outcome.action_instance_id = intent.action_instance_id
	outcome.action_id = intent.action_id
	outcome.actor_person_id = intent.actor_person_id
	outcome.intent_hash = intent.intent_hash
	outcome.context_id = context.context_id
	outcome.source_decision_hash = intent.source_decision_hash
	var invalidation_reasons: Array[String] = preliminary.get(
		"invalidation_reasons", [] as Array[String]
	)
	if not invalidation_reasons.is_empty():
		outcome.processing_status = "INVALIDATED"
		outcome.objective_outcome = "NOT_APPLICABLE"
		outcome.invalidation_reason_ids = invalidation_reasons.duplicate()
		outcome.details = {}
		return {
			"outcome": outcome,
			"witness_seeds": [] as Array[WitnessEvidenceSeed],
		}
	outcome.processing_status = "RESOLVED"
	var draws: Array[RandomDrawRecord] = preliminary.get(
		"random_draws", [] as Array[RandomDrawRecord]
	)
	outcome.random_draws = draws.duplicate()
	if intent.action_id == "A00":
		outcome.objective_outcome = "NOT_APPLICABLE"
		outcome.details = {}
		return {
			"outcome": outcome,
			"witness_seeds": [] as Array[WitnessEvidenceSeed],
		}
	if intent.action_id == "A04":
		var evaluation: ResponseEvaluation = preliminary.get("response_evaluation")
		outcome.objective_outcome = _objective(actual_units, intent.requested_units)
		outcome.details = {
			"target_person_id": intent.target_person_id,
			"source_store_id": evaluation.source_store_id,
			"recipient_store_id": intent.recipient_store_id,
			"requested_units": intent.requested_units,
			"response_decision": evaluation.selected_decision,
			"response_authorized_units": evaluation.selected_authorized_units,
			"proposed_units": evaluation.selected_authorized_units,
			"actual_units": actual_units,
			"response_evaluation": evaluation.to_data(),
		}
		return {
			"outcome": outcome,
			"witness_seeds": [] as Array[WitnessEvidenceSeed],
		}

	var details: Dictionary = preliminary.get("details_base", {}).duplicate(true)
	details["target_store_id"] = intent.target_store_id
	details["recipient_store_id"] = intent.recipient_store_id
	var attempted_units: int = int(details.get("attempted_units", 0))
	var outcome_adjustment: int = 0
	if actual_units == 0:
		outcome_adjustment = 15
	elif actual_units < attempted_units:
		outcome_adjustment = 5
	var exposure_pressure: int = clampi(
		int(details.get("actual_security", 0))
		+ 2 * attempted_units
		+ outcome_adjustment
		- int(details.get("stealth_capability", 0))
		+ int(details.get("exposure_offset", 0)),
		0,
		100
	)
	var trace_created: bool = exposure_pressure >= 50
	var witness_evaluations: Array = []
	var seeds: Array[WitnessEvidenceSeed] = []
	var exposure_half: int = M4Math.round_div(exposure_pressure, 2)
	for witness_id: String in context.present_person_ids:
		if witness_id == intent.actor_person_id:
			continue
		var witness: PersonState = world.find_person(witness_id)
		if witness == null or not witness.alive:
			continue
		var witness_draw: RandomDrawRecord = M4StatelessRng.draw(
			world,
			intent.action_instance_id,
			"A11_WITNESS",
			witness.id
		)
		outcome.random_draws.append(witness_draw)
		var evaluation: WitnessEvaluation = WitnessEvaluation.new()
		evaluation.witness_person_id = witness.id
		evaluation.perception_score = int(witness.aptitude_scores.get("perception", 0))
		evaluation.exposure_pressure = exposure_pressure
		evaluation.exposure_half = exposure_half
		evaluation.notice_offset = witness_draw.mapped_value
		evaluation.notice_score = clampi(
			evaluation.perception_score + exposure_half + evaluation.notice_offset,
			0,
			100
		)
		evaluation.notice_threshold = 75
		evaluation.witnessed = evaluation.notice_score >= evaluation.notice_threshold
		witness_evaluations.append(evaluation.to_data())
		if evaluation.witnessed:
			var seed: WitnessEvidenceSeed = _build_witness_seed(
				world,
				intent,
				context,
				evaluation,
				actual_units,
				trace_created
			)
			seeds.append(seed)
			outcome.witness_evidence_seed_ids.append(seed.id)
	details["actual_units"] = actual_units
	details["exposure_pressure"] = exposure_pressure
	details["trace_created"] = trace_created
	details["witness_evaluations"] = witness_evaluations
	outcome.objective_outcome = _objective(actual_units, intent.desired_units)
	outcome.details = details
	return {"outcome": outcome, "witness_seeds": seeds}


static func _build_witness_seed(
	world: WorldState,
	intent: ActionIntent,
	context: ResolutionContext,
	evaluation: WitnessEvaluation,
	actual_units: int,
	trace_created: bool
) -> WitnessEvidenceSeed:
	var seed: WitnessEvidenceSeed = WitnessEvidenceSeed.new()
	seed.action_instance_id = intent.action_instance_id
	seed.context_id = context.context_id
	seed.witness_person_id = evaluation.witness_person_id
	seed.actor_person_id = intent.actor_person_id
	seed.action_id = intent.action_id
	seed.notice_score = evaluation.notice_score
	seed.notice_threshold = evaluation.notice_threshold
	seed.actual_units = actual_units
	seed.trace_created = trace_created
	seed.day_index = world.day_index
	seed.phase_id = DecisionInstanceKey.PHASE_ID
	seed.id = StateHasher.hash_data({
		"algorithm_id": "m4-witness-seed-id-v1",
		"action_instance_id": seed.action_instance_id,
		"context_id": seed.context_id,
		"witness_person_id": seed.witness_person_id,
	})
	return seed


static func _build_transaction(
	world: WorldState,
	intent: ActionIntent,
	actual_units: int,
	sequence_index: int
) -> ResourceTransactionRecord:
	var transfer_leg: String = "A04_FOOD_GRANT" if intent.action_id == "A04" else "A11_FOOD_THEFT"
	var transaction: ResourceTransactionRecord = ResourceTransactionRecord.new()
	transaction.id = "resource_transaction:m4:" + StateHasher.hash_data({
		"algorithm_id": "m4-resource-transaction-id-v1",
		"action_instance_id": intent.action_instance_id,
		"transfer_leg": transfer_leg,
	})
	transaction.day_index = world.day_index + 1
	transaction.sequence_index = sequence_index
	transaction.resource_type_id = "food"
	transaction.source_store_id = (
		_response_source_store(world, intent)
		if intent.action_id == "A04"
		else intent.target_store_id
	)
	transaction.destination_store_id = intent.recipient_store_id
	transaction.consumer_person_id = ""
	transaction.quantity = actual_units
	transaction.reason_id = "food_request_grant" if intent.action_id == "A04" else "food_theft"
	return transaction


static func _response_source_store(world: WorldState, intent: ActionIntent) -> String:
	var responder: PersonState = world.find_person(intent.target_person_id)
	var household: HouseholdState = world.find_household(responder.household_id)
	return household.resource_store_id


static func _objective(actual_units: int, requested_or_desired_units: int) -> String:
	if actual_units == requested_or_desired_units:
		return "FULL"
	if actual_units > 0:
		return "PARTIAL"
	return "NONE"


static func _context_for(
	contexts: Array[ResolutionContext], action_instance_id: String
) -> ResolutionContext:
	for context: ResolutionContext in contexts:
		if context.action_instance_id == action_instance_id:
			return context
	return null


static func _dictionary_int_sum(values: Dictionary) -> int:
	var result: int = 0
	for value: Variant in values.values():
		result += int(value)
	return result


static func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if not result.has(value):
			result.append(value)
	result.sort()
	return result


static func _claim_less(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("action_instance_id", "")) < str(right.get("action_instance_id", ""))


static func _draw_less(left: RandomDrawRecord, right: RandomDrawRecord) -> bool:
	if left.roll_purpose != right.roll_purpose:
		return left.roll_purpose < right.roll_purpose
	return left.participant_id < right.participant_id


static func _outcome_less(left: ActionOutcomeRecord, right: ActionOutcomeRecord) -> bool:
	return left.action_instance_id < right.action_instance_id


static func _transaction_artifact_less(
	left: ResourceTransactionRecord, right: ResourceTransactionRecord
) -> bool:
	return left.id < right.id


static func _witness_seed_less(left: WitnessEvidenceSeed, right: WitnessEvidenceSeed) -> bool:
	return left.id < right.id
