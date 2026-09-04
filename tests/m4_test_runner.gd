extends SceneTree

const M4_ATOMIC_ACTION_TEST: GDScript = preload(
	"res://tests/unit/m4_atomic_action_test.gd"
)


func _init() -> void:
	var suite: RefCounted = M4_ATOMIC_ACTION_TEST.new()
	var failures: Array[String] = suite.run_all()
	if failures.is_empty():
		print("M4 PASS: schema 4 and atomic action-resolution tests passed.")
		quit(0)
		return
	print("M4 FAIL: %d test(s) failed." % failures.size())
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
