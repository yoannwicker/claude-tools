#!/usr/bin/env python3
"""Hook PostToolUse (Bash) du plugin git-nav : après un merge réussi (gh pr merge,
git merge <branche>, ou git push <remote> <branche>:<branche par défaut> qui y pousse une
autre branche, comme après un rebase), lance gbr cleanup --dry-run sur la branche mergée et
demande à Claude d'enchaîner sur le skill git-nav:branch-cleanup avec ce plan.

Ignorés : gh pr merge --auto (le merge n'a pas encore eu lieu), git merge --abort,
--continue, --quit, git push --delete/--dry-run/--all/--mirror, push d'un SHA ou de la
branche par défaut sur elle-même, entrée ou commande illisible. Non inspectés : bash -c '…',
eval, scripts.
"""
import json
import os
import re
import shlex
import subprocess
import sys

GBR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "gbr")

SEPARATOR_CHARS = set("();|&\n")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
WRAPPERS = {"time", "nohup", "exec", "command", "env"}
GIT_MERGE_SKIP = {"--abort", "--continue", "--quit"}
# Options de git avant la sous-commande qui prennent une valeur (git -C <dir> merge …).
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
# Options de git merge qui prennent une valeur (git merge -m <message> <branche>).
MERGE_OPTS_WITH_VALUE = {"-m", "-F", "-s", "-X", "--file", "--strategy", "--strategy-option"}
# Options de git push qui prennent une valeur, et celles qui ne poussent pas une branche.
PUSH_OPTS_WITH_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
PUSH_SKIP = {"-d", "--delete", "-n", "--dry-run", "--all", "--branches", "--mirror", "--prune"}
SHA = re.compile(r"^[0-9a-f]{7,40}$")


def segments(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    current = []
    for tok in lexer:
        if tok and set(tok) <= SEPARATOR_CHARS:
            if current:
                yield current
            current = []
        else:
            current.append(tok)
    if current:
        yield current


def git_out(cwd, *args):
    """Sortie de git dans cwd, None en cas d'échec."""
    try:
        out = subprocess.run(["git", *args], cwd=cwd or None, capture_output=True,
                             text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout.strip() if out.returncode == 0 else None


def pushed(args, cwd):
    """git push <remote> <src>:<dst> qui pousse une autre branche sur la branche par défaut."""
    if PUSH_SKIP & set(args):
        return None
    positional, i = [], 0
    while i < len(args):
        if args[i] in PUSH_OPTS_WITH_VALUE:
            i += 1
        elif not args[i].startswith("-"):
            positional.append(args[i])
        i += 1
    if len(positional) < 2:
        return None
    remote = positional[0]
    head = git_out(cwd, "symbolic-ref", "--quiet", "--short", f"refs/remotes/{remote}/HEAD")
    defaults = {head.split("/", 1)[1]} if head and "/" in head else {"main", "master"}
    for refspec in positional[1:]:
        src, sep, dst = refspec.lstrip("+").partition(":")
        dst = dst.removeprefix("refs/heads/")
        if not sep or not src or dst not in defaults:
            continue
        if src in ("HEAD", "@"):
            src = git_out(cwd, "symbolic-ref", "--quiet", "--short", "HEAD")
        else:
            src = src.removeprefix("refs/heads/")
        if src and src != dst and not SHA.match(src):
            return f"branche {src} poussée sur {dst}", [src]
    return None


def merged(seg, cwd=None):
    """(ce que le segment a mergé, arguments de gbr cleanup), None si ce n'est pas un merge."""
    i = 0
    while i < len(seg) and (ASSIGNMENT.match(seg[i]) or seg[i] in WRAPPERS):
        i += 1
    seg = seg[i:]
    if seg[:3] == ["gh", "pr", "merge"]:
        args = seg[3:]
        if "--auto" in args:
            return None
        target = next((a for a in args if not a.startswith("-")), None)
        if target:
            return f"PR {target}", ["--pr", target]
        return "PR de la branche courante", []
    if seg[:1] == ["git"]:
        i = 1
        while i < len(seg) and seg[i].startswith("-"):
            if seg[i] == "-C" and i + 1 < len(seg):
                cwd = os.path.join(cwd or os.getcwd(), seg[i + 1])
            i += 2 if seg[i] in GIT_OPTS_WITH_VALUE else 1
        if seg[i:i + 1] == ["push"]:
            return pushed(seg[i + 1:], cwd)
        if seg[i:i + 1] != ["merge"]:
            return None
        args = seg[i + 1:]
        if GIT_MERGE_SKIP & set(args):
            return None
        branches, i = [], 0
        while i < len(args):
            if args[i] in MERGE_OPTS_WITH_VALUE:
                i += 1
            elif not args[i].startswith("-"):
                branches.append(args[i])
            i += 1
        return ("branche " + ", ".join(branches), branches[:1]) if branches else None
    return None


def plan(args, cwd):
    """Sortie de gbr cleanup --dry-run (plan ou raison d'arrêt), None si illisible."""
    try:
        out = subprocess.run([GBR, "cleanup", "--dry-run", *args], cwd=cwd or None,
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    return (out.stdout + out.stderr).strip() or None


def main():
    try:
        data = json.load(sys.stdin)
        command = data["tool_input"]["command"]
        cwd = data.get("cwd")
        found = [m for m in (merged(seg, cwd) for seg in segments(command)) if m]
    except (ValueError, KeyError, TypeError):
        return
    if not found:
        return
    label, args = found[-1]
    context = (
        "Merge effectué (" + " ; ".join(m[0] for m in found) + "). Enchaîner sur le skill "
        "git-nav:branch-cleanup pour proposer le ménage de la branche mergée "
        "(worktree, branche locale, sauvegardes, branche distante), sauf si l'utilisateur a "
        "dit de garder la branche."
    )
    if os.environ.get("MERGE_WATCH_NO_PLAN") != "1":
        out = plan(args, cwd)
        if out:
            context += f"\n\ngbr cleanup --dry-run {' '.join(args)} :\n{out}"
    json.dump({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                                      "additionalContext": context}}, sys.stdout)


if __name__ == "__main__":
    main()
