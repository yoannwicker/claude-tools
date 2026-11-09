"""watchlib — mécanique commune des watchers GitHub de claude-tools (review-watch du plugin
review, tidy-watch du plugin git-tidy) : config et état, clone et worktree, lancement d'une
session Claude (herdr, ou analyse en fond reprise au clic), notifications, timer systemd,
commandes communes.

Plugin gh-watch, dépendance déclarée de review et git-tidy. Chaque watcher se déclare
par un lien ~/.config/claude-tools/watchers.d/<nom> vers son script (posé par le setup.sh
de son plugin) : `gh-watch status` les supervise tous.

Le watcher appelle configure(...) avec ses réglages, puis main(events=…).

Rattrapage automatique (`gh-watch set board_auto on`, /gh-watch:board-auto) : à la fin du
premier `poll` de la journée de l'un des watchers, `gh-watch board --all --missed --json`
lancé en détaché, et une notification s'il y a des actions manquées (voir catchup_*).
"""
import argparse, datetime as dt, fcntl, json, os, re, shlex, shutil, subprocess, sys, uuid
from types import SimpleNamespace

HOME = os.path.expanduser("~")
MODES = ("auto", "notify", "off")
INTERVAL = 5  # min entre deux passages ; surchargé par `interval` (drop-in du timer)
DELAY = 300  # s sans nouvelle review avant de lancer : une revue en plusieurs envois
# Analyse en fond (claude -p, personne pour accepter) : lecture seule
BACKGROUND_TOOLS = [
    "Read", "Grep", "Glob", "Agent",
    "Bash(git log:*)", "Bash(git show:*)", "Bash(git diff:*)", "Bash(git blame:*)",
    "Bash(git rev-parse:*)", "Bash(git branch:*)", "Bash(git status:*)", "Bash(git fetch:*)",
    "Bash(git worktree list:*)", "Bash(git merge-base:*)", "Bash(git cat-file:*)",
    "Bash(git rev-list:*)", "Bash(git merge-tree:*)", "Bash(git ls-remote:*)",
    "Bash(git symbolic-ref:*)",
    "Bash(gh pr view:*)", "Bash(gh pr diff:*)", "Bash(gh pr list:*)", "Bash(gh issue view:*)",
    "Bash(gh repo view:*)", "Bash(gh api user:*)", "Bash(gh api graphql:*)",
    "Bash(gh api repos:*)", "Bash(gpr list:*)", "Bash(gpr view:*)",
    "mcp__claude_ai_Atlassian_Rovo__getAccessibleAtlassianResources",
    "mcp__claude_ai_Atlassian_Rovo__getJiraIssue",
    "mcp__claude_ai_Atlassian_Rovo__getTransitionsForJiraIssue",
    "mcp__claude_ai_Atlassian_MCP__getAccessibleAtlassianResources",
    "mcp__claude_ai_Atlassian_MCP__getJiraIssue",
    "mcp__plugin_intellij_intellij__search_symbol", "mcp__plugin_intellij_intellij__search_text",
    "mcp__plugin_intellij_intellij__search_regex", "mcp__plugin_intellij_intellij__search_structural",
    "mcp__plugin_intellij_intellij__get_symbol_info", "mcp__plugin_intellij_intellij__analyze_calls",
    "mcp__plugin_intellij_intellij__search_file", "mcp__plugin_intellij_intellij__read_file",
]

S = SimpleNamespace()  # réglages du watcher, posés par configure()


# --- gh-watch (supervision, tableau) : config, état, commande ---------------------------------

def gh_watch_config():
    """Config de gh-watch (réglages de board, board_auto)."""
    return os.environ.get("GH_WATCH_CONFIG") or os.path.join(
        os.environ.get("XDG_CONFIG_HOME", f"{HOME}/.config"), "claude-tools", "gh-watch.json")


def gh_watch_state():
    """État de gh-watch (lignes écartées) ; le rattrapage vit à côté (catchup.json)."""
    return os.environ.get("GH_WATCH_STATE") or os.path.join(
        os.environ.get("XDG_STATE_HOME", f"{HOME}/.local/state"), "claude-tools", "gh-watch", "state.json")


def gh_watch_catchup():
    return os.path.join(os.path.dirname(gh_watch_state()), "catchup.json")


def gh_watch_bin():
    """bin/gh-watch du plugin, à côté de lib/ (le PATH d'un timer systemd n'a pas ~/.local/bin) ;
    GH_WATCH_BIN : tests."""
    return os.environ.get("GH_WATCH_BIN") or os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "bin", "gh-watch")


def configure(name, env, self_path, kinds, skill, label, tab, defaults, announce, tell,
              guess_kind, config=None, worktrees=None, detached=(), extra=None, default_kinds=None, repo_extra=None,
              board=None, suggest=None):
    """name : nom de la commande (review-watch) ; env : préfixe des variables d'environnement
    (REVIEW_WATCH : _CONFIG, _STATE, _NOTIFY_LOG) ; config : nom du fichier de config dans
    ~/.config/claude-tools/ (<name>.json par défaut) ; worktrees : dossier des worktrees
    d'analyse en fond dans ~/.cache/claude-tools/ (<name>-worktrees par défaut) ; kinds : événements ; skill[kind] :
    commande lancée (« review:pr 12 » → « /review:pr 12 ») ; label/tab/announce[kind] :
    libellé, onglet herdr, titre de notification ; tell[kind] : message à une session herdr
    déjà ouverte ({n}, {when}) ; guess_kind(state, repo, n) : événement de `launch` sans
    événement donné ; detached : événements lancés sur une branche agent/ à la
    tête de la PR (relecture), les autres sur la branche de la PR ; default_kinds : événements
    d'`auto` sans événement (tous par défaut) ; repo_extra(cfg, repo) : texte ajouté aux
    lignes de dépôt ; extra : dict ajouté à `repos --json` (repo → dict) ; board : états du
    tableau de `gh-watch board` que le watcher prend en charge (état → kind) ; suggest :
    skill proposé par le tableau pour un état ou une alerte, sans le lancer (« behind » →
    « git-tidy:pr-sync »)."""
    cfgdir = os.environ.get("XDG_CONFIG_HOME", f"{HOME}/.config")
    S.name, S.env, S.self = name, env, os.path.realpath(self_path)
    S.config = os.environ.get(f"{env}_CONFIG") or os.path.join(cfgdir, "claude-tools", config or f"{name}.json")
    S.state_dir = os.environ.get(f"{env}_STATE") or os.path.join(
        os.environ.get("XDG_STATE_HOME", f"{HOME}/.local/state"), "claude-tools", name)
    S.state = os.path.join(S.state_dir, "state.json")
    S.worktrees = os.path.join(os.environ.get("XDG_CACHE_HOME", f"{HOME}/.cache"), "claude-tools",
                               worktrees or f"{name}-worktrees")
    S.timer = f"{name}.timer"
    S.dropin = os.path.join(cfgdir, "systemd", "user", f"{S.timer}.d", "interval.conf")
    S.kinds, S.skill, S.label, S.tab = tuple(kinds), skill, label, tab
    S.defaults, S.announce, S.tell, S.detached = defaults, announce, tell, set(detached)
    S.default_kinds = tuple(default_kinds or kinds)
    S.guess_kind = guess_kind
    S.repo_extra = repo_extra or (lambda cfg, repo: "")
    S.extra = extra or (lambda cfg, repo: {})
    S.board, S.suggest = board or {}, suggest or {}


def die(msg, code=1):
    print(f"{S.name}: {msg}", file=sys.stderr)
    sys.exit(code)


def now():
    return dt.datetime.now(dt.timezone.utc)


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def run(cmd, cwd=None, check=True):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"{' '.join(cmd[:4])}… : {(r.stderr or r.stdout).strip()}")
    return r.stdout


# --- config et état -----------------------------------------------------------------------

def load_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)


class State:
    """state.json sous verrou : un seul poll/launch à la fois."""

    def __enter__(self):
        os.makedirs(S.state_dir, exist_ok=True)
        self.lock = open(f"{S.state}.lock", "w")
        fcntl.flock(self.lock, fcntl.LOCK_EX)
        self.data = load_json(S.state)
        for k in (*S.kinds, "sessions", "clones"):
            self.data.setdefault(k, {})
        return self.data

    def __exit__(self, *exc):
        save_json(S.state, self.data)
        self.lock.close()


def repo_cfg(cfg, repo):
    """Réglages du dépôt (noms GitHub insensibles à la casse)."""
    return next((r for k, r in cfg.get("repos", {}).items() if k.lower() == repo.lower()), {})


def setting(cfg, repo, key, default=None):
    """Réglage du dépôt, sinon de `default`, sinon la valeur par défaut donnée."""
    v = repo_cfg(cfg, repo).get(key) if repo else None
    return v if v is not None else cfg.get("default", {}).get(key, default)


def mode(cfg, repo, kind):
    return setting(cfg, repo, kind) or S.defaults[kind]


def claude_cmd(cfg):
    return shlex.split(cfg.get("claude") or "claude")


# --- GitHub ---------------------------------------------------------------------------------

def gh_json(*args):
    out = run(["gh", "api", *args])
    return json.loads(out) if out.strip() else None


def graphql(query, **variables):
    args = ["graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    data = gh_json(*args)
    if data.get("errors"):
        raise RuntimeError(data["errors"][0].get("message"))
    return data["data"]


def me(state):
    if not state.get("me"):
        state["me"] = gh_json("user")["login"]
    return state["me"]


# --- clone local et worktree ----------------------------------------------------------------

def remote_repo(path):
    try:
        url = run(["git", "-C", path, "remote", "get-url", "origin"]).strip()
    except RuntimeError:
        return None
    m = re.search(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$", url)
    return m.group(1).lower() if m else None


def workspaces():
    f = os.path.join(os.environ.get("XDG_CONFIG_HOME", f"{HOME}/.config"), "cl", "workspaces")
    dirs = []
    try:
        with open(f, encoding="utf-8") as fh:
            dirs = [os.path.expanduser(l.strip()) for l in fh if l.strip() and not l.startswith("#")]
    except FileNotFoundError:
        pass
    return dirs or [os.path.join(HOME, d) for d in sorted(os.listdir(HOME)) if d.startswith("workspace")]


def clone_path(cfg, state, repo):
    """Clone du dépôt : `path` de la config, sinon cherché (et retenu) dans les espaces de
    travail de `cl` (~/workspace* à défaut)."""
    p = repo_cfg(cfg, repo).get("path") or state["clones"].get(repo.lower())
    if p and os.path.isdir(os.path.expanduser(p)):
        return os.path.expanduser(p)
    for ws in workspaces():
        if not os.path.isdir(ws):
            continue
        for d in sorted(os.listdir(ws)):
            p = os.path.join(ws, d)
            if os.path.exists(os.path.join(p, ".git")) and remote_repo(p) == repo.lower():
                state["clones"][repo.lower()] = p
                return p
    return None


def worktree_for(clone, branch):
    cur = None
    for line in run(["git", "-C", clone, "worktree", "list", "--porcelain"]).splitlines():
        if line.startswith("worktree "):
            cur = line[9:]
        elif line == f"branch refs/heads/{branch}":
            return cur
    return None


def ensure_worktree(clone, branch, base, root):
    """Dossier où `branch` est extraite : celui qui l'a déjà, sinon un worktree créé sous
    `root` (branche créée depuis `base` si elle n'existe pas en local)."""
    p = worktree_for(clone, branch)
    if p:
        return p
    p = os.path.join(root, os.path.basename(clone), branch.replace("/", "-"))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    exists = subprocess.run(["git", "-C", clone, "show-ref", "--verify", "--quiet",
                             f"refs/heads/{branch}"]).returncode == 0
    if exists:
        run(["git", "-C", clone, "worktree", "add", p, branch])
    else:
        run(["git", "-C", clone, "worktree", "add", "--track", "-b", branch, p, base]
            if base.startswith("origin/") else
            ["git", "-C", clone, "worktree", "add", "-b", branch, p, base])
    return p


def slug(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return s[:40].rstrip("-") or "pr"


# --- herdr ------------------------------------------------------------------------------------

def herdr_running():
    if not shutil.which("herdr"):
        return False
    r = subprocess.run(["herdr", "status", "server"], capture_output=True, text=True, timeout=5)
    return r.returncode == 0 and "status: running" in r.stdout


def herdr(*args):
    return json.loads(run(["herdr", *args]))["result"]


def herdr_alive(session):
    if session.get("mode") != "herdr":
        return False
    try:
        herdr("agent", "get", session["pane"])  # échoue si Claude est sorti du pane
        return True
    except Exception:
        return False


def herdr_tell(pane, kind, n, at=None):
    """Envoie S.tell[kind] à l'agent du pane. herdr refuse si l'agent attend une réponse
    (question, permission) : rien n'est alors tapé dans la question. Retourne True si envoyé."""
    when = f" ({parse(at).astimezone().strftime('%H:%M')})" if at else ""
    try:
        r = subprocess.run(["herdr", "agent", "prompt", pane, S.tell[kind].format(n=n, when=when)],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return r.returncode == 0


def herdr_open(clone, path, label):
    """Pane dans un workspace herdr sur `path` : nouvel onglet si un workspace l'a déjà
    ouvert, sinon workspace de worktree (herdr worktree open)."""
    try:
        listing = herdr("worktree", "list", "--cwd", clone)
        ws = next((w.get("open_workspace_id") for w in listing.get("worktrees", [])
                   if os.path.realpath(w["path"]) == os.path.realpath(path)), None)
    except Exception:
        ws = None
    if ws:
        res = herdr("tab", "create", "--workspace", ws, "--cwd", path, "--label", label, "--no-focus")
    else:
        res = herdr("worktree", "open", "--cwd", clone, "--path", path, "--label", label, "--no-focus")
    pane = res["root_pane"]
    return pane["workspace_id"], pane["pane_id"]


# --- notifications --------------------------------------------------------------------------

def notify(title, body, action=None, urgency="normal"):
    """Notification desktop ; `action` (argv) est lancé au clic. Rend la main tout de suite."""
    payload = {"title": title, "body": body, "action": action, "urgency": urgency}
    log = os.environ.get(f"{S.env}_NOTIFY_LOG")  # tests
    if log:
        with open(log, "a", encoding="utf-8") as f:
            f.write(json.dumps(payload, ensure_ascii=False) + "\n")
        return
    print(f"notification : {title} — {body}")
    detach([sys.executable, S.self, "_notify", json.dumps(payload)])


def detach(cmd, cwd=None, log=None):
    out = open(log, "a") if log else subprocess.DEVNULL
    subprocess.Popen(cmd, cwd=cwd, stdin=subprocess.DEVNULL, stdout=out, stderr=out,
                     start_new_session=True)


def notify_wait(payload):
    try:
        import gi
        gi.require_version("Notify", "0.7")
        from gi.repository import GLib, Notify
    except (ImportError, ValueError):
        if shutil.which("notify-send"):
            body = payload["body"]
            if payload.get("action"):
                body += "\n" + shlex.join(payload["action"])
            subprocess.run(["notify-send", "-a", "Claude Code", payload["title"], body])
        return
    Notify.init("Claude Code")
    n = Notify.Notification.new(payload["title"], payload["body"])
    n.set_urgency(Notify.Urgency.CRITICAL if payload.get("urgency") == "critical" else Notify.Urgency.NORMAL)
    loop, clicked = GLib.MainLoop(), []
    if payload.get("action"):
        n.add_action("default", "Ouvrir", lambda *_: (clicked.append(1), loop.quit()), None)
    n.connect("closed", lambda *_: loop.quit())
    n.show()
    GLib.timeout_add_seconds(12 * 3600, loop.quit)  # la notification reste, le clic ne fait plus rien
    loop.run()
    if clicked:
        subprocess.run(payload["action"])


# --- lancement --------------------------------------------------------------------------------

# --- rattrapage quotidien (board_auto) ---------------------------------------------------------

def today():
    return dt.datetime.now().astimezone().date().isoformat()


def catchup_due():
    """board_auto à on et pas encore de rattrapage aujourd'hui (date locale) : retient la
    journée (sous verrou, pour qu'un autre watcher ne le relance pas) et retourne True."""
    if load_json(gh_watch_config()).get("board_auto") != "on":
        return False
    path = gh_watch_catchup()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(f"{path}.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        last = load_json(path)
        if last.get("day") == today():
            return False
        save_json(path, {**last, "day": today(), "started": iso(now()), "by": S.name, "finished": None})
    return True


def catchup_run():
    """`<watcher> _catchup`, en détaché : gh-watch board --all --missed --json, résultat
    retenu dans catchup.json, et une seule notification « N actions manquées » s'il y en a
    (clic : catchup_open)."""
    path = gh_watch_catchup()
    try:
        rows = json.loads(run([gh_watch_bin(), "board", "--all", "--missed", "--json"]))["prs"]
        error = None
    except Exception as e:
        rows, error = [], str(e)[:300]
    keep = ("repo", "n", "title", "url", "state", "short", "event_at", "since")
    with open(f"{path}.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        rec = load_json(path)
        rec.update(finished=iso(now()), error=error, count=len(rows),
                   rows=[{**{k: r.get(k) for k in keep}, "watcher": r["watch"]["watcher"],
                          "kind": r["watch"]["kind"]} for r in rows])
        save_json(path, rec)
    if error:
        print(f"rattrapage en échec : {error}")
        return
    if not rows:
        print("rattrapage : aucune action manquée")
        return
    s = "s" if len(rows) > 1 else ""
    lines = [f"{r['repo']}#{r['n']} {r['short']}" for r in rows[:4]] + (["…"] if len(rows) > 4 else [])
    notify(f"{len(rows)} action{s} manquée{s}", "\n".join(lines) + "\nclic : gh-watch board --all --missed -i",
           [sys.executable, S.self, "_catchup_open"])


def catchup_open(cfg):
    """Clic sur la notification du rattrapage : la liste des manquées (gh-watch board --all
    --missed -i) dans un workspace herdr s'il tourne, sinon dans un terminal."""
    argv = [gh_watch_bin(), "board", "--all", "--missed", "-i"]
    if herdr_running():
        pane = herdr("workspace", "create", "--cwd", HOME, "--label", "manquées", "--focus")["root_pane"]["pane_id"]
        keep = ' || { printf "\\n(Entrée pour fermer) "; read x; }'  # une erreur reste lisible
        run(["herdr", "pane", "run", pane, "exec sh -c " + shlex.quote(shlex.join(argv) + keep)])
        return
    cmd = terminal_cmd(cfg, HOME, argv)
    if not cmd:
        notify("Actions manquées : pas de terminal", "lancer : gh-watch board --all --missed -i", urgency="critical")
        return
    detach(cmd, cwd=HOME)


def key_of(repo, n, kind):
    return f"{repo}#{n}:{kind}"


def pid_alive(pid):
    if not pid:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def launch(cfg, state, repo, n, kind, at=None, background=False):
    """Lance la session de `kind` sur la PR (`at` : date de l'événement) : herdr s'il tourne,
    sinon (ou avec background) analyse en fond (--prepare) reprise au clic de la
    notification. Retourne une ligne de compte rendu."""
    key = key_of(repo, n, kind)
    prev = state["sessions"].get(key)
    if prev and herdr_alive(prev):
        told = herdr_tell(prev["pane"], kind, n, at)
        notify(f"Nouvelle activité sur {repo}#{n}",
               f"Session ({S.label[kind]}) déjà ouverte dans herdr : "
               + ("message envoyé" if told else "occupée, message non envoyé"),
               ["herdr", "agent", "focus", prev["pane"]], "normal" if told else "critical")
        return f"{key} : session herdr déjà ouverte, " + ("message envoyé" if told else "message non envoyé")
    if prev and prev.get("status") == "running" and pid_alive(prev.get("pid")):
        return f"{key} : analyse déjà en cours"
    clone = clone_path(cfg, state, repo)
    if not clone:
        notify(f"Clone introuvable : {repo}", f"{S.name} add {repo} --path <clone>")
        return f"{key} : clone introuvable"
    pr = json.loads(run(["gh", "pr", "view", str(n), "--repo", repo, "--json",
                         "title,url,state,headRefName,headRefOid"]))
    if pr["state"] != "OPEN":
        return f"{key} : PR {pr['state'].lower()}"
    prompt = f"/{S.skill[kind]} {n}"
    if herdr_running() and not background:
        if kind in S.detached:
            run(["git", "-C", clone, "fetch", "-q", "origin", f"pull/{n}/head"], check=False)
            branch, base = f"agent/review-{n}-{slug(pr['title'])}", pr["headRefOid"]
        else:
            run(["git", "-C", clone, "fetch", "-q", "origin", pr["headRefName"]], check=False)
            branch, base = pr["headRefName"], f"origin/{pr['headRefName']}"
        path = ensure_worktree(clone, branch, base, os.path.join(HOME, ".herdr", "worktrees"))
        ws, pane = herdr_open(clone, path, f"{S.tab[kind]} #{n}")
        run(["herdr", "pane", "run", pane, shlex.join([*claude_cmd(cfg), prompt])])  # pas de JSON en retour
        state["sessions"][key] = {"mode": "herdr", "workspace": ws, "pane": pane, "dir": path,
                                  "url": pr["url"], "title": pr["title"], "launched": iso(now()),
                                  "event_at": at}
        notify(f"{S.label[kind].capitalize()} lancée : {repo}#{n}", f"{pr['title']}\nherdr : {S.tab[kind]} #{n}",
               ["herdr", "agent", "focus", pane])
        return f"{key} : lancée dans herdr ({path})"
    # Sans herdr : analyse en fond, reprise au clic
    if kind in S.detached:
        path = clone  # la relecture lit le diff et le code à la tête de la PR, sans s'y placer
    else:
        run(["git", "-C", clone, "fetch", "-q", "origin", pr["headRefName"]], check=False)
        path = ensure_worktree(clone, pr["headRefName"], f"origin/{pr['headRefName']}", S.worktrees)
    sid = str(uuid.uuid4())
    log = os.path.join(S.state_dir, "logs", f"{key.replace('/', '_').replace(':', '-')}.log")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    state["sessions"][key] = {"mode": "background", "session_id": sid, "dir": path, "url": pr["url"],
                              "title": pr["title"], "status": "running", "log": log, "launched": iso(now()),
                              "event_at": at}
    detach([sys.executable, S.self, "_run", key], cwd=path)
    return f"{key} : analyse lancée en fond (session {sid})"


def background_run(key):
    """Analyse en fond (lancé détaché par launch) : claude -p … --prepare, puis notification."""
    cfg = load_json(S.config)
    with State() as state:
        s = state["sessions"][key]
        s["pid"] = os.getpid()
    repo_n, kind = key.rsplit(":", 1)
    n = repo_n.rsplit("#", 1)[1]
    cmd = [*claude_cmd(cfg), "-p", f"/{S.skill[kind]} {n} --prepare", "--session-id",
           s["session_id"], "--allowedTools", *BACKGROUND_TOOLS]
    with open(s["log"], "a", encoding="utf-8") as out:
        out.write(f"[{iso(now())}] {shlex.join(cmd)}\n")
        out.flush()
        code = subprocess.run(cmd, cwd=s["dir"], stdin=subprocess.DEVNULL, stdout=out, stderr=out).returncode
    with State() as state:
        s = state["sessions"][key]
        s["status"] = "ready" if code == 0 else "failed"
        s["finished"] = iso(now())
    resume = [sys.executable, S.self, "resume", repo_n, kind]
    if code == 0:
        notify(f"{S.label[kind].capitalize()} prête à valider : {repo_n}", s.get("title", ""), resume, "critical")
    else:
        notify(f"Échec de l'analyse : {repo_n}", f"journal : {s['log']}", resume, "critical")


def terminal_cmd(cfg, cwd, argv):
    if cfg.get("terminal"):
        return [*shlex.split(cfg["terminal"]), *argv]
    if shutil.which("gnome-terminal"):
        return ["gnome-terminal", f"--working-directory={cwd}", "--", *argv]
    if shutil.which("x-terminal-emulator"):
        return ["x-terminal-emulator", "-e", shlex.join(argv)]
    return None


def resume(cfg, state, target, kind):
    ready = {k: s for k, s in state["sessions"].items() if s.get("mode") == "background"
             and s.get("status") in ("ready", "failed")}
    if not target:
        if not ready:
            print("aucune session préparée en fond")
        for k, s in ready.items():
            print(f"{k}  {s['status']}  {s.get('title', '')}\n  {S.name} resume {k.replace(':', ' ')}")
        return
    repo, n = split_target(target, state)
    key = key_of(repo, n, kind or S.kinds[0])
    if not kind:
        key = next((key_of(repo, n, k) for k in S.kinds if key_of(repo, n, k) in state["sessions"]), key)
    s = state["sessions"].get(key)
    if not s or s.get("mode") != "background":
        die(f"pas de session préparée pour {key}")
    argv = [*claude_cmd(cfg), "--resume", s["session_id"],
            "Reprends à la validation (l'analyse en fond est faite)."]
    term = terminal_cmd(cfg, s["dir"], argv)
    s["status"] = "resumed"
    if term and (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")
                 or os.environ.get("DBUS_SESSION_BUS_ADDRESS")) and not sys.stdout.isatty():
        detach(term, cwd=s["dir"])
        return
    # dans un terminal : reprendre ici
    os.chdir(s["dir"])
    save_json(S.state, state)
    os.execvp(argv[0], argv)


# --- passage ----------------------------------------------------------------------------------

HISTORY = 300  # déclenchements gardés dans l'état (les plus anciens sortent)


def record(state, kind, repo, n, action, detail="", title="", at=None):
    """Note un déclenchement dans l'historique (supervision : gh-watch history). Une entrée
    identique à la dernière de la même PR (même action et détail, ex. « en attente » à
    chaque passage) n'est pas répétée."""
    h = state.setdefault("history", [])
    key = key_of(repo, n, kind)
    last = next((e for e in reversed(h) if e["key"] == key), None)
    if last and last["action"] == action and last.get("detail") == detail:
        return
    h.append({"when": iso(now()), "key": key, "kind": kind, "repo": repo, "n": n,
              "action": action, "detail": detail, "title": title, "event_at": at})
    del h[:-HISTORY]


def mark(state, kind, repo, n, at):
    """Retient l'événement `at` comme traité (sans reculer une date plus récente)."""
    k = f"{repo}#{n}"
    state[kind][k] = max(state[kind].get(k) or "", at)


def dispatch(cfg, state, events, dry_run=False, seed=False):
    """Traite les événements [(kind, repo, n, titre, url, date)] selon le mode du dépôt, et
    retient leur date (sauf --dry-run). Retourne les lignes de compte rendu."""
    out = []
    for kind, repo, n, title, url, at in events:
        m = mode(cfg, repo, kind)
        tag = f"{repo}#{n} ({kind}, {m})"
        rec = (lambda action, detail="": None) if dry_run else (
            lambda action, detail="": record(state, kind, repo, n, action, detail, title, at))
        if seed:
            out.append(f"{tag} : déjà là, ignoré — {S.name} launch {repo}#{n} {kind}")
            rec("ignoré", "déjà là à l'activation")
        elif m == "off":
            out.append(f"{tag} : ignoré")
            rec("ignoré", "mode off")
        elif dry_run:
            out.append(f"{tag} : {'lancerait' if m == 'auto' else 'notifierait'}")
        elif m == "auto":
            try:
                line = launch(cfg, state, repo, n, kind, at)
                out.append(line)
                rec("lancé", line.split(" : ", 1)[-1])
            except Exception as e:  # un échec ne doit pas bloquer les autres PR
                out.append(f"{tag} : échec — {e}")
                rec("échec", str(e)[:200])
                notify(f"{S.name} : échec sur {repo}#{n}", str(e)[:200],
                       [sys.executable, S.self, "launch", f"{repo}#{n}", kind])
        else:
            notify(f"{S.announce[kind]} : {repo}#{n}", f"{title}\nclic : lancer /{S.skill[kind]}",
                   [sys.executable, S.self, "launch", f"{repo}#{n}", kind])
            out.append(f"{tag} : notifié")
            rec("notifié", f"{S.announce[kind]} (clic : /{S.skill[kind]})")
        if not dry_run:
            state[kind][f"{repo}#{n}"] = at
    return out


def poll(cfg, state, events, dry_run=False, seed=False):
    """Un passage : events(cfg, state, since, delay) donne les événements à traiter
    [(kind, repo, n, titre, url, date)] et les lignes de compte rendu propres au watcher."""
    start = now()
    since = parse(state["since"]) if state.get("since") else start - dt.timedelta(days=1)
    delay = int(cfg.get("feedback_delay", DELAY))
    todo, out = events(cfg, state, since, delay, dry_run=dry_run, seed=seed)
    out += dispatch(cfg, state, todo, dry_run, seed)
    if not dry_run:
        state["since"] = iso(start)
        state["initialized"] = True
    return out


# --- commandes --------------------------------------------------------------------------------

def current_repo():
    repo = remote_repo(".")
    if not repo:
        die("dossier courant : pas de remote origin GitHub")
    out = run(["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"], check=False).strip()
    return out or repo


def repo_arg(arg):
    return (current_repo() if arg == "." else arg).lower()


def split_target(target, state):
    m = re.fullmatch(r"(?:([\w.-]+/[\w.-]+))?#?(\d+)", target)
    if not m:
        die(f"cible attendue : owner/repo#n ou n (dépôt courant), pas « {target} »")
    return (m.group(1) or current_repo()), int(m.group(2))


def timer_state():
    if not shutil.which("systemctl"):
        return "systemd absent"
    r = subprocess.run(["systemctl", "--user", "is-active", S.timer], capture_output=True, text=True)
    return r.stdout.strip() or "inconnu"


def interval(cfg):
    return int(cfg.get("interval") or INTERVAL)


def apply_interval(cfg):
    """Drop-in du timer pour un intervalle autre que celui de l'unité (5 min) ; timer
    relancé s'il tourne."""
    n = interval(cfg)
    if n == INTERVAL:
        if os.path.exists(S.dropin):
            os.remove(S.dropin)
            try:
                os.rmdir(os.path.dirname(S.dropin))
            except OSError:
                pass
    else:
        os.makedirs(os.path.dirname(S.dropin), exist_ok=True)
        with open(S.dropin, "w", encoding="utf-8") as f:
            f.write(f"# Écrit par {S.name} interval (config : interval = {n})\n"
                    f"[Timer]\nOnUnitActiveSec=\nOnUnitActiveSec={n}min\n")
    if shutil.which("systemctl"):
        run(["systemctl", "--user", "daemon-reload"], check=False)
        if timer_state() == "active":
            run(["systemctl", "--user", "restart", S.timer], check=False)


def modes_line(cfg, repo):
    """Modes du dépôt (repo None : des dépôts non listés)."""
    if repo is None:
        d = {**S.defaults, **cfg.get("default", {})}
        return " ".join(f"{k}={d[k]}" for k in S.kinds) + S.repo_extra(cfg, None)
    return " ".join(f"{k}={mode(cfg, repo, k)}" for k in S.kinds) + S.repo_extra(cfg, repo)


def next_run():
    """Prochain passage du timer (heure locale), ou None."""
    if not shutil.which("systemctl"):
        return None
    r = subprocess.run(["systemctl", "--user", "list-timers", S.timer, "-o", "json", "--no-pager"],
                       capture_output=True, text=True)
    try:
        t = json.loads(r.stdout or "[]")
    except ValueError:
        return None
    nxt = t[0].get("next") if t else None
    return iso(dt.datetime.fromtimestamp(nxt / 1e6, dt.timezone.utc)) if nxt else None


def status_data(cfg, state):
    """État du watcher pour `status --json` (supervision par gh-watch)."""
    repos = []
    for repo, r in sorted(cfg.get("repos", {}).items()):
        if not any(k in r for k in S.kinds) and "path" not in r:
            continue
        repos.append({"repo": repo, **{k: mode(cfg, repo, k) for k in S.kinds}, **S.extra(cfg, repo),
                      "path": r.get("path") or state["clones"].get(repo.lower())})
    sessions = []
    for k, s in sorted(state["sessions"].items(), key=lambda kv: kv[1].get("launched", "")):
        d = {"key": k, "mode": s["mode"], "dir": s.get("dir"), "url": s.get("url"),
             "title": s.get("title"), "launched": s.get("launched"), "event_at": s.get("event_at")}
        if s["mode"] == "herdr":
            d["status"] = "ouverte" if herdr_alive(s) else "fermée"
        else:
            d.update(status=s.get("status"), log=s.get("log"), finished=s.get("finished"))
            if s.get("status") in ("ready", "failed"):
                d["resume"] = f"{S.name} resume {k.replace(':', ' ')}"
        sessions.append(d)
    return {"name": S.name, "timer": S.timer, "state": timer_state(), "interval": interval(cfg),
            "last": state.get("since"), "next": next_run(), "kinds": list(S.kinds),
            "default": {**{k: v for k, v in {**S.defaults, **cfg.get("default", {})}.items()}},
            "repos": repos, "sessions": sessions, "history": state.get("history", []),
            "skill": S.skill, "board": S.board, "suggest": S.suggest,
            # Date du dernier événement traité, par événement et PR (repo#n) : suivi de gh-watch board
            "handled": {k: state.get(k, {}) for k in S.kinds}}


def cmd_status(cfg, state, as_json=False):
    if as_json:
        return print(json.dumps(status_data(cfg, state), ensure_ascii=False))
    print(f"surveillance : {timer_state()} ({S.timer}, toutes les {interval(cfg)} min) ;"
          f" dernier passage : {state.get('since', 'jamais')}")
    print(f"dépôts non listés : {modes_line(cfg, None)}")
    for repo, r in sorted(cfg.get("repos", {}).items()):
        if not any(k in r for k in S.kinds) and "path" not in r:
            continue  # réglages sans surveillance (ex. d'un skill)
        print(f"  {repo}  {modes_line(cfg, repo)}"
              f"  {r.get('path') or state['clones'].get(repo.lower()) or '(clone cherché au besoin)'}")
    sessions = state["sessions"]
    if sessions:
        print("sessions :")
    for k, s in sorted(sessions.items(), key=lambda kv: kv[1].get("launched", "")):
        if s["mode"] == "herdr":
            st = "ouverte" if herdr_alive(s) else "fermée"
            print(f"  {k}  herdr {st}  {s['dir']}")
        else:
            print(f"  {k}  fond {s.get('status')}  {s['dir']}  (log : {s.get('log')})")


def remember_path(r, arg):
    if arg == "." and "path" not in r:
        r["path"] = run(["git", "rev-parse", "--show-toplevel"]).strip()


def cmd_add(cfg, state, args):
    repo = repo_arg(args.repo)
    if not re.fullmatch(r"[\w.-]+/[\w.-]+", repo):
        die(f"dépôt attendu : owner/repo, pas « {repo} »")
    r = cfg.setdefault("repos", {}).setdefault(repo, {})
    if not any(getattr(args, k) for k in S.kinds):
        for k in S.kinds:
            setattr(args, k, "auto")
    for kind in S.kinds:
        if getattr(args, kind):
            r[kind] = getattr(args, kind)
    if args.path:
        p = os.path.abspath(os.path.expanduser(args.path))
        if remote_repo(p) != repo.lower():
            die(f"{p} : pas un clone de {repo}")
        r["path"] = p
    remember_path(r, args.repo)
    save_json(S.config, cfg)
    print(f"{repo} : {modes_line(cfg, repo)}")
    if timer_state() != "active":
        print(f"surveillance arrêtée : {S.name} enable")


def local_repos(cfg, state):
    """Dépôts GitHub connus : ceux de la config, plus les clones des espaces de travail."""
    found = {}
    for ws in workspaces():
        if not os.path.isdir(ws):
            continue
        for d in sorted(os.listdir(ws)):
            p = os.path.join(ws, d)
            if os.path.exists(os.path.join(p, ".git")):
                r = remote_repo(p)
                if r:
                    found.setdefault(r, p)
    out = []
    for repo, r in cfg.get("repos", {}).items():
        out.append((repo, r.get("path") or found.pop(repo.lower(), None) or state["clones"].get(repo.lower())))
    out += sorted(found.items())
    return [{"repo": repo, "path": path, **{k: mode(cfg, repo, k) for k in S.kinds},
             **S.extra(cfg, repo)} for repo, path in out]


def prune_repo(cfg, repo):
    """Dépôt retiré de la config quand il n'y reste que son chemin."""
    if not set(cfg.get("repos", {}).get(repo, {})) - {"path"}:
        cfg.get("repos", {}).pop(repo, None)


def cmd_auto(cfg, args):
    """auto <repo|.> on|off [<événement>] : off remet le mode des dépôts non listés, jamais
    « off » explicite."""
    repo = repo_arg(args.repo)
    kinds = [args.kind] if args.kind else list(S.default_kinds)
    r = cfg.setdefault("repos", {}).setdefault(repo, {})
    for kind in kinds:
        if args.state == "on":
            r[kind] = "auto"
        else:
            r.pop(kind, None)
    if args.state == "on":
        remember_path(r, args.repo)
    prune_repo(cfg, repo)
    save_json(S.config, cfg)
    print(f"{repo} : {modes_line(cfg, repo)}")
    if args.state == "on" and timer_state() != "active":
        print(f"surveillance arrêtée : {S.name} enable")


def main(doc, events, extend=None, handle=None):
    """Commandes communes. extend(sub, default_parser) ajoute des sous-commandes ou des
    options de `default` ; handle(cfg, args) traite celles du watcher (True si traité) et
    les options ajoutées à `default`."""
    p = argparse.ArgumentParser(prog=S.name, description=doc.split("\n")[0])
    sub = p.add_subparsers(dest="cmd")
    sub.add_parser("status").add_argument("--json", action="store_true")
    sub.add_parser("repos").add_argument("--json", action="store_true")
    au = sub.add_parser("auto")
    au.add_argument("repo")
    au.add_argument("state", choices=("on", "off"))
    au.add_argument("kind", nargs="?", choices=S.kinds)
    a = sub.add_parser("add")
    a.add_argument("repo")
    for k in S.kinds:
        a.add_argument(f"--{k}", choices=MODES)
    a.add_argument("--path")
    sub.add_parser("remove").add_argument("repo")
    d = sub.add_parser("default")
    for k in S.kinds:
        d.add_argument(f"--{k}", choices=MODES)
    sub.add_parser("interval").add_argument("minutes", nargs="?", type=int)
    sub.add_parser("enable")
    sub.add_parser("disable")
    sub.add_parser("poll").add_argument("--dry-run", action="store_true")
    for name in ("launch", "resume"):
        c = sub.add_parser(name)
        c.add_argument("target", nargs="?" if name == "resume" else None)
        c.add_argument("kind", nargs="?", choices=S.kinds)
        if name == "launch":
            c.add_argument("--at")
            c.add_argument("--background", action="store_true")
    sk = sub.add_parser("skip")
    sk.add_argument("target")
    sk.add_argument("kind", choices=S.kinds)
    sk.add_argument("--at", required=True)
    sub.add_parser("_run").add_argument("key")
    sub.add_parser("_notify").add_argument("payload")
    sub.add_parser("_catchup")
    sub.add_parser("_catchup_open")
    if extend:
        extend(sub, d)
    args = p.parse_args()
    cfg = load_json(S.config)
    try:
        _main(cfg, args, events, handle)
    except RuntimeError as e:
        die(str(e))


def _main(cfg, args, events, handle):
    if args.cmd == "_notify":
        return notify_wait(json.loads(args.payload))
    if args.cmd == "_run":
        return background_run(args.key)
    if args.cmd == "_catchup":
        return catchup_run()
    if args.cmd == "_catchup_open":
        return catchup_open(cfg)
    if args.cmd in (None, "status"):
        with State() as state:
            return cmd_status(cfg, state, getattr(args, "json", False))
    if handle and args.cmd != "default" and handle(cfg, args):
        return
    if args.cmd == "repos":
        with State() as state:
            repos = local_repos(cfg, state)
        if args.json:
            return print(json.dumps(repos, ensure_ascii=False))
        for r in repos:
            print(f"{r['repo']}  {modes_line(cfg, r['repo'])}  {r['path'] or '(pas de clone)'}")
        return
    if args.cmd == "auto":
        return cmd_auto(cfg, args)
    if args.cmd == "add":
        with State() as state:
            return cmd_add(cfg, state, args)
    if args.cmd == "remove":
        repo = repo_arg(args.repo)
        if cfg.get("repos", {}).pop(repo, None) is None:
            die(f"{repo} n'est pas listé")
        save_json(S.config, cfg)
        print(f"{repo} retiré (mode des dépôts non listés désormais)")
        return
    if args.cmd == "default":
        dflt = cfg.setdefault("default", {})
        changed = False
        for kind in S.kinds:
            if getattr(args, kind):
                dflt[kind] = getattr(args, kind)
                changed = True
        if handle and handle(cfg, args):
            changed = True
        if changed:
            save_json(S.config, cfg)
        print(modes_line(cfg, None))
        return
    if args.cmd == "enable":
        with State() as state:
            if not state.get("initialized"):
                print("état initial (rien n'est lancé pour ce qui est déjà là) :")
                for line in poll(cfg, state, events, seed=True) or ["  rien en attente"]:
                    print(f"  {line}")
        apply_interval(cfg)
        run(["systemctl", "--user", "enable", "--now", S.timer])
        print(f"surveillance active ({S.timer}, toutes les {interval(cfg)} min)")
        return
    if args.cmd == "interval":
        if args.minutes is not None:
            if args.minutes < 1:
                die("intervalle en minutes, 1 au moins")
            if args.minutes == INTERVAL:
                cfg.pop("interval", None)
            else:
                cfg["interval"] = args.minutes
            save_json(S.config, cfg)
        apply_interval(cfg)  # sans argument : applique aussi une valeur éditée à la main
        print(f"scan toutes les {interval(cfg)} min ({timer_state()})")
        return
    if args.cmd == "disable":
        run(["systemctl", "--user", "disable", "--now", S.timer], check=False)
        print("surveillance arrêtée")
        return
    if args.cmd == "poll":
        with State() as state:
            seed = not state.get("initialized") and not args.dry_run
            for line in poll(cfg, state, events, dry_run=args.dry_run, seed=seed):
                print(line)
        # Verrou du watcher relâché : rattrapage du jour (board_auto), en détaché
        if not args.dry_run and catchup_due():
            detach([sys.executable, S.self, "_catchup"], log=os.path.join(S.state_dir, "catchup.log"))
            print("rattrapage du jour lancé (gh-watch board --all --missed)")
        return
    if args.cmd == "launch":
        with State() as state:
            repo, n = split_target(args.target, state)
            kind = args.kind or S.guess_kind(state, repo, n)
            try:
                line = launch(cfg, state, repo, n, kind, args.at, args.background)
            except Exception as e:
                record(state, kind, repo, n, "échec", f"lancé à la main : {str(e)[:180]}", at=args.at)
                raise
            record(state, kind, repo, n, "lancé", "à la main : " + line.split(" : ", 1)[-1], at=args.at)
            if args.at:  # événement donné (gh-watch launch) : traité, comme par poll
                mark(state, kind, repo, n, args.at)
            print(line)
        return
    if args.cmd == "skip":
        with State() as state:
            repo, n = split_target(args.target, state)
            mark(state, args.kind, repo, n, args.at)
            record(state, args.kind, repo, n, "refusé", "écarté (gh-watch skip)", at=args.at)
            print(f"{key_of(repo, n, args.kind)} : écarté jusqu'au prochain événement")
        return
    if args.cmd == "resume":
        with State() as state:
            return resume(cfg, state, args.target, args.kind)
