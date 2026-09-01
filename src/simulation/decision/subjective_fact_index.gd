class_name SubjectiveFactIndex
extends RefCounted

var _facts: Dictionary = {}
var _subjects: Dictionary = {}


static func build(world: WorldState, owner_person_id: String) -> SubjectiveFactIndex:
	var index: SubjectiveFactIndex = SubjectiveFactIndex.new()
	for fact: InformationState in world.information:
		if fact.owner_person_id != owner_person_id:
			continue
		var key: String = index._key(fact.subject_kind, fact.subject_id, fact.fact_type_id)
		index._facts[key] = fact
		var subject_key: String = "%s|%s" % [fact.subject_kind, fact.subject_id]
		index._subjects[subject_key] = true
	return index


func get_fact(subject_kind: String, subject_id: String, fact_type_id: String) -> InformationState:
	return _facts.get(_key(subject_kind, subject_id, fact_type_id)) as InformationState


func effective_value(subject_kind: String, subject_id: String, fact_type_id: String) -> int:
	var fact: InformationState = get_fact(subject_kind, subject_id, fact_type_id)
	if fact == null:
		return -1
	return M3DecisionRules.round_div(
		fact.belief_value * fact.confidence, M3DecisionRules.PERCENT_SCALE
	)


func fact_ids(subject_kind: String, subject_id: String, fact_type_ids: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	for fact_type_id: String in fact_type_ids:
		var fact: InformationState = get_fact(subject_kind, subject_id, fact_type_id)
		if fact != null:
			ids.append(fact.id)
	ids.sort()
	return ids


func missing_fact_types(
	subject_kind: String, subject_id: String, fact_type_ids: Array[String]
) -> Array[String]:
	var missing: Array[String] = []
	for fact_type_id: String in fact_type_ids:
		if get_fact(subject_kind, subject_id, fact_type_id) == null:
			missing.append(fact_type_id)
	missing.sort()
	return missing


func subject_ids(subject_kind: String) -> Array[String]:
	var ids: Array[String] = []
	for raw_key: Variant in _subjects.keys():
		var key: String = str(raw_key)
		var prefix: String = "%s|" % subject_kind
		if key.begins_with(prefix):
			ids.append(key.substr(prefix.length()))
	ids.sort()
	return ids


func _key(subject_kind: String, subject_id: String, fact_type_id: String) -> String:
	return "%s|%s|%s" % [subject_kind, subject_id, fact_type_id]
