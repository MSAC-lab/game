class_name TraitPressureState
extends RefCounted

var id: String = ""
var owner_person_id: String = ""
var pressure: int = 0
var trait_id: String = ""


func to_data() -> Dictionary:
	return {
		"id": id,
		"owner_person_id": owner_person_id,
		"pressure": pressure,
		"trait_id": trait_id,
	}


static func from_data(data: Dictionary) -> TraitPressureState:
	var value: TraitPressureState = TraitPressureState.new()
	value.id = data["id"]
	value.owner_person_id = data["owner_person_id"]
	value.pressure = data["pressure"]
	value.trait_id = data["trait_id"]
	return value
