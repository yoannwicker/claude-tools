#!/usr/bin/env python3
"""Hook PreToolUse (Bash) du plugin build-brief : refuse une commande qui lance gradle ou
gradlew sans build-brief.

Laisse passer : build-brief absent du PATH, segment préfixé par BUILD_BRIEF_BYPASS=1,
appel dont toutes les options sont --stop/--status/--version/-v, entrée ou commande
illisible. Non inspectés : bash -c '…', eval, scripts.
"""
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

GRADLE = {"gradle", "gradlew"}
WRAPPERS = {"time", "nohup", "exec", "command", "env"}
INFO_ONLY = {"--stop", "--status", "--version", "-v"}
SEPARATOR_CHARS = set("();|&\n")
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
HEREDOC = re.compile(r"<<-?[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def strip_heredocs(command):
    """Retire le corps des heredocs (texte, pas des commandes)."""
    lines = command.split("\n")
    out, end = [], None
    for line in lines:
        if end is not None:
            if line.strip() == end:
                end = None
            continue
        out.append(line)
        m = HEREDOC.search(line)
        if m:
            end = m.group(2)
    return "\n".join(out)


def segments(command):
    lexer = shlex.shlex(strip_heredocs(command), posix=True, punctuation_chars="();<>|&\n")
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


def raw_gradle(seg):
    """Vrai si le segment lance gradle/gradlew sans build-brief ni exception."""
    i, bypass = 0, False
    while i < len(seg) and (ASSIGNMENT.match(seg[i]) or seg[i] in WRAPPERS):
        bypass = bypass or seg[i] == "BUILD_BRIEF_BYPASS=1"
        i += 1
    if i >= len(seg) or os.path.basename(seg[i]) not in GRADLE or bypass:
        return False
    args = seg[i + 1:]
    return not (args and set(args) <= INFO_ONLY)


def offending(command):
    return [" ".join(s) for s in segments(command) if raw_gradle(s)]


def suggestion(command):
    try:
        out = subprocess.run(["build-brief", "rewrite", command], capture_output=True,
                             text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    return out if out and out != command.strip() else None


def main():
    if not shutil.which("build-brief"):
        return
    try:
        command = json.load(sys.stdin)["tool_input"]["command"]
        found = offending(command)
    except (ValueError, KeyError, TypeError):
        return
    if not found:
        return
    fix = suggestion(command)
    reason = (
        "Gradle lancé sans build-brief (" + " ; ".join(found) + "). "
        + (f"Relancer : {fix}. " if fix else "Préfixer chaque appel Gradle par build-brief (build-brief ./gradlew …). ")
        + "Plus de détail sans quitter build-brief : --stacktrace, le log brut dont il donne le chemin, "
        "puis build-brief --mode raw ./gradlew …. Dernier recours seulement : BUILD_BRIEF_BYPASS=1 ./gradlew …."
    )
    json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                      "permissionDecision": "deny",
                                      "permissionDecisionReason": reason}}, sys.stdout)


if __name__ == "__main__":
    main()
