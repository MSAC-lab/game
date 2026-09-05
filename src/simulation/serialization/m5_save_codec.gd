class_name M5SaveCodec
extends RefCounted


static func encode_checked(world: WorldState, audit: Array = [], resource_audit: Array = [], social_audit: Array = []) -> Dictionary:
	if world == null or world.schema_version != 5 or not M5StateValidator.typed_safe(world):
		return {"ok": false, "json_text": "", "errors": ["invalid Schema 5 world"]}
	var errors: Array[String] = StateValidator.validate_world(world)
	if not errors.is_empty():
		return {"ok": false, "json_text": "", "errors": errors}
	var envelope: Dictionary = StateHasher.state_payload(world)
	envelope.audit = _records(audit)
	envelope.resource_audit = _records(resource_audit)
	envelope.social_audit = _records(social_audit)
	envelope.state_hash = StateHasher.hash_world(world)
	errors = _validate_audits(envelope, world)
	if not errors.is_empty():
		return {"ok": false, "json_text": "", "errors": errors}
	return {"ok": true, "json_text": StateCanonicalizer.canonical_json(envelope), "errors": []}


static func decode_checked(json_text: String) -> Dictionary:
	var parsed: Dictionary = M5JsonReader.parse(json_text)
	if not parsed.ok or typeof(parsed.value) != TYPE_DICTIONARY:
		return _failure([parsed.error if not parsed.ok else "save root must be an object"])
	var envelope: Dictionary = parsed.value
	if not M5Data.exact(envelope, M5Data.keys("save")) or envelope.schema_version != 5:
		return _failure(["invalid Schema 5 save keyset"])
	var errors: Array[String] = M5StateValidator.validate_payload(envelope)
	if not errors.is_empty():
		return _failure(errors)
	var world: WorldState = WorldState.from_data(envelope, envelope.state)
	if typeof(envelope.state_hash) != TYPE_STRING or envelope.state_hash != StateHasher.hash_world(world):
		return _failure(["state_hash mismatch"])
	errors = _validate_audits(envelope, world)
	if not errors.is_empty():
		return _failure(errors)
	var audit: Array[DecisionRecord] = []
	var resources: Array[ResourceTransactionRecord] = []
	for record: Dictionary in envelope.audit:
		audit.append(DecisionRecord.from_data(record))
	for record: Dictionary in envelope.resource_audit:
		resources.append(ResourceTransactionRecord.from_data(record))
	return {"ok": true, "world": world, "audit": audit, "resource_audit": resources, "social_audit": envelope.social_audit, "errors": []}


static func _records(records: Array) -> Array:
	var result: Array = []
	for record: Variant in records:
		if typeof(record) == TYPE_DICTIONARY:
			result.append(record.duplicate(true))
		elif record is RefCounted and record.has_method("to_data"):
			result.append(record.to_data())
		else:
			result.append(null)
	return result


static func _validate_audits(envelope: Dictionary, world: WorldState) -> Array[String]:
	for key: String in ["audit", "resource_audit", "social_audit"]:
		if typeof(envelope[key]) != TYPE_ARRAY or not M5Data.json_value(envelope[key]):
			return [key + " must be an array of JSON records"]
		for record: Variant in envelope[key]:
			if typeof(record) != TYPE_DICTIONARY:
				return [key + " record must be an object"]
	var decision_ids: Dictionary = {}
	for record: Dictionary in envelope.audit:
		var error: String = StateCodec._validate_audit_record(record)
		if not error.is_empty():
			return [error]
		if decision_ids.has(record.id):
			return ["duplicate decision audit ID"]
		decision_ids[record.id] = true
	var ids: Dictionary = {}
	var days: Dictionary = {}
	var sequences: Dictionary = {}
	for record: Dictionary in envelope.resource_audit:
		var error: String = StateCodec._validate_resource_audit_record(record, world, ids, days, sequences)
		if not error.is_empty():
			return [error]
		if record.sequence_index >= world.next_resource_sequence_index:
			return ["resource audit sequence must precede next sequence"]
		if not str(record.consumer_person_id).is_empty():
			var suffix: String = str(record.id).trim_prefix("resource_transaction:")
			if not str(record.id).begins_with("resource_transaction:") or not suffix.is_valid_int() or suffix.to_int() < 1 or suffix.to_int() >= int(world.next_ids.resource_transaction):
				return ["resource audit ID must precede next resource ID"]
	for record: Dictionary in envelope.social_audit:
		var error: String = M5AuditValidator.validate(record)
		if not error.is_empty():
			return [error]
	return []


static func _failure(errors: Array) -> Dictionary:
	return {"ok": false, "world": null, "audit": [], "resource_audit": [], "social_audit": [], "errors": errors}
