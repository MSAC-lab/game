extends SceneTree
## Developer CLI: exit 0 completed, 2 day progression stopped, 1 invalid input/I/O.


func _init() -> void:
	var options: Dictionary = {"scenario": "res://scenarios/m6-0-food-pressure-v1.json", "days": "28",
		"checkpoint-in": "", "checkpoint-out": "", "evidence-path": ""}
	var seen: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var key: String = argument.get_slice("=", 0).trim_prefix("--")
		if not argument.begins_with("--") or not argument.contains("=") or not options.has(key) or seen.has(key):
			_fail("Unknown, duplicate or malformed option: " + argument)
			return
		options[key] = argument.substr(argument.find("=") + 1)
		seen[key] = true
	if not str(options.days).is_valid_int() or str(int(options.days)) != options.days:
		_fail("days must be a canonical integer")
		return
	if not options["checkpoint-out"].is_empty() and _absolute(options["checkpoint-out"]) == _absolute(options["evidence-path"]):
		_fail("Checkpoint and evidence require different output paths")
		return
	for output: String in [options["checkpoint-out"], options["evidence-path"]]:
		if not output.is_empty() and _absolute(output) == _absolute(options.scenario):
			_fail("Output cannot overwrite the scenario")
			return
	if not options["evidence-path"].is_empty() and not options["checkpoint-in"].is_empty() and _absolute(options["evidence-path"]) == _absolute(options["checkpoint-in"]):
		_fail("Evidence cannot overwrite the input checkpoint")
		return
	var scenario_text: String = _read(options.scenario)
	if scenario_text.is_empty():
		return
	var scenario: Dictionary = M60Scenario.load_json(scenario_text)
	if not scenario.ok:
		_fail(scenario.error)
		return
	var checkpoint: String = ""
	if not options["checkpoint-in"].is_empty():
		checkpoint = _read(options["checkpoint-in"])
		if checkpoint.is_empty():
			return
	var result: M60RunResult = M60Runner.run_v1(scenario.world, scenario.config, int(options.days), checkpoint)
	var evidence: String = StateCanonicalizer.canonical_json(result.to_data()) + "\n"
	if not options["evidence-path"].is_empty() and not _write(options["evidence-path"], evidence):
		return
	if not options["checkpoint-out"].is_empty() and not result.checkpoint_json.is_empty():
		if not _write(options["checkpoint-out"], result.checkpoint_json):
			return
	if options["evidence-path"].is_empty():
		print(evidence.strip_edges())
	print("M6-0 %s: advanced %d/%d days; completed history %d days; state %s" % [
		result.status, result.advanced_days, result.requested_days, result.days.size(),
		StateHasher.hash_world(result.next_world) if result.next_world != null else "none"])
	if not result.error.is_empty():
		print(StateCanonicalizer.canonical_json(result.error))
	quit(0 if result.ok else 2 if result.status == "STOPPED" else 1)


func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Cannot read: " + path)
		return ""
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty():
		_fail("Empty input: " + path)
	return text


func _write(path: String, text: String) -> bool:
	path = _absolute(path)
	var directory: String = path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("Cannot create output directory: " + directory)
		return false
	# Replace only after a successful complete write. A failed write leaves the previous save.
	var temporary: String = path + ".m60-%d.tmp" % OS.get_process_id()
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write: " + path)
		return false
	file.store_string(text)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		_fail("Incomplete write: " + path)
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		_fail("Cannot replace output: " + path)
		return false
	return true


func _absolute(path: String) -> String:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not absolute.is_absolute_path():
		absolute = ProjectSettings.globalize_path("res://").path_join(absolute)
	return absolute.simplify_path()


func _fail(message: String) -> void:
	printerr("M6-0 CLI: " + message)
	quit(1)
