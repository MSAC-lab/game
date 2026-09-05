class_name M60Evidence
extends RefCounted

const DAY_KEYS: Array[String] = ["id", "day_index", "day_status", "input_state_hash", "output_state_hash",
	"decisions", "action_status", "m4_batch_artifact", "contact_plan", "operations", "record_hash"]


static func begin_day(world: WorldState) -> Dictionary:
	return {"id": "m60-day:%010d" % world.day_index, "day_index": world.day_index, "day_status": "ABORTED",
		"input_state_hash": StateHasher.hash_world(world), "output_state_hash": "", "decisions": [],
		"action_status": "NOT_RUN", "m4_batch_artifact": null, "contact_plan": {"pairs": []}, "operations": [], "record_hash": ""}


static func finish(record: Dictionary) -> Dictionary:
	var data: Dictionary = record.duplicate(true)
	data.erase("record_hash")
	data.record_hash = StateHasher.hash_data(data)
	return StateCanonicalizer.canonicalize(data)


static func operation(kind: String, result: M5OperationResult) -> Dictionary:
	return {"id": kind, "artifact": result.artifact.duplicate(true),
		"resource_transactions": ModelData.object_array_to_data(result.resource_transactions)}


static func validate_m4(raw: Variant, artifact: Dictionary) -> String:
	if artifact.m4_batch_artifact_hash.is_empty():
		return "m4.unexpected" if raw != null else ""
	if not M5Data.exact(raw, ["batch_resolution", "batch_artifact_hash"]) or not M5Data.json_value(raw):
		return "m4.missing_or_shape"
	var keys: Array = BatchResolutionRecord.new().to_data_without_batch_artifact_hash_and_next_world().keys()
	if not M5Data.exact(raw.batch_resolution, keys):
		return "m4.batch_resolution"
	for key: String in ["errors", "committed_outcomes", "resource_transactions", "witness_evidence_seeds", "attempt_diagnostics"]:
		if typeof(raw.batch_resolution[key]) != TYPE_ARRAY:
			return "m4." + key
	var expected: String = StateHasher.hash_data({"algorithm_id": "m4-batch-artifact-v1", "batch_resolution": raw.batch_resolution})
	if raw.batch_artifact_hash != expected or expected != artifact.m4_batch_artifact_hash:
		return "m4.batch_artifact_hash"
	if raw.batch_resolution.input_state_hash != artifact.input_state_hash:
		return "m4.input_state_hash"
	if raw.batch_resolution.batch_status == "COMMITTED":
		if raw.batch_resolution.output_state_hash != artifact.intermediate_state_hash:
			return "m4.output_state_hash"
	elif raw.batch_resolution.batch_status != "REJECTED" or artifact.status != "REJECTED":
		return "m4.batch_status"
	return ""


static func validate_result(result: M5OperationResult, source: WorldState, kind: String) -> String:
	if result == null or not M5AuditValidator.validate(result.artifact).is_empty():
		return "operation.artifact"
	var artifact: Dictionary = result.artifact
	if artifact.operation_kind != kind or artifact.input_state_hash != StateHasher.hash_world(source):
		return "operation.input"
	if result.ok != (artifact.status == "COMMITTED"):
		return "operation.status"
	if result.ok:
		if result.next_world == null or StateHasher.hash_world(result.next_world) != artifact.output_state_hash:
			return "operation.output"
	elif result.next_world != null or not result.resource_transactions.is_empty():
		return "operation.rejected_output"
	return ""


static func validate_committed_day(value: Variant, day: int, input_hash: String) -> String:
	if not M5Data.exact(value, DAY_KEYS) or not M5Data.json_value(value):
		return "days.record"
	var row: Dictionary = value
	if row.day_index != day or typeof(row.day_index) != TYPE_INT or row.id != "m60-day:%010d" % day or row.day_status != "COMMITTED" or row.input_state_hash != input_hash:
		return "days.boundary"
	if row.record_hash != finish(row).record_hash:
		return "days.record_hash"
	if typeof(row.decisions) != TYPE_ARRAY or typeof(row.operations) != TYPE_ARRAY:
		return "days.rows"
	if not M5Data.exact(row.contact_plan, ["pairs"]) or typeof(row.contact_plan.pairs) != TYPE_ARRAY:
		return "days.contact_plan"
	var expected: Array[String] = ["2:CONTACTS", "3:CLOSE"]
	if row.action_status == "EXECUTED":
		if row.decisions.is_empty():
			return "days.decisions"
		expected.push_front("1:EXECUTE")
	elif row.action_status != "SKIPPED_NO_ACTORS" or not row.decisions.is_empty() or row.m4_batch_artifact != null:
		return "days.action_status"
	if row.operations.size() != expected.size():
		return "days.operations"
	var actors: Dictionary = {}
	var identity: Array = []
	for decision: Variant in row.decisions:
		if not M5Data.exact(decision, DecisionResult.new().to_data().keys()) or decision.ok != true or typeof(decision.actor_person_id) != TYPE_STRING:
			return "days.decisions"
		if decision.day_index != day or decision.input_state_hash != input_hash or actors.has(decision.actor_person_id) or decision.decision_key != "daily_food_strategy":
			return "days.decisions.input"
		var decision_hash: String = StateHasher.hash_data(decision)
		actors[decision.actor_person_id] = decision_hash
		var item: Dictionary = {"actor_person_id": decision.actor_person_id,
			"decision_key": decision.decision_key, "submitted_decision_hash": decision_hash}
		var preimage: Dictionary = item.duplicate(true)
		preimage.algorithm_id = "m5-execute-submission-id-v1"
		item.id = StateHasher.hash_data(preimage)
		identity.append(item)
	var previous_revision: int = -1
	for i: int in expected.size():
		var op: Variant = row.operations[i]
		if not M5Data.exact(op, ["id", "artifact", "resource_transactions"]) or op.id != expected[i] or typeof(op.artifact) != TYPE_DICTIONARY or typeof(op.resource_transactions) != TYPE_ARRAY:
			return "days.operations.shape"
		var artifact: Dictionary = op.artifact
		if not M5AuditValidator.validate(artifact).is_empty() or artifact.status != "COMMITTED":
			return "days.operations.artifact"
		if artifact.operation_kind != expected[i].get_slice(":", 1) or artifact.input_day_index != day or artifact.input_state_hash != input_hash:
			return "days.operations.chain"
		if previous_revision >= 0 and artifact.input_social_revision != previous_revision:
			return "days.operations.revision"
		if artifact.operation_kind == "EXECUTE":
			var error: String = validate_m4(row.m4_batch_artifact, artifact)
			if not error.is_empty():
				return error
			var body: Dictionary = row.m4_batch_artifact.batch_resolution
			if StateCanonicalizer.canonical_json(body.resource_transactions) != StateCanonicalizer.canonical_json(op.resource_transactions) or body.committed_outcomes.size() != actors.size():
				return "days.m4.output_binding"
			var seen: Dictionary = {}
			for outcome: Variant in body.committed_outcomes:
				if not M5Data.exact(outcome, ActionOutcomeRecord.new().to_data().keys()):
					return "days.m4.outcome"
				if typeof(outcome.actor_person_id) != TYPE_STRING or not actors.has(outcome.actor_person_id) or seen.has(outcome.actor_person_id) or outcome.source_decision_hash != actors[outcome.actor_person_id]:
					return "days.m4.decision_binding"
				seen[outcome.actor_person_id] = true
		var request: Variant = identity if artifact.operation_kind == "EXECUTE" else row.contact_plan if artifact.operation_kind == "CONTACTS" else {}
		var stamp: M5RequestStamp = M5RequestStamp.from_data({"day_index": day, "input_state_hash": input_hash, "social_revision": artifact.input_social_revision})
		if artifact.operation_id != M5Artifact.identity(artifact.operation_kind, stamp, request):
			return "days.operations.request_binding"
		for tx: Variant in op.resource_transactions:
			if not M5Data.exact(tx, ResourceTransactionRecord.new().to_data().keys()) or tx.day_index != day + 1 or typeof(tx.consumer_person_id) != TYPE_STRING:
				return "days.transactions"
			if artifact.operation_kind == "CONTACTS" or (artifact.operation_kind == "CLOSE") != (not tx.consumer_person_id.is_empty()):
				return "days.transactions.phase"
		input_hash = artifact.output_state_hash
		previous_revision = artifact.output_social_revision
	if row.output_state_hash != input_hash:
		return "days.output_state_hash"
	return ""
