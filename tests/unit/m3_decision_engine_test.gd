class_name M3DecisionEngineTest
extends RefCounted

const FROZEN_JSON_PATH: String = "res://tests/fixtures/m3_observation_report.json"
const FROZEN_HASH_PATH: String = "res://tests/fixtures/m3_observation_report.sha256"
const M1_JSON_PATH: String = "res://tests/fixtures/m1_canonical.json"
const M1_HASH_PATH: String = "res://tests/fixtures/m1_canonical.sha256"
const M2_JSON_PATH: String = "res://tests/fixtures/m2_day10_canonical.json"
const M2_HASH_PATH: String = "res://tests/fixtures/m2_day10_canonical.sha256"

var _failures: Array[String] = []


func run_all() -> Array[String]:
	_test_t01_wait_candidate_once()
	_test_t02_eligibility_and_exclusion()
	_test_t03_unknown_external_store()
	_test_t04_reproducibility()
	_test_t05_order_and_irrelevant_person_independence()
	_test_t06_exact_integer_components()
	_test_t07_clear_margin_uses_no_randomness()
	_test_t08_near_tie_uses_stateless_randomness()
	_test_t09_input_world_is_immutable()
	_test_t10_artifact_is_auditable_and_not_world_state()
	_test_t11_player_and_npc_share_path()
	_test_t12_frozen_observation_artifact()
	_test_r01_m1_frozen_regression()
	_test_r02_m2_frozen_regression()
	_test_r03_irrelevant_labels_do_not_branch_results()
	_test_r04_objective_private_information_boundary()
	_test_structured_fact_validation()
	_test_schema3_round_trip_and_old_schema_strictness()
	_test_presentation_and_history_are_not_inputs()
	_test_ruleset_hash_covers_constants()
	return _failures


func fixture_artifacts() -> Dictionary:
	var errors: Array[String] = []
	var cases: Array = []
	for case_id: String in ["C01", "C02", "C03", "C04", "C05A", "C05B", "C05C"]:
		var world: WorldState = M3FixtureFactory.create_world(case_id)
		var result: DecisionResult = DecisionEngine.evaluate(
			world, M3FixtureFactory.create_request()
		)
		if not result.ok:
			errors.append("%s: %s" % [case_id, str(result.errors)])
		cases.append({
			"case_id": case_id,
			"world_state_hash": StateHasher.hash_world(world),
			"decision": result.to_data(),
		})
	var report: Dictionary = {
		"artifact_type": "m3_observation_report",
		"behavior_interpretation": "OBSERVED_NOT_PASS_FAIL",
		"mechanics_contract": "M3-T01..T12_AND_M3-R01..R04",
		"ruleset_id": M3DecisionRules.RULESET_ID,
		"ruleset_hash": M3DecisionRules.ruleset_hash(),
		"cases": cases,
	}
	return {
		"json": StateCanonicalizer.pretty_json(report),
		"hash": StateHasher.hash_data(report) + "\n",
		"errors": errors,
	}


func _test_t01_wait_candidate_once() -> void:
	var result: DecisionResult = _evaluate_case("C01")
	if not _require_result(result, "M3-T01"):
		return
	var count: int = 0
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		if candidate.candidate_id == "A00||":
			count += 1
	_expect(count == 1, "M3-T01 A00 exists exactly once")


func _test_t02_eligibility_and_exclusion() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	_set_fact_belief(world, "request_food_access", 0)
	var result: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	if not _require_result(result, "M3-T02"):
		return
	_expect(_find_candidate(result, "A04|person|person:000004") == null, "M3-T02 ineligible A04 is absent")
	var exclusion: DecisionExclusion = _find_exclusion(result, "A04|person|person:000004")
	_expect(exclusion != null, "M3-T02 excluded A04 has an audit record")
	if exclusion != null:
		_expect(
			exclusion.reason_ids.has("request_food_access_below_50"),
			"M3-T02 exclusion uses stable threshold reason"
		)


func _test_t03_unknown_external_store() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	var kept: Array[InformationState] = []
	var kept_ids: Array[String] = []
	for fact: InformationState in world.information:
		if fact.subject_kind != "resource_store":
			kept.append(fact)
			kept_ids.append(fact.id)
	world.information = kept
	world.find_person(M3FixtureFactory.ACTOR_ID).information_ids = kept_ids
	var result: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	if not _require_result(result, "M3-T03"):
		return
	_expect(_count_action(result, M3DecisionRules.ACTION_THEFT) == 0, "M3-T03 unknown store creates no A11")


func _test_t04_reproducibility() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	var first: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	var second: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	_expect(
		DecisionArtifactCodec.canonical_json(first) == DecisionArtifactCodec.canonical_json(second),
		"M3-T04 same world and decision key produce an identical artifact"
	)


func _test_t05_order_and_irrelevant_person_independence() -> void:
	var baseline: WorldState = M3FixtureFactory.create_world("C01")
	var reordered: WorldState = _clone_world(baseline)
	reordered.persons.reverse()
	reordered.households.reverse()
	reordered.resource_stores.reverse()
	reordered.relations.reverse()
	reordered.information.reverse()
	var baseline_result: DecisionResult = DecisionEngine.evaluate(
		baseline, M3FixtureFactory.create_request()
	)
	var reordered_result: DecisionResult = DecisionEngine.evaluate(
		reordered, M3FixtureFactory.create_request()
	)
	_expect(
		_decision_core(baseline_result) == _decision_core(reordered_result),
		"M3-T05 collection order does not change decision mechanics"
	)

	var expanded: WorldState = _clone_world(baseline)
	var irrelevant: PersonState = PersonState.new()
	irrelevant.id = "person:999999"
	irrelevant.display_name = "무관한 사람"
	irrelevant.household_id = M3FixtureFactory.HEAD_HOUSEHOLD_ID
	irrelevant.occupation_id = "potter"
	irrelevant.health = 100
	irrelevant.daily_food_need_units = 2
	irrelevant.need_scores = {"hunger": 12}
	expanded.persons.append(irrelevant)
	expanded.find_household(M3FixtureFactory.HEAD_HOUSEHOLD_ID).member_ids.append(irrelevant.id)
	var expanded_result: DecisionResult = DecisionEngine.evaluate(
		expanded, M3FixtureFactory.create_request()
	)
	_expect(
		_decision_core(baseline_result) == _decision_core(expanded_result),
		"M3-T05 unrelated person does not change actor decision mechanics"
	)


func _test_t06_exact_integer_components() -> void:
	var result: DecisionResult = _evaluate_case("C01")
	if not _require_result(result, "M3-T06"):
		return
	var request_candidate: DecisionCandidateEvaluation = _find_candidate(
		result, "A04|person|person:000004"
	)
	var theft_candidate: DecisionCandidateEvaluation = _find_candidate(
		result, "A11|resource_store|resource_store:village_granary"
	)
	_expect(request_candidate != null and theft_candidate != null, "M3-T06 expected candidates exist")
	if request_candidate == null or theft_candidate == null:
		return
	_expect(
		_components(request_candidate) == [54, 100, 67, 54, 40, 18, 0, 25, 5505],
		"M3-T06 A04 integer components and utility match the frozen arithmetic"
	)
	_expect(
		_components(theft_candidate) == [54, 100, -13, 87, 56, 21, 46, 50, 3535],
		"M3-T06 A11 integer components and utility match the frozen arithmetic"
	)
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		_expect(
			candidate.utility_scaled == M3DecisionRules.utility_scaled(candidate),
			"M3-T06 %s utility is reconstructed from components" % candidate.candidate_id
		)


func _test_t07_clear_margin_uses_no_randomness() -> void:
	var result: DecisionResult = _evaluate_case("C01")
	if not _require_result(result, "M3-T07"):
		return
	_expect(result.selection_mode == "deterministic_margin", "M3-T07 clear margin is deterministic")
	_expect(result.random_digest_hex.is_empty(), "M3-T07 clear margin consumes no random digest")
	_expect(result.random_draw == -1, "M3-T07 clear margin has no random draw")


func _test_t08_near_tie_uses_stateless_randomness() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	var actor: PersonState = world.find_person(M3FixtureFactory.ACTOR_ID)
	for value_key: String in M3DecisionRules.VALUE_KEYS:
		actor.value_scores[value_key] = 0
	var before_rng: String = world.rng_state_hex
	var first: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	var second: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	if not _require_result(first, "M3-T08"):
		return
	_expect(first.selection_mode == "stateless_near_tie", "M3-T08 near tie mandates stateless random selection")
	_expect(not first.random_digest_hex.is_empty(), "M3-T08 near tie records its SHA-256 digest")
	_expect(first.random_total_weight > 0, "M3-T08 near tie records positive total weight")
	_expect(first.random_draw >= 0, "M3-T08 near tie records a bounded draw")
	_expect(
		DecisionArtifactCodec.canonical_json(first) == DecisionArtifactCodec.canonical_json(second),
		"M3-T08 stateless random selection reproduces exactly"
	)
	_expect(world.rng_state_hex == before_rng, "M3-T08 stateless selection leaves world RNG unchanged")
	var near_candidates: Array[DecisionCandidateEvaluation] = []
	for candidate_id: String in first.near_tie_candidate_ids:
		var candidate: DecisionCandidateEvaluation = _find_candidate(first, candidate_id)
		if candidate != null:
			near_candidates.append(candidate)
	near_candidates.reverse()
	var unsorted_result: Dictionary = StatelessNearTie.select(
		world, M3FixtureFactory.create_request(), near_candidates
	)
	_expect(
		str(unsorted_result["selected_candidate_id"]) == first.selected_candidate_id
		and str(unsorted_result["random_digest_hex"]) == first.random_digest_hex,
		"M3-T08 near-tie helper is independent of caller candidate order"
	)


func _test_t09_input_world_is_immutable() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C02")
	var before_json: String = StateCanonicalizer.canonical_json(StateHasher.state_payload(world))
	var before_hash: String = StateHasher.hash_world(world)
	var before_rng: String = world.rng_state_hex
	var result: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	_expect(result.ok, "M3-T09 evaluation succeeds")
	_expect(
		StateCanonicalizer.canonical_json(StateHasher.state_payload(world)) == before_json,
		"M3-T09 evaluation leaves all serialized state unchanged"
	)
	_expect(StateHasher.hash_world(world) == before_hash, "M3-T09 world hash remains unchanged")
	_expect(world.rng_state_hex == before_rng, "M3-T09 world RNG remains unchanged")


func _test_t10_artifact_is_auditable_and_not_world_state() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	var before_hash: String = StateHasher.hash_world(world)
	var result: DecisionResult = DecisionEngine.evaluate(world, M3FixtureFactory.create_request())
	if not _require_result(result, "M3-T10"):
		return
	var data: Dictionary = result.to_data()
	_expect(data.has("candidate_evaluations") and data.has("excluded_candidates"), "M3-T10 artifact exposes candidate audit")
	_expect(data.has("input_state_hash") and data.has("ruleset_hash"), "M3-T10 artifact binds input and rules")
	_expect(StateHasher.hash_world(world) == before_hash, "M3-T10 decision artifact is excluded from world hash")


func _test_t11_player_and_npc_share_path() -> void:
	var as_player: WorldState = M3FixtureFactory.create_world("C01")
	var as_npc: WorldState = _clone_world(as_player)
	as_npc.player_person_id = M3FixtureFactory.HEAD_ID
	var player_result: DecisionResult = DecisionEngine.evaluate(
		as_player, M3FixtureFactory.create_request()
	)
	var npc_result: DecisionResult = DecisionEngine.evaluate(
		as_npc, M3FixtureFactory.create_request()
	)
	_expect(
		_decision_core(player_result) == _decision_core(npc_result),
		"M3-T11 player flag does not change actor evaluation path"
	)


func _test_t12_frozen_observation_artifact() -> void:
	var artifacts: Dictionary = fixture_artifacts()
	_expect(artifacts["errors"].is_empty(), "M3-T12 observation cases evaluate successfully")
	_expect(
		_read_text(FROZEN_JSON_PATH) == artifacts["json"],
		"M3-T12 observation JSON is byte-identical to frozen artifact"
	)
	_expect(
		_read_text(FROZEN_HASH_PATH) == artifacts["hash"],
		"M3-T12 observation artifact hash is identical"
	)


func _test_r01_m1_frozen_regression() -> void:
	var suite: M1StateModelTest = M1StateModelTest.new()
	var artifacts: Dictionary = suite.fixture_artifacts()
	_expect(_read_text(M1_JSON_PATH) == artifacts["json"], "M3-R01 M1 frozen JSON remains byte-identical")
	_expect(_read_text(M1_HASH_PATH) == artifacts["hash"], "M3-R01 M1 frozen hash remains identical")


func _test_r02_m2_frozen_regression() -> void:
	var suite: M2TimeResourceTest = M2TimeResourceTest.new()
	var artifacts: Dictionary = suite.fixture_artifacts()
	_expect(_read_text(M2_JSON_PATH) == artifacts["json"], "M3-R02 M2 day-10 JSON remains byte-identical")
	_expect(_read_text(M2_HASH_PATH) == artifacts["hash"], "M3-R02 M2 day-10 hash remains identical")


func _test_r03_irrelevant_labels_do_not_branch_results() -> void:
	var baseline: WorldState = M3FixtureFactory.create_world("C01")
	var changed: WorldState = _clone_world(baseline)
	changed.scenario_id = "test-name-must-not-control-decision"
	changed.find_person(M3FixtureFactory.ACTOR_ID).display_name = "다른 이름"
	var first: DecisionResult = DecisionEngine.evaluate(baseline, M3FixtureFactory.create_request())
	var second: DecisionResult = DecisionEngine.evaluate(changed, M3FixtureFactory.create_request())
	_expect(_decision_core(first) == _decision_core(second), "M3-R03 scenario and display labels do not branch results")


func _test_r04_objective_private_information_boundary() -> void:
	var result_a: DecisionResult = _evaluate_case("C05A")
	var result_b: DecisionResult = _evaluate_case("C05B")
	var result_c: DecisionResult = _evaluate_case("C05C")
	_expect(
		_decision_core(result_a) == _decision_core(result_c),
		"M3-R04 different actual security with identical belief leaves decision core identical"
	)
	_expect(
		_decision_core(result_a) != _decision_core(result_b),
		"M3-R04 changed structured belief is visible to decision mechanics"
	)
	var baseline: WorldState = M3FixtureFactory.create_world("C01")
	var private_changes: WorldState = _clone_world(baseline)
	private_changes.find_resource_store(M3FixtureFactory.GRANARY_ID).quantity = 9999
	private_changes.find_resource_store(M3FixtureFactory.HEAD_STORE_ID).quantity = 0
	private_changes.find_person(M3FixtureFactory.HEAD_ID).need_scores["hunger"] = 100
	private_changes.find_person(M3FixtureFactory.HEAD_ID).health = 1
	var baseline_result: DecisionResult = DecisionEngine.evaluate(
		baseline, M3FixtureFactory.create_request()
	)
	var private_result: DecisionResult = DecisionEngine.evaluate(
		private_changes, M3FixtureFactory.create_request()
	)
	_expect(
		_decision_core(baseline_result) == _decision_core(private_result),
		"M3-R04 external quantity and target private state are not decision inputs"
	)


func _test_structured_fact_validation() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	var duplicate: InformationState = InformationState.from_data(
		world.information[0].to_data(WorldState.SCHEMA_VERSION_M3),
		WorldState.SCHEMA_VERSION_M3
	)
	duplicate.id = "information:999999"
	world.information.append(duplicate)
	world.find_person(M3FixtureFactory.ACTOR_ID).information_ids.append(duplicate.id)
	var errors: Array[String] = StateValidator.validate_world(world)
	var found_duplicate: bool = false
	for error: String in errors:
		found_duplicate = found_duplicate or error.begins_with("duplicate structured information key:")
	_expect(found_duplicate, "M3 schema rejects duplicate owner/type/subject facts")


func _test_schema3_round_trip_and_old_schema_strictness() -> void:
	var world: WorldState = M3FixtureFactory.create_world("C01")
	var encoded: String = StateCodec.encode(
		world, [] as Array[DecisionRecord], [] as Array[ResourceTransactionRecord]
	)
	var decoded: Dictionary = StateCodec.decode(encoded)
	_expect(bool(decoded["ok"]), "M3 schema 3 state round-trips through StateCodec")
	if bool(decoded["ok"]):
		_expect(
			StateHasher.hash_world(decoded["world"]) == StateHasher.hash_world(world),
			"M3 schema 3 round-trip preserves canonical state hash"
		)

	var schema2_payload: Dictionary = StateHasher.state_payload(M2FixtureFactory.create_world())
	var schema2_state: Dictionary = schema2_payload["state"]
	var schema2_stores: Array = schema2_state["resource_stores"]
	var schema2_store: Dictionary = schema2_stores[0]
	schema2_store["security_level"] = 50
	var schema2_errors: Array[String] = StateValidator.validate_envelope(schema2_payload)
	_expect(
		_has_error_containing(schema2_errors, "schema 2 store", "security_level"),
		"M3 schema 2 strictly forbids schema 3 store fields"
	)

	var schema1_fixture: Dictionary = M1FixtureFactory.create()
	var schema1_world: WorldState = schema1_fixture["world"]
	var schema1_payload: Dictionary = StateHasher.state_payload(schema1_world)
	var schema1_state: Dictionary = schema1_payload["state"]
	var schema1_information: Array = schema1_state["information"]
	var schema1_fact: Dictionary = schema1_information[0]
	schema1_fact["belief_value"] = 100
	var schema1_errors: Array[String] = StateValidator.validate_envelope(schema1_payload)
	_expect(
		_has_error_containing(schema1_errors, "schema 1 information", "belief_value"),
		"M3 schema 1 strictly forbids schema 3 fact fields"
	)


func _test_presentation_and_history_are_not_inputs() -> void:
	var baseline: WorldState = M3FixtureFactory.create_world("C01")
	var changed: WorldState = _clone_world(baseline)
	for fact: InformationState in changed.information:
		fact.claim = "completely different presentation text"
	changed.events[0].result_id = "different-history-label"
	var memory: MemoryState = MemoryState.new()
	memory.id = "memory:000001"
	memory.owner_person_id = M3FixtureFactory.ACTOR_ID
	memory.linked_event_id = "event:000001"
	memory.linked_information_id = "information:000001"
	memory.perceived_action_id = "presentation-only-action"
	memory.perceived_result_id = "presentation-only-result"
	memory.related_person_ids = [M3FixtureFactory.HEAD_ID]
	memory.emotion_scores = {"fear": 100}
	memory.importance = 100
	memory.occurred_day_index = 6
	memory.tier = "recent"
	changed.memories.append(memory)
	changed.find_person(M3FixtureFactory.ACTOR_ID).memory_ids.append(memory.id)
	var first: DecisionResult = DecisionEngine.evaluate(baseline, M3FixtureFactory.create_request())
	var second: DecisionResult = DecisionEngine.evaluate(changed, M3FixtureFactory.create_request())
	_expect(
		_decision_core(first) == _decision_core(second),
		"M3 claim and event text do not directly affect decision mechanics"
	)


func _test_ruleset_hash_covers_constants() -> void:
	var rules: Dictionary = M3DecisionRules.to_data()
	var authority: Dictionary = rules["authority"]
	var opportunity_cost: Dictionary = rules["opportunity_cost"]
	var norm_conflict: Dictionary = rules["norm_conflict"]
	_expect(
		str(authority["fact_type_id"]) == M3DecisionRules.FACT_VILLAGE_AUTHORITY,
		"M3 ruleset publishes the authority fact input"
	)
	_expect(
		int(opportunity_cost[M3DecisionRules.ACTION_REQUEST_FOOD])
		== M3DecisionRules.REQUEST_OPPORTUNITY_COST
		and int(opportunity_cost[M3DecisionRules.ACTION_THEFT])
		== M3DecisionRules.THEFT_OPPORTUNITY_COST,
		"M3 ruleset publishes action opportunity costs"
	)
	_expect(
		int(norm_conflict["norm_weight"]) == M3DecisionRules.NORM_WEIGHT
		and int(norm_conflict["duty_weight"]) == M3DecisionRules.DUTY_WEIGHT,
		"M3 ruleset publishes norm-conflict coefficients"
	)
	var changed_rules: Dictionary = rules.duplicate(true)
	changed_rules["near_tie_threshold"] = int(rules["near_tie_threshold"]) + 1
	_expect(
		StateHasher.hash_data({"m3_decision_rules": rules}) == M3DecisionRules.ruleset_hash(),
		"M3 ruleset hash reconstructs from published constants"
	)
	_expect(
		StateHasher.hash_data({"m3_decision_rules": changed_rules}) != M3DecisionRules.ruleset_hash(),
		"M3 ruleset hash changes when a decision constant changes"
	)


func _evaluate_case(case_id: String) -> DecisionResult:
	return DecisionEngine.evaluate(
		M3FixtureFactory.create_world(case_id), M3FixtureFactory.create_request()
	)


func _clone_world(world: WorldState) -> WorldState:
	var payload: Dictionary = StateHasher.state_payload(world)
	return WorldState.from_data(payload, payload["state"])


func _decision_core(result: DecisionResult) -> Dictionary:
	var data: Dictionary = result.to_data()
	data.erase("input_state_hash")
	return StateCanonicalizer.canonicalize(data)


func _find_candidate(
	result: DecisionResult, candidate_id: String
) -> DecisionCandidateEvaluation:
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		if candidate.candidate_id == candidate_id:
			return candidate
	return null


func _find_exclusion(result: DecisionResult, candidate_id: String) -> DecisionExclusion:
	for exclusion: DecisionExclusion in result.excluded_candidates:
		if exclusion.candidate_id == candidate_id:
			return exclusion
	return null


func _count_action(result: DecisionResult, action_id: String) -> int:
	var count: int = 0
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		if candidate.action_id == action_id:
			count += 1
	return count


func _components(candidate: DecisionCandidateEvaluation) -> Array[int]:
	return [
		candidate.need_component,
		candidate.goal_component,
		candidate.value_component,
		candidate.relation_component,
		candidate.expected_benefit_component,
		candidate.risk_component,
		candidate.norm_conflict_component,
		candidate.opportunity_cost_component,
		candidate.utility_scaled,
	]


func _set_fact_belief(world: WorldState, fact_type_id: String, belief_value: int) -> void:
	for fact: InformationState in world.information:
		if fact.fact_type_id == fact_type_id:
			fact.belief_value = belief_value
			return


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _has_error_containing(
	errors: Array[String], first_fragment: String, second_fragment: String
) -> bool:
	for error: String in errors:
		if error.contains(first_fragment) and error.contains(second_fragment):
			return true
	return false


func _require_result(result: DecisionResult, label: String) -> bool:
	_expect(result.ok, "%s evaluation succeeds: %s" % [label, str(result.errors)])
	return result.ok


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
