class_name HouseholdState
extends RefCounted

var id: String = ""
var member_ids: Array[String] = []
var food_units: int = 0
var wealth_units: int = 0
var daily_food_need_units: int = 0
var livelihood_id: String = ""
var dependency_load: int = 0
var residence_id: String = ""


func to_data() -> Dictionary:
	return {
		"id": id,
		"member_ids": member_ids.duplicate(),
		"food_units": food_units,
		"wealth_units": wealth_units,
		"daily_food_need_units": daily_food_need_units,
		"livelihood_id": livelihood_id,
		"dependency_load": dependency_load,
		"residence_id": residence_id,
	}


static func from_data(data: Dictionary) -> HouseholdState:
	var state: HouseholdState = HouseholdState.new()
	state.id = str(data.get("id", ""))
	state.member_ids = ModelData.copy_string_array(data.get("member_ids", []))
	state.food_units = int(data.get("food_units", 0))
	state.wealth_units = int(data.get("wealth_units", 0))
	state.daily_food_need_units = int(data.get("daily_food_need_units", 0))
	state.livelihood_id = str(data.get("livelihood_id", ""))
	state.dependency_load = int(data.get("dependency_load", 0))
	state.residence_id = str(data.get("residence_id", ""))
	return state
