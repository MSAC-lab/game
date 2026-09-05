class_name M5Artifact
extends RefCounted

const PRIORITY: Dictionary = {"M5_INVALID_WORLD_TYPE": 0, "M5_UNSUPPORTED_SCHEMA": 10, "M5_FIELD_CONTRACT": 20,
	"M5_RULESET_MISMATCH": 30, "M5_WORLD_NOT_PUBLISHABLE": 40, "M5_STALE_DAY": 50, "M5_STALE_REVISION": 51,
	"M5_STALE_STATE_HASH": 52, "M5_ACTIONS_CLOSED": 60, "M5_CONTACT_ALREADY_PROCESSED": 61, "M5_CONTACT_REQUIRED": 62,
	"M5_REQUEST_CONTRACT": 70, "M5_M4_REJECTED": 80, "M5_ARTIFACT_BINDING": 90, "M5_OBSERVATION_CONTRACT": 91,
	"M5_ARITHMETIC_OVERFLOW": 100, "M5_POST_APPLY_INVARIANT": 110}


static func begin(kind: String) -> Dictionary:
	return {"algorithm_id": "m5-operation-artifact-v2", "operation_kind": kind, "operation_id": "", "status": "REJECTED",
		"input_state_hash": "", "intermediate_state_hash": "", "output_state_hash": "", "input_day_index": -1, "output_day_index": -1,
		"input_social_revision": -1, "output_social_revision": -1, "m4_batch_artifact_hash": "", "errors": [],
		"observation_changes": [], "effect_applications": [], "field_changes": [], "maintenance_changes": [], "defaulted_inputs": [], "state_metrics": {}}


static func select(issues: Array[Dictionary]) -> Dictionary:
	var ordered: Array[Dictionary] = issues.duplicate()
	ordered.sort_custom(_issue_less)
	return ordered[0]


static func _issue_less(a: Dictionary, b: Dictionary) -> bool:
	if PRIORITY[a.code] != PRIORITY[b.code]:
		return PRIORITY[a.code] < PRIORITY[b.code]
	for key: String in ["field_path", "entity_id", "cause_code"]:
		if a[key] != b[key]:
			return a[key] < b[key]
	return false


static func failure(artifact: Dictionary, issue: Dictionary) -> M5OperationResult:
	var result: M5OperationResult = M5OperationResult.new()
	var data: Dictionary = artifact.duplicate(true)
	data.status = "REJECTED"
	data.output_state_hash = ""
	data.output_day_index = -1
	data.output_social_revision = -1
	data.state_metrics = {}
	for key: String in ["observation_changes", "effect_applications", "field_changes", "maintenance_changes", "defaulted_inputs"]:
		data[key] = []
	data.errors = [M5Data.identified("errors", issue)]
	result.artifact = finish(data)
	return result


static func finish(data: Dictionary) -> Dictionary:
	data.erase("artifact_hash")
	data["artifact_hash"] = StateHasher.hash_data(data)
	return StateCanonicalizer.canonicalize(data)


static func identity(kind: String, stamp: M5RequestStamp, request: Variant) -> String:
	return StateHasher.hash_data({"algorithm_id": "m5-operation-id-v2", "operation_kind": kind, "stamp": stamp.to_data(), "request_identity": request})


static func execute_identity(submissions: Array) -> Array:
	var identity: Array = []
	for submission: DecisionSubmission in submissions:
		var fields: Dictionary = {"actor_person_id": submission.decision_request.actor_person_id,
			"decision_key": submission.decision_request.decision_key, "submitted_decision_hash": DecisionArtifactCodec.hash_result(submission.submitted_decision_result)}
		var preimage: Dictionary = fields.duplicate(true)
		preimage["algorithm_id"] = "m5-execute-submission-id-v1"
		fields["id"] = StateHasher.hash_data(preimage)
		identity.append(fields)
	return StateCanonicalizer.canonicalize(identity)


static func metrics(world: WorldState) -> Dictionary:
	var result: Dictionary = {"persons": world.persons.size(), "events": world.events.size(), "traces": world.traces.size(),
		"observations": world.social_observations.size(), "effect_receipts": world.social_effect_receipts.size(),
		"memories_recent": 0, "memories_important": 0, "memories_core": 0, "relations": world.relations.size(),
		"trait_pressures": world.trait_pressures.size(), "repeat_exposures": world.repeat_exposures.size(),
		"canonical_state_bytes": StateCanonicalizer.canonical_json(StateHasher.state_payload(world)).to_utf8_buffer().size()}
	for memory: MemoryState in world.memories:
		result["memories_" + memory.tier] += 1
	return result
