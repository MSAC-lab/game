class_name WitnessEvaluation
extends RefCounted

var witness_person_id: String = ""
var perception_score: int = 0
var exposure_pressure: int = 0
var exposure_half: int = 0
var notice_offset: int = 0
var notice_score: int = 0
var notice_threshold: int = 0
var witnessed: bool = false


func to_data() -> Dictionary:
	return {
		"witness_person_id": witness_person_id,
		"perception_score": perception_score,
		"exposure_pressure": exposure_pressure,
		"exposure_half": exposure_half,
		"notice_offset": notice_offset,
		"notice_score": notice_score,
		"notice_threshold": notice_threshold,
		"witnessed": witnessed,
	}
