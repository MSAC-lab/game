class_name ResponseEvaluator
extends RefCounted

const CARE_FIELDS: Array = [
	["trait_scores", "empathy"],
	["value_scores", "community_survival"],
	["value_scores", "fairness_reciprocity"],
	["value_scores", "life_protection"],
]
const RELATION_FIELDS: Array[String] = [
	"trust",
	"affection",
	"obligation",
	"fear",
	"resentment",
]


static func evaluate(world: WorldState, intent: ActionIntent) -> Dictionary:
	if not M4Rules.validate_world_manifest(world, ["response"]).is_empty():
		return {
			"ok": false,
			"errors": ["component_ruleset_mismatch"],
			"evaluation": null,
			"random_draws": [] as Array[RandomDrawRecord],
		}
	var responder: PersonState = world.find_person(intent.target_person_id)
	var responder_household: HouseholdState = world.find_household(responder.household_id)
	var source: ResourceStoreState = world.find_resource_store(
		responder_household.resource_store_id
	)
	var evaluation: ResponseEvaluation = ResponseEvaluation.new()
	evaluation.responder_person_id = responder.id
	evaluation.source_store_id = source.id
	evaluation.source_stock_units = source.quantity
	for member_id: String in responder_household.member_ids:
		var member: PersonState = world.find_person(member_id)
		if member != null and member.alive:
			evaluation.reserve_need_units += member.daily_food_need_units * 10
	evaluation.surplus_units = maxi(
		0, evaluation.source_stock_units - evaluation.reserve_need_units
	)

	var care_total: int = 0
	for field_value: Variant in CARE_FIELDS:
		var field: Array = field_value
		var domain: String = str(field[0])
		var key: String = str(field[1])
		var scores: Dictionary = responder.get(domain)
		if not scores.has(key):
			evaluation.defaulted_inputs.append(
				"persons[%s].%s.%s" % [responder.id, domain, key]
			)
		care_total += int(scores.get(key, 0))
	evaluation.care_score = M4Math.round_div(care_total, 4)

	var relation: RelationState = _find_relation(world, responder.id, intent.actor_person_id)
	if relation == null:
		for component: String in RELATION_FIELDS:
			evaluation.defaulted_inputs.append(
				"relations[%s->%s].%s"
				% [responder.id, intent.actor_person_id, component]
			)
	else:
		evaluation.relation_score = clampi(
			M4Math.round_div(
				relation.trust
				+ relation.affection
				+ relation.obligation
				- relation.fear
				- relation.resentment,
				3
			),
			-100,
			100
		)

	if evaluation.surplus_units > 0:
		evaluation.grant_candidate_present = true
		evaluation.grant_authorized_units = mini(
			evaluation.surplus_units, intent.requested_units
		)
		evaluation.grant_candidate_decision = (
			"GRANT_FULL"
			if evaluation.grant_authorized_units == intent.requested_units
			else "GRANT_PARTIAL"
		)
		evaluation.reserve_cost = M4Math.round_div(
			evaluation.grant_authorized_units * 100, evaluation.surplus_units
		)
		evaluation.grant_utility = (
			20 * evaluation.care_score
			+ 10 * evaluation.relation_score
			- 20 * evaluation.reserve_cost
		)
	evaluation.defaulted_inputs = _sorted_unique(evaluation.defaulted_inputs)

	var random_draws: Array[RandomDrawRecord] = []
	if not evaluation.grant_candidate_present or evaluation.grant_utility < 0:
		evaluation.selected_decision = "REJECT"
	elif evaluation.grant_utility > 0:
		evaluation.selected_decision = evaluation.grant_candidate_decision
		evaluation.selected_authorized_units = evaluation.grant_authorized_units
	else:
		evaluation.tie_break_used = true
		var draw: RandomDrawRecord = M4StatelessRng.draw(
			world,
			intent.action_instance_id,
			M4StatelessRng.TIE_PURPOSE,
			responder.id,
			2
		)
		random_draws.append(draw)
		if draw.mapped_value == 0:
			evaluation.selected_decision = evaluation.grant_candidate_decision
			evaluation.selected_authorized_units = evaluation.grant_authorized_units
		else:
			evaluation.selected_decision = "REJECT"
	return {
		"ok": true,
		"errors": [] as Array[String],
		"evaluation": evaluation,
		"random_draws": random_draws,
	}


static func _find_relation(
	world: WorldState, source_person_id: String, target_person_id: String
) -> RelationState:
	var relation_id: String = IdAllocator.relation_id(source_person_id, target_person_id)
	for relation: RelationState in world.relations:
		if relation.id == relation_id:
			return relation
	return null


static func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if not result.has(value):
			result.append(value)
	result.sort()
	return result
