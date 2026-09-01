extends SceneTree

const M1_STATE_MODEL_TEST: GDScript = preload("res://tests/unit/m1_state_model_test.gd")

func _init() -> void:
	var suite: RefCounted = M1_STATE_MODEL_TEST.new()
	if "--print-fixture" in OS.get_cmdline_user_args():
		var artifacts: Dictionary = suite.fixture_artifacts()
		print("FIXTURE_JSON_BEGIN")
		printraw(artifacts["json"])
		print("FIXTURE_JSON_END")
		print("FIXTURE_HASH_BEGIN")
		printraw(artifacts["hash"])
		print("FIXTURE_HASH_END")
		quit(0)
		return

	var failures: Array[String] = suite.run_all()
	if failures.is_empty():
		print("M1 PASS: all state-model and serialization tests passed.")
		quit(0)
		return
	print("M1 FAIL: %d test(s) failed." % failures.size())
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
