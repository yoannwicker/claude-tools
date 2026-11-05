"""board — état des PR ouvertes qui me concernent, pour `gh-watch board` (plugin gh-watch).

Deux temps, pour ménager le quota GraphQL : une recherche légère (identifiants des PR :
les miennes, celles où une relecture m'est demandée, celles que j'ai relues, celles où je
suis mentionné, et pour les dépôts en `others = open` toutes celles des autres), puis le
détail de ces PR par `nodes(ids:)`. Le classement (`classify`) est pur : il ne lit que le
nœud GraphQL, ce qui le rend testable sans réseau.

Ne lit que l'état actuel de GitHub, jamais les notifications.
"""
import concurrent.futures, json, subprocess, urllib.parse

import watchlib as w

# Groupes, dans l'ordre d'affichage : (état, libellé)
MINE = (("feedback", "retours à traiter"), ("approved", "approuvée, à préparer"),
        ("unrequested", "à faire relire"), ("in_review", "en relecture"),
        ("waiting_reviewer", "en attente du relecteur"), ("draft", "brouillon"))
OTHERS = (("re_requested", "relecture redemandée"), ("to_review", "à relire"),
          ("reviewed", "relue"), ("mentioned", "mentionné"),
          ("open_unrequested", "ouvertes, sans demande"))
LABEL = dict(MINE + OTHERS)
ALERTS = {"ci": "CI en échec", "conflict": "conflit", "behind": "en retard sur sa base"}
# États où une attente trop longue est signalée (⚠) : ceux où quelqu'un attend une action
STALE = {"feedback", "approved", "unrequested", "in_review", "waiting_reviewer", "to_review", "re_requested"}
# Qui doit agir : moi (me), les autres (others), personne pour l'instant (rest)
BUCKETS = (("me", "À toi"), ("others", "En attente des autres"), ("rest", "Le reste"))
BUCKET = {"feedback": "me", "approved": "me", "unrequested": "me", "to_review": "me", "re_requested": "me",
          "in_review": "others", "waiting_reviewer": "others", "reviewed": "others",
          "draft": "rest", "mentioned": "rest", "open_unrequested": "rest"}
# Action proposée quand aucun watcher ne prend l'état en charge
TEXT = {"unrequested": "demander une relecture", "in_review": "relancer",
        "waiting_reviewer": "relancer"}

FRAGMENT = """fragment pr on PullRequest {
  id number title url isDraft createdAt headRefOid baseRefName
  author { login } repository { nameWithOwner }
  mergeable mergeStateStatus
  reviewRequests(first: 20) { nodes { requestedReviewer {
    __typename ... on User { login } ... on Team { slug } } } }
  timelineItems(itemTypes: [REVIEW_REQUESTED_EVENT, READY_FOR_REVIEW_EVENT], last: 30) { nodes {
    __typename
    ... on ReviewRequestedEvent { createdAt actor { login } requestedReviewer {
      __typename ... on User { login } ... on Team { slug } } }
    ... on ReadyForReviewEvent { createdAt } } }
  latestOpinionatedReviews(first: 30) { nodes { author { __typename login } state submittedAt } }
  reviews(last: 50) { nodes { author { __typename login } state submittedAt } }
  reviewThreads(first: 100) { nodes { isResolved
    first: comments(first: 1) { nodes { author { __typename login } createdAt } }
    last: comments(last: 1) { nodes { author { __typename login } createdAt } } } }
  commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
}"""


def gql(query, variables):
    """GraphQL avec des variables quelconques (listes comprises), par l'entrée standard."""
    r = subprocess.run(["gh", "api", "graphql", "--input", "-"], capture_output=True, text=True,
                       input=json.dumps({"query": query, "variables": variables}))
    if r.returncode:
        raise RuntimeError(f"gh api graphql : {(r.stderr or r.stdout).strip()}")
    data = json.loads(r.stdout)
    if data.get("errors"):
        raise RuntimeError(data["errors"][0].get("message"))
    return data["data"]


def searches(repo=None, open_repos=()):
    """{catégorie: requête de recherche} ; repo : restreint à un dépôt."""
    base = "is:pr is:open archived:false" + (f" repo:{repo}" if repo else "")
    q = {"mine": f"{base} author:@me",
         "requested": f"{base} review-requested:@me",
         "reviewed": f"{base} reviewed-by:@me -author:@me",
         "mentioned": f"{base} mentions:@me -author:@me"}
    for i, r in enumerate(x for x in open_repos if not repo or x == repo):
        q[f"open{i}"] = f"is:pr is:open archived:false repo:{r} -author:@me draft:false"
    return q


def fetch(repo=None, open_repos=(), active=None):
    """(login, [(nœud PR, {catégories})]) ; les miennes reçoivent `behind_by`. active(dépôt) :
    dépôts retenus, filtrés dès la recherche (les autres ne coûtent pas leur détail)."""
    q = searches(repo, open_repos)
    names = list(q)
    query = ("query(" + ", ".join(f"${k}: String!" for k in names) + ") {\n"
             + "\n".join(f"  {k}: search(query: ${k}, type: ISSUE, first: 100) "
                         "{ nodes { ... on PullRequest { id repository { nameWithOwner } } } }" for k in names)
             + "\n  viewer { login } }")
    data = gql(query, q)
    cats = {}
    for k in names:
        cat = "open" if k.startswith("open") else k
        for n in (data.get(k) or {}).get("nodes", []):
            if n and n.get("id") and (not active or active(n["repository"]["nameWithOwner"])):
                cats.setdefault(n["id"], set()).add(cat)
    ids, nodes = list(cats), []
    for i in range(0, len(ids), 50):
        d = gql("query($ids: [ID!]!) { nodes(ids: $ids) { ...pr } }\n" + FRAGMENT, {"ids": ids[i:i + 50]})
        nodes += [n for n in d["nodes"] if n]
    mine = [n for n in nodes if "mine" in cats[n["id"]]]
    with concurrent.futures.ThreadPoolExecutor(8) as ex:
        for n, b in zip(mine, ex.map(behind_by, mine)):
            n["behind_by"] = b
    return data["viewer"]["login"], [(n, cats[n["id"]]) for n in nodes]


def behind_by(pr):
    """Commits de la base absents de la PR (None si GitHub ne répond pas)."""
    base = urllib.parse.quote(pr["baseRefName"], safe="")
    r = subprocess.run(["gh", "api", f"repos/{pr['repository']['nameWithOwner']}/compare/"
                        f"{base}...{pr['headRefOid']}?per_page=1", "--jq", ".behind_by"],
                       capture_output=True, text=True)
    try:
        return int(r.stdout.strip()) if not r.returncode else None
    except ValueError:
        return None


# --- classement ---------------------------------------------------------------------------

def _login(a):
    return (a or {}).get("login")


def _human(a):
    return bool(a) and a.get("__typename") != "Bot" and not a.get("login", "").endswith("[bot]")


def _reviewer(r):
    r = r or {}
    return r.get("login") or (f"@{r['slug']}" if r.get("slug") else None)


def _threads(pr):
    """Fils non résolus : [(auteur du premier message, du dernier, date du dernier)]."""
    out = []
    for t in (pr.get("reviewThreads") or {}).get("nodes", []):
        if not t or t.get("isResolved"):
            continue
        f, l = (t.get("first") or {}).get("nodes") or [{}], (t.get("last") or {}).get("nodes") or [{}]
        out.append((_login(f[0].get("author")), _login(l[0].get("author")), l[0].get("createdAt")))
    return out


def _n(k, word):
    return f"{k} {word}" + ("s" if k > 1 else "")


def _alerts(pr):
    out = []
    ci = (((pr.get("commits") or {}).get("nodes") or [{}])[0].get("commit") or {}).get("statusCheckRollup")
    if ci and ci.get("state") in ("FAILURE", "ERROR"):
        out.append("ci")
    if pr.get("mergeable") == "CONFLICTING" or pr.get("mergeStateStatus") == "DIRTY":
        out.append("conflict")
    if pr.get("behind_by"):
        out.append("behind")
    return out


def classify(pr, login, cats, approvals=2):
    """État d'une PR : {state, short, detail, since, event_at, alerts, mine, bucket} (short :
    libellé court pour le tableau ; bucket : qui doit agir, voir BUCKETS). `event_at` : date
    de l'événement au sens des watchers (feedback : dernière review d'un autre ; approved :
    N-ième approbation ; review : dernière demande qui me vise), None sinon."""
    mine = _login(pr.get("author")) == login
    r = (classify_mine if mine else classify_other)(pr, login, cats, approvals)
    r.update(mine=mine, alerts=_alerts(pr) if mine else [])
    r.setdefault("event_at", None)
    bucket = BUCKET[r["state"]]
    if r.pop("answered", False):
        bucket = "me"  # l'auteur m'a répondu
    elif mine and bucket == "others" and {"ci", "conflict"} & set(r["alerts"]):
        bucket = "me"  # CI en échec ou conflit : à moi de corriger
    r["bucket"] = bucket
    return r


def classify_mine(pr, login, cats, need):
    latest = [x for x in (pr.get("latestOpinionatedReviews") or {}).get("nodes", [])
              if x and _human(x.get("author")) and _login(x["author"]) != login]
    changes = [x for x in latest if x["state"] == "CHANGES_REQUESTED"]
    ok = sorted(x["submittedAt"] for x in latest if x["state"] == "APPROVED" and x.get("submittedAt"))
    others = [x["submittedAt"] for x in (pr.get("reviews") or {}).get("nodes", [])
              if x and x.get("submittedAt") and x["state"] != "PENDING"
              and _human(x.get("author")) and _login(x["author"]) != login]
    threads = _threads(pr)
    on_me = [t for t in threads if t[1] and t[1] != login]
    on_them = [t for t in threads if t[1] == login and t[0] and t[0] != login]
    requested = [x for x in (_reviewer(n.get("requestedReviewer"))
                             for n in (pr.get("reviewRequests") or {}).get("nodes", []) if n) if x]
    count = f"{len(ok)}/{need} approbation(s)"
    if pr.get("isDraft"):
        return {"state": "draft", "short": "brouillon", "detail": count if ok else "", "since": pr["createdAt"]}
    if changes or on_me:
        parts = [f"{len(on_me)} fil(s) à traiter"] if on_me else []
        if changes:
            parts.append("changements demandés par " + ", ".join(_login(x["author"]) for x in changes))
        since = min([x["submittedAt"] for x in changes if x.get("submittedAt")] + [t[2] for t in on_me if t[2]]
                    or [pr["createdAt"]])
        short = "retours (" + ", ".join(([_n(len(on_me), "fil")] if on_me else [])
                                        + (["changements demandés"] if changes else [])) + ")"
        return {"state": "feedback", "short": short, "detail": " ; ".join(parts + [count]), "since": since,
                "event_at": max(others) if others else None}
    if len(ok) >= need:
        return {"state": "approved", "short": f"approuvée {len(ok)}/{need}", "detail": count, "since": ok[need - 1], "event_at": ok[need - 1]}
    if on_them:
        who = sorted({t[0] for t in on_them})
        return {"state": "waiting_reviewer", "short": f"attend {', '.join(who)} ({_n(len(on_them), 'fil')})",
                "since": max(t[2] for t in on_them if t[2]),
                "detail": f"{len(on_them)} fil(s) en attente de {', '.join(who)} ; {count}"}
    if requested:
        asked = {}
        for e in (pr.get("timelineItems") or {}).get("nodes", []):
            if e and e.get("__typename") == "ReviewRequestedEvent":
                who = _reviewer(e.get("requestedReviewer"))
                if who in requested:
                    asked[who] = max(asked.get(who, ""), e["createdAt"])
        return {"state": "in_review", "short": f"en relecture : {', '.join(requested)}"
                + (f" ({len(ok)}/{need})" if ok else ""), "since": min(asked.values()) if asked else pr["createdAt"],
                "detail": f"attend {', '.join(requested)} ; {count}"}
    ready = [e["createdAt"] for e in (pr.get("timelineItems") or {}).get("nodes", [])
             if e and e.get("__typename") == "ReadyForReviewEvent"]
    return {"state": "unrequested", "short": "à faire relire" + (f" ({len(ok)}/{need})" if ok else ""),
            "since": max(ready) if ready else pr["createdAt"],
            "detail": f"{count}, aucun relecteur en attente" if ok or others else "aucun relecteur demandé"}


def classify_other(pr, login, cats, need):
    author = _login(pr.get("author")) or "?"
    mine = sorted(x["submittedAt"] for x in (pr.get("reviews") or {}).get("nodes", [])
                  if x and x.get("submittedAt") and x["state"] != "PENDING" and _login(x.get("author")) == login)
    if "requested" in cats:
        teams = [r for r in (_reviewer(n.get("requestedReviewer"))
                             for n in (pr.get("reviewRequests") or {}).get("nodes", []) if n) if r]
        direct = login in teams
        events = [e for e in (pr.get("timelineItems") or {}).get("nodes", [])
                  if e and e.get("__typename") == "ReviewRequestedEvent"
                  and (_login(e.get("requestedReviewer")) == login
                       or (e.get("requestedReviewer") or {}).get("__typename") == "Team")]
        last = max(events, key=lambda e: e["createdAt"]) if events else None
        asked = last["createdAt"] if last else pr["createdAt"]
        parts = [f"de {author}"]
        if last and _login(last.get("actor")) and _login(last.get("actor")) != author:
            actor = _login(last["actor"])
            parts.append("demandée par " + ("moi" if actor == login else actor))
        if not direct:
            parts.append("via " + ", ".join(t for t in teams if t.startswith("@")))
        prior = [t for t in mine if t < asked]
        short = ("redemandée" if prior else "à relire") + (" via " + ", ".join(
            t for t in teams if t.startswith("@")) if not direct else "")
        return {"state": "re_requested" if prior else "to_review", "short": short, "detail": " ; ".join(parts),
                "since": asked, "event_at": asked}
    if "reviewed" in cats and mine:
        threads = [t for t in _threads(pr) if t[0] == login]
        answered = [t for t in threads if t[1] and t[1] != login]
        if answered:
            return {"state": "reviewed", "short": f"réponse de l'auteur ({_n(len(answered), 'fil')})",
                    "answered": True, "since": max(t[2] for t in answered if t[2]),
                    "detail": f"de {author} ; l'auteur a répondu ({len(answered)} fil(s))"}
        if threads:
            return {"state": "reviewed", "short": f"attend l'auteur ({_n(len(threads), 'fil')})", "since": mine[-1],
                    "detail": f"de {author} ; {len(threads)} fil(s) en attente de l'auteur"}
        opinion = [x["state"] for x in (pr.get("latestOpinionatedReviews") or {}).get("nodes", [])
                   if x and _login(x.get("author")) == login]
        verdict = ("approuvée par moi" if "APPROVED" in opinion
                   else "changements demandés par moi" if "CHANGES_REQUESTED" in opinion else "commentée")
        return {"state": "reviewed", "short": verdict, "since": mine[-1],
                "detail": f"de {author} ; " + ("approuvée par moi" if "APPROVED" in opinion
                                               else "changements demandés par moi" if "CHANGES_REQUESTED" in opinion
                                               else "commentée")}
    if "mentioned" in cats:
        return {"state": "mentioned", "short": "mentionné", "since": pr["createdAt"], "detail": f"de {author}"}
    ok = [x for x in (pr.get("latestOpinionatedReviews") or {}).get("nodes", [])
          if x and x["state"] == "APPROVED" and _login(x.get("author")) != author]
    return {"state": "open_unrequested", "short": f"sans demande ({len(ok)}/{need})", "since": pr["createdAt"],
            "detail": f"de {author} ; {len(ok)}/{need} approbation(s)"}


def keep(pr, login, cats, need):
    """Une PR « open » (dépôt en others = open) n'est gardée que si elle a encore besoin de
    relecteurs et que je ne l'ai pas relue ; les autres catégories, toujours."""
    if cats - {"open"}:
        return True
    if any(_login(x.get("author")) == login for x in (pr.get("reviews") or {}).get("nodes", []) if x):
        return False
    ok = [x for x in (pr.get("latestOpinionatedReviews") or {}).get("nodes", [])
          if x and x["state"] == "APPROVED"]
    return len(ok) < need


def workdays(a, b):
    """Jours ouvrés (fractions comprises) entre deux dates, samedis et dimanches exclus,
    jours découpés à minuit heure locale."""
    a, b = a.astimezone(), b.astimezone()
    total = 0.0
    while a < b:
        nxt = min(b, (a + w.dt.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0))
        if a.weekday() < 5:
            total += (nxt - a).total_seconds() / 86400
        a = nxt
    return total


def build(login, items, approvals, stale_days, now=None):
    """Lignes du tableau : [{repo, n, title, url, author, mine, state, label, detail, since,
    age_days, workdays, stale, alerts, event_at}], triées par groupe puis ancienneté.
    `stale` : plus de `stale_days` jours ouvrés depuis `since`, pour un état de STALE."""
    now = now or w.now()
    order = {s: i for i, (s, _) in enumerate(MINE + OTHERS)}
    rows = []
    for pr, cats in items:
        repo = pr["repository"]["nameWithOwner"]
        need = approvals(repo)
        if not keep(pr, login, cats, need):
            continue
        c = classify(pr, login, cats, need)
        since = w.parse(c["since"]) if c.get("since") else None
        age = (now - since).total_seconds() / 86400 if since else None
        work = workdays(since, now) if since else None
        rows.append({"repo": repo, "n": pr["number"], "title": pr["title"], "url": pr["url"],
                     "author": _login(pr.get("author")), **c, "label": LABEL[c["state"]],
                     "age_days": round(age, 2) if since else None,
                     "workdays": round(work, 2) if since else None,
                     "stale": bool(since) and c["state"] in STALE and work > stale_days})
    border = {k: i for i, (k, _) in enumerate(BUCKETS)}
    rows.sort(key=lambda r: (border[r["bucket"]], not r["mine"], order[r["state"]], r["since"] or ""))
    return rows
