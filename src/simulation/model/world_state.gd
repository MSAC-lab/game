class_name WorldState
extends RefCounted

const SUPPORTED_SCHEMA_VERSION: int = 1

var schema_version: int = SUPPORTED_SCHEMA_VERSION
var ruleset_id: String = ""
var ruleset_hash: String = ""
var scenario_id: String = ""
var day_index: int = 0
var season_id: String = ""
var rng_seed_hex: String = ""
var rng_state_hex: String = ""
var next_ids: Dictionary = {}
var player_person_id: String = ""
var persons: Array[PersonState] = []
var households: Array[HouseholdState] = []
var relations: Array[RelationState] = []
var events: Array[EventRecord] = []
var information: Array[InformationState] = []
var memories: Array[MemoryState] = []


func to_state_data() -> Dictionary:
	return {
		"scenario_id": scenario_id,
		"day_index": day_index,
		"season_id": season_id,
		"rng_seed_hex": rng_seed_hex,
		"rng_state_hex": rng_state_hex,
		"next_ids": next_ids.duplicate(true),
		"player_person_id": player_person_id,
		"persons": ModelData.object_array_to_data(persons),
		"households": ModelData.object_array_to_data(households),
		"relations": ModelData.object_array_to_data(relations),
		"events": ModelData.object_array_to_data(events),
		"information": ModelData.object_array_to_data(information),
		"memories": ModelData.object_array_to_data(memories),
	}


static func from_data(metadata: Dictionary, state_data: Dictionary) -> WorldState:
	var world: WorldState = WorldState.new()
	world.schema_version = int(metadata.get("schema_version", 0))
	world.ruleset_id = str(metadata.get("ruleset_id", ""))
	world.ruleset_hash = str(metadata.get("ruleset_hash", ""))
	world.scenario_id = str(state_data.get("scenario_id", ""))
	world.day_index = int(state_data.get("day_index", 0))
	world.season_id = str(state_data.get("season_id", ""))
	world.rng_seed_hex = str(state_data.get("rng_seed_hex", ""))
	world.rng_state_hex = str(state_data.get("rng_state_hex", ""))
	world.next_ids = ModelData.copy_string_int_dictionary(state_data.get("next_ids", {}))
	world.player_person_id = str(state_data.get("player_person_id", ""))

	var person_data: Array = state_data.get("persons", [])
	for item: Variant in person_data:
		world.persons.append(PersonState.from_data(item))

	var household_data: Array = state_data.get("households", [])
	for item: Variant in household_data:
		world.households.append(HouseholdState.from_data(item))

	var relation_data: Array = state_data.get("relations", [])
	for item: Variant in relation_data:
		world.relations.append(RelationState.from_data(item))

	var event_data: Array = state_data.get("events", [])
	for item: Variant in event_data:
		world.events.append(EventRecord.from_data(item))

	var information_data: Array = state_data.get("information", [])
	for item: Variant in information_data:
		world.information.append(InformationState.from_data(item))

	var memory_data: Array = state_data.get("memories", [])
	for item: Variant in memory_data:
		world.memories.append(MemoryState.from_data(item))

	return world


func find_person(person_id: String) -> PersonState:
	for person: PersonState in persons:
		if person.id == person_id:
			return person
	return null
