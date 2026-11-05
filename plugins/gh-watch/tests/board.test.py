#!/usr/bin/env python3
"""Tests du classement de gh-watch board : python3 plugins/gh-watch/tests/board.test.py
PR fictives (nœuds GraphQL), sans réseau."""
import datetime as dt, os, sys, unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "lib"))
import board as b  # noqa: E402

ME = "moi"


def user(login, bot=False):
    return {"__typename": "Bot" if bot else "User", "login": login}


def review(login, state, at, bot=False):
    return {"author": user(login, bot), "state": state, "submittedAt": at}


def thread(first, last, at, resolved=False):
    return {"isResolved": resolved,
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
        self.assertEqual(c["state"], "reviewed")
        self.assertIn("l'auteur a répondu (1 fil(s))", c["detail"])
        self.assertEqual((c["short"], c["bucket"]), ("réponse de l'auteur (1 fil)", "me"))

    def test_reviewed_approved(self):
        c = state(pr(author="alice", reviews=[review(ME, "APPROVED", "2026-11-03T08:00:00Z")],
                     latest=[review(ME, "APPROVED", "2026-11-03T08:00:00Z")]), {"reviewed"})
        self.assertIn("approuvée par moi", c["detail"])

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


if __name__ == "__main__":
    unittest.main(verbosity=1)
