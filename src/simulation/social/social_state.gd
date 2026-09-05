class_name SocialState
extends RefCounted

var last_closed_day_index: int = -1
var last_contact_day_index: int = -1
var last_integrated_resolution_epoch: int = 0
var last_settled_week_index: int = -1
var revision: int = 0


func to_data() -> Dictionary:
	return {
		"last_closed_day_index": last_closed_day_index,
		"last_contact_day_index": last_contact_day_index,
		"last_integrated_resolution_epoch": last_integrated_resolution_epoch,
		"last_settled_week_index": last_settled_week_index,
		"revision": revision,
	}


static func from_data(data: Dictionary) -> SocialState:
	var value: SocialState = SocialState.new()
	value.last_closed_day_index = data["last_closed_day_index"]
	value.last_contact_day_index = data["last_contact_day_index"]
	value.last_integrated_resolution_epoch = data["last_integrated_resolution_epoch"]
	value.last_settled_week_index = data["last_settled_week_index"]
	value.revision = data["revision"]
	return value
