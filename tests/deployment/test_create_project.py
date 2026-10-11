import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "tools/create-project.py"
spec = importlib.util.spec_from_file_location("create_project", SCRIPT)
CREATE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CREATE)


class CreateProjectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_creates_isolated_rust_and_static_git_repositories(self):
        app, web = CREATE.create("contabilita", "conti-online", self.home)
        self.assertTrue((app / "api/Cargo.toml").is_file())
        self.assertTrue((app / "modules/common/src/lib.rs").is_file())
        self.assertTrue((app / "secrets/README.md").is_file())
        self.assertTrue((web / "index.html").is_file())
        self.assertFalse((web / "api").exists())
        self.assertEqual((app / "api/Cargo.toml").stat().st_mode & 0o777, 0o600)
        self.assertEqual((app / "secrets").stat().st_mode & 0o777, 0o700)
        self.assertEqual((web / "index.html").stat().st_mode & 0o777, 0o644)
        self.assertTrue((app / ".git").is_dir())
        self.assertTrue((web / ".git").is_dir())
        self.assertIn("contabilita-api", (app / "api/Cargo.toml").read_text())
        self.assertIn("conti-online", (web / "index.html").read_text())

    def test_never_overwrites_either_existing_target(self):
        apps = self.home / "apps"
        web = self.home / "web"
        apps.mkdir()
        web.mkdir()
        existing = apps / "contabilita"
        existing.mkdir()
        (existing / "keep").write_text("preserve")
        with self.assertRaises(FileExistsError):
            CREATE.create("contabilita", "conti-online", self.home)
        self.assertEqual((existing / "keep").read_text(), "preserve")
        self.assertFalse((web / "conti-online").exists())

    def test_rejects_invalid_slugs(self):
        for value in ("../escape", "Upper", "x/y", "-bad", "bad-"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                CREATE.valid_slug(value)

    def test_rejects_symlinked_web_root(self):
        (self.home / "apps").mkdir()
        other = self.home / "external"
        other.mkdir()
        (self.home / "web").symlink_to(other, target_is_directory=True)
        with self.assertRaises(ValueError):
            CREATE.create("app", "site", self.home)


if __name__ == "__main__":
    unittest.main()
