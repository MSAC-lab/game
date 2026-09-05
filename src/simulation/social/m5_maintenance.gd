class_name M5Maintenance
extends RefCounted


static func weekly(score: int, pressure: int) -> Dictionary:
	var rules: Dictionary = M5Rules.data().pressure
	var requested: int = clampi(M5Data.td(pressure, rules.weekly_threshold), -rules.weekly_delta_limit, rules.weekly_delta_limit)
	var next: int = clampi(score + requested, 0, 100)
	return {"requested_delta": requested, "actual_delta": next - score, "new_score": next,
		"remaining_pressure": pressure - rules.weekly_threshold * (next - score)}


static func close(world: WorldState, completed_day: int, artifact: Dictionary) -> bool:
	var rules: Dictionary = M5Rules.data().maintenance
	for person: PersonState in world.persons:
		for emotion: String in ["fear", "anger", "guilt"]:
			if person.emotion_scores.has(emotion):
				var old: int = person.emotion_scores[emotion]
				var next: int = maxi(0, old - int(rules[emotion + "_daily_decay"]))
				person.emotion_scores[emotion] = next
				_record(artifact, person.id, "EMOTION_DECAY", emotion, old, next)
	if (completed_day + 1) % 7 == 0:
		var week: int = M5Data.td(completed_day, 7)
		if world.social_state.last_settled_week_index + 1 != week:
			return false
		for pressure: TraitPressureState in world.trait_pressures:
			var person: PersonState = world.find_person(pressure.owner_person_id)
			var old: int = M5Data.score(person, "trait_scores", "norm_adherence", artifact.defaulted_inputs)
			var change: Dictionary = weekly(old, pressure.pressure)
			if person.trait_scores.has("norm_adherence") or change.new_score != 0:
				person.trait_scores["norm_adherence"] = change.new_score
			_record(artifact, person.id, "WEEKLY_TRAIT", "norm_adherence", old, change.new_score)
			_record(artifact, person.id, "PRESSURE_REMAINDER", pressure.id, pressure.pressure, change.remaining_pressure)
			pressure.pressure = change.remaining_pressure
		world.social_state.last_settled_week_index = week
	memories(world, completed_day, artifact)
	for repeat: RepeatExposureState in world.repeat_exposures:
		var old: Array[int] = repeat.low_risk_days.duplicate()
		var next: Array[int] = []
		for day: int in old:
			if day >= completed_day + 1 - 6:
				next.append(day)
		repeat.low_risk_days = next
		_record(artifact, repeat.owner_person_id, "REPEAT_PRUNE", repeat.id, old, next)
	return true


static func memories(world: WorldState, closed_day: int, artifact: Dictionary) -> void:
	var retained: Array[MemoryState] = []
	var rules: Dictionary = M5Rules.data().maintenance
	for person: PersonState in world.persons:
		var candidates: Array[MemoryState] = []
		for memory: MemoryState in world.memories:
			if memory.owner_person_id == person.id:
				candidates.append(memory)
		candidates.sort_custom(_priority_less)
		var selected: Dictionary = {}
		for tier: String in ["core", "important", "recent"]:
			var used: int = 0
			var cap: int = rules[tier + "_cap"]
			for memory: MemoryState in candidates:
				if selected.has(memory.id) or used >= cap:
					continue
				var eligible: bool = memory.core_eligible if tier == "core" else memory.importance >= rules.important_threshold if tier == "important" else maxi(0, closed_day - memory.first_learned_day_index) <= rules.recent_max_age
				if eligible:
					_record(artifact, person.id, "MEMORY_TIER", memory.id, memory.tier, tier)
					memory.tier = tier
					selected[memory.id] = true
					retained.append(memory)
					used += 1
		for memory: MemoryState in candidates:
			if selected.has(memory.id):
				continue
			person.memory_ids.erase(memory.id)
			for receipt: SocialEffectReceipt in world.social_effect_receipts:
				if receipt.memory_id == memory.id:
					receipt.memory_id = ""
			_record(artifact, person.id, "MEMORY_COMPRESS", memory.id, memory.id, "")
	world.memories = retained


static func _priority_less(a: MemoryState, b: MemoryState) -> bool:
	if a.importance != b.importance:
		return a.importance > b.importance
	if a.first_learned_day_index != b.first_learned_day_index:
		return a.first_learned_day_index > b.first_learned_day_index
	return a.id < b.id


static func _record(artifact: Dictionary, owner: String, kind: String, target: String, before: Variant, after: Variant) -> void:
	if before != after:
		artifact.maintenance_changes.append(M5Data.identified("maintenance_changes", {"owner_person_id": owner, "kind": kind,
			"target_id": target, "before_value": before, "after_value": after}))
