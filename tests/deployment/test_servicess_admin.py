import importlib.util
import os
import pwd
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "admin/servicess-admin.py"
spec = importlib.util.spec_from_file_location("servicess_admin", SCRIPT)
ADMIN = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = ADMIN
spec.loader.exec_module(ADMIN)
TEMPLATE = Path(__file__).resolve().parents[2] / "deployment/systemd/rust-api.service.template"


class ServiceUnitTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        project = self.home / "apps/demo/api/target/release"
        project.mkdir(parents=True)
        self.binary = project / "demo-api"
        self.binary.write_text("binary-placeholder")
        self.binary.chmod(0o755)
        secrets = self.home / "apps/demo/secrets"
        secrets.mkdir()
        self.env = secrets / "runtime.env"
        self.env.write_text("PORT=3000\n")
        self.env.chmod(0o600)
        self.user = pwd.getpwuid(os.getuid()).pw_name

    def tearDown(self):
        self.tmp.cleanup()

    def test_unit_renders_safe_paths_and_hardening(self):
        unit = ADMIN.render_unit("demo", self.user, self.home, TEMPLATE)
        self.assertIn(f"User={self.user}\n", unit)
        self.assertIn(f"ExecStart={self.binary}\n", unit)
        self.assertIn("NoNewPrivileges=true", unit)
        self.assertIn("ProtectSystem=strict", unit)
        self.assertIn("EnvironmentFile=-", unit)
        self.assertNotIn("{{", unit)

    def test_unit_rejects_missing_binary_and_world_readable_secrets(self):
        self.binary.unlink()
        with self.assertRaises(ValueError):
            ADMIN.render_unit("demo", self.user, self.home, TEMPLATE)
        self.binary.write_text("binary-placeholder")
        self.binary.chmod(0o755)
        self.env.chmod(0o644)
        with self.assertRaises(ValueError):
            ADMIN.render_unit("demo", self.user, self.home, TEMPLATE)

    def test_unit_rejects_invalid_project_slug_and_home_path(self):
        with self.assertRaises(ValueError):
            ADMIN.render_unit("../bad", self.user, self.home, TEMPLATE)
        with self.assertRaises(ValueError):
            ADMIN.render_unit("demo", self.user, Path("/tmp/name\nExecStart=/bin/sh"), TEMPLATE)


if __name__ == "__main__":
    unittest.main()
