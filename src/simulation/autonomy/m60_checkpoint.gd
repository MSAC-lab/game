class_name M60Checkpoint
extends RefCounted

const KEYS: Array[String] = ["algorithm_id", "boundary_kind", "config", "config_hash", "initial_state_hash",
	"world_save", "days", "checkpoint_hash"]


static func boundary_error(world: Variant) -> String:
	if not world is WorldState or world.schema_version != 5 or not M5StateValidator.typed_safe(world):
		return "world"
	if not StateValidator.validate_world(world).is_empty():
		return "world.validation"
	var d: int = world.day_index
	if world.day_phase != WorldState.DAY_END_PHASE:
		return "world.day_phase"
	if world.social_state.last_closed_day_index != d - 1:
		return "world.social_state.last_closed_day_index"
	if world.social_state.last_contact_day_index != d - 1:
		return "world.social_state.last_contact_day_index"
	if not world.resolved_decision_slot_ids.is_empty():
		return "world.resolved_decision_slot_ids"
	if world.social_state.last_integrated_resolution_epoch != world.resolution_epoch:
		return "world.social_state.last_integrated_resolution_epoch"
	return ""


static func encode(initial_hash: String, config: Dictionary, world: WorldState, days: Array) -> Dictionary:
	var boundary: String = boundary_error(world)
	if not boundary.is_empty():
		return {"ok": false, "json_text": "", "error": boundary}
	# M5 optional audit history stays in the outer day ledger, without intermediate worlds.
	var saved: Dictionary = M5SaveCodec.encode_checked(world)
	if not saved.ok:
		return {"ok": false, "json_text": "", "error": "world_save"}
	var parsed: Dictionary = M5JsonReader.parse(saved.json_text)
	var envelope: Dictionary = {"algorithm_id": "m60-checkpoint-v1", "boundary_kind": "INITIAL" if days.is_empty() else "DAY_BOUNDARY",
		"config": config.duplicate(true), "config_hash": StateHasher.hash_data(config), "initial_state_hash": initial_hash,
		"world_save": parsed.value, "days": days.duplicate(true)}
	envelope.checkpoint_hash = StateHasher.hash_data(envelope)
	return {"ok": true, "json_text": StateCanonicalizer.canonical_json(envelope), "error": ""}


static func decode(text: String, initial: WorldState, expected_config: Dictionary) -> Dictionary:
	var parsed: Dictionary = M5JsonReader.parse(text)
	if not parsed.ok or not M5Data.exact(parsed.value, KEYS):
		return _failure("checkpoint.shape")
	var envelope: Dictionary = parsed.value
	if envelope.algorithm_id != "m60-checkpoint-v1" or not M5Data.json_value(envelope):
		return _failure("checkpoint.version")
	var payload: Dictionary = envelope.duplicate(true)
	payload.erase("checkpoint_hash")
	if envelope.checkpoint_hash != StateHasher.hash_data(payload):
		return _failure("checkpoint.checkpoint_hash")
	if envelope.initial_state_hash != StateHasher.hash_world(initial) or envelope.config_hash != StateHasher.hash_data(expected_config):
		return _failure("checkpoint.expected_input")
	if typeof(envelope.config) != TYPE_DICTIONARY or envelope.config_hash != StateHasher.hash_data(envelope.config):
		return _failure("checkpoint.config_hash")
	if typeof(envelope.world_save) != TYPE_DICTIONARY or typeof(envelope.days) != TYPE_ARRAY:
		return _failure("checkpoint.world_save")
	var loaded: Dictionary = M5SaveCodec.decode_checked(StateCanonicalizer.canonical_json(envelope.world_save))
	if not loaded.ok:
		return _failure("checkpoint.world_save")
	var world: WorldState = loaded.world
	var error: String = boundary_error(world)
	if not error.is_empty():
		return _failure(error)
	error = M60Config.validate(envelope.config, world)
	if not error.is_empty():
		return _failure(error)
	if world.rng_seed_hex != initial.rng_seed_hex or world.scenario_id != initial.scenario_id:
		return _failure("checkpoint.world_identity")
	var expected_day: int = initial.day_index
	var expected_hash: String = StateHasher.hash_world(initial)
	var previous_revision: int = initial.social_state.revision
	var resources: Array = []
	var audits: Array = []
	var expected_actors: Array[String] = M60Config.actors(expected_config, initial)
	var expected_contacts: String = StateCanonicalizer.canonical_json(M60Config.contact_plan(expected_config, initial).to_data())
	for record: Variant in envelope.days:
		error = M60Evidence.validate_committed_day(record, expected_day, expected_hash)
		if not error.is_empty():
			return _failure(error)
		if record.operations[0].artifact.input_social_revision != previous_revision:
			return _failure("checkpoint.revision_chain")
		var actual_actors: Array[String] = []
		for decision: Dictionary in record.decisions:
			actual_actors.append(decision.actor_person_id)
		actual_actors.sort()
		if actual_actors != expected_actors or StateCanonicalizer.canonical_json(record.contact_plan) != expected_contacts:
			return _failure("checkpoint.config_history")
		for op: Dictionary in record.operations:
			resources.append_array(op.resource_transactions)
			audits.append(op.artifact)
		previous_revision = record.operations[-1].artifact.output_social_revision
		expected_day += 1
		expected_hash = record.output_state_hash
	if world.day_index != expected_day or StateHasher.hash_world(world) != expected_hash or world.social_state.revision != previous_revision:
		return _failure("checkpoint.completed_boundary")
	if envelope.boundary_kind != ("INITIAL" if envelope.days.is_empty() else "DAY_BOUNDARY"):
		return _failure("checkpoint.boundary_kind")
	# Validate resource shape, IDs, references, duplicate consumption and sequence bounds
	# using the existing Schema 5 audit contract; do not replay decisions to reconstruct evidence.
	if not M5SaveCodec._validate_audits({"audit": [], "resource_audit": resources, "social_audit": audits}, world).is_empty():
		return _failure("checkpoint.audit_history")
	return {"ok": true, "world": world, "days": envelope.days.duplicate(true), "error": ""}


static func _failure(path: String) -> Dictionary:
	return {"ok": false, "world": null, "days": [], "error": path}
