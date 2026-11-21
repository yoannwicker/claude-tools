#!/usr/bin/env python3
"""Convertit un plugin Claude Code de ce dépôt en plugin Cursor (dossier local).

    python3 cursor/convert.py [--as <chemin installé>] <plugins/<plugin>> <dossier de sortie>

Le dossier de sortie (en pratique ~/.cursor/plugins/local/<plugin>, voir ./install.sh plugin
--cursor) est régénéré en entier : copie du plugin, sauf ce qui ne sert qu'à Claude ou au
dépôt, avec :
- .cursor-plugin/plugin.json tiré de .claude-plugin/plugin.json ;
- ${CLAUDE_PLUGIN_ROOT} et ${CLAUDE_SKILL_DIR} remplacés par leur chemin installé dans les
  skills, agents, commandes et le MCP (.mcp.json devient mcp.json) ;
- hooks/hooks.json réécrit au format Cursor, chaque commande passant par
  .claude-compat/hook-adapter.py, qui traduit l'entrée et la réponse ;
- par-dessus, le dossier cursor/ du plugin s'il existe (version Cursor de certains fichiers ;
  son hooks/hooks.json, au format Claude ou Cursor, remplace celui du plugin avant conversion).

--as : chemins écrits comme si le dossier était installé là (comparaison par ./install.sh
status avec la version installée).
Un dossier de sortie existant n'est remplacé que s'il a été généré ici (.claude-compat/source).
Les avertissements sortent sur stdout, une ligne « note <message> » chacun.
"""
import json
import os
import re
import shlex
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MARKER = ".claude-compat"
EXCLUDED = {".claude-plugin", "tests", "setup.sh", "cursor", ".mcp.json", "__pycache__"}
EVENTS = {
    "SessionStart": "sessionStart", "SessionEnd": "sessionEnd",
    "PreToolUse": "preToolUse", "PostToolUse": "postToolUse",
    "UserPromptSubmit": "beforeSubmitPrompt", "Stop": "stop", "StopFailure": "stop",
    "SubagentStop": "subagentStop", "PreCompact": "preCompact",
}
TOOLS = {"Bash": "Shell", "Read": "Read", "Write": "Write", "Edit": "Write", "MultiEdit": "Write",
         "NotebookEdit": "Write", "Grep": "Grep", "Glob": "Grep", "Task": "Task", "Agent": "Task"}
MANIFEST_FIELDS = ("name", "description", "version", "author", "homepage", "repository",
                   "license", "keywords")

notes = []


def note(msg):
    notes.append(msg)


def tool_matcher(matcher):
    """Matcher d'outils Claude -> Cursor ; None : tous les outils."""
    if not matcher or matcher == "*":
        return None
    names = matcher.split("|")
    if not all(re.fullmatch(r"[A-Za-z_][\w-]*", n) for n in names):
        note(f"matcher « {matcher} » gardé tel quel (expression, pas une liste d'outils)")
        return matcher
    out = []
    for n in names:
        if n.startswith("mcp__"):
            m = "MCP:" + n.split("__", 2)[-1]
        else:
            m = TOOLS.get(n, n)
        if m not in out:
            out.append(m)
    return "|".join(out)


def convert_hooks(src):
    """hooks.json Claude (ou déjà Cursor pour les événements en camelCase) -> hooks.json Cursor."""
    hooks = {}
    if src.get("modules"):
        note("mod d'interface (" + ", ".join(src["modules"]) + ") : pas d'équivalent dans Cursor")
    for event, groups in (src.get("hooks") or {}).items():
        if event[:1].islower():  # déjà au format Cursor (dossier cursor/ du plugin)
            hooks.setdefault(event, []).extend(groups)
            continue
        target = EVENTS.get(event)
        if not target:
            note(f"hook {event} : pas d'équivalent dans Cursor")
            continue
        for group in groups:
            matcher = group.get("matcher")
            if event in ("PreToolUse", "PostToolUse"):
                matcher = tool_matcher(matcher)
            elif event == "SessionStart":
                # Cursor ne dit pas d'où vient la session : l'adaptateur annonce « startup ».
                if matcher and not re.search(matcher, "startup"):
                    note(f"hook SessionStart « {matcher} » ignoré (ne vise pas le démarrage)")
                    continue
                matcher = None
            else:
                matcher = None
            for h in group.get("hooks", []):
                if h.get("type", "command") != "command":
                    note(f"hook {event} de type {h.get('type')} ignoré")
                    continue
                entry = {"command": 'python3 "${CURSOR_PLUGIN_ROOT}/%s/hook-adapter.py" %s %s'
                                    % (MARKER, event, shlex.quote(h["command"]))}
                if matcher:
                    entry["matcher"] = matcher
                if h.get("timeout"):
                    entry["timeout"] = h["timeout"]
                hooks.setdefault(target, []).append(entry)
    return {"version": 1, "hooks": hooks}


def substitute(path, out, installed, skill_dir=None):
    """Chemins Claude -> chemins installés (installed = out, sauf avec --as)."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except (UnicodeDecodeError, OSError):
        return
    new = text.replace("${CLAUDE_PLUGIN_ROOT}", installed)
    if skill_dir:
        new = new.replace("${CLAUDE_SKILL_DIR}", os.path.join(installed, os.path.relpath(skill_dir, out)))
    if "${CLAUDE_SESSION_ID}" in new:
        note(f"{os.path.relpath(path, out)} : ${{CLAUDE_SESSION_ID}} n'a pas d'équivalent dans Cursor")
    if new != text:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new)


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def convert(src, out, installed=None):
    src, out = os.path.abspath(src), os.path.abspath(out)
    installed = os.path.abspath(installed or out)
    name = os.path.basename(src)
    if os.path.lexists(out):
        if not os.path.isfile(os.path.join(out, MARKER, "source")):
            sys.exit(f"{out} existe et n'a pas été généré par cursor/convert.py : rien n'est remplacé")
        shutil.rmtree(out)

    claude_hooks = os.path.join(src, "hooks", "hooks.json")
    overlay = os.path.join(src, "cursor")
    modules = set()
    if os.path.isfile(claude_hooks):
        modules = {os.path.normpath(os.path.join("hooks", m)) for m in read_json(claude_hooks).get("modules", [])}

    def ignore(d, names):
        rel = os.path.relpath(d, src)
        skip = set()
        for n in names:
            r = os.path.normpath(os.path.join(rel, n))
            if (rel == "." and n in EXCLUDED) or n == "__pycache__" or n.endswith(".pyc") \
                    or r == os.path.join("hooks", "hooks.json") or r in modules:
                skip.add(n)
        return skip

    shutil.copytree(src, out, ignore=ignore)
    if os.path.isdir(overlay):
        shutil.copytree(overlay, out, dirs_exist_ok=True)

    # Manifeste : celui de Claude, complété par un .cursor-plugin/plugin.json du dossier cursor/.
    manifest = {k: v for k, v in read_json(os.path.join(src, ".claude-plugin", "plugin.json")).items()
                if k in MANIFEST_FIELDS}
    manifest["name"] = manifest.get("name") or name
    cursor_manifest = os.path.join(out, ".cursor-plugin", "plugin.json")
    if os.path.isfile(cursor_manifest):
        manifest.update(read_json(cursor_manifest))
    write_json(cursor_manifest, manifest)

    # Chemins Claude remplacés par leurs chemins installés.
    for kind in ("skills", "agents", "commands"):
        base = os.path.join(out, kind)
        for d, _, files in os.walk(base):
            rel = os.path.relpath(d, base).split(os.sep)
            skill_dir = os.path.join(base, rel[0]) if kind == "skills" and rel[0] != "." else None
            for f in files:
                substitute(os.path.join(d, f), out, installed, skill_dir)

    mcp = os.path.join(src, ".mcp.json")
    if os.path.isfile(mcp) and not os.path.isfile(os.path.join(out, "mcp.json")):
        shutil.copyfile(mcp, os.path.join(out, "mcp.json"))
    if os.path.isfile(os.path.join(out, "mcp.json")):
        substitute(os.path.join(out, "mcp.json"), out, installed)

    # Hooks : ceux du dossier cursor/ s'il en a, sinon ceux du plugin.
    hooks_src = os.path.join(overlay, "hooks", "hooks.json")
    if not os.path.isfile(hooks_src):
        hooks_src = claude_hooks
    target = os.path.join(out, "hooks", "hooks.json")
    if os.path.isfile(hooks_src):
        converted = convert_hooks(read_json(hooks_src))
        if converted["hooks"]:
            write_json(target, converted)
        elif os.path.exists(target):
            os.remove(target)

    os.makedirs(os.path.join(out, MARKER), exist_ok=True)
    shutil.copy2(os.path.join(HERE, "hook-adapter.py"), os.path.join(out, MARKER, "hook-adapter.py"))
    with open(os.path.join(out, MARKER, "source"), "w", encoding="utf-8") as f:
        f.write(src + "\n")


def main():
    args = sys.argv[1:]
    installed = None
    if args[:1] == ["--as"] and len(args) > 1:
        installed, args = args[1], args[2:]
    if len(args) != 2:
        sys.exit("usage : convert.py [--as <chemin installé>] <dossier du plugin> <dossier de sortie>")
    convert(args[0], args[1], installed)
    for n in notes:
        print("note " + n)


if __name__ == "__main__":
    main()
