class_name M60FixtureFactory
extends RefCounted


static func config(world: WorldState) -> Dictionary:
	var parsed: Dictionary = M5JsonReader.parse(FileAccess.get_file_as_string("res://scenarios/m6-0-food-pressure-v1.json"))
	assert(parsed.ok)
	var value: Dictionary = parsed.value.config.duplicate(true)
	value.initial_state_hash = StateHasher.hash_world(world)
	return value


static func isolated(world: WorldState) -> Dictionary:
	var value: Dictionary = config(world)
	value.automatic_person_ids = ["person:000001"]
	value.contacts = []
	value.person_sites["person:000004"] = "site:head-house"
	return value


static func starvation() -> WorldState:
	var world: WorldState = M5FixtureFactory.initial()
	for store: ResourceStoreState in world.resource_stores:
		store.quantity = 0
	var child: PersonState = world.find_person("person:000003")
	child.need_scores.hunger = 100
	child.severe_hunger_days = 3
	child.health = 1
	return world


static func theft() -> WorldState:
	var world: WorldState = M5FixtureFactory.initial()
	for fact: InformationState in world.information:
		if fact.owner_person_id == "person:000001" and fact.fact_type_id == "request_food_access":
			fact.belief_value = 0
	var actor: PersonState = world.find_person("person:000001")
	actor.trait_scores.norm_adherence = 70
	actor.value_scores.family_protection = 95
	actor.need_scores.hunger = 90
	return world
