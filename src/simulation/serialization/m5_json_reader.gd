class_name M5JsonReader
extends RefCounted
## Schema 5 token reader. Detect duplicates and noninteger tokens before typed conversion.

var _text: String
var _at: int = 0
var _error: String = ""


static func parse(text: String) -> Dictionary:
	var reader: M5JsonReader = M5JsonReader.new()
	reader._text = text
	var value: Variant = reader._value(0)
	reader._space()
	if reader._at != text.length() and reader._error.is_empty():
		reader._error = "trailing JSON data"
	return {"ok": reader._error.is_empty(), "value": value, "error": reader._error}


func _space() -> void:
	while _at < _text.length() and _text[_at] in [" ", "\n", "\r", "\t"]:
		_at += 1


func _take(token: String) -> bool:
	_space()
	if _text.substr(_at, token.length()) == token:
		_at += token.length()
		return true
	return false


func _string() -> String:
	var start: int = _at
	_at += 1
	while _at < _text.length():
		var char: String = _text[_at]
		_at += 1
		if char.unicode_at(0) < 32:
			_error = "unescaped control character in JSON string"
			return ""
		if char == "\\":
			_at += 1
		elif char == "\"":
			var parser: JSON = JSON.new()
			if parser.parse(_text.substr(start, _at - start)) == OK and typeof(parser.data) == TYPE_STRING:
				return parser.data
			_error = "invalid JSON string"
			return ""
	_error = "unterminated JSON string"
	return ""


func _value(depth: int) -> Variant:
	_space()
	if depth > 128 or _at >= _text.length() or not _error.is_empty():
		_error = "invalid JSON value"
		return null
	var char: String = _text[_at]
	if char == "\"":
		return _string()
	if _take("{"):
		var object: Dictionary = {}
		if _take("}"):
			return object
		while _error.is_empty():
			_space()
			if _at >= _text.length() or _text[_at] != "\"":
				break
			var key: String = _string()
			if object.has(key):
				_error = "duplicate JSON object key: " + key
				return null
			if not _take(":"):
				break
			object[key] = _value(depth + 1)
			if _take("}"):
				return object
			if not _take(","):
				break
	elif _take("["):
		var array: Array = []
		if _take("]"):
			return array
		while _error.is_empty():
			array.append(_value(depth + 1))
			if _take("]"):
				return array
			if not _take(","):
				break
	elif _take("true"):
		return true
	elif _take("false"):
		return false
	elif _take("null"):
		return null
	else:
		var start: int = _at
		while _at < _text.length() and _text[_at] not in [" ", "\n", "\r", "\t", ",", "]", "}"]:
			_at += 1
		var token: String = _text.substr(start, _at - start)
		var pattern: RegEx = RegEx.create_from_string("^-?(0|[1-9][0-9]*)$")
		var digits: String = token.trim_prefix("-")
		if pattern.search(token) != null and (digits.length() < 10 or (digits.length() == 10 and digits <= "2147483647")):
			return token.to_int()
		_error = "Schema 5 requires bounded integer JSON tokens"
		return null
	if _error.is_empty():
		_error = "invalid JSON syntax"
	return null
