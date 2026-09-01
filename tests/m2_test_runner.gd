extends SceneTree

const M2_TIME_RESOURCE_TEST: GDScript = preload("res://tests/unit/m2_time_resource_test.gd")


func _init() -> void:
	var suite: RefCounted = M2_TIME_RESOURCE_TEST.new()
	if "--print-fixture" in OS.get_cmdline_user_args():
		var artifacts: Dictionary = suite.fixture_artifacts()
		var errors: Array = artifacts["errors"]
		if not errors.is_empty():
			for error: Variant in errors:
				push_error(str(error))
			quit(1)
			return
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
		print("M2 PASS: all time, resource, hunger, health, and regression tests passed.")
		quit(0)
		return
	print("M2 FAIL: %d test(s) failed." % failures.size())
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
