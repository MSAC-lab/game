class_name M5FixtureFactory
extends RefCounted

static var _annex: Dictionary = {}


static func annex() -> Dictionary:
	if _annex.is_empty():
		var parsed: Dictionary = M5JsonReader.parse(FileAccess.get_file_as_string("res://tests/fixtures/m5_design_vectors.json"))
		assert(parsed.ok, parsed.error)
		_annex = parsed.value
	return _annex.duplicate(true)


static func initial(legacy_memory: bool = false) -> WorldState:
	var data: Dictionary = annex()
	var payload: Dictionary = data.blocker_vectors.B01.initial_payload if legacy_memory else data.FCAL_initial_payload
	return WorldState.from_data(payload, payload.state)


static func submission(world: WorldState, actor: String) -> DecisionSubmission:
	var request: DecisionRequest = DecisionRequest.create(actor, "daily_food_strategy")
	return DecisionSubmission.create(request, DecisionEngine.evaluate(world, request))


static func issuer(world: WorldState, submissions: Array, people: Array[String] = [], stores: Array[String] = []) -> TestResolutionContextIssuer:
	var result: TestResolutionContextIssuer = TestResolutionContextIssuer.new()
	for item: DecisionSubmission in submissions:
		var parameterized: ParameterizationResult = IntentParameterizer.parameterize(world, item.decision_request, item.submitted_decision_result)
		if not parameterized.ok:
			continue
		var intent: ActionIntent = parameterized.intent
		var present: Array[String] = people.duplicate()
		if present.is_empty():
			present.append(intent.actor_person_id)
			if not intent.target_person_id.is_empty():
				present.append(intent.target_person_id)
		var available: Array[String] = stores.duplicate()
		if available.is_empty():
			for store: ResourceStoreState in world.resource_stores:
				available.append(store.id)
		result.set_presence(intent.action_instance_id, present, available)
	return result


static func execute(world: WorldState, actor: String, people: Array[String] = [], stores: Array[String] = []) -> M5OperationResult:
	var submissions: Array = [submission(world, actor)]
	return M5Facade.execute_decisions_v1(world, M5RequestStamp.for_world(world), submissions, issuer(world, submissions, people, stores))


static func contacts(world: WorldState, pairs: Array = []) -> M5OperationResult:
	return M5Facade.process_contacts_v1(world, M5RequestStamp.for_world(world), SocialContactPlan.from_pairs(pairs))
