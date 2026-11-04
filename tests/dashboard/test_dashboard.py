import json
from pathlib import Path
import sys
import threading
import unittest
from urllib import request, error

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "demo"))
import dashboard


class FakeApp:
    token = "unit-test-token"
    lock = threading.Lock()
    args = type("Args", (), {"database": "bank_a_ci_demo_123456abcdef_main"})()
    evidence = {"label": "unit fixture"}
    calls = 0

    def snapshot(self):
        return {"fixture": True}

    def architecture(self):
        return {"fixture": True}

    def operation(self, data):
        self.calls += 1
        return {"ok": True}


class HttpSafetyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = FakeApp()
        cls.server = dashboard.ThreadingHTTPServer(("127.0.0.1", 0), dashboard.make_handler(cls.app))
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def fetch(self, path, data=None, headers=None):
        r = request.Request(self.url + path, data=json.dumps(data).encode() if data is not None else None, headers=headers or {})
        try:
            with request.urlopen(r, timeout=5) as response:
                return response.status, response.read(), response.headers
        except error.HTTPError as e:
            return e.code, e.read(), e.headers

    def test_html_shell(self):
        status, body, headers = self.fetch("/")
        self.assertEqual(status, 200)
        self.assertIn(b"NON-SECURITY DEMO", body)
        self.assertIn(b"guide-next", body)
        self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])

    def test_csrf_rejected(self):
        before = self.app.calls
        self.assertEqual(self.fetch("/api/operate", {"action": "deposit"})[0], 403)
        self.assertEqual(self.app.calls, before)

    def test_foreign_origin_rejected(self):
        self.assertEqual(self.fetch("/api/operate", {}, {"Origin": "https://evil.invalid", "X-CSRF-Token": self.app.token})[0], 403)

    def test_bad_host_rejected(self):
        self.assertEqual(self.fetch("/api/bootstrap", headers={"Host": "evil.invalid"})[0], 403)

    def test_no_sql_endpoint(self):
        self.assertEqual(self.fetch("/api/sql")[0], 404)
        self.assertEqual(self.fetch("/../../README.md")[0], 404)

    def test_json_boundary(self):
        self.assertEqual(self.fetch("/api/operate", [], {"Origin": self.url, "X-CSRF-Token": self.app.token, "Content-Type": "application/json"})[0], 400)

    def test_authorized_post(self):
        self.assertEqual(self.fetch("/api/operate", {"action": "deposit"}, {"Origin": self.url, "X-CSRF-Token": self.app.token, "Content-Type": "application/json"})[0], 200)

    def test_cleaned_session_refused_before_sql(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / "session.json"
            p.write_text(json.dumps({"Prefix": "bank_a_ci_demo_123456abcdef", "Database": "bank_a_ci_demo_123456abcdef_main", "Status": "cleaned"}))
            with self.assertRaises(ValueError):
                dashboard.Dashboard(p)

    def test_protected_session_refused(self):
        import tempfile
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / "session.json"
            p.write_text(json.dumps({"Prefix": "bank_txn", "Database": "bank_txn", "Status": "ready"}))
            with self.assertRaises(ValueError):
                dashboard.Dashboard(p)


class StartupPathTests(unittest.TestCase):
    def make_session(self, folder):
        p = Path(folder) / "session.json"
        p.write_text(json.dumps({"Prefix": "bank_a_ci_demo_123456abcdef", "Database": "bank_a_ci_demo_123456abcdef_main", "Status": "ready", "Owner": "a" * 32}))
        return p

    def test_mysql_directory_resolved_without_changing_environment(self):
        import os
        import tempfile
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as folder:
            executable = Path(folder) / ("mysql.exe" if os.name == "nt" else "mysql")
            executable.touch()
            config = Path(folder) / "external.cnf"
            config.touch()
            with patch.dict(os.environ, {"BANK_MYSQL_BIN": folder, "BANK_MYSQL_CNF": str(config)}), patch.object(dashboard.Dashboard, "sql", return_value="a" * 32):
                app = dashboard.Dashboard(self.make_session(folder))
                self.assertEqual(app.args.mysql, str(executable))
                self.assertEqual(os.environ["BANK_MYSQL_BIN"], folder)

    def test_missing_mysql_executable_refused_before_sql(self):
        import os
        import tempfile
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / "external.cnf"
            config.touch()
            with patch.dict(os.environ, {"BANK_MYSQL_BIN": folder, "BANK_MYSQL_CNF": str(config)}), patch.object(dashboard.Dashboard, "sql") as sql:
                with self.assertRaisesRegex(ValueError, "BANK_MYSQL_BIN"):
                    dashboard.Dashboard(self.make_session(folder))
                sql.assert_not_called()


if __name__ == "__main__":
    unittest.main()
