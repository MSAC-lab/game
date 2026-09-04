class_name ActionIntent
extends RefCounted

var action_instance_id: String = ""
var decision_instance_key: DecisionInstanceKey = null
var decision_slot_id: String = ""
var input_resolution_epoch: int = 0
var actor_person_id: String = ""
var action_id: String = ""
var source_decision_hash: String = ""
var source_decision_input_state_hash: String = ""
var source_decision_ruleset_hash: String = ""
var source_selected_candidate_id: String = ""
var parameterization_ruleset_hash: String = ""
var parameterization_input_fact_ids: Array[String] = []
var target_person_id: String = ""
var requested_resource_type_id: String = ""
var requested_units: int = 0
var recipient_store_id: String = ""
var target_store_id: String = ""
var desired_units: int = 0
var intent_hash: String = ""


static func from_data(data: Dictionary) -> ActionIntent:
	var intent: ActionIntent = ActionIntent.new()
	intent.action_instance_id = str(data.get("action_instance_id", ""))
	var key_value: Variant = data.get("decision_instance_key")
	if typeof(key_value) == TYPE_DICTIONARY:
		intent.decision_instance_key = DecisionInstanceKey.from_data(key_value)
	intent.decision_slot_id = str(data.get("decision_slot_id", ""))
	intent.input_resolution_epoch = int(data.get("input_resolution_epoch", 0))
	intent.actor_person_id = str(data.get("actor_person_id", ""))
	intent.action_id = str(data.get("action_id", ""))
	intent.source_decision_hash = str(data.get("source_decision_hash", ""))
	intent.source_decision_input_state_hash = str(
		data.get("source_decision_input_state_hash", "")
	)
	intent.source_decision_ruleset_hash = str(data.get("source_decision_ruleset_hash", ""))
	intent.source_selected_candidate_id = str(data.get("source_selected_candidate_id", ""))
	intent.parameterization_ruleset_hash = str(data.get("parameterization_ruleset_hash", ""))
	intent.parameterization_input_fact_ids = ModelData.copy_string_array(
		data.get("parameterization_input_fact_ids", [])
	)
	intent.target_person_id = str(data.get("target_person_id", ""))
	intent.requested_resource_type_id = str(data.get("requested_resource_type_id", ""))
	intent.requested_units = int(data.get("requested_units", 0))
	intent.recipient_store_id = str(data.get("recipient_store_id", ""))
	intent.target_store_id = str(data.get("target_store_id", ""))
	intent.desired_units = int(data.get("desired_units", 0))
	intent.intent_hash = str(data.get("intent_hash", ""))
	return intent


func to_data_without_intent_hash() -> Dictionary:
	var data: Dictionary = {
		"action_instance_id": action_instance_id,
		"decision_instance_key": (
			decision_instance_key.to_data() if decision_instance_key != null else {}
		),
		"decision_slot_id": decision_slot_id,
		"input_resolution_epoch": input_resolution_epoch,
		"actor_person_id": actor_person_id,
		"action_id": action_id,
		"source_decision_hash": source_decision_hash,
		"source_decision_input_state_hash": source_decision_input_state_hash,
		"source_decision_ruleset_hash": source_decision_ruleset_hash,
		"source_selected_candidate_id": source_selected_candidate_id,
		"parameterization_ruleset_hash": parameterization_ruleset_hash,
		"parameterization_input_fact_ids": parameterization_input_fact_ids.duplicate(),
	}
	if action_id == "A04":
		data["target_person_id"] = target_person_id
		data["requested_resource_type_id"] = requested_resource_type_id
		data["requested_units"] = requested_units
		data["recipient_store_id"] = recipient_store_id
	elif action_id == "A11":
		data["target_store_id"] = target_store_id
		data["desired_units"] = desired_units
		data["recipient_store_id"] = recipient_store_id
	return data


func to_data() -> Dictionary:
	var data: Dictionary = to_data_without_intent_hash()
	data["intent_hash"] = intent_hash
	return data


func compute_intent_hash() -> String:
	return StateHasher.hash_data({
		"algorithm_id": "m4-action-intent-v1",
		"action_intent": to_data_without_intent_hash(),
	})


func compute_action_instance_id() -> String:
	return StateHasher.hash_data({
		"algorithm_id": "m4-action-instance-v1",
		"decision_slot_id": decision_slot_id,
		"parameterization_ruleset_hash": parameterization_ruleset_hash,
		"selected_candidate_id": source_selected_candidate_id,
	})
