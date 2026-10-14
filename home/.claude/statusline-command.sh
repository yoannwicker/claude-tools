#!/usr/bin/env bash
# Claude Code status line — https://code.claude.com/docs/en/statusline
# Reads the session JSON on stdin; a single python3 call parses and renders it.

read -r -d '' PY <<'PY'
import hashlib, json, os, subprocess, sys, time, unicodedata, re
from datetime import datetime

RST = "\033[0m"
BOLD = "\033[1m"
GRAY = "\033[90m"
RED = "\033[31m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
MAGENTA = "\033[35m"
CYAN_B = "\033[1;36m"
BLUE_B = "\033[1;34m"
YELLOW_B = "\033[1;33m"
SEP = f"{GRAY} │ {RST}"

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}


def get(obj, *path):
    for key in path:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
    return obj


def num(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return value
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def level_color(pct):
    if pct >= 90:
        return RED
    if pct >= 70:
        return YELLOW
    return GREEN


def bar(pct):
    p = max(0, int(pct))
    filled = min(p, 100) * 10 // 100
    color = level_color(p)
    return f"{color}{'█' * filled}{RST}{GRAY}{'░' * (10 - filled)}{RST} {color}{BOLD}{p:3d}%{RST}"


def size_label(size):
    size = int(size)
    if size >= 1_000_000:
        return f"{size / 1_000_000:g}M"
    return f"{size // 1000}k"


def duration(ms):
    total = int(ms) // 1000
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}h{m:02d}"
    return f"{m}m {s:02d}s"


def reset_in(epoch):
    delta = int(epoch - time.time())
    if delta <= 0:
        return None
    d, rem = divmod(delta, 86400)
    h, rem = divmod(rem, 3600)
    m = rem // 60
    if d:
        return f"reset dans{RST} {d}j{h}h"
    if h:
        return f"reset dans{RST} {h}h{m:02d}"
    return f"reset dans{RST} {m}m"


def reset_on(epoch):
    if epoch <= time.time():
        return None
    return f"reset le{RST} {datetime.fromtimestamp(epoch):%d/%m %H:%M}"


ANSI = re.compile(r"\033\[[0-9;]*m|\033\]8;;[^\a]*\a")


def width(text):
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
               for c in ANSI.sub("", text))


def git_info(cwd):
    key = data.get("session_id") or hashlib.md5(cwd.encode()).hexdigest()
    key = re.sub(r"[^A-Za-z0-9_.-]", "_", str(key))
    cache = f"/tmp/statusline-git-{key}"
    try:
        if time.time() - os.path.getmtime(cache) < 5:
            with open(cache) as f:
                cached = json.load(f)
            if cached.get("cwd") == cwd:
                return cached
    except Exception:
        pass
    info = {"cwd": cwd, "branch": None, "staged": 0, "modified": 0}
    try:
        out = subprocess.run(
            ["git", "--no-optional-locks", "-C", cwd, "status", "--porcelain=v2", "--branch"],
            capture_output=True, text=True, timeout=2,
        )
        if out.returncode == 0:
            oid = None
            for line in out.stdout.splitlines():
                if line.startswith("# branch.head "):
                    info["branch"] = line.split(" ", 2)[2]
                elif line.startswith("# branch.oid "):
                    oid = line.split(" ", 2)[2]
                elif line[:2] in ("1 ", "2 ", "u "):
                    xy = line[2:4]
                    info["staged"] += xy[0] != "."
                    info["modified"] += xy[1] != "."
            if info["branch"] == "(detached)":
                info["detached"] = True
                if oid:
                    info["branch"] = oid[:7]
    except Exception:
        pass
    try:
        with open(cache, "w") as f:
            json.dump(info, f)
    except Exception:
        pass
    return info


def pr_approvals(url):
    key = hashlib.md5(url.encode()).hexdigest()
    cache = f"/tmp/statusline-pr-{key}"
    try:
        if time.time() - os.path.getmtime(cache) < 60:
            with open(cache) as f:
                return json.load(f)["approvals"]
    except Exception:
        pass
    approvals = None
    try:
        out = subprocess.run(
            ["gh", "pr", "view", url, "--json", "latestReviews",
             "-q", '[.latestReviews[] | select(.state == "APPROVED")] | length'],
            capture_output=True, text=True, timeout=3,
        )
        if out.returncode == 0:
            approvals = int(out.stdout.strip())
    except Exception:
        pass
    try:
        with open(cache, "w") as f:
            json.dump({"approvals": approvals}, f)
    except Exception:
        pass
    return approvals


def branch_pr(cwd, branch):
    key = hashlib.md5(f"{cwd}\0{branch}".encode()).hexdigest()
    cache = f"/tmp/statusline-branch-pr-{key}"
    try:
        if time.time() - os.path.getmtime(cache) < 60:
            with open(cache) as f:
                return json.load(f)["pr"]
    except Exception:
        pass
    pr = "unknown"
    try:
        out = subprocess.run(
            ["gh", "pr", "view", branch, "--json",
             "number,url,state,isDraft,reviewDecision,latestReviews"],
            cwd=cwd, capture_output=True, text=True, timeout=3,
        )
        if out.returncode == 0:
            d = json.loads(out.stdout)
            pr = None
            if d.get("state") == "OPEN":
                review_state = "draft" if d.get("isDraft") else {
                    "APPROVED": "approved",
                    "CHANGES_REQUESTED": "changes_requested",
                    "REVIEW_REQUIRED": "pending",
                }.get(d.get("reviewDecision"))
                pr = {
                    "number": d["number"],
                    "url": d["url"],
                    "review_state": review_state,
                    "approvals": sum(r.get("state") == "APPROVED"
                                     for r in d.get("latestReviews") or []),
                }
        elif "no pull requests found" in out.stderr:
            pr = None
    except Exception:
        pass
    if pr != "unknown":
        try:
            with open(cache, "w") as f:
                json.dump({"pr": pr}, f)
        except Exception:
            pass
    return pr


# Line 1
line1 = []
git = {}
model = get(data, "model", "display_name")
if model:
    seg = f"{CYAN_B}[{model}]{RST}"
    effort = get(data, "effort", "level")
    if effort:
        seg += f" {GRAY}{effort}{RST}"
    line1.append(seg)

config_dir = os.environ.get("CLAUDE_CONFIG_DIR", "")
if config_dir.startswith(os.path.expanduser("~/.claude-profiles/")):
    line1.append(f"🧩 {MAGENTA}{os.path.basename(config_dir.rstrip('/'))}{RST}")

cwd = get(data, "workspace", "current_dir") or data.get("cwd")
if isinstance(cwd, str) and cwd:
    line1.append(f"📁 {BLUE_B}{os.path.basename(cwd.rstrip('/')) or '/'}{RST}")
    git = git_info(cwd)
    if git.get("branch"):
        seg = f"🌿 {MAGENTA}{git['branch']}{RST}"
        changes = []
        if git["staged"]:
            changes.append(f"{GREEN}+{git['staged']}{RST}")
        if git["modified"]:
            changes.append(f"{YELLOW}~{git['modified']}{RST}")
        seg += " " + (" ".join(changes) if changes else "✅")
        line1.append(seg)

local_pr = "unknown"
if git.get("branch") and not git.get("detached"):
    local_pr = branch_pr(cwd, git["branch"])
pr = data.get("pr") if local_pr == "unknown" else local_pr
if not isinstance(pr, dict):
    pr = None

pr_number = get(pr, "number")
if pr_number is not None:
    label = f"MR !{pr_number}" if get(pr, "kind") == "mr" else f"PR #{pr_number}"
    url = get(pr, "url")
    if url:
        label = f"\033]8;;{url}\a{label}\033]8;;\a"
    seg = f"🔀 {label}"
    review_state = get(pr, "review_state")
    approvals = get(pr, "approvals")
    if approvals is None and url and get(pr, "kind") != "mr":
        approvals = pr_approvals(url)
    if approvals is None:
        approvals = 1 if review_state == "approved" else 0
    if review_state == "approved":
        approvals = max(approvals, 1)
    if approvals:
        seg += f" {GREEN}{'✔' * approvals}{RST}"
    state = {
        "pending": (YELLOW, "en revue"),
        "changes_requested": (RED, "changements demandés"),
        "draft": (GRAY, "brouillon"),
    }.get(review_state)
    if state:
        seg += f" {state[0]}{state[1]}{RST}"
    line1.append(seg)

worktree = get(data, "workspace", "git_worktree") or get(data, "worktree", "name")
if worktree:
    line1.append(f"🌳 {GREEN}{worktree}{RST}")

# Line 2
line2 = []
used = num(get(data, "context_window", "used_percentage"))
if used is None:
    line2.append(f"🧠 {GRAY}-- en attente{RST}")
else:
    seg = f"🧠 {bar(used)}"
    size = num(get(data, "context_window", "context_window_size"))
    if size:
        seg += f" de {size_label(size)}"
    line2.append(seg)

cost = num(get(data, "cost", "total_cost_usd"))
if cost is not None:
    line2.append(f"💰 {YELLOW_B}${cost:.2f}{RST}")

dur = num(get(data, "cost", "total_duration_ms"))
if dur is not None:
    line2.append(f"⏳ {duration(dur)}")

added = int(num(get(data, "cost", "total_lines_added")) or 0)
removed = int(num(get(data, "cost", "total_lines_removed")) or 0)
if added or removed:
    parts = []
    if added:
        parts.append(f"{GREEN}+{added}{RST}")
    if removed:
        parts.append(f"{RED}-{removed}{RST}")
    line2.append("📝 " + " ".join(parts))

# Line 3
limits = []
spend_cap = num(os.environ.get("STATUSLINE_SPEND_CAP_USD"))
for key, icon, name, reset_label in (
    ("five_hour", "⚡", "5h", reset_in),
    ("seven_day", "📅", "7j", reset_on),
    ("spend_limit", "💳", "mois", reset_on),
):
    pct = num(get(data, "rate_limits", key, "used_percentage"))
    if pct is None:
        continue
    seg = f"{icon} {name} {bar(pct)}"
    if key == "spend_limit" and spend_cap:
        seg += f" {YELLOW_B}${pct * spend_cap / 100:.0f}{RST} {GRAY}/ ${spend_cap:g}{RST}"
    resets = num(get(data, "rate_limits", key, "resets_at"))
    reset = reset_label(resets) if resets is not None else None
    if reset:
        seg += f" {GRAY}{reset}"
    limits.append(seg)

lines = [SEP.join(line1), SEP.join(line2)]
if limits:
    joined = SEP.join(limits)
    try:
        columns = int(os.environ.get("COLUMNS", ""))
    except ValueError:
        columns = 0
    if columns and width(joined) > columns:
        lines.extend(limits)
    else:
        lines.append(joined)

print("\n".join(line for line in lines if line))
PY

exec python3 -c "$PY" 2>/dev/null
