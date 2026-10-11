#!/usr/bin/env python3
"""Allowlist-based static publication. Source only: not installed or run on /var."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pwd
import re
import shutil
import stat
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SITE_RE = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
ALLOWED = {
    ".html", ".htm", ".css", ".js", ".mjs", ".png", ".jpg", ".jpeg",
    ".gif", ".webp", ".avif", ".ico", ".woff", ".woff2", ".ttf",
}
DENIED_PARTS = {"private", "secrets", "secret", "data", "database", "backups", "node_modules"}
DENIED_NAMES = {"agents.md", "id_rsa", "id_ed25519", "authorized_keys", "credentials"}
SECRET_PATTERNS = (
    re.compile(rb"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(rb"(?i)(?:api[_-]?key|token|password|secret)\s*[:=]\s*[^\s<>]{12,}"),
    re.compile(rb"(?i)authorization\s*:\s*bearer\s+\S{16,}"),
    re.compile(rb"(?:gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{24,})"),
)


def default_source_root() -> Path:
    if os.geteuid() == 0:
        sudo_user = os.environ.get("SUDO_USER")
        if not sudo_user or sudo_user == "root":
            raise PermissionError("publish root richiede un utente SUDO_USER non-root")
        user_home = Path(pwd.getpwnam(sudo_user).pw_dir)
    else:
        user_home = Path.home()
    return user_home / "web"


def valid_site(site: str) -> None:
    if not SITE_RE.fullmatch(site):
        raise ValueError("nome sito non valido")


def check_path_ancestors(path: Path, root_owned: bool = False) -> None:
    absolute = path.absolute()
    for parent in reversed((absolute, *absolute.parents)):
        if not parent.exists() and not parent.is_symlink():
            continue
        st = parent.lstat()
        if stat.S_ISLNK(st.st_mode):
            raise ValueError(f"symlink nel percorso: {parent}")
        if root_owned and (st.st_uid != 0 or stat.S_IMODE(st.st_mode) & 0o022):
            raise ValueError(f"percorso non protetto da root: {parent}")


def collect(source: Path) -> tuple[list[dict], list[str]]:
    check_path_ancestors(source)
    if source.is_symlink() or not source.is_dir():
        raise ValueError("sorgente assente o symlink")
    entries: list[dict] = []
    excluded: list[str] = []
    for root, dirs, files in os.walk(source, followlinks=False):
        base = Path(root)
        kept = []
        for d in sorted(dirs):
            p = base / d
            rel = p.relative_to(source)
            if d.startswith(".") or d.lower() in DENIED_PARTS or p.is_symlink():
                excluded.append(rel.as_posix() + "/")
            else:
                kept.append(d)
        dirs[:] = kept
        for name in sorted(files):
            p = base / name
            rel = p.relative_to(source)
            low = name.lower()
            try:
                st = p.lstat()
            except FileNotFoundError:
                continue
            if (name.startswith(".") or any(part.startswith(".") for part in rel.parts)
                    or any(part.lower() in DENIED_PARTS for part in rel.parts)
                    or low in DENIED_NAMES or low == "agents.md"
                    or p.is_symlink() or not stat.S_ISREG(st.st_mode) or st.st_nlink != 1
                    or p.suffix.lower() not in ALLOWED):
                excluded.append(rel.as_posix())
                continue
            fd = os.open(p, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
            with os.fdopen(fd, "rb") as f:
                data = f.read()
            if any(pattern.search(data) for pattern in SECRET_PATTERNS):
                excluded.append(rel.as_posix() + " (contenuto sensibile)" )
                continue
            entries.append({
                "path": rel.as_posix(),
                "size": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
            })
    entries.sort(key=lambda item: item["path"])
    return entries, excluded


def manifest(site: str, source: Path, entries: list[dict]) -> dict:
    body = {"site": site, "source": str(source), "files": entries}
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    return {**body, "sha256": hashlib.sha256(canonical).hexdigest()}


def ensure_plain_tree(path: Path) -> None:
    if path.is_symlink():
        raise ValueError(f"destinazione symlink rifiutata: {path}")
    if path.exists():
        for root, dirs, files in os.walk(path, followlinks=False):
            for name in dirs + files:
                item = Path(root) / name
                if item.is_symlink():
                    raise ValueError(f"symlink nella destinazione: {item}")


def ensure_root_destination(path: Path) -> None:
    check_path_ancestors(path.parent, root_owned=os.geteuid() == 0)


def publish(source: Path, destination: Path, backup_root: Path, entries: list[dict]) -> Path:
    test_mode = os.environ.get("STATIC_DEPLOY_TEST") == "1" and os.geteuid() != 0
    if not test_mode and os.geteuid() != 0:
        raise PermissionError("publish richiede l'integrazione con il deploy privilegiato")
    ensure_plain_tree(destination)
    ensure_root_destination(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    backup_root.mkdir(parents=True, exist_ok=True)
    check_path_ancestors(backup_root, root_owned=not test_mode)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = backup_root / f"{stamp}-{os.getpid()}"
    stage = Path(tempfile.mkdtemp(prefix=".public-stage-", dir=destination.parent))
    stage.chmod(0o755)
    old = destination.parent / f".public-old-{os.getpid()}"
    moved_old = False
    try:
        for item in entries:
            rel = Path(item["path"])
            src = source / rel
            st = src.lstat()
            if src.is_symlink() or not stat.S_ISREG(st.st_mode):
                raise ValueError(f"sorgente cambiata dopo manifest: {rel}")
            fd = os.open(src, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
            with os.fdopen(fd, "rb") as f:
                data = f.read()
            if len(data) != item["size"] or hashlib.sha256(data).hexdigest() != item["sha256"]:
                raise ValueError(f"hash sorgente cambiato dopo manifest: {rel}")
            out = stage / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(data)
            out.chmod(0o644)
        if destination.exists():
            backup.mkdir(mode=0o700)
            shutil.copytree(destination, backup / "public")
            (backup / "state").write_text("present\n")
            os.replace(destination, old)
            moved_old = True
        else:
            backup.mkdir(mode=0o700)
            (backup / "state").write_text("absent\n")
        os.replace(stage, destination)
        if moved_old:
            shutil.rmtree(old)
        return backup
    except Exception:
        shutil.rmtree(stage, ignore_errors=True)
        if moved_old and old.exists() and not destination.exists():
            os.replace(old, destination)
        raise


def rollback(destination: Path, backup: Path) -> None:
    if os.geteuid() != 0 and os.environ.get("STATIC_DEPLOY_TEST") != "1":
        raise PermissionError("rollback richiede l'integrazione con il deploy privilegiato")
    saved = backup / "public"
    state = backup / "state"
    if backup.is_symlink() or not backup.is_dir() or not state.is_file() or state.is_symlink():
        raise ValueError("backup non valido")
    ensure_plain_tree(destination)
    ensure_root_destination(destination)
    test_mode = os.environ.get("STATIC_DEPLOY_TEST") == "1" and os.geteuid() != 0
    check_path_ancestors(backup, root_owned=not test_mode)
    previous = state.read_text().strip()
    if previous not in {"present", "absent"}:
        raise ValueError("stato backup non valido")
    if previous == "present":
        if not saved.is_dir() or saved.is_symlink():
            raise ValueError("contenuto backup assente")
        ensure_plain_tree(saved)
    destination.parent.mkdir(parents=True, exist_ok=True)
    old = destination.parent / f".public-old-{os.getpid()}"
    moved_old = False
    try:
        if destination.exists():
            os.replace(destination, old)
            moved_old = True
        if previous == "present":
            stage = Path(tempfile.mkdtemp(prefix=".public-rollback-", dir=destination.parent))
            shutil.rmtree(stage)
            shutil.copytree(saved, stage)
            os.replace(stage, destination)
        if moved_old:
            shutil.rmtree(old)
    except Exception:
        if "stage" in locals():
            shutil.rmtree(stage, ignore_errors=True)
        if moved_old and old.exists() and not destination.exists():
            os.replace(old, destination)
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("site")
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--plan", action="store_true")
    modes.add_argument("--publish", action="store_true")
    modes.add_argument("--rollback", metavar="BACKUP_ID")
    parser.add_argument("--approve", help="sha256 del manifest dopo revisione")
    expected_source_root = default_source_root()
    parser.add_argument("--source-root", type=Path, default=expected_source_root)
    parser.add_argument("--target-root", type=Path, default=Path("/var/www"))
    parser.add_argument("--backup-root", type=Path, default=Path("/var/backups/web-deploy"))
    args = parser.parse_args()
    try:
        valid_site(args.site)
        if os.geteuid() == 0 and (
            args.source_root != expected_source_root
            or args.target_root != Path("/var/www")
            or args.backup_root != Path("/var/backups/web-deploy")
        ):
            raise ValueError("root non accetta root di test o percorsi personalizzati")
        if args.rollback:
            if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z-[0-9]+", args.rollback):
                raise ValueError("identificativo backup non valido")
            destination = args.target_root / args.site / "public"
            backup = args.backup_root / args.site / args.rollback
            rollback(destination, backup)
            print(f"rollback completato per {args.site} dal backup {args.rollback}")
            return 0
        source = args.source_root / args.site
        entries, excluded = collect(source)
        current = manifest(args.site, source, entries)
        if args.plan:
            print(json.dumps({**current, "excluded_count": len(excluded), "excluded": excluded}, indent=2))
            return 0
        if not args.approve or args.approve != current["sha256"]:
            raise ValueError("manifest non approvato o hash cambiato; rieseguire --plan")
        destination = args.target_root / args.site / "public"
        backup = publish(source, destination, args.backup_root / args.site, entries)
        print(f"pubblicato {args.site}; backup={backup}; manifest={current['sha256']}")
        return 0
    except Exception as exc:
        print(f"ERRORE: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
