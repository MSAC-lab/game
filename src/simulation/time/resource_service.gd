class_name ResourceService
extends RefCounted


static func total_quantity(world: WorldState) -> int:
	var total: int = 0
	for store: ResourceStoreState in world.resource_stores:
		total += store.quantity
	return total


static func validate_transactions(
	world: WorldState, transactions: Array[ResourceTransactionRecord]
) -> Array[String]:
	var errors: Array[String] = []
	if world.schema_version == WorldState.SCHEMA_VERSION_M4:
		errors.append_array(M4Rules.validate_world_manifest(world, ["resource"]))
	var simulated_quantities: Dictionary = {}
	for store: ResourceStoreState in world.resource_stores:
		simulated_quantities[store.id] = store.quantity
	var transaction_ids: Dictionary = {}
	var consumed_people: Dictionary = {}
	var sequence_keys: Dictionary = {}
	var ordered_transactions: Array[ResourceTransactionRecord] = _ordered(transactions)
	for record: ResourceTransactionRecord in ordered_transactions:
		if record.id.is_empty():
			errors.append("resource transaction ID must not be empty")
		elif transaction_ids.has(record.id):
			errors.append("duplicate resource transaction ID: %s" % record.id)
		else:
			transaction_ids[record.id] = true
		if record.quantity <= 0:
			errors.append("resource transaction %s quantity must be positive" % record.id)
		if record.day_index < 0 or record.sequence_index < 0:
			errors.append("resource transaction %s day and sequence must be non-negative" % record.id)
		elif (
			world.schema_version == WorldState.SCHEMA_VERSION_M4
			and (record.day_index > 2147483647 or record.sequence_index > 2147483647)
		):
			errors.append("resource transaction %s day or sequence overflows schema 4" % record.id)
		var sequence_key: String = (
			str(record.sequence_index)
			if world.schema_version == WorldState.SCHEMA_VERSION_M4
			else "%d:%d" % [record.day_index, record.sequence_index]
		)
		if sequence_keys.has(sequence_key):
			if world.schema_version == WorldState.SCHEMA_VERSION_M4:
				errors.append(
					"duplicate resource transaction sequence identity: %s" % sequence_key
				)
			else:
				errors.append(
					"duplicate resource transaction day and sequence: %s" % sequence_key
				)
		else:
			sequence_keys[sequence_key] = true
		if record.resource_type_id != "food":
			errors.append("resource transaction %s must use food" % record.id)
		if record.reason_id.is_empty():
			errors.append("resource transaction %s reason_id must not be empty" % record.id)
		if not simulated_quantities.has(record.source_store_id):
			errors.append("resource transaction %s source store is missing" % record.id)

		var is_transfer: bool = not record.destination_store_id.is_empty()
		var is_consumption: bool = not record.consumer_person_id.is_empty()
		if is_transfer == is_consumption:
			errors.append(
				"resource transaction %s must have exactly one destination or consumer" % record.id
			)
		if is_transfer:
			if record.destination_store_id == record.source_store_id:
				errors.append("resource transaction %s source and destination are identical" % record.id)
			if not simulated_quantities.has(record.destination_store_id):
				errors.append("resource transaction %s destination store is missing" % record.id)
			elif (
				record.quantity > 0
				and int(simulated_quantities[record.destination_store_id])
				> 2147483647 - record.quantity
			):
				errors.append("resource transaction %s overflows destination store" % record.id)
		if is_consumption:
			if world.find_person(record.consumer_person_id) == null:
				errors.append("resource transaction %s consumer person is missing" % record.id)
			var consumer_key: String = "%d:%s" % [record.day_index, record.consumer_person_id]
			if consumed_people.has(consumer_key):
				errors.append(
					"person %s has more than one consumption on day %d"
					% [record.consumer_person_id, record.day_index]
				)
			else:
				consumed_people[consumer_key] = true

		if (
			record.quantity > 0
			and simulated_quantities.has(record.source_store_id)
			and int(simulated_quantities[record.source_store_id]) < record.quantity
		):
			errors.append("resource transaction %s overdraws source store" % record.id)
		elif record.quantity > 0 and simulated_quantities.has(record.source_store_id):
			simulated_quantities[record.source_store_id] = (
				int(simulated_quantities[record.source_store_id]) - record.quantity
			)
			if is_transfer and simulated_quantities.has(record.destination_store_id):
				simulated_quantities[record.destination_store_id] = (
					int(simulated_quantities[record.destination_store_id]) + record.quantity
				)
	return errors


static func apply_transactions(
	world: WorldState, transactions: Array[ResourceTransactionRecord]
) -> Array[String]:
	var errors: Array[String] = validate_transactions(world, transactions)
	if not errors.is_empty():
		return errors
	for record: ResourceTransactionRecord in _ordered(transactions):
		var source: ResourceStoreState = world.find_resource_store(record.source_store_id)
		source.quantity -= record.quantity
		if not record.destination_store_id.is_empty():
			var destination: ResourceStoreState = world.find_resource_store(
				record.destination_store_id
			)
			destination.quantity += record.quantity
	return errors


static func reconcile(
	before_world: WorldState,
	after_world: WorldState,
	transactions: Array[ResourceTransactionRecord]
) -> Dictionary:
	var errors: Array[String] = []
	var expected: Dictionary = {}
	for store: ResourceStoreState in before_world.resource_stores:
		expected[store.id] = store.quantity
	for record: ResourceTransactionRecord in transactions:
		if not expected.has(record.source_store_id):
			errors.append("ledger source store missing from before state: %s" % record.source_store_id)
			continue
		expected[record.source_store_id] = int(expected[record.source_store_id]) - record.quantity
		if not record.destination_store_id.is_empty():
			if not expected.has(record.destination_store_id):
				errors.append(
					"ledger destination store missing from before state: %s"
					% record.destination_store_id
				)
				continue
			expected[record.destination_store_id] = (
				int(expected[record.destination_store_id]) + record.quantity
			)
	var after_ids: Dictionary = {}
	for store: ResourceStoreState in after_world.resource_stores:
		after_ids[store.id] = true
		if not expected.has(store.id):
			errors.append("after state contains unexplained store: %s" % store.id)
		elif int(expected[store.id]) != store.quantity:
			errors.append(
				"unexplained quantity change for %s: expected %d, found %d"
				% [store.id, int(expected[store.id]), store.quantity]
			)
	for store_id: Variant in expected.keys():
		if not after_ids.has(store_id):
			errors.append("after state is missing store: %s" % store_id)
	var consumed_total: int = 0
	for record: ResourceTransactionRecord in transactions:
		if not record.consumer_person_id.is_empty():
			consumed_total += record.quantity
	return {"errors": errors, "consumed_total": consumed_total}


static func _ordered(
	transactions: Array[ResourceTransactionRecord]
) -> Array[ResourceTransactionRecord]:
	var ordered: Array[ResourceTransactionRecord] = transactions.duplicate()
	ordered.sort_custom(_compare_transactions)
	return ordered


static func _compare_transactions(
	left: ResourceTransactionRecord, right: ResourceTransactionRecord
) -> bool:
	if left.day_index != right.day_index:
		return left.day_index < right.day_index
	if left.sequence_index != right.sequence_index:
		return left.sequence_index < right.sequence_index
	return left.id < right.id
