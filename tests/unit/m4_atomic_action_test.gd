class_name M4AtomicActionTest
extends RefCounted

const ANNEX_SHA256: String = "63a154f947ccbe6309d3d89690dbb7b3d6b1f5bf695356a89dd5ff45028e6819"
const ANNEX_HASH_PATH: String = "res://tests/fixtures/m4_exact_artifacts.sha256"
const LEGACY_M1_PATH: String = "res://tests/fixtures/m1_canonical.json"
const LEGACY_M2_PATH: String = "res://tests/fixtures/m2_day10_canonical.json"
const LEGACY_M3_PATH: String = "res://tests/fixtures/m3_observation_report.json"

var _annex: Dictionary = {}
var _failures: Array[String] = []


func run_all() -> Array[String]:
	_annex = M4FixtureFactory.load_annex()
	_expect(not _annex.is_empty(), "M4 fixture annex parses")
	_test_t01_legacy_artifacts()
	_test_t02_schema4_and_rulesets()
	_test_t03_component_authority()
	_test_t04_provenance_and_mutation()
	_test_t05_information_boundary()
	_test_t06_zero_change_and_replay()
	_test_t06_to_t13_exact_normal_fixtures()
	_test_t08_response_purity()
	_test_t09_theft_formula()
	_test_t10_zero_stock_evidence()
	_test_t11_rng_purpose_independence()
	_test_t14_sequential_day_processing()
	_test_t15_malformed_atomic_rejection()
	_test_t16_context_binding_and_stale()
	_test_t17_artifact_boundaries_and_order()
	_test_t18_frozen_annex_digest()
	_test_t19_rejection_and_invalidation_vectors()
	_test_t20_parameterization_boundaries_and_defaults()
	_test_t21_equal_reason_permutation()
	_test_t22_cross_rank_permutation()
	return _failures


func _test_t01_legacy_artifacts() -> void:
	for path: String in [LEGACY_M1_PATH, LEGACY_M2_PATH]:
		var frozen: String = FileAccess.get_file_as_string(path)
		var decoded: Dictionary = StateCodec.decode(frozen)
		_expect(bool(decoded.get("ok", false)), "M4-T01 legacy save decodes: %s" % path)
		if not bool(decoded.get("ok", false)):
			continue
		var encoded: String = StateCodec.encode(
			decoded.get("world"),
			decoded.get("audit", []),
			decoded.get("resource_audit", [])
		)
		_expect(encoded == frozen, "M4-T01 legacy save is byte-stable: %s" % path)
	var m3_artifacts: Dictionary = M3DecisionEngineTest.new().fixture_artifacts()
	_expect(
		str(m3_artifacts.get("json", "")) == FileAccess.get_file_as_string(LEGACY_M3_PATH),
		"M4-T01 schema 3 decision artifact is frozen"
	)


func _test_t02_schema4_and_rulesets() -> void:
	var expected_rules: Dictionary = _annex.get("rulesets", {})
	_expect_data_equal(
		M4ParameterizationRules.to_data(),
		expected_rules.get("parameterization", {}).get("to_data", {}),
		"M4-T02 parameterization rules exact data"
	)
	_expect_data_equal(
		M4ResponseRules.to_data(),
		expected_rules.get("response", {}).get("to_data", {}),
		"M4-T02 response rules exact data"
	)
	_expect_data_equal(
		M4ResolutionRules.to_data(),
		expected_rules.get("resolution", {}).get("to_data", {}),
		"M4-T02 resolution rules exact data"
	)
	_expect(
		M4ParameterizationRules.ruleset_hash() == M4ParameterizationRules.EXPECTED_HASH,
		"M4-T02 parameterization rules hash"
	)
	_expect(
		M4ResponseRules.ruleset_hash() == M4ResponseRules.EXPECTED_HASH,
		"M4-T02 response rules hash"
	)
	_expect(
		M4ResolutionRules.ruleset_hash() == M4ResolutionRules.EXPECTED_HASH,
		"M4-T02 resolution rules hash"
	)
	_expect_data_equal(
		M4Rules.current_manifest_data(),
		expected_rules.get("manifest", {}),
		"M4-T02 manifest exact data"
	)
	_expect(
		M4Rules.simulation_ruleset_hash(M4Rules.current_manifest_data())
		== M4Rules.SIMULATION_RULESET_HASH,
		"M4-T02 simulation ruleset hash"
	)
	_expect(
		M4Rules.validate_implementation_hashes().is_empty(),
		"M4-T02 runtime rules implement frozen component hashes"
	)

	var fixture: Dictionary = _fixture("F02")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	_expect(StateValidator.validate_world(world).is_empty(), "M4-T02 schema 4 world validates")
	var encoded: String = StateCodec.encode(world, [], [])
	var parsed: Variant = JSON.parse_string(encoded)
	_expect(
		typeof(parsed) == TYPE_DICTIONARY
		and _exact_keys(parsed, [
			"schema_version",
			"ruleset_manifest",
			"simulation_ruleset_hash",
			"state",
			"audit",
			"resource_audit",
			"state_hash",
		]),
		"M4-T02 schema 4 save envelope exact keyset"
	)
	var decoded: Dictionary = StateCodec.decode(encoded)
	_expect(bool(decoded.get("ok", false)), "M4-T02 schema 4 round-trip decodes")
	if bool(decoded.get("ok", false)):
		_expect(
			StateHasher.hash_world(decoded.get("world")) == StateHasher.hash_world(world),
			"M4-T02 schema 4 round-trip hash"
		)
	var missing_score: Dictionary = parsed.duplicate(true)
	var people: Array = missing_score.get("state", {}).get("persons", [])
	var first_person: Dictionary = people[0]
	var aptitude: Dictionary = first_person.get("aptitude_scores", {})
	aptitude.erase("perception")
	_expect(
		not bool(StateCodec.decode(JSON.stringify(missing_score)).get("ok", false)),
		"M4-T02 schema 4 rejects missing aptitude key"
	)
	var extra_root: Dictionary = parsed.duplicate(true)
	extra_root["ruleset_id"] = "forbidden-in-schema-4"
	_expect(
		not bool(StateCodec.decode(JSON.stringify(extra_root)).get("ok", false)),
		"M4-T02 schema 4 rejects legacy top-level ruleset fields"
	)


func _test_t03_component_authority() -> void:
	var world: WorldState = _world("F02")
	var future: WorldState = M4FixtureFactory.clone_world(world)
	var decision_component: Dictionary = future.ruleset_manifest.get("decision", {})
	decision_component["ruleset_hash"] = "0000000000000000000000000000000000000000000000000000000000000000"
	future.simulation_ruleset_hash = M4Rules.simulation_ruleset_hash(future.ruleset_manifest)
	var result: DecisionResult = DecisionEngine.evaluate(
		future, M4FixtureFactory.request("person:000001")
	)
	_expect(not result.ok, "M4-T03 DecisionEngine rejects non-authoritative decision component")
	_expect(
		M4Rules.validate_world_manifest(world, ["decision"]).is_empty(),
		"M4-T03 valid manifest passes component authority"
	)
	var legacy: WorldState = M2FixtureFactory.create_world()
	_expect(
		ResourceService.validate_transactions(legacy, []).is_empty(),
		"M4-T03 legacy ResourceService branch remains valid"
	)


func _test_t04_provenance_and_mutation() -> void:
	var world: WorldState = _world("F02")
	var request: DecisionRequest = M4FixtureFactory.request("person:000001")
	var decision: DecisionResult = DecisionEngine.evaluate(world, request)
	decision.input_state_hash = "0000000000000000000000000000000000000000000000000000000000000000"
	var rejected: ParameterizationResult = IntentParameterizer.parameterize(
		world, request, decision
	)
	_expect(
		not rejected.ok and rejected.errors == ["decision_provenance_mismatch"],
		"M4-T04 altered DecisionResult provenance is rejected"
	)

	decision = DecisionEngine.evaluate(world, request)
	var parameterized: ParameterizationResult = IntentParameterizer.parameterize(
		world, request, decision
	)
	_expect(parameterized.ok, "M4-T04 valid decision parameterizes")
	if not parameterized.ok:
		return
	var intent: ActionIntent = parameterized.intent
	var expected_context: Dictionary = _fixture("F02").get("contexts", [])[0]
	var issuer: TestResolutionContextIssuer = M4FixtureFactory.issuer_for_contexts(
		[expected_context]
	)
	var context: ResolutionContext = issuer.issue_context(world, intent)
	intent.requested_units -= 1
	var batch_request: ResolutionBatchRequest = ResolutionBatchRequest.new()
	batch_request.intents = [intent]
	batch_request.execution_contexts = [context]
	var batch: BatchResolutionRecord = AtomicActionResolver.resolve_trusted_v1(
		world, batch_request, issuer
	)
	_expect(
		batch.batch_status == "REJECTED" and batch.errors == ["intent_hash_mismatch"],
		"M4-T04 trusted-boundary accidental intent mutation is detected"
	)


func _test_t05_information_boundary() -> void:
	var low_stock_world: WorldState = _world("F07")
	var high_stock_world: WorldState = _world("F06C")
	var low_intent: ActionIntent = _parameterize_actor(low_stock_world, "person:000001")
	var high_intent: ActionIntent = _parameterize_actor(high_stock_world, "person:000001")
	_expect(
		low_intent != null
		and high_intent != null
		and low_intent.desired_units == high_intent.desired_units
		and low_intent.parameterization_input_fact_ids == high_intent.parameterization_input_fact_ids,
		"M4-T05 target actual stock is outside parameterization inputs"
	)
	var security_low: ActionIntent = _parameterize_actor(_world("F08L"), "person:000001")
	var security_high: ActionIntent = _parameterize_actor(_world("F08H"), "person:000001")
	_expect(
		security_low != null
		and security_high != null
		and security_low.desired_units == security_high.desired_units,
		"M4-T05 target actual security is outside parameterization inputs"
	)


func _test_t06_zero_change_and_replay() -> void:
	var fixture: Dictionary = _fixture("F01")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var result: BatchResolutionRecord = _execute_fixture_with_order(fixture, world, false)
	_expect(result.batch_status == "COMMITTED", "M4-T06 zero-change action commits")
	if result.next_world == null:
		return
	_expect(
		_resource_quantities(result.next_world) == _resource_quantities(world),
		"M4-T06 A00 does not change resources"
	)
	_expect(
		result.next_world.resolution_epoch == world.resolution_epoch + 1,
		"M4-T06 zero-change commit consumes an epoch"
	)
	_expect(
		result.next_world.resolved_decision_slot_ids.size() == 1,
		"M4-T06 zero-change commit consumes its slot"
	)
	var replay_request: DecisionRequest = M4FixtureFactory.request("person:000001")
	var replay_decision: DecisionResult = DecisionEngine.evaluate(result.next_world, replay_request)
	var replay_parameterization: ParameterizationResult = IntentParameterizer.parameterize(
		result.next_world, replay_request, replay_decision
	)
	_expect(replay_parameterization.ok, "M4-T06 replay attempt can be attributed to stable slot")
	if not replay_parameterization.ok:
		return
	_expect(
		replay_parameterization.intent.action_instance_id
		== result.committed_outcomes[0].action_instance_id,
		"M4-T06 action identity is stable across state hash and epoch changes"
	)
	var issuer: TestResolutionContextIssuer = TestResolutionContextIssuer.new()
	issuer.set_presence(
		replay_parameterization.intent.action_instance_id,
		["person:000001"],
		[]
	)
	var replay: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		result.next_world,
		[DecisionSubmission.create(replay_request, replay_decision)],
		issuer
	)
	_expect(
		replay.batch_status == "REJECTED"
		and replay.errors == ["decision_slot_already_resolved"],
		"M4-T06 consumed decision slot rejects replay"
	)

	var duplicate_world: WorldState = _world("F02")
	var duplicate_submission: DecisionSubmission = _decision_submission(
		duplicate_world, "person:000001"
	)
	var duplicate_intent: ActionIntent = _parameterize_actor(
		duplicate_world, "person:000001"
	)
	var duplicate_issuer: TestResolutionContextIssuer = TestResolutionContextIssuer.new()
	duplicate_issuer.set_presence(
		duplicate_intent.action_instance_id,
		["person:000001", "person:000004"],
		[
			"resource_store:household:000001",
			"resource_store:household:000002",
		]
	)
	var duplicate_batch: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		duplicate_world,
		[duplicate_submission, duplicate_submission],
		duplicate_issuer
	)
	_expect(
		duplicate_batch.errors == ["duplicate_decision_slot_id"],
		"M4-T06 duplicate decision slot rejects the whole batch"
	)


func _test_t06_to_t13_exact_normal_fixtures() -> void:
	for fixture_id: String in [
		"F01", "F02", "F03", "F04", "F05", "F06A", "F06B",
		"F06C", "F07", "F08L", "F08H", "F09",
	]:
		_execute_and_compare_fixture(fixture_id)
	var f09: Dictionary = _fixture("F09")
	var world: WorldState = M4FixtureFactory.world_from_payload(f09.get("input_world", {}))
	var normal: BatchResolutionRecord = _execute_fixture_with_order(f09, world, false)
	var reversed: BatchResolutionRecord = _execute_fixture_with_order(f09, world, true)
	_expect_data_equal(
		normal.to_data(), reversed.to_data(), "M4-T12 batch submission permutation"
	)
	_expect(
		ResourceService.total_quantity(world)
		== ResourceService.total_quantity(normal.next_world),
		"M4-T13 simultaneous transfer conservation"
	)


func _test_t08_response_purity() -> void:
	var world: WorldState = _world("F02")
	var intent: ActionIntent = _parameterize_actor(world, "person:000001")
	var before: String = StateHasher.hash_world(world)
	var first: Dictionary = ResponseEvaluator.evaluate(world, intent)
	var second: Dictionary = ResponseEvaluator.evaluate(world, intent)
	var first_evaluation: ResponseEvaluation = first.get("evaluation")
	var second_evaluation: ResponseEvaluation = second.get("evaluation")
	_expect_data_equal(
		first_evaluation.to_data(), second_evaluation.to_data(),
		"M4-T08 response evaluator is pure"
	)
	_expect(
		first_evaluation.source_store_id == "resource_store:household:000002",
		"M4-T08 request source derives from responder household"
	)
	_expect(StateHasher.hash_world(world) == before, "M4-T08 response evaluation is read-only")


func _test_t09_theft_formula() -> void:
	var fixture: Dictionary = _fixture("F06C")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var result: BatchResolutionRecord = _execute_fixture_with_order(fixture, world, false)
	_expect(
		result.batch_status == "COMMITTED" and not result.committed_outcomes.is_empty(),
		"M4-T09 theft formula produces a committed outcome"
	)
	if result.batch_status != "COMMITTED" or result.committed_outcomes.is_empty():
		return
	var details: Dictionary = result.committed_outcomes[0].details
	_expect(
		int(details.get("desired_units", -1)) == 6
		and int(details.get("attempted_units", -1)) == 6
		and int(details.get("performance_score", -1)) == 58
		and int(details.get("performance_offset", 99)) == -5
		and int(details.get("performance_scale", -1)) == 3
		and int(details.get("proposed_units", -1)) == 0,
		"M4-T09 belief cap, penalties, rounding and performance formula"
	)


func _test_t10_zero_stock_evidence() -> void:
	var fixture: Dictionary = _fixture("F07")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var result: BatchResolutionRecord = _execute_fixture_with_order(fixture, world, false)
	_expect(
		result.batch_status == "COMMITTED" and not result.committed_outcomes.is_empty(),
		"M4-T10 zero-stock attempt produces a committed outcome"
	)
	if result.batch_status != "COMMITTED" or result.committed_outcomes.is_empty():
		return
	var outcome: ActionOutcomeRecord = result.committed_outcomes[0]
	_expect(
		outcome.processing_status == "RESOLVED"
		and outcome.objective_outcome == "NONE"
		and int(outcome.details.get("proposed_units", -1)) == 3
		and int(outcome.details.get("actual_units", -1)) == 0,
		"M4-T10 empty real store remains a resolved failed attempt"
	)
	_expect(
		outcome.details.get("trace_created") == false
		and outcome.witness_evidence_seed_ids.size() == 1
		and result.resource_transactions.is_empty(),
		"M4-T10 zero acquisition still computes trace and witness independently"
	)


func _test_t11_rng_purpose_independence() -> void:
	var world: WorldState = _world("F06C")
	var intent: ActionIntent = _parameterize_actor(world, "person:000001")
	var performance_a: RandomDrawRecord = M4StatelessRng.draw(
		world, intent.action_instance_id, "A11_PERFORMANCE", intent.actor_person_id
	)
	var performance_b: RandomDrawRecord = M4StatelessRng.draw(
		world, intent.action_instance_id, "A11_PERFORMANCE", intent.actor_person_id
	)
	var exposure: RandomDrawRecord = M4StatelessRng.draw(
		world, intent.action_instance_id, "A11_EXPOSURE", intent.actor_person_id
	)
	_expect_data_equal(
		performance_a.to_data(), performance_b.to_data(),
		"M4-T11 stateless roll reproducibility"
	)
	_expect(
		performance_a.digest_hex != exposure.digest_hex,
		"M4-T11 roll purpose has an independent hash domain"
	)


func _test_t14_sequential_day_processing() -> void:
	var fixture: Dictionary = _fixture("F10")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var batch1_data: Dictionary = fixture.get("batch1", {})
	var batch1: BatchResolutionRecord = _execute_single_stage(world, batch1_data)
	_expect_data_equal(
		batch1.to_data(), batch1_data.get("batch", {}), "M4-T14 F10 batch1 exact"
	)
	if batch1.next_world == null:
		return
	var batch2_data: Dictionary = fixture.get("batch2", {})
	var batch2: BatchResolutionRecord = _execute_single_stage(batch1.next_world, batch2_data)
	_expect_data_equal(
		batch2.to_data(), batch2_data.get("batch", {}), "M4-T14 F10 batch2 exact"
	)
	if batch2.next_world == null:
		return
	var day: DayAdvanceResult = DayProcessor.advance_day(batch2.next_world)
	var expected_day: Dictionary = fixture.get("day", {})
	_expect(day.ok, "M4-T14 schema 4 DayProcessor succeeds")
	if not day.ok:
		return
	_expect_data_equal(
		StateHasher.state_payload(day.next_world),
		expected_day.get("world", {}),
		"M4-T14 F10 day world exact"
	)
	_expect_data_equal(
		_resource_data(day.resource_transactions),
		expected_day.get("transactions", []),
		"M4-T14 F10 day transactions exact"
	)
	_expect(
		StateHasher.hash_world(day.next_world) == str(expected_day.get("state_hash", "")),
		"M4-T14 F10 day hash exact"
	)
	var all_transactions: Array[ResourceTransactionRecord] = []
	all_transactions.append_array(batch1.resource_transactions)
	all_transactions.append_array(batch2.resource_transactions)
	all_transactions.append_array(day.resource_transactions)
	var encoded: String = StateCodec.encode(day.next_world, [], all_transactions)
	_expect(
		bool(StateCodec.decode(encoded).get("ok", false)),
		"M4-T14 global sequence counter round-trips with complete ledger"
	)
	var duplicate_global_sequence: ResourceTransactionRecord = ResourceTransactionRecord.from_data(
		all_transactions[0].to_data()
	)
	duplicate_global_sequence.id = "resource_transaction:test:duplicate-global-sequence"
	duplicate_global_sequence.day_index += 1
	var duplicate_sequence_errors: Array[String] = ResourceService.validate_transactions(
		world, [all_transactions[0], duplicate_global_sequence]
	)
	_expect(
		duplicate_sequence_errors.has(
			"duplicate resource transaction sequence identity: %d"
			% all_transactions[0].sequence_index
		),
		"M4-T14 schema 4 sequence identity is global across days"
	)

	var overflow_world: WorldState = _world("F02")
	overflow_world.next_resource_sequence_index = AtomicActionResolver.MAX_STORED_INT
	var overflow_hash: String = StateHasher.hash_world(overflow_world)
	var overflow_day: DayAdvanceResult = DayProcessor.advance_day(overflow_world)
	_expect(
		not overflow_day.ok
		and overflow_day.next_world == null
		and overflow_day.resource_transactions.is_empty()
		and StateHasher.hash_world(overflow_world) == overflow_hash,
		"M4-T14 DayProcessor sequence overflow is atomic"
	)
	overflow_world = _world("F02")
	overflow_world.day_index = AtomicActionResolver.MAX_STORED_INT
	overflow_hash = StateHasher.hash_world(overflow_world)
	overflow_day = DayProcessor.advance_day(overflow_world)
	_expect(
		not overflow_day.ok
		and overflow_day.errors == ["schema 4 day index overflow"]
		and overflow_day.next_world == null
		and StateHasher.hash_world(overflow_world) == overflow_hash,
		"M4-T14 DayProcessor day index overflow is atomic"
	)
	var missing_counter_world: WorldState = _world("F02")
	missing_counter_world.next_ids.erase("resource_transaction")
	var missing_counter_hash: String = StateHasher.hash_world(missing_counter_world)
	var missing_counter_day: DayAdvanceResult = DayProcessor.advance_day(missing_counter_world)
	_expect(
		not missing_counter_day.ok
		and missing_counter_day.errors == ["state.next_ids.resource_transaction is required"]
		and missing_counter_day.next_world == null
		and missing_counter_day.resource_transactions.is_empty()
		and StateHasher.hash_world(missing_counter_world) == missing_counter_hash,
		"M4-T14 missing resource transaction counter is rejected as invalid state"
	)


func _test_t15_malformed_atomic_rejection() -> void:
	var fixture: Dictionary = _fixture("F02")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var before_hash: String = StateHasher.hash_world(world)
	var result: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		world, "not-an-array", null
	)
	_expect(
		result.batch_status == "REJECTED"
		and result.next_world == null
		and result.committed_outcomes.is_empty()
		and result.resource_transactions.is_empty()
		and result.witness_evidence_seeds.is_empty(),
		"M4-T15 malformed batch exposes no committed artifacts"
	)
	_expect(StateHasher.hash_world(world) == before_hash, "M4-T15 rejection leaves world unchanged")

	world = _world("F02")
	world.resolution_epoch = AtomicActionResolver.MAX_STORED_INT
	before_hash = StateHasher.hash_world(world)
	result = _execute_actor_with_presence(
		world,
		"person:000001",
		["person:000001", "person:000004"],
		[
			"resource_store:household:000001",
			"resource_store:household:000002",
		]
	)
	_expect(
		result.batch_status == "REJECTED"
		and result.errors == ["arithmetic_overflow"]
		and StateHasher.hash_world(world) == before_hash,
		"M4-T15 resolution epoch overflow rejects atomically"
	)

	world = _world("F02")
	world.next_resource_sequence_index = AtomicActionResolver.MAX_STORED_INT
	before_hash = StateHasher.hash_world(world)
	result = _execute_actor_with_presence(
		world,
		"person:000001",
		["person:000001", "person:000004"],
		[
			"resource_store:household:000001",
			"resource_store:household:000002",
		]
	)
	_expect(
		result.batch_status == "REJECTED"
		and result.errors == ["resource_sequence_overflow"]
		and StateHasher.hash_world(world) == before_hash,
		"M4-T15 resource sequence overflow rejects atomically"
	)

	world = _world("F02")
	world.day_index = AtomicActionResolver.MAX_STORED_INT
	before_hash = StateHasher.hash_world(world)
	result = _execute_actor_with_presence(
		world,
		"person:000001",
		["person:000001", "person:000004"],
		[
			"resource_store:household:000001",
			"resource_store:household:000002",
		]
	)
	_expect(
		result.batch_status == "REJECTED"
		and result.errors == ["arithmetic_overflow"]
		and StateHasher.hash_world(world) == before_hash,
		"M4-T15 transaction day overflow rejects atomically"
	)


func _test_t16_context_binding_and_stale() -> void:
	var edge: Dictionary = _edge("E03_REJECTED_STALE_CONTEXT_EPOCH")
	var world: WorldState = M4FixtureFactory.world_from_payload(edge.get("input_world", {}))
	var intent: ActionIntent = _parameterize_actor(world, "person:000001")
	var context: ResolutionContext = ResolutionContext.from_data(edge.get("context", {}))
	var issuer: TestResolutionContextIssuer = TestResolutionContextIssuer.new()
	var request: ResolutionBatchRequest = ResolutionBatchRequest.new()
	request.intents = [intent]
	request.execution_contexts = [context]
	var result: BatchResolutionRecord = AtomicActionResolver.resolve_trusted_v1(
		world, request, issuer
	)
	_expect_data_equal(
		result.to_data(), edge.get("batch", {}), "M4-T16 stale epoch rejection exact"
	)

	var valid_issuer: TestResolutionContextIssuer = M4FixtureFactory.issuer_for_contexts(
		[edge.get("context", {})]
	)
	context = valid_issuer.issue_context(world, intent)
	context.context_id = "0000000000000000000000000000000000000000000000000000000000000000"
	request.execution_contexts = [context]
	result = AtomicActionResolver.resolve_trusted_v1(world, request, valid_issuer)
	_expect(result.errors == ["context_id_mismatch"], "M4-T16 context hash binding")

	context = valid_issuer.issue_context(world, intent)
	context.present_person_ids = ["person:000001"]
	context.context_id = context.compute_context_id()
	request.execution_contexts = [context]
	result = AtomicActionResolver.resolve_trusted_v1(world, request, valid_issuer)
	_expect(
		result.errors == ["untrusted_context_issuer"],
		"M4-T16 issuer rejects a self-consistent context it did not issue"
	)

	context = valid_issuer.issue_context(world, intent)
	request.execution_contexts = [context, context]
	result = AtomicActionResolver.resolve_trusted_v1(world, request, valid_issuer)
	_expect(result.errors == ["duplicate_context"], "M4-T16 duplicate context rejection")

	request.execution_contexts = []
	result = AtomicActionResolver.resolve_trusted_v1(world, request, valid_issuer)
	_expect(
		result.errors == ["action_context_set_mismatch"],
		"M4-T16 one-to-one action/context binding"
	)

	context = valid_issuer.issue_context(world, intent)
	context.present_person_ids.reverse()
	context.context_id = context.compute_context_id()
	valid_issuer.register_context_for_testing(context)
	request.execution_contexts = [context]
	result = AtomicActionResolver.resolve_trusted_v1(world, request, valid_issuer)
	_expect(
		result.errors == ["context_person_ids_not_sorted_unique"],
		"M4-T16 context person IDs require canonical order"
	)

	context = valid_issuer.issue_context(world, intent)
	context.present_person_ids.append("person:999999")
	context.present_person_ids.sort()
	context.context_id = context.compute_context_id()
	valid_issuer.register_context_for_testing(context)
	request.execution_contexts = [context]
	result = AtomicActionResolver.resolve_trusted_v1(world, request, valid_issuer)
	_expect(
		result.errors == ["context_missing_person_id"],
		"M4-T16 context rejects a missing person reference"
	)


func _test_t17_artifact_boundaries_and_order() -> void:
	var fixture: Dictionary = _fixture("F09")
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var result: BatchResolutionRecord = _execute_fixture_with_order(fixture, world, true)
	_expect(_outcomes_sorted(result.committed_outcomes), "M4-T17 outcomes sort by action ID")
	_expect(_transactions_sorted_by_id(result.resource_transactions), "M4-T17 transaction artifact sort")
	for outcome: ActionOutcomeRecord in result.committed_outcomes:
		_expect(
			outcome.semantic_resolution_hash == StateHasher.hash_data({
				"algorithm_id": "m4-semantic-resolution-v1",
				"action_outcome": outcome.to_data_without_semantic_resolution_hash(),
			}),
			"M4-T17 semantic hash excludes batch sequencing"
		)
	_expect(
		result.batch_artifact_hash == StateHasher.hash_data({
			"algorithm_id": "m4-batch-artifact-v1",
			"batch_resolution": result.to_data_without_batch_artifact_hash_and_next_world(),
		}),
		"M4-T17 batch hash includes committed transaction records"
	)


func _test_t18_frozen_annex_digest() -> void:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(M4FixtureFactory.ANNEX_PATH))
	var digest: String = context.finish().hex_encode()
	var frozen_digest: String = FileAccess.get_file_as_string(ANNEX_HASH_PATH).strip_edges()
	_expect(frozen_digest == ANNEX_SHA256, "M4-T18 approved annex digest is pinned")
	_expect(digest == frozen_digest, "M4-T18 frozen exact annex SHA-256")


func _test_t19_rejection_and_invalidation_vectors() -> void:
	var invalidated: Dictionary = _edge("E01_INVALIDATED_MULTI_REASON")
	var world: WorldState = M4FixtureFactory.world_from_payload(
		invalidated.get("input_world", {})
	)
	var stage: Dictionary = {
		"decision": invalidated.get("decision", {}),
		"intent": invalidated.get("intent", {}),
		"context": invalidated.get("context", {}),
		"batch": invalidated.get("batch", {}),
	}
	var result: BatchResolutionRecord = _execute_single_stage(world, stage)
	_expect_data_equal(
		result.to_data(), invalidated.get("batch", {}), "M4-T19 INVALIDATED exact vector"
	)
	var rejected_invalid: Dictionary = _edge("E02_REJECTED_INVALID_WORLD")
	result = M4Facade.execute_decisions_v1(
		rejected_invalid.get("submitted_world", {}), [], null
	)
	_expect_data_equal(
		result.to_data(), rejected_invalid.get("batch", {}), "M4-T19 unreadable world sentinel"
	)


func _test_t20_parameterization_boundaries_and_defaults() -> void:
	var defaults_edge: Dictionary = _edge("E04_A04_DEFAULT_PATHS")
	var world: WorldState = M4FixtureFactory.world_from_payload(
		defaults_edge.get("input_world", {})
	)
	_expect(StateValidator.validate_world(world).is_empty(), "M4-T20 E04 input has no dangling relation")
	var stage: Dictionary = {
		"decision": defaults_edge.get("decision", {}),
		"intent": defaults_edge.get("intent", {}),
		"context": defaults_edge.get("context", {}),
		"batch": defaults_edge.get("batch", {}),
	}
	var result: BatchResolutionRecord = _execute_single_stage(world, stage)
	_expect_data_equal(
		result.to_data(), defaults_edge.get("batch", {}), "M4-T20 default path fixture exact"
	)
	var boundaries: Dictionary = _edge("E05_PARAMETERIZATION_BOUNDARIES")
	for vector_value: Variant in boundaries.get("vectors", []):
		var vector: Dictionary = vector_value.duplicate(true)
		var expected_hash: String = str(vector.get("vector_hash", ""))
		vector.erase("vector_hash")
		_expect(
			StateHasher.hash_data({
				"algorithm_id": "m4-parameterization-boundary-vector-v1",
				"vector": vector,
			}) == expected_hash,
			"M4-T20 E05 boundary vector hash: %s" % str(vector.get("id", ""))
		)
	var empty_need: int = IntentParameterizer.calculate_need_basis_from_values([], [], 15)
	_expect(empty_need == 0, "M4-T20 empty alive household need basis is zero")


func _test_t21_equal_reason_permutation() -> void:
	var edge: Dictionary = _edge("E06_FACADE_EQUAL_REASON_PERMUTATION")
	var selected_a: Dictionary = AtomicActionResolver.select_rejection_candidate(
		edge.get("permutation_a", [])
	)
	var selected_b: Dictionary = AtomicActionResolver.select_rejection_candidate(
		edge.get("permutation_b", [])
	)
	_expect_data_equal(selected_a, edge.get("selected_a", {}), "M4-T21 equal-rank selection A")
	_expect_data_equal(selected_b, edge.get("selected_b", {}), "M4-T21 equal-rank selection B")
	var world: WorldState = M4FixtureFactory.world_from_payload(edge.get("input_world", {}))
	var batch_a: BatchResolutionRecord = AtomicActionResolver.reject_candidate(world, selected_a)
	var batch_b: BatchResolutionRecord = AtomicActionResolver.reject_candidate(world, selected_b)
	_expect_data_equal(batch_a.to_data(), edge.get("batch_a", {}), "M4-T21 rejection batch A")
	_expect_data_equal(batch_b.to_data(), edge.get("batch_b", {}), "M4-T21 rejection batch B")

	var facade_world: WorldState = _same_store_request_world()
	var submission_a: DecisionSubmission = _decision_submission(facade_world, "person:000001")
	var submission_b: DecisionSubmission = _decision_submission(facade_world, "person:000002")
	var facade_a: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		facade_world, [submission_a, submission_b], null
	)
	var facade_b: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		facade_world, [submission_b, submission_a], null
	)
	_expect_data_equal(facade_a.to_data(), facade_b.to_data(), "M4-T21 facade permutation exact")
	_expect(
		facade_a.errors == ["request_source_equals_recipient"]
		and not facade_a.attempt_diagnostics.is_empty()
		and facade_a.attempt_diagnostics[0].action_instance_id
		== "c4f1fa79c01b386b0bf3f90723ff1f6002afc37a93a8603f70cb72fd37676414",
		"M4-T21 facade equal rank selects lexicographically lower action ID"
	)


func _test_t22_cross_rank_permutation() -> void:
	var high_rank: Dictionary = {
		"reason_id": "theft_target_equals_recipient",
		"action_instance_id": "0000000000000000000000000000000000000000000000000000000000000001",
	}
	var low_rank: Dictionary = {
		"reason_id": "request_source_equals_recipient",
		"action_instance_id": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
	}
	var selected_a: Dictionary = AtomicActionResolver.select_rejection_candidate(
		[high_rank, low_rank]
	)
	var selected_b: Dictionary = AtomicActionResolver.select_rejection_candidate(
		[low_rank, high_rank]
	)
	_expect(
		selected_a == selected_b
		and selected_a.get("reason_id") == "request_source_equals_recipient",
		"M4-T22 reason precedence beats action ID and input order"
	)
	var world: WorldState = _same_store_request_world()
	var same_store: DecisionSubmission = _decision_submission(world, "person:000001")
	var unsupported_request: DecisionRequest = M4FixtureFactory.request(
		"person:000002", "unsupported_strategy"
	)
	var unsupported: DecisionSubmission = DecisionSubmission.create(
		unsupported_request,
		DecisionEngine.evaluate(world, M4FixtureFactory.request("person:000002"))
	)
	var facade_a: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		world, [same_store, unsupported], null
	)
	var facade_b: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		world, [unsupported, same_store], null
	)
	_expect_data_equal(facade_a.to_data(), facade_b.to_data(), "M4-T22 facade cross-rank permutation")
	_expect(
		facade_a.errors == ["unsupported_decision_key"]
		and not facade_a.attempt_diagnostics.is_empty()
		and facade_a.attempt_diagnostics[0].action_instance_id.is_empty(),
		"M4-T22 facade chooses lower reason precedence with empty action sentinel"
	)


func _execute_and_compare_fixture(fixture_id: String) -> void:
	var fixture: Dictionary = _fixture(fixture_id)
	var world: WorldState = M4FixtureFactory.world_from_payload(fixture.get("input_world", {}))
	var before_hash: String = StateHasher.hash_world(world)
	var expected_decisions: Array = fixture.get("decisions", [])
	var expected_intents: Array = fixture.get("intents", [])
	var expected_contexts: Array = fixture.get("contexts", [])
	var issuer: TestResolutionContextIssuer = M4FixtureFactory.issuer_for_contexts(
		expected_contexts
	)
	var submissions: Array[DecisionSubmission] = []
	for index: int in expected_decisions.size():
		var expected_decision: Dictionary = expected_decisions[index]
		var actor_id: String = str(expected_decision.get("actor_person_id", ""))
		var request: DecisionRequest = M4FixtureFactory.request(actor_id)
		var decision: DecisionResult = DecisionEngine.evaluate(world, request)
		_expect_data_equal(
			decision.to_data(), expected_decision,
			"M4-T06..T13 %s decision %s" % [fixture_id, actor_id]
		)
		var parameterization: ParameterizationResult = IntentParameterizer.parameterize(
			world, request, decision
		)
		_expect(parameterization.ok, "M4-T06..T13 %s parameterizes %s" % [fixture_id, actor_id])
		if parameterization.ok:
			_expect_data_equal(
				parameterization.intent.to_data(), expected_intents[index],
				"M4-T06..T13 %s intent %s" % [fixture_id, actor_id]
			)
			var context: ResolutionContext = issuer.issue_context(world, parameterization.intent)
			var expected_context: Dictionary = _find_by_action_id(
				expected_contexts, parameterization.intent.action_instance_id
			)
			_expect_data_equal(
				context.to_data(), expected_context,
				"M4-T06..T13 %s context %s" % [fixture_id, actor_id]
			)
		submissions.append(DecisionSubmission.create(request, decision))
	var result: BatchResolutionRecord = M4Facade.execute_decisions_v1(
		world, submissions, issuer
	)
	_expect_data_equal(
		result.to_data(), fixture.get("batch", {}),
		"M4-T06..T13 %s complete batch" % fixture_id
	)
	_expect(StateHasher.hash_world(world) == before_hash, "M4 %s input world immutable" % fixture_id)


func _execute_fixture_with_order(
	fixture: Dictionary, world: WorldState, reverse_order: bool
) -> BatchResolutionRecord:
	var contexts: Array = fixture.get("contexts", [])
	var issuer: TestResolutionContextIssuer = M4FixtureFactory.issuer_for_contexts(contexts)
	var submissions: Array[DecisionSubmission] = []
	for decision_value: Variant in fixture.get("decisions", []):
		var decision_data: Dictionary = decision_value
		var request: DecisionRequest = M4FixtureFactory.request(
			str(decision_data.get("actor_person_id", ""))
		)
		var decision: DecisionResult = DecisionEngine.evaluate(world, request)
		submissions.append(DecisionSubmission.create(request, decision))
	if reverse_order:
		submissions.reverse()
	return M4Facade.execute_decisions_v1(world, submissions, issuer)


func _execute_single_stage(world: WorldState, stage: Dictionary) -> BatchResolutionRecord:
	var expected_decision: Dictionary = stage.get("decision", {})
	var actor_id: String = str(expected_decision.get("actor_person_id", ""))
	var request: DecisionRequest = M4FixtureFactory.request(actor_id)
	var decision: DecisionResult = DecisionEngine.evaluate(world, request)
	var expected_context: Dictionary = stage.get("context", {})
	var issuer: TestResolutionContextIssuer = M4FixtureFactory.issuer_for_contexts(
		[expected_context]
	)
	return M4Facade.execute_decisions_v1(
		world, [DecisionSubmission.create(request, decision)], issuer
	)


func _parameterize_actor(world: WorldState, actor_id: String) -> ActionIntent:
	var request: DecisionRequest = M4FixtureFactory.request(actor_id)
	var decision: DecisionResult = DecisionEngine.evaluate(world, request)
	var result: ParameterizationResult = IntentParameterizer.parameterize(
		world, request, decision
	)
	return result.intent if result.ok else null


func _decision_submission(world: WorldState, actor_id: String) -> DecisionSubmission:
	var request: DecisionRequest = M4FixtureFactory.request(actor_id)
	return DecisionSubmission.create(request, DecisionEngine.evaluate(world, request))


func _execute_actor_with_presence(
	world: WorldState,
	actor_id: String,
	present_person_ids: Array[String],
	present_store_ids: Array[String]
) -> BatchResolutionRecord:
	var intent: ActionIntent = _parameterize_actor(world, actor_id)
	if intent == null:
		return BatchResolutionRecord.rejected(world, "decision_provenance_mismatch")
	var issuer: TestResolutionContextIssuer = TestResolutionContextIssuer.new()
	issuer.set_presence(intent.action_instance_id, present_person_ids, present_store_ids)
	return M4Facade.execute_decisions_v1(
		world, [_decision_submission(world, actor_id)], issuer
	)


func _same_store_request_world() -> WorldState:
	var world: WorldState = _world("F02")
	var first_household: HouseholdState = world.find_household("household:000001")
	var second_household: HouseholdState = world.find_household("household:000002")
	var responder: PersonState = world.find_person("person:000004")
	responder.household_id = first_household.id
	first_household.member_ids.append(responder.id)
	first_household.member_ids.sort()
	second_household.member_ids = []
	var request_types: Array[String] = [
		"request_food_access",
		"request_food_capacity",
		"request_success_expectation",
		"request_social_risk",
	]
	var beliefs: Array[int] = [100, 60, 50, 25]
	var confidences: Array[int] = [100, 80, 80, 80]
	for index: int in request_types.size():
		var fact: InformationState = world.information[10 + index]
		fact.fact_type_id = request_types[index]
		fact.subject_kind = "person"
		fact.subject_id = responder.id
		fact.belief_value = beliefs[index]
		fact.confidence = confidences[index]
	var authority: InformationState = world.information[14]
	authority.fact_type_id = "village_authority"
	authority.subject_kind = "person"
	authority.subject_id = responder.id
	authority.belief_value = 100
	authority.confidence = 100
	return world


func _fixture(fixture_id: String) -> Dictionary:
	return _annex.get("fixtures", {}).get(fixture_id, {})


func _edge(edge_id: String) -> Dictionary:
	return _annex.get("edge_fixtures", {}).get(edge_id, {})


func _world(fixture_id: String) -> WorldState:
	return M4FixtureFactory.world_from_payload(_fixture(fixture_id).get("input_world", {}))


func _find_by_action_id(values: Array, action_instance_id: String) -> Dictionary:
	for value: Variant in values:
		var data: Dictionary = value
		if str(data.get("action_instance_id", "")) == action_instance_id:
			return data
	return {}


func _resource_data(records: Array[ResourceTransactionRecord]) -> Array:
	var data: Array = []
	for record: ResourceTransactionRecord in records:
		data.append(record.to_data())
	return data


func _resource_quantities(world: WorldState) -> Dictionary:
	var quantities: Dictionary = {}
	for store: ResourceStoreState in world.resource_stores:
		quantities[store.id] = store.quantity
	return quantities


func _outcomes_sorted(outcomes: Array[ActionOutcomeRecord]) -> bool:
	for index: int in range(1, outcomes.size()):
		if outcomes[index].action_instance_id <= outcomes[index - 1].action_instance_id:
			return false
	return true


func _transactions_sorted_by_id(records: Array[ResourceTransactionRecord]) -> bool:
	for index: int in range(1, records.size()):
		if records[index].id <= records[index - 1].id:
			return false
	return true


func _exact_keys(data: Dictionary, keys: Array[String]) -> bool:
	if data.size() != keys.size():
		return false
	for key: String in keys:
		if not data.has(key):
			return false
	return true


func _expect_data_equal(actual: Variant, expected: Variant, label: String) -> void:
	var actual_json: String = StateCanonicalizer.canonical_json(actual)
	var expected_json: String = StateCanonicalizer.canonical_json(expected)
	if actual_json == expected_json:
		return
	if (
		typeof(actual) == TYPE_DICTIONARY
		and typeof(expected) == TYPE_DICTIONARY
		and (actual as Dictionary).has("batch_artifact_hash")
		and (expected as Dictionary).has("batch_artifact_hash")
	):
		var actual_without_hash: Dictionary = (actual as Dictionary).duplicate(true)
		var expected_without_hash: Dictionary = (expected as Dictionary).duplicate(true)
		actual_without_hash.erase("batch_artifact_hash")
		expected_without_hash.erase("batch_artifact_hash")
		if (
			StateCanonicalizer.canonical_json(actual_without_hash)
			!= StateCanonicalizer.canonical_json(expected_without_hash)
		):
			_failures.append(
				"%s differs beyond batch hash at %s"
				% [label, _first_difference(actual_without_hash, expected_without_hash, "$", 0)]
			)
			return
	_failures.append(
		"%s differs at %s" % [label, _first_difference(actual, expected, "$", 0)]
	)


func _first_difference(actual: Variant, expected: Variant, path: String, depth: int) -> String:
	if depth > 30:
		return path
	if typeof(actual) != typeof(expected):
		return "%s (type %d != %d)" % [path, typeof(actual), typeof(expected)]
	if typeof(actual) == TYPE_DICTIONARY:
		var actual_dictionary: Dictionary = actual
		var expected_dictionary: Dictionary = expected
		var keys: Array[String] = []
		for key: Variant in actual_dictionary.keys():
			if not keys.has(str(key)):
				keys.append(str(key))
		for key: Variant in expected_dictionary.keys():
			if not keys.has(str(key)):
				keys.append(str(key))
		keys.sort()
		for key: String in keys:
			if not actual_dictionary.has(key) or not expected_dictionary.has(key):
				return "%s.%s (missing key)" % [path, key]
			if actual_dictionary[key] != expected_dictionary[key]:
				return _first_difference(
					actual_dictionary[key], expected_dictionary[key], "%s.%s" % [path, key], depth + 1
				)
		return path
	if typeof(actual) == TYPE_ARRAY:
		var actual_array: Array = actual
		var expected_array: Array = expected
		if actual_array.size() != expected_array.size():
			return "%s (array size %d != %d)" % [path, actual_array.size(), expected_array.size()]
		for index: int in actual_array.size():
			if actual_array[index] != expected_array[index]:
				return _first_difference(
					actual_array[index], expected_array[index], "%s[%d]" % [path, index], depth + 1
				)
		return path
	return "%s (%s != %s)" % [path, str(actual), str(expected)]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
