"""Run the native M6-0 gate, rejecting script aborts and incomplete test groups."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


GROUPS = {
    "_observed_compatibility", "_entry_contract", "_fixed_presence",
    "_manual_and_no_actors", "_atomic_failures", "_checkpoint_rejections",
    "_repeat_and_resume",
}
DESIGN_SHA256 = "a8bcb4fb2346a3eb185ca50c0df0cf988d623d7dd2c7f6ff515998bf652332f8"


def verify_cli(godot: str, root: Path, output: Path, evidence: dict) -> None:
    directory = output.parent / "m60-cli"
    directory.mkdir(parents=True, exist_ok=True)
    checkpoint = directory / "checkpoint.json"
    observation = directory / "observation.json"

    def execute(options: list[str], expected_code: int) -> None:
        command = [godot, "--headless", "--path", str(root), "--script",
                   "res://tools/run_m60.gd", "--", *options]
        result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, encoding="utf-8", errors="replace")
        with output.with_suffix(".log").open("a", encoding="utf-8") as log:
            log.write(result.stdout)
        if result.returncode != expected_code or "ERROR:" in result.stdout:
            raise ValueError("CLI exit/engine diagnostic mismatch: " + result.stdout)

    common = ["--checkpoint-out=" + str(checkpoint), "--evidence-path=" + str(observation)]
    execute(["--days=0", *common], 0)
    execute(["--days=1", "--checkpoint-in=" + str(checkpoint), *common], 0)
    saved = json.loads(checkpoint.read_text(encoding="utf-8"))
    report = json.loads(observation.read_text(encoding="utf-8"))
    if saved["world_save"]["state_hash"] != evidence["food_pressure_28"]["days"][0]["output_state_hash"]:
        raise ValueError("CLI resume differs from native first day")
    if report["advanced_days"] != 1 or report["status"] != "COMPLETED":
        raise ValueError("CLI completed period not reported")
    previous = checkpoint.read_bytes()
    execute(["--days=0", "--checkpoint-out=" + str(checkpoint), "--evidence-path=" + str(checkpoint)], 1)
    execute(["--days=1.0", *common], 1)
    execute(["--days=1", "--days=2", *common], 1)
    if checkpoint.read_bytes() != previous:
        raise ValueError("CLI input rejection replaced previous checkpoint")
    boundary = evidence["expected_health_stop"]
    scenario = directory / "health-boundary.json"
    scenario.write_text(json.dumps({"algorithm_id": "m60-scenario-v1",
                                   "initial_payload": boundary["initial_payload"],
                                   "config": boundary["config"]}), encoding="utf-8")
    execute(["--days=3", "--scenario=" + str(scenario), *common], 2)
    report = json.loads(observation.read_text(encoding="utf-8"))
    if report != boundary:
        raise ValueError("CLI stopped observation differs from native result")
    print("M6-0 CLI PASS: file replacement, resume, rejection and stop exit codes verified.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--evidence-path", default="builds/m60-runtime-evidence.json")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = Path(args.evidence_path).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    command = [args.godot, "--headless", "--path", str(root), "--script",
               "res://tests/m60_test_runner.gd", "--", "--evidence-path=" + str(output)]
    result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, encoding="utf-8", errors="replace")
    output.with_suffix(".log").write_text(result.stdout, encoding="utf-8")
    print(result.stdout, end="")
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        print("M6-0 FAIL: native process failed or engine diagnostics occurred.", file=sys.stderr)
        return 1
    if not output.exists():
        print("M6-0 FAIL: missing execution evidence.", file=sys.stderr)
        return 1
    evidence = json.loads(output.read_text(encoding="utf-8"))
    valid = (
        evidence.get("m60_status") == "PASS"
        and not evidence.get("failures", ["missing"])
        and set(evidence.get("completed_groups", [])) == GROUPS
        and len(evidence.get("completed_groups", [])) == len(GROUPS)
        and evidence.get("design_sha256") == DESIGN_SHA256
        and evidence.get("food_pressure_28", {}).get("status") == "COMPLETED"
        and evidence.get("food_pressure_28", {}).get("advanced_days") == 28
        and evidence.get("expected_health_stop", {}).get("status") == "STOPPED"
        and evidence.get("expected_health_stop", {}).get("advanced_days") == 0
        and evidence.get("day_29_stop", {}).get("status") == "STOPPED"
        and evidence.get("day_29_stop", {}).get("completed_days") == 28
        and all(evidence.get("repeat_resume", {}).get(key) is True for key in
                ("repeat_equal", "resume_equal", "permutation_equal"))
    )
    if not valid:
        print("M6-0 FAIL: incomplete contract evidence.", file=sys.stderr)
        return 1
    try:
        verify_cli(args.godot, root, output, evidence)
    except (ValueError, OSError) as error:
        print("M6-0 FAIL: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
