class_name RulesetManifest
extends RefCounted

const COMPONENT_NAMES: Array[String] = [
	"resource",
	"decision",
	"parameterization",
	"response",
	"resolution",
]
const SCHEMA5_COMPONENT_NAMES: Array[String] = ["resource", "decision", "parameterization", "response", "resolution", "social"]

var components: Dictionary = {}
var schema_version: int = WorldState.SCHEMA_VERSION_M4


static func from_data(data: Dictionary, version: int = WorldState.SCHEMA_VERSION_M4) -> RulesetManifest:
	var manifest: RulesetManifest = RulesetManifest.new()
	manifest.schema_version = version
	for component_name: String in SCHEMA5_COMPONENT_NAMES if version == WorldState.SCHEMA_VERSION_M5 else COMPONENT_NAMES:
		var value: Variant = data.get(component_name)
		if typeof(value) == TYPE_DICTIONARY:
			manifest.components[component_name] = RulesetComponentRef.from_data(value)
	return manifest


func to_data() -> Dictionary:
	var data: Dictionary = {}
	for component_name: String in SCHEMA5_COMPONENT_NAMES if schema_version == WorldState.SCHEMA_VERSION_M5 else COMPONENT_NAMES:
		var component: RulesetComponentRef = components.get(component_name)
		if component != null:
			data[component_name] = component.to_data()
	return data


func component(component_name: String) -> RulesetComponentRef:
	return components.get(component_name)
