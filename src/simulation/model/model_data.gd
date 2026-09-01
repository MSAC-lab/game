class_name ModelData
extends RefCounted


static func copy_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result

	var source: Array = value
	for item: Variant in source:
		result.append(str(item))
	return result


static func copy_string_int_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result

	var source: Dictionary = value
	for key: Variant in source.keys():
		result[str(key)] = int(source[key])
	return result


static func copy_string_string_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result

	var source: Dictionary = value
	for key: Variant in source.keys():
		result[str(key)] = str(source[key])
	return result


static func object_array_to_data(value: Array) -> Array:
	var result: Array = []
	for item: Variant in value:
		result.append(item.to_data())
	return result
