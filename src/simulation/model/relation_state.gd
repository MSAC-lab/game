class_name RelationState
extends RefCounted

var id: String = ""
var from_person_id: String = ""
var to_person_id: String = ""
var trust: int = 0
var affection: int = 0
var fear: int = 0
var resentment: int = 0
var obligation: int = 0


func to_data() -> Dictionary:
	return {
		"id": id,
		"from_person_id": from_person_id,
		"to_person_id": to_person_id,
		"trust": trust,
		"affection": affection,
		"fear": fear,
		"resentment": resentment,
		"obligation": obligation,
	}


static func from_data(data: Dictionary) -> RelationState:
	var state: RelationState = RelationState.new()
	state.id = str(data.get("id", ""))
	state.from_person_id = str(data.get("from_person_id", ""))
	state.to_person_id = str(data.get("to_person_id", ""))
	state.trust = int(data.get("trust", 0))
	state.affection = int(data.get("affection", 0))
	state.fear = int(data.get("fear", 0))
	state.resentment = int(data.get("resentment", 0))
	state.obligation = int(data.get("obligation", 0))
	return state
