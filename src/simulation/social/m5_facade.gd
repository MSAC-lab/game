class_name M5Facade
extends RefCounted

var _active_scope: M5OperationScope


static func execute_decisions_v1(world: Variant, stamp: Variant, submissions: Variant, issuer: ResolutionContextIssuer) -> M5OperationResult:
	return M5Facade.new()._run("EXECUTE", world, stamp, submissions, issuer)


static func process_contacts_v1(world: Variant, stamp: Variant, plan: Variant) -> M5OperationResult:
	return M5Facade.new()._run("CONTACTS", world, stamp, plan, null)


static func close_day_v1(world: Variant, stamp: Variant) -> M5OperationResult:
	return M5Facade.new()._run("CLOSE", world, stamp, null, null)


func _run(kind: String, world_value: Variant, stamp_value: Variant, request: Variant, issuer: ResolutionContextIssuer) -> M5OperationResult:
	var artifact: Dictionary = M5Artifact.begin(kind)
	if not world_value is WorldState:
		return _fail(artifact, "M5_INVALID_WORLD_TYPE", "world")
	var world: WorldState = world_value
	if world.schema_version != 5:
		return _fail(artifact, "M5_UNSUPPORTED_SCHEMA", "world.schema_version")
	if not M5StateValidator.typed_safe(world):
		return _fail(artifact, "M5_FIELD_CONTRACT", "world")
	var issues: Array[Dictionary] = M5StateValidator.issues(StateHasher.state_payload(world))
	if not issues.is_empty():
		return M5Artifact.failure(artifact, M5Artifact.select(issues))
	artifact.input_state_hash = StateHasher.hash_world(world)
	artifact.input_day_index = world.day_index
	artifact.input_social_revision = world.social_state.revision
	if not stamp_value is M5RequestStamp:
		return _fail(artifact, "M5_FIELD_CONTRACT", "stamp")
	var stamp: M5RequestStamp = stamp_value
	if stamp.day_index < 0 or stamp.day_index > M5Data.MAX_INT or stamp.social_revision < 0 or stamp.social_revision > M5Data.MAX_INT or not M5StateValidator._hash(stamp.input_state_hash):
		return _fail(artifact, "M5_FIELD_CONTRACT", "stamp")
	if stamp.day_index != world.day_index:
		return _fail(artifact, "M5_STALE_DAY", "stamp.day_index")
	if stamp.social_revision != world.social_state.revision:
		return _fail(artifact, "M5_STALE_REVISION", "stamp.social_revision")
	if stamp.input_state_hash != artifact.input_state_hash:
		return _fail(artifact, "M5_STALE_STATE_HASH", "stamp.input_state_hash")
	var contact_done: bool = world.social_state.last_contact_day_index == world.day_index
	if kind == "EXECUTE" and contact_done:
		return _fail(artifact, "M5_ACTIONS_CLOSED", "state.social_state.last_contact_day_index")
	if kind == "CONTACTS" and contact_done:
		return _fail(artifact, "M5_CONTACT_ALREADY_PROCESSED", "state.social_state.last_contact_day_index")
	if kind == "CLOSE" and not contact_done:
		return _fail(artifact, "M5_CONTACT_REQUIRED", "state.social_state.last_contact_day_index")
	var identity: Variant = {}
	if kind == "EXECUTE":
		if not _valid_submissions(request):
			return _fail(artifact, "M5_REQUEST_CONTRACT", "submissions")
		identity = M5Artifact.execute_identity(request)
		var seen: Dictionary = {}
		for element: Dictionary in identity:
			if seen.has(element.id) and seen[element.id] != element:
				return _fail(artifact, "M5_REQUEST_CONTRACT", "submissions")
			seen[element.id] = element
	elif kind == "CONTACTS":
		if not request is SocialContactPlan or not M5Contacts.validate(world, request):
			return _fail(artifact, "M5_REQUEST_CONTRACT", "plan.pairs")
		identity = request.to_data()
	artifact.operation_id = M5Artifact.identity(kind, stamp, identity)
	_active_scope = M5OperationScope._begin(self, world, kind)
	var scope: M5OperationScope = _active_scope
	var stage: WorldState
	var transactions: Array[ResourceTransactionRecord] = []
	var reports: Array = []
	var experiences: Dictionary = {}
	var physical_checkpoint: WorldState
	if kind == "EXECUTE":
		var batch: BatchResolutionRecord = M4Facade._execute_m5(scope, request, issuer)
		_after_kernel(scope, batch)
		var binding: String = M5StageBoundary._validate_batch(scope, batch, issuer)
		if not binding.is_empty():
			return _fail(artifact, "M5_ARTIFACT_BINDING", binding)
		if batch.batch_status == "REJECTED":
			artifact.m4_batch_artifact_hash = batch.batch_artifact_hash
			return _fail(artifact, "M5_M4_REJECTED", "m4.batch", batch.attempt_diagnostics[0].action_instance_id, batch.errors[0])
		artifact.intermediate_state_hash = batch.output_state_hash
		artifact.m4_batch_artifact_hash = batch.batch_artifact_hash
		stage = batch.next_world
		transactions = batch.resource_transactions
		physical_checkpoint = M5Data.clone(stage)
		var projection: Dictionary = M5Projector.project(scope, batch)
		if not projection.ok:
			return _fail(artifact, "M5_ARITHMETIC_OVERFLOW" if projection.get("overflow", false) else "M5_OBSERVATION_CONTRACT", "state.next_ids.event" if projection.get("overflow", false) else "reports")
		reports = projection.reports
		experiences = M5Projector.experiences(scope.input_world, request, artifact.defaulted_inputs)
	elif kind == "CONTACTS":
		stage = M5Data.clone(scope.input_world)
		scope.register_stage(stage)
		physical_checkpoint = M5Data.clone(stage)
		reports = M5Contacts.reports(scope.input_world, request, artifact.defaulted_inputs)
	else:
		var day_result: DayAdvanceResult = DayProcessor._advance_m5(scope)
		if not day_result.ok:
			for reason: String in day_result.errors:
				if reason.begins_with("M2_DEATH_NOT_IMPLEMENTED: "):
					var person_id: String = reason.trim_prefix("M2_DEATH_NOT_IMPLEMENTED: ").get_slice(" ", 0)
					return _fail(artifact, "M5_POST_APPLY_INVARIANT", "state.persons.health", person_id)
			return _fail(artifact, "M5_ARITHMETIC_OVERFLOW" if _contains_overflow(day_result.errors) else "M5_ARTIFACT_BINDING", "day_resources")
		stage = day_result.next_world
		transactions = day_result.resource_transactions
		_after_day_kernel(scope, stage)
		if not M5StageBoundary._validate_after_day_resources(scope, stage, transactions).is_empty():
			return _fail(artifact, "M5_ARTIFACT_BINDING", "day_resources")
		artifact.intermediate_state_hash = M5StageBoundary._hash_stage(scope, "AFTER_DAY_RESOURCES", stage)
		physical_checkpoint = M5Data.clone(stage)
	if world.social_state.revision >= M5Data.MAX_INT:
		return _fail(artifact, "M5_ARITHMETIC_OVERFLOW", "state.social_state.revision")
	if kind != "CLOSE":
		var effect_error: Dictionary = M5Effects.apply(scope.input_world, stage, reports, experiences, artifact)
		if not effect_error.is_empty():
			return _fail_issue(artifact, effect_error)
		M5Maintenance.memories(stage, world.social_state.last_closed_day_index, artifact)
	else:
		if not M5Maintenance.close(stage, world.day_index, artifact):
			return _fail(artifact, "M5_POST_APPLY_INVARIANT", "state.social_state.last_settled_week_index")
	stage.social_state.revision = world.social_state.revision + 1
	if kind == "EXECUTE":
		stage.social_state.last_integrated_resolution_epoch = stage.resolution_epoch
	elif kind == "CONTACTS":
		stage.social_state.last_contact_day_index = world.day_index
	else:
		stage.social_state.last_closed_day_index = world.day_index
	_before_publish(scope, stage, artifact)
	if _physical_projection(physical_checkpoint, kind) != _physical_projection(stage, kind):
		return _fail(artifact, "M5_POST_APPLY_INVARIANT", "state.physical_delta")
	issues = M5StateValidator.issues(StateHasher.state_payload(stage))
	if stage.social_state.revision != world.social_state.revision + 1:
		issues.append(M5StateValidator.issue("state.social_state.revision"))
	if not issues.is_empty():
		var error: Dictionary = M5Artifact.select(issues).duplicate(true)
		error.code = "M5_POST_APPLY_INVARIANT"
		return _fail_issue(artifact, error)
	artifact.status = "COMMITTED"
	artifact.output_state_hash = StateHasher.hash_world(stage)
	artifact.output_day_index = stage.day_index
	artifact.output_social_revision = stage.social_state.revision
	artifact.state_metrics = M5Artifact.metrics(stage)
	var result: M5OperationResult = M5OperationResult.new()
	result.ok = true
	result.next_world = stage
	result.resource_transactions = transactions
	result.artifact = M5Artifact.finish(artifact)
	scope.finish()
	_active_scope = null
	return result


static func _valid_submissions(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.is_empty():
		return false
	for item: Variant in value:
		if not item is DecisionSubmission or item.decision_request == null or item.submitted_decision_result == null:
			return false
		if not M5Data.exact(item.decision_request.to_data(), ["actor_person_id", "decision_key"]):
			return false
		var result: DecisionResult = item.submitted_decision_result
		for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
			if candidate == null:
				return false
		for exclusion: DecisionExclusion in result.excluded_candidates:
			if exclusion == null:
				return false
		if not M5Data.json_value(result.to_data()):
			return false
	return true


static func _contains_overflow(errors: Array[String]) -> bool:
	for error: String in errors:
		if "overflow" in error:
			return true
	return false


func _fail(artifact: Dictionary, code: String, path: String, entity: String = "", cause: String = "") -> M5OperationResult:
	return _fail_issue(artifact, {"code": code, "field_path": path, "entity_id": entity, "cause_code": cause})


func _fail_issue(artifact: Dictionary, issue: Dictionary) -> M5OperationResult:
	if _active_scope != null:
		_active_scope.finish()
	_active_scope = null
	return M5Artifact.failure(artifact, issue)


func _after_kernel(_scope: M5OperationScope, _batch: BatchResolutionRecord) -> void:
	pass


func _after_day_kernel(_scope: M5OperationScope, _stage: WorldState) -> void:
	pass


func _before_publish(_scope: M5OperationScope, _stage: WorldState, _artifact: Dictionary) -> void:
	pass


static func _physical_projection(world: WorldState, kind: String) -> String:
	var payload: Dictionary = StateHasher.state_payload(world)
	var state: Dictionary = payload.state
	for key: String in ["social_state", "social_observations", "social_effect_receipts", "traces", "trait_pressures", "repeat_exposures", "events", "information", "memories", "relations"]:
		state.erase(key)
	for key: String in ["event", "information", "memory"]:
		state.next_ids.erase(key)
	for person: Dictionary in state.persons:
		for key: String in ["information_ids", "memory_ids", "relation_ids"]:
			person.erase(key)
		for emotion: String in ["fear", "anger", "guilt"]:
			person.emotion_scores.erase(emotion)
		if kind == "CLOSE":
			person.trait_scores.erase("norm_adherence")
	return StateCanonicalizer.canonical_json(payload)
