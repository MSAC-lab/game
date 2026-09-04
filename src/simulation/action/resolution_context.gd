class_name ResolutionContext
extends RefCounted

var context_id: String = ""
var issuer_id: String = ""
var action_instance_id: String = ""
var input_state_hash: String = ""
var resolution_epoch: int = 0
var day_index: int = 0
var phase_id: String = ""
var present_person_ids: Array[String] = []
var present_store_ids: Array[String] = []


static func from_data(data: Dictionary) -> ResolutionContext:
	var context: ResolutionContext = ResolutionContext.new()
	context.context_id = str(data.get("context_id", ""))
	context.issuer_id = str(data.get("issuer_id", ""))
	context.action_instance_id = str(data.get("action_instance_id", ""))
	context.input_state_hash = str(data.get("input_state_hash", ""))
	context.resolution_epoch = int(data.get("resolution_epoch", 0))
	context.day_index = int(data.get("day_index", 0))
	context.phase_id = str(data.get("phase_id", ""))
	context.present_person_ids = ModelData.copy_string_array(data.get("present_person_ids", []))
	context.present_store_ids = ModelData.copy_string_array(data.get("present_store_ids", []))
	return context


func to_data_without_context_id() -> Dictionary:
	return {
		"issuer_id": issuer_id,
		"action_instance_id": action_instance_id,
		"input_state_hash": input_state_hash,
		"resolution_epoch": resolution_epoch,
		"day_index": day_index,
		"phase_id": phase_id,
		"present_person_ids": present_person_ids.duplicate(),
		"present_store_ids": present_store_ids.duplicate(),
	}


func to_data() -> Dictionary:
	var data: Dictionary = to_data_without_context_id()
	data["context_id"] = context_id
	return data


func compute_context_id() -> String:
	var payload: Dictionary = {"algorithm_id": "m4-resolution-context-v1"}
	for key: Variant in to_data_without_context_id().keys():
		payload[key] = to_data_without_context_id()[key]
	return StateHasher.hash_data(payload)
