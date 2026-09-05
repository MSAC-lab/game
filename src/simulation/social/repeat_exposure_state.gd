class_name RepeatExposureState
extends RefCounted

var action_family: String = ""
var id: String = ""
var low_risk_days: Array[int] = []
var owner_person_id: String = ""
var trait_id: String = ""


func to_data() -> Dictionary:
	return {
		"action_family": action_family,
		"id": id,
		"low_risk_days": low_risk_days.duplicate(),
		"owner_person_id": owner_person_id,
		"trait_id": trait_id,
	}


static func from_data(data: Dictionary) -> RepeatExposureState:
	var value: RepeatExposureState = RepeatExposureState.new()
	value.action_family = data["action_family"]
	value.id = data["id"]
	value.low_risk_days.assign(data["low_risk_days"])
	value.owner_person_id = data["owner_person_id"]
	value.trait_id = data["trait_id"]
	return value
