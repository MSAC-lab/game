class_name SocialContactPair
extends RefCounted

var id: String = ""
var person_a_id: String = ""
var person_b_id: String = ""


func to_data() -> Dictionary:
	return {
		"id": id,
		"person_a_id": person_a_id,
		"person_b_id": person_b_id,
	}


static func from_data(data: Dictionary) -> SocialContactPair:
	var value: SocialContactPair = SocialContactPair.new()
	value.id = data["id"]
	value.person_a_id = data["person_a_id"]
	value.person_b_id = data["person_b_id"]
	return value
