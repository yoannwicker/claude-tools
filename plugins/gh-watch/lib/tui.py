"""tui — liste interactive de `gh-watch board -i` (curses, plugin gh-watch).

Une ligne par PR, regroupées par dépôt et par « qui doit agir », une ligne surlignée, et une
touche par action : lancer l'action proposée (herdr s'il tourne, sinon en fond), la lancer
en fond (analyse jusqu'à ce qu'il faille valider, puis notification), écarter, réintégrer,
rafraîchir. La logique (Model, key_action, apply) est séparée du dessin (run) : elle se
teste sans terminal.
"""
import curses

HELP = ("↑↓ z s : naviguer · Entrée : lancer · f : en fond · x : écarter · X : jusqu'à la "
        "fermeture · u : réintégrer · r : rafraîchir · q : quitter")
BUCKET = {"me": "À toi", "others": "En attente des autres", "rest": "Le reste"}

_KEYS = {"z": "up", "s": "down", "\n": "launch", "\r": "launch", "f": "background",
         "x": "skip", "X": "skip_closed", "u": "unskip", "r": "refresh", "q": "quit", "\x1b": "quit"}


def key_action(key):
    """Touche (caractère, ou code curses) → action, None si la touche ne fait rien."""
    if key in (curses.KEY_UP,):
        return "up"
    if key in (curses.KEY_DOWN,):
        return "down"
    if key in (curses.KEY_ENTER, 10, 13):
        return "launch"
    if isinstance(key, int):
        key = chr(key) if 0 <= key < 0x110000 else ""
    return _KEYS.get(key)


class Model:
    """Lignes du tableau, ligne choisie, message du bas, annotations des actions faites."""

    def __init__(self, rows, fmt, many_repos):
        self.fmt, self.many_repos = fmt, many_repos
        self.msg = ""
        self.set_rows(rows)

    def set_rows(self, rows):
        self.rows, self.notes = list(rows), {}
        self.sel = min(getattr(self, "sel", 0), max(0, len(self.rows) - 1))

    def move(self, delta):
        if self.rows:
            self.sel = max(0, min(len(self.rows) - 1, self.sel + delta))

    def current(self):
        return self.rows[self.sel] if self.rows else None

    def lines(self):
        """[(texte des colonnes ou titre, index de la ligne ou None pour un titre)]."""
        out, last = [], (None, None)
        for i, r in enumerate(self.rows):
            group = (r["repo"] if self.many_repos else None, r.get("bucket"))
            if group != last:
                if self.many_repos and group[0] != last[0]:
                    out.append((r["repo"], None))
                if group[1]:
                    out.append((" " + BUCKET.get(group[1], group[1]), None))
                last = group
            cells = list(self.fmt(r))
            note = self.notes.get(i)
            if note:
                cells[1] = f"{cells[1]} · {note}"
            out.append((cells, i))
        return out


def apply(model, action, ops):
    """Applique l'action à la ligne choisie. ops : launch(r, background) -> (ok, msg),
    skip(r, until_closed) -> msg, unskip(r) -> (ok, msg), refresh() -> lignes.
    Retourne False pour quitter."""
    if action == "quit":
        return False
    if action in ("up", "down"):
        model.move(-1 if action == "up" else 1)
        return True
    if action == "refresh":
        model.set_rows(ops.refresh())
        model.msg = f"{len(model.rows)} PR"
        return True
    r = model.current()
    if r is None:
        model.msg = "aucune PR"
        return True
    if action in ("launch", "background"):
        ok, model.msg = ops.launch(r, action == "background")
        if ok:
            model.notes[model.sel] = "en fond" if action == "background" else "lancée"
    elif action in ("skip", "skip_closed"):
        model.msg = ops.skip(r, action == "skip_closed")
        model.notes[model.sel] = "écartée" + (" jusqu'à la fermeture" if action == "skip_closed" else "")
    elif action == "unskip":
        ok, model.msg = ops.unskip(r)
        if ok:
            model.notes[model.sel] = "réintégrée"
    return True


def _draw(scr, model, title):
    scr.erase()
    h, wd = scr.getmaxyx()
    lines = model.lines()
    cols = [c for c, i in lines if i is not None]
    widths = [max((len(c[k]) for c in cols), default=0) for k in range(len(cols[0]) - 1)] if cols else []
    body = h - 4
    sel_line = next((n for n, (_, i) in enumerate(lines) if i == model.sel), 0)
    top = max(0, sel_line - body + 1)

    def put(y, text, attr=0):
        try:
            scr.addnstr(y, 0, text, wd - 1, attr)
        except curses.error:
            pass
    put(0, title, curses.A_BOLD)
    for y, (c, i) in enumerate(lines[top:top + body], start=1):
        if i is None:
            put(y, c, curses.A_BOLD)
            continue
        text = "  " + "  ".join(v.ljust(w_) for v, w_ in zip(c[:-1], widths)) + "  " + c[-1]
        put(y, text, curses.A_REVERSE if i == model.sel else 0)
    if not lines:
        put(1, "  aucune PR")
    put(h - 2, model.msg)
    put(h - 1, HELP, curses.A_DIM)
    scr.refresh()


def run(rows, ops, fmt, title, many_repos):
    """Boucle de la liste interactive."""
    model = Model(rows, fmt, many_repos)

    def loop(scr):
        curses.curs_set(0)
        scr.keypad(True)
        while True:
            _draw(scr, model, title)
            action = key_action(scr.get_wch())
            if action in ("launch", "background", "refresh"):
                model.msg = "lancement…" if action != "refresh" else "rafraîchissement…"
                _draw(scr, model, title)
            if action and not apply(model, action, ops):
                return
    curses.wrapper(loop)
