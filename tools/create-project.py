#!/usr/bin/env python3
"""Create a private Rust manager and an isolated static website from templates."""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path

SLUG = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
ROOT = Path(__file__).resolve().parents[1]
APP_TEMPLATE = ROOT / "templates/project-manager"
WEB_TEMPLATE = ROOT / "templates/web-site"


def valid_slug(value: str) -> str:
    if not SLUG.fullmatch(value):
        raise ValueError(f"identificativo non valido: {value}")
    return value


def safe_root(path: Path) -> Path:
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    resolved = path.resolve(strict=True)
    if resolved != path.absolute() or path.is_symlink() or not path.is_dir():
        raise ValueError(f"root non valido o symlink: {path}")
    return resolved


def render_tree(source: Path, destination: Path, values: dict[str, str], modes: tuple[int, int]) -> None:
    shutil.copytree(source, destination, symlinks=False)
    dir_mode, file_mode = modes
    for path in destination.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"template contiene symlink: {path}")
        if path.is_dir():
            path.chmod(dir_mode)
            continue
        content = path.read_bytes()
        try:
            text = content.decode("utf-8")
        except UnicodeDecodeError:
            path.chmod(file_mode)
            continue
        for key, value in values.items():
            text = text.replace("{{" + key + "}}", value)
        path.write_text(text, encoding="utf-8")
        path.chmod(file_mode)
    destination.chmod(dir_mode)


def init_private_repo(path: Path) -> None:
    subprocess.run(
        ["git", "init", "--quiet", "--initial-branch=main"],
        cwd=path,
        check=True,
        stdout=subprocess.DEVNULL,
    )


def create(project: str, site: str, home: Path) -> tuple[Path, Path]:
    project = valid_slug(project)
    site = valid_slug(site)
    home = home.resolve(strict=True)
    apps = safe_root(home / "apps")
    web = safe_root(home / "web")
    app = apps / project
    website = web / site
    if app.exists() or app.is_symlink() or website.exists() or website.is_symlink():
        raise FileExistsError("progetto o sito gia' esistente; non sovrascrivo")

    created: list[Path] = []
    try:
        crate = project.replace("-", "_")
        render_tree(
            APP_TEMPLATE,
            app,
            {"PROJECT_SLUG": project, "PROJECT_CRATE": crate, "SITE_SLUG": site},
            (0o700, 0o600),
        )
        created.append(app)
        render_tree(WEB_TEMPLATE, website, {"SITE_SLUG": site}, (0o755, 0o644))
        created.append(website)
        init_private_repo(app)
        init_private_repo(website)
        return app, website
    except Exception:
        for path in reversed(created):
            shutil.rmtree(path, ignore_errors=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", help="slug gestionale (minuscolo, numeri, trattini)")
    parser.add_argument("site", help="slug sito statico")
    parser.add_argument("--home", type=Path, default=Path.home(), help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        app, web = create(args.project, args.site, args.home)
    except Exception as exc:
        parser.exit(1, f"errore: {exc}\n")
    print(f"Gestionale: {app} (0700, repository Git locale privato)")
    print(f"Sito:      {web} (statici soltanto, repository Git locale)")
    print("Aggiungere solo remote GitHub privati dopo aver verificato gh auth status.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
