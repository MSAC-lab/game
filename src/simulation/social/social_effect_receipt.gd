class_name SocialEffectReceipt
extends RefCounted

var applied_day_index: int = 0
var applied_observation_id: String = ""
var applied_payload_hash: String = ""
var applied_revision: int = 0
var event_id: String = ""
var id: String = ""
var memory_id: String = ""
var owner_person_id: String = ""


func to_data() -> Dictionary:
	return {
		"applied_day_index": applied_day_index,
		"applied_observation_id": applied_observation_id,
		"applied_payload_hash": applied_payload_hash,
		"applied_revision": applied_revision,
		"event_id": event_id,
		"id": id,
		"memory_id": memory_id,
		"owner_person_id": owner_person_id,
	}


static func from_data(data: Dictionary) -> SocialEffectReceipt:
	var value: SocialEffectReceipt = SocialEffectReceipt.new()
	value.applied_day_index = data["applied_day_index"]
	value.applied_observation_id = data["applied_observation_id"]
	value.applied_payload_hash = data["applied_payload_hash"]
	value.applied_revision = data["applied_revision"]
	value.event_id = data["event_id"]
	value.id = data["id"]
	value.memory_id = data["memory_id"]
	value.owner_person_id = data["owner_person_id"]
	return value
