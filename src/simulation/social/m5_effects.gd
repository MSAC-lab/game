class_name M5Effects
extends RefCounted
## Plan all owner/event effects from one snapshot, preflight IDs, then sum and clamp once.


static func apply(snapshot: WorldState, stage: WorldState, reports: Array, experiences: Dictionary, artifact: Dictionary) -> Dictionary:
	var people: Dictionary = {}
	var stores: Dictionary = {}
	for person: PersonState in snapshot.persons:
		people[person.id] = person
	for store: ResourceStoreState in snapshot.resource_stores:
		stores[store.id] = store
	var groups: Dictionary = {}
	for report: Dictionary in reports:
		if not M5StateValidator.report_valid(report, people, stores):
			return M5StateValidator.issue("reports.payload", "", "M5_OBSERVATION_CONTRACT")
		var key: String = report.owner_person_id + "|" + report.event_id
		if not groups.has(key):
			groups[key] = []
		groups[key].append(report)
	var keys: Array = groups.keys()
	keys.sort()
	var plans: Array[Dictionary] = []
	var new_memories: int = 0
	var new_facts: int = 0
	var fact_keys: Dictionary = {}
	for key: String in keys:
		var group: Array = groups[key]
		var owner: PersonState = people[group[0].owner_person_id]
		var obs_id: String = M5Data.observation_id(owner.id, group[0].event_id)
		var existing: SocialObservationState = _observation(snapshot, obs_id)
		var before: Dictionary = existing.to_data() if existing != null else {}
		var obs: Dictionary = M5ObservationMerger.merge(before, group, snapshot.day_index)
		var plan: Dictionary = {"observation": obs, "before": before, "count": group.size(), "appraisal": {}, "fact": null, "fact_new": false}
		if obs.accepted and not _has_receipt(snapshot, owner.id, obs.event_id):
			var prior_days: Array = []
			for repeat: RepeatExposureState in snapshot.repeat_exposures:
				if repeat.owner_person_id == owner.id:
					prior_days = repeat.low_risk_days.duplicate()
			var context: Dictionary = experiences.get(owner.id, {}) if obs.acquisition_type != "hearsay" else {}
			var appraisal: Dictionary = M5Appraisal.evaluate(owner, obs, context, prior_days, snapshot.day_index, artifact.defaulted_inputs)
			obs.importance = appraisal.importance
			plan.appraisal = appraisal
			new_memories += 1
			if obs.origin_view == "aid_requester" and obs.acquisition_type == "direct_interaction":
				var fact_key: String = owner.id + "|request_success_expectation|" + obs.payload.responder_person_id
				if fact_keys.has(fact_key):
					return M5StateValidator.issue("reports", owner.id, "M5_OBSERVATION_CONTRACT")
				fact_keys[fact_key] = true
				var fact: InformationState = _fact(snapshot, owner.id, obs.payload.responder_person_id)
				plan.fact = fact
				plan.fact_new = fact == null
				plan.fact_key = fact_key
				if fact == null:
					new_facts += 1
		plans.append(plan)
	for pair: Array in [["memory", new_memories], ["information", new_facts]]:
		if pair[1] > M5Data.MAX_INT - int(stage.next_ids[pair[0]]):
			return M5StateValidator.issue("state.next_ids." + pair[0], "", "M5_ARITHMETIC_OVERFLOW")
	# Fact allocation order is independent of event/memory allocation order.
	var fact_plans: Array[Dictionary] = []
	for plan: Dictionary in plans:
		if plan.has("fact_key"):
			fact_plans.append(plan)
	fact_plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.fact_key < b.fact_key)
	for plan: Dictionary in fact_plans:
		_learn(stage, plan)
	var sums: Dictionary = {}
	for plan: Dictionary in plans:
		var obs: Dictionary = plan.observation
		var existing: SocialObservationState = _observation(stage, obs.id)
		if existing != null:
			stage.social_observations.erase(existing)
		stage.social_observations.append(SocialObservationState.from_data(obs))
		var operation: String = "CREATE" if plan.before.is_empty() else "KEEP_CONFLICT" if obs.conflicted else "KEEP_DUPLICATE" if obs == plan.before else "UPDATE"
		artifact.observation_changes.append(M5Data.identified("observation_changes", {"observation_id": obs.id, "operation": operation,
			"before_hash": "" if plan.before.is_empty() else StateHasher.hash_data(plan.before), "after_hash": StateHasher.hash_data(obs),
			"selected_source_person_id": obs.current_source_person_id, "received_report_count": plan.count}))
		if plan.appraisal.is_empty():
			continue
		var app: Dictionary = plan.appraisal
		var memory: MemoryState = _memory(stage, obs, app)
		var receipt: SocialEffectReceipt = SocialEffectReceipt.from_data({"id": M5Data.receipt_id(obs.owner_person_id, obs.event_id),
			"owner_person_id": obs.owner_person_id, "event_id": obs.event_id, "applied_revision": snapshot.social_state.revision + 1,
			"applied_day_index": snapshot.day_index, "applied_observation_id": obs.id,
			"applied_payload_hash": StateHasher.hash_data({"origin_view": obs.origin_view, "payload": obs.payload}), "memory_id": memory.id})
		stage.social_effect_receipts.append(receipt)
		for delta: Dictionary in app.relation_deltas:
			for field: String in M5Data.RELATION_FIELDS:
				_accumulate(sums, obs.owner_person_id, delta.target_person_id, "relation." + field, delta[field])
		for field: String in app.emotion_deltas:
			_accumulate(sums, obs.owner_person_id, obs.owner_person_id, "emotion_scores." + field, app.emotion_deltas[field])
		if not app.pressure_delta.trait_id.is_empty():
			_accumulate(sums, obs.owner_person_id, obs.owner_person_id, "trait_pressure.norm_adherence", app.pressure_delta.applied_pressure, true)
			if app.experience_context.K < 40:
				var repeat: RepeatExposureState = _repeat(stage, obs.owner_person_id)
				if repeat.low_risk_days.has(snapshot.day_index):
					return M5StateValidator.issue("state.repeat_exposures.low_risk_days", repeat.id, "M5_OBSERVATION_CONTRACT")
				var days: Array[int] = []
				for day: int in repeat.low_risk_days:
					if day >= snapshot.day_index - 6:
						days.append(day)
				days.append(snapshot.day_index)
				repeat.low_risk_days = days
		artifact.effect_applications.append(M5Data.identified("effect_applications", {"receipt_id": receipt.id, "observation_id": obs.id,
			"rule_id": app.rule_id, "relation_deltas": app.relation_deltas, "emotion_deltas": app.emotion_deltas,
			"pressure_delta": app.pressure_delta, "belief_change": app.belief_change, "experience_context": app.experience_context}))
	_apply_sums(snapshot, stage, sums, artifact)
	return {}


static func _observation(world: WorldState, id: String) -> SocialObservationState:
	for obs: SocialObservationState in world.social_observations:
		if obs.id == id:
			return obs
	return null


static func _has_receipt(world: WorldState, owner: String, event: String) -> bool:
	for receipt: SocialEffectReceipt in world.social_effect_receipts:
		if receipt.owner_person_id == owner and receipt.event_id == event:
			return true
	return false


static func _fact(world: WorldState, owner: String, target: String) -> InformationState:
	for fact: InformationState in world.information:
		if fact.owner_person_id == owner and fact.fact_type_id == "request_success_expectation" and fact.subject_id == target:
			return fact
	return null


static func _learn(stage: WorldState, plan: Dictionary) -> void:
	var obs: Dictionary = plan.observation
	var previous: InformationState = plan.fact
	var fact: InformationState = _fact(stage, obs.owner_person_id, obs.payload.responder_person_id)
	var old_b: int = previous.belief_value if previous != null else 0
	var old_c: int = previous.confidence if previous != null else 0
	var change: Dictionary = M5Appraisal.learning(old_b, old_c, obs.payload.requested_units, obs.payload.actual_units, previous != null)
	if fact == null:
		fact = InformationState.new()
		fact.id = IdAllocator.next_id(stage, "information")
		fact.owner_person_id = obs.owner_person_id
		fact.fact_type_id = "request_success_expectation"
		fact.subject_kind = "person"
		fact.subject_id = obs.payload.responder_person_id
		stage.information.append(fact)
		stage.find_person(fact.owner_person_id).information_ids.append(fact.id)
	fact.belief_value = change.new_belief
	fact.confidence = change.new_confidence
	fact.linked_event_id = obs.event_id
	fact.source_observation_id = obs.id
	fact.learned_day_index = stage.day_index
	fact.acquisition_type = "direct_interaction"
	fact.original_source_person_id = obs.owner_person_id
	fact.current_source_person_id = obs.owner_person_id
	fact.is_secret = false
	fact.claim = "m5:request_success_expectation"
	plan.appraisal.belief_change = {"information_id": fact.id, "old_belief": old_b, "new_belief": fact.belief_value,
		"old_confidence": old_c, "new_confidence": fact.confidence, "sample": change.sample}


static func _memory(stage: WorldState, obs: Dictionary, app: Dictionary) -> MemoryState:
	var memory: MemoryState = MemoryState.new()
	memory.id = IdAllocator.next_id(stage, "memory")
	memory.owner_person_id = obs.owner_person_id
	memory.linked_event_id = obs.event_id
	memory.source_observation_id = obs.id
	memory.perceived_action_id = "A04" if obs.origin_view.begins_with("aid_") else "A11"
	memory.perceived_result_id = app.memory_result
	memory.related_person_ids = M5Data.named_people(obs.payload)
	memory.related_person_ids.erase(obs.owner_person_id)
	for emotion: String in app.emotion_deltas:
		if app.emotion_deltas[emotion] > 0:
			memory.emotion_scores[emotion] = app.emotion_deltas[emotion]
	memory.importance = app.importance
	memory.occurred_day_index = obs.occurred_day_index
	memory.first_learned_day_index = obs.first_learned_day_index
	stage.memories.append(memory)
	stage.find_person(memory.owner_person_id).memory_ids.append(memory.id)
	return memory


static func _repeat(world: WorldState, owner: String) -> RepeatExposureState:
	for item: RepeatExposureState in world.repeat_exposures:
		if item.owner_person_id == owner:
			return item
	var item: RepeatExposureState = RepeatExposureState.from_data({"id": "repeat_exposure:%s:A11:norm_adherence" % owner,
		"owner_person_id": owner, "action_family": "A11", "trait_id": "norm_adherence", "low_risk_days": []})
	world.repeat_exposures.append(item)
	return item


static func _accumulate(sums: Dictionary, owner: String, target: String, path: String, delta: int, include_zero: bool = false) -> void:
	if delta == 0 and not include_zero:
		return
	var key: String = owner + "|" + target + "|" + path
	if not sums.has(key):
		sums[key] = {"owner_person_id": owner, "target_id": target, "field_path": path, "requested_delta": 0}
	sums[key].requested_delta += delta


static func _apply_sums(snapshot: WorldState, stage: WorldState, sums: Dictionary, artifact: Dictionary) -> void:
	var keys: Array = sums.keys()
	keys.sort()
	for key: String in keys:
		var change: Dictionary = sums[key]
		var owner: String = change.owner_person_id
		var target: String = change.target_id
		var field: String = change.field_path.get_slice(".", 1)
		var before: int = 0
		var low: int = 0
		if change.field_path.begins_with("relation."):
			before = M5Data.relation_values(snapshot, owner, target, artifact.defaulted_inputs)[field]
		elif change.field_path.begins_with("emotion_scores."):
			before = M5Data.score(snapshot.find_person(owner), "emotion_scores", field, artifact.defaulted_inputs)
		else:
			low = -100
			for pressure: TraitPressureState in snapshot.trait_pressures:
				if pressure.owner_person_id == owner:
					before = pressure.pressure
		var after: int = clampi(before + int(change.requested_delta), low, 100)
		if change.field_path.begins_with("relation."):
			var relation: RelationState = M5Data.relation(stage, owner, target)
			if relation == null and after != 0:
				relation = RelationState.new()
				relation.id = "relation:%s->%s" % [owner, target]
				relation.from_person_id = owner
				relation.to_person_id = target
				stage.relations.append(relation)
				stage.find_person(owner).relation_ids.append(relation.id)
			if relation != null:
				relation.set(field, after)
		elif change.field_path.begins_with("emotion_scores."):
			stage.find_person(owner).emotion_scores[field] = after
		else:
			var pressure: TraitPressureState = null
			for item: TraitPressureState in stage.trait_pressures:
				if item.owner_person_id == owner:
					pressure = item
			if pressure == null:
				pressure = TraitPressureState.from_data({"id": "trait_pressure:%s:norm_adherence" % owner, "owner_person_id": owner, "trait_id": field, "pressure": 0})
				stage.trait_pressures.append(pressure)
			pressure.pressure = after
		change.before_value = before
		change.after_value = after
		change.applied_delta = after - before
		artifact.field_changes.append(M5Data.identified("field_changes", change))
