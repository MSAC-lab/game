class_name M2TimeResourceTest
extends RefCounted

const FROZEN_JSON_PATH: String = "res://tests/fixtures/m2_day10_canonical.json"
const FROZEN_HASH_PATH: String = "res://tests/fixtures/m2_day10_canonical.sha256"
const M1_JSON_PATH: String = "res://tests/fixtures/m1_canonical.json"
const M1_HASH_PATH: String = "res://tests/fixtures/m1_canonical.sha256"

var _failures: Array[String] = []


func run_all() -> Array[String]:
	_test_t01_day_increment_and_schema2_round_trip()
	_test_t02_sufficient_food()
	_test_t03_shortage_proportional_rotation()
	_test_t04_conservation()
	_test_t05_one_consumption_per_person_day()
	_test_t06_hunger_tracks_shortfall()
	_test_t07_health_threshold_and_delay()
	_test_t08_deterministic_ten_days()
	_test_t09_day_end_save_resume()
	_test_t10_phase_order_guard()
	_test_t11_frozen_day10_artifacts()
	_test_t12_daily_ledger_reconciliation()
	_test_r01_m1_frozen_regression()
	_test_r02_rng_is_unchanged()
	_test_r03_failed_day_is_atomic()
	_test_r04_schema_boundary()
	_test_r05_explicit_transfer_conserves_food()
	_test_r06_resource_audit_is_excluded_from_hash()
	_test_r07_unlogged_change_is_detected()
	_test_r08_death_boundary_is_atomic()
	return _failures


func fixture_artifacts() -> Dictionary:
	var simulation: Dictionary = _simulate_days(M2FixtureFactory.create_world(), 10)
	if not bool(simulation["ok"]):
		return {"json": "", "hash": "", "errors": simulation["errors"]}
	var world: WorldState = simulation["world"]
	var transactions: Array[ResourceTransactionRecord] = simulation["transactions"]
	return {
		"json": StateCodec.encode(world, [] as Array[DecisionRecord], transactions),
		"hash": StateHasher.hash_world(world) + "\n",
		"errors": [] as Array[String],
	}


func _test_t01_day_increment_and_schema2_round_trip() -> void:
	var original: WorldState = M2FixtureFactory.create_world()
	var before_hash: String = StateHasher.hash_world(original)
	var result: DayAdvanceResult = DayProcessor.advance_day(original)
	_expect(result.ok, "M2-T01 one atomic day succeeds: %s" % str(result.errors))
	if not result.ok:
		return
	_expect(result.next_world.day_index == 1, "M2-T01 completed day increments day_index once")
	_expect(StateHasher.hash_world(original) == before_hash, "M2-T01 input world remains unchanged")
	var encoded: String = StateCodec.encode(
		result.next_world, [] as Array[DecisionRecord], result.resource_transactions
	)
	var decoded: Dictionary = StateCodec.decode(encoded)
	_expect(bool(decoded["ok"]), "M2-T01 schema 2 envelope round-trips: %s" % str(decoded["errors"]))
	if bool(decoded["ok"]):
		_expect(
			StateHasher.hash_world(decoded["world"]) == StateHasher.hash_world(result.next_world),
			"M2-T01 restored schema 2 world has identical hash"
		)


func _test_t02_sufficient_food() -> void:
	var result: DayAdvanceResult = DayProcessor.advance_day(M2FixtureFactory.create_world())
	if not _require_result(result, "M2-T02"):
		return
	var world: WorldState = result.next_world
	var all_fed: bool = true
	for person: PersonState in world.persons:
		all_fed = all_fed and int(person.need_scores["hunger"]) == 0
	_expect(all_fed, "M2-T02 sufficient household stores fully feed every person")
	_expect(result.consumed_total == 14, "M2-T02 day one consumes exact total need of 14")


func _test_t03_shortage_proportional_rotation() -> void:
	var world: WorldState = M2FixtureFactory.create_world()
	var members: Array[PersonState] = [
		world.find_person("person:000001"),
		world.find_person("person:000002"),
		world.find_person("person:000004"),
	]
	var day_zero: Dictionary = ConsumptionAllocation.allocate(members, 2, 0)
	var day_one: Dictionary = ConsumptionAllocation.allocate(members, 2, 1)
	var again: Dictionary = ConsumptionAllocation.allocate(members, 2, 0)
	_expect(day_zero == again, "M2-T03 same shortage inputs produce identical allocation")
	var zero_allocations: Dictionary = day_zero["allocations"]
	var one_allocations: Dictionary = day_one["allocations"]
	_expect(
		int(zero_allocations["person:000001"]) == 1
		and int(zero_allocations["person:000002"]) == 1
		and int(zero_allocations["person:000004"]) == 0,
		"M2-T03 day-index remainder starts at canonical first person"
	)
	_expect(
		int(one_allocations["person:000001"]) == 0
		and int(one_allocations["person:000002"]) == 1
		and int(one_allocations["person:000004"]) == 1,
		"M2-T03 remainder start rotates with day index"
	)
	_expect(int(day_zero["allocated_total"]) == 2, "M2-T03 shortage never creates or loses food")


func _test_t04_conservation() -> void:
	var result: DayAdvanceResult = DayProcessor.advance_day(M2FixtureFactory.create_world())
	if not _require_result(result, "M2-T04"):
		return
	_expect(
		result.before_total == result.after_total + result.consumed_total,
		"M2-T04 before food equals after food plus consumption"
	)


func _test_t05_one_consumption_per_person_day() -> void:
	var result: DayAdvanceResult = DayProcessor.advance_day(M2FixtureFactory.create_world())
	if not _require_result(result, "M2-T05"):
		return
	var keys: Dictionary = {}
	var unique: bool = true
	for record: ResourceTransactionRecord in result.resource_transactions:
		var key: String = "%d:%s" % [record.day_index, record.consumer_person_id]
		unique = unique and not keys.has(key)
		keys[key] = true
	_expect(unique, "M2-T05 each person has at most one consumption transaction per day")


func _test_t06_hunger_tracks_shortfall() -> void:
	var full: PersonState = _test_person(2, 50)
	var half: PersonState = _test_person(2, 10)
	var none: PersonState = _test_person(2, 10)
	var one_need: PersonState = _test_person(1, 10)
	PersonDayUpdate.update_hunger(full, 2)
	PersonDayUpdate.update_hunger(half, 1)
	PersonDayUpdate.update_hunger(none, 0)
	PersonDayUpdate.update_hunger(one_need, 0)
	_expect(int(full.need_scores["hunger"]) == 44, "M2-T06 full meal reduces hunger by 6")
	_expect(int(half.need_scores["hunger"]) == 22, "M2-T06 half of need raises hunger by 12")
	_expect(int(none.need_scores["hunger"]) == 34, "M2-T06 zero of need 2 raises hunger by 24")
	_expect(int(one_need.need_scores["hunger"]) == 34, "M2-T06 zero of need 1 raises hunger by 24")


func _test_t07_health_threshold_and_delay() -> void:
	var person: PersonState = _test_person(2, 80)
	person.health = 100
	var first_error: String = PersonDayUpdate.update_health(person)
	var first_health: int = person.health
	var second_error: String = PersonDayUpdate.update_health(person)
	_expect(first_error.is_empty() and second_error.is_empty(), "M2-T07 health updates succeed")
	_expect(first_health == 100, "M2-T07 first severe-hunger day causes no damage")
	_expect(person.health == 95, "M2-T07 second severe-hunger day causes 5 damage")
	person.need_scores["hunger"] = 79
	PersonDayUpdate.update_health(person)
	_expect(person.severe_hunger_days == 0, "M2-T07 leaving threshold resets severe-day counter")


func _test_t08_deterministic_ten_days() -> void:
	var first: Dictionary = _simulate_days(M2FixtureFactory.create_world(), 10)
	var second: Dictionary = _simulate_days(M2FixtureFactory.create_world(), 10)
	_expect(bool(first["ok"]) and bool(second["ok"]), "M2-T08 both ten-day runs succeed")
	if not bool(first["ok"]) or not bool(second["ok"]):
		return
	_expect(first["hashes"] == second["hashes"], "M2-T08 every daily state hash is reproducible")
	var world: WorldState = first["world"]
	_expect(ResourceService.total_quantity(world) == 100, "M2-T08 day 10 leaves only granary food")
	_expect(int(first["consumed_total"]) == 81, "M2-T08 ten days consume exactly 81 food")


func _test_t09_day_end_save_resume() -> void:
	var continuous: Dictionary = _simulate_days(M2FixtureFactory.create_world(), 10)
	var first_half: Dictionary = _simulate_days(M2FixtureFactory.create_world(), 5)
	if not bool(continuous["ok"]) or not bool(first_half["ok"]):
		_expect(false, "M2-T09 prerequisite simulation succeeds")
		return
	var saved: String = StateCodec.encode(
		first_half["world"], [] as Array[DecisionRecord], first_half["transactions"]
	)
	var decoded: Dictionary = StateCodec.decode(saved)
	_expect(bool(decoded["ok"]), "M2-T09 day-end save decodes: %s" % str(decoded["errors"]))
	if not bool(decoded["ok"]):
		return
	var second_half: Dictionary = _simulate_days(decoded["world"], 5)
	_expect(bool(second_half["ok"]), "M2-T09 resumed five-day run succeeds")
	if bool(second_half["ok"]):
		_expect(
			StateHasher.hash_world(continuous["world"])
			== StateHasher.hash_world(second_half["world"]),
			"M2-T09 five-day save/resume equals continuous ten-day state"
		)


func _test_t10_phase_order_guard() -> void:
	var guard: DayPhaseGuard = DayPhaseGuard.new()
	var skipped: String = guard.advance(DayPhaseGuard.ALLOCATION_PLANNED)
	var first: String = guard.advance(DayPhaseGuard.NEEDS_FIXED)
	var duplicate: String = guard.advance(DayPhaseGuard.NEEDS_FIXED)
	_expect(not skipped.is_empty(), "M2-T10 skipped phase is rejected")
	_expect(first.is_empty(), "M2-T10 expected phase is accepted")
	_expect(not duplicate.is_empty(), "M2-T10 duplicate or reverse phase is rejected")


func _test_t11_frozen_day10_artifacts() -> void:
	if not FileAccess.file_exists(FROZEN_JSON_PATH) or not FileAccess.file_exists(FROZEN_HASH_PATH):
		_expect(false, "M2-T11 frozen day-10 artifact files exist")
		return
	var artifacts: Dictionary = fixture_artifacts()
	_expect(Array(artifacts["errors"]).is_empty(), "M2-T11 fixture generation succeeds")
	_expect(
		str(artifacts["json"]) == FileAccess.get_file_as_string(FROZEN_JSON_PATH),
		"M2-T11 day-10 canonical JSON matches frozen artifact"
	)
	_expect(
		str(artifacts["hash"]) == FileAccess.get_file_as_string(FROZEN_HASH_PATH),
		"M2-T11 day-10 SHA-256 matches frozen artifact"
	)


func _test_t12_daily_ledger_reconciliation() -> void:
	var world: WorldState = M2FixtureFactory.create_world()
	var all_reconciled: bool = true
	for _day: int in 10:
		var result: DayAdvanceResult = DayProcessor.advance_day(world)
		if not result.ok:
			all_reconciled = false
			break
		var reconciliation: Dictionary = ResourceService.reconcile(
			world, result.next_world, result.resource_transactions
		)
		all_reconciled = all_reconciled and Array(reconciliation["errors"]).is_empty()
		world = result.next_world
	_expect(all_reconciled, "M2-T12 every daily store delta is explained by the ledger")


func _test_r01_m1_frozen_regression() -> void:
	var suite: M1StateModelTest = M1StateModelTest.new()
	var artifacts: Dictionary = suite.fixture_artifacts()
	_expect(
		str(artifacts["json"]) == FileAccess.get_file_as_string(M1_JSON_PATH),
		"M2-R01 schema 1 canonical JSON remains frozen"
	)
	_expect(
		str(artifacts["hash"]) == FileAccess.get_file_as_string(M1_HASH_PATH),
		"M2-R01 schema 1 SHA-256 remains frozen"
	)


func _test_r02_rng_is_unchanged() -> void:
	var before: WorldState = M2FixtureFactory.create_world()
	var result: DayAdvanceResult = DayProcessor.advance_day(before)
	if not _require_result(result, "M2-R02"):
		return
	_expect(result.next_world.rng_seed_hex == before.rng_seed_hex, "M2-R02 RNG seed is unchanged")
	_expect(result.next_world.rng_state_hex == before.rng_state_hex, "M2-R02 RNG state is unchanged")


func _test_r03_failed_day_is_atomic() -> void:
	var world: WorldState = M2FixtureFactory.create_world()
	world.find_resource_store("resource_store:household:000001").quantity = -1
	var before: String = StateCanonicalizer.canonical_json(StateHasher.state_payload(world))
	var result: DayAdvanceResult = DayProcessor.advance_day(world)
	_expect(not result.ok, "M2-R03 invalid input day fails")
	_expect(result.next_world == null, "M2-R03 failed day returns no next world")
	_expect(result.resource_transactions.is_empty(), "M2-R03 failed day returns no partial transactions")
	_expect(
		StateCanonicalizer.canonical_json(StateHasher.state_payload(world)) == before,
		"M2-R03 failed day leaves input state untouched"
	)


func _test_r04_schema_boundary() -> void:
	var m1: WorldState = M1FixtureFactory.create()["world"]
	var m2: WorldState = M2FixtureFactory.create_world()
	var m1_state: Dictionary = m1.to_state_data()
	var m2_state: Dictionary = m2.to_state_data()
	var m1_households: Array = m1_state["households"]
	var m2_households: Array = m2_state["households"]
	_expect(
		not m1_state.has("resource_stores") and not m1_state.has("day_phase"),
		"M2-R04 schema 1 excludes M2 top-level state fields"
	)
	_expect(
		m2_state.has("resource_stores") and m2_state.has("day_phase"),
		"M2-R04 schema 2 requires M2 top-level state fields"
	)
	_expect(
		Dictionary(m1_households[0]).has("food_units")
		and not Dictionary(m1_households[0]).has("resource_store_id"),
		"M2-R04 schema 1 household retains only legacy food fields"
	)
	_expect(
		not Dictionary(m2_households[0]).has("food_units")
		and Dictionary(m2_households[0]).has("resource_store_id"),
		"M2-R04 schema 2 household uses only resource store reference"
	)


func _test_r05_explicit_transfer_conserves_food() -> void:
	var before: WorldState = M2FixtureFactory.create_world()
	var after: WorldState = _clone_world(before)
	var record: ResourceTransactionRecord = ResourceTransactionRecord.new()
	record.id = "resource_transaction:900001"
	record.day_index = 1
	record.sequence_index = 0
	record.source_store_id = "resource_store:village_granary"
	record.destination_store_id = "resource_store:household:000001"
	record.quantity = 10
	record.reason_id = "test_explicit_transfer"
	var records: Array[ResourceTransactionRecord] = [record]
	var errors: Array[String] = ResourceService.apply_transactions(after, records)
	var reconciliation: Dictionary = ResourceService.reconcile(before, after, records)
	_expect(errors.is_empty(), "M2-R05 explicit granary transfer applies")
	_expect(
		ResourceService.total_quantity(before) == ResourceService.total_quantity(after),
		"M2-R05 transfer conserves total food"
	)
	_expect(Array(reconciliation["errors"]).is_empty(), "M2-R05 transfer ledger reconciles")


func _test_r06_resource_audit_is_excluded_from_hash() -> void:
	var result: DayAdvanceResult = DayProcessor.advance_day(M2FixtureFactory.create_world())
	if not _require_result(result, "M2-R06"):
		return
	var before_hash: String = StateHasher.hash_world(result.next_world)
	result.resource_transactions[0].reason_id = "audit-only edited reason"
	_expect(
		StateHasher.hash_world(result.next_world) == before_hash,
		"M2-R06 ResourceTransactionRecord changes do not affect future state hash"
	)


func _test_r07_unlogged_change_is_detected() -> void:
	var before: WorldState = M2FixtureFactory.create_world()
	var after: WorldState = _clone_world(before)
	after.find_resource_store("resource_store:household:000001").quantity -= 1
	var reconciliation: Dictionary = ResourceService.reconcile(
		before, after, [] as Array[ResourceTransactionRecord]
	)
	_expect(
		not Array(reconciliation["errors"]).is_empty(),
		"M2-R07 direct quantity manipulation is detected as unexplained"
	)


func _test_r08_death_boundary_is_atomic() -> void:
	var world: WorldState = M2FixtureFactory.create_world()
	world.find_resource_store("resource_store:household:000001").quantity = 0
	var person: PersonState = world.find_person("person:000001")
	person.need_scores["hunger"] = 80
	person.severe_hunger_days = 1
	person.health = 5
	var before: String = StateCanonicalizer.canonical_json(StateHasher.state_payload(world))
	var result: DayAdvanceResult = DayProcessor.advance_day(world)
	_expect(_contains(result.errors, "M2_DEATH_NOT_IMPLEMENTED"), "M2-R08 death boundary fails explicitly")
	_expect(not result.ok and result.next_world == null, "M2-R08 death boundary returns no next world")
	_expect(result.resource_transactions.is_empty(), "M2-R08 death boundary returns no partial ledger")
	_expect(
		StateCanonicalizer.canonical_json(StateHasher.state_payload(world)) == before,
		"M2-R08 death-boundary failure leaves input unchanged"
	)


func _simulate_days(start_world: WorldState, day_count: int) -> Dictionary:
	var world: WorldState = start_world
	var transactions: Array[ResourceTransactionRecord] = []
	var hashes: Array[String] = []
	var consumed_total: int = 0
	for _day: int in day_count:
		var result: DayAdvanceResult = DayProcessor.advance_day(world)
		if not result.ok:
			return {
				"ok": false,
				"errors": result.errors,
				"world": world,
				"transactions": transactions,
				"hashes": hashes,
				"consumed_total": consumed_total,
			}
		world = result.next_world
		transactions.append_array(result.resource_transactions)
		hashes.append(StateHasher.hash_world(world))
		consumed_total += result.consumed_total
	return {
		"ok": true,
		"errors": [] as Array[String],
		"world": world,
		"transactions": transactions,
		"hashes": hashes,
		"consumed_total": consumed_total,
	}


func _clone_world(world: WorldState) -> WorldState:
	return WorldState.from_data(
		{
			"schema_version": world.schema_version,
			"ruleset_id": world.ruleset_id,
			"ruleset_hash": world.ruleset_hash,
		},
		world.to_state_data()
	)


func _test_person(food_need: int, hunger: int) -> PersonState:
	var person: PersonState = PersonState.new()
	person.id = "person:test"
	person.daily_food_need_units = food_need
	person.need_scores = {"hunger": hunger}
	return person


func _require_result(result: DayAdvanceResult, test_id: String) -> bool:
	_expect(result.ok, "%s prerequisite day succeeds: %s" % [test_id, str(result.errors)])
	return result.ok


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _contains(messages: Array[String], needle: String) -> bool:
	for message: String in messages:
		if message.contains(needle):
			return true
	return false
