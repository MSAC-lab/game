class_name PersonState
extends RefCounted

var id: String = ""
var display_name: String = ""
var household_id: String = ""
var occupation_id: String = ""
var role_ids: Array[String] = []
var alive: bool = true
var health: int = 100
var daily_food_need_units: int = 0
var severe_hunger_days: int = 0
var trait_scores: Dictionary = {}
var value_scores: Dictionary = {}
var emotion_scores: Dictionary = {}
var need_scores: Dictionary = {}
var goal_ids: Array[String] = []
var information_ids: Array[String] = []
var memory_ids: Array[String] = []
var relation_ids: Array[String] = []
var aptitude_scores: Dictionary = {}
var skill_scores: Dictionary = {}


func to_data(schema_version: int = WorldState.SCHEMA_VERSION_M1) -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"display_name": display_name,
		"household_id": household_id,
		"occupation_id": occupation_id,
		"role_ids": role_ids.duplicate(),
		"alive": alive,
		"health": health,
		"trait_scores": trait_scores.duplicate(true),
		"value_scores": value_scores.duplicate(true),
		"emotion_scores": emotion_scores.duplicate(true),
		"need_scores": need_scores.duplicate(true),
		"goal_ids": goal_ids.duplicate(),
		"information_ids": information_ids.duplicate(),
		"memory_ids": memory_ids.duplicate(),
		"relation_ids": relation_ids.duplicate(),
	}
	if schema_version in [
		WorldState.SCHEMA_VERSION_M2,
		WorldState.SCHEMA_VERSION_M3,
		WorldState.SCHEMA_VERSION_M4,
	]:
		data["daily_food_need_units"] = daily_food_need_units
		data["severe_hunger_days"] = severe_hunger_days
	if schema_version == WorldState.SCHEMA_VERSION_M4:
		data["aptitude_scores"] = aptitude_scores.duplicate(true)
		data["skill_scores"] = skill_scores.duplicate(true)
	return data


static func from_data(
	data: Dictionary, schema_version: int = WorldState.SCHEMA_VERSION_M1
) -> PersonState:
	var state: PersonState = PersonState.new()
	state.id = str(data.get("id", ""))
	state.display_name = str(data.get("display_name", ""))
	state.household_id = str(data.get("household_id", ""))
	state.occupation_id = str(data.get("occupation_id", ""))
	state.role_ids = ModelData.copy_string_array(data.get("role_ids", []))
	state.alive = bool(data.get("alive", false))
	state.health = int(data.get("health", 0))
	if schema_version in [
		WorldState.SCHEMA_VERSION_M2,
		WorldState.SCHEMA_VERSION_M3,
		WorldState.SCHEMA_VERSION_M4,
	]:
		state.daily_food_need_units = int(data.get("daily_food_need_units", 0))
		state.severe_hunger_days = int(data.get("severe_hunger_days", 0))
	state.trait_scores = ModelData.copy_string_int_dictionary(data.get("trait_scores", {}))
	state.value_scores = ModelData.copy_string_int_dictionary(data.get("value_scores", {}))
	state.emotion_scores = ModelData.copy_string_int_dictionary(data.get("emotion_scores", {}))
	state.need_scores = ModelData.copy_string_int_dictionary(data.get("need_scores", {}))
	state.goal_ids = ModelData.copy_string_array(data.get("goal_ids", []))
	state.information_ids = ModelData.copy_string_array(data.get("information_ids", []))
	state.memory_ids = ModelData.copy_string_array(data.get("memory_ids", []))
	state.relation_ids = ModelData.copy_string_array(data.get("relation_ids", []))
	if schema_version == WorldState.SCHEMA_VERSION_M4:
		state.aptitude_scores = ModelData.copy_string_int_dictionary(
			data.get("aptitude_scores", {})
		)
		state.skill_scores = ModelData.copy_string_int_dictionary(data.get("skill_scores", {}))
	return state
