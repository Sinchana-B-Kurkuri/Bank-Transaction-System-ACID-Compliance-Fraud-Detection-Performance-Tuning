"""Input-boundary tests; runtime integration is run_demo.ps1."""
import importlib.util
from pathlib import Path
import unittest
import contextlib
import io

spec = importlib.util.spec_from_file_location("bank_cli", Path(__file__).resolve().parents[2] / "demo/bank_cli.py")
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)


class CliTests(unittest.TestCase):
    def test_decimal(self):
        self.assertEqual(cli.money("1e2"), "100.00")
        for value in ("NaN", "Infinity", "0", "-1", "0.001", "1000000000000"):
            with self.assertRaises(Exception):
                cli.money(value)

    def test_text_quoting(self):
        value = "O'Brien; DROP DATABASE bank_txn; --\n☃"
        encoded = cli.literal(value)
        self.assertNotIn("DROP", encoded)
        self.assertEqual(bytes.fromhex(encoded.split("0x")[1].split()[0]).decode(), value)
        self.assertEqual(cli.literal(None), "NULL")

    def test_only_public_mutation(self):
        p = cli.parser()
        a = p.parse_args(["--database", "bank_a_ci_demo_123456abcdef_main", "transfer", "1", "2", "10"])
        self.assertIn("CALL sp_transfer_funds(1,2,10.00", cli.command_sql(a))
        self.assertNotIn("sp_internal", cli.command_sql(a))
        self.assertIn("NULL,0,@g", cli.command_sql(a))

    def test_protected_targets(self):
        for database in ("bank_txn", "bank_txn_scratch", "bank_lab", "bank_a_ci_demo_bad_main"):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                cli.main(["--database", database, "whoami"])

    def test_dates(self):
        self.assertEqual(cli.date("2026-10-20"), "2026-10-20")
        with self.assertRaises(Exception):
            cli.date("2026-02-31")

    def test_rate(self):
        self.assertEqual(cli.rate("0"), "0.00")
        self.assertEqual(cli.rate("8.5"), "8.50")
        with self.assertRaises(Exception):
            cli.rate("1000")


if __name__ == "__main__":
    unittest.main()
