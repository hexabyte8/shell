import QtQuick
import Quickshell
import qs.modules.network
import qs.modules.control
import qs.modules.calendar
import qs.modules.bar
import qs.modules.system
import qs.modules.switcher
import Quickshell.Io
import qs.services as Services
import qs.components
import qs.Osd
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.launcher
import qs.modules.wallpaper
import qs.modules.workspacedisc
import qs.modules.expose

import qs.modules.notes
import qs.modules.clipboard
import qs.modules.notepad
import qs.modules.ollama
import qs.modules.power
import qs.modules.github
import qs.modules.avatar
import qs.modules.updates
import qs.modules.lockthemes
import qs.modules.desktoptheme
import qs.modules.desktopwidgets

ShellRoot {
    id: root

    // This instance owns the compositor side of desktop themes and writes
    // Firefox's stylesheets (the lock screen instance only reads the choice).
    Component.onCompleted: {
        Services.DesktopTheme.manage = true
        Services.FirefoxTheme.manage = true
    }

    // The wallpaper, with the desktop theme's layer over it.
    WallpaperLayer {}
    NotificationToasts {}
    CalendarWindow {}
    DesktopWidgetsLayer {}
    WorkspaceDiscWindow {}
    Expose {}
    WindowSwitcher{}
    // Hover strips along the screen edges that open the launcher, the notes
    // drawer and the GitHub popout. Each is a tiny surface of its own, so the
    // full-screen panel surface below can shrink away while no panel is open.
    // Declared before it: surfaces on one layer stack in creation order, and
    // the panels must cover the strips (rootPanel's mask leaves them out, so
    // they keep working while a panel is open, as when they lived inside it).
    component EdgeTrigger: PanelWindow {
        id: trigger

        signal hovered
        signal clicked

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: trigger.hovered()
            onClicked: trigger.clicked()

            Rectangle {
                anchors.fill: parent
                color: parent.containsMouse ? "#40FFFFFF" : "transparent"
                visible: parent.containsMouse
            }
        }
    }

    EdgeTrigger {
        id: notesDrawerTrigger
        anchors.bottom: true
        implicitWidth: 900
        implicitHeight: 2
        onClicked: notesDrawer.opened = !notesDrawer.opened
    }

    EdgeTrigger {
        id: githubTrigger
        anchors.right: true
        anchors.bottom: true
        implicitWidth: 2
        implicitHeight: 500
        onHovered: ghPopout.opened = !ghPopout.opened
    }

    EdgeTrigger {
        id: launcherTrigger
        anchors.left: true
        anchors.bottom: true
        implicitWidth: 2
        implicitHeight: 600
        onHovered: launcherWindow.toggle()
    }

    OsdWindow {}

    PanelWindow {
        id: rootPanel

        // Follow the currently focused monitor so popups (launcher, power
        // menu, clipboard, etc.) always appear where the user is actually
        // looking, instead of being pinned to whichever screen Quickshell
        // picked as the default on startup. Quickshell.screens entries and
        // Hyprland monitors share the same Wayland output `name` (e.g.
        // "DP-1"), so match on that. Kept reactive (not just updated on
        // toggle) so the surface is already on the right output by the time
        // a panel opens.
        readonly property var focusedScreen: {
            const mon = Services.Hyprland.focusedMonitor
            if (!mon)
                return null
            return Quickshell.screens.find(s => s.name === mon.name) ?? null
        }
        screen: focusedScreen ?? Quickshell.screens[0] ?? null

        // Whether any panel is up (or on its way out). While none is, the
        // surface shrinks to a pixel in the corner rather than being unmapped
        // (a new map would stack it over the bar and take keyboard focus):
        // its full-screen buffers cost GPU memory, and the compositor blends
        // it into every frame it draws. hypr/quickshell.lua turns Hyprland's
        // layer animation off for this namespace, or the panels would be
        // drawn growing out of the corner as the surface grows.
        WlrLayershell.namespace: "quickshell:panels"
        readonly property bool needed: ghPopout.visible
            || systemPanel.visible
            || updatesPanel.visible
            || networkPanelLoader.active
            || notesDrawer.opened || notesDrawer.implicitHeight > 0
            || launcherWindow.isOpen
            || wallpaperLoader.active
            || controlCenterLoader.active
            || chatLoader.active
            || clipboardLoader.active
            || notepad.visible
            || powerMenu.visible
            || avatarPicker.visible
            || lockThemes.visible
        readonly property real screenW: screen ? screen.width : 1920
        readonly property real screenH: screen ? screen.height : 1200

        exclusionMode: ExclusionMode.Ignore
        implicitHeight: needed ? screenH : 1
        implicitWidth: needed ? screenW : 1
        anchors {
            top: true
            bottom: needed
            left: true
            right: needed
        }
        color: "transparent"
        focusable: true

        // The panels, laid out on the whole screen whatever the surface's
        // size at the moment (it grows from and shrinks to the top-left
        // corner, so nothing moves).
        Item {
            width: rootPanel.screenW
            height: rootPanel.screenH

            GhPopout {
                id: ghPopout
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
            }
            SystemPanel {
                id: systemPanel
            }
            UpdatesPanel {
                id: updatesPanel
                anchors {
                    right: parent.right
                    top: parent.top
                }
            }
            Loader {
                id: networkPanelLoader
                active: false
                anchors.fill: parent
                sourceComponent: NetworkPanel {
                    id: networkPanel
                }
            }

            NotesDrawer{
                id: notesDrawer
            }

            LauncherWindow{
                id: launcherWindow
            }

            Loader {
                id: wallpaperLoader
                active: false
                anchors.fill: parent
                sourceComponent: Wallpaper {}
                focus: true
            }

            Loader {
                active: false
                id: controlCenterLoader
                anchors.fill: parent
                sourceComponent: ControlCenter {
                    id: controlCenter
                }
                focus: true
            }
            Loader {
                active: false
                id: chatLoader
                anchors.centerIn: parent
                sourceComponent: OllamaChat{
                    id: ollamaChat
                }
                focus: true
            }
            // Built for each opening (the emoji and kaomoji lists, the history
            // and its thumbnails stayed in memory behind the closed panel), on
            // the tab it was last left on.
            Loader {
                id: clipboardLoader
                active: false
                anchors.fill: parent
                focus: true

                property int lastTab: 0

                sourceComponent: ClipboardManager {
                    currentTab: clipboardLoader.lastTab
                    onCurrentTabChanged: clipboardLoader.lastTab = currentTab
                }
            }

            NotepadPanel {
                id: notepad
            }

            PowerMenu {
                id: powerMenu
            }

            AvatarPicker {
                id: avatarPicker
            }

            LockThemesPanel {
                id: lockThemes
            }

        }

        property bool altHeld: false

        mask: Region{
            Region{
                item: systemPanel
            }
            Region {
                item: networkPanelLoader.item && networkPanelLoader.item.visible ? networkPanelLoader.item : null
            }
            Region{
                item: notesDrawer.opened ? notesDrawer : null
            }
            Region{
                item: controlCenterLoader.item && controlCenterLoader.item.visible ? controlCenterLoader.item : null
            }
            Region {
                item: ghPopout
            }
            Region {
                item: updatesPanel.opened ? updatesPanel : null
            }
            Region {
                item: launcherWindow.isOpen ? launcherWindow : null
            }
            Region{
                item: wallpaperLoader.item && wallpaperLoader.item.visible ? wallpaperLoader.item : null
            }
            Region{
                item: chatLoader.active ? chatLoader : null
            }
            Region {
                item: clipboardLoader.item && clipboardLoader.item.visible ? clipboardLoader.item : null
            }
            Region {
                item: notepad.visible ? notepad : null
            }
            Region {
                item: powerMenu.visible ? powerMenu : null
            }
            Region {
                item: avatarPicker
            }
            Region {
                item: lockThemes.visible ? lockThemes : null
            }
            // The edge strips stay with their own surfaces below.
            Region {
                intersection: Intersection.Subtract
                x: (rootPanel.screenW - notesDrawerTrigger.implicitWidth) / 2
                y: rootPanel.screenH - notesDrawerTrigger.implicitHeight
                width: notesDrawerTrigger.implicitWidth
                height: notesDrawerTrigger.implicitHeight
            }
            Region {
                intersection: Intersection.Subtract
                x: rootPanel.screenW - githubTrigger.implicitWidth
                y: rootPanel.screenH - githubTrigger.implicitHeight
                width: githubTrigger.implicitWidth
                height: githubTrigger.implicitHeight
            }
            Region {
                intersection: Intersection.Subtract
                x: 0
                y: rootPanel.screenH - launcherTrigger.implicitHeight
                width: launcherTrigger.implicitWidth
                height: launcherTrigger.implicitHeight
            }
        }
    }

    // The bar has its own 42px surface: hover animations and value updates in
    // the bar then repaint a thin strip instead of the fullscreen panel
    // surface above. It also reserves the bar's exclusive zone. Declared after
    // rootPanel so it stacks above it on the Top layer.
    //
    // Inside the old shared surface, panels declared after TopBar drew over
    // it while the ones before it (media, GitHub, system, updates, network,
    // which hang from the bar) drew under it. To keep that, the bar drops to
    // the Bottom layer — beneath rootPanel — while any of the later panels is
    // open. The layer changes in place (layer-shell set_layer), no remap.
    PanelWindow {
        id: barWindow

        readonly property bool coveredByPanel: notesDrawer.opened
            || launcherWindow.isOpen
            || (wallpaperLoader.item !== null && wallpaperLoader.item.visible)
            || (controlCenterLoader.item !== null && controlCenterLoader.item.visible)
            || chatLoader.active
            || (clipboardLoader.item !== null && clipboardLoader.item.visible)
            || notepad.visible
            || powerMenu.visible
            || avatarPicker.visible
            || lockThemes.visible

        WlrLayershell.layer: coveredByPanel ? WlrLayer.Bottom : WlrLayer.Top
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 42
        color: "transparent"

        TopBar {
            id: topBar
        }
    }

    Timer {
        id: closeChatTimer
        interval: 600
        onTriggered: chatLoader.active = false
    }

    Connections {
        target: chatLoader.item
        function onVisibleChanged() {
            if (chatLoader.item && !chatLoader.item.visible) {
                closeChatTimer.start()
            }
        }
    }

    Timer {
        id: closeNetworkTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!networkPanelLoader.item?.opened) networkPanelLoader.active = false
    }

    Connections {
        target: networkPanelLoader.item
        function onOpenedChanged() {
            if (networkPanelLoader.item && !networkPanelLoader.item.opened) {
                closeNetworkTimer.start()
            }
        }
    }

    // bluetoothd wants an answer (a pairing code, a device asking to
    // connect): bring up the Bluetooth tab, where the question is.
    Connections {
        target: Services.Bluetooth
        function onRequestArrived() {
            if (!networkPanelLoader.active)
                networkPanelLoader.active = true
            const panel = networkPanelLoader.item
            if (!panel)
                return
            panel.currentTab = 1
            panel.opened = true
        }
    }

    Timer {
        id: closeWallpaperTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!wallpaperLoader.item?.visible) wallpaperLoader.active = false
    }

    Connections {
        target: wallpaperLoader.item
        function onVisibleChanged() {
            if (wallpaperLoader.item && !wallpaperLoader.item.visible) {
                closeWallpaperTimer.start()
            }
        }
    }

    Timer {
        id: closeControlCenterTimer
        interval: 600
        onTriggered: controlCenterLoader.active = false
    }

    Connections {
        target: controlCenterLoader.item
        function onOpenedChanged() {
            if (controlCenterLoader.item && !controlCenterLoader.item.opened) {
                closeControlCenterTimer.start()
            }
        }
    }

    IpcHandler {
        target: "networkPanel"

        function changeVisible(tab: string): void {
            if (!networkPanelLoader.active)
                networkPanelLoader.active = true

            const panel = networkPanelLoader.item
            if (!panel)
                return

            if (panel.opened) {
                panel.opened = false
                return
            }

            if (tab === "wifi")
                panel.currentTab = 0
            else if (tab === "bluetooth")
                panel.currentTab = 1

            if (tab !== undefined)
                panel.opened = true
            else
                panel.opened = !panel.opened
        }
    }

    IpcHandler {
        target: "controlCenter"
        function changeVisible(): void {
            if (!controlCenterLoader.active) {
                controlCenterLoader.active = true
                controlCenterLoader.item.opened = true
            } else {
                controlCenterLoader.item.opened = !controlCenterLoader.item.opened
            }
        }
    }

    IpcHandler {
        target: "ollamaChat"
        function changeVisible(): void {
            if (!chatLoader.active) {
                chatLoader.active = true
                chatLoader.item.visible = true
            } else {
                chatLoader.item.visible = !chatLoader.item.visible
            }
        }
    }

    IpcHandler {
        target: "launcherWindow"

        function toggle() {
            launcherWindow.toggle()
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() {
            if (!wallpaperLoader.active)
                wallpaperLoader.active = true
            const picker = wallpaperLoader.item
            if (!picker.visible || picker.closing)
                picker.open()
            else
                picker.close()
        }
        function set(path: string): void {
            Services.WallpaperEngine.set(path)
        }
        function wallhaven(): void {
            if (!wallpaperLoader.active)
                wallpaperLoader.active = true
            wallpaperLoader.item.open()
            wallpaperLoader.item.setMode("wallhaven")
        }
        function current(): string {
            return Services.WallpaperEngine.current
        }
    }

    Timer {
        id: closeWindowSwitcherTimer
        interval: 300
        onTriggered: windowSwitcherLoader.active = false
    }

    IpcHandler {
        target: "clipboardManager"
        function changeVisible(): void {
            if (!clipboardLoader.active)
                clipboardLoader.active = true
            const clipboard = clipboardLoader.item
            if (!clipboard.visible) {
                clipboard.open()
            } else {
                clipboard.close()
            }
        }
    }

    Timer {
        id: closeClipboardTimer
        interval: 600
        // unless it was opened again in the meantime
        onTriggered: if (!clipboardLoader.item?.visible) clipboardLoader.active = false
    }

    Connections {
        target: clipboardLoader.item
        function onVisibleChanged() {
            if (clipboardLoader.item && !clipboardLoader.item.visible) {
                closeClipboardTimer.start()
            }
        }
    }

    IpcHandler {
        target: "notepad"
        function toggle(): void {
            notepad.toggle()
        }
    }

    IpcHandler {
        target: "powerMenu"
        function toggle(): void {
            if (!powerMenu.visible) {
                powerMenu.open()
            } else {
                powerMenu.close()
            }
        }
    }

    IpcHandler {
        target: "desktopTheme"
        function toggle(): void {
            Services.DesktopTheme.toggle()
        }
        function enable(): void {
            if (!Services.DesktopTheme.enabled)
                Services.DesktopTheme.toggle()
        }
        function set(theme: string): void {
            Services.DesktopTheme.setTheme(theme)
        }
        function disable(): void {
            Services.DesktopTheme.setTheme("")
        }
        function screenEffect(mode: string): void {
            Services.DesktopTheme.setScreenEffect(mode)
        }
    }

    IpcHandler {
        target: "themes"
        function toggle(): void {
            lockThemes.toggle()
        }
        function desktop(): void {
            lockThemes.openTab("desktop")
        }
        function lockscreen(): void {
            lockThemes.openTab("lock")
        }
        function widgets(): void {
            lockThemes.openTab("widgets")
        }
    }

    IpcHandler {
        target: "widgets"
        function toggle(): void {
            if (lockThemes.visible && lockThemes.tab === "widgets")
                lockThemes.close()
            else
                lockThemes.openTab("widgets")
        }
        function enable(id: string): void {
            Services.DesktopWidgets.setEnabled(id, true)
        }
        function disable(id: string): void {
            Services.DesktopWidgets.setEnabled(id, false)
        }
        function reset(): void {
            Services.DesktopWidgets.resetPositions()
        }
    }

    IpcHandler {
        target: "lockscreen"
        function toggle(): void {
            lockThemes.toggle()
        }
        function open(): void {
            lockThemes.open()
        }
        function close(): void {
            lockThemes.close()
        }
        function lock(): void {
            lockThemes.lockNow()
        }
        function preview(theme: string): void {
            lockThemes.preview(theme)
        }
    }

    IpcHandler {
        target: "avatarPicker"
        function toggle(): void {
            if (!avatarPicker.opened) {
                avatarPicker.open()
            } else {
                avatarPicker.close()
            }
        }
    }

    IpcHandler {
        target: "barLayout"
        function reset(): void {
            Services.BarLayout.reset()
        }
    }

    IpcHandler {
        target: "updatesPanel"
        function toggle(): void {
            updatesPanel.opened = !updatesPanel.opened
            if (updatesPanel.opened)
                Services.Updates.refresh()
        }
        function refresh(): void {
            Services.Updates.refresh()
        }
    }
}
