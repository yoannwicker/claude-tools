import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const STATE_DIR = GLib.build_filenamev([GLib.get_user_state_dir(), 'claude-notify']);
// Link to notify-click.sh of the notify Claude Code plugin, set by ./install.sh plugin notify
const CLICK_SCRIPT = GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'claude-notify-click']);

function run(...args) {
    try {
        Gio.Subprocess.new(['bash', CLICK_SCRIPT, ...args],
            Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE);
    } catch (e) {
        console.error(`claude-notify: ${e.message}`);
    }
}

function readPending() {
    const dir = Gio.File.new_for_path(STATE_DIR);
    const pending = [];
    let children;
    try {
        children = dir.enumerate_children('standard::name', Gio.FileQueryInfoFlags.NONE, null);
    } catch (e) {
        return pending;
    }
    let info;
    while ((info = children.next_file(null)) !== null) {
        const name = info.get_name();
        if (!name.endsWith('.json'))
            continue;
        const path = GLib.build_filenamev([STATE_DIR, name]);
        try {
            const [, bytes] = GLib.file_get_contents(path);
            const data = JSON.parse(new TextDecoder().decode(bytes));
            pending.push({path, ...data});
        } catch (e) {
            // partially written file: the monitor will fire again
        }
    }
    children.close(null);
    return pending.sort((a, b) => (b.time ?? 0) - (a.time ?? 0));
}

class ClaudeNotifyButton extends PanelMenu.Button {
    static {
        GObject.registerClass(this);
    }

    _init() {
        super._init(0.0, 'Claude Notify', false);
        const box = new St.BoxLayout({style_class: 'panel-status-menu-box'});
        this._icon = new St.Label({
            text: '✳',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'claude-notify-icon',
        });
        this._count = new St.Label({
            text: '',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'claude-notify-count',
        });
        box.add_child(this._icon);
        box.add_child(this._count);
        this.add_child(box);
        this.refresh();
    }

    refresh() {
        const pending = readPending();
        this._count.text = `${pending.length}`;
        this._count.visible = pending.length > 0;
        if (pending.length > 0)
            this._icon.remove_style_class_name('dim');
        else
            this._icon.add_style_class_name('dim');

        this.menu.removeAll();
        if (pending.length === 0) {
            const item = new PopupMenu.PopupMenuItem('Aucune notification en attente', {reactive: false});
            this.menu.addMenuItem(item);
            return;
        }
        for (const n of pending) {
            const item = new PopupMenu.PopupBaseMenuItem();
            const column = new St.BoxLayout({vertical: true, x_expand: true});
            column.add_child(new St.Label({text: n.title ?? 'Claude Code', style_class: 'claude-notify-title'}));
            if (n.body)
                column.add_child(new St.Label({text: n.body, style_class: 'claude-notify-body'}));
            item.add_child(column);
            item.connect('activate', () => run('--open', n.path));
            this.menu.addMenuItem(item);
        }
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        const clear = new PopupMenu.PopupMenuItem('Tout effacer');
        clear.connect('activate', () => run('--clear-all'));
        this.menu.addMenuItem(clear);
    }
}

export default class ClaudeNotifyExtension extends Extension {
    enable() {
        GLib.mkdir_with_parents(STATE_DIR, 0o755);
        this._button = new ClaudeNotifyButton();
        Main.panel.addToStatusArea(this.uuid, this._button, 0, 'right');
        this._monitor = Gio.File.new_for_path(STATE_DIR)
            .monitor_directory(Gio.FileMonitorFlags.NONE, null);
        this._monitorId = this._monitor.connect('changed', () => this._scheduleRefresh());
    }

    disable() {
        if (this._refreshId) {
            GLib.source_remove(this._refreshId);
            this._refreshId = null;
        }
        if (this._monitor) {
            this._monitor.disconnect(this._monitorId);
            this._monitor.cancel();
            this._monitor = null;
        }
        this._button?.destroy();
        this._button = null;
    }

    _scheduleRefresh() {
        if (this._refreshId)
            return;
        this._refreshId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
            this._refreshId = null;
            this._button?.refresh();
            return GLib.SOURCE_REMOVE;
        });
    }
}
