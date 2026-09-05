class_name M5Contacts
extends RefCounted


static func validate(world: WorldState, plan: SocialContactPlan) -> bool:
	if plan == null:
		return false
	var partners: Dictionary = {}
	var seen: Dictionary = {}
	for pair: SocialContactPair in plan.pairs:
		if pair == null or pair.person_a_id >= pair.person_b_id or pair.id != "contact:%s->%s" % [pair.person_a_id, pair.person_b_id] or seen.has(pair.id):
			return false
		seen[pair.id] = true
		for id: String in [pair.person_a_id, pair.person_b_id]:
			var person: PersonState = world.find_person(id)
			if person == null or not person.alive:
				return false
			partners[id] = int(partners.get(id, 0)) + 1
			if partners[id] > 3:
				return false
	return true


static func reports(snapshot: WorldState, plan: SocialContactPlan, defaults: Array) -> Array:
	var result: Array = []
	for pair: SocialContactPair in plan.pairs:
		result.append_array(_direction(snapshot, pair.person_a_id, pair.person_b_id, defaults))
		result.append_array(_direction(snapshot, pair.person_b_id, pair.person_a_id, defaults))
	return result


static func _direction(world: WorldState, sender_id: String, receiver_id: String, defaults: Array) -> Array:
	var candidates: Array[Dictionary] = []
	var sender: PersonState = world.find_person(sender_id)
	var rules: Dictionary = M5Rules.data().contact
	for obs: SocialObservationState in world.social_observations:
		if obs.owner_person_id != sender_id or not obs.accepted or obs.is_secret or obs.depth >= rules.max_depth:
			continue
		var eligible: bool = world.day_index - obs.first_learned_day_index <= rules.max_recent_send_age
		if not eligible:
			for memory: MemoryState in world.memories:
				if memory.source_observation_id == obs.id and memory.tier in ["important", "core"]:
					eligible = true
		if not eligible:
			continue
		var relation: Dictionary = M5Data.relation_values(world, sender_id, receiver_id, defaults)
		var bond: int = M5Data.td(relation.trust + relation.affection + relation.obligation, rules.share_relation_divisor)
		var threat: int = M5Data.td(relation.fear + relation.resentment, rules.share_threat_divisor)
		var relevance: int = rules.named_recipient_relevance if M5Data.named_people(obs.payload).has(receiver_id) else 0
		var score: int = obs.importance + bond + relevance - threat - M5Data.td(M5Data.score(sender, "emotion_scores", "fear", defaults), rules.share_self_fear_divisor)
		if score >= rules.share_min_score:
			candidates.append({"score": score, "observation": obs})
	candidates.sort_custom(_candidate_less)
	var result: Array = []
	for i: int in mini(candidates.size(), int(rules.max_claims_per_direction)):
		var obs: SocialObservationState = candidates[i].observation
		var trust: int = M5Data.relation_values(world, receiver_id, sender_id, defaults).trust
		var report: Dictionary = M5ObservationMerger.report_of(obs.to_data())
		report.owner_person_id = receiver_id
		report.acquisition_type = "hearsay"
		report.current_source_person_id = sender_id
		report.depth += 1
		report.confidence = receiver_confidence(obs.confidence, trust)
		result.append(report)
	return result


static func _candidate_less(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	var ao: SocialObservationState = a.observation
	var bo: SocialObservationState = b.observation
	if ao.importance != bo.importance:
		return ao.importance > bo.importance
	if ao.first_learned_day_index != bo.first_learned_day_index:
		return ao.first_learned_day_index > bo.first_learned_day_index
	return ao.id < bo.id


static func receiver_confidence(sender_confidence: int, trust: int) -> int:
	var rules: Dictionary = M5Rules.data().contact
	return maxi(0, sender_confidence - int(rules.confidence_loss_base) - M5Data.td(100 - trust, rules.confidence_loss_trust_divisor))
