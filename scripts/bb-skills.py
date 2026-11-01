#!/usr/bin/env python3
"""Copy every agent skill on this computer into bb's user skills folder (~/.bb/skills).

bb gives the skills in ~/.bb/skills to every agent it runs (Claude Code, Codex, Pi / CROZ Code).
Sources, first one wins when two skills share a name:
  ~/.bb/skills (already there, never overwritten)
  ~/.agents/skills, ~/.claude/skills, ~/.codex/skills (without Codex's built-in .system)
  CROZ Code: bundled packages and ~/.croz-code/agent/croz-packages/*/skills
  in WSL also the Windows profiles: /mnt/c/Users/<name>/{.agents,.claude,.codex}/skills
Originals are never changed. --link also links every bb skill back into ~/.claude/skills and
~/.agents/skills, so the agents see the same skills outside bb. Python 3.8+.
"""
import argparse
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
MAX_BYTES = 50 * 1024 * 1024
IGNORE = shutil.ignore_patterns(".git", "node_modules", "__pycache__", ".DS_Store", "*.pyc", ".venv")


def is_wsl():
    try:
        with open("/proc/version") as fh:
            return "microsoft" in fh.read().lower()
    except OSError:
        return False


def windows_profiles():
    out = []
    for d in sorted(glob.glob("/mnt/c/Users/*")):
        if os.path.basename(d) in ("Public", "Default", "Default User", "All Users", "WsiAccount", "defaultuser0"):
            continue
        out.append(d)
    return out


def croz_roots():
    roots = []
    try:
        npm_root = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        npm_root = ""
    if npm_root:
        roots += glob.glob(os.path.join(npm_root, "@croz", "croz-code", "bundled", "*", "skills"))
    roots += glob.glob(os.path.join(HOME, ".croz-code", "agent", "croz-packages", "*", "skills"))
    return [(r, "CROZ Code") for r in roots]


def sources(include_windows):
    out = [(os.path.join(HOME, ".agents", "skills"), "~/.agents"),
           (os.path.join(HOME, ".claude", "skills"), "Claude Code"),
           (os.path.join(HOME, ".codex", "skills"), "Codex")]
    out += croz_roots()
    if include_windows and is_wsl():
        for prof in windows_profiles():
            name = os.path.basename(prof)
            for sub, label in ((".agents", "~/.agents"), (".claude", "Claude Code"), (".codex", "Codex")):
                out.append((os.path.join(prof, sub, "skills"), "%s (Windows %s)" % (label, name)))
    return out


def find_skills(root, max_depth=3):
    """Directories that hold a SKILL.md; never descends into a found skill."""
    found = []
    if not os.path.isdir(root):
        return found
    base_depth = root.rstrip("/").count("/")
    for d, dirs, files in os.walk(root, followlinks=True):
        if d.rstrip("/").count("/") - base_depth > max_depth:
            dirs[:] = []
            continue
        dirs[:] = [x for x in dirs if not x.startswith(".") and x not in ("node_modules", "__pycache__")]
        if "SKILL.md" in files and d != root:
            found.append(d)
            dirs[:] = []
    return found


def parse_frontmatter(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        return None, None, ""
    m = re.match(r"^---\s*\n(.*?)\n---\s*(\n|$)", text, re.S)
    if not m:
        return None, None, text
    fm = m.group(1)
    fields, cur = {}, None
    for line in fm.splitlines():
        km = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if km:
            cur = km.group(1)
            fields[cur] = km.group(2).strip()
        elif cur and line.startswith((" ", "\t")):
            fields[cur] = (fields[cur] + " " + line.strip()).strip()
    def clean(v):
        if v is None:
            return None
        v = v.strip()
        if v in (">", "|", ">-", "|-"):
            return ""
        if v[:1] in ("'", '"') and v[-1:] == v[:1]:
            v = v[1:-1]
        v = re.sub(r"^[>|]-?\s+", "", v)
        return v.strip()
    return clean(fields.get("name")), clean(fields.get("description")), text


def normalize(name):
    n = re.sub(r"[^a-z0-9-]+", "-", (name or "").lower()).strip("-")
    n = re.sub(r"-{2,}", "-", n)
    return n[:64]


KEEP_KEYS = ("allowed-tools", "disable-model-invocation", "user-invocable", "license", "argument-hint", "model")


def safe_frontmatter(text, name, desc):
    """Rewrite the frontmatter so bb accepts it: valid YAML, name = folder, description <= 1024 chars."""
    m = re.match(r"^---\s*\n(.*?)\n---[ \t]*\n?", text, re.S)
    body = text[m.end():] if m else text
    extra = []
    if m:
        for line in m.group(1).splitlines():
            km = re.match(r"^([A-Za-z0-9_-]+):\s*(\S.*)$", line)
            if km and km.group(1) in KEEP_KEYS:
                val = km.group(2).strip()
                if val[:1] not in ("'", '"', "[", "{") and (": " in val or val.endswith(":") or " #" in val):
                    val = json.dumps(val, ensure_ascii=False)
                extra.append("%s: %s" % (km.group(1), val))
    desc = re.sub(r"\s+", " ", desc).strip()
    if len(desc) > 1024:
        cut = desc[:1020]
        dot = cut.rfind(". ")
        desc = cut[:dot + 1] if dot > 500 else cut.rstrip() + "…"
    lines = ["---", "name: %s" % name, "description: %s" % json.dumps(desc, ensure_ascii=False)] + extra + ["---", ""]
    return "\n".join(lines) + body.lstrip("\n")


def dir_size(path):
    total = 0
    for d, dirs, files in os.walk(path):
        dirs[:] = [x for x in dirs if x not in (".git", "node_modules", "__pycache__", ".venv")]
        for f in files:
            try:
                total += os.path.getsize(os.path.join(d, f))
            except OSError:
                pass
    return total


def digest(path):
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except OSError:
        return ""


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dest", default=os.path.join(os.environ.get("BB_DATA_DIR", os.path.join(HOME, ".bb")), "skills"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-windows", action="store_true")
    ap.add_argument("--link", action="store_true", help="link bb skills back into ~/.claude/skills and ~/.agents/skills")
    a = ap.parse_args()
    dest = os.path.abspath(os.path.expanduser(a.dest))
    dest_real = os.path.realpath(dest)
    if not a.dry_run:
        os.makedirs(dest, exist_ok=True)

    taken = {}
    for p in glob.glob(os.path.join(dest, "*", "SKILL.md")):
        taken[os.path.basename(os.path.dirname(p))] = "bb"
    imported, same, skipped, dupes = [], [], [], []
    manifest_path = os.path.join(dest, ".bb-skills-import.json")
    try:
        manifest = json.load(open(manifest_path, encoding="utf-8"))
    except (OSError, ValueError):
        manifest = {"skills": {}}

    for root, label in sources(not a.no_windows):
        for sdir in find_skills(root):
            real = os.path.realpath(sdir)
            if real == dest_real or real.startswith(dest_real + os.sep):
                continue  # already a link into bb
            fm_name, desc, text = parse_frontmatter(os.path.join(sdir, "SKILL.md"))
            name = normalize(fm_name or os.path.basename(sdir))
            if not name:
                skipped.append((sdir, "nema imena"))
                continue
            if not desc:
                skipped.append((sdir, "nema opisa (description) u SKILL.md"))
                continue
            if name in taken:
                if taken[name] != "bb":
                    dupes.append(sdir)
                else:
                    same.append(name)
                continue
            size = dir_size(sdir)
            if size > MAX_BYTES:
                skipped.append((sdir, "prevelik (%d MB)" % (size // 1048576)))
                continue
            target = os.path.join(dest, name)
            taken[name] = label
            if not a.dry_run:
                shutil.copytree(sdir, target, symlinks=False, ignore=IGNORE, ignore_dangling_symlinks=True)
                with open(os.path.join(target, "SKILL.md"), "w", encoding="utf-8") as fh:
                    fh.write(safe_frontmatter(text, name, desc))
                manifest["skills"][name] = {"source": sdir, "from": label, "imported": time.strftime("%Y-%m-%d %H:%M")}
            imported.append((name, label))

    if not a.dry_run:
        with open(manifest_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=1)

    linked = 0
    if a.link and not a.dry_run:
        for target_root in (os.path.join(HOME, ".claude", "skills"), os.path.join(HOME, ".agents", "skills")):
            os.makedirs(target_root, exist_ok=True)
            for p in glob.glob(os.path.join(dest, "*", "SKILL.md")):
                name = os.path.basename(os.path.dirname(p))
                link = os.path.join(target_root, name)
                if not os.path.lexists(link):
                    os.symlink(os.path.dirname(p), link)
                    linked += 1

    by_src = {}
    for _, label in imported:
        by_src[label] = by_src.get(label, 0) + 1
    print("  Uvezeno u %s: %d skillova%s" % (dest.replace(HOME, "~"), len(imported),
          (" (" + ", ".join("%s %d" % kv for kv in sorted(by_src.items())) + ")") if by_src else ""))
    if same:
        print("  Već u bb-u: %d" % len(same))
    if dupes:
        print("  Duplikati istog imena (uzet je prvi): %d" % len(dupes))
    for sdir, why in skipped[:15]:
        print("  Preskočeno: %s (%s)" % (sdir.replace(HOME, "~"), why))
    if len(skipped) > 15:
        print("  … i još %d preskočenih" % (len(skipped) - 15))
    if a.link:
        print("  Povezano natrag u ~/.claude/skills i ~/.agents/skills: %d" % linked)


if __name__ == "__main__":
    sys.exit(main())
