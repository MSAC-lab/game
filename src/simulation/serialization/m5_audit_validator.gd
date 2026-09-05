class_name M5AuditValidator
extends RefCounted
## Audit is optional history, but supplied records still obey the exact wire contract.

const ROW_KEYS: Dictionary = {
	"errors": ["id", "code", "field_path", "entity_id", "cause_code"],
	"observation_changes": ["id", "observation_id", "operation", "before_hash", "after_hash", "selected_source_person_id", "received_report_count"],
	"effect_applications": ["id", "receipt_id", "observation_id", "rule_id", "relation_deltas", "emotion_deltas", "pressure_delta", "belief_change", "experience_context"],
	"field_changes": ["id", "owner_person_id", "target_id", "field_path", "before_value", "requested_delta", "after_value", "applied_delta"],
	"maintenance_changes": ["id", "owner_person_id", "kind", "target_id", "before_value", "after_value"],
}
const METRICS: Array[String] = ["persons", "events", "traces", "observations", "effect_receipts", "memories_recent", "memories_important", "memories_core", "relations", "trait_pressures", "repeat_exposures", "canonical_state_bytes"]


static func validate(record: Dictionary) -> String:
	if not M5Data.exact(record, M5Data.keys("operation_artifact")) or not M5Data.json_value(record):
		return "social audit exact keyset violation"
	for key: String in ["algorithm_id", "operation_kind", "status", "artifact_hash", "operation_id", "input_state_hash", "intermediate_state_hash", "output_state_hash", "m4_batch_artifact_hash"]:
		if typeof(record[key]) != TYPE_STRING:
			return "social audit field type violation"
	for key: String in ["artifact_hash", "operation_id", "input_state_hash", "intermediate_state_hash", "output_state_hash", "m4_batch_artifact_hash"]:
		if not record[key].is_empty() and not M5StateValidator._hash(record[key]):
			return "social audit invalid hash"
	for key: String in ["input_day_index", "output_day_index", "input_social_revision", "output_social_revision"]:
		if typeof(record[key]) != TYPE_INT or record[key] < -1:
			return "social audit invalid clock"
	if record.algorithm_id != "m5-operation-artifact-v2" or record.status not in ["COMMITTED", "REJECTED"] or record.operation_kind not in ["EXECUTE", "CONTACTS", "CLOSE"]:
		return "social audit invalid identity"
	var preimage: Dictionary = record.duplicate(true)
	preimage.erase("artifact_hash")
	if StateHasher.hash_data(preimage) != record.artifact_hash:
		return "social audit hash mismatch"
	for name: String in ROW_KEYS:
		if typeof(record[name]) != TYPE_ARRAY:
			return "social audit rows must be arrays"
		var ids: Dictionary = {}
		for row: Variant in record[name]:
			if not M5Data.exact(row, ROW_KEYS[name]) or typeof(row.id) != TYPE_STRING:
				return "social audit row exact keyset violation"
			var fields: Dictionary = row.duplicate(true)
			fields.erase("id")
			if row.id != name + ":" + StateHasher.hash_data(fields) or ids.has(row.id) or not _row_valid(name, row):
				return "social audit invalid row"
			ids[row.id] = true
	if typeof(record.defaulted_inputs) != TYPE_ARRAY:
		return "social audit invalid default paths"
	for path: Variant in record.defaulted_inputs:
		if typeof(path) != TYPE_STRING:
			return "social audit invalid default path"
	if typeof(record.state_metrics) != TYPE_DICTIONARY:
		return "social audit invalid metrics"
	if record.operation_kind != "EXECUTE" and not record.m4_batch_artifact_hash.is_empty():
		return "social audit unexpected M4 hash"
	if record.operation_kind == "CONTACTS" and not record.intermediate_state_hash.is_empty():
		return "social audit unexpected stage hash"
	if record.status == "REJECTED":
		if not record.output_state_hash.is_empty() or record.output_day_index != -1 or record.output_social_revision != -1 or not record.state_metrics.is_empty() or record.errors.size() != 1:
			return "social audit rejected output must be empty"
		for name: String in ["observation_changes", "effect_applications", "field_changes", "maintenance_changes", "defaulted_inputs"]:
			if not record[name].is_empty():
				return "social audit rejected changes must be empty"
		if record.input_state_hash.is_empty() and (record.input_day_index != -1 or record.input_social_revision != -1 or not record.operation_id.is_empty() or not record.intermediate_state_hash.is_empty() or not record.m4_batch_artifact_hash.is_empty()):
			return "social audit invalid input checkpoint"
	else:
		if not record.errors.is_empty() or record.operation_id.is_empty() or record.input_state_hash.is_empty() or record.output_state_hash.is_empty() or record.input_day_index < 0 or record.input_social_revision < 0 or record.output_social_revision != record.input_social_revision + 1:
			return "social audit invalid commit"
		if record.output_day_index != record.input_day_index + (1 if record.operation_kind == "CLOSE" else 0):
			return "social audit invalid committed day"
		if record.operation_kind in ["EXECUTE", "CLOSE"] and record.intermediate_state_hash.is_empty():
			return "social audit missing stage hash"
		if record.operation_kind == "EXECUTE" and record.m4_batch_artifact_hash.is_empty():
			return "social audit missing M4 hash"
		if not M5Data.exact(record.state_metrics, METRICS) or not _integers(record.state_metrics):
			return "social audit invalid metrics"
		for value: int in record.state_metrics.values():
			if value < 0:
				return "social audit negative metric"
	return ""


static func _row_valid(name: String, row: Dictionary) -> bool:
	match name:
		"errors":
			return _strings(row) and M5Artifact.PRIORITY.has(row.code) and (row.code == "M5_M4_REJECTED" or row.cause_code.is_empty())
		"observation_changes":
			return _strings(row, ["received_report_count"]) and typeof(row.received_report_count) == TYPE_INT and row.received_report_count >= 1 and row.operation in ["CREATE", "UPDATE", "KEEP_CONFLICT", "KEEP_DUPLICATE"] and (row.before_hash.is_empty() or M5StateValidator._hash(row.before_hash)) and M5StateValidator._hash(row.after_hash)
		"field_changes":
			return _strings(row, ["before_value", "after_value", "requested_delta", "applied_delta"]) and _integer_fields(row, ["before_value", "after_value", "requested_delta", "applied_delta"]) and row.applied_delta == row.after_value - row.before_value
		"maintenance_changes":
			if not _strings(row, ["before_value", "after_value"]) or typeof(row.before_value) != typeof(row.after_value):
				return false
			match row.kind:
				"EMOTION_DECAY", "WEEKLY_TRAIT", "PRESSURE_REMAINDER":
					return typeof(row.before_value) == TYPE_INT
				"MEMORY_TIER", "MEMORY_COMPRESS":
					return typeof(row.before_value) == TYPE_STRING
				"REPEAT_PRUNE":
					if typeof(row.before_value) != TYPE_ARRAY:
						return false
					for value: Variant in row.before_value + row.after_value:
						if typeof(value) != TYPE_INT:
							return false
					return true
		"effect_applications":
			return _effect_valid(row)
	return false


static func _effect_valid(row: Dictionary) -> bool:
	if not _strings(row, ["relation_deltas", "emotion_deltas", "pressure_delta", "belief_change", "experience_context"]) or typeof(row.relation_deltas) != TYPE_ARRAY:
		return false
	for relation: Variant in row.relation_deltas:
		if not M5Data.exact(relation, ["target_person_id", "trust", "affection", "fear", "resentment", "obligation"]) or typeof(relation.target_person_id) != TYPE_STRING or not _integer_fields(relation, M5Data.RELATION_FIELDS):
			return false
	if not M5Data.exact(row.emotion_deltas, ["anger", "fear", "guilt"]) or not _integers(row.emotion_deltas):
		return false
	if not M5Data.exact(row.pressure_delta, ["trait_id", "raw_magnitude", "sign", "repeat_prior_count", "applied_pressure"]):
		return false
	if row.pressure_delta.trait_id not in ["", "norm_adherence"] or not _integer_fields(row.pressure_delta, ["raw_magnitude", "sign", "repeat_prior_count", "applied_pressure"]):
		return false
	if typeof(row.belief_change) != TYPE_DICTIONARY or typeof(row.experience_context) != TYPE_DICTIONARY:
		return false
	if not row.belief_change.is_empty():
		if not M5Data.exact(row.belief_change, ["information_id", "old_belief", "new_belief", "old_confidence", "new_confidence", "sample"]) or typeof(row.belief_change.information_id) != TYPE_STRING or not _integer_fields(row.belief_change, ["old_belief", "new_belief", "old_confidence", "new_confidence", "sample"]):
			return false
	if not row.experience_context.is_empty():
		var context: Dictionary = row.experience_context
		if not M5Data.exact(context, M5Data.keys("experience_context")) or not _integer_fields(context, ["C", "K", "N", "family_protection", "norm_adherence"]):
			return false
		if typeof(context.voluntary) != TYPE_BOOL or not _strings(context, ["C", "K", "N", "family_protection", "norm_adherence", "voluntary"]):
			return false
	return true


static func _strings(value: Dictionary, except_keys: Array = []) -> bool:
	for key: String in value:
		if key not in except_keys and typeof(value[key]) != TYPE_STRING:
			return false
	return true


static func _integers(value: Dictionary) -> bool:
	return _integer_fields(value, value.keys())


static func _integer_fields(value: Dictionary, keys: Array) -> bool:
	for key: String in keys:
		if typeof(value[key]) != TYPE_INT:
			return false
	return true
