extends SceneTree

const M3_DECISION_ENGINE_TEST: GDScript = preload(
	"res://tests/unit/m3_decision_engine_test.gd"
)


func _init() -> void:
	var suite: RefCounted = M3_DECISION_ENGINE_TEST.new()
	if "--print-fixture" in OS.get_cmdline_user_args():
		var artifacts: Dictionary = suite.fixture_artifacts()
		print("FIXTURE_JSON_BEGIN")
		printraw(artifacts["json"])
		print("FIXTURE_JSON_END")
		print("FIXTURE_HASH_BEGIN")
		printraw(artifacts["hash"])
		print("FIXTURE_HASH_END")
		quit(0 if artifacts["errors"].is_empty() else 1)
		return

	var failures: Array[String] = suite.run_all()
	if failures.is_empty():
		print("M3 PASS: all decision mechanics tests passed; behavior remains observational.")
		quit(0)
		return
	print("M3 FAIL: %d test(s) failed." % failures.size())
	for failure: String in failures:
		print(" - %s" % failure)
	quit(1)
