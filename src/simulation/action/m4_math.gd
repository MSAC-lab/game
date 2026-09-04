class_name M4Math
extends RefCounted


static func round_div(numerator: int, denominator: int) -> int:
	assert(denominator > 0)
	if numerator == 0:
		return 0
	var magnitude: int = (2 * absi(numerator) + denominator) / (2 * denominator)
	return magnitude if numerator > 0 else -magnitude


static func ceil_div_nonnegative(numerator: int, denominator: int) -> int:
	assert(numerator >= 0)
	assert(denominator > 0)
	return (numerator + denominator - 1) / denominator
