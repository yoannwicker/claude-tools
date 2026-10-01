#!/usr/bin/env python3
"""Desktop notification lifecycle for Claude Code hooks.

show   reads a JSON payload on stdin (title, body, urgency, session context),
       shows the notification, records it as pending in the state dir, waits
       for the click (-> notify-click.sh --open) or the dismissal.
close  <id> closes a notification by its server id.
"""
import json
import os
import subprocess
import sys
import time

import gi

gi.require_version("Notify", "0.7")
from gi.repository import GLib, Notify  # noqa: E402

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "claude-notify"
)
CLICK = os.path.expanduser("~/.claude/notify-click.sh")
DISMISSED = 2


def show(payload):
    Notify.init("Claude Code")
    n = Notify.Notification.new(payload["title"], payload.get("body") or "…")
    n.set_urgency(
        Notify.Urgency.CRITICAL if payload.get("urgency") == "critical" else Notify.Urgency.NORMAL
    )
    result = {}
    loop = GLib.MainLoop()

    def on_action(_n, action, _data):
        result["action"] = action
        loop.quit()

    def on_closed(notif):
        result.setdefault("reason", notif.get_closed_reason())
        loop.quit()

    n.add_action("default", "Ouvrir", on_action, None)
    n.connect("closed", on_closed)
    n.show()
    payload["id"] = n.get_property("id")
    payload["time"] = time.time()
    os.makedirs(STATE_DIR, exist_ok=True)
    path = os.path.join(STATE_DIR, f'{payload["id"]}.json')
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)

    def on_tick():
        # cleared from the panel menu or by UserPromptSubmit: nothing left to wait for
        if os.path.exists(path):
            return GLib.SOURCE_CONTINUE
        result.setdefault("reason", "cleared")
        loop.quit()
        return GLib.SOURCE_REMOVE

    GLib.timeout_add(500, on_tick)
    loop.run()
    if result.get("action") == "default":
        subprocess.run(["bash", CLICK, "--open", path], check=False)
    elif result.get("reason") == DISMISSED:
        try:
            os.remove(path)
        except FileNotFoundError:
            pass


def close(notification_id):
    Notify.init("Claude Code")
    n = Notify.Notification.new("", "")
    n.set_property("id", int(notification_id))
    try:
        n.close()
    except GLib.Error:
        pass


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd == "close":
        close(sys.argv[2])
    else:
        show(json.load(sys.stdin))
