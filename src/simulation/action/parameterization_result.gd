class_name ParameterizationResult
extends RefCounted

var ok: bool = false
var errors: Array[String] = []
var intent: ActionIntent = null
var failure_action_instance_id: String = ""


static func success(value: ActionIntent) -> ParameterizationResult:
	var result: ParameterizationResult = ParameterizationResult.new()
	result.ok = true
	result.intent = value
	return result


static func failure(reason_id: String, action_instance_id: String = "") -> ParameterizationResult:
	var result: ParameterizationResult = ParameterizationResult.new()
	result.errors = [reason_id]
	result.failure_action_instance_id = action_instance_id
	return result


func to_data() -> Dictionary:
	return {
		"ok": ok,
		"errors": errors.duplicate(),
		"intent": intent.to_data() if intent != null else null,
	}
