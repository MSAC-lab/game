class_name M3FixtureFactory
extends RefCounted

const ACTOR_ID: String = "person:000001"
const SPOUSE_ID: String = "person:000002"
const CHILD_ID: String = "person:000003"
const HEAD_ID: String = "person:000004"
const ACTOR_HOUSEHOLD_ID: String = "household:000001"
const HEAD_HOUSEHOLD_ID: String = "household:000002"
const ACTOR_STORE_ID: String = "resource_store:household:000001"
const HEAD_STORE_ID: String = "resource_store:household:000002"
const GRANARY_ID: String = "resource_store:village_granary"
const DECISION_KEY: String = "daily_food_strategy"


static func create_world(case_id: String = "C01") -> WorldState:
	var world: WorldState = _base_world()
	match case_id:
		"C01":
			pass
		"C02":
			_set_food_and_hunger(world, 0, 80, 75, 90)
			_set_actor_emotions(world, 85, 70)
			_set_head_relation(world, 15, 5, 22, 55, 15)
			_set_fact(world, "request_success_expectation", "person", HEAD_ID, 10, 100)
			_set_fact(world, "theft_opportunity", "resource_store", GRANARY_ID, 90, 90)
		"C03":
			_set_food_and_hunger(world, 50, 10, 10, 15)
			_set_head_relation(world, 65, 5, 22, 0, 30)
			_set_fact(world, "request_success_expectation", "person", HEAD_ID, 70, 90)
		"C04":
			world.find_household(ACTOR_HOUSEHOLD_ID).dependent_person_ids = []
		"C05A":
			_set_security_observation(world, 20, 20)
		"C05B":
			_set_security_observation(world, 80, 80)
		"C05C":
			_set_security_observation(world, 80, 20)
		_:
			push_error("Unknown M3 observation case: %s" % case_id)
	world.scenario_id = "m3-observation-%s" % case_id.to_lower()
	return world


static func create_request(actor_id: String = ACTOR_ID) -> DecisionRequest:
	return DecisionRequest.create(actor_id, DECISION_KEY)


static func _base_world() -> WorldState:
	var world: WorldState = WorldState.new()
	world.schema_version = WorldState.SCHEMA_VERSION_M3
	world.ruleset_id = M3DecisionRules.RULESET_ID
	world.ruleset_hash = M3DecisionRules.ruleset_hash()
	world.scenario_id = "m3-observation-c01"
	world.day_index = 7
	world.day_phase = WorldState.DAY_END_PHASE
	world.season_id = "late_summer_drought"
	world.rng_seed_hex = "0123456789abcdef"
	world.rng_state_hex = "fedcba9876543210"
	world.next_ids = {
		"decision": 1,
		"event": 2,
		"household": 3,
		"information": 11,
		"memory": 1,
		"person": 5,
		"resource_transaction": 1,
	}
	world.player_person_id = ACTOR_ID

	var actor: PersonState = _person(ACTOR_ID, "한결", ACTOR_HOUSEHOLD_ID, "field_worker", 2, 35)
	actor.trait_scores = {
		"risk_taking": 54,
		"empathy": 67,
		"self_control": 56,
		"norm_adherence": 69,
	}
	actor.value_scores = {
		"family_protection": 94,
		"community_survival": 50,
		"legitimate_order": 50,
		"fairness_reciprocity": 74,
		"property_autonomy": 50,
		"life_protection": 50,
	}
	actor.emotion_scores = {"fear": 70, "anger": 20}
	actor.goal_ids = [M3DecisionRules.GOAL_SECURE_HOUSEHOLD_FOOD]

	var spouse: PersonState = _person(SPOUSE_ID, "미라", ACTOR_HOUSEHOLD_ID, "weaver", 2, 30)
	var child: PersonState = _person(CHILD_ID, "나리", ACTOR_HOUSEHOLD_ID, "child", 1, 40)
	var head: PersonState = _person(HEAD_ID, "도윤", HEAD_HOUSEHOLD_ID, "village_head", 2, 5)
	head.role_ids = ["village_head"]
	world.persons = [actor, spouse, child, head]

	var actor_household: HouseholdState = _household(
		ACTOR_HOUSEHOLD_ID,
		[ACTOR_ID, SPOUSE_ID, CHILD_ID],
		ACTOR_STORE_ID,
		[CHILD_ID]
	)
	var head_household: HouseholdState = _household(
		HEAD_HOUSEHOLD_ID, [HEAD_ID], HEAD_STORE_ID, [] as Array[String]
	)
	world.households = [actor_household, head_household]
	world.resource_stores = [
		_store(GRANARY_ID, "village", "village:main", 80, 45),
		_store(ACTOR_STORE_ID, "household", ACTOR_HOUSEHOLD_ID, 15, 10),
		_store(HEAD_STORE_ID, "household", HEAD_HOUSEHOLD_ID, 60, 30),
	]

	world.relations = [
		_relation(ACTOR_ID, SPOUSE_ID, 85, 90, 0, 0, 85),
		_relation(ACTOR_ID, CHILD_ID, 92, 96, 0, 0, 98),
		_relation(ACTOR_ID, HEAD_ID, 43, 5, 22, 8, 15),
	]
	for relation: RelationState in world.relations:
		actor.relation_ids.append(relation.id)

	var source_event: EventRecord = EventRecord.new()
	source_event.id = "event:000001"
	source_event.day_index = 6
	source_event.event_type = "subjective_observation_basis"
	source_event.actor_ids = [ACTOR_ID]
	source_event.target_ids = [HEAD_ID]
	source_event.action_id = "observe"
	source_event.result_id = "facts_acquired"
	source_event.location_id = "location:village_center"
	source_event.witness_ids = [ACTOR_ID]
	source_event.is_public = false
	world.events = [source_event]

	world.information = [
		_fact("information:000001", "request_food_access", "person", HEAD_ID, 100, 100),
		_fact("information:000002", "request_food_capacity", "person", HEAD_ID, 60, 80),
		_fact("information:000003", "request_success_expectation", "person", HEAD_ID, 50, 80),
		_fact("information:000004", "request_social_risk", "person", HEAD_ID, 25, 80),
		_fact("information:000005", "village_authority", "person", HEAD_ID, 100, 100),
		_fact("information:000006", "food_stock_level", "resource_store", GRANARY_ID, 80, 80),
		_fact("information:000007", "theft_access", "resource_store", GRANARY_ID, 70, 90),
		_fact("information:000008", "theft_opportunity", "resource_store", GRANARY_ID, 70, 80),
		_fact("information:000009", "detection_risk", "resource_store", GRANARY_ID, 45, 80),
		_fact("information:000010", "sanction_severity", "resource_store", GRANARY_ID, 70, 90),
	]
	for fact: InformationState in world.information:
		actor.information_ids.append(fact.id)
	return world


static func _person(
	id: String,
	display_name: String,
	household_id: String,
	occupation_id: String,
	daily_food_need: int,
	hunger: int
) -> PersonState:
	var person: PersonState = PersonState.new()
	person.id = id
	person.display_name = display_name
	person.household_id = household_id
	person.occupation_id = occupation_id
	person.health = 100
	person.daily_food_need_units = daily_food_need
	person.severe_hunger_days = 0
	person.need_scores = {"hunger": hunger}
	return person


static func _household(
	id: String,
	member_ids: Array[String],
	store_id: String,
	dependent_ids: Array[String]
) -> HouseholdState:
	var household: HouseholdState = HouseholdState.new()
	household.id = id
	household.member_ids = member_ids
	household.resource_store_id = store_id
	household.wealth_units = 0
	household.livelihood_id = "mixed_labor"
	household.dependency_load = dependent_ids.size()
	household.dependent_person_ids = dependent_ids
	household.residence_id = "residence:%s" % id
	return household


static func _store(
	id: String,
	owner_kind: String,
	owner_id: String,
	quantity: int,
	security_level: int
) -> ResourceStoreState:
	var store: ResourceStoreState = ResourceStoreState.new()
	store.id = id
	store.owner_kind = owner_kind
	store.owner_id = owner_id
	store.resource_type_id = "food"
	store.quantity = quantity
	store.security_level = security_level
	return store


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


static func _fact(
	id: String,
	fact_type_id: String,
	subject_kind: String,
	subject_id: String,
	belief_value: int,
	confidence: int
) -> InformationState:
	var fact: InformationState = InformationState.new()
	fact.id = id
	fact.claim = "presentation-only:%s" % fact_type_id
	fact.owner_person_id = ACTOR_ID
	fact.linked_event_id = "event:000001"
	fact.acquisition_type = "observation_fixture"
	fact.original_source_person_id = ""
	fact.current_source_person_id = ""
	fact.confidence = confidence
	fact.is_secret = false
	fact.learned_day_index = 6
	fact.fact_type_id = fact_type_id
	fact.subject_kind = subject_kind
	fact.subject_id = subject_id
	fact.belief_value = belief_value
	return fact


static func _set_food_and_hunger(
	world: WorldState, food: int, actor_hunger: int, spouse_hunger: int, child_hunger: int
) -> void:
	world.find_resource_store(ACTOR_STORE_ID).quantity = food
	world.find_person(ACTOR_ID).need_scores["hunger"] = actor_hunger
	world.find_person(SPOUSE_ID).need_scores["hunger"] = spouse_hunger
	world.find_person(CHILD_ID).need_scores["hunger"] = child_hunger


static func _set_actor_emotions(world: WorldState, fear: int, anger: int) -> void:
	world.find_person(ACTOR_ID).emotion_scores["fear"] = fear
	world.find_person(ACTOR_ID).emotion_scores["anger"] = anger


static func _set_head_relation(
	world: WorldState,
	trust: int,
	affection: int,
	fear: int,
	resentment: int,
	obligation: int
) -> void:
	var relation_id: String = IdAllocator.relation_id(ACTOR_ID, HEAD_ID)
	for relation: RelationState in world.relations:
		if relation.id == relation_id:
			relation.trust = trust
			relation.affection = affection
			relation.fear = fear
			relation.resentment = resentment
			relation.obligation = obligation
			return


static func _set_fact(
	world: WorldState,
	fact_type_id: String,
	subject_kind: String,
	subject_id: String,
	belief_value: int,
	confidence: int
) -> void:
	for fact: InformationState in world.information:
		if (
			fact.fact_type_id == fact_type_id
			and fact.subject_kind == subject_kind
			and fact.subject_id == subject_id
		):
			fact.belief_value = belief_value
			fact.confidence = confidence
			return


static func _set_security_observation(
	world: WorldState, actual_security: int, known_detection_risk: int
) -> void:
	world.find_resource_store(GRANARY_ID).security_level = actual_security
	_set_fact(
		world,
		"detection_risk",
		"resource_store",
		GRANARY_ID,
		known_detection_risk,
		100
	)
