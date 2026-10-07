import QtQuick
import Quickshell.Io
pragma Singleton

Item {
    id: root

    property real percentage: 0
    property bool charging: false
    property bool full: percentage >= 100

    function getIcon(percent, charging, isReady) {
        if (!isReady)
            return Icons.batteryUnknown;

        if (charging)
            return Icons.batteryCharging;

        const p = Math.round(percent);
        if (p >= 90)
            return Icons.battery100;

        if (p >= 80)
            return Icons.battery90;

        if (p >= 70)
            return Icons.battery80;

        if (p >= 60)
            return Icons.battery70;

        if (p >= 50)
            return Icons.battery60;

        if (p >= 40)
            return Icons.battery50;

        if (p >= 30)
            return Icons.battery40;

        if (p >= 20)
            return Icons.battery30;

        if (p >= 10)
            return Icons.battery20;

        return Icons.battery10;
    }

    function getStateColor(percent, charging, full) {
        if (charging)
            return "#a6e3a1";

        if (full)
            return "#89b4fa";

        if (percent <= 20)
            return "#f38ba8";

        if (percent <= 40)
            return "#fab387";

        return "#cdd6f4";
    }

    function formatTime(seconds) {
        if (seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0)
            return hours + "h " + minutes + "m";

        return minutes + "m";
    }

    // Read sysfs directly rather than spawning sh + cat every poll. The
    // battery's sysfs name isn't always BAT0 (e.g. this is BAT1 here), so
    // discover it once at startup instead of hardcoding it — with
    // printErrors disabled a wrong hardcoded name silently stays at 0%
    // forever rather than erroring.
    Process {
        id: findBattery
        command: ["bash", "-c", "ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                if (!dir)
                    return;
                capacityFile.path = dir + "/capacity";
                statusFile.path = dir + "/status";
                capacityFile.reload();
                statusFile.reload();
            }
        }
    }

    FileView {
        id: capacityFile
        printErrors: false
        onLoaded: root.percentage = parseInt(text()) || 0
    }

    FileView {
        id: statusFile
        printErrors: false
        onLoaded: root.charging = text().trim() === "Charging"
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            capacityFile.reload();
            statusFile.reload();
        }
    }

}