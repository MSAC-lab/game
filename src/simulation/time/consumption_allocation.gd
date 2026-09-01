class_name ConsumptionAllocation
extends RefCounted


static func allocate(
	people: Array[PersonState], available_quantity: int, day_index: int
) -> Dictionary:
	var alive_people: Array[PersonState] = []
	for person: PersonState in people:
		if person.alive:
			alive_people.append(person)
	alive_people.sort_custom(_compare_person_ids)

	var allocations: Dictionary = {}
	var total_need: int = 0
	for person: PersonState in alive_people:
		allocations[person.id] = 0
		total_need += person.daily_food_need_units
	if total_need == 0 or alive_people.is_empty() or available_quantity <= 0:
		return {"allocations": allocations, "total_need": total_need, "allocated_total": 0}

	var allocatable: int = mini(available_quantity, total_need)
	if allocatable == total_need:
		for person: PersonState in alive_people:
			allocations[person.id] = person.daily_food_need_units
		return {
			"allocations": allocations,
			"total_need": total_need,
			"allocated_total": total_need,
		}

	var allocated_total: int = 0
	for person: PersonState in alive_people:
		@warning_ignore("integer_division")
		var base: int = allocatable * person.daily_food_need_units / total_need
		allocations[person.id] = base
		allocated_total += base

	var remainder: int = allocatable - allocated_total
	var cursor: int = day_index % alive_people.size()
	while remainder > 0:
		var person: PersonState = alive_people[cursor]
		if int(allocations[person.id]) < person.daily_food_need_units:
			allocations[person.id] = int(allocations[person.id]) + 1
			remainder -= 1
			allocated_total += 1
		cursor = (cursor + 1) % alive_people.size()

	return {
		"allocations": allocations,
		"total_need": total_need,
		"allocated_total": allocated_total,
	}


static func _compare_person_ids(left: PersonState, right: PersonState) -> bool:
	return left.id < right.id
