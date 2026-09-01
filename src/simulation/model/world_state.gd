class_name WorldState
extends RefCounted

const SCHEMA_VERSION_M1: int = 1
const SCHEMA_VERSION_M2: int = 2
const SCHEMA_VERSION_M3: int = 3
const CURRENT_SCHEMA_VERSION: int = SCHEMA_VERSION_M3
const SUPPORTED_SCHEMA_VERSION: int = CURRENT_SCHEMA_VERSION
const DAY_END_PHASE: String = "DAY_END"

var schema_version: int = CURRENT_SCHEMA_VERSION
var ruleset_id: String = ""
var ruleset_hash: String = ""
var scenario_id: String = ""
var day_index: int = 0
var day_phase: String = DAY_END_PHASE
var season_id: String = ""
var rng_seed_hex: String = ""
var rng_state_hex: String = ""
var next_ids: Dictionary = {}
var player_person_id: String = ""
var persons: Array[PersonState] = []
var households: Array[HouseholdState] = []
var resource_stores: Array[ResourceStoreState] = []
var relations: Array[RelationState] = []
var events: Array[EventRecord] = []
var information: Array[InformationState] = []
var memories: Array[MemoryState] = []


func to_state_data() -> Dictionary:
	var person_data: Array = []
	for person: PersonState in persons:
		person_data.append(person.to_data(schema_version))
	var household_data: Array = []
	for household: HouseholdState in households:
		household_data.append(household.to_data(schema_version))
	var data: Dictionary = {
		"scenario_id": scenario_id,
		"day_index": day_index,
		"season_id": season_id,
		"rng_seed_hex": rng_seed_hex,
		"rng_state_hex": rng_state_hex,
		"next_ids": next_ids.duplicate(true),
		"player_person_id": player_person_id,
		"persons": person_data,
		"households": household_data,
		"relations": ModelData.object_array_to_data(relations),
		"events": ModelData.object_array_to_data(events),
		"memories": ModelData.object_array_to_data(memories),
	}
	var information_data: Array = []
	for fact: InformationState in information:
		information_data.append(fact.to_data(schema_version))
	data["information"] = information_data
	if schema_version in [SCHEMA_VERSION_M2, SCHEMA_VERSION_M3]:
		data["day_phase"] = day_phase
		var resource_store_data: Array = []
		for store: ResourceStoreState in resource_stores:
			resource_store_data.append(store.to_data(schema_version))
		data["resource_stores"] = resource_store_data
	return data


static func from_data(metadata: Dictionary, state_data: Dictionary) -> WorldState:
	var world: WorldState = WorldState.new()
	world.schema_version = int(metadata.get("schema_version", 0))
	world.ruleset_id = str(metadata.get("ruleset_id", ""))
	world.ruleset_hash = str(metadata.get("ruleset_hash", ""))
	world.scenario_id = str(state_data.get("scenario_id", ""))
	world.day_index = int(state_data.get("day_index", 0))
	if world.schema_version in [SCHEMA_VERSION_M2, SCHEMA_VERSION_M3]:
		world.day_phase = str(state_data.get("day_phase", ""))
	world.season_id = str(state_data.get("season_id", ""))
	world.rng_seed_hex = str(state_data.get("rng_seed_hex", ""))
	world.rng_state_hex = str(state_data.get("rng_state_hex", ""))
	world.next_ids = ModelData.copy_string_int_dictionary(state_data.get("next_ids", {}))
	world.player_person_id = str(state_data.get("player_person_id", ""))

	var person_data: Array = state_data.get("persons", [])
	for item: Variant in person_data:
		world.persons.append(PersonState.from_data(item, world.schema_version))

	var household_data: Array = state_data.get("households", [])
	for item: Variant in household_data:
		world.households.append(HouseholdState.from_data(item, world.schema_version))

	if world.schema_version in [SCHEMA_VERSION_M2, SCHEMA_VERSION_M3]:
		var resource_store_data: Array = state_data.get("resource_stores", [])
		for item: Variant in resource_store_data:
			world.resource_stores.append(ResourceStoreState.from_data(item, world.schema_version))

	var relation_data: Array = state_data.get("relations", [])
	for item: Variant in relation_data:
		world.relations.append(RelationState.from_data(item))

	var event_data: Array = state_data.get("events", [])
	for item: Variant in event_data:
		world.events.append(EventRecord.from_data(item))

	var information_data: Array = state_data.get("information", [])
	for item: Variant in information_data:
		world.information.append(InformationState.from_data(item, world.schema_version))

	var memory_data: Array = state_data.get("memories", [])
	for item: Variant in memory_data:
		world.memories.append(MemoryState.from_data(item))

	return world


func find_person(person_id: String) -> PersonState:
	for person: PersonState in persons:
		if person.id == person_id:
			return person
	return null


func find_household(household_id: String) -> HouseholdState:
	for household: HouseholdState in households:
		if household.id == household_id:
			return household
	return null


func find_resource_store(store_id: String) -> ResourceStoreState:
	for store: ResourceStoreState in resource_stores:
		if store.id == store_id:
			return store
	return null
