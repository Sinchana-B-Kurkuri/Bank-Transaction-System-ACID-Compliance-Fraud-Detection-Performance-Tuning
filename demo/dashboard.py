"""Offline localhost dashboard; existing native MySQL/public banking API adapter."""
import argparse
import csv
import datetime as dt
import io
import json
import os
from pathlib import Path
import re
import secrets
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from types import SimpleNamespace
import bank_cli as bank

ROOT = Path(__file__).resolve().parents[1]
STATIC = Path(__file__).resolve().parent / "web"
VERIFIED = ROOT / "evidence/reviews/final-demo/runs/workflow-20261020-190002-497-51085f9cf61f46d4a5bbee110928b886"
REGRESSION = ROOT / "evidence/reviews/final-demo/runs/isolated-20261020-185810-465-c1fcdcc71d0446e5a090e67884cd375f"


def verified_evidence():
    """Pinned successful historical run, never relabel a new/failed run as success."""
    def read(name):
        p = VERIFIED / name
        return p.read_text(encoding="utf-8-sig") if p.exists() else "Evidence file unavailable in this checkout"
    def csv_read(name):
        p = VERIFIED / name
        return list(csv.DictReader(io.StringIO(p.read_text(encoding="utf-8-sig")))) if p.exists() else []
    populations = []
    p = REGRESSION / "test-populations.csv"
    if p.exists():
        rows = list(csv.DictReader(io.StringIO(p.read_text(encoding="utf-8-sig"))))
        for mode in ("Standalone", "Integrated"):
            chosen = [r for r in rows if re.match(mode + r"-(schema|functions|triggers|procedures|invariants|integration)-", r["Name"])]
            populations.append({"name": mode + " SQL", "pass": sum(int(r["Pass"]) for r in chosen), "fail": sum(int(r["Fail"]) for r in chosen)})
    summary = read("summary.txt")
    match = re.search(r"TOTAL\|PASS=(\d+)\|FAIL=(\d+)", summary)
    if match:
        populations.append({"name": "CLI workflow", "pass": int(match[1]), "fail": int(match[2])})
    seed_path = ROOT / "evidence/error1222/20261020-185957-390-838bfda4c2ea445ba08d315bebec081c/summary.txt"
    if seed_path.exists():
        m = re.search(r"TOTAL\|PASS=(\d+)\|FAIL=(\d+)", seed_path.read_text(encoding="utf-8-sig"))
        if m:
            populations.append({"name": "ERROR 1222 regression", "pass": int(m[1]), "fail": int(m[2])})
    isolation = []
    for level in ("READ_UNCOMMITTED", "READ_COMMITTED", "REPEATABLE_READ", "SERIALIZABLE"):
        isolation.append({"level": level.replace("_", " "), "reader": read(f"isolation-{level}/reader.stdout.txt"), "error": read(f"isolation-{level}/reader.stderr.txt")})
    return {"label": "Previously Verified Experiment — 2026-10-20", "source": str(VERIFIED.relative_to(ROOT)).replace("\\", "/"),
            "performance": csv_read("performance-summary.csv"), "populations": populations,
            "dataset": read("benchmark-row-counts.txt"), "environment": read("environment.txt"),
            "hardware": read("hardware-verified.json"), "isolation": isolation,
            "deadlock": read("deadlock/naive-0.stderr.txt") + read("deadlock/naive-1.stderr.txt"),
            "retry": read("deadlock/retry-rows.txt"), "invariants": read("final-invariants.txt"),
            "fraud": read("fraud-observations.txt"), "checks": read("checks.txt"),
            "plans": [{"query": q, "baseline": read(f"Baseline-plan-{q}.txt"), "optimized": read(f"Optimized-plan-{q}.txt")} for q in range(3)]}


class Dashboard:
    def __init__(self, session_file):
        state = json.loads(Path(session_file).read_text(encoding="utf-8-sig"))
        prefix = state.get("Prefix", "")
        if not re.fullmatch(r"bank_a_ci_demo_[a-f0-9]{12}", prefix) or state.get("Database") != prefix + "_main" or state.get("Status") != "ready":
            raise ValueError("Dashboard requires an active, valid owned demo session")
        if not re.fullmatch(r"[a-f0-9]{32}", state.get("Owner", "")):
            raise ValueError("Invalid owner token")
        self.args = SimpleNamespace(database=state["Database"], config=os.environ.get("BANK_MYSQL_CNF"), mysql=os.environ.get("BANK_MYSQL_BIN"), non_security_demo=True)
        if not self.args.config or not Path(self.args.config).is_file() or not self.args.mysql:
            raise ValueError("Set BANK_MYSQL_CNF and BANK_MYSQL_BIN externally")
        actual = self.sql("SELECT owner_token FROM _a_test_owner;").strip().splitlines()[-1]
        if not secrets.compare_digest(actual, state["Owner"]):
            raise ValueError("Database ownership mismatch; dashboard refused")
        self.token = secrets.token_urlsafe(32)
        self.lock = threading.Lock()
        self.evidence = verified_evidence()

    def sql(self, sql):
        return bank.query(self.args, sql)

    def rows(self, select, fields):
        expr = ",".join(bank.literal(f) + ",x.`" + f + "`" for f in fields)
        raw = self.sql("SELECT JSON_OBJECT(" + expr + ") AS row_json FROM (" + select + ") x;")
        return [json.loads(line) for line in raw.splitlines()[1:] if line.strip()]

    def effects(self):
        return {"balances": self.rows("SELECT account_id,balance,status FROM Accounts ORDER BY account_id", ["account_id", "balance", "status"]),
                "counts": self.rows("SELECT (SELECT COUNT(*) FROM Transactions) ledger,(SELECT COUNT(*) FROM Audit_Log) audit,(SELECT COUNT(*) FROM Fraud_Flags) flags,(SELECT COALESCE(SUM(risk_score),0) FROM Account_Risk_Profile) risk_sum", ["ledger", "audit", "flags", "risk_sum"])[0]}

    def snapshot(self):
        return {
            "identity": self.rows("SELECT USER() session_user,CURRENT_ROLE() active_roles,VERSION() version,NOW() measured_at", ["session_user", "active_roles", "version", "measured_at"])[0],
            "stats": self.rows("SELECT (SELECT COUNT(*) FROM Customers) customers,(SELECT COUNT(*) FROM Accounts) accounts,(SELECT COUNT(*) FROM Accounts WHERE status='Active') active,(SELECT COUNT(*) FROM Accounts WHERE status='Frozen') frozen,(SELECT COUNT(*) FROM Transactions WHERE status='Completed') completed,(SELECT COUNT(*) FROM Fraud_Flags) flags,(SELECT COUNT(*) FROM Fraud_Flags WHERE flag_status='Open') open_cases,(SELECT COALESCE(SUM(balance),0) FROM Accounts) total_balance", ["customers", "accounts", "active", "frozen", "completed", "flags", "open_cases", "total_balance"])[0],
            "customers": self.rows("SELECT customer_id,full_name,email,kyc_status,is_active FROM Customers ORDER BY customer_id", ["customer_id", "full_name", "email", "kyc_status", "is_active"]),
            "accounts": self.rows("SELECT a.account_id,a.account_number,a.customer_id,a.branch_id,a.account_type_id,a.balance,a.status,COALESCE(r.risk_score,0) risk_score,COALESCE(r.risk_level,'Low') risk_level FROM Accounts a LEFT JOIN Account_Risk_Profile r USING(account_id) ORDER BY account_id", ["account_id", "account_number", "customer_id", "branch_id", "account_type_id", "balance", "status", "risk_score", "risk_level"]),
            "branches": self.rows("SELECT branch_id,branch_name FROM Branches ORDER BY branch_id", ["branch_id", "branch_name"]),
            "types": self.rows("SELECT account_type_id,type_name,min_balance FROM Account_Types ORDER BY account_type_id", ["account_type_id", "type_name", "min_balance"]),
            "employees": self.rows("SELECT employee_id,branch_id,full_name,role FROM Employees WHERE is_active ORDER BY employee_id", ["employee_id", "branch_id", "full_name", "role"]),
            "devices": self.rows("SELECT device_id,customer_id,is_trusted FROM Devices ORDER BY device_id", ["device_id", "customer_id", "is_trusted"]),
            "transactions": self.rows("SELECT transaction_id,account_id,related_account_id,transfer_group_id,transaction_type,amount,balance_after,channel,status,transaction_timestamp,device_id FROM Transactions ORDER BY transaction_id DESC LIMIT 150", ["transaction_id", "account_id", "related_account_id", "transfer_group_id", "transaction_type", "amount", "balance_after", "channel", "status", "transaction_timestamp", "device_id"]),
            "flags": self.rows("SELECT f.flag_id,f.transaction_id,t.account_id,r.rule_code,r.weight,f.risk_score,f.flag_status,f.reviewed_by,f.evidence FROM Fraud_Flags f JOIN Fraud_Rules r USING(rule_id) JOIN Transactions t USING(transaction_id) ORDER BY f.flag_id DESC LIMIT 150", ["flag_id", "transaction_id", "account_id", "rule_code", "weight", "risk_score", "flag_status", "reviewed_by", "evidence"]),
            "rules": self.rows("SELECT rule_id,rule_code,description,weight,param_json,is_active FROM Fraud_Rules ORDER BY rule_id", ["rule_id", "rule_code", "description", "weight", "param_json", "is_active"]),
            "audit": self.rows("SELECT audit_id,table_name,record_pk,action_type,old_value,new_value,db_session_user,actor_type,performed_at FROM Audit_Log ORDER BY audit_id DESC LIMIT 100", ["audit_id", "table_name", "record_pk", "action_type", "old_value", "new_value", "db_session_user", "actor_type", "performed_at"]),
            "activity": self.rows("SELECT DATE(transaction_timestamp) day,COUNT(*) count FROM Transactions WHERE status='Completed' GROUP BY DATE(transaction_timestamp) ORDER BY day", ["day", "count"]),
            "distribution": self.rows("SELECT risk_level,COUNT(*) count FROM Account_Risk_Profile GROUP BY risk_level", ["risk_level", "count"]),
            "transaction_types": self.rows("SELECT transaction_type,COUNT(*) count FROM Transactions GROUP BY transaction_type", ["transaction_type", "count"]),
            "watermark": self.rows("SELECT db_name,event_type,created_at FROM `" + self.args.database.replace("_main", "_lab") + "`.Experiment_Log WHERE db_name=DATABASE() AND event_type='AUDIT_TRIGGERS_INSTALLED' ORDER BY log_id DESC LIMIT 1", ["db_name", "event_type", "created_at"]),
        }

    def architecture(self):
        return {"tables": self.rows("SELECT TABLE_NAME table_name,ENGINE engine FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_TYPE='BASE TABLE' AND TABLE_NAME<>'_a_test_owner' ORDER BY TABLE_NAME", ["table_name", "engine"]),
                "routines": self.rows("SELECT ROUTINE_NAME name,ROUTINE_TYPE type,SECURITY_TYPE security FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=DATABASE() ORDER BY ROUTINE_TYPE,ROUTINE_NAME", ["name", "type", "security"]),
                "triggers": self.rows("SELECT TRIGGER_NAME name,EVENT_OBJECT_TABLE target,EVENT_MANIPULATION event,ACTION_TIMING timing,ACTION_ORDER ordering FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=DATABASE() ORDER BY EVENT_OBJECT_TABLE,EVENT_MANIPULATION,ACTION_TIMING,ACTION_ORDER", ["name", "target", "event", "timing", "ordering"]),
                "views": self.rows("SELECT TABLE_NAME name,SECURITY_TYPE security FROM information_schema.VIEWS WHERE TABLE_SCHEMA=DATABASE() ORDER BY TABLE_NAME", ["name", "security"]),
                "relationships": self.rows("SELECT TABLE_NAME child,COLUMN_NAME column_name,REFERENCED_TABLE_NAME parent,REFERENCED_COLUMN_NAME parent_column FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=DATABASE() AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME,COLUMN_NAME", ["child", "column_name", "parent", "parent_column"]),
                "indexes": self.rows("SELECT TABLE_NAME table_name,INDEX_NAME index_name,COLUMN_NAME column_name,NON_UNIQUE non_unique FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME<>'_a_test_owner' ORDER BY TABLE_NAME,INDEX_NAME,SEQ_IN_INDEX", ["table_name", "index_name", "column_name", "non_unique"]),
                "durability": self.rows("SELECT @@innodb_flush_log_at_trx_commit flush_at_commit,@@sync_binlog sync_binlog,@@log_bin log_bin,@@transaction_isolation isolation_level", ["flush_at_commit", "sync_binlog", "log_bin", "isolation_level"])[0]}

    def operation(self, data):
        action = data.get("action")
        allowed = {
            "register": ([], ["name", "dob", "email", "phone", "address", "id-proof", "id-type"]),
            "open": ([], ["customer", "branch", "type", "initial", "number", "employee"]),
            "deposit": (["account", "amount"], ["channel", "employee", "device", "location"]),
            "withdraw": (["account", "amount"], ["channel", "employee", "device", "location"]),
            "transfer": (["account", "to_account", "amount"], ["channel", "employee", "device", "location"]),
            "statement": (["account"], ["from", "to"]), "history": (["account"], []),
            "review": (["flag", "status"], ["manager"]),
        }
        if action not in allowed:
            raise ValueError("Operation is not an exposed public dashboard action")
        positional, optional = allowed[action]
        if set(data) - set(positional + optional + ["action"]):
            raise ValueError("Unexpected operation field")
        if any(not isinstance(v, str) or len(v) > 250 for k, v in data.items() if k != "action"):
            raise ValueError("Use short text/number form fields")
        if action == "register" and (not data.get("email", "").endswith("@example.invalid") or not data.get("id-proof", "").startswith("SYN-")):
            raise ValueError("Demo accepts synthetic example.invalid emails and SYN- proof numbers only")
        argv = ["--database", self.args.database, "--non-security-demo", action]
        argv += [data.get(k, "") for k in positional]
        for key in optional:
            if data.get(key):
                argv.append("--" + key + "=" + data[key])
        try:
            with io.StringIO() as sink:
                import contextlib
                with contextlib.redirect_stderr(sink):
                    args = bank.parser().parse_args(argv)
        except SystemExit as exc:
            raise ValueError("Invalid or missing IDs, amounts, dates or required fields") from exc
        before = self.effects()
        try:
            result = self.sql(bank.command_sql(args))
            return {"ok": True, "procedure_output": result, "before": before, "after": self.effects()}
        except RuntimeError as exc:
            return {"ok": False, "error": str(exc), "before": before, "after": self.effects()}

    def rollback(self, data):
        if set(data) != {"account", "to_account", "amount"}:
            raise ValueError("Rollback requires account, to_account and amount only")
        a, b = bank.positive(data["account"]), bank.positive(data["to_account"])
        amount = bank.money(data["amount"])
        before = self.effects()
        error = "No failure observed"
        try:
            self.sql(f"CALL sp_transfer_funds({a},{b},{amount},'Online',NULL,NULL,NULL,1,@g,@d,@c);")
        except RuntimeError as exc:
            error = str(exc)
        after = self.effects()
        return {"ok": "5016" in error and before == after, "observed_error": error, "before": before, "after": after,
                "meaning": "Only expected5016 plus identical snapshots proves this atomic rollback probe"}

    def invariants(self):
        raw = self.sql("CALL sp_reconcile_balances(NULL);SELECT @reconcile_results AS row_json;")
        for line in reversed(raw.splitlines()):
            if line.startswith("["):
                return json.loads(line)
        raise RuntimeError("Reconciliation returned no invariant JSON")


def make_handler(app):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            print("HTTP", self.command, self.path.split("?")[0])

        def reply(self, status, payload, content_type="application/json; charset=utf-8"):
            if isinstance(payload, (dict, list)):
                payload = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            if isinstance(payload, str):
                payload = payload.encode("utf-8")
            self.send_response(status)
            for k, v in {"Content-Type": content_type, "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", "X-Frame-Options": "DENY", "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"}.items():
                self.send_header(k, v)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def valid_host(self):
            return self.headers.get("Host") == f"127.0.0.1:{self.server.server_port}"

        def do_GET(self):
            if not self.valid_host():
                return self.reply(403, {"error": "Local host required"})
            paths = {"/": ("index.html", "text/html; charset=utf-8"), "/app.js": ("app.js", "text/javascript; charset=utf-8"), "/style.css": ("style.css", "text/css; charset=utf-8")}
            try:
                if self.path in paths:
                    path, kind = paths[self.path]
                    return self.reply(200, (STATIC / path).read_bytes(), kind)
                if self.path == "/api/bootstrap":
                    return self.reply(200, {"csrf": app.token, "mode": "NON-SECURITY DEMO", "database": app.args.database})
                with app.lock:
                    routes = {"/api/snapshot": app.snapshot, "/api/architecture": app.architecture, "/api/evidence": lambda: app.evidence}
                    if self.path not in routes:
                        return self.reply(404, {"error": "Unknown resource"})
                    return self.reply(200, routes[self.path]())
            except Exception as exc:
                return self.reply(500, {"error": str(exc)})

        def do_POST(self):
            origin = f"http://127.0.0.1:{self.server.server_port}"
            if not self.valid_host() or self.headers.get("Origin") != origin or not secrets.compare_digest(self.headers.get("X-CSRF-Token", ""), app.token):
                return self.reply(403, {"error": "Invalid local origin or CSRF token"})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if length < 2 or length > 16384 or self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                    return self.reply(400, {"error": "Small JSON request required"})
                data = json.loads(self.rfile.read(length))
                if not isinstance(data, dict):
                    raise ValueError("JSON object required")
                with app.lock:
                    if self.path == "/api/operate":
                        result = app.operation(data)
                    elif self.path == "/api/rollback":
                        result = app.rollback(data)
                    elif self.path == "/api/invariants" and not data:
                        result = {"results": app.invariants()}
                    else:
                        return self.reply(404, {"error": "Unknown action"})
                    return self.reply(200 if result.get("ok", True) else 422, result)
            except (ValueError, TypeError, argparse.ArgumentTypeError) as exc:
                return self.reply(400, {"error": str(exc)})
            except Exception as exc:
                return self.reply(500, {"error": str(exc)})
    return Handler


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--session", required=True)
    p.add_argument("--port", type=int, default=5000)
    a = p.parse_args()
    if not 1024 <= a.port <= 65535:
        p.error("Choose a local unprivileged port")
    app = Dashboard(a.session)
    server = ThreadingHTTPServer(("127.0.0.1", a.port), make_handler(app))
    print(f"DASHBOARD READY http://127.0.0.1:{a.port} — NON-SECURITY DEMO", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
