class_name M5StateValidator
extends RefCounted

const COLLECTIONS: Dictionary = {
	"persons": "person", "households": "household", "resource_stores": "resource_store",
	"relations": "relation", "events": "event", "information": "information", "memories": "memory",
	"social_observations": "social_observation", "social_effect_receipts": "effect_receipt",
	"traces": "trace", "trait_pressures": "trait_pressure", "repeat_exposures": "repeat_exposure",
}
const INTS: Array[String] = [
	"schema_version", "day_index", "resolution_epoch", "next_resource_sequence_index", "health", "daily_food_need_units",
	"severe_hunger_days", "wealth_units", "dependency_load", "quantity", "security_level", "trust", "affection", "fear",
	"resentment", "obligation", "confidence", "learned_day_index", "belief_value", "importance", "occurred_day_index",
	"first_learned_day_index", "first_accepted_day_index", "depth", "applied_day_index", "applied_revision", "pressure",
	"last_closed_day_index", "last_contact_day_index", "last_settled_week_index", "last_integrated_resolution_epoch", "revision",
	"input_resolution_epoch", "output_resolution_epoch", "actual_units", "requested_units", "attempted_units", "social_revision",
]
const BOOLS: Array[String] = ["alive", "is_public", "is_secret", "core_eligible", "accepted", "conflicted", "exists", "took_goods", "trace_created"]
const DICTS: Array[String] = ["next_ids", "social_state", "trait_scores", "value_scores", "emotion_scores", "need_scores", "aptitude_scores", "skill_scores", "m5_origin", "objective_payload", "payload", "ruleset_manifest", "state"]
const ARRAYS: Array[String] = ["role_ids", "goal_ids", "information_ids", "memory_ids", "relation_ids", "member_ids", "dependent_person_ids", "actor_ids", "target_ids", "witness_ids", "related_person_ids", "resolved_decision_slot_ids", "low_risk_days"]


static func issue(path: String, entity: String = "", code: String = "M5_WORLD_NOT_PUBLISHABLE") -> Dictionary:
	return {"code": code, "field_path": path, "entity_id": entity, "cause_code": ""}


static func _shape(data: Variant, name: String, path: String, out: Array[Dictionary]) -> void:
	var entity: String = str(data.get("id", "")) if typeof(data) == TYPE_DICTIONARY else ""
	if not M5Data.exact(data, M5Data.keys(name)):
		out.append(issue(path, entity, "M5_FIELD_CONTRACT"))
		return
	for key: String in data:
		var value: Variant = data[key]
		var expected: int = TYPE_STRING
		if key in INTS:
			expected = TYPE_INT
		elif key in BOOLS:
			expected = TYPE_BOOL
		elif key in DICTS:
			expected = TYPE_DICTIONARY
		elif key in ARRAYS or COLLECTIONS.has(key):
			expected = TYPE_ARRAY
		if typeof(value) != expected:
			out.append(issue(path + "." + key, entity, "M5_FIELD_CONTRACT"))
		elif expected == TYPE_ARRAY and key in ARRAYS:
			var item_type: int = TYPE_INT if key == "low_risk_days" else TYPE_STRING
			for item: Variant in value:
				if typeof(item) != item_type:
					out.append(issue(path + "." + key, entity, "M5_FIELD_CONTRACT"))
		elif expected == TYPE_INT:
			var minimum: int = -100 if key == "pressure" else -1 if key.begins_with("last_") or key == "first_accepted_day_index" else 0
			if value < minimum or value > M5Data.MAX_INT:
				out.append(issue(path + "." + key, entity, "M5_FIELD_CONTRACT"))


static func _structure_issues(payload: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_shape(payload, "payload", "world", out)
	if not out.is_empty():
		return out
	if payload.schema_version != 5 or not M5Data.json_value(payload):
		return [issue("world", "", "M5_FIELD_CONTRACT")]
	var state: Dictionary = payload.state
	_shape(state, "state", "state", out)
	if not out.is_empty():
		return out
	_shape(state.social_state, "social_state", "state.social_state", out)
	if not M5Data.exact(state.next_ids, M5Data.keys("next_ids")):
		out.append(issue("state.next_ids", "", "M5_FIELD_CONTRACT"))
	else:
		for key: String in state.next_ids:
			if typeof(state.next_ids[key]) != TYPE_INT or state.next_ids[key] < 1 or state.next_ids[key] > M5Data.MAX_INT:
				out.append(issue("state.next_ids." + key, "", "M5_FIELD_CONTRACT"))
	for collection: String in COLLECTIONS:
		for item: Variant in state[collection]:
			_shape(item, COLLECTIONS[collection], "state." + collection, out)
	if not out.is_empty():
		return out
	if payload.ruleset_manifest != M5Rules.current_manifest_data() or payload.simulation_ruleset_hash != M5Rules.SIMULATION_HASH:
		return [issue("world.ruleset_manifest", "", "M5_RULESET_MISMATCH")]
	if StateHasher.hash_data(M5Rules.data()) != M5Rules.EXPECTED_HASH or not M4Rules.validate_implementation_hashes().is_empty():
		return [issue("world.ruleset_manifest", "", "M5_RULESET_MISMATCH")]
	var legacy_errors: Array[String] = []
	StateValidator._validate_state(state, 5, legacy_errors)
	var indexes: Dictionary = {}
	for collection: String in COLLECTIONS:
		var index: Dictionary = {}
		for item: Dictionary in state[collection]:
			if index.has(item.id) or item.id.is_empty():
				out.append(issue("state." + collection, item.id))
			index[item.id] = item
		indexes[collection] = index
	_validate_links(state, indexes, out)
	_validate_social(state, indexes, out)
	if out.is_empty() and not legacy_errors.is_empty():
		out.append(issue("state"))
	return out


static func issues(payload: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = _structure_issues(payload)
	if not out.is_empty():
		return out
	var s: Dictionary = payload.state
	var social: Dictionary = s.social_state
	var d: int = s.day_index
	if s.resolution_epoch != social.last_integrated_resolution_epoch:
		out.append(issue("state.social_state.last_integrated_resolution_epoch"))
	if social.last_closed_day_index != d - 1:
		out.append(issue("state.social_state.last_closed_day_index"))
	if social.last_settled_week_index != M5Data.td(d, 7) - 1:
		out.append(issue("state.social_state.last_settled_week_index"))
	if social.last_contact_day_index not in [d - 1, d]:
		out.append(issue("state.social_state.last_contact_day_index"))
	if social.revision < s.resolution_epoch:
		out.append(issue("state.social_state.revision"))
	_validate_memory_tiers(s, out)
	return out


static func validate_payload(envelope: Dictionary) -> Array[String]:
	var payload: Dictionary = envelope.duplicate(true)
	if envelope.has("audit") or envelope.has("state_hash") or envelope.has("social_audit") or envelope.has("resource_audit"):
		if not M5Data.exact(envelope, M5Data.keys("save")):
			return ["schema 5 save violates exact keyset"]
		for key: String in ["audit", "resource_audit", "social_audit", "state_hash"]:
			payload.erase(key)
	var errors: Array[String] = []
	for item: Dictionary in issues(payload):
		errors.append("%s:%s:%s" % [item.code, item.field_path, item.entity_id])
	return errors


static func _validate_links(s: Dictionary, ix: Dictionary, out: Array[Dictionary]) -> void:
	var counter_collections: Dictionary = {"person": "persons", "household": "households", "event": "events", "information": "information", "memory": "memories"}
	for key: String in counter_collections:
		for record: Dictionary in s[counter_collections[key]]:
			var suffix: String = record.id.trim_prefix(key + ":")
			if not record.id.begins_with(key + ":") or not suffix.is_valid_int() or suffix.to_int() < 1 or suffix.to_int() >= s.next_ids[key]:
				out.append(issue("state.next_ids." + key, record.id))
	for person: Dictionary in s.persons:
		for pair: Array in [["information_ids", "information", "owner_person_id"], ["memory_ids", "memories", "owner_person_id"], ["relation_ids", "relations", "from_person_id"]]:
			var actual: Array = person[pair[0]].duplicate()
			var expected: Array = []
			for record: Dictionary in s[pair[1]]:
				if record[pair[2]] == person.id:
					expected.append(record.id)
			actual.sort()
			expected.sort()
			if actual != expected:
				out.append(issue("state.persons." + pair[0], person.id))
	var relation_pairs: Dictionary = {}
	for r: Dictionary in s.relations:
		var key: String = r.from_person_id + "->" + r.to_person_id
		if relation_pairs.has(key) or r.from_person_id == r.to_person_id:
			out.append(issue("state.relations", r.id))
		relation_pairs[key] = true
	for fact: Dictionary in s.information:
		if fact.learned_day_index > s.day_index:
			out.append(issue("state.information.learned_day_index", fact.id))
		if not fact.source_observation_id.is_empty():
			var obs: Dictionary = ix.social_observations.get(fact.source_observation_id, {})
			if obs.is_empty() or obs.owner_person_id != fact.owner_person_id or obs.event_id != fact.linked_event_id or not obs.accepted:
				out.append(issue("state.information.source_observation_id", fact.id))
	for memory: Dictionary in s.memories:
		var event: Dictionary = ix.events.get(memory.linked_event_id, {})
		if event.is_empty() or event.day_index != memory.occurred_day_index:
			out.append(issue("state.memories.linked_event_id", memory.id))
		if memory.first_learned_day_index < memory.occurred_day_index or memory.first_learned_day_index > s.day_index:
			out.append(issue("state.memories.first_learned_day_index", memory.id))
		if memory.source_observation_id.is_empty() == memory.linked_information_id.is_empty():
			out.append(issue("state.memories.source_observation_id", memory.id))
		elif memory.source_observation_id.is_empty():
			var fact: Dictionary = ix.information.get(memory.linked_information_id, {})
			if fact.is_empty() or fact.owner_person_id != memory.owner_person_id:
				out.append(issue("state.memories.linked_information_id", memory.id))
		else:
			var obs: Dictionary = ix.social_observations.get(memory.source_observation_id, {})
			if obs.is_empty() or obs.owner_person_id != memory.owner_person_id or obs.event_id != memory.linked_event_id or obs.first_learned_day_index != memory.first_learned_day_index or not obs.accepted:
				out.append(issue("state.memories.source_observation_id", memory.id))
			var receipt: Dictionary = ix.social_effect_receipts.get(M5Data.receipt_id(memory.owner_person_id, memory.linked_event_id), {})
			if receipt.get("memory_id", "") != memory.id:
				out.append(issue("state.memories.source_observation_id", memory.id))


static func report_valid(report: Dictionary, persons: Dictionary, stores: Dictionary) -> bool:
	var shape_errors: Array[Dictionary] = []
	_shape(report, "report_storage_preimage", "report", shape_errors)
	if not shape_errors.is_empty():
		return false
	for key: String in ["owner_person_id", "original_source_person_id", "current_source_person_id"]:
		if not persons.has(report[key]):
			return false
	var p: Dictionary = report.payload
	var view: String = report.origin_view
	var acquisition: String = report.acquisition_type
	if acquisition not in ["self_experience", "direct_interaction", "direct_witness", "hearsay"] or view not in ["aid_requester", "aid_responder", "theft_self", "theft_witness"]:
		return false
	var payload_kind: String = "aid_payload" if view.begins_with("aid_") else view + "_payload"
	_shape(p, payload_kind, "report.payload", shape_errors)
	if not shape_errors.is_empty() or not M5Data.json_value(p):
		return false
	for id: String in M5Data.named_people(p):
		if not persons.has(id):
			return false
	if view.begins_with("aid_"):
		if p.requested_units < 1 or p.requested_units > 10 or p.actual_units > p.requested_units or p.response_decision not in ["GRANT_FULL", "GRANT_PARTIAL", "REJECT"] or (p.response_decision == "REJECT" and p.actual_units != 0):
			return false
	else:
		if not stores.has(p.store_id) or (view == "theft_self" and p.actual_units > 10):
			return false
	if acquisition == "hearsay":
		return view != "theft_self" and report.depth >= 1 and report.depth <= 3 and report.confidence <= 99
	if report.depth != 0 or report.confidence != 100 or report.original_source_person_id != report.owner_person_id or report.current_source_person_id != report.owner_person_id:
		return false
	if view == "theft_self":
		return acquisition == "self_experience" and report.owner_person_id == p.actor_person_id and report.is_secret
	if view == "theft_witness":
		return acquisition == "direct_witness" and report.owner_person_id != p.actor_person_id
	return acquisition == "direct_interaction" and report.owner_person_id == p["requester_person_id" if view == "aid_requester" else "responder_person_id"]


static func _validate_social(s: Dictionary, ix: Dictionary, out: Array[Dictionary]) -> void:
	for obs: Dictionary in s.social_observations:
		var report: Dictionary = {}
		for key: String in M5Data.keys("report_storage_preimage"):
			report[key] = obs[key]
		if not report_valid(report, ix.persons, ix.resource_stores) or not ix.events.has(obs.event_id) or obs.id != M5Data.observation_id(obs.owner_person_id, obs.event_id):
			out.append(issue("state.social_observations", obs.id))
		if obs.occurred_day_index > obs.first_learned_day_index or obs.first_learned_day_index > s.day_index or obs.importance > 100:
			out.append(issue("state.social_observations.first_learned_day_index", obs.id))
		var receipt: Dictionary = ix.social_effect_receipts.get(M5Data.receipt_id(obs.owner_person_id, obs.event_id), {})
		if obs.accepted:
			if receipt.is_empty() or obs.first_accepted_day_index < obs.first_learned_day_index or obs.first_accepted_day_index > s.day_index:
				out.append(issue("state.social_observations.accepted", obs.id))
		elif not receipt.is_empty() or obs.first_accepted_day_index != -1 or obs.importance != 0:
			out.append(issue("state.social_observations.accepted", obs.id))
	for receipt: Dictionary in s.social_effect_receipts:
		var obs: Dictionary = ix.social_observations.get(receipt.applied_observation_id, {})
		if obs.is_empty() or not obs.accepted or obs.owner_person_id != receipt.owner_person_id or obs.event_id != receipt.event_id or receipt.id != M5Data.receipt_id(receipt.owner_person_id, receipt.event_id):
			out.append(issue("state.social_effect_receipts.applied_observation_id", receipt.id))
		if receipt.applied_revision > s.social_state.revision or receipt.applied_revision < 1 or receipt.applied_day_index > s.day_index or not _hash(receipt.applied_payload_hash):
			out.append(issue("state.social_effect_receipts.applied_revision", receipt.id))
		if not obs.is_empty() and receipt.applied_day_index != obs.first_accepted_day_index:
			out.append(issue("state.social_effect_receipts.applied_day_index", receipt.id))
		if not receipt.memory_id.is_empty():
			var memory: Dictionary = ix.memories.get(receipt.memory_id, {})
			if memory.is_empty() or memory.owner_person_id != receipt.owner_person_id or memory.linked_event_id != receipt.event_id or memory.source_observation_id != receipt.applied_observation_id:
				out.append(issue("state.social_effect_receipts.memory_id", receipt.id))
	for pressure: Dictionary in s.trait_pressures:
		if not ix.persons.has(pressure.owner_person_id) or pressure.trait_id != "norm_adherence" or pressure.id != "trait_pressure:%s:norm_adherence" % pressure.owner_person_id or absi(pressure.pressure) > 100:
			out.append(issue("state.trait_pressures", pressure.id))
	for repeat: Dictionary in s.repeat_exposures:
		if not ix.persons.has(repeat.owner_person_id) or repeat.action_family != "A11" or repeat.trait_id != "norm_adherence" or repeat.id != "repeat_exposure:%s:A11:norm_adherence" % repeat.owner_person_id or repeat.low_risk_days.size() > 7:
			out.append(issue("state.repeat_exposures", repeat.id))
		var previous: int = -1
		for day: int in repeat.low_risk_days:
			if day <= previous or day > s.day_index or day < maxi(0, s.social_state.last_closed_day_index + 1 - 6):
				out.append(issue("state.repeat_exposures.low_risk_days", repeat.id))
			previous = day
	var source_actions: Dictionary = {}
	for event: Dictionary in s.events:
		if event.day_index > s.day_index or event.m5_origin.is_empty() != event.objective_payload.is_empty():
			out.append(issue("state.events", event.id))
		if event.m5_origin.is_empty():
			continue
		var origin: Dictionary = event.m5_origin
		var shape_errors: Array[Dictionary] = []
		_shape(origin, "event_origin", "state.events.m5_origin", shape_errors)
		if not shape_errors.is_empty():
			out.append_array(shape_errors)
			continue
		if origin.output_resolution_epoch != origin.input_resolution_epoch + 1 or origin.output_resolution_epoch > s.resolution_epoch or event.is_public or event.action_id not in ["A04", "A11"] or event.result_id not in ["FULL", "PARTIAL", "NONE"]:
			out.append(issue("state.events.m5_origin", event.id))
		for key: String in ["source_action_instance_id", "source_outcome_hash", "source_context_id"]:
			if not _hash(origin[key]):
				out.append(issue("state.events.m5_origin." + key, event.id))
		if source_actions.has(origin.source_action_instance_id):
			out.append(issue("state.events.m5_origin.source_action_instance_id", event.id))
		source_actions[origin.source_action_instance_id] = true
		if not _objective_valid(event, ix):
			out.append(issue("state.events.objective_payload", event.id))
	for trace: Dictionary in s.traces:
		var event: Dictionary = ix.events.get(trace.event_id, {})
		if event.is_empty() or not ix.resource_stores.has(trace.store_id) or trace.trace_type != "theft_disturbance" or not trace.exists or trace.id != "trace:" + trace.source_action_instance_id:
			out.append(issue("state.traces", trace.id))
		elif event.action_id != "A11" or event.day_index != trace.occurred_day_index or event.m5_origin.get("source_action_instance_id") != trace.source_action_instance_id or not event.objective_payload.get("trace_created", false) or event.location_id != trace.store_id:
			out.append(issue("state.traces.event_id", trace.id))
	for event: Dictionary in s.events:
		if event.action_id == "A11" and event.objective_payload.get("trace_created", false) == true:
			if not ix.traces.has("trace:" + str(event.m5_origin.get("source_action_instance_id", ""))):
				out.append(issue("state.events.objective_payload.trace_created", event.id))


static func _objective_valid(event: Dictionary, ix: Dictionary) -> bool:
	var p: Dictionary = event.objective_payload
	var expected: Array = M5Data.keys("aid_payload") + ["source_store_id", "recipient_store_id"] if event.action_id == "A04" else ["actor_person_id", "store_id", "actual_units", "attempted_units", "trace_created"]
	if not M5Data.exact(p, expected):
		return false
	for key: String in p:
		var value_type: int = TYPE_INT if key in ["requested_units", "actual_units", "attempted_units"] else TYPE_BOOL if key == "trace_created" else TYPE_STRING
		if typeof(p[key]) != value_type:
			return false
		if value_type == TYPE_INT and (p[key] < 0 or p[key] > 10):
			return false
	if event.action_id == "A04":
		return event.event_type == "aid_exchange" and event.actor_ids == [p.requester_person_id] and event.target_ids == [p.responder_person_id] and event.witness_ids.is_empty() and p.requester_person_id != p.responder_person_id and ix.resource_stores.has(p.source_store_id) and ix.resource_stores.has(p.recipient_store_id) and p.source_store_id != p.recipient_store_id and event.location_id == p.source_store_id and p.requested_units >= 1 and p.actual_units <= p.requested_units and p.response_decision in ["GRANT_FULL", "GRANT_PARTIAL", "REJECT"] and (p.response_decision != "REJECT" or p.actual_units == 0)
	return event.action_id == "A11" and event.event_type == "theft_attempt" and event.actor_ids == [p.actor_person_id] and event.target_ids.is_empty() and not event.witness_ids.has(p.actor_person_id) and ix.resource_stores.has(p.store_id) and event.location_id == p.store_id and p.actual_units <= p.attempted_units


static func _hash(value: String) -> bool:
	return RegEx.create_from_string("^[0-9a-f]{64}$").search(value) != null


static func _validate_memory_tiers(s: Dictionary, out: Array[Dictionary]) -> void:
	var counts: Dictionary = {}
	for memory: Dictionary in s.memories:
		var key: String = memory.owner_person_id + ":" + memory.tier
		counts[key] = int(counts.get(key, 0)) + 1
		var cap: int = {"core": 8, "important": 24, "recent": 64}.get(memory.tier, 0)
		var age: int = maxi(0, s.social_state.last_closed_day_index - memory.first_learned_day_index)
		if counts[key] > cap or (memory.tier == "core" and not memory.core_eligible) or (memory.tier == "important" and memory.importance < 70) or (memory.tier == "recent" and age > 13):
			out.append(issue("state.memories.tier", memory.id))


static func typed_safe(world: WorldState) -> bool:
	if world.social_state == null:
		return false
	for key: String in COLLECTIONS:
		for item: Variant in world.get(key):
			if item == null:
				return false
	return true
