class_name RulesetManifest
extends RefCounted

const COMPONENT_NAMES: Array[String] = [
	"resource",
	"decision",
	"parameterization",
	"response",
	"resolution",
]

var components: Dictionary = {}


static func from_data(data: Dictionary) -> RulesetManifest:
	var manifest: RulesetManifest = RulesetManifest.new()
	for component_name: String in COMPONENT_NAMES:
		var value: Variant = data.get(component_name)
		if typeof(value) == TYPE_DICTIONARY:
			manifest.components[component_name] = RulesetComponentRef.from_data(value)
	return manifest


func to_data() -> Dictionary:
	var data: Dictionary = {}
	for component_name: String in COMPONENT_NAMES:
		var component: RulesetComponentRef = components.get(component_name)
		if component != null:
			data[component_name] = component.to_data()
	return data


func component(component_name: String) -> RulesetComponentRef:
	return components.get(component_name)
