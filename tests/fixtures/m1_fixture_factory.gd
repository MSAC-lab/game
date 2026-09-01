class_name M1FixtureFactory
extends RefCounted


static func create() -> Dictionary:
	var world: WorldState = WorldState.new()
	world.ruleset_id = "drought-prototype-rules-v1"
	world.scenario_id = "three-person-state-fixture"
	world.day_index = 7
	world.season_id = "late_spring"
	world.rng_seed_hex = "0123456789abcdef"
	world.rng_state_hex = "fedcba9876543210"
	world.next_ids = {
		"decision": 2,
		"event": 2,
		"household": 3,
		"information": 2,
		"memory": 2,
		"person": 4,
	}
	world.player_person_id = "person:000001"

	var player: PersonState = _person("person:000001", "한결", "household:000001", "store_assistant")
	player.role_ids = ["player_window"]
	player.trait_scores = {"courage": 42, "discipline": 61}
	player.value_scores = {"family": 78, "law": 55}
	player.emotion_scores = {"anxiety": 35}
	player.need_scores = {"hunger": 28, "security": 44}
	player.goal_ids = ["goal:protect_household"]
	player.information_ids = ["information:000001"]
	player.memory_ids = ["memory:000001"]

	var spouse: PersonState = _person("person:000002", "미라", "household:000001", "weaver")
	spouse.trait_scores = {"courage": 37, "discipline": 68}
	spouse.value_scores = {"family": 82, "law": 64}
	spouse.emotion_scores = {"anxiety": 22}
	spouse.need_scores = {"hunger": 24, "security": 40}

	var head: PersonState = _person("person:000003", "도윤", "household:000002", "village_head")
	head.role_ids = ["village_authority"]
	head.trait_scores = {"courage": 58, "discipline": 73}
	head.value_scores = {"family": 48, "law": 80}
	head.emotion_scores = {"anxiety": 16}
	head.need_scores = {"hunger": 12, "security": 25}

	var relation_out: RelationState = _relation(player.id, head.id, 62, 18, 9, 6, 25)
	var relation_in: RelationState = _relation(head.id, player.id, 47, 12, 3, 8, 14)
	player.relation_ids = [relation_out.id]
	head.relation_ids = [relation_in.id]
	world.persons = [head, player, spouse]
	world.relations = [relation_in, relation_out]

	var household_one: HouseholdState = HouseholdState.new()
	household_one.id = "household:000001"
	household_one.member_ids = [spouse.id, player.id]
	household_one.food_units = 36
	household_one.wealth_units = 18
	household_one.daily_food_need_units = 4
	household_one.livelihood_id = "mixed_labor"
	household_one.dependency_load = 1
	household_one.residence_id = "residence:south_lane_03"
	var household_two: HouseholdState = HouseholdState.new()
	household_two.id = "household:000002"
	household_two.member_ids = [head.id]
	household_two.food_units = 52
	household_two.wealth_units = 41
	household_two.daily_food_need_units = 2
	household_two.livelihood_id = "village_administration"
	household_two.dependency_load = 0
	household_two.residence_id = "residence:headman_compound"
	world.households = [household_two, household_one]

	var event: EventRecord = EventRecord.new()
	event.id = "event:000001"
	event.day_index = 6
	event.event_type = "overheard_storehouse_count"
	event.actor_ids = [head.id]
	event.target_ids = []
	event.action_id = "action:count_public_grain"
	event.result_id = "result:reserve_lower_than_claimed"
	event.location_id = "location:village_storehouse"
	event.witness_ids = [player.id]
	event.is_public = false
	world.events = [event]

	var info: InformationState = InformationState.new()
	info.id = "information:000001"
	info.claim = "The public grain reserve is lower than the announced amount."
	info.owner_person_id = player.id
	info.linked_event_id = event.id
	info.acquisition_type = "direct_observation"
	info.original_source_person_id = head.id
	info.current_source_person_id = ""
	info.confidence = 88
	info.is_secret = true
	info.learned_day_index = 6
	world.information = [info]

	var memory: MemoryState = MemoryState.new()
	memory.id = "memory:000001"
	memory.owner_person_id = player.id
	memory.linked_event_id = event.id
	memory.linked_information_id = info.id
	memory.perceived_action_id = event.action_id
	memory.perceived_result_id = event.result_id
	memory.related_person_ids = [head.id]
	memory.emotion_scores = {"distrust": 31, "worry": 44}
	memory.importance = 57
	memory.occurred_day_index = 6
	memory.tier = "recent"
	world.memories = [memory]

	var action: ActionDefinition = ActionDefinition.new()
	action.id = "action:request_food_aid"
	action.version = 1
	action.display_name = "Request food aid"
	action.semantic_tags = ["legal", "social", "survival"]
	action.required_information_types = ["knows_authority"]
	action.relationship_keys = ["obligation", "trust"]
	action.resource_keys = ["food_units"]
	world.ruleset_hash = StateHasher.hash_data([action.to_data()])

	var audit: DecisionRecord = DecisionRecord.new()
	audit.id = "decision:000001"
	audit.actor_person_id = player.id
	audit.day_index = 7
	audit.candidate_action_ids = ["action:request_food_aid", "action:wait"]
	audit.unavailable_reasons = {"action:steal_food": "need pressure below threshold"}
	audit.evaluation_reasons = ["authority is still trusted", "legal route remains available"]
	audit.selected_intent = "protect_household_legally"
	audit.selected_action_id = "action:request_food_aid"
	audit.result_event_id = ""
	audit.change_pressure = {"desperation": 12, "distrust": 9}
	return {"world": world, "audit": [audit] as Array[DecisionRecord], "actions": [action] as Array[ActionDefinition]}


static func _person(id: String, name: String, household_id: String, occupation_id: String) -> PersonState:
	var person: PersonState = PersonState.new()
	person.id = id
	person.display_name = name
	person.household_id = household_id
	person.occupation_id = occupation_id
	return person


static func _relation(
	from_id: String,
	to_id: String,
	trust: int,
	affection: int,
	fear: int,
	resentment: int,
	obligation: int
) -> RelationState:
	var relation: RelationState = RelationState.new()
	relation.id = IdAllocator.relation_id(from_id, to_id)
	relation.from_person_id = from_id
	relation.to_person_id = to_id
	relation.trust = trust
	relation.affection = affection
	relation.fear = fear
	relation.resentment = resentment
	relation.obligation = obligation
	return relation
