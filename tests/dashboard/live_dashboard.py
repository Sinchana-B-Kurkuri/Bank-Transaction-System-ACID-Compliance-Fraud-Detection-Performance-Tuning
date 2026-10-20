"""Real HTTP workflow against an already running owned dashboard. No SQL access."""
import argparse
import datetime as dt
import json
from pathlib import Path
import time
from urllib import request, error


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="http://127.0.0.1:5000")
    p.add_argument("--evidence-dir", required=True)
    a = p.parse_args()
    if a.url != "http://127.0.0.1:5000":
        p.error("This live runner uses the documented localhost5000 server only")
    directory = Path(a.evidence_dir)
    directory.mkdir(parents=True, exist_ok=False)
    results = []
    token = ""

    def call(path, payload=None, use_token=True):
        headers = {"Origin": a.url, "Content-Type": "application/json"}
        if use_token:
            headers["X-CSRF-Token"] = token
        r = request.Request(a.url + path, data=json.dumps(payload).encode() if payload is not None else None, headers=headers)
        try:
            with request.urlopen(r, timeout=60) as response:
                return response.status, json.loads(response.read())
        except error.HTTPError as e:
            return e.code, json.loads(e.read())

    def check(name, ok, detail):
        results.append({"test": name, "status": "PASS" if ok else "FAIL", "detail": detail})
        print("TEST|" + results[-1]["status"] + "|" + name + "|" + detail, flush=True)
        if not ok:
            raise AssertionError(name)

    def operate(name, fields):
        status, result = call("/api/operate", fields)
        (directory / (name + ".json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
        check(name, status == 200 and result.get("ok"), "real native MySQL public API via HTTP")
        return result

    try:
        status, boot = call("/api/bootstrap")
        token = boot["csrf"]
        check("live bootstrap", status == 200 and boot["mode"] == "NON-SECURITY DEMO", "owned session / explicit mode")
        status, before = call("/api/snapshot")
        check("real overview", status == 200 and before["stats"]["accounts"] >= 8, "statistics from seeded MySQL")
        check("CSRF rejects missing token", call("/api/operate", {"action": "deposit"}, False)[0] == 403, "no mutation")
        check("arbitrary SQL rejected", call("/api/operate", {"action": "sql", "sql": "SELECT 1"})[0] == 400, "fixed public actions only")
        suffix = str(time.time_ns())[-9:]
        email = "web." + suffix + "@example.invalid"
        operate("registration", {"action": "register", "name": "Synthetic <b>Dashboard</b> Customer", "dob": "1992-01-01", "email": email, "phone": "9" + suffix, "address": "Synthetic campus address", "id-proof": "SYN-PAN-" + suffix, "id-type": "PAN"})
        _, state = call("/api/snapshot")
        customer = next(c for c in state["customers"] if c["email"] == email)
        branch = state["branches"][0]["branch_id"]
        kind = next(t for t in state["types"] if t["type_name"] == "Savings")
        teller = next(e for e in state["employees"] if e["branch_id"] == branch and e["role"] == "Teller")
        manager = next(e for e in state["employees"] if e["branch_id"] == branch and e["role"] == "Manager")
        number = "WEB-" + suffix
        operate("opening", {"action": "open", "customer": str(customer["customer_id"]), "branch": str(branch), "type": str(kind["account_type_id"]), "initial": "20000", "number": number, "employee": str(teller["employee_id"])})
        _, state = call("/api/snapshot")
        account = next(x for x in state["accounts"] if x["account_number"] == number)
        aid = str(account["account_id"])
        to = str(next(x for x in state["accounts"] if x["account_id"] != account["account_id"] and x["status"] == "Active")["account_id"])
        operate("deposit", {"action": "deposit", "account": aid, "amount": "100", "channel": "Online"})
        operate("withdrawal", {"action": "withdraw", "account": aid, "amount": "25", "channel": "Online"})
        transfer = operate("transfer", {"action": "transfer", "account": aid, "to_account": to, "amount": "50", "channel": "Online"})
        actual = next(x for x in transfer["after"]["balances"] if str(x["account_id"]) == aid)["balance"]
        check("financial balance", float(actual) == 20025, "20000+100-25-50=20025")
        statement = operate("statement", {"action": "statement", "account": aid, "from": dt.date.today().isoformat(), "to": dt.date.today().isoformat()})
        check("statement running balance", "20025.00" in statement["procedure_output"], "actual window result returned")
        operate("history", {"action": "history", "account": aid})
        check("invalid money rejected", call("/api/operate", {"action": "deposit", "account": aid, "amount": "0.001"})[0] == 400, "no SQL mutation")
        code, failed = call("/api/operate", {"action": "withdraw", "account": aid, "amount": "99999999"})
        check("native business error", code == 422 and "5004" in failed["error"], "native errno visible; D4 Failed row allowed")
        (directory / "rejection.json").write_text(json.dumps(failed, indent=2), encoding="utf-8")
        operate("suspicious", {"action": "deposit", "account": aid, "amount": "6000", "channel": "Online"})
        _, state = call("/api/snapshot")
        tx = next(x for x in state["transactions"] if str(x["account_id"]) == aid and x["transaction_type"] == "Deposit" and float(x["amount"]) == 6000)
        flags = [f for f in state["flags"] if f["transaction_id"] == tx["transaction_id"]]
        check("automatic fraud integration", len(flags) > 0 and max(float(f["risk_score"]) for f in flags) == 100, "observed controlled suspicious score100; UI does not assume it")
        flag = flags[0]
        operate("review-underreview", {"action": "review", "flag": str(flag["flag_id"]), "status": "UnderReview", "manager": str(manager["employee_id"])})
        operate("review-confirmed", {"action": "review", "flag": str(flag["flag_id"]), "status": "Confirmed", "manager": str(manager["employee_id"])})
        code, rollback = call("/api/rollback", {"account": aid, "to_account": to, "amount": "1"})
        (directory / "rollback.json").write_text(json.dumps(rollback, indent=2), encoding="utf-8")
        check("real5016 atomic rollback", code == 200 and rollback["ok"] and rollback["before"] == rollback["after"], "balances/ledger/audit/flags/profile snapshot unchanged")
        _, state = call("/api/snapshot")
        check("audit observed", any(str(x["record_pk"]) == aid and x["table_name"] == "Accounts" for x in state["audit"]), "actual session audit rows")
        _, invariants = call("/api/invariants", {})
        (directory / "invariants.json").write_text(json.dumps(invariants, indent=2), encoding="utf-8")
        for inv in invariants["results"]:
            check("live invariant " + inv["invariant"], inv["status"] == "PASS" and inv["violations"] == 0, "actual reconciliation")
        check("exact six invariants", len(invariants["results"]) == 6, "I1/I1b/I2/I3/I4/I5")
        status, model = call("/api/architecture")
        check("installed schema architecture", status == 200 and len(model["tables"]) == 16 and len(model["views"]) == 3, "information_schema, real A+B")
        audit = next(t for t in model["triggers"] if t["name"] == "trg_transactions_ai_audit")
        fraud = next(t for t in model["triggers"] if t["name"] == "trg_transactions_ai_fraud_evaluate")
        check("audit before fraud", audit["ordering"] < fraud["ordering"], "installed trigger order")
        _, evidence = call("/api/evidence")
        check("measured performance evidence", len(evidence["performance"]) == 6, "six actual CSV groups; no fabricated timing")
        check("previous verification counts", any(p["name"] == "Integrated SQL" and p["pass"] == 688 and p["fail"] == 0 for p in evidence["populations"]), "loaded per-file CSV, historical not live")
        (directory / "final-snapshot.json").write_text(json.dumps(state, indent=2), encoding="utf-8")
    finally:
        (directory / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
        print("TOTAL|PASS=" + str(sum(r["status"] == "PASS" for r in results)) + "|FAIL=" + str(sum(r["status"] == "FAIL" for r in results)), flush=True)


if __name__ == "__main__":
    main()
