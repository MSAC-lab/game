class_name DayPlan
extends RefCounted

var allocations: Dictionary = {}
var resource_transactions: Array[ResourceTransactionRecord] = []


func eaten_by(person_id: String) -> int:
	return int(allocations.get(person_id, 0))
