pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick

// Desktop widgets (modules/desktopwidgets): which are on and where they sit.
// A position is stored as a fraction of the free space on the screen
// (0 = left/top edge, 1 = right/bottom edge), so widgets stay on screen and
// keep their place across resolutions. The visualizer keeps its own settings
// (services/CavaWidget.qml); here it is only listed and switched.
//
// Settings: ~/.config/quickshell/desktopwidgets.json.
Singleton {
    id: root

    readonly property var widgets: [
        { id: "clock", name: "Clock", icon: "schedule", description: "The theme's own clock face", x: 0.03, y: 0.08 },
        { id: "music", name: "Music player", icon: "music_note", description: "Now playing, with controls", x: 0.97, y: 0.08 },
        { id: "sysmon", name: "System monitor", icon: "monitoring", description: "CPU, memory, temperature and disk", x: 0.97, y: 0.52 },
        { id: "quote", name: "Headlines", icon: "sentiment_very_satisfied", description: "A fresh Hacker News headline every ten minutes", x: 0.03, y: 0.98 },
        { id: "cava", name: "Visualizer", icon: "graphic_eq", description: "Cava spectrum of what's playing" }
    ]

    readonly property var defaults: ({ clock: true, music: true, sysmon: true, quote: true })

    function info(id) {
        return widgets.find(w => w.id === id);
    }

    function enabled(id) {
        if (id === "cava")
            return CavaWidget.enabled;
        const v = adapter.on[id];
        return v === undefined ? (defaults[id] ?? false) : v;
    }

    function setEnabled(id, on) {
        if (id === "cava") {
            CavaWidget.enabled = on;
            CavaWidget.save();
            return;
        }
        const next = Object.assign({}, adapter.on);
        next[id] = on;
        adapter.on = next;
    }

    function toggle(id) {
        setEnabled(id, !enabled(id));
    }

    // { x, y } fractions.
    function pos(id) {
        const p = adapter.positions[id];
        const w = info(id);
        return p ? p : { x: w ? w.x : 0, y: w ? w.y : 0 };
    }

    function setPos(id, x, y) {
        const next = Object.assign({}, adapter.positions);
        next[id] = { x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y)) };
        adapter.positions = next;
    }

    function resetPositions() {
        adapter.positions = ({});
        CavaWidget.posX = 40;
        CavaWidget.posY = 880;
        CavaWidget.save();
    }

    // ── Headlines (the quote widget) — a Hacker News top-story title,
    // fetched only while it's on. Keeps the old joke/refreshJoke names so
    // QuoteWidget.qml and the widgets list above don't need to change.
    property string joke: ""

    function refreshJoke() {
        topStoriesProc.running = true;
    }

    Timer {
        interval: 10 * 60 * 1000
        running: root.enabled("quote")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshJoke()
    }

    // Step 1: grab the top-story id list, then pick one of the first 30
    // and fetch its title.
    Process {
        id: topStoriesProc
        command: ["curl", "-s", "-m", "10", "https://hacker-news.firebaseio.com/v0/topstories.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ids = JSON.parse(text);
                    if (Array.isArray(ids) && ids.length > 0) {
                        const pick = ids[Math.floor(Math.random() * Math.min(30, ids.length))];
                        headlineProc.command = ["curl", "-s", "-m", "10", "https://hacker-news.firebaseio.com/v0/item/" + pick + ".json"];
                        headlineProc.running = true;
                    }
                } catch (e) {
                    // leave the previous headline up rather than clearing it
                }
            }
        }
    }

    // Step 2: fetch the picked story's title.
    Process {
        id: headlineProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const item = JSON.parse(text);
                    if (item && item.title)
                        root.joke = item.title;
                } catch (e) {
                    // ignore malformed response
                }
            }
        }
    }

    // ── Settings ─────────────────────────────────────────────────────────────
    Timer {
        id: writeTimer
        interval: 150
        onTriggered: settingsFile.writeAdapter()
    }

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/desktopwidgets.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeTimer.restart()

        adapter: JsonAdapter {
            id: adapter
            property var on: ({})
            property var positions: ({})
        }
    }
}
