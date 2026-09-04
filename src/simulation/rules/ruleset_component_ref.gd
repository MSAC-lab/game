class_name RulesetComponentRef
extends RefCounted

var ruleset_id: String = ""
var ruleset_hash: String = ""


static func create(id: String, hash_value: String) -> RulesetComponentRef:
	var component: RulesetComponentRef = RulesetComponentRef.new()
	component.ruleset_id = id
	component.ruleset_hash = hash_value
	return component


static func from_data(data: Dictionary) -> RulesetComponentRef:
	return create(str(data.get("ruleset_id", "")), str(data.get("ruleset_hash", "")))


func to_data() -> Dictionary:
	return {
		"ruleset_id": ruleset_id,
		"ruleset_hash": ruleset_hash,
	}
