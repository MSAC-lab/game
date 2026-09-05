"""Run the reviewed five-household experiment through the unchanged native M6-0 CLI.

Raw native records/checkpoints stay in --output-dir. summary.json is derived from
those records; it never supplies decisions or effects to the simulation.
"""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SCENARIO = ROOT / "scenarios/m6-five-household-observation-v1.json"
FROZEN = ROOT / "scenarios/m6-0-food-pressure-v1.json"
FROZEN_SHA = "113340d2df337564f9414398f4a9e1c4d739b0c1c624bc29d58dbe7668b890cd"
PERSON_CHANGES = {
    "C01": (13, "trait_scores", "risk_taking", 50, 80),
    "C02": (4, "trait_scores", "empathy", 50, 80),
    "C03": (1, "value_scores", "family_protection", 70, 90),
    "C04": (4, "value_scores", "life_protection", 50, 80),
    "C05": (4, "value_scores", "community_survival", 50, 80),
    "C06": (4, "value_scores", "family_protection", 70, 90),
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def canonical(value):
    """Mirror StateCanonicalizer for input hashing; native loading verifies it."""
    if isinstance(value, dict):
        return {key: canonical(value[key]) for key in sorted(value)}
    if isinstance(value, list):
        result = [canonical(item) for item in value]
        if result and all(isinstance(item, str) for item in result):
            result.sort()
        elif result and all(isinstance(item, dict) and "id" in item for item in result):
            result.sort(key=lambda item: item["id"])
        return result
    return value


def encoded(value):
    return json.dumps(canonical(value), ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def digest(value):
    return hashlib.sha256(encoded(value)).hexdigest()


def write(path, value):
    path.write_bytes(encoded(value) + b"\n")


def person_id(number):
    return f"person:{number:06d}"


def scalar_differences(before, after, path=""):
    if isinstance(before, dict) and isinstance(after, dict):
        require(before.keys() == after.keys(), "Input keys changed at " + path)
        return [item for key in sorted(before) for item in
                scalar_differences(before[key], after[key], path + "/" + key)]
    if isinstance(before, list) and isinstance(after, list):
        require(len(before) == len(after), "Input array size changed at " + path)
        return [item for i, (a, b) in enumerate(zip(before, after))
                for item in scalar_differences(a, b, path + "/" + str(i))]
    return [] if type(before) is type(after) and before == after else [
        {"path": path, "before": before, "after": after}]


def make_inputs(directory):
    require(hashlib.sha256(FROZEN.read_bytes()).hexdigest() == FROZEN_SHA,
            "The frozen four-person scenario changed")
    base = load(SCENARIO)
    state = base["initial_payload"]["state"]
    require([len(state[key]) for key in ("households", "persons", "information", "relations")]
            == [5, 15, 109, 58], "Initial entity counts differ from the reviewed plan")
    require(len(base["config"]["automatic_person_ids"]) == 9
            and len(base["config"]["contacts"]) == 15, "Actor/contact count mismatch")
    require(sum(p["daily_food_need_units"] for p in state["persons"]) == 24
            and sum(s["quantity"] for s in state["resource_stores"]) == 398,
            "Initial food or need differs from the reviewed plan")
    access = [f for f in state["information"] if f["fact_type_id"] == "request_food_access"]
    require(len(access) == 14 and all(f["belief_value"] == 100 and f["confidence"] == 100
                                    for f in access), "Reviewed access correction missing")
    require(base["config"]["initial_state_hash"] == digest(base["initial_payload"]),
            "Base input hash mismatch")
    inputs, changes = {"F00": base}, {}
    for label in [f"C{i:02d}" for i in range(1, 9)]:
        value = copy.deepcopy(base)
        world = value["initial_payload"]["state"]
        if label in PERSON_CHANGES:
            number, group, key, old, new = PERSON_CHANGES[label]
            target = next(p for p in world["persons"] if p["id"] == person_id(number))[group]
        else:
            number, subject, fact, key, old, new = (
                (1, person_id(4), "request_success_expectation", "belief_value", 80, 20)
                if label == "C07" else
                (13, "resource_store:village_granary", "theft_access", "confidence", 100, 60))
            target = next(f for f in world["information"] if f["owner_person_id"] == person_id(number)
                          and f["subject_id"] == subject and f["fact_type_id"] == fact)
        require(target[key] == old, label + " old value mismatch")
        target[key] = new
        delta = scalar_differences(base["initial_payload"], value["initial_payload"])
        require(len(delta) == 1, label + " must change exactly one causal scalar")
        value["config"]["initial_state_hash"] = digest(value["initial_payload"])
        all_delta = scalar_differences(base, value)
        require(len(all_delta) == 2 and any(d["path"] == "/config/initial_state_hash"
                                         for d in all_delta), label + " config contamination")
        changes[label] = {"causal_changes": delta, "derived_changes": [d for d in all_delta
                            if d["path"] == "/config/initial_state_hash"]}
        inputs[label] = value
    for label, value in inputs.items():
        write(directory / (label + ".input.json"), value)
    return inputs, changes


def run_native(godot, directory, label, input_label, days, checkpoint_in=None):
    observation = directory / (label + ".json")
    checkpoint = directory / (label + ".checkpoint.json")
    observation.unlink(missing_ok=True)
    checkpoint.unlink(missing_ok=True)
    command = [godot, "--headless", "--path", str(ROOT), "--script", "res://tools/run_m60.gd", "--",
               "--scenario=" + str(directory / (input_label + ".input.json")), "--days=" + str(days),
               "--evidence-path=" + str(observation), "--checkpoint-out=" + str(checkpoint)]
    if checkpoint_in:
        command.append("--checkpoint-in=" + str(checkpoint_in))
    print("Running " + label + " (" + str(days) + " days requested)", flush=True)
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            encoding="utf-8", errors="replace")
    (directory / (label + ".log")).write_text(result.stdout, encoding="utf-8")
    require(result.returncode in (0, 2) and "ERROR:" not in result.stdout,
            label + " native failure: " + result.stdout)
    require(observation.exists() and checkpoint.exists(), label + " missing native output")
    report = load(observation)
    require((result.returncode == 0) == (report["status"] == "COMPLETED"), label + " exit mismatch")
    print(label + ": " + report["status"] + ", completed history " + str(report["completed_days"]), flush=True)


def read_bound(directory, label, scenario):
    result = load(directory / (label + ".json"))
    require(result["initial_payload"] == canonical(scenario["initial_payload"])
            and result["config"] == canonical(scenario["config"]), label + " evidence/input mismatch")
    require(result["status"] in ("COMPLETED", "STOPPED") and result["next_world"] is not None,
            label + " input rejected or output missing")
    raw = (directory / (label + ".checkpoint.json")).read_bytes()
    require(result["checkpoint_sha256"] == hashlib.sha256(raw).hexdigest(), label + " checkpoint mismatch")
    saved = json.loads(raw)
    require(saved["world_save"]["state_hash"] == digest(result["next_world"])
            and saved["days"] == result["days"], label + " checkpoint world/history differs")
    if result["status"] == "STOPPED":
        error, failed = result["error"], result["failed_day"]
        require(error["code"] == "M60_M5_REJECTED" and error["phase"] == "CLOSE"
                and len(error["details"]) == 1
                and error["details"][0]["code"] == "M5_POST_APPLY_INVARIANT"
                and error["details"][0]["field_path"] == "state.persons.health",
                label + " unexpected stop (not the authorized health boundary): " + str(error))
        require(not result["ok"] and failed["day_status"] == "ABORTED"
                and failed["input_state_hash"] == digest(result["next_world"])
                and failed["output_state_hash"] == ""
                and failed["day_index"] == result["next_world"]["state"]["day_index"]
                and failed["operations"][-1]["artifact"]["status"] == "REJECTED",
                label + " aborted day replaced the last completed world")
    else:
        require(result["ok"] and result["failed_day"] is None and not result["error"]
                and result["advanced_days"] == result["requested_days"], label + " invalid completion")
    return result


def candidate(day, number, action):
    decision = next(d for d in day["decisions"] if d["actor_person_id"] == person_id(number))
    candidates = [c for c in decision["candidate_evaluations"] if c["action_id"] == action]
    if action == "A04":
        candidates = [c for c in candidates if c["target_id"] == person_id(4)]
    require(len(candidates) == 1, f"Expected {action} candidate for P{number:02d}")
    return candidates[0]


def response(day):
    records = day["m4_batch_artifact"]["batch_resolution"]["committed_outcomes"]
    matching = [r for r in records if r["actor_person_id"] == person_id(1) and r["action_id"] == "A04"
                and r["details"].get("target_person_id") == person_id(4)
                and "response_evaluation" in r["details"]]
    return matching[0]["details"] if len(matching) == 1 else None


def ledger_and_choices(result):
    initial = result["initial_payload"]["state"]
    stock = {s["id"]: s["quantity"] for s in initial["resource_stores"]}
    original = sum(stock.values())
    total_consumed = 0
    rows, tx_ids = [], set()
    input_hash = digest(result["initial_payload"])
    for day in result["days"]:
        require(day["day_status"] == "COMMITTED" and day["input_state_hash"] == input_hash,
                "Day boundary chain mismatch")
        body = {k: v for k, v in day.items() if k != "record_hash"}
        require(digest(body) == day["record_hash"], "Day record hash mismatch")
        opening = stock.copy()
        movements = {key: {"opening": amount, "incoming": 0, "outgoing": 0, "consumed": 0}
                     for key, amount in stock.items()}
        for operation in day["operations"]:
            artifact = operation["artifact"]
            require(artifact["status"] == "COMMITTED" and artifact["input_state_hash"] == input_hash,
                    "Partially committed day")
            input_hash = artifact["output_state_hash"]
            for tx in sorted(operation["resource_transactions"], key=lambda tx: tx["sequence_index"]):
                require(tx["id"] not in tx_ids and tx["quantity"] > 0, "Duplicate/nonpositive transaction")
                tx_ids.add(tx["id"])
                source, target, quantity = tx["source_store_id"], tx["destination_store_id"], tx["quantity"]
                stock[source] -= quantity
                require(stock[source] >= 0, "Resource overdraft")
                if tx["consumer_person_id"]:
                    require(not target, "Consumption has destination")
                    movements[source]["consumed"] += quantity
                    total_consumed += quantity
                else:
                    stock[target] += quantity
                    movements[source]["outgoing"] += quantity
                    movements[target]["incoming"] += quantity
        require(input_hash == day["output_state_hash"] and original == sum(stock.values()) + total_consumed,
                "Resource conservation/day output mismatch")
        for key in stock:
            movements[key]["closing"] = stock[key]
            require(stock[key] == opening[key] + movements[key]["incoming"]
                    - movements[key]["outgoing"] - movements[key]["consumed"], "Store ledger mismatch")
        choices = []
        outcomes = day["m4_batch_artifact"]["batch_resolution"]["committed_outcomes"]
        for decision in day["decisions"]:
            chosen = next(c for c in decision["candidate_evaluations"]
                          if c["candidate_id"] == decision["selected_candidate_id"])
            outcome = next(o for o in outcomes if o["actor_person_id"] == decision["actor_person_id"])
            require(outcome["source_decision_hash"] == digest(decision), "Outcome/decision binding mismatch")
            choices.append({"person": decision["actor_person_id"], "candidate": chosen,
                            "selection_mode": decision["selection_mode"], "processing_status": outcome["processing_status"],
                            "objective_outcome": outcome["objective_outcome"], "details": outcome["details"]})
        rows.append({"day": day["day_index"] + 1, "stores": movements, "choices": choices,
                     "remaining_food": sum(stock.values()), "cumulative_consumed": total_consumed,
                     "belief_changes": [effect["belief_change"] for op in day["operations"]
                                        for effect in op["artifact"]["effect_applications"] if effect["belief_change"]],
                     "social_metrics": day["operations"][-1]["artifact"]["state_metrics"]})
    require(stock == {s["id"]: s["quantity"] for s in result["next_world"]["state"]["resource_stores"]},
            "Ledger does not reach committed next world")
    require(input_hash == digest(result["next_world"]), "Final state hash mismatch")
    return rows


def collect(directory, inputs, changes):
    base = read_bound(directory, "F00", inputs["F00"])
    require(base["requested_days"] == 28 and base["completed_days"] == len(base["days"]), "F00 duration mismatch")
    rows = ledger_and_choices(base)
    first = base["days"][0]
    require(sum(len(d["candidate_evaluations"]) for d in first["decisions"]) == 23, "Initial candidate count")
    require(candidate(first, 1, "A04")["utility_scaled"] == 5795
            and candidate(first, 1, "A11")["utility_scaled"] == 3570, "Initial utilities differ")
    base_response = response(first)
    comparisons = []
    for label in changes:
        result = read_bound(directory, label, inputs[label])
        require(result["status"] == "COMPLETED" and result["advanced_days"] == 1, label + " did not complete day")
        ledger_and_choices(result)
        day = result["days"][0]
        detail = {"id": label, **changes[label], "status": "PASS", "initial_state_hash": result["config"]["initial_state_hash"]}
        if label in ("C02", "C04", "C05", "C06"):
            actual = response(day)
            if actual is None or base_response is None:
                detail["status"] = "NOT_EXERCISED"
            else:
                detail.update(before=base_response, after=actual)
                if label == "C06":
                    require(actual == base_response, "C06 direct response changed")
                else:
                    require(base_response["response_evaluation"]["care_score"] == 50
                            and actual["response_evaluation"]["care_score"] == 58
                            and base_response["response_evaluation"]["grant_utility"] == 1080
                            and actual["response_evaluation"]["grant_utility"] == 1240,
                            label + " response arithmetic mismatch")
        elif label in ("C01", "C03", "C07"):
            number = 13 if label == "C01" else 1
            detail["before"] = [candidate(first, number, action) for action in ("A04", "A11")]
            detail["after"] = [candidate(day, number, action) for action in ("A04", "A11")]
            if label == "C01":
                require(all(b["K"] < a["K"] and b["utility_scaled"] - a["utility_scaled"] == 15 * (a["K"] - b["K"])
                            for a, b in zip(detail["before"], detail["after"])), "C01 risk path mismatch")
            elif label == "C03":
                require([c["V"] for c in detail["after"]] == [63, -12], "C03 value path mismatch")
            else:
                require(detail["before"][0]["utility_scaled"] - detail["after"][0]["utility_scaled"] == 600,
                        "C07 expectation path mismatch")
                fact = next(f for f in inputs[label]["initial_payload"]["state"]["information"]
                            if f["owner_person_id"] == person_id(1) and f["subject_id"] == person_id(4)
                            and f["fact_type_id"] == "request_success_expectation")
                learned = [e["belief_change"] for op in day["operations"] for e in op["artifact"]["effect_applications"]
                           if e["belief_change"].get("information_id") == fact["id"]]
                require(len(learned) == 1 and learned[0]["old_belief"] == 20
                        and learned[0]["new_belief"] == 40 and learned[0]["sample"] == 100,
                        "C07 actual request learning mismatch")
                detail["actual_learning"] = learned[0]
        else:
            decision = next(d for d in day["decisions"] if d["actor_person_id"] == person_id(13))
            detail["before"] = candidate(first, 13, "A11")
            detail["after"] = decision
            require(not any(c["action_id"] == "A11" for c in decision["candidate_evaluations"])
                    and any("theft_access_below_50" in e["reason_ids"] for e in decision["excluded_candidates"]),
                    "C08 access exclusion not exercised")
        detail["selected_before"] = {d["actor_person_id"]: d["selected_candidate_id"] for d in first["decisions"]}
        detail["selected_after"] = {d["actor_person_id"]: d["selected_candidate_id"] for d in day["decisions"]}
        comparisons.append(detail)
    repeat = read_bound(directory, "F00-repeat", inputs["F00"])
    require(repeat == base and (directory / "F00-repeat.json").read_bytes() == (directory / "F00.json").read_bytes(),
            "Repeated native evidence differs")
    seven = read_bound(directory, "F00-seven", inputs["F00"])
    require(seven["requested_days"] == 7, "Split prefix did not request seven days")
    resume_status = "NOT_EXERCISED"
    if seven["status"] == "COMPLETED" and seven["advanced_days"] == 7:
        resumed = read_bound(directory, "F00-resumed", inputs["F00"])
        require(seven["days"] == base["days"][:7] and resumed["requested_days"] == 21
                and resumed["advanced_days"] + 7 == base["advanced_days"], "Resume period mismatch")
        for key in base.keys() - {"requested_days", "advanced_days"}:
            require(base[key] == resumed[key], "7+21 resume differs at " + key)
        require((directory / "F00.checkpoint.json").read_bytes()
                == (directory / "F00-resumed.checkpoint.json").read_bytes(), "Resume checkpoint bytes differ")
        resume_status = "PASS"
    manifest = {path.name: {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
                for path in sorted(directory.glob("*.json")) if path.name != "summary.json"}
    summary = {"algorithm_id": "five-household-observation-v1", "input_status": "PASS",
               "status": "PASS" if all(c["status"] == "PASS" for c in comparisons) else "PARTIAL",
               "scenario_sha256": hashlib.sha256(SCENARIO.read_bytes()).hexdigest(),
               "requested_days": base["requested_days"], "completed_days": base["completed_days"],
               "run_status": base["status"], "error": base["error"], "failed_day": base["failed_day"],
               "health_boundary_exercised": base["status"] == "STOPPED",
               "theft_executed": any(c["candidate"]["action_id"] == "A11" for row in rows for c in row["choices"]),
               "final_state_hash": digest(base["next_world"]), "repeat_status": "PASS", "resume_status": resume_status,
               "food_conservation": "PASS", "daily_observations": rows, "comparisons": comparisons,
               "final_persons": base["next_world"]["state"]["persons"], "native_files": manifest}
    write(directory / "summary.json", summary)
    print("Observation " + summary["status"] + "; " + str(base["completed_days"]) + "/28 days; repeat PASS; resume " + resume_status)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output-dir", default="builds/five-household")
    parser.add_argument("--mode", choices=("all", "remaining", "collect"), default="all",
                        help="remaining reuses an already produced F00 native record after input binding checks")
    args = parser.parse_args()
    directory = Path(args.output_dir).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    inputs, changes = make_inputs(directory)
    if args.mode != "collect":
        if args.mode == "all":
            run_native(args.godot, directory, "F00", "F00", 28)
        else:
            read_bound(directory, "F00", inputs["F00"])
        for label in changes:
            run_native(args.godot, directory, label, label, 1)
        run_native(args.godot, directory, "F00-repeat", "F00", 28)
        run_native(args.godot, directory, "F00-seven", "F00", 7)
        seven = read_bound(directory, "F00-seven", inputs["F00"])
        if seven["status"] == "COMPLETED" and seven["advanced_days"] == 7:
            run_native(args.godot, directory, "F00-resumed", "F00", 21, directory / "F00-seven.checkpoint.json")
    summary = collect(directory, inputs, changes)
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, StopIteration) as error:
        print("Five-household observation FAIL: " + str(error), file=sys.stderr)
        sys.exit(1)
