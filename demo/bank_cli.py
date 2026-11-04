"""Native MySQL banking CLI. No connector dependency, grants or financial DML."""
import argparse
import datetime as dt
from decimal import Decimal, InvalidOperation
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def literal(value):
    """SQL text independent of NO_BACKSLASH_ESCAPES / connection quote mode."""
    if value is None:
        return "NULL"
    if value == "":
        return "''"
    return "CONVERT(0x" + str(value).encode("utf-8").hex() + " USING utf8mb4)"


def money(value):
    try:
        number = Decimal(value)
    except InvalidOperation as exc:
        raise argparse.ArgumentTypeError("Use a decimal amount") from exc
    if not number.is_finite() or number <= 0 or number > Decimal("999999999999.99"):
        raise argparse.ArgumentTypeError("Amount must be positive and fit DECIMAL(14,2)")
    if number != number.quantize(Decimal("0.01")):
        raise argparse.ArgumentTypeError("At most two decimal places")
    return format(number, ".2f")


def rate(value):
    if value in ("0", "0.00"):
        return "0.00"
    number = money(value)
    if Decimal(number) > Decimal("999.99"):
        raise argparse.ArgumentTypeError("Rate must fit DECIMAL(5,2)")
    return number


def positive(value):
    number = int(value)
    if number < 1 or number > 2147483647:
        raise argparse.ArgumentTypeError("Use a positive INT identifier")
    return number


def date(value):
    try:
        return dt.date.fromisoformat(value).isoformat()
    except ValueError as exc:
        raise argparse.ArgumentTypeError("Use YYYY-MM-DD") from exc


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database", required=True, help="Owned disposable bank_a_ci_demo_<hex>_main only")
    p.add_argument("--config", default=os.environ.get("BANK_MYSQL_CNF"))
    p.add_argument("--mysql", default=os.environ.get("BANK_MYSQL_BIN") or shutil.which("mysql"))
    p.add_argument("--non-security-demo", action="store_true", help="Explicit privileged demonstration, never least-privilege proof")
    s = p.add_subparsers(dest="command", required=True)
    for name in ("whoami", "accounts", "history", "flags", "audit", "reconcile"):
        c = s.add_parser(name)
        if name == "history":
            c.add_argument("account", type=positive)
    c = s.add_parser("register")
    for name in ("name", "dob", "email", "phone", "address", "id-proof"):
        c.add_argument("--" + name, required=True, type=date if name == "dob" else str)
    c.add_argument("--id-type", choices=["Aadhaar", "PAN", "Passport", "DrivingLicense", "VoterID"], required=True)
    c = s.add_parser("open")
    for name in ("customer", "branch", "type"):
        c.add_argument("--" + name, required=True, type=positive)
    c.add_argument("--initial", required=True, type=money)
    c.add_argument("--number", required=True)
    c.add_argument("--employee", type=positive)
    for name in ("deposit", "withdraw", "transfer"):
        c = s.add_parser(name)
        c.add_argument("account", type=positive)
        if name == "transfer":
            c.add_argument("to_account", type=positive)
        c.add_argument("amount", type=money)
        c.add_argument("--channel", choices=["Online", "Mobile", "Branch", "ATM"], default="Online")
        for field in ("employee", "device", "location"):
            c.add_argument("--" + field, type=positive)
    c = s.add_parser("statement")
    c.add_argument("account", type=positive)
    c.add_argument("--from", dest="from_date", type=date, required=True)
    c.add_argument("--to", dest="to_date", type=date, required=True)
    c = s.add_parser("review")
    c.add_argument("flag", type=positive)
    c.add_argument("status", choices=["UnderReview", "Confirmed", "Dismissed"])
    c.add_argument("--manager", type=positive, required=True)
    c = s.add_parser("request-approval")
    c.add_argument("account", type=positive)
    c.add_argument("to_account", type=positive)
    c.add_argument("amount", type=money)
    actor = c.add_mutually_exclusive_group(required=True)
    actor.add_argument("--employee", type=positive)
    actor.add_argument("--customer", type=positive)
    c = s.add_parser("decide-approval")
    c.add_argument("approval", type=positive)
    c.add_argument("decision", choices=["Approved", "Rejected"])
    c.add_argument("--manager", type=positive, required=True)
    c = s.add_parser("loan")
    c.add_argument("customer", type=positive)
    c.add_argument("principal", type=money)
    c.add_argument("--account", type=positive)
    c.add_argument("--rate", type=rate, required=True)
    c.add_argument("--months", type=positive, required=True)
    c.add_argument("--employee", type=positive)
    return p


def query(a, sql):
    command = [a.mysql, "--defaults-extra-file=" + str(Path(a.config).resolve()),
               "--batch", "--raw", "--skip-force", "--default-character-set=utf8mb4",
               "--connect-timeout=5", "--database=" + a.database]
    # SQL is UTF-8 stdin, never shell text or password-bearing arguments.
    result = subprocess.run(command, input="SET SESSION innodb_lock_wait_timeout=5;\n" + sql,
                            text=True, encoding="utf-8", capture_output=True, timeout=30)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "MySQL failed")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return result.stdout


def command_sql(a):
    c = a.command
    if c == "whoami":
        return "SELECT USER() AS authenticated_session,CURRENT_USER() AS privilege_identity,CURRENT_ROLE() AS active_roles;"
    if c == "accounts":
        if a.non_security_demo:
            return "SELECT account_id,account_number,customer_id,branch_id,balance,status FROM Accounts ORDER BY account_id;"
        # Views remain the server's security boundary. Staff can derive only visible activity.
        return ("SELECT * FROM v_customer_account_summary ORDER BY account_id;" if a.customer_view else
                "SELECT account_id,balance_after AS last_completed_balance FROM "
                "(SELECT account_id,balance_after,ROW_NUMBER() OVER(PARTITION BY account_id ORDER BY transaction_id DESC) n "
                "FROM v_transaction_activity WHERE status='Completed') x WHERE n=1 ORDER BY account_id;")
    if c == "history":
        table = "Transactions" if a.non_security_demo else "v_transaction_activity"
        return f"SELECT * FROM {table} WHERE account_id={a.account} ORDER BY transaction_id;"
    if c == "flags":
        return "SELECT * FROM v_fraud_case_queue ORDER BY flag_id LIMIT 100;"
    if c == "audit":
        return "SELECT audit_id,table_name,record_pk,action_type,db_session_user,actor_type,performed_at FROM Audit_Log ORDER BY audit_id DESC LIMIT 50;"
    if c == "reconcile":
        return "CALL sp_reconcile_balances(NULL);"
    if c == "register":
        args = [a.name, a.dob, None, a.email, a.phone, a.address, a.id_proof, a.id_type]
        return "CALL sp_register_customer(" + ",".join(map(literal, args)) + ",@id);SELECT @id AS customer_id;"
    if c == "open":
        return f"CALL sp_open_account({a.customer},{a.branch},{a.type},{a.initial},{a.employee or 'NULL'},{literal(a.number)},@id,@number);SELECT @id AS account_id,@number AS account_number;"
    if c in ("deposit", "withdraw", "transfer"):
        tail = f"{literal(a.channel)},{a.employee or 'NULL'},{a.device or 'NULL'},{a.location or 'NULL'}"
        if c == "transfer":
            return f"CALL sp_transfer_funds({a.account},{a.to_account},{a.amount},{tail},0,@g,@d,@c);SELECT @g AS transfer_group_id,@d AS debit_txn_id,@c AS credit_txn_id;"
        return f"CALL sp_{c}({a.account},{a.amount},{tail},@id,@balance);SELECT @id AS transaction_id,@balance AS balance_after;"
    if c == "statement":
        return f"CALL sp_generate_statement({a.account},{literal(a.from_date)},{literal(a.to_date)});"
    if c == "review":
        return f"CALL sp_review_fraud_flag({a.flag},{literal(a.status)},{a.manager});SELECT 'Reviewed' AS result;"
    if c == "request-approval":
        return f"CALL sp_request_approval({a.account},{a.to_account},{a.amount},{a.employee or 'NULL'},{a.customer or 'NULL'},@id);SELECT @id AS approval_id;"
    if c == "decide-approval":
        return f"CALL sp_decide_approval({a.approval},{literal(a.decision)},{a.manager},@g);SELECT @g AS transfer_group_id;"
    if c == "loan":
        return f"CALL sp_disburse_loan({a.customer},{a.account or 'NULL'},{a.principal},{a.rate},{a.months},{a.employee or 'NULL'},@id);SELECT @id AS loan_id;"
    raise ValueError("Unknown command")


def main(argv=None):
    p = parser()
    a = p.parse_args(argv)
    if not re.fullmatch(r"bank_a_ci_demo_[a-f0-9]{12}_main", a.database):
        p.error("Only a fresh demo-owned database name is accepted; protected names are forbidden")
    if not a.config or not Path(a.config).is_file() or not a.mysql:
        p.error("Set BANK_MYSQL_CNF and BANK_MYSQL_BIN (external private option file and native client)")
    try:
        if a.non_security_demo:
            print("NON-SECURITY DEMO: privileged connection; no least-privilege claim", file=sys.stderr)
            if a.command in ("register", "open"):
                print("Use synthetic example.invalid identities and SYN- proof numbers only", file=sys.stderr)
        else:
            identity = query(a, "SELECT CURRENT_ROLE() AS active_roles;")
            # Derive capabilities from the authenticated session, never a menu role.
            if not any("bank_" + r + "_role" in identity for r in ("customer", "teller", "manager", "auditor")):
                raise RuntimeError("No recognized active banking role; use an approved mapped restricted login, or explicitly --non-security-demo")
            a.customer_view = "bank_customer_role" in identity
            print("Authenticated role mode; server grants and USER() mappings enforce access", file=sys.stderr)
        print(query(a, command_sql(a)), end="")
        return 0
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
