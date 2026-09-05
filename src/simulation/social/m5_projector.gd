class_name M5Projector
extends RefCounted


static func project(scope: M5OperationScope, batch: BatchResolutionRecord) -> Dictionary:
	if not scope.owns_stage(batch.next_world):
		return {"ok": false, "reports": []}
	var stage: WorldState = batch.next_world
	var count: int = 0
	for outcome: ActionOutcomeRecord in batch.committed_outcomes:
		if outcome.processing_status == "RESOLVED" and outcome.action_id in ["A04", "A11"]:
			count += 1
	if count > M5Data.MAX_INT - int(stage.next_ids.event):
		return {"ok": false, "reports": [], "overflow": true}
	var reports: Array = []
	var outcomes: Array[ActionOutcomeRecord] = batch.committed_outcomes.duplicate()
	outcomes.sort_custom(func(a: ActionOutcomeRecord, b: ActionOutcomeRecord) -> bool: return a.action_instance_id < b.action_instance_id)
	for outcome: ActionOutcomeRecord in outcomes:
		if outcome.processing_status != "RESOLVED" or outcome.action_id == "A00":
			continue
		var d: Dictionary = outcome.details
		var event: EventRecord = EventRecord.new()
		event.id = IdAllocator.next_id(stage, "event")
		event.day_index = scope.input_day_index
		event.action_id = outcome.action_id
		event.actor_ids = [outcome.actor_person_id]
		event.result_id = outcome.objective_outcome
		event.m5_origin = {"source_action_instance_id": outcome.action_instance_id, "source_outcome_hash": outcome.semantic_resolution_hash,
			"source_context_id": outcome.context_id, "input_resolution_epoch": scope.input_resolution_epoch, "output_resolution_epoch": scope.input_resolution_epoch + 1}
		if outcome.action_id == "A04":
			event.event_type = "aid_exchange"
			event.target_ids = [str(d.target_person_id)]
			event.location_id = d.source_store_id
			var payload: Dictionary = {"requester_person_id": outcome.actor_person_id, "responder_person_id": d.target_person_id,
				"requested_units": d.requested_units, "response_decision": d.response_decision, "actual_units": d.actual_units}
			event.objective_payload = payload.duplicate(true)
			event.objective_payload["source_store_id"] = d.source_store_id
			event.objective_payload["recipient_store_id"] = d.recipient_store_id
			reports.append(_report(event, outcome.actor_person_id, "aid_requester", "direct_interaction", payload))
			reports.append(_report(event, d.target_person_id, "aid_responder", "direct_interaction", payload))
		else:
			event.event_type = "theft_attempt"
			event.location_id = d.target_store_id
			event.objective_payload = {"actor_person_id": outcome.actor_person_id, "store_id": d.target_store_id,
				"actual_units": d.actual_units, "attempted_units": d.attempted_units, "trace_created": d.trace_created}
			reports.append(_report(event, outcome.actor_person_id, "theft_self", "self_experience",
				{"actor_person_id": outcome.actor_person_id, "store_id": d.target_store_id, "actual_units": d.actual_units}))
			for seed: WitnessEvidenceSeed in batch.witness_evidence_seeds:
				if seed.action_instance_id == outcome.action_instance_id:
					event.witness_ids.append(seed.witness_person_id)
					reports.append(_report(event, seed.witness_person_id, "theft_witness", "direct_witness",
						{"actor_person_id": outcome.actor_person_id, "store_id": d.target_store_id, "took_goods": d.actual_units > 0}))
			event.witness_ids.sort()
			if d.trace_created:
				stage.traces.append(TraceState.from_data({"id": "trace:" + outcome.action_instance_id, "event_id": event.id,
					"store_id": d.target_store_id, "occurred_day_index": event.day_index, "trace_type": "theft_disturbance",
					"exists": true, "source_action_instance_id": outcome.action_instance_id}))
		stage.events.append(event)
	return {"ok": true, "reports": reports}


static func _report(event: EventRecord, owner: String, view: String, acquisition: String, payload: Dictionary) -> Dictionary:
	return {"owner_person_id": owner, "event_id": event.id, "occurred_day_index": event.day_index,
		"acquisition_type": acquisition, "origin_view": view, "original_source_person_id": owner,
		"current_source_person_id": owner, "depth": 0, "confidence": 100, "is_secret": view == "theft_self", "payload": payload.duplicate(true)}


static func experiences(world: WorldState, submissions: Array, defaults: Array) -> Dictionary:
	var result: Dictionary = {}
	for submission: DecisionSubmission in submissions:
		var decision: DecisionResult = submission.submitted_decision_result
		var candidate: DecisionCandidateEvaluation = IntentParameterizer._selected_candidate(decision)
		var actor: PersonState = world.find_person(decision.actor_person_id)
		var parameterization: ParameterizationResult = IntentParameterizer.parameterize(world, submission.decision_request, decision)
		if not parameterization.ok:
			continue
		result[actor.id] = {"actor_person_id": actor.id, "action_instance_id": parameterization.intent.action_instance_id,
			"decision_hash": DecisionArtifactCodec.hash_result(decision), "norm_adherence": M5Data.score(actor, "trait_scores", "norm_adherence", defaults),
			"family_protection": M5Data.score(actor, "value_scores", "family_protection", defaults), "N": candidate.need_component,
			"K": candidate.risk_component, "C": candidate.norm_conflict_component, "voluntary": true}
	return result
