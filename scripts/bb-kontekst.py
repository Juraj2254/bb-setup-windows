#!/usr/bin/env python3
"""Collect earlier Claude Code, Codex and CROZ Code context into Markdown files for the bb import.

Reads (never writes) the agents' local history:
  ~/.claude      CLAUDE.md, per-project auto-memory, session transcripts
  ~/.codex       AGENTS.md, memories, session transcripts
  ~/.croz-code   CROZ Code memory and sessions
Inside WSL it also reads the Windows profiles under /mnt/c/Users/<name>/ and maps C:\\ paths to /mnt/c/.

Writes <out>/global.md, <out>/projects/<slug>.md and <out>/index.json.
Python 3.8+ (macOS Command Line Tools ship 3.9).
"""
import argparse
import glob
import json
import os
import re
import sys
import time

HOME = os.path.expanduser("~")
MAX_FILE_CHARS = 6000
MAX_PROMPT_CHARS = 280
MAX_PROMPTS = 30
MAX_SESSIONS_PER_PROJECT = 25
INSTRUCTION_FILES = ["CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", ".claude/CLAUDE.md", "GEMINI.md",
                     ".cursorrules", ".github/copilot-instructions.md"]
SKIP_PROMPT_PREFIXES = ("<", "Caveat:", "# AGENTS.md", "[Request interrupted", "This session is being continued")
SECRET_PATTERNS = [
    re.compile(r"sk-[A-Za-z0-9_\-]{16,}"),
    re.compile(r"(?:ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{20,}"),
    re.compile(r"glpat-[A-Za-z0-9_\-]{16,}"),
    re.compile(r"xox[abpr]-[A-Za-z0-9\-]{10,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"(?i)((?:api[_-]?key|token|secret|password|lozinka)\s*[:=]\s*)\S{6,}"),
    re.compile(r"\b[A-Za-z0-9+/_\-]{40,}={0,2}\b"),
]


def redact(text):
    for pat in SECRET_PATTERNS:
        if pat.groups:
            text = pat.sub(lambda m: m.group(1) + "[skriveno]", text)
        else:
            text = pat.sub("[skriveno]", text)
    return text


def read_text(path, limit=MAX_FILE_CHARS):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            data = fh.read(limit + 1)
    except (OSError, UnicodeError):
        return None
    if len(data) > limit:
        data = data[:limit] + "\n…(skraćeno)"
    return redact(data.strip())


def is_wsl():
    try:
        with open("/proc/version") as fh:
            return "microsoft" in fh.read().lower()
    except OSError:
        return False


def windows_profiles():
    """Windows user folders that hold agent history, seen from WSL."""
    out = []
    for d in sorted(glob.glob("/mnt/c/Users/*")):
        name = os.path.basename(d)
        if name in ("Public", "Default", "Default User", "All Users", "WsiAccount", "defaultuser0"):
            continue
        if any(os.path.isdir(os.path.join(d, sub)) for sub in (".claude", ".codex", ".croz-code")):
            out.append(d)
    return out


def norm_path(p):
    """Map Windows paths to WSL paths when running inside WSL; strip trailing slashes."""
    if not p:
        return None
    p = p.strip()
    m = re.match(r"^([A-Za-z]):[\\/](.*)$", p)
    if m:
        if not IN_WSL:
            return None
        rest = m.group(2).replace("\\", "/")
        p = "/mnt/%s/%s" % (m.group(1).lower(), rest)
    p = p.rstrip("/") or "/"
    return p


def skip_path(p):
    if p is None:
        return True
    low = p.lower()
    bad = ("/tmp", "/private/var/", "/var/folders/", "/appdata/", "/.bb/", "/.cache/", "/library/",
           "/.claude/", "/.codex/", "/.croz-code/", "/node_modules/", "/mnt/c/windows/", "/program files",
           "/proc/")
    if low == "/tmp" or low.startswith("/tmp/") or any(b in low + "/" for b in bad):
        return True
    return False


def clean_prompt(text):
    if not isinstance(text, str):
        return None
    t = text.strip()
    if not t or t.startswith(SKIP_PROMPT_PREFIXES):
        return None
    t = re.sub(r"\s+", " ", t)
    if len(t) > MAX_PROMPT_CHARS:
        t = t[:MAX_PROMPT_CHARS] + "…"
    return redact(t)


class Bucket:
    def __init__(self, path):
        self.path = path
        self.last = 0.0
        self.sessions = {"Claude Code": 0, "Codex": 0, "CROZ Code": 0}
        self.prompts = []           # (timestamp, tool, text)
        self.memories = []          # (title, text)

    def touch(self, ts):
        self.last = max(self.last, ts)


BUCKETS = {}
GLOBAL = Bucket("~")
GLOBAL_FILES = []                   # (title, text)


def path_key(p):
    """Windows drives are case-insensitive, so /mnt/c/Users and /mnt/c/users are one folder."""
    return p.lower() if p.startswith("/mnt/") else p


def bucket_for(path, homes):
    p = norm_path(path)
    if p is None:
        return None
    if path_key(p) in homes or p == "/":
        return GLOBAL
    if skip_path(p):
        return None
    k = path_key(p)
    if k not in BUCKETS:
        BUCKETS[k] = Bucket(p)
    elif BUCKETS[k].path.islower() and not p.islower():
        BUCKETS[k].path = p
    return BUCKETS[k]


# ---------------------------------------------------------------- Claude Code

def claude_session(path, want_prompts):
    """Return (cwd, prompts[(ts, text)]) from a Claude Code transcript."""
    cwd, prompts = None, []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for i, line in enumerate(fh):
                if cwd is None and '"cwd"' in line:
                    try:
                        cwd = json.loads(line).get("cwd")
                    except ValueError:
                        pass
                if not want_prompts:
                    if cwd is not None or i > 400:
                        break
                    continue
                if '"type":"user"' not in line.replace(" ", ""):
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                msg = d.get("message") or {}
                content = msg.get("content")
                if isinstance(content, list):
                    texts = [c.get("text") for c in content if isinstance(c, dict) and c.get("type") == "text"]
                    content = " ".join(t for t in texts if t)
                t = clean_prompt(content)
                if t:
                    prompts.append((d.get("timestamp") or "", t))
    except OSError:
        pass
    return cwd, prompts


def scan_claude(home, homes):
    root = os.path.join(home, ".claude")
    if not os.path.isdir(root):
        return
    g = read_text(os.path.join(root, "CLAUDE.md"))
    if g:
        GLOBAL_FILES.append(("Claude Code: globalne upute (%s)" % shown(os.path.join(root, "CLAUDE.md")), g))
    for pdir in sorted(glob.glob(os.path.join(root, "projects", "*"))):
        sessions = sorted(glob.glob(os.path.join(pdir, "*.jsonl")), key=os.path.getmtime, reverse=True)
        cwd = None
        for s in sessions[:3]:
            cwd, _ = claude_session(s, False)
            if cwd:
                break
        b = bucket_for(cwd, homes) if cwd else None
        if b is None:
            continue
        for s in sessions[:MAX_SESSIONS_PER_PROJECT]:
            b.touch(os.path.getmtime(s))
            b.sessions["Claude Code"] += 1
            _, prompts = claude_session(s, True)
            b.prompts += [(ts, "Claude Code", t) for ts, t in prompts]
        b.sessions["Claude Code"] += max(0, len(sessions) - MAX_SESSIONS_PER_PROJECT)
        for mf in sorted(glob.glob(os.path.join(pdir, "memory", "*.md"))):
            txt = read_text(mf)
            if txt:
                b.memories.append(("Claude Code memorija: %s" % os.path.basename(mf), txt))


# ---------------------------------------------------------------- Codex

def scan_codex(home, homes):
    root = os.path.join(home, ".codex")
    if not os.path.isdir(root):
        return
    g = read_text(os.path.join(root, "AGENTS.md"))
    if g:
        GLOBAL_FILES.append(("Codex: globalne upute (%s)" % shown(os.path.join(root, "AGENTS.md")), g))
    for mf in sorted(glob.glob(os.path.join(root, "memories", "**", "*.md"), recursive=True))[:40]:
        txt = read_text(mf)
        if txt:
            GLOBAL_FILES.append(("Codex memorija: %s" % os.path.relpath(mf, root), txt))
    files = glob.glob(os.path.join(root, "sessions", "*", "*", "*", "*.jsonl"))
    files += glob.glob(os.path.join(root, "archived_sessions", "*.jsonl"))
    files.sort(key=os.path.getmtime, reverse=True)
    per_bucket = {}
    for f in files[:600]:
        cwd, prompts, ts0 = None, [], ""
        try:
            with open(f, "r", encoding="utf-8", errors="replace") as fh:
                for i, line in enumerate(fh):
                    if i == 0:
                        try:
                            d = json.loads(line)
                            p = d.get("payload") or {}
                            cwd = p.get("cwd")
                            ts0 = p.get("timestamp") or d.get("timestamp") or ""
                        except ValueError:
                            break
                        continue
                    if '"user_message"' not in line:
                        continue
                    try:
                        d = json.loads(line)
                    except ValueError:
                        continue
                    p = d.get("payload") or {}
                    if p.get("type") == "user_message":
                        t = clean_prompt(p.get("message"))
                        if t:
                            prompts.append((d.get("timestamp") or ts0, t))
        except OSError:
            continue
        b = bucket_for(cwd, homes) if cwd else None
        if b is None:
            continue
        n = per_bucket.get(id(b), 0)
        per_bucket[id(b)] = n + 1
        b.touch(os.path.getmtime(f))
        b.sessions["Codex"] += 1
        if n < MAX_SESSIONS_PER_PROJECT:
            b.prompts += [(ts, "Codex", t) for ts, t in prompts]


# ---------------------------------------------------------------- CROZ Code (Pi)

def scan_croz(home, homes):
    root = os.path.join(home, ".croz-code", "agent")
    if not os.path.isdir(root):
        return
    for name in ("USER.md", "MEMORY.md", "STANDING.md"):
        txt = read_text(os.path.join(root, "memory", "global", name))
        if txt:
            GLOBAL_FILES.append(("CROZ Code memorija: %s" % name, txt))
    croz_projects = {}
    for pdir in glob.glob(os.path.join(root, "memory", "projects", "*")):
        parts = []
        for mf in sorted(glob.glob(os.path.join(pdir, "*.md"))):
            txt = read_text(mf)
            if txt:
                parts.append(("CROZ Code memorija: %s" % os.path.basename(mf), txt))
        if parts:
            croz_projects[os.path.basename(pdir).lower()] = parts
    for sdir in glob.glob(os.path.join(root, "sessions", "*")):
        files = sorted(glob.glob(os.path.join(sdir, "*.jsonl")), key=os.path.getmtime, reverse=True)
        for f in files[:MAX_SESSIONS_PER_PROJECT]:
            cwd, prompts = None, []
            try:
                with open(f, "r", encoding="utf-8", errors="replace") as fh:
                    for i, line in enumerate(fh):
                        try:
                            d = json.loads(line)
                        except ValueError:
                            continue
                        if i == 0:
                            cwd = d.get("cwd")
                            continue
                        m = d.get("message")
                        if d.get("type") == "message" and isinstance(m, dict) and m.get("role") == "user":
                            c = m.get("content")
                            if isinstance(c, list):
                                c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
                            t = clean_prompt(c)
                            if t:
                                prompts.append((d.get("timestamp") or "", t))
            except OSError:
                continue
            b = bucket_for(cwd, homes) if cwd else None
            if b is None:
                continue
            b.touch(os.path.getmtime(f))
            b.sessions["CROZ Code"] += 1
            b.prompts += [(ts, "CROZ Code", t) for ts, t in prompts]
    for b in list(BUCKETS.values()):
        key = os.path.basename(b.path).lower()
        if key in croz_projects:
            b.memories += croz_projects.pop(key)
    for key, parts in croz_projects.items():
        GLOBAL_FILES.extend(("%s (projekt %s)" % (t, key), x) for t, x in parts)


# ---------------------------------------------------------------- output

def shown(p):
    return p.replace(HOME, "~", 1) if p.startswith(HOME) else p


def slugify(path):
    base = os.path.basename(path) or "projekt"
    s = re.sub(r"[^a-z0-9]+", "-", base.lower()).strip("-") or "projekt"
    return s[:40]


def fmt_time(ts):
    return time.strftime("%Y-%m-%d", time.localtime(ts)) if ts else "nepoznato"


def render_bucket(b, title, extra_files):
    lines = ["# %s" % title, ""]
    if b is not GLOBAL:
        lines += ["- Mapa: `%s`" % b.path]
    lines += ["- Zadnja aktivnost: %s" % fmt_time(b.last)]
    used = ", ".join("%s (%d sesija)" % (k, v) for k, v in b.sessions.items() if v)
    lines += ["- Stare sesije: %s" % (used or "nema"), ""]
    for t, txt in extra_files:
        lines += ["## %s" % t, "", "````", txt, "````", ""]
    for t, txt in b.memories:
        lines += ["## %s" % t, "", "````", txt, "````", ""]
    if b.prompts:
        seen, recent = set(), []
        for ts, tool, txt in sorted(b.prompts, key=lambda x: x[0], reverse=True):
            if txt in seen:
                continue
            seen.add(txt)
            recent.append((ts, tool, txt))
            if len(recent) >= MAX_PROMPTS:
                break
        lines += ["## Zadnji upiti iz starih sesija (najnoviji prvi)", ""]
        for ts, tool, txt in recent:
            lines.append("- [%s, %s] %s" % ((ts or "")[:10], tool, txt))
        lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-projects", type=int, default=12)
    ap.add_argument("--no-windows", action="store_true", help="ignore Windows profiles in WSL")
    a = ap.parse_args()

    homes = [HOME]
    if IN_WSL and not a.no_windows:
        homes += windows_profiles()
    home_set = set(path_key(norm_path(h)) for h in homes)
    for h in homes:
        for rel in ("AGENTS.md", "CLAUDE.md"):
            txt = read_text(os.path.join(h, rel))
            if txt:
                GLOBAL_FILES.append(("Upute u korisničkoj mapi: %s" % shown(os.path.join(h, rel)), txt))
        scan_claude(h, home_set)
        scan_codex(h, home_set)
        scan_croz(h, home_set)

    projects = [b for b in BUCKETS.values() if os.path.isdir(b.path)]
    projects.sort(key=lambda b: b.last, reverse=True)
    dropped = projects[a.max_projects:]
    projects = projects[:a.max_projects]

    os.makedirs(os.path.join(a.out, "projects"), exist_ok=True)
    for old in glob.glob(os.path.join(a.out, "projects", "*.md")):
        os.remove(old)
    index = {"generated": time.strftime("%Y-%m-%d %H:%M"), "sources": [shown(h) for h in homes],
             "global": os.path.join(a.out, "global.md"), "projects": [], "skipped": [b.path for b in dropped]}
    with open(index["global"], "w", encoding="utf-8") as fh:
        fh.write(render_bucket(GLOBAL, "Globalni kontekst (sve izvan projekata)", GLOBAL_FILES))
    used = set()
    for b in projects:
        slug = slugify(b.path)
        while slug in used:
            slug += "-2"
        used.add(slug)
        files = []
        for rel in INSTRUCTION_FILES:
            txt = read_text(os.path.join(b.path, rel))
            if txt:
                files.append(("Upute u repozitoriju: %s" % rel, txt))
        for readme in ("README.md", "readme.md", "README"):
            txt = read_text(os.path.join(b.path, readme), 2500)
            if txt:
                files.append(("README (početak)", txt))
                break
        path = os.path.join(a.out, "projects", slug + ".md")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(render_bucket(b, "Projekt %s" % os.path.basename(b.path), files))
        index["projects"].append({"name": os.path.basename(b.path), "path": b.path, "file": path,
                                  "last": fmt_time(b.last), "sessions": b.sessions})
    with open(os.path.join(a.out, "index.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False, indent=1)

    print("  Izvori: %s" % ", ".join(index["sources"]))
    print("  Globalni kontekst: %d datoteka, %d starih upita" % (len(GLOBAL_FILES), len(GLOBAL.prompts)))
    for p in index["projects"]:
        s = ", ".join("%s %d" % (k, v) for k, v in p["sessions"].items() if v)
        print("  Projekt: %-28s %s  (%s)" % (p["name"][:28], p["last"], s))
    if dropped:
        print("  Preskočeno (starije od prvih %d): %d" % (a.max_projects, len(dropped)))


IN_WSL = is_wsl()

if __name__ == "__main__":
    sys.exit(main())
