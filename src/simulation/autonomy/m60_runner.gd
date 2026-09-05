class_name M60Runner
extends RefCounted
## The published state advances only after a complete day; observations never feed decisions.

const MAX_DAYS_PER_CALL: int = 366


static func run_v1(initial: Variant, config: Variant, day_count: Variant, checkpoint_json: String = "") -> M60RunResult:
	return M60Runner.new()._run(initial, config, day_count, checkpoint_json)


func _run(initial: Variant, config_value: Variant, day_count: Variant, checkpoint_json: String = "") -> M60RunResult:
	var result: M60RunResult = M60RunResult.new()
	var error: String = M60Checkpoint.boundary_error(initial)
	if not error.is_empty():
		return _reject(result, "M60_INPUT_WORLD", "START", error)
	error = M60Config.validate(config_value, initial)
	if not error.is_empty():
		return _reject(result, "M60_CONFIG", "START", error)
	var config: Dictionary = StateCanonicalizer.canonicalize(config_value)
	var initial_hash: String = StateHasher.hash_world(initial)
	if initial_hash != config.initial_state_hash:
		return _reject(result, "M60_INITIAL_HASH", "START", "config.initial_state_hash")
	if typeof(day_count) != TYPE_INT or day_count < 0 or day_count > MAX_DAYS_PER_CALL:
		return _reject(result, "M60_DAY_COUNT", "START", "day_count")
	result.requested_days = day_count
	result.initial_payload = StateCanonicalizer.canonicalize(StateHasher.state_payload(initial))
	result.config = config.duplicate(true)
	var committed: WorldState = M5Data.clone(initial)
	var records: Array = []
	if not checkpoint_json.is_empty():
		var restored: Dictionary = M60Checkpoint.decode(checkpoint_json, initial, config)
		if not restored.ok:
			return _reject(result, "M60_CHECKPOINT", "RESUME", restored.error)
		committed = restored.world
		records = restored.days
	if day_count > M5Data.MAX_INT - committed.day_index:
		return _reject(result, "M60_DAY_COUNT", "START", "world.day_index")
	for index: int in day_count:
		var day_result: Dictionary = _day(committed, config)
		if not day_result.ok:
			result.status = "STOPPED"
			result.failed_day = M60Evidence.finish(day_result.record)
			result.error = day_result.error
			break
		committed = day_result.world
		records.append(M60Evidence.finish(day_result.record))
		result.advanced_days += 1
	result.next_world = M5Data.clone(committed)
	result.days = records.duplicate(true)
	var saved: Dictionary = M60Checkpoint.encode(initial_hash, config, committed, records)
	if not saved.ok:
		return _reject(result, "M60_CHECKPOINT", "SAVE", saved.error)
	result.checkpoint_json = saved.json_text
	if result.status != "STOPPED":
		result.ok = true
		result.status = "COMPLETED"
	return result


func _day(start: WorldState, config: Dictionary) -> Dictionary:
	var record: Dictionary = M60Evidence.begin_day(start)
	var world: WorldState = M5Data.clone(start)
	var submissions: Array = []
	for actor_id: String in M60Config.actors(config, start):
		var request: DecisionRequest = DecisionRequest.create(actor_id, "daily_food_strategy")
		var decision: DecisionResult = DecisionEngine.evaluate(start, request)
		record.decisions.append(decision.to_data())
		if not decision.ok:
			return _stop(record, "M60_DECISION_REJECTED", "DECISION", actor_id)
		submissions.append(DecisionSubmission.create(request, decision))
	if submissions.is_empty():
		record.action_status = "SKIPPED_NO_ACTORS"
	else:
		record.action_status = "EXECUTED"
		var issuer: M60PresenceIssuer = M60PresenceIssuer.create(start, config)
		var observed: M5ObservedExecutionResult = _execute_actions(world, submissions, issuer)
		if observed == null or observed.operation_result == null:
			return _stop(record, "M60_EVIDENCE_BINDING", "EXECUTE", "operation_result")
		var action: M5OperationResult = observed.operation_result
		record.m4_batch_artifact = observed.m4_batch_artifact.duplicate(true) if observed.m4_batch_artifact != null else null
		record.operations.append(M60Evidence.operation("1:EXECUTE", action))
		var binding: String = M60Evidence.validate_result(action, world, "EXECUTE")
		if binding.is_empty():
			binding = M60Evidence.validate_m4(record.m4_batch_artifact, action.artifact)
		if not binding.is_empty():
			return _stop(record, "M60_EVIDENCE_BINDING", "EXECUTE", binding)
		if not action.ok:
			return _stop(record, "M60_M5_REJECTED", "EXECUTE", "", action.artifact.errors)
		world = action.next_world
	var plan: SocialContactPlan = M60Config.contact_plan(config, world)
	record.contact_plan = plan.to_data()
	var contact: M5OperationResult = M5Facade.process_contacts_v1(world, M5RequestStamp.for_world(world), plan)
	record.operations.append(M60Evidence.operation("2:CONTACTS", contact))
	var binding: String = M60Evidence.validate_result(contact, world, "CONTACTS")
	if not binding.is_empty():
		return _stop(record, "M60_EVIDENCE_BINDING", "CONTACTS", binding)
	if not contact.ok:
		return _stop(record, "M60_M5_REJECTED", "CONTACTS", "", contact.artifact.errors)
	world = contact.next_world
	var closed: M5OperationResult = M5Facade.close_day_v1(world, M5RequestStamp.for_world(world))
	record.operations.append(M60Evidence.operation("3:CLOSE", closed))
	binding = M60Evidence.validate_result(closed, world, "CLOSE")
	if not binding.is_empty():
		return _stop(record, "M60_EVIDENCE_BINDING", "CLOSE", binding)
	if not closed.ok:
		return _stop(record, "M60_M5_REJECTED", "CLOSE", "", closed.artifact.errors)
	binding = M60Checkpoint.boundary_error(closed.next_world)
	if not binding.is_empty():
		return _stop(record, "M60_EVIDENCE_BINDING", "CLOSE", binding)
	record.day_status = "COMMITTED"
	record.output_state_hash = StateHasher.hash_world(closed.next_world)
	return {"ok": true, "world": closed.next_world, "record": record, "error": {}}


func _execute_actions(world: WorldState, submissions: Array, issuer: ResolutionContextIssuer) -> M5ObservedExecutionResult:
	return M5Facade.execute_decisions_observed_v1(world, M5RequestStamp.for_world(world), submissions, issuer)


static func _stop(record: Dictionary, code: String, phase: String, path: String, details: Array = []) -> Dictionary:
	return {"ok": false, "world": null, "record": record,
		"error": {"code": code, "phase": phase, "field_path": path, "details": details.duplicate(true)}}


static func _reject(result: M60RunResult, code: String, phase: String, path: String) -> M60RunResult:
	result.ok = false
	result.status = "REJECTED"
	result.next_world = null
	result.checkpoint_json = ""
	result.error = {"code": code, "phase": phase, "field_path": path, "details": []}
	return result
