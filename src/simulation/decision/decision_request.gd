class_name DecisionRequest
extends RefCounted

var actor_person_id: String = ""
var decision_key: String = ""


static func create(actor_id: String, key: String) -> DecisionRequest:
	var request: DecisionRequest = DecisionRequest.new()
	request.actor_person_id = actor_id
	request.decision_key = key
	return request


func to_data() -> Dictionary:
	return {
		"actor_person_id": actor_person_id,
		"decision_key": decision_key,
	}
