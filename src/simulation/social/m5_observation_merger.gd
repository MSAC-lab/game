class_name M5ObservationMerger
extends RefCounted
## Pure report reduction. No objective event lookup and no mutation of input reports.


static func report_of(observation: Dictionary) -> Dictionary:
	var report: Dictionary = {}
	for key: String in M5Data.keys("report_storage_preimage"):
		report[key] = observation[key]
	return report.duplicate(true)


static func rank(report: Dictionary) -> Array[int]:
	return [1 if report.acquisition_type == "hearsay" else 2, report.occurred_day_index, report.confidence]


static func compare_rank(a: Dictionary, b: Dictionary) -> int:
	var ar: Array[int] = rank(a)
	var br: Array[int] = rank(b)
	for i: int in ar.size():
		if ar[i] != br[i]:
			return 1 if ar[i] > br[i] else -1
	return 0


static func meaning(report: Dictionary) -> Dictionary:
	var payload: Dictionary = report.payload
	if report.origin_view.begins_with("aid_"):
		return payload.duplicate(true)
	return {"actor_person_id": payload.actor_person_id, "store_id": payload.store_id,
		"took_goods": payload.actual_units > 0 if report.origin_view == "theft_self" else payload.took_goods}


static func _storage_less(a: Dictionary, b: Dictionary) -> bool:
	if a.depth != b.depth:
		return a.depth < b.depth
	for key: String in ["original_source_person_id", "current_source_person_id"]:
		if a[key] != b[key]:
			return a[key] < b[key]
	var ah: String = StateHasher.hash_data(a)
	var bh: String = StateHasher.hash_data(b)
	return ah < bh if ah != bh else StateCanonicalizer.canonical_json(a) < StateCanonicalizer.canonical_json(b)


static func _compatible_less(a: Dictionary, b: Dictionary) -> bool:
	var ac: int = 2 if a.origin_view == "theft_self" else 1
	var bc: int = 2 if b.origin_view == "theft_self" else 1
	if ac != bc:
		return ac > bc
	if a.depth != b.depth:
		return a.depth < b.depth
	for key: String in ["original_source_person_id", "current_source_person_id"]:
		if a[key] != b[key]:
			return a[key] < b[key]
	var ah: String = StateHasher.hash_data(a.payload)
	var bh: String = StateHasher.hash_data(b.payload)
	return ah < bh if ah != bh else _storage_less(a, b)


static func merge(existing: Dictionary, incoming: Array, day: int) -> Dictionary:
	var reports: Array = incoming.duplicate(true)
	if not existing.is_empty():
		reports.append(report_of(existing))
	if reports.is_empty():
		return {}
	var best: Dictionary = reports[0]
	for report: Dictionary in reports:
		if compare_rank(report, best) > 0:
			best = report
	var top: Array[Dictionary] = []
	for report: Dictionary in reports:
		if compare_rank(report, best) == 0:
			top.append(report)
	var conflict: bool = false
	for report: Dictionary in top:
		if meaning(report) != meaning(best):
			conflict = true
	var barrier: bool = not existing.is_empty() and existing.conflicted and compare_rank(best, existing) <= 0
	if not existing.is_empty() and existing.accepted and (conflict or barrier or compare_rank(best, existing) < 0):
		var kept: Dictionary = existing.duplicate(true)
		kept.conflicted = existing.conflicted or conflict
		return kept
	top.sort_custom(_storage_less if conflict or barrier else _compatible_less)
	var selected: Dictionary = top[0].duplicate(true)
	var was_accepted: bool = not existing.is_empty() and existing.accepted
	selected["id"] = M5Data.observation_id(selected.owner_person_id, selected.event_id)
	selected["first_learned_day_index"] = day if existing.is_empty() else existing.first_learned_day_index
	selected["conflicted"] = conflict or barrier
	selected["accepted"] = was_accepted or (not selected.conflicted and (selected.acquisition_type != "hearsay" or selected.confidence >= 60))
	selected["first_accepted_day_index"] = existing.first_accepted_day_index if was_accepted else day if selected.accepted else -1
	selected["importance"] = existing.importance if was_accepted else 0
	return selected
