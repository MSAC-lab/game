"""Run the native M5 contract gate; exit 2 preserves a reproduced design HOLD.

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
    if evidence["failures"] or result.returncode not in (0, 2):
        return 1
    expected = 2 if evidence["m5_status"] == "HOLD" else 0
    if result.returncode != expected or evidence["m5_status"] not in ("PASS", "HOLD"):
        print("M5 FAIL: runner status and exit code disagree.", file=sys.stderr)
        return 1
    return expected


if __name__ == "__main__":
    sys.exit(main())
