class_name SocialContactPlan
extends RefCounted

var pairs: Array[SocialContactPair] = []


func to_data() -> Dictionary:
	return {"pairs": ModelData.object_array_to_data(pairs)}


static func from_pairs(person_pairs: Array) -> SocialContactPlan:
	var plan: SocialContactPlan = SocialContactPlan.new()
	for pair: Array in person_pairs:
		var a: String = str(pair[0])
		var b: String = str(pair[1])
		plan.pairs.append(SocialContactPair.from_data({"id": "contact:%s->%s" % [a, b], "person_a_id": a, "person_b_id": b}))
	return plan
