class_name ActionDefinition
extends RefCounted

var id: String = ""
var version: int = 1
var display_name: String = ""
var semantic_tags: Array[String] = []
var required_information_types: Array[String] = []
var relationship_keys: Array[String] = []
var resource_keys: Array[String] = []


func to_data() -> Dictionary:
	return {
		"id": id,
		"version": version,
		"display_name": display_name,
		"semantic_tags": semantic_tags.duplicate(),
		"required_information_types": required_information_types.duplicate(),
		"relationship_keys": relationship_keys.duplicate(),
		"resource_keys": resource_keys.duplicate(),
	}


static func from_data(data: Dictionary) -> ActionDefinition:
	var definition: ActionDefinition = ActionDefinition.new()
	definition.id = str(data.get("id", ""))
	definition.version = int(data.get("version", 1))
	definition.display_name = str(data.get("display_name", ""))
	definition.semantic_tags = ModelData.copy_string_array(data.get("semantic_tags", []))
	definition.required_information_types = ModelData.copy_string_array(
		data.get("required_information_types", [])
	)
	definition.relationship_keys = ModelData.copy_string_array(data.get("relationship_keys", []))
	definition.resource_keys = ModelData.copy_string_array(data.get("resource_keys", []))
	return definition
