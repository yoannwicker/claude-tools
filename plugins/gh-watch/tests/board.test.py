#!/usr/bin/env python3
"""Tests du classement de gh-watch board : python3 plugins/gh-watch/tests/board.test.py
PR fictives (nœuds GraphQL), sans réseau."""
import datetime as dt, importlib.machinery, importlib.util, os, sys, unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "lib"))
import board as b  # noqa: E402
import tui  # noqa: E402

ME = "moi"


def user(login, bot=False):
    return {"__typename": "Bot" if bot else "User", "login": login}


def review(login, state, at, bot=False):
    return {"author": user(login, bot), "state": state, "submittedAt": at}


def thread(first, last, at, resolved=False, outdated=False):
    return {"isResolved": resolved, "isOutdated": outdated,
            "first": {"nodes": [{"author": user(first), "createdAt": at}]},
            "last": {"nodes": [{"author": user(last), "createdAt": at}]}}


def requested(at, login=ME, actor="alice", team=None):
    who = {"__typename": "Team", "slug": team} if team else {"__typename": "User", "login": login}
    return {"__typename": "ReviewRequestedEvent", "createdAt": at, "actor": {"login": actor},
            "requestedReviewer": who}


def pr(author=ME, draft=False, reviews=(), latest=(), threads=(), asked=(), timeline=(), ci=None,
       mergeable="MERGEABLE", merge_state="CLEAN", behind=0, n=1, repo="o/r"):
    return {"id": f"{repo}#{n}", "number": n, "title": f"PR {n}", "url": f"https://github.com/{repo}/pull/{n}",
            "isDraft": draft, "createdAt": "2026-11-02T08:00:00Z", "author": {"login": author},
            "repository": {"nameWithOwner": repo}, "mergeable": mergeable, "mergeStateStatus": merge_state,
            "reviewRequests": {"nodes": [{"requestedReviewer": ({"__typename": "Team", "slug": a[1:]}
                                                                if a.startswith("@") else user(a))} for a in asked]},
            "timelineItems": {"nodes": list(timeline)},
            "latestOpinionatedReviews": {"nodes": list(latest)}, "reviews": {"nodes": list(reviews)},
            "reviewThreads": {"nodes": list(threads)},
            "commits": {"nodes": [{"commit": {"statusCheckRollup": {"state": ci} if ci else None}}]},
            "behind_by": behind}


def state(p, cats=frozenset({"mine"}), need=2):
    return b.classify(p, ME, set(cats), need)


class Mine(unittest.TestCase):
    def test_draft(self):
        self.assertEqual(state(pr(draft=True))["state"], "draft")

    def test_unrequested(self):
        c = state(pr(timeline=[{"__typename": "ReadyForReviewEvent", "createdAt": "2026-11-03T09:00:00Z"}]))
        self.assertEqual((c["state"], c["since"]), ("unrequested", "2026-11-03T09:00:00Z"))

    def test_in_review_since_oldest_pending_request(self):
        c = state(pr(asked=["bob", "carol"], timeline=[
            requested("2026-11-03T09:00:00Z", "bob"), requested("2026-11-04T09:00:00Z", "carol"),
            requested("2026-11-01T09:00:00Z", "dave")]))
        self.assertEqual((c["state"], c["since"]), ("in_review", "2026-11-03T09:00:00Z"))
        self.assertIn("attend bob, carol", c["detail"])

    def test_feedback_on_unanswered_thread(self):
        c = state(pr(asked=["bob"], reviews=[review("bob", "COMMENTED", "2026-11-04T10:00:00Z")],
                     threads=[thread("bob", "bob", "2026-11-04T10:00:00Z"),
                              thread("bob", ME, "2026-11-04T11:00:00Z"),
                              thread("bob", "bob", "2026-11-03T10:00:00Z", resolved=True)]))
        self.assertEqual((c["state"], c["event_at"]), ("feedback", "2026-11-04T10:00:00Z"))
        self.assertIn("1 fil(s) à traiter", c["detail"])

    def test_feedback_on_changes_requested(self):
        c = state(pr(latest=[review("bob", "CHANGES_REQUESTED", "2026-11-04T10:00:00Z")]))
        self.assertEqual(c["state"], "feedback")
        self.assertIn("changements demandés par bob", c["detail"])

    def test_approved_at_nth_approval_even_if_my_reply_pending(self):
        c = state(pr(latest=[review("bob", "APPROVED", "2026-11-04T10:00:00Z"),
                             review("carol", "APPROVED", "2026-11-04T12:00:00Z"),
                             review("dave", "APPROVED", "2026-11-04T15:00:00Z")],
                     threads=[thread("bob", ME, "2026-11-04T09:00:00Z")]))
        self.assertEqual((c["state"], c["event_at"]), ("approved", "2026-11-04T12:00:00Z"))

    def test_approval_threshold(self):
        p = pr(latest=[review("bob", "APPROVED", "2026-11-04T10:00:00Z")])
        self.assertEqual(state(p, need=1)["state"], "approved")
        self.assertEqual(state(p, need=2)["state"], "unrequested")

    def test_bot_and_own_reviews_ignored(self):
        c = state(pr(latest=[review("copilot", "APPROVED", "2026-11-04T10:00:00Z", bot=True),
                             review(ME, "APPROVED", "2026-11-04T10:00:00Z")]), need=1)
        self.assertEqual(c["state"], "unrequested")

    def test_waiting_reviewer(self):
        c = state(pr(asked=["bob"], threads=[thread("bob", ME, "2026-11-04T11:00:00Z")]))
        self.assertEqual(c["state"], "waiting_reviewer")
        self.assertIn("en attente de bob", c["detail"])

    def test_bucket_ci_failure_on_pr_in_review_is_mine(self):
        self.assertEqual(state(pr(asked=["bob"]))["bucket"], "others")
        self.assertEqual(state(pr(asked=["bob"], ci="FAILURE"))["bucket"], "me")
        self.assertEqual(state(pr(asked=["bob"], behind=2))["bucket"], "others")

    def test_short(self):
        self.assertEqual(state(pr(asked=["bob"], threads=[thread("bob", ME, "x"), thread("bob", ME, "x")]))["short"],
                         "attend bob (2 fils)")

    def test_alerts(self):
        c = state(pr(ci="FAILURE", mergeable="CONFLICTING", behind=3))
        self.assertEqual(c["alerts"], ["ci", "conflict", "behind"])
        self.assertEqual(state(pr(ci="SUCCESS"))["alerts"], [])


    def test_message_to_handle_even_with_approval(self):
        c = state(pr(latest=[review("bob", "APPROVED", "2026-11-04T10:00:00Z")],
                     reviews=[dict(review("bob", "APPROVED", "2026-11-04T10:00:00Z"), body="Renomme la méthode ?")]))
        self.assertEqual((c["state"], c["messages"], c["event_at"]), ("feedback", 1, "2026-11-04T10:00:00Z"))
        self.assertIn("message de bob à traiter", c["detail"])

    def test_trivial_message_is_not_feedback(self):
        for body in ("LGTM 👍", "ça me va !", "Thanks, good job", "", "ok."):
            c = state(pr(latest=[review("bob", "APPROVED", "2026-11-04T10:00:00Z")],
                         reviews=[dict(review("bob", "APPROVED", "2026-11-04T10:00:00Z"), body=body)]), need=1)
            self.assertEqual(c["state"], "approved", body)
        self.assertFalse(b.trivial("LGTM ?"))

    def test_message_answered_by_me_or_superseded(self):
        msg = dict(review("bob", "COMMENTED", "2026-11-04T10:00:00Z"), body="Pourquoi ce choix")
        later = [review(ME, "COMMENTED", "2026-11-04T11:00:00Z")]
        self.assertEqual(state(pr(reviews=[msg] + later))["messages"], 0)
        p = pr(reviews=[msg])
        p["comments"] = {"nodes": [{"author": {"login": ME}, "createdAt": "2026-11-04T11:00:00Z"}]}
        self.assertEqual(state(p)["messages"], 0)
        approve = review("bob", "APPROVED", "2026-11-04T12:00:00Z")
        self.assertEqual(state(pr(reviews=[msg, approve]))["messages"], 0)
        reply = dict(review("bob", "COMMENTED", "2026-11-04T12:00:00Z"), body="")  # réponse dans un fil
        self.assertEqual(state(pr(reviews=[msg, reply]))["messages"], 1)

    def test_feedback_event_counts_bot_reviews(self):
        c = state(pr(reviews=[review("copilot", "COMMENTED", "2026-11-04T10:00:00Z", bot=True)],
                     threads=[thread("copilot", "copilot", "2026-11-04T10:00:00Z")]))
        self.assertEqual((c["state"], c["event_at"]), ("feedback", "2026-11-04T10:00:00Z"))


class Others(unittest.TestCase):
    def test_to_review_self_requested(self):
        c = state(pr(author="alice", asked=[ME], timeline=[requested("2026-11-05T08:00:00Z", actor=ME)]),
                  {"requested"})
        self.assertEqual((c["state"], c["event_at"]), ("to_review", "2026-11-05T08:00:00Z"))
        self.assertIn("demandée par moi", c["detail"])

    def test_re_requested(self):
        c = state(pr(author="alice", asked=[ME], reviews=[review(ME, "COMMENTED", "2026-11-03T08:00:00Z")],
                     timeline=[requested("2026-11-02T08:00:00Z"), requested("2026-11-04T08:00:00Z")]),
                  {"requested", "reviewed"})
        self.assertEqual((c["state"], c["since"]), ("re_requested", "2026-11-04T08:00:00Z"))

    def test_via_team(self):
        c = state(pr(author="alice", asked=["@back"], timeline=[requested("2026-11-04T08:00:00Z", team="back")]),
                  {"requested"})
        self.assertEqual(c["state"], "to_review")
        self.assertIn("via @back", c["detail"])

    def test_reviewed_author_answered(self):
        c = state(pr(author="alice", reviews=[review(ME, "COMMENTED", "2026-11-03T08:00:00Z")],
                     threads=[thread(ME, "alice", "2026-11-04T08:00:00Z"), thread(ME, ME, "2026-11-03T08:00:00Z")]),
                  {"reviewed"})
        self.assertEqual(c["state"], "answered")
        self.assertIn("l'auteur a répondu (1 fil)", c["detail"])
        self.assertEqual((c["short"], c["bucket"]), ("réponse de l'auteur (1 fil)", "me"))

    def test_reviewed_outdated_threads(self):
        c = state(pr(author="alice", reviews=[review(ME, "COMMENTED", "2026-11-03T08:00:00Z")],
                     threads=[thread(ME, ME, "2026-11-03T08:00:00Z", outdated=True),
                              thread(ME, ME, "2026-11-03T08:00:00Z", outdated=True),
                              thread(ME, ME, "2026-11-03T08:00:00Z")]), {"reviewed"})
        self.assertEqual((c["state"], c["short"], c["bucket"]), ("answered", "code modifié (2 fils obsolètes)", "me"))
        self.assertEqual(c["event_at"], c["since"])
        self.assertIn("code modifié sous 2 fils obsolètes", c["detail"])

    def test_reviewed_author_comment_and_outdated(self):
        p = pr(author="alice", reviews=[review(ME, "COMMENTED", "2026-11-03T08:00:00Z")],
               threads=[thread(ME, ME, "2026-11-03T08:00:00Z", outdated=True)])
        p["comments"] = {"nodes": [{"author": user("alice"), "createdAt": "2026-11-02T09:00:00Z"},
                                   {"author": user("alice"), "createdAt": "2026-11-04T09:00:00Z"}]}
        c = state(p, {"reviewed"})
        self.assertEqual((c["short"], c["bucket"]), ("réponse de l'auteur (1 commentaire) + 1 fil obsolète", "me"))
        p["comments"]["nodes"].append({"author": user(ME), "createdAt": "2026-11-05T09:00:00Z"})
        p["reviewThreads"]["nodes"] = []
        self.assertEqual(state(p, {"reviewed"})["bucket"], "others")  # j'ai déjà répondu

    def test_reviewed_approved(self):
        c = state(pr(author="alice", reviews=[review(ME, "APPROVED", "2026-11-03T08:00:00Z")],
                     latest=[review(ME, "APPROVED", "2026-11-03T08:00:00Z")]), {"reviewed"})
        self.assertIn("approuvée par moi", c["detail"])
        self.assertEqual((c["short"], c["approved"], c["approved_by_me"]), ("☑ approuvée par moi", False, True))

    def test_one_check_per_approval_mine_apart(self):
        ok = [review("bob", "APPROVED", "2026-11-03T08:00:00Z"), review(ME, "APPROVED", "2026-11-03T09:00:00Z")]
        c = state(pr(author="alice", reviews=ok, latest=ok), {"reviewed"}, need=2)
        self.assertEqual((c["short"], c["checks"], c["approved"]), ("☑✓ approuvée 2/2", "☑✓", True))
        c = state(pr(author="alice", reviews=ok, latest=ok[1:], threads=[thread(ME, "alice", "2026-11-04T08:00:00Z")]),
                  {"reviewed"}, need=2)
        self.assertEqual(c["short"], "☑ réponse de l'auteur (1 fil)")
        c = state(pr(author="alice", latest=ok[:1], asked=[ME], timeline=[requested("2026-11-04T08:00:00Z")]),
                  {"requested"}, need=1)
        self.assertEqual((c["short"], c["approved_by_me"]), ("✓ à relire", False))
        self.assertIn("approuvée 1/1", c["detail"])
        c = state(pr(latest=ok + [review("carol", "APPROVED", "x"), review("dan", "COMMENTED", "x")],
                     threads=[thread("dan", "dan", "2026-11-04T10:00:00Z")]), need=2)
        self.assertEqual((c["state"], c["short"]), ("feedback", "✓✓ retours (1 fil)"))  # ma PR : ma coche ne compte pas
        self.assertEqual(state(pr(latest=ok), need=1)["short"], "✓ approuvée 1/1")
        self.assertEqual(state(pr(author="alice"), {"mentioned"})["checks"], "")

    def test_mentioned(self):
        self.assertEqual(state(pr(author="alice"), {"mentioned"})["state"], "mentioned")

    def test_open_unrequested_kept_only_if_needing_reviewers(self):
        p = pr(author="alice")
        self.assertTrue(b.keep(p, ME, {"open"}, 2))
        self.assertEqual(state(p, {"open"})["state"], "open_unrequested")
        self.assertFalse(b.keep(pr(author="alice", reviews=[review(ME, "COMMENTED", "2026-11-03T08:00:00Z")]),
                                ME, {"open"}, 2))
        self.assertFalse(b.keep(pr(author="alice", latest=[review("bob", "APPROVED", "x"),
                                                           review("carol", "APPROVED", "x")]), ME, {"open"}, 2))


class Build(unittest.TestCase):
    def test_workdays_skip_weekend(self):
        fri = dt.datetime(2026, 11, 6, 12, tzinfo=dt.timezone.utc).astimezone()
        self.assertAlmostEqual(b.workdays(fri, fri + dt.timedelta(days=3)), 1.0, places=5)  # → lundi midi
        self.assertAlmostEqual(b.workdays(fri, fri + dt.timedelta(hours=6)), 0.25, places=5)

    def test_order_and_stale(self):
        now = dt.datetime(2026, 11, 9, 12, tzinfo=dt.timezone.utc)  # lundi
        items = [(pr(n=1, draft=True), {"mine"}),
                 (pr(n=2, latest=[review("b", "CHANGES_REQUESTED", "2026-11-06T12:00:00Z")]), {"mine"}),
                 (pr(n=3, author="alice", asked=[ME], timeline=[requested("2026-11-04T12:00:00Z")]), {"requested"}),
                 (pr(n=4), {"mine"})]
        rows = b.build(ME, items, lambda repo: 2, 2, now)
        # à moi (les miennes puis celles des autres), puis le reste
        self.assertEqual([r["n"] for r in rows], [2, 4, 3, 1])
        self.assertEqual([r["bucket"] for r in rows], ["me", "me", "me", "rest"])
        stale = {r["n"]: r["stale"] for r in rows}
        # 2 : vendredi → lundi, 1 jour ouvré ; 3 : mercredi → lundi, 3 ; 1 : brouillon, jamais signalé
        self.assertEqual(stale, {1: False, 2: False, 3: True, 4: True})


def watcher(mode="auto", handled=None, sessions=(), history=(), interval=5):
    return {"name": "review-watch", "interval": interval, "board": {"to_review": "review"},
            "default": {"review": "notify"}, "repos": [{"repo": "o/r", "review": mode}],
            "handled": {"review": handled or {}}, "sessions": list(sessions), "history": list(history)}


EV = "2026-11-05T08:00:00Z"
NOW = dt.datetime(2026, 11, 5, 12, tzinfo=dt.timezone.utc)


def row(ev=EV, repo="O/R"):
    return {"repo": repo, "n": 5, "state": "to_review", "event_at": ev}


def hist(action, when="2026-11-05T08:05:00Z", detail=""):
    return {"key": "o/r#5:review", "when": when, "action": action, "detail": detail}


class Follow(unittest.TestCase):
    def follow(self, **kw):
        return b.watch([row(kw.pop("ev", EV))], [watcher(**kw)], NOW)[0]["watch"]

    def test_not_seen_is_missed(self):
        f = self.follow()
        self.assertEqual((f["follow"], f["missed"], f["command"]), ("pas vue", True, "gh-watch launch O/R#5"))

    def test_handled_case_insensitive(self):
        f = self.follow(handled={"o/r#5": EV})
        self.assertEqual((f["follow"], f["missed"]), ("traitée", False))

    def test_older_handled_event_is_missed(self):
        self.assertTrue(self.follow(handled={"o/r#5": "2026-11-01T00:00:00Z"})["missed"])

    def test_recent_event_waits_for_next_poll(self):
        f = self.follow(ev="2026-11-05T11:55:00Z")
        self.assertEqual((f["follow"], f["missed"]), ("au prochain passage", False))

    def test_mode_off_and_default(self):
        self.assertEqual(self.follow(mode="off")["follow"], "mode off")
        w = watcher()
        w["repos"] = []
        self.assertEqual(b.watch([row()], [w], NOW)[0]["watch"]["mode"], "notify")

    def test_notify_mode_never_missed(self):
        f = self.follow(mode="notify", history=[hist("notifié")], handled={"o/r#5": EV})
        self.assertEqual((f["mode"], f["missed"]), ("notify", False))
        self.assertFalse(self.follow(mode="notify")["missed"])  # pas vue non plus

    def test_failure_ignored_notified_are_missed(self):
        for action, text in (("échec", "échec"), ("ignoré", "ignorée"), ("notifié", "notifiée")):
            f = self.follow(handled={"o/r#5": EV}, history=[hist(action)])
            self.assertTrue(f["missed"], action)
            self.assertTrue(f["follow"].startswith(text), f["follow"])

    def test_launched_then_history_for_older_event_ignored(self):
        f = self.follow(handled={"o/r#5": EV}, history=[hist("échec", when="2026-11-04T08:00:00Z")])
        self.assertEqual(f["follow"], "traitée")
        self.assertTrue(self.follow(handled={"o/r#5": EV}, history=[hist("lancé")])["follow"].startswith("lancée"))

    def test_sessions(self):
        s = {"key": "o/r#5:review", "launched": "2026-11-05T09:00:00Z", "event_at": None}
        f = self.follow(sessions=[{**s, "status": "ready", "resume": "review-watch resume o/r#5 review"}])
        self.assertEqual((f["follow"], f["missed"], f["command"]),
                         ("prête à reprendre", False, "review-watch resume o/r#5 review"))
        self.assertEqual(self.follow(sessions=[{**s, "status": "ouverte"}])["follow"], "session herdr ouverte")
        self.assertTrue(self.follow(sessions=[{**s, "status": "failed"}])["missed"])
        self.assertFalse(self.follow(sessions=[{**s, "status": "fermée"}])["missed"])
        old = {**s, "launched": "2026-11-04T09:00:00Z", "status": "fermée"}
        self.assertTrue(self.follow(sessions=[old])["missed"])  # session d'un événement antérieur

    def test_state_without_watcher(self):
        self.assertIsNone(b.watch([{**row(), "state": "draft"}], [watcher()], NOW)[0]["watch"])


def load(path, name):
    loader = importlib.machinery.SourceFileLoader(name, os.path.join(ROOT, path))
    mod = importlib.util.module_from_spec(importlib.util.spec_from_loader(name, loader))
    loader.exec_module(mod)
    return mod


class SameAsPoll(unittest.TestCase):
    """Le tableau (build) et le poll des watchers (feedback_events, approved_events) donnent
    les mêmes événements, à la même date."""

    def test_board_and_watchers_agree(self):
        t = "2026-11-04T10:00:00Z"
        prs = [pr(n=1, reviews=[review("bob", "COMMENTED", t)], threads=[thread("bob", "bob", t)]),
               pr(n=2, latest=[review("bob", "APPROVED", t), review("eve", "APPROVED", "2026-11-04T12:00:00Z")],
                  reviews=[review("bob", "APPROVED", t), review("eve", "APPROVED", "2026-11-04T12:00:00Z")]),
               pr(n=3, latest=[review("bob", "APPROVED", t)],
                  reviews=[dict(review("bob", "APPROVED", t), body="Ajoute un test pour le cas vide")]),
               pr(n=4, latest=[review("bob", "APPROVED", t), review("eve", "APPROVED", t)],
                  reviews=[dict(review("bob", "APPROVED", t), body="LGTM 👍")]),
               pr(n=5, latest=[review("bob", "CHANGES_REQUESTED", t)], reviews=[review("bob", "CHANGES_REQUESTED", t)]),
               pr(n=6, draft=True, reviews=[review("bob", "COMMENTED", t)], threads=[thread("bob", "bob", t)]),
               pr(n=7, latest=[review("bob", "APPROVED", t), review("eve", "APPROVED", t)],
                  reviews=[review("bob", "APPROVED", t)], threads=[thread("bob", "bob", t)])]
        old = b.gql
        b.gql = lambda q, v: {"viewer": {"login": ME}, "search": {"nodes": prs}}
        try:
            rw = load("plugins/review/bin/review-watch", "review_watch")
            tw = load("plugins/git-tidy/bin/tidy-watch", "tidy_watch")
            feedback = rw.feedback_events({"feedback": {}}, 300)
            approved, waiting = tw.approved_events({}, {"approved": {}}, 300)
        finally:
            b.gql = old
        rows = b.build(ME, [(p, {"mine"}) for p in prs], lambda repo: 2, 2)
        board = lambda s: sorted((r["n"], r["event_at"]) for r in rows if r["state"] == s)
        self.assertEqual(sorted((n, at) for _, n, _, _, at, todo, _ in feedback if todo), board("feedback"))
        self.assertEqual(sorted((n, at) for _, n, _, _, at in approved), board("approved"))
        self.assertEqual(board("feedback"), [(1, t), (3, t), (5, t), (7, t)])
        self.assertEqual(board("approved"), [(2, "2026-11-04T12:00:00Z"), (4, t)])
        self.assertEqual([x[1] for x in waiting], [7])  # approuvée, mais un fil attend ma réponse
        self.assertNotIn(6, [x[1] for x in feedback])  # brouillon


class Tui(unittest.TestCase):
    def rows(self):
        return [{"repo": "a/x", "n": 1, "bucket": "me", "short": "à relire"},
                {"repo": "a/x", "n": 2, "bucket": "others", "short": "en relecture"},
                {"repo": "b/y", "n": 3, "bucket": "me", "short": "approuvée"}]

    def model(self):
        return tui.Model(self.rows(), lambda r: [f"#{r['n']}", r["short"], "1 h", "", "titre"], True)

    def test_keys(self):
        self.assertEqual([tui.key_action(k) for k in ("z", "s", "\n", "f", "x", "X", "u", "r", "q", "\x1b", "w")],
                         ["up", "down", "launch", "background", "skip", "skip_closed", "unskip", "refresh",
                          "quit", "quit", None])
        self.assertEqual((tui.key_action(tui.curses.KEY_UP), tui.key_action(tui.curses.KEY_DOWN), tui.key_action(10)),
                         ("up", "down", "launch"))

    def test_lines_grouped_by_repo_and_bucket(self):
        lines = self.model().lines()
        self.assertEqual([c if i is None else i for c, i in lines],
                         ["a/x", " À toi", 0, " En attente des autres", 1, "b/y", " À toi", 2])

    def test_move_clamped(self):
        m = self.model()
        tui.apply(m, "up", None)
        self.assertEqual(m.sel, 0)
        for _ in range(5):
            tui.apply(m, "down", None)
        self.assertEqual(m.sel, 2)

    def test_actions(self):
        calls = []

        class Ops:
            @staticmethod
            def launch(r, background):
                calls.append(("launch", r["n"], background))
                return r["n"] != 2, f"lancé {r['n']}" if r["n"] != 2 else "pas d'action à lancer"

            @staticmethod
            def skip(r, until_closed):
                calls.append(("skip", r["n"], until_closed))
                return "écartée"

            @staticmethod
            def unskip(r):
                return False, "pas écartée"

            @staticmethod
            def refresh():
                return [{"repo": "a/x", "n": 9, "bucket": "me", "short": "x"}]
        m = self.model()
        tui.apply(m, "background", Ops)
        tui.apply(m, "down", Ops)
        tui.apply(m, "launch", Ops)
        tui.apply(m, "down", Ops)
        tui.apply(m, "skip_closed", Ops)
        tui.apply(m, "unskip", Ops)
        self.assertEqual(calls, [("launch", 1, True), ("launch", 2, False), ("skip", 3, True)])
        self.assertEqual(m.notes, {0: "en fond", 2: "écartée jusqu'à la fermeture"})  # 2 : échec, pas noté
        self.assertEqual(m.msg, "pas écartée")
        self.assertIn("· en fond", m.lines()[2][0][1])
        tui.apply(m, "refresh", Ops)
        self.assertEqual((m.sel, m.notes, len(m.rows)), (0, {}, 1))
        self.assertFalse(tui.apply(m, "quit", Ops))


if __name__ == "__main__":
    unittest.main(verbosity=1)
