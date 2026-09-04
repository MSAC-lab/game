class_name M4Facade
extends RefCounted


static func execute_decisions_v1(
	world_value: Variant,
	decision_submissions_value: Variant,
	trusted_context_issuer: ResolutionContextIssuer
) -> BatchResolutionRecord:
	if not world_value is WorldState:
		return BatchResolutionRecord.rejected(null, "invalid_world")
	var world: WorldState = world_value
	var world_candidates: Array[Dictionary] = AtomicActionResolver.world_rejection_candidates(
		world
	)
	if not world_candidates.is_empty():
		return AtomicActionResolver.reject_candidate(
			world, AtomicActionResolver.select_rejection_candidate(world_candidates)
		)
	if typeof(decision_submissions_value) != TYPE_ARRAY:
		return BatchResolutionRecord.rejected(world, "field_contract_violation")
	var decision_submissions: Array = decision_submissions_value
	if decision_submissions.is_empty():
		return BatchResolutionRecord.rejected(world, "field_contract_violation")

	var intents: Array[ActionIntent] = []
	var failure_candidates: Array[Dictionary] = []
	for value: Variant in decision_submissions:
		if not value is DecisionSubmission:
			failure_candidates.append({
				"reason_id": "field_contract_violation",
				"action_instance_id": "",
			})
			continue
		var submission: DecisionSubmission = value
		if submission.decision_request == null or submission.submitted_decision_result == null:
			failure_candidates.append({
				"reason_id": "field_contract_violation",
				"action_instance_id": "",
			})
			continue
		var parameterization: ParameterizationResult = IntentParameterizer.parameterize(
			world,
			submission.decision_request,
			submission.submitted_decision_result
		)
		if parameterization.ok:
			intents.append(parameterization.intent)
		else:
			failure_candidates.append({
				"reason_id": parameterization.errors[0],
				"action_instance_id": parameterization.failure_action_instance_id,
			})
	if not failure_candidates.is_empty():
		return AtomicActionResolver.reject_candidate(
			world,
			AtomicActionResolver.select_rejection_candidate(failure_candidates)
		)

	if trusted_context_issuer == null or not trusted_context_issuer.is_trusted():
		return BatchResolutionRecord.rejected(world, "untrusted_context_issuer")
	intents.sort_custom(_intent_less)
	var contexts: Array[ResolutionContext] = []
	for intent: ActionIntent in intents:
		var context: ResolutionContext = trusted_context_issuer.issue_context(world, intent)
		if context == null:
			failure_candidates.append({
				"reason_id": "untrusted_context_issuer",
				"action_instance_id": intent.action_instance_id,
			})
		else:
			contexts.append(context)
	if not failure_candidates.is_empty():
		return AtomicActionResolver.reject_candidate(
			world,
			AtomicActionResolver.select_rejection_candidate(failure_candidates)
		)

	var request: ResolutionBatchRequest = ResolutionBatchRequest.new()
	request.intents = intents
	request.execution_contexts = contexts
	return AtomicActionResolver.resolve_trusted_v1(
		world, request, trusted_context_issuer
	)


static func _intent_less(left: ActionIntent, right: ActionIntent) -> bool:
	return left.action_instance_id < right.action_instance_id
