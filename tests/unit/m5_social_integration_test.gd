class_name M5SocialIntegrationTest
extends RefCounted

var failures: Array[String] = []
var checks: int = 0
var runtime_evidence: Dictionary = {}
var _group_completed: bool = false


func run_all() -> Array[String]:
	var groups: Array = [
		["_test_initial_and_b01", []], ["_test_failures_and_stage_boundary", []],
		["_test_fcal", [false]], ["_test_fcal", [true]], ["_test_date_separated_memory", []],
		["_test_numeric_and_conflict", []], ["_test_codec_and_authority", []],
		["_test_capacity_feedback_and_purity", []], ["_test_m4_projection_vectors", []],
		["_test_native_theft_and_receipts", []], ["_test_native_zero_and_order", []], ["_test_contact_caps_and_wire", []],
	]
	for group: Array in groups:
		_group_completed = false
		callv(group[0], group[1])
		_expect(_group_completed, "test group reached final assertion: " + group[0] + str(group[1]))
	return failures


func _test_initial_and_b01() -> void:
	var annex: Dictionary = M5FixtureFactory.annex()
	for legacy: bool in [false, true]:
		var world: WorldState = M5FixtureFactory.initial(legacy)
		var errors: Array[String] = StateValidator.validate_world(world)
		_expect(errors.is_empty(), "M5-T01 initial validation: " + str(errors))
		if not errors.is_empty():
			continue
		_equal(StateHasher.hash_world(world), annex.blocker_vectors.B01.initial_state_hash if legacy else annex.FCAL_initial_state_hash, "M5-T01 initial hash")
		var before: String = StateCanonicalizer.canonical_json(StateHasher.state_payload(world))
		var sub: DecisionSubmission = M5FixtureFactory.submission(world, "person:000001")
		_expect(sub.submitted_decision_result.ok, "M5-T12 native M3 accepts Schema 5")
		if not sub.submitted_decision_result.ok:
			continue
		var context: Dictionary = annex.blocker_vectors.B01.expected_native_context
		var issuer: TestResolutionContextIssuer = M5FixtureFactory.issuer(world, [sub], ModelData.copy_string_array(context.present_person_ids), ModelData.copy_string_array(context.present_store_ids))
		if legacy:
			_equal(sub.submitted_decision_result.to_data(), annex.blocker_vectors.B01.expected_native_decision_result, "B01 native decision")
		var result: M5OperationResult = M5Facade.execute_decisions_v1(world, M5RequestStamp.for_world(world), [sub], issuer)
		_expect(result.ok, "M5-T03 A04 commit: " + str(result.artifact.errors))
		_equal(StateCanonicalizer.canonical_json(StateHasher.state_payload(world)), before, "M5-T17 original immutable")
		if not result.ok:
			continue
		if legacy:
			_equal(StateHasher.state_payload(result.next_world), annex.blocker_vectors.B01.expected_payload_after_A04, "B01 complete native payload")
			_equal(result.artifact.intermediate_state_hash, annex.blocker_vectors.B01.execute_checkpoint.stage_hash, "B01 stage hash")
		var saved: Dictionary = M5SaveCodec.encode_checked(result.next_world)
		_expect(saved.ok, "M5-T01 checked encode")
		var resumed: Dictionary = M5SaveCodec.decode_checked(saved.json_text)
		_expect(resumed.ok, "M5-T01 checked decode: " + str(resumed.errors))
		if resumed.ok:
			_equal(StateHasher.state_payload(resumed.world), StateHasher.state_payload(result.next_world), "M5-T18 state resume")
		if legacy:
			_equal(saved.json_text, annex.blocker_vectors.B01.save_canonical_json, "B01 exact save")
	_group_completed = true


func _test_failures_and_stage_boundary() -> void:
	var annex: Dictionary = M5FixtureFactory.annex()
	var initial: WorldState = M5FixtureFactory.initial(true)
	var context: Dictionary = annex.blocker_vectors.B01.expected_native_context
	var submission: DecisionSubmission = M5FixtureFactory.submission(initial, "person:000001")
	var issuer: TestResolutionContextIssuer = M5FixtureFactory.issuer(initial, [submission], ModelData.copy_string_array(context.present_person_ids), ModelData.copy_string_array(context.present_store_ids))
	var aid: M5OperationResult = M5Facade.execute_decisions_v1(initial, M5RequestStamp.for_world(initial), [submission], issuer)
	if not aid.ok:
		_expect(false, "FAR prerequisite A04")
		return
	var contact: M5OperationResult = M5FixtureFactory.contacts(aid.next_world)
	if not contact.ok:
		_expect(false, "FAR prerequisite contact")
		return
	for index: int in 7:
		var vector: Dictionary = annex.blocker_vectors.B03.failure_artifact_vectors[index]
		var result: M5OperationResult
		var source: WorldState = initial if index < 5 else aid.next_world if index == 5 else contact.next_world
		var before: Dictionary = StateHasher.state_payload(source)
		var probe: M5ProbeFacade = M5ProbeFacade.new()
		probe.fault = "FAR-%02d" % index
		if index == 0:
			result = M5Facade.execute_decisions_v1(null, null, null, null)
		elif index == 1:
			result = M5Facade.execute_decisions_v1(source, M5RequestStamp.for_world(source), [], issuer)
		elif index == 2:
			result = M5Facade.execute_decisions_v1(source, M5RequestStamp.for_world(source), [submission, submission], issuer)
		elif index < 5:
			result = probe._run("EXECUTE", source, M5RequestStamp.for_world(source), [submission], issuer)
		elif index == 5:
			result = probe._run("CONTACTS", source, M5RequestStamp.for_world(source), SocialContactPlan.new(), null)
		else:
			result = probe._run("CLOSE", source, M5RequestStamp.for_world(source), null, null)
		_equal(result.to_data(), vector.expected_result, "M5-T17 exact " + vector.id)
		_equal(StateHasher.state_payload(source), before, "M5-T17 rollback " + vector.id)
		for key: String in probe.stage_checks:
			_expect(probe.stage_checks[key], "D26-R01 " + key)
	for fault: String in ["STAGE_QUANTITY", "STAGE_EPOCH", "STAGE_SOCIAL"]:
		var probe: M5ProbeFacade = M5ProbeFacade.new()
		probe.fault = fault
		var result: M5OperationResult = probe._run("EXECUTE", initial, M5RequestStamp.for_world(initial), [submission], issuer)
		_expect(not result.ok and result.next_world == null and result.resource_transactions.is_empty(), "D26-R01 corruption rejected " + fault)
		_equal(result.artifact.intermediate_state_hash, "", "D26-R01 incomplete checkpoint hidden")
	var overflow: WorldState = M5FixtureFactory.initial()
	overflow.next_ids.memory = M5Data.MAX_INT
	var result: M5OperationResult = M5FixtureFactory.execute(overflow, "person:000001")
	_expect(not result.ok and result.artifact.errors[0].code == "M5_ARITHMETIC_OVERFLOW", "M5-T17 late counter overflow")
	_expect(not result.artifact.intermediate_state_hash.is_empty() and result.resource_transactions.is_empty(), "M5-T17 checkpoint retained and transaction discarded")
	_group_completed = true


func _test_fcal(proposed_fixture: bool) -> void:
	var annex: Dictionary = M5FixtureFactory.annex()
	var world: WorldState = M5FixtureFactory.initial()
	if proposed_fixture:
		world.find_person("person:000003").need_scores.hunger = 37
		runtime_evidence["FCAL_proposed_initial_hash"] = StateHasher.hash_world(world)
		runtime_evidence["FCAL_proposed_initial_decision"] = M5FixtureFactory.submission(world, "person:000001").submitted_decision_result.to_data()
	var branch: WorldState = null
	var hashes: Array = []
	var total_consumed: int = 0
	var all_resources: Array = []
	var all_social: Array = []
	for row: Dictionary in annex.FCAL_rows:
		var action: M5OperationResult = M5FixtureFactory.execute(world, row.action_actor)
		_expect(action.ok, row.id + " native action " + str(action.artifact.errors))
		if not action.ok:
			return
		var contacts: M5OperationResult = M5FixtureFactory.contacts(action.next_world, row.contact_pairs)
		_expect(contacts.ok, row.id + " contacts " + str(contacts.artifact.errors))
		if not contacts.ok:
			return
		var close_stamp: M5RequestStamp = M5RequestStamp.for_world(contacts.next_world)
		var closed: M5OperationResult = M5Facade.close_day_v1(contacts.next_world, close_stamp)
		if not proposed_fixture and row.closing_day == 27:
			_expect(not closed.ok and closed.artifact.errors[0].entity_id == "person:000003", "D26-R02 known canonical FCAL health conflict reproduces")
			_equal(contacts.next_world.find_person("person:000003").health, 5, "D26-R02 death boundary health before close")
			_expect(closed.next_world == null and closed.resource_transactions.is_empty(), "D26-R02 rejected day leaves resources unpublished")
			runtime_evidence["FCAL_canonical"] = hashes
			runtime_evidence["FCAL_canonical_blocker"] = {"id": "M5-RUNTIME-B01", "day": 27, "person_id": "person:000003", "health_before": 5, "health_after_requested": 0, "expected_close_success": true, "actual_close_success": false, "artifact": closed.artifact, "input_payload": StateHasher.state_payload(contacts.next_world)}
			_group_completed = true
			return
		_expect(closed.ok, row.id + " close " + str(closed.artifact.errors))
		if not closed.ok:
			return
		if branch != null:
			var ba: M5OperationResult = M5FixtureFactory.execute(branch, row.action_actor)
			var bc: M5OperationResult = M5FixtureFactory.contacts(ba.next_world, row.contact_pairs)
			var bd: M5OperationResult = M5Facade.close_day_v1(bc.next_world, M5RequestStamp.for_world(bc.next_world))
			_expect(bd.ok, row.id + " resumed branch executes")
			if bd.ok:
				_equal(bd.artifact, closed.artifact, "M5-T18 " + row.id + " resumed artifact")
				_equal(StateHasher.state_payload(bd.next_world), StateHasher.state_payload(closed.next_world), "M5-T18 " + row.id + " resumed full state")
				branch = bd.next_world
		world = closed.next_world
		var ss: SocialState = world.social_state
		for pair: Array in [[world.day_index, row.output_world_day], [world.resolution_epoch, row.output_resolution_epoch], [ss.last_integrated_resolution_epoch, row.output_integrated_epoch], [ss.revision, row.output_social_revision], [ss.last_closed_day_index, row.output_last_closed_day], [ss.last_contact_day_index, row.output_last_contact_day], [ss.last_settled_week_index, row.last_settled_week], [world.next_resource_sequence_index, row.next_resource_sequence_index], [world.social_observations.size(), row.observation_count], [world.social_effect_receipts.size(), row.effect_receipt_count], [world.memories.size(), row.memory_count]]:
			_equal(pair[0], pair[1], "D26-R02 " + row.id + " clock/count")
		_equal(world.find_resource_store("resource_store:household:000001").quantity, row.household_1_stock, row.id + " household 1 food")
		_equal(world.find_resource_store("resource_store:household:000002").quantity, row.household_2_stock, row.id + " household 2 food")
		_equal(world.find_resource_store("resource_store:granary:village_01").quantity if world.find_resource_store("resource_store:granary:village_01") != null else world.resource_stores[2].quantity, row.granary_stock, row.id + " granary food")
		_equal(world.find_person("person:000003").trait_scores.norm_adherence, row.seeded_person_norm, row.id + " weekly trait")
		_equal(world.trait_pressures[0].pressure, row.seeded_person_pressure, row.id + " weekly remainder")
		var consumed: int = 0
		for transaction: ResourceTransactionRecord in closed.resource_transactions:
			consumed += transaction.quantity
			_equal(transaction.day_index, row.consumption_transaction_day, row.id + " consumption date")
		total_consumed += consumed
		_equal(consumed, row.consumed_quantity, row.id + " consumed")
		_equal(closed.resource_transactions.size(), row.consumption_transaction_count, row.id + " consumption count")
		for transaction: ResourceTransactionRecord in action.resource_transactions:
			_equal(transaction.day_index, row.action_transaction_day, row.id + " action transaction date")
			_equal(transaction.quantity, row.action_quantity, row.id + " action quantity")
		all_resources.append_array(action.resource_transactions)
		all_resources.append_array(closed.resource_transactions)
		all_social.append_array([action.artifact, contacts.artifact, closed.artifact])
		var learned: Dictionary = {}
		for memory: MemoryState in world.memories:
			learned[memory.owner_person_id] = memory.first_learned_day_index
		_equal(learned.has("person:000001") and learned.has("person:000004"), row.first_memories_retained, row.id + " first memories retained")
		_equal(learned.has("person:000002"), row.late_memory_retained, row.id + " late memory retained")
		if learned.has("person:000002"):
			_equal(learned["person:000002"], 13, row.id + " delayed first learning")
		if row.closing_day == 13:
			_expect(M5Effects._observation(world, M5Data.observation_id("person:000003", "event:000002")) == null, "M5-T08 same-pass 2->3 blocked")
			_expect(not M5FixtureFactory.contacts(contacts.next_world).ok, "M5-T08 repeated contact blocked")
			var stale: M5OperationResult = M5Facade.close_day_v1(world, close_stamp)
			_equal(stale.artifact.errors[0].code, "M5_STALE_DAY", "M5-T19 repeated close uses stale day priority")
			_equal(M5Facade.close_day_v1(world, M5RequestStamp.for_world(world)).artifact.errors[0].code, "M5_CONTACT_REQUIRED", "M5-T19 next day requires contacts")
		if row.save_resume_checkpoint:
			var encoded: Dictionary = M5SaveCodec.encode_checked(world)
			var decoded: Dictionary = M5SaveCodec.decode_checked(encoded.json_text)
			_expect(decoded.ok, row.id + " audit-free resume")
			if decoded.ok:
				branch = decoded.world
		var hash_row: Dictionary = {"id": row.id, "state_hash": StateHasher.hash_world(world), "action_artifact_hash": action.artifact.artifact_hash,
			"contact_artifact_hash": contacts.artifact.artifact_hash, "close_artifact_hash": closed.artifact.artifact_hash, "state_metrics": closed.artifact.state_metrics,
			"person3_health": world.find_person("person:000003").health, "person3_hunger": world.find_person("person:000003").need_scores.hunger,
			"person3_severe_hunger_days": world.find_person("person:000003").severe_hunger_days}
		hashes.append(hash_row)
	_equal(total_consumed, 75, "D26-R02 total consumed 75")
	_equal(ResourceService.total_quantity(world), 80, "D26-R02 total remaining 80")
	var full_save: Dictionary = M5SaveCodec.encode_checked(world, [], all_resources, all_social)
	_expect(full_save.ok, "M5-T01 full audit encode " + str(full_save.errors))
	if full_save.ok:
		_expect(M5SaveCodec.decode_checked(full_save.json_text).ok, "M5-T01 full audit decode")
	runtime_evidence["FCAL_proposed_noncanonical"] = hashes
	runtime_evidence["final_state_hash"] = StateHasher.hash_world(world)
	runtime_evidence["resource_transactions"] = all_resources.size()
	_group_completed = true


func _test_date_separated_memory() -> void:
	var world: WorldState = M5FixtureFactory.initial(true)
	var legacy: Dictionary = world.memories[0].to_data(5)
	var contact: M5OperationResult = M5FixtureFactory.contacts(world)
	var day: M5OperationResult = M5Facade.close_day_v1(contact.next_world, M5RequestStamp.for_world(contact.next_world))
	_expect(day.ok, "B01 date separation day 0 close")
	if not day.ok:
		return
	var aid: M5OperationResult = M5FixtureFactory.execute(day.next_world, "person:000001")
	_expect(aid.ok, "B01 date separation day 1 A04")
	if not aid.ok:
		return
	for memory: MemoryState in aid.next_world.memories:
		if memory.id == "memory:000001":
			_equal(memory.to_data(5), legacy, "B01 day 0 historical memory fully preserved")
	var fact: InformationState = M5Effects._fact(aid.next_world, "person:000001", "person:000004")
	_equal(fact.learned_day_index, 1, "B01 current belief learns on day 1")
	_equal(fact.linked_event_id, "event:000002", "B01 current belief new event")
	var resume: Dictionary = M5SaveCodec.decode_checked(M5SaveCodec.encode_checked(aid.next_world).json_text)
	_expect(resume.ok, "B01 date separation save/resume")
	if resume.ok:
		_equal(StateHasher.state_payload(resume.world), StateHasher.state_payload(aid.next_world), "B01 day 1 full resume")
	runtime_evidence["B01_day_separated_hash"] = StateHasher.hash_world(aid.next_world)
	_group_completed = true


func _test_numeric_and_conflict() -> void:
	var annex: Dictionary = M5FixtureFactory.annex()
	var numbers: Dictionary = annex.numeric_vectors
	for row: Dictionary in numbers.rounding:
		_equal(M5Data.rd(row.numerator, row.denominator), row.expected, "M5 signed half rounding")
	for row: Dictionary in numbers.learning:
		var learned: Dictionary = M5Appraisal.learning(row.old_belief, row.old_confidence, row.requested, row.actual)
		_equal(learned, {"sample": row.sample, "new_belief": row.expected_belief, "new_confidence": row.expected_confidence}, "M5-T12 learning")
	for row: Dictionary in numbers.confidence:
		_equal(M5Contacts.receiver_confidence(row.sender, row.receiver_to_sender_trust), row.expected_confidence, "M5-T07 directional confidence")
	for row: Dictionary in numbers.pressure_cases:
		var prior: Array = []
		for i: int in row.prior:
			prior.append(i)
		_equal(M5Appraisal.pressure({"N": row.N, "K": row.K, "C": row.C, "norm_adherence": row.norm, "family_protection": row.family}, prior, 3).applied_pressure, row.pressure, "M5-T13 " + row.id)
	for row: Dictionary in numbers.weekly:
		var actual: Dictionary = M5Maintenance.weekly(row.input_score, row.input_pressure)
		_equal({"score": actual.new_score, "delta": actual.actual_delta, "remaining_pressure": actual.remaining_pressure}, row.expected, "M5-T14 weekly bounds")
	var world: WorldState = M5FixtureFactory.initial()
	for row: Dictionary in numbers.appraisal:
		var person: PersonState = world.find_person("person:000001")
		var obs: Dictionary = {"origin_view": "aid_requester", "acquisition_type": "direct_interaction", "confidence": 100, "payload": {}}
		var context: Dictionary = {}
		if row.id == "THEFT_HEARSAY":
			person.trait_scores.norm_adherence = row.norm
			person.value_scores.property_autonomy = row.property
			obs.origin_view = "theft_witness"
			obs.acquisition_type = "hearsay"
			obs.confidence = row.confidence
			obs.payload = {"actor_person_id": "person:000004", "store_id": world.resource_stores[0].id, "took_goods": row.took_goods}
		else:
			obs.payload = {"requester_person_id": person.id, "responder_person_id": "person:000004", "requested_units": row.requested, "actual_units": row.actual, "response_decision": row.response}
			context = {"N": row.N}
		var result: Dictionary = M5Appraisal.evaluate(person, obs, context, [], 0, [])
		var relation: Dictionary = {"trust": 0, "affection": 0, "fear": 0, "resentment": 0, "obligation": 0}
		if not result.relation_deltas.is_empty():
			relation = result.relation_deltas[0].duplicate(true)
			relation.erase("target_person_id")
		_equal(relation, row.get("requester_relation_delta", row.get("relation_delta")), "M5-T11 relation " + row.id)
		_equal(result.emotion_deltas, row.get("requester_emotion_delta", row.get("emotion_delta")), "M5-T11 emotions " + row.id)
		_equal(result.importance, row.get("requester_importance", row.get("importance")), "M5-T11 importance " + row.id)
	var b02: Dictionary = annex.blocker_vectors.B02
	var merged: Dictionary = M5ObservationMerger.merge({}, b02.forward_reports, b02.receiving_day_index)
	_equal(merged, b02.expected_observation, "B02 complete observation")
	_equal(M5ObservationMerger.merge({}, b02.reverse_reports, b02.receiving_day_index), merged, "B02 reverse order")
	_equal(M5ObservationMerger.merge(merged, [b02.same_rank_rehear_report], 2), merged, "B02 conflict survives rehearing")
	_equal(StateHasher.hash_data(merged), b02.expected_observation_hash, "B02 exact observation hash")
	var stronger: Dictionary = b02.forward_reports[0].duplicate(true)
	stronger.confidence = 90
	var accepted: Dictionary = M5ObservationMerger.merge(merged, [stronger], 2)
	_expect(accepted.accepted and not accepted.conflicted and accepted.first_learned_day_index == 1 and accepted.first_accepted_day_index == 2, "M5-T10 strictly stronger resolves persisted barrier")
	_group_completed = true


func _test_codec_and_authority() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var saved: Dictionary = M5SaveCodec.encode_checked(world)
	for altered: String in [saved.json_text.replace('"schema_version":5', '"schema_version":5.0'), saved.json_text.replace('"schema_version":5', '"schema_version":5e0'), saved.json_text.replace('"schema_version":5', '"schema_version":5,"schema_version":5'), saved.json_text.replace('"schema_version":5', '"schema_version":5,"schema_versio\\u006e":5')]:
		_expect(not M5SaveCodec.decode_checked(altered).ok, "M5-T01 strict raw JSON tokens and duplicate keys")
	_expect(not M5JsonReader.parse('"raw\nnewline"').ok, "M5-T01 unescaped string control character rejected")
	_expect(M5JsonReader.parse('"escaped\\nnewline"').ok, "M5-T01 escaped newline remains valid")
	var broken: Dictionary = StateHasher.state_payload(world)
	broken.state.next_ids.erase("memory")
	_expect(not M5StateValidator.validate_payload(broken).is_empty(), "M5-T01 missing counter rejected before typed conversion")
	_equal(WorldState.new().schema_version, 4, "M5-T01 default world remains Schema 4")
	_expect(not DayProcessor.advance_day(world).ok, "M5-T19 direct day rejects Schema 5")
	_expect(not ResourceService.apply_transactions(world, []).is_empty(), "M5-T19 direct resource mutation rejects Schema 5")
	var sub: DecisionSubmission = M5FixtureFactory.submission(world, "person:000001")
	var issuer: TestResolutionContextIssuer = M5FixtureFactory.issuer(world, [sub])
	_equal(M4Facade.execute_decisions_v1(world, [sub], issuer).batch_status, "REJECTED", "M5-T19 direct M4 rejects Schema 5")
	var successful: M5OperationResult = M5FixtureFactory.contacts(world)
	var replay: M5OperationResult = M5Facade.process_contacts_v1(successful.next_world, M5RequestStamp.for_world(world), SocialContactPlan.new())
	_equal(replay.artifact.errors[0].code, "M5_STALE_REVISION", "M5-T08 replay stamp priority")
	_equal(M5FixtureFactory.execute(successful.next_world, "person:000001").artifact.errors[0].code, "M5_ACTIONS_CLOSED", "M5-T19 actions closed after contact")
	for pairs: Array in [[["person:000001", "person:000001"]], [["person:000004", "person:000001"]], [["person:000001", "person:000004"], ["person:000001", "person:000004"]]]:
		_expect(not M5FixtureFactory.contacts(world, pairs).ok, "M5-T08 invalid contact rejected")
	_group_completed = true


func _test_capacity_feedback_and_purity() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	for i: int in 104:
		var memory: MemoryState = MemoryState.from_data(M5FixtureFactory.annex().blocker_vectors.B01.expected_legacy_memory, 5)
		memory.id = IdAllocator.next_id(world, "memory")
		memory.core_eligible = i < 9
		memory.importance = 100 if i < 9 else 80 if i < 34 else 40
		world.memories.append(memory)
		world.find_person(memory.owner_person_id).memory_ids.append(memory.id)
	var before_relations: Array = ModelData.object_array_to_data(world.relations)
	var artifact: Dictionary = M5Artifact.begin("CONTACTS")
	M5Maintenance.memories(world, 0, artifact)
	var metrics: Dictionary = M5Artifact.metrics(world)
	_equal([metrics.memories_core, metrics.memories_important, metrics.memories_recent], [8, 24, 64], "M5-T15 104 memories reduce to 8/24/64")
	_equal(world.memories.size(), 96, "M5-T20 detailed memory cap")
	_equal(ModelData.object_array_to_data(world.relations), before_relations, "M5-T16 compression never reapplies relation effects")
	_expect(StateValidator.validate_world(world).is_empty(), "M5-T16 no dangling links after capacity compression")
	var base: WorldState = M5FixtureFactory.initial()
	var learned: M5OperationResult = M5FixtureFactory.execute(base, "person:000001")
	if not learned.ok:
		_expect(false, "feedback prerequisite")
		return
	var control: WorldState = M5Data.clone(learned.next_world)
	var fact: InformationState = M5Effects._fact(control, "person:000001", "person:000004")
	fact.belief_value = 50
	fact.confidence = 80
	var old_decision: DecisionResult = M5FixtureFactory.submission(control, "person:000001").submitted_decision_result
	var new_decision: DecisionResult = M5FixtureFactory.submission(learned.next_world, "person:000001").submitted_decision_result
	_equal(_candidate(old_decision, "A04").expected_benefit_component, 40, "M5-T12 prelearning M40")
	_equal(_candidate(new_decision, "A04").expected_benefit_component, 48, "M5-T12 postlearning M48")
	_equal(_candidate(new_decision, "A04").utility_scaled - _candidate(old_decision, "A04").utility_scaled, 80, "M5-T12 isolated learning utility +80")
	for norm: int in [69, 71]:
		var adjusted: WorldState = M5Data.clone(base)
		adjusted.find_person("person:000001").trait_scores.norm_adherence = norm
		adjusted.find_person("person:000001").role_ids = []
		var decision: DecisionResult = M5FixtureFactory.submission(adjusted, "person:000001").submitted_decision_result
		_equal(_candidate(decision, "A11").norm_conflict_component, 46 if norm == 69 else 47, "M5-T12 norm feedback")
	var changed_player: WorldState = M5Data.clone(base)
	changed_player.player_person_id = "person:000004"
	_equal(_candidate(M5FixtureFactory.submission(changed_player, "person:000001").submitted_decision_result, "A04").to_data(), _candidate(M5FixtureFactory.submission(base, "person:000001").submitted_decision_result, "A04").to_data(), "M5-T20 player and NPC identical calculation")
	var concealed: WorldState = M5Data.clone(base)
	concealed.find_person("person:000004").trait_scores["norm_adherence"] = 0
	concealed.resource_stores[2].security_level = 100
	var concealed_decision: DecisionResult = M5FixtureFactory.submission(concealed, "person:000001").submitted_decision_result
	_expect(concealed_decision.ok, "M5-T05 concealed fixture valid: " + str(concealed_decision.to_data()))
	if concealed_decision.ok:
		_equal(_candidate(concealed_decision, "A04").to_data(), _candidate(M5FixtureFactory.submission(base, "person:000001").submitted_decision_result, "A04").to_data(), "M5-T05 private state excluded from subjective candidate")
	for fault: String in ["SOCIAL_RESOURCE", "SOCIAL_HEALTH"]:
		var probe: M5ProbeFacade = M5ProbeFacade.new()
		probe.fault = fault
		var result: M5OperationResult = probe._run("CONTACTS", base, M5RequestStamp.for_world(base), SocialContactPlan.new(), null)
		_expect(not result.ok and result.artifact.errors[0].field_path == "state.physical_delta", "M5-T19 social kernel physical purity " + fault)
	# Native aggregate: aid trust +4 and a confidence-99 theft report trust -3.
	var snapshot: WorldState = M5FixtureFactory.initial()
	var owner: PersonState = snapshot.find_person("person:000001")
	owner.trait_scores.norm_adherence = 50
	owner.value_scores.property_autonomy = 50
	M5Data.relation(snapshot, owner.id, "person:000004").trust = 99
	var event: EventRecord = EventRecord.from_data(snapshot.events[0].to_data(5), 5)
	event.id = IdAllocator.next_id(snapshot, "event")
	snapshot.events.append(event)
	var aid_report: Dictionary = M5Projector._report(snapshot.events[0], owner.id, "aid_requester", "direct_interaction", {"requester_person_id": owner.id, "responder_person_id": "person:000004", "requested_units": 10, "actual_units": 10, "response_decision": "GRANT_FULL"})
	var theft_report: Dictionary = M5Projector._report(event, owner.id, "theft_witness", "hearsay", {"actor_person_id": "person:000004", "store_id": snapshot.resource_stores[2].id, "took_goods": false})
	theft_report.original_source_person_id = "person:000002"
	theft_report.current_source_person_id = "person:000002"
	theft_report.depth = 1
	theft_report.confidence = 99
	var outputs: Array = []
	for reports: Array in [[aid_report, theft_report], [theft_report, aid_report]]:
		var stage: WorldState = M5Data.clone(snapshot)
		var audit: Dictionary = M5Artifact.begin("EXECUTE")
		var error: Dictionary = M5Effects.apply(snapshot, stage, reports, {owner.id: {"N": 54}}, audit)
		_expect(error.is_empty(), "M5-T11 aggregate effect plans")
		_equal(M5Data.relation(stage, owner.id, "person:000004").trust, 100, "M5-T11 snapshot 99+4-3 clamps once to100")
		outputs.append(StateHasher.state_payload(stage))
	_equal(outputs[0], outputs[1], "M5-T18 report permutation complete state")
	_group_completed = true


func _candidate(result: DecisionResult, action: String) -> DecisionCandidateEvaluation:
	for candidate: DecisionCandidateEvaluation in result.candidate_evaluations:
		if candidate.action_id == action:
			return candidate
	return null


func _test_m4_projection_vectors() -> void:
	var annex: Dictionary = M5FixtureFactory.annex()
	var m4: Dictionary = M4RulesData.load_dictionary("res://tests/fixtures/m4_exact_artifacts.json")
	var matched: int = 0
	for vector: Dictionary in annex.M4_projection_vectors:
		var fixture_id: String = vector.id.get_slice("-", 0)
		var fixture: Dictionary = m4.fixtures[fixture_id]
		var world: WorldState = M4FixtureFactory.world_from_payload(fixture.input_world)
		var submissions: Array = []
		for decision: Dictionary in fixture.decisions:
			submissions.append(M5FixtureFactory.submission(world, decision.actor_person_id))
		var issuer: TestResolutionContextIssuer = M4FixtureFactory.issuer_for_contexts(fixture.contexts)
		var result: BatchResolutionRecord = M4Facade.execute_decisions_v1(world, submissions, issuer)
		_expect(result.batch_status == "COMMITTED", "M5-T04 frozen M4 vector executes " + vector.id)
		if result.next_world == null:
			continue
		# The projector unit seam consumes a native M4 outcome, never a public submitted report.
		var owner: M5Facade = M5Facade.new()
		var scope: M5OperationScope = M5OperationScope._begin(owner, world, "EXECUTE")
		owner._active_scope = scope
		var native: ActionOutcomeRecord = null
		for outcome: ActionOutcomeRecord in result.committed_outcomes:
			if outcome.action_instance_id == vector.source_action_instance_id:
				native = outcome
		if native == null:
			_expect(false, "projection outcome missing " + vector.id)
			scope.finish()
			continue
		_equal(native.semantic_resolution_hash, vector.source_outcome_hash, "M5-T04 source outcome binding " + vector.id)
		var single: BatchResolutionRecord = BatchResolutionRecord.new()
		single.next_world = M5Data.clone(result.next_world)
		single.committed_outcomes = [native]
		for seed: WitnessEvidenceSeed in result.witness_evidence_seeds:
			if seed.action_instance_id == native.action_instance_id:
				single.witness_evidence_seeds.append(seed)
		scope.register_stage(single.next_world)
		var projection: Dictionary = M5Projector.project(scope, single)
		_expect(projection.ok, "M5-T04 projection " + vector.id)
		var owners: Array = []
		for report: Dictionary in projection.reports:
			owners.append(report.owner_person_id)
			if report.origin_view == "theft_witness":
				_expect(M5Data.exact(report.payload, M5Data.keys("theft_witness_payload")), "M5-T05 narrow witness keyset")
			else:
				_equal(report.payload.actual_units, vector.expected_actual_units, "M5-T03/04 actor amount " + vector.id)
			if report.origin_view == "theft_self":
				_expect(report.is_secret, "M5-T09 self theft stays secret")
		_equal(owners, vector.expected_owner_ids, "M5-T03/04 permitted owners " + vector.id)
		_equal(single.next_world.traces.size(), vector.trace_count, "M5-T06 trace projection " + vector.id)
		scope.finish()
		owner._active_scope = null
		matched += 1
	_equal(matched, 9, "M5-T03..T06 nine frozen M4 projection vectors")
	_group_completed = true


func _test_native_theft_and_receipts() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var actor: PersonState = world.find_person("person:000001")
	# A new test scenario disables aid belief and makes theft the native selected action.
	for fact: InformationState in world.information:
		if fact.owner_person_id == actor.id and fact.fact_type_id == "request_food_access":
			fact.belief_value = 0
	actor.trait_scores.norm_adherence = 70
	actor.value_scores.family_protection = 95
	actor.need_scores.hunger = 90
	var sub: DecisionSubmission = M5FixtureFactory.submission(world, actor.id)
	_equal(_candidate(sub.submitted_decision_result, "A11").action_id, "A11", "M5-T04 theft candidate")
	var chosen: DecisionCandidateEvaluation = IntentParameterizer._selected_candidate(sub.submitted_decision_result)
	_equal(chosen.action_id, "A11", "M5-T04 native theft selected")
	var result: M5OperationResult = M5FixtureFactory.execute(world, actor.id, [actor.id, "person:000004"])
	_expect(result.ok, "M5-T04 native Schema 5 theft " + str(result.artifact.errors))
	if not result.ok:
		return
	var self_observation: SocialObservationState = M5Effects._observation(result.next_world, M5Data.observation_id(actor.id, "event:000002"))
	_expect(self_observation != null and self_observation.is_secret, "M5-T09 secret native self experience")
	var contacts: M5OperationResult = M5FixtureFactory.contacts(result.next_world, [["person:000001", "person:000002"]])
	_expect(contacts.ok, "M5-T09 native contacts after theft")
	if contacts.ok:
		_expect(M5Effects._observation(contacts.next_world, M5Data.observation_id("person:000002", "event:000002")) == null, "M5-T09 no automatic confession")
	var persons: Dictionary = {}
	var stores: Dictionary = {}
	for person: PersonState in world.persons:
		persons[person.id] = person
	for store: ResourceStoreState in world.resource_stores:
		stores[store.id] = store
	var report: Dictionary = M5ObservationMerger.report_of(self_observation.to_data())
	for field: String in ["actual_security", "trace_created", "notice_score", "witness_ids"]:
		var polluted: Dictionary = report.duplicate(true)
		polluted.payload[field] = 50
		_expect(not M5StateValidator.report_valid(polluted, persons, stores), "M5-T05 forbidden self payload " + field)
	# A third person first disbelieves, then accepts once, then receives stronger hearsay.
	var snapshot: WorldState = M5Data.clone(result.next_world)
	var received: Dictionary = {"owner_person_id": "person:000002", "event_id": "event:000002", "occurred_day_index": 0,
		"acquisition_type": "hearsay", "origin_view": "theft_witness", "original_source_person_id": "person:000004",
		"current_source_person_id": "person:000004", "depth": 1, "confidence": 59, "is_secret": false,
		"payload": {"actor_person_id": actor.id, "store_id": report.payload.store_id, "took_goods": false}}
	var counts: Array = []
	for confidence: int in [59, 60, 90, 90]:
		received.confidence = confidence
		var stage: WorldState = M5Data.clone(snapshot)
		var artifact: Dictionary = M5Artifact.begin("CONTACTS")
		var error: Dictionary = M5Effects.apply(snapshot, stage, [received], {}, artifact)
		_expect(error.is_empty(), "M5-T07/10 receipt update")
		counts.append(artifact.effect_applications.size())
		stage.social_state.revision += 1
		snapshot = stage
	_equal(counts, [0, 1, 0, 0], "M5-T07/10 first acceptance effect exactly once")
	var receipt_count: int = snapshot.social_effect_receipts.size()
	var maintenance: Dictionary = M5Artifact.begin("CLOSE")
	M5Maintenance.memories(snapshot, 30, maintenance)
	var before: Array = ModelData.object_array_to_data(snapshot.relations)
	var replay: WorldState = M5Data.clone(snapshot)
	var artifact: Dictionary = M5Artifact.begin("CONTACTS")
	M5Effects.apply(snapshot, replay, [received], {}, artifact)
	_equal(replay.social_effect_receipts.size(), receipt_count, "M5-T16 receipt retained after compression")
	_equal(artifact.effect_applications.size(), 0, "M5-T16 compressed event never reapplied")
	_equal(ModelData.object_array_to_data(replay.relations), before, "M5-T16 compressed event relation unchanged")
	_group_completed = true


func _test_native_zero_and_order() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var sub: DecisionSubmission = M5FixtureFactory.submission(world, "person:000001")
	var invalidated: M5OperationResult = M5Facade.execute_decisions_v1(world, M5RequestStamp.for_world(world), [sub], M5FixtureFactory.issuer(world, [sub], ["person:000001"]))
	_expect(invalidated.ok, "M5-T02 missing target invalidates outcome inside committed batch")
	if invalidated.ok:
		_equal(invalidated.next_world.events.size(), world.events.size(), "M5-T02 INVALIDATED creates no event")
		_equal(invalidated.next_world.social_effect_receipts.size(), 0, "M5-T02 INVALIDATED creates no response")
		_equal([invalidated.next_world.resolution_epoch, invalidated.next_world.social_state.last_integrated_resolution_epoch], [1, 1], "M5-T02 INVALIDATED integrates epoch")
		var duplicate: M5OperationResult = M5FixtureFactory.execute(invalidated.next_world, "person:000001")
		_expect(not duplicate.ok, "M5-T02 same daily slot cannot execute again")
	# Two native claims compete for one unit. The aid offer is positive before allocation.
	var responder: PersonState = world.find_person("person:000004")
	responder.daily_food_need_units = 0
	responder.trait_scores["empathy"] = 100
	responder.value_scores["community_survival"] = 100
	responder.value_scores["fairness_reciprocity"] = 100
	responder.value_scores["life_protection"] = 100
	var donor_relation: RelationState = M5Data.relation(world, responder.id, "person:000001")
	donor_relation.trust = 100
	donor_relation.affection = 100
	donor_relation.obligation = 100
	var source: ResourceStoreState = world.find_resource_store("resource_store:household:000002")
	source.quantity = 1
	source.security_level = 0
	var thief: PersonState = world.find_person("person:000002")
	thief.trait_scores["norm_adherence"] = 0
	thief.trait_scores["empathy"] = 0
	thief.trait_scores["risk_aversion"] = 0
	thief.need_scores["hunger"] = 100
	thief.aptitude_scores["dexterity"] = 100
	thief.skill_scores["intrigue.theft"] = 100
	thief.skill_scores["intrigue.stealth"] = 100
	for fact: InformationState in world.information:
		if fact.owner_person_id == thief.id and fact.subject_kind == "resource_store":
			fact.subject_id = source.id
			if fact.fact_type_id == "theft_access":
				fact.belief_value = 100
			elif fact.fact_type_id == "detection_risk":
				fact.belief_value = 0
	var submissions: Array = [M5FixtureFactory.submission(world, "person:000001"), M5FixtureFactory.submission(world, thief.id)]
	for item: DecisionSubmission in submissions:
		_expect(item.submitted_decision_result.ok, "M5-T03 grant-zero scenario valid")
		if not item.submitted_decision_result.ok:
			return
	_equal(IntentParameterizer._selected_candidate(submissions[0].submitted_decision_result).action_id, "A04", "M5-T03 request selected")
	_equal(IntentParameterizer._selected_candidate(submissions[1].submitted_decision_result).action_id, "A11", "M5-T03 competing theft selected")
	var result: M5OperationResult = M5Facade.execute_decisions_v1(world, M5RequestStamp.for_world(world), submissions, M5FixtureFactory.issuer(world, submissions))
	_expect(result.ok, "M5-T03 native grant-zero commit: " + str(result.artifact.errors))
	if not result.ok:
		return
	var offered_zero: bool = false
	for obs: SocialObservationState in result.next_world.social_observations:
		if obs.owner_person_id == "person:000001" and obs.origin_view == "aid_requester":
			_equal(obs.payload.response_decision, "GRANT_PARTIAL", "M5-T03 offer remains GRANT_PARTIAL")
			_equal(obs.payload.actual_units, 0, "M5-T03 allocation reduces aid to zero")
		for effect: Dictionary in result.artifact.effect_applications:
			if effect.observation_id == obs.id and obs.owner_person_id == "person:000001":
				offered_zero = effect.rule_id == "aid_offered_zero" and effect.relation_deltas.is_empty()
	_expect(offered_zero, "M5-T03 zero offer uses its own rule, without refusal relation penalty")
	var reversed: Array = submissions.duplicate()
	reversed.reverse()
	var reverse_result: M5OperationResult = M5Facade.execute_decisions_v1(world, M5RequestStamp.for_world(world), reversed, M5FixtureFactory.issuer(world, reversed))
	_equal(reverse_result.to_data(), result.to_data(), "M5-T18 complete execute submission permutation")
	_group_completed = true


func _test_contact_caps_and_wire() -> void:
	var world: WorldState = M5FixtureFactory.initial()
	var extra: PersonState = PersonState.from_data(world.find_person("person:000002").to_data(5), 5)
	extra.id = IdAllocator.next_id(world, "person")
	extra.information_ids = []
	extra.memory_ids = []
	extra.relation_ids = []
	world.persons.append(extra)
	world.find_household(extra.household_id).member_ids.append(extra.id)
	_expect(StateValidator.validate_world(world).is_empty(), "M5-T08 five-person contact fixture valid")
	var pairs: Array = [["person:000001", "person:000002"], ["person:000001", "person:000003"], ["person:000001", "person:000004"]]
	var contact: M5OperationResult = M5FixtureFactory.contacts(world, pairs)
	_expect(contact.ok, "M5-T08 three partners allowed")
	pairs.append(["person:000001", extra.id])
	_equal(M5FixtureFactory.contacts(world, pairs).artifact.errors[0].code, "M5_REQUEST_CONTRACT", "M5-T08 fourth partner rejects entire plan")
	world = M5FixtureFactory.initial()
	var reports: Array = []
	for i: int in 3:
		var event: EventRecord = EventRecord.from_data(world.events[0].to_data(5), 5)
		event.id = IdAllocator.next_id(world, "event")
		world.events.append(event)
		reports.append(M5Projector._report(event, "person:000004", "aid_responder", "direct_interaction", {"requester_person_id": "person:000001", "responder_person_id": "person:000004", "requested_units": 10, "actual_units": 10, "response_decision": "GRANT_FULL"}))
	var stage: WorldState = M5Data.clone(world)
	_expect(M5Effects.apply(world, stage, reports, {}, M5Artifact.begin("EXECUTE")).is_empty(), "M5-T08 seed three actual held reports")
	stage.social_state.revision += 1
	var transmission: M5OperationResult = M5FixtureFactory.contacts(stage, [["person:000002", "person:000004"]])
	_expect(transmission.ok, "M5-T08 capped contact succeeds")
	if not transmission.ok:
		return
	_equal(transmission.artifact.observation_changes.size(), 2, "M5-T08 only two reports in one direction")
	for obs: SocialObservationState in transmission.next_world.social_observations:
		if obs.owner_person_id == "person:000002":
			_equal([obs.depth, obs.confidence, obs.original_source_person_id, obs.current_source_person_id], [1, 70, "person:000004", "person:000004"], "M5-T09 provenance and confidence decrease")
	for obs: SocialObservationState in stage.social_observations:
		obs.acquisition_type = "hearsay"
		obs.depth = 3
		obs.confidence = 70
		obs.current_source_person_id = "person:000001"
	_equal(M5Contacts.reports(stage, SocialContactPlan.from_pairs([["person:000002", "person:000004"]]), []).size(), 0, "M5-T09 depth three cannot be sent again")
	var context: Dictionary = {"N": 80, "K": 20, "C": 60, "norm_adherence": 70, "family_protection": 95}
	_equal(M5Appraisal.pressure(context, [0], 6).applied_pressure, -1, "M5-T13 day zero still counts on day six")
	_equal(M5Appraisal.pressure(context, [0], 7).applied_pressure, -2, "M5-T13 day zero expires before day seven action")
	var repeated: RepeatExposureState = M5Effects._repeat(stage, "person:000001")
	repeated.low_risk_days = [0, 1, 2, 3, 4, 5, 6]
	stage.social_state.last_settled_week_index = -1
	M5Maintenance.close(stage, 6, M5Artifact.begin("CLOSE"))
	_equal(repeated.low_risk_days, [1, 2, 3, 4, 5, 6], "M5-T13 close prunes for next day's window")
	var aid: M5OperationResult = M5FixtureFactory.execute(M5FixtureFactory.initial(), "person:000001")
	if not aid.ok:
		_expect(false, "wire fixture A04 prerequisite")
		return
	var payload: Dictionary = StateHasher.state_payload(aid.next_world)
	for invalid: Variant in ["0", null, [], false]:
		var broken: Dictionary = payload.duplicate(true)
		broken.state.events[1].m5_origin.input_resolution_epoch = invalid
		_expect(not M5StateValidator.issues(broken).is_empty(), "M5-T01 malformed nested origin rejects without conversion")
		broken = payload.duplicate(true)
		broken.state.events[1].objective_payload.actual_units = invalid
		_expect(not M5StateValidator.issues(broken).is_empty(), "M5-T01 malformed objective units reject")
	var audit: Dictionary = aid.artifact.duplicate(true)
	audit.observation_changes[0]["actual_security"] = 100
	audit = M5Artifact.finish(audit)
	_expect(not M5SaveCodec.encode_checked(aid.next_world, [], [], [audit]).ok, "M5-T01 extra audit row key rejects even with valid hash")
	audit = aid.artifact.duplicate(true)
	audit.effect_applications[0].pressure_delta = {"unexpected": 1}
	audit = M5Artifact.finish(audit)
	_expect(not M5SaveCodec.encode_checked(aid.next_world, [], [], [audit]).ok, "M5-T01 malformed nested effect rejects")
	_equal(RulesetManifest.from_data(M5Rules.current_manifest_data(), 5).to_data(), M5Rules.current_manifest_data(), "M5-T01 six manifest components round-trip")
	_group_completed = true


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _equal(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if StateCanonicalizer.canonical_json(actual) != StateCanonicalizer.canonical_json(expected):
		failures.append(message + ": " + _difference(actual, expected, "$"))


func _difference(actual: Variant, expected: Variant, path: String) -> String:
	if typeof(actual) != typeof(expected):
		return path + " types differ"
	if typeof(actual) == TYPE_DICTIONARY:
		for key: Variant in expected:
			if not actual.has(key):
				return path + "." + str(key) + " missing"
			if StateCanonicalizer.canonical_json(actual[key]) != StateCanonicalizer.canonical_json(expected[key]):
				return _difference(actual[key], expected[key], path + "." + str(key))
	elif typeof(actual) == TYPE_ARRAY:
		if actual.size() != expected.size():
			return path + " sizes differ %d != %d" % [actual.size(), expected.size()]
		var a: Array = StateCanonicalizer.canonicalize(actual)
		var b: Array = StateCanonicalizer.canonicalize(expected)
		for i: int in a.size():
			if a[i] != b[i]:
				return _difference(a[i], b[i], path + "[%d]" % i)
	return path + " (" + str(actual).left(150) + " != " + str(expected).left(150) + ")"
