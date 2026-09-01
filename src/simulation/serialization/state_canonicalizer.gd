class_name StateCanonicalizer
extends RefCounted


static func canonicalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			return _canonicalize_dictionary(value)
		TYPE_ARRAY:
			return _canonicalize_array(value)
		_:
			return value


static func canonical_json(value: Variant) -> String:
	return JSON.stringify(canonicalize(value), "", true, true)


static func pretty_json(value: Variant) -> String:
	return JSON.stringify(canonicalize(value), "  ", true, true) + "\n"


static func _canonicalize_dictionary(value: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	for key: Variant in value.keys():
		keys.append(str(key))
	keys.sort()

	var result: Dictionary = {}
	for key: String in keys:
		result[key] = canonicalize(value[key])
	return result


static func _canonicalize_array(value: Array) -> Array:
	var result: Array = []
	var all_strings: bool = not value.is_empty()
	var all_identified_dictionaries: bool = not value.is_empty()
	for item: Variant in value:
		var canonical_item: Variant = canonicalize(item)
		result.append(canonical_item)
		all_strings = all_strings and typeof(canonical_item) == TYPE_STRING
		all_identified_dictionaries = (
			all_identified_dictionaries
			and typeof(canonical_item) == TYPE_DICTIONARY
			and canonical_item.has("id")
		)

	if all_strings:
		result.sort()
	elif all_identified_dictionaries:
		result.sort_custom(_compare_dictionary_ids)
	return result


static func _compare_dictionary_ids(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("id", "")) < str(right.get("id", ""))
