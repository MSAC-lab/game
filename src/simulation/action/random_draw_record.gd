class_name RandomDrawRecord
extends RefCounted

var roll_purpose: String = ""
var participant_id: String = ""
var digest_hex: String = ""
var source_hex: String = ""
var modulus: int = 0
var mapped_value: int = 0


func to_data() -> Dictionary:
	return {
		"roll_purpose": roll_purpose,
		"participant_id": participant_id,
		"digest_hex": digest_hex,
		"source_hex": source_hex,
		"modulus": modulus,
		"mapped_value": mapped_value,
	}
