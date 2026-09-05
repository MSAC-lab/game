class_name M60RunResult
extends RefCounted

var ok: bool = false
var status: String = "REJECTED"
var next_world: WorldState = null
var checkpoint_json: String = ""
var days: Array = []
var failed_day: Variant = null
var error: Dictionary = {}
var requested_days: int = 0
var advanced_days: int = 0
var initial_payload: Dictionary = {}
var config: Dictionary = {}


func to_data() -> Dictionary:
	return {"algorithm_id": "m60-run-result-v1", "ok": ok, "status": status,
		"initial_payload": initial_payload.duplicate(true), "config": config.duplicate(true),
		"config_hash": StateHasher.hash_data(config) if not config.is_empty() else "",
		"requested_days": requested_days, "advanced_days": advanced_days, "completed_days": days.size(),
		"next_world": StateHasher.state_payload(next_world) if next_world != null else null,
		"checkpoint_sha256": checkpoint_json.sha256_text() if not checkpoint_json.is_empty() else "",
		"days": days.duplicate(true), "failed_day": failed_day.duplicate(true) if failed_day != null else null,
		"error": error.duplicate(true)}
