class_name M5StageBoundary
extends RefCounted


static func _hash_stage(scope: M5OperationScope, kind: String, stage: WorldState) -> String:
	if not scope.owns_stage(stage) or kind not in ["AFTER_RESOLUTION", "AFTER_DAY_RESOURCES"]:
		return ""
	return StateHasher.hash_data({"algorithm_id": "m5-stage-state-v1", "scope_id": scope.scope_id,
		"stage_kind": kind, "payload": StateHasher.state_payload(stage)})


static func _validate_after_resolution(scope: M5OperationScope, stage: WorldState, transactions: Array[ResourceTransactionRecord]) -> Array[String]:
	if not scope.owns_stage(stage) or scope.operation_kind != "EXECUTE":
		return ["unowned resolution stage"]
	var before: WorldState = scope.input_world
	var expected: WorldState = M5Data.clone(before)
	scope.register_stage(expected)
	var errors: Array[String] = ResourceService._apply_m5(scope, expected, transactions)
	var sequence: int = before.next_resource_sequence_index
	for transaction: ResourceTransactionRecord in ResourceService._ordered(transactions):
		if transaction.sequence_index != sequence or transaction.day_index != before.day_index + 1 or not transaction.consumer_person_id.is_empty():
			errors.append("resolution transaction clock/sequence/transfer mismatch")
		sequence += 1
	expected.next_resource_sequence_index = sequence
	expected.resolution_epoch += 1
	for intent: ActionIntent in scope.intents:
		expected.resolved_decision_slot_ids.append(intent.decision_slot_id)
	expected.resolved_decision_slot_ids.sort()
	if not M5StateValidator._structure_issues(StateHasher.state_payload(stage)).is_empty():
		errors.append("resolution stage structure invalid")
	if StateCanonicalizer.canonical_json(StateHasher.state_payload(expected)) != StateCanonicalizer.canonical_json(StateHasher.state_payload(stage)):
		errors.append("resolution stage contains unauthorized delta")
	return errors


static func _validate_after_day_resources(scope: M5OperationScope, stage: WorldState, transactions: Array[ResourceTransactionRecord]) -> Array[String]:
	if not scope.owns_stage(stage) or scope.operation_kind != "CLOSE":
		return ["unowned day resource stage"]
	var before: WorldState = scope.input_world
	var expected: WorldState = M5Data.clone(before)
	scope.register_stage(expected)
	var plan: DayPlan = DayProcessor._build_plan_schema4(expected, before.next_resource_sequence_index)
	var errors: Array[String] = ResourceService._apply_m5(scope, expected, plan.resource_transactions)
	if StateCanonicalizer.canonical_json(ModelData.object_array_to_data(transactions)) != StateCanonicalizer.canonical_json(ModelData.object_array_to_data(plan.resource_transactions)):
		errors.append("day transaction plan mismatch")
	for person: PersonState in expected.persons:
		if person.alive:
			var hunger_error: String = PersonDayUpdate.update_hunger(person, plan.eaten_by(person.id))
			var health_error: String = PersonDayUpdate.update_health(person)
			if not hunger_error.is_empty() or not health_error.is_empty():
				errors.append("day physical update invalid")
	expected.day_index += 1
	expected.next_resource_sequence_index += transactions.size()
	expected.resolved_decision_slot_ids = []
	if not M5StateValidator._structure_issues(StateHasher.state_payload(stage)).is_empty():
		errors.append("day resource stage structure invalid")
	if StateCanonicalizer.canonical_json(StateHasher.state_payload(expected)) != StateCanonicalizer.canonical_json(StateHasher.state_payload(stage)):
		errors.append("day resource stage contains unauthorized delta")
	return errors


static func _validate_batch(scope: M5OperationScope, batch: BatchResolutionRecord, issuer: ResolutionContextIssuer) -> String:
	if not scope.owns_input(scope.input_world) or batch.input_state_hash != scope.input_state_hash or batch.input_resolution_epoch != scope.input_resolution_epoch:
		return "m4.batch.input_state_hash"
	if batch.batch_status == "REJECTED":
		if batch.errors.size() != 1 or batch.attempt_diagnostics.size() != 1:
			return "m4.batch"
		var expected: BatchResolutionRecord = BatchResolutionRecord.rejected(scope.input_world, batch.errors[0], batch.attempt_diagnostics[0].action_instance_id)
		if expected.to_data() != batch.to_data():
			return "m4.batch"
		return ""
	if batch.batch_status != "COMMITTED" or batch.next_world == null or not batch.errors.is_empty() or not batch.attempt_diagnostics.is_empty():
		return "m4.batch"
	if not _validate_after_resolution(scope, batch.next_world, batch.resource_transactions).is_empty():
		return "m4.batch.output_state_hash"
	if batch.output_state_hash != _hash_stage(scope, "AFTER_RESOLUTION", batch.next_world):
		return "m4.batch.output_state_hash"
	if batch.output_resolution_epoch != scope.input_resolution_epoch + 1:
		return "m4.batch.output_resolution_epoch"
	var expected_hash: String = StateHasher.hash_data({"algorithm_id": "m4-batch-artifact-v1", "batch_resolution": batch.to_data_without_batch_artifact_hash_and_next_world()})
	if expected_hash != batch.batch_artifact_hash or batch.committed_outcomes.size() != scope.intents.size():
		return "m4.batch.batch_artifact_hash"
	var seen: Dictionary = {}
	var seen_seeds: Dictionary = {}
	var seed_ids: Array[String] = []
	var transaction_ids: Array[String] = []
	for outcome: ActionOutcomeRecord in batch.committed_outcomes:
		var intent: ActionIntent = null
		var context: ResolutionContext = null
		for item: ActionIntent in scope.intents:
			if item.action_instance_id == outcome.action_instance_id:
				intent = item
		for item: ResolutionContext in scope.contexts:
			if item.action_instance_id == outcome.action_instance_id:
				context = item
		if intent == null or context == null or seen.has(outcome.action_instance_id):
			return "m4.batch.committed_outcomes"
		seen[outcome.action_instance_id] = true
		if issuer == null or not issuer.owns_context(context) or context.context_id != context.compute_context_id() or context.input_state_hash != scope.input_state_hash:
			return "m4.batch.context"
		if outcome.intent_hash != intent.intent_hash or outcome.context_id != context.context_id or outcome.actor_person_id != intent.actor_person_id or outcome.action_id != intent.action_id or outcome.source_decision_hash != intent.source_decision_hash:
			return "m4.batch.committed_outcomes"
		if outcome.semantic_resolution_hash != StateHasher.hash_data({"algorithm_id": "m4-semantic-resolution-v1", "action_outcome": outcome.to_data_without_semantic_resolution_hash()}):
			return "m4.batch.committed_outcomes.semantic_resolution_hash"
		if outcome.processing_status not in ["RESOLVED", "INVALIDATED"]:
			return "m4.batch.committed_outcomes.processing_status"
		seed_ids.append_array(outcome.witness_evidence_seed_ids)
		transaction_ids.append_array(outcome.resource_transaction_ids)
		for seed: WitnessEvidenceSeed in batch.witness_evidence_seeds:
			if seed.action_instance_id != outcome.action_instance_id:
				continue
			if not outcome.witness_evidence_seed_ids.has(seed.id) or seed.action_id != "A11" or seed.actor_person_id != intent.actor_person_id or seed.context_id != context.context_id or seed.day_index != scope.input_day_index or not context.present_person_ids.has(seed.witness_person_id) or seed.witness_person_id == intent.actor_person_id or seed.actual_units != outcome.details.get("actual_units") or seed.trace_created != outcome.details.get("trace_created"):
				return "m4.batch.witness_evidence_seeds"
			if seen_seeds.has(seed.id) or seed.phase_id != DecisionInstanceKey.PHASE_ID or seed.notice_threshold != 75 or seed.notice_score < seed.notice_threshold or seed.notice_score > 100:
				return "m4.batch.witness_evidence_seeds"
			seen_seeds[seed.id] = true
			var expected_seed_id: String = StateHasher.hash_data({"algorithm_id": "m4-witness-seed-id-v1", "action_instance_id": seed.action_instance_id, "context_id": seed.context_id, "witness_person_id": seed.witness_person_id})
			if seed.id != expected_seed_id:
				return "m4.batch.witness_evidence_seeds"
			var bound_evaluation: bool = false
			for evaluation: Dictionary in outcome.details.get("witness_evaluations", []):
				if evaluation.witness_person_id == seed.witness_person_id and evaluation.witnessed and evaluation.notice_score == seed.notice_score and evaluation.notice_threshold == seed.notice_threshold:
					bound_evaluation = true
			if not bound_evaluation:
				return "m4.batch.witness_evidence_seeds"
	var actual_seeds: Array[String] = []
	for seed: WitnessEvidenceSeed in batch.witness_evidence_seeds:
		actual_seeds.append(seed.id)
	var actual_transactions: Array[String] = []
	for transaction: ResourceTransactionRecord in batch.resource_transactions:
		actual_transactions.append(transaction.id)
	seed_ids.sort()
	actual_seeds.sort()
	transaction_ids.sort()
	actual_transactions.sort()
	if seed_ids != actual_seeds or transaction_ids != actual_transactions:
		return "m4.batch.references"
	return ""
