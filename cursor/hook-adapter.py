#!/usr/bin/env python3
"""Adaptateur des hooks d'un plugin Claude Code converti pour Cursor (cursor/convert.py).

Appel (écrit par convert.py dans le hooks/hooks.json généré) :
    python3 hook-adapter.py <événement Claude> <commande du hook Claude>

Lit le JSON de l'événement Cursor sur stdin, le traduit au format Claude, lance la commande
d'origine (bash -c, CLAUDE_PLUGIN_ROOT = dossier du plugin installé), puis traduit sa réponse
au format Cursor. Répond toujours un JSON valide : sans décision, « {} » (ou « continue »
pour beforeSubmitPrompt), Cursor poursuit normalement.
"""
import json
import os
import subprocess
import sys

# Outils Cursor -> Claude (preToolUse, postToolUse).
TOOLS_TO_CLAUDE = {"Shell": "Bash", "Read": "Read", "Write": "Write", "Grep": "Grep",
                   "Delete": "Bash", "Task": "Task"}


def claude_input(event, cur):
    roots = cur.get("workspace_roots") or []
    cwd = cur.get("cwd") or (roots[0] if roots else os.getcwd())
    out = {
        "session_id": cur.get("session_id") or cur.get("conversation_id", ""),
        "transcript_path": cur.get("transcript_path") or "",
        "cwd": cwd,
        "hook_event_name": event,
    }
    if event in ("PreToolUse", "PostToolUse"):
        tool = cur.get("tool_name", "")
        if tool.startswith("MCP:"):
            tool = "mcp__" + tool[4:].strip()
        out["tool_name"] = TOOLS_TO_CLAUDE.get(tool, tool)
        out["tool_input"] = cur.get("tool_input") or {}
        out["tool_use_id"] = cur.get("tool_use_id", "")
        if event == "PostToolUse":
            out["tool_response"] = cur.get("tool_output", cur.get("tool_response", ""))
    elif event == "UserPromptSubmit":
        out["prompt"] = cur.get("prompt", "")
    elif event == "SessionStart":
        out["source"] = "startup"
    elif event == "SessionEnd":
        out["reason"] = cur.get("reason", "other")
    elif event == "Stop":
        out["stop_hook_active"] = bool(cur.get("loop_count"))
    elif event == "StopFailure":
        out["error"] = cur.get("status", "error")
    return out, cwd


def parse(stdout):
    s = stdout.strip()
    if s.startswith("{"):
        try:
            return json.loads(s), ""
        except ValueError:
            pass
    return {}, s


def cursor_output(event, code, stdout, stderr):
    data, text = parse(stdout)
    spec = data.get("hookSpecificOutput") or {}
    reason = spec.get("permissionDecisionReason") or data.get("reason") or ""
    blocked = code == 2 or data.get("decision") == "block"
    if code == 2:
        reason = stderr.strip() or reason
    context = spec.get("additionalContext") or ""

    if event == "PreToolUse":
        decision = spec.get("permissionDecision") or ("deny" if blocked else "")
        if decision == "deny":
            return {"permission": "deny", "user_message": reason, "agent_message": reason}
        res = {"permission": "allow"} if decision == "allow" else {}
        if spec.get("updatedInput"):
            res["updated_input"] = spec["updatedInput"]
        return res
    if event == "SessionStart":
        context = context or (text if code == 0 else "")
        return {"additional_context": context} if context else {}
    if event == "PostToolUse":
        context = context or (reason if blocked else "")
        return {"additional_context": context} if context else {}
    if event == "UserPromptSubmit":
        return {"continue": False, "user_message": reason} if blocked else {"continue": True}
    if event in ("Stop", "SubagentStop"):
        return {"followup_message": reason} if blocked and reason else {}
    return {}


def main():
    if len(sys.argv) != 3:
        print("usage : hook-adapter.py <événement Claude> <commande>", file=sys.stderr)
        print("{}")
        return
    event, command = sys.argv[1], sys.argv[2]
    try:
        cur = json.load(sys.stdin)
    except ValueError:
        cur = {}
    # Cursor n'a qu'un événement stop : Stop pour une fin normale, StopFailure sur erreur.
    status = cur.get("status")
    if (event == "Stop" and status == "error") or (event == "StopFailure" and status != "error"):
        print("{}")
        return

    payload, cwd = claude_input(event, cur)
    root = os.environ.get("CURSOR_PLUGIN_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    env = dict(os.environ, CLAUDE_PLUGIN_ROOT=root, CLAUDE_PROJECT_DIR=cwd)
    try:
        proc = subprocess.run(["bash", "-c", command], input=json.dumps(payload), capture_output=True,
                              text=True, env=env, cwd=cwd if os.path.isdir(cwd) else None)
        code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
    except OSError as e:
        code, stdout, stderr = 1, "", str(e)
    if stderr and code not in (0, 2):
        sys.stderr.write(stderr)
    res = cursor_output(event, code, stdout, stderr)
    if not res and event == "UserPromptSubmit":
        res = {"continue": True}
    json.dump(res, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
