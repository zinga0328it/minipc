#!/usr/bin/env python3
"""Restricted VAR publisher and project-service manager; never accepts shell commands."""
from __future__ import annotations

import argparse
import os
import pwd
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

SLUG = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
MANIFEST = re.compile(r"^[a-f0-9]{64}$")
BACKUP_ID = re.compile(r"^[0-9]{8}T[0-9]{6}Z-[0-9]+$")
UNIT_BACKUP_ID = re.compile(r"^[0-9]{8}T[0-9]{6}Z-[0-9]+$")
DEPLOY = Path("/usr/local/lib/servicess/static-site/deploy.py")
TEMPLATE = Path("/usr/local/lib/servicess/templates/rust-api.service.template")
UNIT_DIR = Path("/etc/systemd/system")
BACKUP_DIR = Path("/var/backups/servicess")


def slug(value: str) -> str:
    if not SLUG.fullmatch(value):
        raise ValueError("slug non valido")
    return value


def invoking_user() -> tuple[pwd.struct_passwd, Path]:
    name = os.environ.get("SUDO_USER")
    if not name or name == "root":
        raise PermissionError("richiesto sudo da un account non-root")
    user = pwd.getpwnam(name)
    home = Path(user.pw_dir)
    if not home.is_absolute() or home == Path("/"):
        raise ValueError("HOME utente non valido")
    return user, home


def render_unit(project: str, username: str, home: Path, template: Path | None = None) -> str:
    slug(project)
    if not re.fullmatch(r"[a-z_][a-z0-9_-]*", username):
        raise ValueError("nome utente non valido")
    if not re.fullmatch(r"/[A-Za-z0-9_./-]+", str(home)):
        raise ValueError("percorso HOME non valido")
    app = home / "apps" / project
    binary = app / "api" / "target" / "release" / f"{project}-api"
    secret = app / "secrets" / "runtime.env"
    if not app.is_dir() or app.is_symlink() or app.stat().st_uid != pwd.getpwnam(username).pw_uid:
        raise ValueError("cartella gestionale assente, symlink o proprietario errato")
    if not binary.is_file() or binary.is_symlink():
        raise ValueError("binario API assente; eseguire cargo build --release")
    mode = stat.S_IMODE(binary.stat().st_mode)
    if binary.stat().st_uid != pwd.getpwnam(username).pw_uid or mode & 0o022 or not mode & 0o111:
        raise ValueError("binario API deve appartenere all'utente e non essere scrivibile da altri")
    if secret.exists() and (
        secret.is_symlink()
        or not secret.is_file()
        or secret.stat().st_uid != pwd.getpwnam(username).pw_uid
        or stat.S_IMODE(secret.stat().st_mode) & 0o077
    ):
        raise ValueError("runtime.env deve essere file regolare 0600, senza symlink")
    source = template or TEMPLATE
    if source.is_symlink() or not source.is_file():
        raise ValueError("template unit assente o symlink")
    content = source.read_text(encoding="utf-8")
    for key, value in {
        "SERVICE_USER": username,
        "APP_ROOT": str(app),
        "PROJECT_SLUG": project,
    }.items():
        content = content.replace("{{" + key + "}}", value)
    if "{{" in content or "}}" in content:
        raise ValueError("placeholder unit non risolto")
    return content


def call(argv: list[str]) -> None:
    subprocess.run(argv, check=True)


def publish(args: argparse.Namespace) -> None:
    slug(args.site)
    if not MANIFEST.fullmatch(args.manifest):
        raise ValueError("hash manifest deve essere SHA-256 esadecimale")
    if os.geteuid() != 0:
        raise PermissionError("publish richiede sudo -n")
    invoking_user()
    call(["/usr/bin/python3", str(DEPLOY), args.site, "--publish", "--approve", args.manifest])


def rollback_site(args: argparse.Namespace) -> None:
    slug(args.site)
    if not BACKUP_ID.fullmatch(args.backup):
        raise ValueError("id backup non valido")
    if os.geteuid() != 0:
        raise PermissionError("rollback richiede sudo -n")
    invoking_user()
    call(["/usr/bin/python3", str(DEPLOY), args.site, "--rollback", args.backup])


def install_unit(project: str) -> None:
    slug(project)
    if os.geteuid() != 0:
        raise PermissionError("install-service richiede sudo -n")
    user, home = invoking_user()
    unit = render_unit(project, user.pw_name, home)
    target = UNIT_DIR / f"servicess-{project}.service"
    UNIT_DIR.mkdir(mode=0o755, parents=True, exist_ok=True)
    backup_base = BACKUP_DIR / "systemd" / project
    backup_base.mkdir(mode=0o700, parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_id = f"{stamp}-{os.getpid()}"
    backup = backup_base / backup_id
    backup.mkdir(mode=0o700)
    if target.exists():
        if target.is_symlink() or not target.is_file():
            raise ValueError("unit esistente non e' un file regolare")
        shutil.copy2(target, backup / "unit")
        (backup / "state").write_text("present\n")
    else:
        (backup / "state").write_text("absent\n")
    temp = None
    try:
        fd, temp_name = tempfile.mkstemp(prefix=".servicess-", suffix=".service", dir=UNIT_DIR)
        temp = Path(temp_name)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(unit)
        temp.chmod(0o644)
        call(["/usr/bin/systemd-analyze", "verify", str(temp)])
        os.replace(temp, target)
        temp = None
        call(["/usr/bin/systemctl", "daemon-reload"])
    except Exception:
        if temp and temp.exists():
            temp.unlink()
        if (backup / "state").read_text().strip() == "present":
            shutil.copy2(backup / "unit", target)
        else:
            target.unlink(missing_ok=True)
        subprocess.run(["/usr/bin/systemctl", "daemon-reload"], check=False)
        raise
    print(f"unit installata non abilitata: {target}; backup={backup_id}")


def rollback_unit(project: str, backup_id: str) -> None:
    slug(project)
    if not UNIT_BACKUP_ID.fullmatch(backup_id):
        raise ValueError("id backup non valido")
    if os.geteuid() != 0:
        raise PermissionError("rollback servizio richiede sudo -n")
    invoking_user()
    backup = BACKUP_DIR / "systemd" / project / backup_id
    target = UNIT_DIR / f"servicess-{project}.service"
    if backup.is_symlink() or not backup.is_dir():
        raise ValueError("backup assente o symlink")
    state = (backup / "state").read_text().strip()
    if state == "present":
        saved = backup / "unit"
        if saved.is_symlink() or not saved.is_file():
            raise ValueError("unit di backup non valida")
        temp = target.with_suffix(".service.rollback")
        shutil.copy2(saved, temp)
        call(["/usr/bin/systemd-analyze", "verify", str(temp)])
        os.replace(temp, target)
    elif state == "absent":
        target.unlink(missing_ok=True)
    else:
        raise ValueError("stato backup sconosciuto")
    call(["/usr/bin/systemctl", "daemon-reload"])


def service_action(action: str, project: str) -> None:
    slug(project)
    if action not in {"status", "start", "stop", "restart", "enable", "disable"}:
        raise ValueError("azione systemd non autorizzata")
    if os.geteuid() != 0:
        raise PermissionError("operazione systemd richiede sudo -n")
    invoking_user()
    unit = f"servicess-{project}.service"
    if not (UNIT_DIR / unit).is_file():
        raise ValueError("unit Servicess non installata")
    if action == "status":
        call(["/usr/bin/systemctl", "is-active", unit])
    else:
        call(["/usr/bin/systemctl", action, unit])


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="group", required=True)
    pub = sub.add_parser("publish")
    pub.add_argument("site")
    pub.add_argument("manifest")
    pub.set_defaults(func=publish)
    rb = sub.add_parser("rollback-site")
    rb.add_argument("site")
    rb.add_argument("backup")
    rb.set_defaults(func=rollback_site)
    srv = sub.add_parser("service")
    srv_sub = srv.add_subparsers(dest="action", required=True)
    install = srv_sub.add_parser("install")
    install.add_argument("project")
    install.set_defaults(func=lambda a: install_unit(a.project))
    rollback = srv_sub.add_parser("rollback")
    rollback.add_argument("project")
    rollback.add_argument("backup")
    rollback.set_defaults(func=lambda a: rollback_unit(a.project, a.backup))
    manage = srv_sub.add_parser("manage")
    manage.add_argument("operation", choices=["status", "start", "stop", "restart", "enable", "disable"])
    manage.add_argument("project")
    manage.set_defaults(func=lambda a: service_action(a.operation, a.project))
    args = parser.parse_args()
    try:
        args.func(args)
        return 0
    except Exception as exc:
        print(f"ERRORE: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
