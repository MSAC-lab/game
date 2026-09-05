class_name M60AutonomyTest
extends RefCounted

var checks: int = 0
var failures: Array[String] = []
var completed_groups: Array[String] = []
var runtime_evidence: Dictionary = {}
var _group_completed: bool = false


func run_all() -> Array[String]:
	for method: String in ["_observed_compatibility", "_entry_contract", "_fixed_presence", "_manual_and_no_actors",
		"_atomic_failures", "_checkpoint_rejections", "_repeat_and_resume"]:
		_group_completed = false
		call(method)
		_expect(_group_completed, "group completed: " + method)
		if _group_completed:
			completed_groups.append(method)
	runtime_evidence.completed_groups = completed_groups.duplicate()
	return failures


func _observed_compatibility() -> void:
	var records: Array = []
	for mode: String in ["A04", "A00", "INVALIDATED", "A11", "M4_REJECTED", "LATE_OVERFLOW", "BATCH_CORRUPT", "EARLY"]:
		var world: WorldState = M60FixtureFactory.theft() if mode == "A11" else M5FixtureFactory.initial()
		var config: Dictionary = M60FixtureFactory.isolated(world) if mode == "INVALIDATED" else M60FixtureFactory.config(world)
		if mode == "LATE_OVERFLOW":
			world.next_ids.memory = M5Data.MAX_INT
		var actor: String = "person:000004" if mode == "A00" else "person:000001"
		var submissions: Array = [] if mode == "EARLY" else [M5FixtureFactory.submission(world, actor)]
		var issuer: ResolutionContextIssuer = ResolutionContextIssuer.new() if mode == "M4_REJECTED" else M60PresenceIssuer.create(world, config)
		var before: String = StateCanonicalizer.canonical_json(StateHasher.state_payload(world))
		var legacy: M60M5Probe = M60M5Probe.new()
		var observed: M60M5Probe = M60M5Probe.new()
		if mode == "BATCH_CORRUPT":
			legacy.fault = "FAR-03"
			observed.fault = "FAR-03"
		var old: M5OperationResult = legacy._run("EXECUTE", world, M5RequestStamp.for_world(world), submissions, issuer)
		var value: M5ObservedExecutionResult = observed._run_observed(world, M5RequestStamp.for_world(world), submissions, issuer)
		_equal(value.operation_result.to_data(), old.to_data(), mode + " old/new canonical return equality")
		_equal(observed.kernel_calls, 0 if mode == "EARLY" else 1, mode + " actual kernel runs once")
		_equal(StateCanonicalizer.canonical_json(StateHasher.state_payload(world)), before, mode + " input unchanged")
		_equal(M60Evidence.validate_m4(value.m4_batch_artifact, value.operation_result.artifact), "", mode + " native hash binding")
		if mode in ["EARLY", "BATCH_CORRUPT"]:
			_expect(value.m4_batch_artifact == null and not value.operation_result.ok, mode + " no validated batch exposed")
		else:
			var body: Dictionary = value.m4_batch_artifact.batch_resolution
			_expect(not body.has("next_world"), mode + " no intermediate world")
			_equal(body.batch_status, "REJECTED" if mode == "M4_REJECTED" else "COMMITTED", mode + " native status preserved")
			if mode == "M4_REJECTED":
				_expect(not value.operation_result.ok and not body.errors.is_empty() and body.attempt_diagnostics.size() == 1, "native rejection diagnostic captured")
			else:
				_equal(body.committed_outcomes.size(), 1, mode + " complete outcome captured")
				var outcome: Dictionary = body.committed_outcomes[0]
				if mode == "INVALIDATED":
					_equal(outcome.processing_status, "INVALIDATED", "individual invalidation is committed")
					_expect(not outcome.invalidation_reason_ids.is_empty() and value.operation_result.ok, "invalidation reason preserved")
				elif mode in ["A00", "A04", "A11"]:
					_equal(outcome.action_id, mode, mode + " native choice")
				var raw_before: String = StateCanonicalizer.canonical_json(value.m4_batch_artifact)
				observed.batch_reference.committed_outcomes[0].details["detachment_probe"] = 1
				_equal(StateCanonicalizer.canonical_json(value.m4_batch_artifact), raw_before, mode + " raw detached from kernel object")
			records.append({"id": mode, "result": value.to_data(), "kernel_calls": observed.kernel_calls})
	runtime_evidence.observed_compatibility = records
	_group_completed = true


func _entry_contract() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var config: Dictionary = M60FixtureFactory.config(world)
	var zero: M60RunResult = M60Runner.run_v1(world, config, 0)
	_expect(zero.ok and zero.advanced_days == 0 and not zero.checkpoint_json.is_empty(), "zero-day initial checkpoint")
	for count: Variant in [-1, 367, 1.0, "1", null, true]:
		var result: M60RunResult = M60Runner.run_v1(world, config, count)
		_expect(result.status == "REJECTED" and result.next_world == null, "invalid day count " + str(count))
	for key: String in config.keys():
		var broken: Dictionary = config.duplicate(true)
		broken.erase(key)
		_expect(M60Runner.run_v1(world, broken, 0).status == "REJECTED", "required config " + key)
	for key: String in ["runner_version", "initial_state_hash", "simulation_ruleset_hash", "automatic_person_ids", "person_sites", "store_sites", "contacts"]:
		var broken: Dictionary = config.duplicate(true)
		broken[key] = null
		_expect(M60Runner.run_v1(world, broken, 0).status == "REJECTED", "typed config " + key)
	for mode: String in ["duplicate_actor", "unknown_actor", "duplicate_pair", "reverse_pair", "foreign_site", "unknown_person", "missing_store", "blank_site", "unknown_key", "wrong_initial", "version"]:
		var broken: Dictionary = config.duplicate(true)
		match mode:
			"duplicate_actor": broken.automatic_person_ids.append(broken.automatic_person_ids[0])
			"unknown_actor": broken.automatic_person_ids.append("person:999999")
			"duplicate_pair": broken.contacts.append(broken.contacts[0].duplicate(true))
			"reverse_pair": broken.contacts[0].person_a_id = broken.contacts[0].person_b_id
			"foreign_site": broken.person_sites["person:000002"] = "site:elsewhere"
			"unknown_person": broken.person_sites["person:999999"] = "site:village"
			"missing_store": broken.store_sites.erase(broken.store_sites.keys()[0])
			"blank_site": broken.store_sites[broken.store_sites.keys()[0]] = " "
			"unknown_key": broken.extra = 1
			"wrong_initial": broken.initial_state_hash = "0".repeat(64)
			"version": broken.runner_version = "m6-0-runner-v2"
		_expect(M60Runner.run_v1(world, broken, 0).status == "REJECTED", "config rejection " + mode)
	for kind: String in ["A00", "INVALIDATED", "CONTACTS_EMPTY", "CONTACTS_PAIRS"]:
		var middle: M5OperationResult
		if kind.begins_with("CONTACTS"):
			var plan: SocialContactPlan = M60Config.contact_plan(config, world) if kind == "CONTACTS_PAIRS" else SocialContactPlan.new()
			middle = M5Facade.process_contacts_v1(world, M5RequestStamp.for_world(world), plan)
		else:
			var actor: String = "person:000004" if kind == "A00" else "person:000001"
			middle = M5Facade.execute_decisions_v1(world, M5RequestStamp.for_world(world), [M5FixtureFactory.submission(world, actor)], M60PresenceIssuer.create(world, M60FixtureFactory.isolated(world)))
		_expect(middle.ok, kind + " valid M5 mid-day world")
		if not middle.ok:
			return
		var declared: Dictionary = M60FixtureFactory.config(middle.next_world)
		var rejected: M60RunResult = M60Runner.run_v1(middle.next_world, declared, 0)
		_expect(rejected.status == "REJECTED" and rejected.error.code == "M60_INPUT_WORLD", kind + " fresh entry still rejects mid-day")
		_expect(not M60Checkpoint.encode(declared.initial_state_hash, declared, middle.next_world, []).ok, kind + " save boundary rejects")
	var malformed: WorldState = M5FixtureFactory.initial()
	malformed.social_state.last_integrated_resolution_epoch = 1
	_expect(M60Runner.run_v1(malformed, config, 0).status == "REJECTED", "unsynchronized epoch rejected")
	_expect(M60Runner.run_v1(null, config, 0).status == "REJECTED", "null world rejected")
	_group_completed = true


func _fixed_presence() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var config: Dictionary = M60FixtureFactory.isolated(world)
	config.store_sites["resource_store:village_granary"] = "site:granary"
	var sub: DecisionSubmission = M5FixtureFactory.submission(world, "person:000001")
	var intent: ActionIntent = IntentParameterizer.parameterize(world, sub.decision_request, sub.submitted_decision_result).intent
	var issuer: M60PresenceIssuer = M60PresenceIssuer.create(world, config)
	var context: ResolutionContext = issuer.issue_context(world, intent)
	_expect(context != null and issuer.owns_context(context), "production context owned")
	_equal(context.present_person_ids, ["person:000001", "person:000002", "person:000003"], "fixed people only")
	_expect(not context.present_person_ids.has(intent.target_person_id), "selected target cannot enter site")
	_expect(not context.present_store_ids.has("resource_store:village_granary"), "remote store absent")
	config.person_sites["person:000004"] = "site:village"
	_equal(issuer.issue_context(world, intent).present_person_ids, context.present_person_ids, "issuer copied configuration")
	context.present_person_ids.append("person:000004")
	_expect(not issuer.owns_context(context), "edited context not owned")
	var altered: WorldState = M5Data.clone(world)
	altered.resource_stores[0].quantity += 1
	_expect(issuer.issue_context(altered, intent) == null, "issuer rejects different world")
	var invalidated: M60RunResult = M60Runner.run_v1(world, M60FixtureFactory.isolated(world), 1)
	_expect(invalidated.ok, "individual INVALIDATED permits contacts and close")
	if not invalidated.ok:
		return
	var outcome: Dictionary = invalidated.days[0].m4_batch_artifact.batch_resolution.committed_outcomes[0]
	_equal(outcome.processing_status, "INVALIDATED", "no invented target presence")
	_equal(invalidated.next_world.events.size(), world.events.size(), "invalidation makes no event")
	var theft: WorldState = M60FixtureFactory.theft()
	var thief_config: Dictionary = M60FixtureFactory.isolated(theft)
	thief_config.person_sites["person:000002"] = "site:remote"
	thief_config.person_sites["person:000003"] = "site:remote"
	var theft_run: M60RunResult = M60Runner.run_v1(theft, thief_config, 1)
	_expect(theft_run.ok, "native theft in fixed site")
	if not theft_run.ok:
		return
	var theft_body: Dictionary = theft_run.days[0].m4_batch_artifact.batch_resolution
	_equal(theft_body.committed_outcomes[0].action_id, "A11", "native theft fixture choice")
	_equal(theft_body.witness_evidence_seeds, [], "outside people never witness")
	for obs: SocialObservationState in theft_run.next_world.social_observations:
		_expect(obs.owner_person_id == "person:000001", "no contact, no remote report")
	runtime_evidence.fixed_presence = {"invalidated": invalidated.to_data(), "theft": theft_run.to_data()}
	_group_completed = true


func _manual_and_no_actors() -> void:
	var initial: WorldState = M5FixtureFactory.initial()
	var config: Dictionary = M60FixtureFactory.config(initial)
	var run: M60RunResult = M60Runner.run_v1(initial, config, 1)
	_expect(run.ok, "automatic one day completes")
	if not run.ok:
		return
	var submissions: Array = []
	for actor: String in ["person:000001", "person:000002", "person:000004"]:
		submissions.append(M5FixtureFactory.submission(initial, actor))
	var manual: M5OperationResult = M5Facade.execute_decisions_v1(initial, M5RequestStamp.for_world(initial), submissions, M60PresenceIssuer.create(initial, config))
	_expect(manual.ok, "manual execute")
	_equal(run.days[0].operations[0], M60Evidence.operation("1:EXECUTE", manual), "single batch matches manual public M5")
	for i: int in submissions.size():
		_equal(run.days[0].decisions[i], submissions[i].submitted_decision_result.to_data(), "same start snapshot actor %d" % i)
	var contact: M5OperationResult = M5Facade.process_contacts_v1(manual.next_world, M5RequestStamp.for_world(manual.next_world), M60Config.contact_plan(config, manual.next_world))
	var closed: M5OperationResult = M5Facade.close_day_v1(contact.next_world, M5RequestStamp.for_world(contact.next_world))
	_expect(closed.ok, "manual close")
	_equal(StateHasher.state_payload(run.next_world), StateHasher.state_payload(closed.next_world), "whole day matches public calls")
	_equal(run.days[0].operations[1], M60Evidence.operation("2:CONTACTS", contact), "manual contact record")
	_equal(run.days[0].operations[2], M60Evidence.operation("3:CLOSE", closed), "manual close record")
	for with_pairs: bool in [false, true]:
		var inactive: Dictionary = config.duplicate(true)
		inactive.automatic_person_ids = []
		if not with_pairs:
			inactive.contacts = []
		var probe: M60ProbeRunner = M60ProbeRunner.new()
		var result: M60RunResult = probe._run(initial, inactive, 1)
		_expect(result.ok and probe.calls == 0, "empty cohort skips kernel only")
		if not result.ok:
			return
		_equal(result.days[0].action_status, "SKIPPED_NO_ACTORS", "explicit skip record")
		_expect(result.days[0].m4_batch_artifact == null, "skipped raw is null")
		_equal(result.days[0].contact_plan.pairs.size(), 3 if with_pairs else 0, "contact pairs independent of cohort")
		_equal(result.next_world.resolution_epoch, initial.resolution_epoch, "skip no action epoch")
		_equal(result.next_world.social_state.revision, 2, "contacts and close each execute")
		var expected_contact: M5OperationResult = M5Facade.process_contacts_v1(initial, M5RequestStamp.for_world(initial), M60Config.contact_plan(inactive, initial))
		var expected_close: M5OperationResult = M5Facade.close_day_v1(expected_contact.next_world, M5RequestStamp.for_world(expected_contact.next_world))
		_equal(StateHasher.state_payload(result.next_world), StateHasher.state_payload(expected_close.next_world), "empty cohort manual equality")
		_expect(result.next_world.find_person("person:000003").need_scores.hunger < initial.find_person("person:000003").need_scores.hunger, "passive child still eats")
		_expect(M60Runner.run_v1(initial, inactive, 0, result.checkpoint_json).ok, "empty cohort checkpoint resumes")
	_group_completed = true


func _atomic_failures() -> void:
	var world: WorldState = M60FixtureFactory.starvation()
	var config: Dictionary = M60FixtureFactory.config(world)
	var before: String = StateHasher.hash_world(world)
	var stopped: M60RunResult = M60Runner.run_v1(world, config, 3)
	_expect(stopped.status == "STOPPED" and not stopped.ok and stopped.advanced_days == 0 and stopped.days.is_empty(), "health boundary stops without day commit")
	if stopped.failed_day == null:
		_expect(false, "failed day evidence exists")
		return
	_equal(StateHasher.hash_world(stopped.next_world), before, "health failure keeps initial completed boundary")
	_equal(StateHasher.hash_world(world), before, "health failure leaves input unchanged")
	_equal(stopped.failed_day.day_status, "ABORTED", "outer day aborted")
	_equal(stopped.failed_day.m4_batch_artifact.batch_resolution.batch_status, "COMMITTED", "inner M4 commit not rewritten")
	_equal(stopped.error.phase, "CLOSE", "raw failure phase")
	_equal(stopped.error.details[0].code, "M5_POST_APPLY_INVARIANT", "native error not reclassified as death")
	_equal(stopped.error.details[0].field_path, "state.persons.health", "native health path preserved")
	_equal(stopped.error.details[0].entity_id, "person:000003", "native health entity preserved")
	var resumed: M60RunResult = M60Runner.run_v1(world, config, 3, stopped.checkpoint_json)
	_equal(resumed.to_data(), stopped.to_data(), "failed-day retry reproduces exactly")
	runtime_evidence.expected_health_stop = stopped.to_data()
	var initial: WorldState = M5FixtureFactory.initial()
	for fault: String in ["MISSING", "HASH", "BODY", "M4_REJECTED"]:
		var probe: M60ProbeRunner = M60ProbeRunner.new()
		probe.fault = fault
		var result: M60RunResult = probe._run(initial, M60FixtureFactory.config(initial), 1)
		_expect(not result.ok and result.status == "STOPPED" and result.advanced_days == 0, fault + " day aborted")
		_equal(probe.calls, 1, fault + " no retry")
		_equal(StateHasher.hash_world(result.next_world), StateHasher.hash_world(initial), fault + " no partial world")
		_equal(result.error.code, "M60_M5_REJECTED" if fault == "M4_REJECTED" else "M60_EVIDENCE_BINDING", fault + " explicit failure class")
		if fault == "M4_REJECTED":
			_equal(result.failed_day.m4_batch_artifact.batch_resolution.batch_status, "REJECTED", "rejected kernel raw retained")
	var overflow: WorldState = M5FixtureFactory.initial()
	overflow.next_ids.memory = M5Data.MAX_INT
	var failed: M60RunResult = M60Runner.run_v1(overflow, M60FixtureFactory.config(overflow), 1)
	_expect(failed.status == "STOPPED" and failed.advanced_days == 0, "late M5 failure aborts day")
	_equal(failed.failed_day.m4_batch_artifact.batch_resolution.batch_status, "COMMITTED", "late M5 failure retains raw")
	_equal(failed.error.details[0].code, "M5_ARITHMETIC_OVERFLOW", "late M5 overflow diagnostic")
	var contact_limit: WorldState = M5FixtureFactory.initial()
	contact_limit.social_state.revision = M5Data.MAX_INT - 1
	var limit_config: Dictionary = M60FixtureFactory.config(contact_limit)
	limit_config.automatic_person_ids = ["person:000004"]
	var contact_failure: M60RunResult = M60Runner.run_v1(contact_limit, limit_config, 1)
	_expect(contact_failure.status == "STOPPED" and contact_failure.error.phase == "CONTACTS", "contact failure after action commit")
	_equal(StateHasher.hash_world(contact_failure.next_world), StateHasher.hash_world(contact_limit), "contact failure rolls back action slot and epoch")
	_equal(contact_failure.failed_day.m4_batch_artifact.batch_resolution.batch_status, "COMMITTED", "contact failure preserves native action commit")
	_group_completed = true


func _checkpoint_rejections() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var config: Dictionary = M60FixtureFactory.config(world)
	var run: M60RunResult = M60Runner.run_v1(world, config, 1)
	_expect(run.ok, "checkpoint test prerequisite")
	if not run.ok:
		return
	var checkpoint: Dictionary = M5JsonReader.parse(run.checkpoint_json).value
	for mode: String in ["checksum", "config_hash", "config_body", "version", "world_hash", "initial", "boundary", "dropped_day", "bad_row", "raw", "decision", "contact", "resource", "midday"]:
		var data: Dictionary = checkpoint.duplicate(true)
		match mode:
			"checksum": data.checkpoint_hash = "0".repeat(64)
			"config_hash": data.config_hash = "0".repeat(64)
			"config_body": data.config.automatic_person_ids = []
			"version": data.algorithm_id = "future"
			"world_hash": data.world_save.state_hash = "0".repeat(64)
			"initial": data.initial_state_hash = "0".repeat(64)
			"boundary": data.boundary_kind = "INITIAL"
			"dropped_day": data.days = []
			"bad_row": data.days[0].extra = 1
			"raw": data.days[0].m4_batch_artifact = null
			"decision": data.days[0].decisions[0].input_state_hash = "0".repeat(64)
			"contact": data.days[0].contact_plan.pairs = []
			"resource": data.days[0].operations[-1].resource_transactions[0].quantity = -1
			"midday":
				var contacts: M5OperationResult = M5Facade.process_contacts_v1(run.next_world, M5RequestStamp.for_world(run.next_world), SocialContactPlan.new())
				data.world_save = M5JsonReader.parse(M5SaveCodec.encode_checked(contacts.next_world).json_text).value
		if mode in ["bad_row", "raw", "decision", "contact", "resource"]:
			data.days[0] = M60Evidence.finish(data.days[0])
		if mode != "checksum":
			data.erase("checkpoint_hash")
			data.checkpoint_hash = StateHasher.hash_data(data)
		var rejected: M60RunResult = M60Runner.run_v1(world, config, 1, StateCanonicalizer.canonical_json(data))
		_expect(rejected.status == "REJECTED" and rejected.next_world == null and rejected.advanced_days == 0, "checkpoint corruption " + mode)
	for text: String in ["{}", "[]", "null", "{\"x\":1,\"x\":2}", run.checkpoint_json.replace('"day_index":0', '"day_index":0.0')]:
		_expect(M60Runner.run_v1(world, config, 0, text).status == "REJECTED", "strict checkpoint wire rejects")
	var different: Dictionary = config.duplicate(true)
	different.automatic_person_ids = []
	_expect(M60Runner.run_v1(world, different, 1, run.checkpoint_json).status == "REJECTED", "expected config binding rejects changed cohort")
	var different_seed: WorldState = M5Data.clone(world)
	different_seed.rng_seed_hex = "1".repeat(16)
	_expect(M60Runner.run_v1(different_seed, M60FixtureFactory.config(different_seed), 1, run.checkpoint_json).status == "REJECTED", "different initial world rejected")
	_group_completed = true


func _repeat_and_resume() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var config: Dictionary = M60FixtureFactory.config(world)
	var before: String = StateCanonicalizer.canonical_json(StateHasher.state_payload(world))
	var first: M60RunResult = M60Runner.run_v1(world, config, 28)
	_expect(first.next_world != null and first.days.size() > 1, "28-day observation produces completed history")
	var repeated: M60RunResult = M60Runner.run_v1(world, config, 28)
	_equal(first.to_data(), repeated.to_data(), "repeat full observation bytes")
	_equal(first.checkpoint_json, repeated.checkpoint_json, "repeat checkpoint bytes")
	var split: M60RunResult = M60Runner.run_v1(world, config, 7)
	_expect(split.ok, "first seven days complete")
	var resumed: M60RunResult = M60Runner.run_v1(world, config, 21, split.checkpoint_json)
	_equal(resumed.days, first.days, "resume full day ledger equality")
	_equal(resumed.failed_day, first.failed_day, "resume failed day equality")
	_equal(resumed.checkpoint_json, first.checkpoint_json, "resume checkpoint byte equality")
	_equal(StateHasher.state_payload(resumed.next_world), StateHasher.state_payload(first.next_world), "resume final world equality")
	var reordered: WorldState = M5Data.clone(world)
	for key: String in M5StateValidator.COLLECTIONS:
		reordered.get(key).reverse()
	var shuffled: Dictionary = config.duplicate(true)
	shuffled.automatic_person_ids.reverse()
	shuffled.contacts.reverse()
	var permutation: M60RunResult = M60Runner.run_v1(reordered, shuffled, 3)
	var prefix: M60RunResult = M60Runner.run_v1(world, config, 3)
	_equal(permutation.to_data(), prefix.to_data(), "input collection and configuration array permutation")
	_equal(permutation.checkpoint_json, prefix.checkpoint_json, "permutation checkpoint bytes")
	_equal(StateCanonicalizer.canonical_json(StateHasher.state_payload(world)), before, "repeated runs never mutate initial")
	_equal(first.to_data().initial_payload, StateHasher.state_payload(world), "observation carries reproducible initial world")
	_equal(first.to_data().config, config, "observation carries fixed sites, cohort, version and rules")
	var after_horizon: M60RunResult = M60Runner.run_v1(world, config, 1, first.checkpoint_json)
	_expect(after_horizon.status == "STOPPED" and after_horizon.advanced_days == 0 and after_horizon.days.size() == 28, "day 29 reaches natural health boundary")
	_equal(after_horizon.checkpoint_json, first.checkpoint_json, "natural stop preserves all 28 completed days and counters")
	_equal(after_horizon.failed_day.m4_batch_artifact.batch_resolution.batch_status, "COMMITTED", "day 29 actual action evidence survives outer rollback")
	_equal(after_horizon.error.details[0].field_path, "state.persons.health", "day 29 native health diagnostic")
	runtime_evidence.day_29_stop = {"status": after_horizon.status, "advanced_days": after_horizon.advanced_days,
		"completed_days": after_horizon.days.size(), "checkpoint_sha256": after_horizon.checkpoint_json.sha256_text(),
		"failed_day": after_horizon.failed_day, "error": after_horizon.error}
	var consumed: int = 0
	var sequences: Dictionary = {}
	for day: Dictionary in first.days:
		_equal(M60Evidence.validate_committed_day(day, day.day_index, day.input_state_hash), "", "day hash and native artifact chain")
		for decision: Dictionary in day.decisions:
			_equal(decision.input_state_hash, day.input_state_hash, "same snapshot across days")
		for op: Dictionary in day.operations:
			for tx: Dictionary in op.resource_transactions:
				_expect(not sequences.has(tx.sequence_index), "resource sequence unique across action and close")
				sequences[tx.sequence_index] = true
				_equal(tx.day_index, day.day_index + 1, "native transaction clock")
				if not tx.consumer_person_id.is_empty():
					consumed += tx.quantity
	var initial_food: int = 0
	var final_food: int = 0
	for resource: ResourceStoreState in world.resource_stores:
		initial_food += resource.quantity
	for resource: ResourceStoreState in first.next_world.resource_stores:
		final_food += resource.quantity
	_equal(initial_food - consumed, final_food, "transfers conserve food; only successful consumption reduces total")
	runtime_evidence.food_pressure_28 = first.to_data()
	runtime_evidence.repeat_resume = {"repeat_equal": StateCanonicalizer.canonical_json(first.to_data()) == StateCanonicalizer.canonical_json(repeated.to_data()),
		"resume_equal": resumed.checkpoint_json == first.checkpoint_json and resumed.failed_day == first.failed_day,
		"permutation_equal": StateCanonicalizer.canonical_json(permutation.to_data()) == StateCanonicalizer.canonical_json(prefix.to_data()),
		"checkpoint_sha256": first.checkpoint_json.sha256_text(), "completed_days": first.days.size(),
		"requested_period_completed": first.ok, "consumed_units": consumed, "remaining_units": final_food}
	_group_completed = true


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if StateCanonicalizer.canonical_json(actual) != StateCanonicalizer.canonical_json(expected):
		failures.append(message)
