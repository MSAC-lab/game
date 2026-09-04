class_name M4RulesData
extends RefCounted


static func load_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open M4 rules resource: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("M4 rules resource is not a dictionary: %s" % path)
		return {}
	return _normalize_numbers(parsed)


static func _normalize_numbers(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, floor(value)):
		return int(value)
	if typeof(value) == TYPE_ARRAY:
		var array: Array = []
		for item: Variant in value:
			array.append(_normalize_numbers(item))
		return array
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = {}
		for key: Variant in value.keys():
			dictionary[key] = _normalize_numbers(value[key])
		return dictionary
	return value
