class_name HouseholdState
extends RefCounted

var id: String = ""
var member_ids: Array[String] = []
var food_units: int = 0
var wealth_units: int = 0
var daily_food_need_units: int = 0
var resource_store_id: String = ""
var livelihood_id: String = ""
var dependency_load: int = 0
var dependent_person_ids: Array[String] = []
var residence_id: String = ""


func to_data(schema_version: int = WorldState.SCHEMA_VERSION_M1) -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"member_ids": member_ids.duplicate(),
		"wealth_units": wealth_units,
		"livelihood_id": livelihood_id,
		"dependency_load": dependency_load,
		"residence_id": residence_id,
	}
	if schema_version == WorldState.SCHEMA_VERSION_M1:
		data["food_units"] = food_units
		data["daily_food_need_units"] = daily_food_need_units
	elif schema_version in [WorldState.SCHEMA_VERSION_M2, WorldState.SCHEMA_VERSION_M3]:
		data["resource_store_id"] = resource_store_id
		if schema_version == WorldState.SCHEMA_VERSION_M3:
			data["dependent_person_ids"] = dependent_person_ids.duplicate()
	return data


static func from_data(
	data: Dictionary, schema_version: int = WorldState.SCHEMA_VERSION_M1
) -> HouseholdState:
	var state: HouseholdState = HouseholdState.new()
	state.id = str(data.get("id", ""))
	state.member_ids = ModelData.copy_string_array(data.get("member_ids", []))
	state.wealth_units = int(data.get("wealth_units", 0))
	if schema_version == WorldState.SCHEMA_VERSION_M1:
		state.food_units = int(data.get("food_units", 0))
		state.daily_food_need_units = int(data.get("daily_food_need_units", 0))
	elif schema_version in [WorldState.SCHEMA_VERSION_M2, WorldState.SCHEMA_VERSION_M3]:
		state.resource_store_id = str(data.get("resource_store_id", ""))
		if schema_version == WorldState.SCHEMA_VERSION_M3:
			state.dependent_person_ids = ModelData.copy_string_array(
				data.get("dependent_person_ids", [])
			)
	state.livelihood_id = str(data.get("livelihood_id", ""))
	state.dependency_load = int(data.get("dependency_load", 0))
	state.residence_id = str(data.get("residence_id", ""))
	return state
