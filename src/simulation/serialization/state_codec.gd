class_name StateCodec
extends RefCounted


static func encode(
	world: WorldState,
	audit_records: Array[DecisionRecord],
	resource_records: Array[ResourceTransactionRecord] = []
) -> String:
	var audit_data: Array = []
	for record: DecisionRecord in audit_records:
		audit_data.append(record.to_data())
	var envelope: Dictionary = StateHasher.state_payload(world)
	envelope["audit"] = audit_data
	if world.schema_version in [WorldState.SCHEMA_VERSION_M2, WorldState.SCHEMA_VERSION_M3]:
		var resource_audit_data: Array = []
		for record: ResourceTransactionRecord in resource_records:
			resource_audit_data.append(record.to_data())
		envelope["resource_audit"] = resource_audit_data
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
	var schema_version: int = int(envelope.get("schema_version", 0))
	if schema_version in [WorldState.SCHEMA_VERSION_M2, WorldState.SCHEMA_VERSION_M3]:
		if typeof(envelope.get("resource_audit")) != TYPE_ARRAY:
			errors.append("resource_audit must be an array for schema 2 or 3")
	elif schema_version == WorldState.SCHEMA_VERSION_M1 and envelope.has("resource_audit"):
		errors.append("schema 1 envelope forbids resource_audit")
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

	var resource_records: Array[ResourceTransactionRecord] = []
	if schema_version in [WorldState.SCHEMA_VERSION_M2, WorldState.SCHEMA_VERSION_M3]:
		var resource_audit_data: Array = envelope.get("resource_audit")
		var transaction_ids: Dictionary = {}
		var consumer_days: Dictionary = {}
		var sequence_keys: Dictionary = {}
		for item: Variant in resource_audit_data:
			if typeof(item) != TYPE_DICTIONARY:
				return _failure(["resource_audit item must be a dictionary"])
			var record_data: Dictionary = item
			var resource_error: String = _validate_resource_audit_record(
				record_data, world, transaction_ids, consumer_days, sequence_keys
			)
			if not resource_error.is_empty():
				return _failure([resource_error])
			resource_records.append(ResourceTransactionRecord.from_data(record_data))
	return {
		"ok": true,
		"errors": [] as Array[String],
		"world": world,
		"audit": audit_records,
		"resource_audit": resource_records,
	}


static func _failure(errors: Array[String]) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"world": null,
		"audit": [] as Array[DecisionRecord],
		"resource_audit": [] as Array[ResourceTransactionRecord],
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


static func _validate_resource_audit_record(
	data: Dictionary,
	world: WorldState,
	transaction_ids: Dictionary,
	consumer_days: Dictionary,
	sequence_keys: Dictionary
) -> String:
	for key: String in [
		"id",
		"resource_type_id",
		"source_store_id",
		"destination_store_id",
		"consumer_person_id",
		"reason_id",
	]:
		if typeof(data.get(key)) != TYPE_STRING:
			return "resource_audit.%s must be a string" % key
	for key: String in ["day_index", "sequence_index", "quantity"]:
		if not StateValidator._is_integer(data.get(key)):
			return "resource_audit.%s must be an integer" % key
	var id: String = str(data.get("id", ""))
	if id.is_empty() or transaction_ids.has(id):
		return "resource_audit has empty or duplicate transaction ID: %s" % id
	transaction_ids[id] = true
	if int(data.get("quantity")) <= 0 or int(data.get("quantity")) > 2147483647:
		return "resource_audit quantity must be from 1 to 2147483647"
	if int(data.get("day_index")) < 0 or int(data.get("sequence_index")) < 0:
		return "resource_audit day and sequence must be non-negative"
	if str(data.get("resource_type_id")) != "food":
		return "resource_audit resource_type_id must be food"
	if str(data.get("reason_id")).is_empty():
		return "resource_audit reason_id must not be empty"
	var sequence_key: String = "%d:%d" % [
		int(data.get("day_index")), int(data.get("sequence_index"))
	]
	if sequence_keys.has(sequence_key):
		return "resource_audit has duplicate day and sequence index: %s" % sequence_key
	sequence_keys[sequence_key] = true
	var source_id: String = str(data.get("source_store_id"))
	var destination_id: String = str(data.get("destination_store_id"))
	var consumer_id: String = str(data.get("consumer_person_id"))
	if world.find_resource_store(source_id) == null:
		return "resource_audit source store is missing: %s" % source_id
	var is_transfer: bool = not destination_id.is_empty()
	var is_consumption: bool = not consumer_id.is_empty()
	if is_transfer == is_consumption:
		return "resource_audit must have exactly one destination or consumer"
	if is_transfer:
		if destination_id == source_id:
			return "resource_audit source and destination must differ"
		if world.find_resource_store(destination_id) == null:
			return "resource_audit destination store is missing: %s" % destination_id
	else:
		if world.find_person(consumer_id) == null:
			return "resource_audit consumer is missing: %s" % consumer_id
		var consumer_key: String = "%d:%s" % [int(data.get("day_index")), consumer_id]
		if consumer_days.has(consumer_key):
			return "resource_audit consumes for one person more than once per day"
		consumer_days[consumer_key] = true
	return ""
