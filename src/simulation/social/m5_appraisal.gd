class_name M5Appraisal
extends RefCounted
## Only a person's own state, permitted observation and verified experience enter here.


static func pressure(context: Dictionary, previous_days: Array, day: int) -> Dictionary:
	var result: Dictionary = {"trait_id": "", "raw_magnitude": 0, "sign": 0, "repeat_prior_count": 0, "applied_pressure": 0}
	var rules: Dictionary = M5Rules.data().pressure
	if context.is_empty() or context.C < rules.min_conflict:
		return result
	var magnitude: int = rules.base_magnitude + int(context.K >= rules.risk_add_threshold) + int(context.C >= rules.conflict_add_threshold)
	if context.K >= rules.major_risk_threshold and context.C >= rules.major_conflict_threshold and context.N >= rules.major_need_threshold:
		magnitude = rules.major_magnitude
	var sign_value: int = -1 if context.N >= rules.justification_need_threshold and context.family_protection >= context.norm_adherence + rules.justification_family_margin else 1
	var prior: int = 0
	var applied: int = magnitude
	if context.K < rules.repeat_low_risk_below:
		for previous: int in previous_days:
			if previous >= day - 6 and previous <= day:
				prior += 1
		applied = M5Data.td(magnitude, int(rules.repeat_divisors[prior])) if prior < 3 else 0
	return {"trait_id": "norm_adherence", "raw_magnitude": magnitude, "sign": sign_value, "repeat_prior_count": prior, "applied_pressure": sign_value * applied}


static func learning(old_belief: int, old_confidence: int, requested: int, actual: int, exists: bool = true) -> Dictionary:
	var rules: Dictionary = M5Rules.data().belief
	var sample: int = M5Data.rd(rules.sample_scale * actual, requested)
	return {"sample": sample, "new_belief": M5Data.rd(rules.old_weight * old_belief + sample, rules.divisor) if exists else sample,
		"new_confidence": mini(100, old_confidence + int(rules.confidence_increment)) if exists else rules.new_confidence}


static func evaluate(owner: PersonState, obs: Dictionary, experience: Dictionary, previous_days: Array, day: int, defaults: Array) -> Dictionary:
	var rules: Dictionary = M5Rules.data().appraisal
	var p: Dictionary = obs.payload
	var view: String = obs.origin_view
	var hearsay: bool = obs.acquisition_type == "hearsay"
	var result: Dictionary = {"rule_id": "", "relation_deltas": [], "emotion_deltas": {"anger": 0, "fear": 0, "guilt": 0},
		"pressure_delta": {"trait_id": "", "raw_magnitude": 0, "sign": 0, "repeat_prior_count": 0, "applied_pressure": 0},
		"belief_change": {}, "experience_context": {}, "importance": 0, "memory_result": ""}
	var relation_delta: Dictionary = {}
	var emotion_delta: Dictionary = {}
	var target: String = ""
	if view.begins_with("aid_"):
		var rule: String
		if hearsay:
			rule = "aid_hearsay"
			result.memory_result = "aid_report"
		elif view == "aid_requester":
			result.experience_context = experience.duplicate(true)
			target = p.responder_person_id
			if p.actual_units > 0:
				rule = "aid_received"
			elif p.response_decision == "REJECT":
				rule = "aid_refused_high" if experience.get("N", 0) >= 60 else "aid_refused_low"
			else:
				rule = "aid_offered_zero"
			result.memory_result = "aid_refused" if rule.begins_with("aid_refused") else rule
		else:
			target = p.requester_person_id
			rule = "aid_given" if p.actual_units > 0 else "aid_responder_zero"
			result.memory_result = "aid_given" if p.actual_units > 0 else "aid_response_zero"
		var table: Dictionary = rules[rule]
		result.rule_id = rule
		relation_delta = table.relation.duplicate(true)
		emotion_delta = table.emotion.duplicate(true)
		result.importance = M5Data.rd(table.importance_base * obs.confidence, 100) if hearsay else table.importance
		if rule == "aid_received":
			var sample: int = M5Data.rd(100 * p.actual_units, p.requested_units)
			for key: String in relation_delta:
				relation_delta[key] = M5Data.rd(relation_delta[key] * sample, 100)
			for key: String in emotion_delta:
				emotion_delta[key] = M5Data.rd(emotion_delta[key] * sample, 100)
	elif view == "theft_self":
		var table: Dictionary = rules.theft_self
		result.rule_id = "theft_self"
		result.experience_context = experience.duplicate(true)
		var conflict: bool = experience.C >= table.conflict_threshold
		emotion_delta = {"guilt": table.guilt_delta if conflict else 0, "fear": M5Data.rd(experience.K, table.fear_divisor)}
		result.importance = table.importance_base + (table.importance_conflict_add if conflict else 0) + (table.importance_risk_add if experience.K >= table.importance_risk_threshold else 0)
		result.pressure_delta = pressure(experience, previous_days, day)
		result.memory_result = "attempt_with_gain" if p.actual_units > 0 else "attempt_without_gain"
	else:
		var table: Dictionary = rules.theft_observer
		var norm: int = M5Data.score(owner, "trait_scores", "norm_adherence", defaults)
		var property_score: int = M5Data.score(owner, "value_scores", "property_autonomy", defaults)
		var q: int = table.q_base + int(norm >= table.norm_threshold) + int(property_score >= table.property_threshold)
		target = p.actor_person_id
		relation_delta = {"trust": table.trust_per_q * q, "resentment": table.resentment_per_q * q, "fear": table.fear_if_goods if p.took_goods else 0}
		emotion_delta = {"anger": table.anger_per_q * q, "fear": table.fear_if_goods if p.took_goods else 0}
		result.importance = table.importance_base + table.importance_per_q * q
		result.rule_id = "theft_hearsay" if hearsay else "theft_witness"
		result.memory_result = "theft_report" if hearsay else "witnessed_attempt_with_goods" if p.took_goods else "witnessed_attempt_without_goods"
		if hearsay:
			for key: String in relation_delta:
				relation_delta[key] = M5Data.rd(relation_delta[key] * obs.confidence, table.hearsay_delta_divisor)
			for key: String in emotion_delta:
				emotion_delta[key] = M5Data.rd(emotion_delta[key] * obs.confidence, table.hearsay_delta_divisor)
			result.importance = M5Data.rd(result.importance * obs.confidence, table.hearsay_importance_divisor)
	if not target.is_empty() and target != owner.id and not relation_delta.is_empty():
		var delta: Dictionary = {"target_person_id": target}
		for key: String in M5Data.RELATION_FIELDS:
			delta[key] = int(relation_delta.get(key, 0))
		result.relation_deltas.append(delta)
	for key: String in emotion_delta:
		result.emotion_deltas[key] = emotion_delta[key]
	return result
