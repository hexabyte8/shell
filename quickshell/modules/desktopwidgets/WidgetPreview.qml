pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services as Services

// The desktop widgets for a preview in the Themes panel: each enabled widget
// at its place on a screen-sized item (the caller scales it), in the look of
// `themeId`. With `editable` they can be dragged here too, which moves them
// on the desktop.
Item {
    id: root

    property string themeId: Services.DesktopTheme.enabled ? Services.DesktopTheme.theme : ""
    property bool editable: false

    readonly property var ids: ["clock", "sysmon", "quote"]
    readonly property var components: ({ clock: clockC, sysmon: sysmonC, quote: quoteC })

    width: Quickshell.screens[0]?.width ?? 1920
    height: Quickshell.screens[0]?.height ?? 1080

    // Drag in item coordinates; `commit(x, y)` stores the result.
    component Draggable: MouseArea {
        id: dragArea

        property Item target
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false
        property real dragX: 0
        property real dragY: 0
        signal commit(real x, real y)

        anchors.fill: parent
        enabled: root.editable
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: mouse => {
            dragX = target.x;
            dragY = target.y;
            pressX = mouse.x;
            pressY = mouse.y;
            dragging = true;
        }
        onPositionChanged: mouse => {
            dragX = Math.max(0, Math.min(root.width - target.width, dragX + mouse.x - pressX));
            dragY = Math.max(0, Math.min(root.height - target.height, dragY + mouse.y - pressY));
        }
        onReleased: {
            commit(dragX, dragY);
            dragging = false;
        }
        onCanceled: dragging = false
    }

    Repeater {
        model: root.ids

        Item {
            id: slot

            required property string modelData
            readonly property var frac: Services.DesktopWidgets.pos(modelData)

            visible: Services.DesktopWidgets.enabled(modelData)
            width: loader.implicitWidth
            height: loader.implicitHeight
            x: drag.dragging ? drag.dragX : Math.round(frac.x * (root.width - width))
            y: drag.dragging ? drag.dragY : Math.round(frac.y * (root.height - height))

            Loader {
                id: loader
                sourceComponent: root.components[slot.modelData]
            }

            Draggable {
                id: drag
                target: slot
                onCommit: (x, y) => Services.DesktopWidgets.setPos(slot.modelData, x / Math.max(1, root.width - slot.width), y / Math.max(1, root.height - slot.height))
            }
        }
    }

    Component {
        id: clockC
        ClockWidget { themeId: root.themeId }
    }

    Component {
        id: sysmonC
        SysmonWidget { themeId: root.themeId }
    }

    Component {
        id: quoteC
        QuoteWidget { themeId: root.themeId }
    }
}
