class_name DayProcessor
extends RefCounted


static func advance_day(current_world: WorldState) -> DayAdvanceResult:
	if current_world.schema_version == WorldState.SCHEMA_VERSION_M4:
		return _advance_schema4(current_world)
	var input_errors: Array[String] = StateValidator.validate_world(current_world)
	if current_world.schema_version != WorldState.SCHEMA_VERSION_M2:
		input_errors.append("M2 day processing requires schema 2")
	if current_world.day_phase != WorldState.DAY_END_PHASE:
		input_errors.append("M2 day processing requires DAY_END input")
	if current_world.ruleset_id != M2ResourceRules.RULESET_ID:
		input_errors.append("M2 day processing requires ruleset %s" % M2ResourceRules.RULESET_ID)
	if current_world.ruleset_hash != M2ResourceRules.ruleset_hash():
		input_errors.append("M2 day processing ruleset hash mismatch")
	if not input_errors.is_empty():
		return DayAdvanceResult.failure(input_errors)

	var metadata: Dictionary = {
		"schema_version": current_world.schema_version,
		"ruleset_id": current_world.ruleset_id,
		"ruleset_hash": current_world.ruleset_hash,
	}
	var next_world: WorldState = WorldState.from_data(metadata, current_world.to_state_data())
	var guard: DayPhaseGuard = DayPhaseGuard.new()
	var phase_error: String = guard.advance(DayPhaseGuard.NEEDS_FIXED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var before_total: int = ResourceService.total_quantity(next_world)
	var plan: DayPlan = _build_plan(next_world)
	phase_error = guard.advance(DayPhaseGuard.ALLOCATION_PLANNED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var transaction_errors: Array[String] = ResourceService.apply_transactions(
		next_world, plan.resource_transactions
	)
	if not transaction_errors.is_empty():
		return DayAdvanceResult.failure(transaction_errors)
	phase_error = guard.advance(DayPhaseGuard.CONSUMPTION_APPLIED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	for person: PersonState in next_world.persons:
		if not person.alive:
			continue
		var hunger_error: String = PersonDayUpdate.update_hunger(
			person, plan.eaten_by(person.id)
		)
		if not hunger_error.is_empty():
			return DayAdvanceResult.failure([hunger_error])
	phase_error = guard.advance(DayPhaseGuard.HUNGER_UPDATED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	for person: PersonState in next_world.persons:
		if not person.alive:
			continue
		var health_error: String = PersonDayUpdate.update_health(person)
		if not health_error.is_empty():
			return DayAdvanceResult.failure([health_error])
	phase_error = guard.advance(DayPhaseGuard.HEALTH_UPDATED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var reconciliation: Dictionary = ResourceService.reconcile(
		current_world, next_world, plan.resource_transactions
	)
	var conservation_errors: Array[String] = reconciliation["errors"]
	var after_total: int = ResourceService.total_quantity(next_world)
	var consumed_total: int = int(reconciliation["consumed_total"])
	if before_total != after_total + consumed_total:
		conservation_errors.append(
			"food conservation failed: %d != %d + %d"
			% [before_total, after_total, consumed_total]
		)
	if not conservation_errors.is_empty():
		return DayAdvanceResult.failure(conservation_errors)
	phase_error = guard.advance(DayPhaseGuard.CONSERVATION_VERIFIED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	next_world.day_index += 1
	phase_error = guard.advance(DayPhaseGuard.DAY_END)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])
	var final_errors: Array[String] = StateValidator.validate_world(next_world)
	if not final_errors.is_empty():
		return DayAdvanceResult.failure(final_errors)
	if StateHasher.hash_world(next_world).is_empty():
		return DayAdvanceResult.failure(["failed to hash completed M2 day"])
	return DayAdvanceResult.success(
		next_world, plan.resource_transactions, before_total, after_total, consumed_total
	)


static func _build_plan(world: WorldState) -> DayPlan:
	var plan: DayPlan = DayPlan.new()
	var households: Array[HouseholdState] = world.households.duplicate()
	households.sort_custom(_compare_household_ids)
	var sequence_index: int = 0
	for household: HouseholdState in households:
		var members: Array[PersonState] = []
		for person_id: String in household.member_ids:
			var person: PersonState = world.find_person(person_id)
			if person != null and person.alive:
				members.append(person)
		var store: ResourceStoreState = world.find_resource_store(household.resource_store_id)
		var allocation: Dictionary = ConsumptionAllocation.allocate(
			members, store.quantity, world.day_index
		)
		var household_allocations: Dictionary = allocation["allocations"]
		for person: PersonState in members:
			var eaten: int = int(household_allocations.get(person.id, 0))
			plan.allocations[person.id] = eaten
			if eaten == 0:
				continue
			var transaction: ResourceTransactionRecord = ResourceTransactionRecord.new()
			transaction.id = IdAllocator.next_id(world, "resource_transaction")
			transaction.day_index = world.day_index + 1
			transaction.sequence_index = sequence_index
			transaction.source_store_id = store.id
			transaction.consumer_person_id = person.id
			transaction.quantity = eaten
			transaction.reason_id = "daily_food_consumption"
			plan.resource_transactions.append(transaction)
			sequence_index += 1
	return plan


static func _compare_household_ids(left: HouseholdState, right: HouseholdState) -> bool:
	return left.id < right.id


static func _advance_m5(scope: M5OperationScope) -> DayAdvanceResult:
	if not scope.is_owned() or scope.operation_kind != "CLOSE":
		return DayAdvanceResult.failure(["unowned M5 day scope"])
	return _advance_schema4(scope.input_world, scope)


static func _advance_schema4(current_world: WorldState, scope: M5OperationScope = null) -> DayAdvanceResult:
	if current_world.schema_version == 5 and (scope == null or not scope.owns_input(current_world)):
		return DayAdvanceResult.failure(["Schema 5 day processing requires M5 scope"])
	var input_errors: Array[String] = StateValidator.validate_world(current_world)
	input_errors.append_array(
		M4Rules.validate_world_manifest(current_world, ["resource", "resolution"])
	)
	if current_world.day_phase != WorldState.DAY_END_PHASE:
		input_errors.append("schema 4 day processing requires DAY_END input")
	if not input_errors.is_empty():
		return DayAdvanceResult.failure(input_errors)
	if current_world.day_index >= 2147483647:
		return DayAdvanceResult.failure(["schema 4 day index overflow"])

	var transaction_count: int = _count_schema4_consumption_transactions(current_world)
	if transaction_count < 0:
		return DayAdvanceResult.failure(["failed to preflight schema 4 consumption"])
	if transaction_count > 2147483647 - current_world.next_resource_sequence_index:
		return DayAdvanceResult.failure(["schema 4 resource sequence overflow"])
	var next_resource_id: int = int(current_world.next_ids.get("resource_transaction", 0))
	if next_resource_id <= 0 or transaction_count > 2147483647 - next_resource_id:
		return DayAdvanceResult.failure(["schema 4 resource transaction ID overflow"])

	var metadata: Dictionary = {
		"schema_version": current_world.schema_version,
		"ruleset_manifest": current_world.ruleset_manifest.duplicate(true),
		"simulation_ruleset_hash": current_world.simulation_ruleset_hash,
	}
	var next_world: WorldState = WorldState.from_data(metadata, current_world.to_state_data())
	var guard: DayPhaseGuard = DayPhaseGuard.new()
	var phase_error: String = guard.advance(DayPhaseGuard.NEEDS_FIXED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var before_total: int = ResourceService.total_quantity(next_world)
	var plan: DayPlan = _build_plan_schema4(
		next_world, current_world.next_resource_sequence_index
	)
	phase_error = guard.advance(DayPhaseGuard.ALLOCATION_PLANNED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var transaction_errors: Array[String]
	if scope != null:
		scope.register_stage(next_world)
		transaction_errors = ResourceService._apply_m5(scope, next_world, plan.resource_transactions)
	else:
		transaction_errors = ResourceService.apply_transactions(next_world, plan.resource_transactions)
	if not transaction_errors.is_empty():
		return DayAdvanceResult.failure(transaction_errors)
	phase_error = guard.advance(DayPhaseGuard.CONSUMPTION_APPLIED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	for person: PersonState in next_world.persons:
		if not person.alive:
			continue
		var hunger_error: String = PersonDayUpdate.update_hunger(
			person, plan.eaten_by(person.id)
		)
		if not hunger_error.is_empty():
			return DayAdvanceResult.failure([hunger_error])
	phase_error = guard.advance(DayPhaseGuard.HUNGER_UPDATED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var health_persons: Array[PersonState] = next_world.persons
	if next_world.schema_version == WorldState.SCHEMA_VERSION_M5:
		# D26 section 7 selects same-stage health errors by entity ID.
		health_persons = health_persons.duplicate()
		health_persons.sort_custom(_compare_person_ids)
	for person: PersonState in health_persons:
		if not person.alive:
			continue
		var health_error: String = PersonDayUpdate.update_health(person)
		if not health_error.is_empty():
			return DayAdvanceResult.failure([health_error])
	phase_error = guard.advance(DayPhaseGuard.HEALTH_UPDATED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	var reconciliation: Dictionary = ResourceService.reconcile(
		current_world, next_world, plan.resource_transactions
	)
	var conservation_errors: Array[String] = reconciliation.get("errors", [])
	var after_total: int = ResourceService.total_quantity(next_world)
	var consumed_total: int = int(reconciliation.get("consumed_total", 0))
	if before_total != after_total + consumed_total:
		conservation_errors.append(
			"food conservation failed: %d != %d + %d"
			% [before_total, after_total, consumed_total]
		)
	if not conservation_errors.is_empty():
		return DayAdvanceResult.failure(conservation_errors)
	phase_error = guard.advance(DayPhaseGuard.CONSERVATION_VERIFIED)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])

	next_world.day_index += 1
	next_world.next_resource_sequence_index = (
		current_world.next_resource_sequence_index + plan.resource_transactions.size()
	)
	next_world.resolved_decision_slot_ids = []
	phase_error = guard.advance(DayPhaseGuard.DAY_END)
	if not phase_error.is_empty():
		return DayAdvanceResult.failure([phase_error])
	var final_errors: Array[String] = (M5StageBoundary._validate_after_day_resources(scope, next_world, plan.resource_transactions) if scope != null else StateValidator.validate_world(next_world))
	if not final_errors.is_empty():
		return DayAdvanceResult.failure(final_errors)
	if scope == null and StateHasher.hash_world(next_world).is_empty():
		return DayAdvanceResult.failure(["failed to hash completed schema 4 day"])
	return DayAdvanceResult.success(
		next_world, plan.resource_transactions, before_total, after_total, consumed_total
	)


static func _build_plan_schema4(world: WorldState, sequence_start: int) -> DayPlan:
	var plan: DayPlan = DayPlan.new()
	var households: Array[HouseholdState] = world.households.duplicate()
	households.sort_custom(_compare_household_ids)
	var sequence_index: int = sequence_start
	for household: HouseholdState in households:
		var members: Array[PersonState] = []
		for person_id: String in household.member_ids:
			var person: PersonState = world.find_person(person_id)
			if person != null and person.alive:
				members.append(person)
		members.sort_custom(_compare_person_ids)
		var store: ResourceStoreState = world.find_resource_store(household.resource_store_id)
		var allocation: Dictionary = ConsumptionAllocation.allocate(
			members, store.quantity, world.day_index
		)
		var household_allocations: Dictionary = allocation.get("allocations", {})
		for person: PersonState in members:
			var eaten: int = int(household_allocations.get(person.id, 0))
			plan.allocations[person.id] = eaten
			if eaten == 0:
				continue
			var transaction: ResourceTransactionRecord = ResourceTransactionRecord.new()
			transaction.id = IdAllocator.next_id(world, "resource_transaction")
			transaction.day_index = world.day_index + 1
			transaction.sequence_index = sequence_index
			transaction.source_store_id = store.id
			transaction.destination_store_id = ""
			transaction.consumer_person_id = person.id
			transaction.quantity = eaten
			transaction.reason_id = "daily_food_consumption"
			plan.resource_transactions.append(transaction)
			sequence_index += 1
	return plan


static func _count_schema4_consumption_transactions(world: WorldState) -> int:
	var count: int = 0
	var households: Array[HouseholdState] = world.households.duplicate()
	households.sort_custom(_compare_household_ids)
	for household: HouseholdState in households:
		var members: Array[PersonState] = []
		for person_id: String in household.member_ids:
			var person: PersonState = world.find_person(person_id)
			if person != null and person.alive:
				members.append(person)
		members.sort_custom(_compare_person_ids)
		var store: ResourceStoreState = world.find_resource_store(household.resource_store_id)
		if store == null:
			return -1
		var allocation: Dictionary = ConsumptionAllocation.allocate(
			members, store.quantity, world.day_index
		)
		var household_allocations: Dictionary = allocation.get("allocations", {})
		for person: PersonState in members:
			if int(household_allocations.get(person.id, 0)) > 0:
				count += 1
	return count


static func _compare_person_ids(left: PersonState, right: PersonState) -> bool:
	return left.id < right.id
