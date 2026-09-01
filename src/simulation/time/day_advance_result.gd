class_name DayAdvanceResult
extends RefCounted

var ok: bool = false
var errors: Array[String] = []
var next_world: WorldState = null
var resource_transactions: Array[ResourceTransactionRecord] = []
var before_total: int = 0
var after_total: int = 0
var consumed_total: int = 0


static func failure(failure_errors: Array[String]) -> DayAdvanceResult:
	var result: DayAdvanceResult = DayAdvanceResult.new()
	result.errors = failure_errors.duplicate()
	return result


static func success(
	world: WorldState,
	transactions: Array[ResourceTransactionRecord],
	before: int,
	after: int,
	consumed: int
) -> DayAdvanceResult:
	var result: DayAdvanceResult = DayAdvanceResult.new()
	result.ok = true
	result.next_world = world
	result.resource_transactions = transactions.duplicate()
	result.before_total = before
	result.after_total = after
	result.consumed_total = consumed
	return result
