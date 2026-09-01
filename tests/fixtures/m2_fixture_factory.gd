class_name M2FixtureFactory
extends RefCounted


static func create_world() -> WorldState:
	var world: WorldState = WorldState.new()
	world.schema_version = WorldState.SCHEMA_VERSION_M2
	world.ruleset_id = M2ResourceRules.RULESET_ID
	world.ruleset_hash = M2ResourceRules.ruleset_hash()
	world.scenario_id = "m2-three-household-eight-person-fixture"
	world.day_index = 0
	world.day_phase = WorldState.DAY_END_PHASE
	world.season_id = "early_summer"
	world.rng_seed_hex = "0123456789abcdef"
	world.rng_state_hex = "fedcba9876543210"
	world.next_ids = {
		"decision": 1,
		"event": 1,
		"household": 4,
		"information": 1,
		"memory": 1,
		"person": 9,
		"resource_transaction": 1,
	}
	world.player_person_id = "person:000001"

	world.persons = [
		_person("person:000001", "한결", "household:000001", "store_assistant", 2),
		_person("person:000002", "미라", "household:000001", "weaver", 2),
		_person("person:000003", "도윤", "household:000002", "village_head", 2),
		_person("person:000004", "나리", "household:000001", "child", 1),
		_person("person:000005", "서린", "household:000002", "household_manager", 2),
		_person("person:000006", "백운", "household:000002", "elder", 1),
		_person("person:000007", "태오", "household:000003", "field_worker", 2),
		_person("person:000008", "라온", "household:000003", "field_worker", 2),
	]

	world.households = [
		_household(
			"household:000001",
			["person:000001", "person:000002", "person:000004"],
			"resource_store:household:000001",
			"mixed_labor",
			"residence:south_lane_03"
		),
		_household(
			"household:000002",
			["person:000003", "person:000005", "person:000006"],
			"resource_store:household:000002",
			"village_administration",
			"residence:headman_compound"
		),
		_household(
			"household:000003",
			["person:000007", "person:000008"],
			"resource_store:household:000003",
			"field_labor",
			"residence:north_lane_02"
		),
	]

	world.resource_stores = [
		_store("resource_store:village_granary", "village", "village:main", 100),
		_store("resource_store:household:000001", "household", "household:000001", 22),
		_store("resource_store:household:000002", "household", "household:000002", 46),
		_store("resource_store:household:000003", "household", "household:000003", 13),
	]
	return world


static func _person(
	id: String, name: String, household_id: String, occupation_id: String, food_need: int
) -> PersonState:
	var person: PersonState = PersonState.new()
	person.id = id
	person.display_name = name
	person.household_id = household_id
	person.occupation_id = occupation_id
	person.health = 100
	person.daily_food_need_units = food_need
	person.severe_hunger_days = 0
	person.need_scores = {"hunger": 0}
	return person


static func _household(
	id: String,
	member_ids: Array[String],
	store_id: String,
	livelihood_id: String,
	residence_id: String
) -> HouseholdState:
	var household: HouseholdState = HouseholdState.new()
	household.id = id
	household.member_ids = member_ids
	household.resource_store_id = store_id
	household.wealth_units = 0
	household.livelihood_id = livelihood_id
	household.dependency_load = 0
	household.residence_id = residence_id
	return household


static func _store(
	id: String, owner_kind: String, owner_id: String, quantity: int
) -> ResourceStoreState:
	var store: ResourceStoreState = ResourceStoreState.new()
	store.id = id
	store.owner_kind = owner_kind
	store.owner_id = owner_id
	store.quantity = quantity
	return store
