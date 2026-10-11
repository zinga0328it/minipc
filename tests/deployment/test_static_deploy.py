import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "deployment/static-site/deploy.py"
spec = importlib.util.spec_from_file_location("static_deploy", SCRIPT)
DEPLOY = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = DEPLOY
spec.loader.exec_module(DEPLOY)


class StaticDeployTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.source = self.root / "web"
        self.site = self.source / "demo"
        self.site.mkdir(parents=True)
        (self.site / "index.html").write_text("<h1>demo</h1>")
        (self.site / "site.css").write_text("body { color: green; }")
        (self.site / "app.js").write_text("console.log('ok')")
        (self.site / ".env").write_text("TOKEN=secret-value-123456")
        (self.site / "AGENTS.md").write_text("private instructions")
        (self.site / "backend.py").write_text("secret = 'x'")
        (self.site / "private").mkdir()
        (self.site / "private" / "index.html").write_text("must not publish")
        self.target = self.root / "www"
        self.backups = self.root / "backups"
        self.env = {**os.environ, "STATIC_DEPLOY_TEST": "1"}
        self.test_mode = patch.dict(os.environ, {"STATIC_DEPLOY_TEST": "1"})
        self.test_mode.start()
        self.addCleanup(self.test_mode.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def test_allowlist_excludes_secrets_and_private_trees(self):
        entries, excluded = DEPLOY.collect(self.site)
        self.assertEqual([e["path"] for e in entries], ["app.js", "index.html", "site.css"])
        self.assertEqual(len(excluded), 4)

    def test_symlink_is_never_published(self):
        (self.site / "leak.js").symlink_to(self.site / ".env")
        entries, excluded = DEPLOY.collect(self.site)
        self.assertNotIn("leak.js", [e["path"] for e in entries])
        self.assertIn("leak.js", excluded)

    def test_secret_like_content_is_rejected(self):
        (self.site / "leak.js").write_text("const api_token = 'abcdefghijklmnopqrstuvwxyz';")
        entries, excluded = DEPLOY.collect(self.site)
        self.assertNotIn("leak.js", [e["path"] for e in entries])
        self.assertIn("leak.js (contenuto sensibile)", excluded)

    def test_plan_hash_changes_when_content_changes(self):
        first, _ = DEPLOY.collect(self.site)
        digest = DEPLOY.manifest("demo", self.site, first)["sha256"]
        (self.site / "index.html").write_text("changed")
        second, _ = DEPLOY.collect(self.site)
        self.assertNotEqual(digest, DEPLOY.manifest("demo", self.site, second)["sha256"])

    def test_publish_requires_approved_manifest_and_rolls_back(self):
        public = self.target / "demo" / "public"
        public.mkdir(parents=True)
        (public / "old.html").write_text("old release")
        entries, _ = DEPLOY.collect(self.site)
        current = DEPLOY.manifest("demo", self.site, entries)
        backup = DEPLOY.publish(self.site, public, self.backups / "demo", entries)
        self.assertTrue((public / "index.html").exists())
        self.assertFalse((public / ".env").exists())
        self.assertFalse((public / "backend.py").exists())
        self.assertTrue((backup / "public" / "old.html").exists())
        DEPLOY.rollback(public, backup)
        self.assertEqual((public / "old.html").read_text(), "old release")
        self.assertFalse((public / "index.html").exists())
        self.assertTrue(current["sha256"])

    def test_first_release_rollback_removes_created_public(self):
        public = self.target / "demo" / "public"
        entries, _ = DEPLOY.collect(self.site)
        backup = DEPLOY.publish(self.site, public, self.backups / "demo", entries)
        DEPLOY.rollback(public, backup)
        self.assertFalse(public.exists())

    def test_cli_publish_rejects_unapproved_hash(self):
        command = [sys.executable, str(SCRIPT), "demo", "--publish", "--approve", "wrong",
                   "--source-root", str(self.source), "--target-root", str(self.target),
                   "--backup-root", str(self.backups)]
        result = subprocess.run(command, capture_output=True, text=True, env=self.env, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("hash cambiato", result.stderr)

    def test_invalid_site_names_rejected(self):
        for name in ("../etc", "UpperCase", "a/b", ".", "-bad"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                DEPLOY.valid_site(name)


if __name__ == "__main__":
    unittest.main()
