"""Run the native M5 contract gate with the approved FCAL correction.

Godot can return zero after a script method aborts. Reject engine diagnostics as
well as assertion failures, missing evidence, and incomplete test groups.
"""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--evidence-path", default="builds/m5-runtime-evidence.json")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = Path(args.evidence_path).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    command = [
        args.godot, "--headless", "--path", str(root),
        "--script", "res://tests/m5_test_runner.gd", "--",
        "--evidence-path=" + str(output),
    ]
    result = subprocess.run(command, cwd=root, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, encoding="utf-8", errors="replace")
    output.with_suffix(".log").write_text(result.stdout, encoding="utf-8")
    print(result.stdout, end="")
    if "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        print("M5 FAIL: engine diagnostics occurred.", file=sys.stderr)
        return 1
    if not output.exists():
        print("M5 FAIL: runner did not produce evidence.", file=sys.stderr)
        return 1
    evidence = json.loads(output.read_text(encoding="utf-8"))
    if evidence["failures"] or result.returncode != 0:
        return 1
    if evidence["m5_status"] != "PASS":
        print("M5 FAIL: runner did not pass the canonical contract.", file=sys.stderr)
        return 1
    if len(evidence.get("FCAL_canonical", [])) != 28:
        print("M5 FAIL: corrected canonical FCAL did not complete 28 days.", file=sys.stderr)
        return 1
    if not evidence.get("FCAL_health_boundary_regression", {}).get("passed", False):
        print("M5 FAIL: original hunger 40 rejection/atomicity regression did not pass.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
