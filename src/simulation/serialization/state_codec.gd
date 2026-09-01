class_name StateCodec
extends RefCounted


static func encode(world: WorldState, audit_records: Array[DecisionRecord]) -> String:
	var audit_data: Array = []
	for record: DecisionRecord in audit_records:
		audit_data.append(record.to_data())
	var envelope: Dictionary = StateHasher.state_payload(world)
	envelope["audit"] = audit_data
	envelope["state_hash"] = StateHasher.hash_world(world)
	return StateCanonicalizer.pretty_json(envelope)


static func decode(json_text: String) -> Dictionary:
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(json_text)
	if parse_error != OK:
		return _failure(["JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()]])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _failure(["save root must be a dictionary"])

	var envelope: Dictionary = json.data
	var errors: Array[String] = StateValidator.validate_envelope(envelope)
	if typeof(envelope.get("audit")) != TYPE_ARRAY:
		errors.append("audit must be an array")
	if typeof(envelope.get("state_hash")) != TYPE_STRING or len(str(envelope.get("state_hash"))) != 64:
		errors.append("state_hash must be a 64-character hexadecimal string")
	if not errors.is_empty():
		return _failure(errors)

	var world: WorldState = WorldState.from_data(envelope, envelope.get("state"))
	var actual_hash: String = StateHasher.hash_world(world)
	var stored_hash: String = str(envelope.get("state_hash", ""))
	if actual_hash != stored_hash:
		return _failure(["state_hash mismatch: expected %s, computed %s" % [stored_hash, actual_hash]])

	var audit_records: Array[DecisionRecord] = []
	var audit_data: Array = envelope.get("audit")
	for item: Variant in audit_data:
		if typeof(item) != TYPE_DICTIONARY:
			return _failure(["audit item must be a dictionary"])
		var record_data: Dictionary = item
		var audit_error: String = _validate_audit_record(record_data)
		if not audit_error.is_empty():
			return _failure([audit_error])
		audit_records.append(DecisionRecord.from_data(record_data))
	return {
		"ok": true,
		"errors": [] as Array[String],
		"world": world,
		"audit": audit_records,
	}


static func _failure(errors: Array[String]) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"world": null,
		"audit": [] as Array[DecisionRecord],
	}


static func _validate_audit_record(data: Dictionary) -> String:
	for key: String in ["id", "actor_person_id", "selected_intent", "selected_action_id", "result_event_id"]:
		if typeof(data.get(key)) != TYPE_STRING:
			return "audit.%s must be a string" % key
	if not StateValidator._is_integer(data.get("day_index")):
		return "audit.day_index must be an integer"
	for key: String in ["candidate_action_ids", "evaluation_reasons"]:
		if typeof(data.get(key)) != TYPE_ARRAY:
			return "audit.%s must be an array" % key
		var values: Array = data.get(key)
		for item: Variant in values:
			if typeof(item) != TYPE_STRING:
				return "audit.%s contains a non-string value" % key
	for key: String in ["unavailable_reasons", "change_pressure"]:
		if typeof(data.get(key)) != TYPE_DICTIONARY:
			return "audit.%s must be a dictionary" % key
	return ""
