#!/usr/bin/python3
"""Backup-aware state manager used by install.sh and uninstall.sh.

Every file, directory tree, gsettings key, dconf path and MIME default that MacShell changes is
recorded in a manifest *the first time it is touched*, together with its original value. Running the
installer again never overwrites that record, so `restore` always returns to the pre-MacShell state.

Only the Python standard library is used. Nothing here needs root.
"""
import argparse, ast, hashlib, json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path

HOME = Path.home()
PREFIX = Path(os.environ.get("MACSHELL_PREFIX", HOME / ".local/share/macshell-cinnamon"))
BACKUP = PREFIX / "backup"
MANIFEST = BACKUP / "manifest.json"


def load():
    try:
        return json.loads(MANIFEST.read_text())
    except (OSError, ValueError):
        return {"schema": 1, "created": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "files": {}, "trees": {}, "gsettings": {}, "dconf": {}, "mime": {}}


def save(m):
    BACKUP.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=BACKUP, prefix=".manifest-")
    with os.fdopen(fd, "w") as f:
        json.dump(m, f, indent=2, sort_keys=True)
    os.replace(tmp, MANIFEST)


def slot(path):
    return hashlib.sha256(str(path).encode()).hexdigest()[:16]


def run(*args):
    return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def render(src, substitutions):
    data = Path(src).read_text()
    for k, v in substitutions.items():
        data = data.replace("@" + k + "@", v)
    return data


def install_file(src, dst, mode=None, subst=None):
    dst = Path(dst).expanduser()
    m = load()
    key = str(dst)
    if key not in m["files"]:
        if dst.exists() or dst.is_symlink():
            slotdir = BACKUP / "files" / slot(dst)
            slotdir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, slotdir / dst.name, follow_symlinks=False)
            m["files"][key] = {"backup": str(slotdir / dst.name)}
        else:
            m["files"][key] = {"backup": None}
        save(m)
    dst.parent.mkdir(parents=True, exist_ok=True)
    data = render(src, subst).encode() if subst is not None else Path(src).read_bytes()
    fd, tmp = tempfile.mkstemp(dir=dst.parent, prefix=".macshell-")
    with os.fdopen(fd, "wb") as out:
        out.write(data)
    os.chmod(tmp, int(mode, 8) if mode else (Path(src).stat().st_mode & 0o777))
    os.replace(tmp, dst)


def install_tree(src, dst):
    dst = Path(dst).expanduser()
    m = load()
    key = str(dst)
    if key not in m["trees"]:
        if dst.exists() or dst.is_symlink():
            slotdir = BACKUP / "trees" / slot(dst)
            slotdir.parent.mkdir(parents=True, exist_ok=True)
            if slotdir.exists():
                shutil.rmtree(slotdir)
            shutil.move(str(dst), str(slotdir))
            m["trees"][key] = {"backup": str(slotdir)}
        else:
            m["trees"][key] = {"backup": None}
        save(m)
    elif dst.exists():
        shutil.rmtree(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dst, symlinks=True)


def gget(schema, key):
    r = run("gsettings", "get", schema, key)
    return r.stdout.strip() if r.returncode == 0 else None


def gset(schema, key, value):
    m = load()
    tag = f"{schema} {key}"
    if tag not in m["gsettings"]:
        m["gsettings"][tag] = gget(schema, key)
        save(m)
    r = run("gsettings", "set", schema, key, value)
    if r.returncode != 0:
        print(f"warning: could not set {tag}: {r.stderr.strip()}", file=sys.stderr)
        return False
    return True


def parse_list(text):
    text = (text or "").strip()
    if text.startswith("@as"):
        text = text[3:].strip()
    return ast.literal_eval(text) if text else []


def gset_add(schema, key, item):
    current = parse_list(gget(schema, key))
    if item not in current:
        current.append(item)
    return gset(schema, key, repr(current))


def dconf_load(path, text):
    m = load()
    if path not in m["dconf"]:
        m["dconf"][path] = run("dconf", "dump", path).stdout
        save(m)
    run("dconf", "reset", "-f", path)
    r = subprocess.run(["dconf", "load", path], input=text, text=True, capture_output=True)
    return r.returncode == 0


def mime_default(mimetype, desktop):
    m = load()
    if mimetype not in m["mime"]:
        m["mime"][mimetype] = run("xdg-mime", "query", "default", mimetype).stdout.strip()
        save(m)
    return run("xdg-mime", "default", desktop, mimetype).returncode == 0


def restore(keep_backup=False):
    m = load()
    log = []
    for tag, original in m["gsettings"].items():
        schema, key = tag.split(" ", 1)
        if original is None:
            run("gsettings", "reset", schema, key)
        else:
            run("gsettings", "set", schema, key, original)
        log.append(f"setting {tag}")
    for path, text in m["dconf"].items():
        run("dconf", "reset", "-f", path)
        if text.strip():
            subprocess.run(["dconf", "load", path], input=text, text=True, capture_output=True)
        log.append(f"dconf {path}")
    for mimetype, original in m["mime"].items():
        if original:
            run("xdg-mime", "default", original, mimetype)
        log.append(f"mime {mimetype}")
    for key, info in m["files"].items():
        dst = Path(key)
        if dst.is_symlink() or dst.exists():
            dst.unlink()
        if info["backup"] and Path(info["backup"]).exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(info["backup"], dst, follow_symlinks=False)
        log.append(f"file {key}")
    for key, info in m["trees"].items():
        dst = Path(key)
        if dst.is_symlink():
            dst.unlink()
        elif dst.exists():
            shutil.rmtree(dst)
        if info["backup"] and Path(info["backup"]).exists():
            shutil.move(info["backup"], str(dst))
        log.append(f"tree {key}")
    if not keep_backup:
        shutil.rmtree(BACKUP, ignore_errors=True)
    return log


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("file"); s.add_argument("src"); s.add_argument("dst"); s.add_argument("--mode")
    s.add_argument("--subst", nargs="*", default=None, help="KEY=VALUE pairs replacing @KEY@ (omit for a byte copy)")
    s = sub.add_parser("tree"); s.add_argument("src"); s.add_argument("dst")
    s = sub.add_parser("gset"); s.add_argument("schema"); s.add_argument("key"); s.add_argument("value")
    s = sub.add_parser("gadd"); s.add_argument("schema"); s.add_argument("key"); s.add_argument("item")
    s = sub.add_parser("dconf"); s.add_argument("path"); s.add_argument("keyfile")
    s = sub.add_parser("mime"); s.add_argument("mimetype"); s.add_argument("desktop")
    s = sub.add_parser("restore"); s.add_argument("--keep-backup", action="store_true")
    sub.add_parser("status")
    a = p.parse_args()
    if a.cmd == "file":
        subst = dict(kv.split("=", 1) for kv in a.subst) if a.subst is not None else None
        install_file(a.src, a.dst, a.mode, subst)
    elif a.cmd == "tree":
        install_tree(a.src, a.dst)
    elif a.cmd == "gset":
        sys.exit(0 if gset(a.schema, a.key, a.value) else 1)
    elif a.cmd == "gadd":
        sys.exit(0 if gset_add(a.schema, a.key, a.item) else 1)
    elif a.cmd == "dconf":
        sys.exit(0 if dconf_load(a.path, Path(a.keyfile).read_text()) else 1)
    elif a.cmd == "mime":
        sys.exit(0 if mime_default(a.mimetype, a.desktop) else 1)
    elif a.cmd == "restore":
        for line in restore(a.keep_backup):
            print("restored", line)
    elif a.cmd == "status":
        m = load()
        print(json.dumps({k: (len(v) if isinstance(v, dict) else v) for k, v in m.items()}, indent=2))


if __name__ == "__main__":
    main()
