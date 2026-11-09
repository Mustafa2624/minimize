import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property var activeTarget: widget || module
    readonly property var barWindow: activeTarget ? activeTarget.barWindow : null
    readonly property bool isCompact: activeTarget ? activeTarget.isCompact : false

    property string orientation: (activeTarget && activeTarget.orientation !== undefined)
        ? activeTarget.orientation
        : "horizontal"
    readonly property bool isVertical: orientation === "vertical"
    readonly property bool moduleActive: module ? module.moduleActive : true

    function px(value) {
        return barWindow && typeof barWindow.s === "function"
            ? barWindow.s(value)
            : value
    }

    readonly property string shelfWorkspace: "special:omarchy-minimized"
    property var minimizedOrigins: ({})

    property bool showLayout: false
    Timer {
        running: root.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    property int modelRevision: 0

    Connections {
        target: (typeof Hyprland !== "undefined" && Hyprland.toplevels) ? Hyprland.toplevels : null
        function onValuesChanged() { root.modelRevision++ }
    }

    Connections {
        target: (typeof Hyprland !== "undefined") ? Hyprland : null
        function onRawEvent(event) {
            if (!event || !event.name) return
            const n = event.name
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "workspace"
                    || n === "activewindow" || n === "activewindowv2" || n === "focusedmon") {
                root.modelRevision++
                refreshTimer.restart()
            }
        }
        function onActiveToplevelChanged() { root.modelRevision++ }
        function onFocusedWorkspaceChanged() { root.modelRevision++ }
    }

    Timer {
        id: refreshTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (typeof Hyprland !== "undefined" && typeof Hyprland.refreshToplevels === "function") {
                Hyprland.refreshToplevels()
            }
        }
    }

    readonly property var minimizedWindows: {
        let rev = root.modelRevision
        let out = []
        if (typeof Hyprland === "undefined" || !Hyprland.toplevels || !Hyprland.toplevels.values) return out
        let vals = Hyprland.toplevels.values
        for (let i = 0; i < vals.length; i++) {
            let t = vals[i]
            if (t && t.workspace && t.workspace.name === shelfWorkspace) {
                out.push(t)
            }
        }
        return out
    }

    readonly property var activeWindow: (typeof Hyprland !== "undefined") ? Hyprland.activeToplevel : null
    readonly property bool canMinimize: activeWindow !== null
        && activeWindow.workspace !== null
        && activeWindow.workspace.name !== shelfWorkspace

    function normalizedAddress(addr) {
        if (!addr) return ""
        let s = String(addr).trim()
        return s.indexOf("0x") === 0 ? s : "0x" + s
    }

    function moveWindow(t, workspace, follow) {
        if (!t) return
        let addr = normalizedAddress(t.address)
        if (!addr || !workspace) return
        if (typeof Hyprland !== "undefined" && Hyprland.usingLua === false) {
            let action = follow ? "movetoworkspace" : "movetoworkspacesilent"
            Quickshell.execDetached(["hyprctl", "dispatch", action + " " + workspace + ",address:" + addr])
        } else {
            let cmd = 'hl.dsp.window.move({ workspace = "' + workspace + '", window = "address:' + addr + '", follow = ' + (follow ? 'true' : 'false') + ' })'
            Quickshell.execDetached(["hyprctl", "dispatch", cmd])
        }
        if (typeof Hyprland !== "undefined" && typeof Hyprland.refreshToplevels === "function") {
            refreshTimer.restart()
        }
    }

    function minimizeActive() {
        if (!canMinimize) return
        let t = activeWindow
        let addr = normalizedAddress(t.address)
        let ws = t.workspace ? String(t.workspace.name) : ""
        if (addr && ws && ws.indexOf("special:") !== 0) {
            minimizedOrigins[addr] = ws
            minimizedOrigins = Object.assign({}, minimizedOrigins)
        }
        moveWindow(t, shelfWorkspace, false)
    }

    function restore(t) {
        if (!t) return
        let addr = normalizedAddress(t.address)
        let curWs = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace)
            ? String(Hyprland.focusedWorkspace.name) : "1"
        let targetWs = minimizedOrigins[addr] || (curWs.indexOf("special:") !== 0 ? curWs : "1")
        delete minimizedOrigins[addr]
        minimizedOrigins = Object.assign({}, minimizedOrigins)
        moveWindow(t, targetWs, true)
    }

    function windowTitle(t) {
        let title = String(t && t.title ? t.title : "Window").trim()
        if (title.length > 18) return title.substring(0, 15) + "..."
        return title.length > 0 ? title : "Window"
    }

    function windowInitial(t) {
        let ipc = t ? t.lastIpcObject : null
        let name = String(ipc && ipc.class ? ipc.class : windowTitle(t)).trim()
        return name.length > 0 ? name.charAt(0).toUpperCase() : "W"
    }

    function windowIcon(t) {
        if (!t) return ""
        let ipc = t.lastIpcObject || null
        let wayland = t.wayland || null
        let candidates = [
            wayland && wayland.appId ? wayland.appId : "",
            ipc && ipc.class ? ipc.class : "",
            ipc && ipc.initialClass ? ipc.initialClass : ""
        ]
        let iconName = ""
        for (let i = 0; i < candidates.length; i++) {
            let candidate = String(candidates[i] || "").trim()
            if (!candidate) continue
            if (typeof AppMatcher !== "undefined") {
                let id = AppMatcher.resolve(candidate)
                let entry = id ? AppMatcher.entry(id) : null
                if (entry && entry.icon) {
                    iconName = entry.icon
                    break
                }
            }
            iconName = candidate
            break
        }
        if (!iconName) return ""
        if (iconName.indexOf("/") === 0 || iconName.indexOf("file://") === 0 || iconName.indexOf("image://") === 0) {
            return iconName.indexOf("/") === 0 ? "file://" + iconName : iconName
        }
        if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
            let resolved = Quickshell.iconPath(iconName, true)
            if (resolved && resolved.length > 0) {
                return resolved.indexOf("/") === 0 ? "file://" + resolved : resolved
            }
        }
        return "image://icon/" + iconName
    }

    property real targetLength: {
        if (!root.moduleActive || !root.showLayout) return 0
        let len = root.isVertical ? content.implicitHeight : content.implicitWidth
        return len + root.px(root.isVertical ? 6 : 8)
    }

    readonly property bool isFaceVisible: root.showLayout && root.targetLength > 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)
    opacity: root.showLayout ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    AxisFlow {
        id: content
        anchors.centerIn: parent
        vertical: root.isVertical
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        spacing: root.px(3)

        Rectangle {
            id: minimizeBtn
            readonly property bool hovered: btnMouse.containsMouse
            width: root.px(root.isCompact ? 26 : 28)
            height: width
            radius: Math.max(0, ThemeBackend.borderRadius - root.px(2))
            color: root.isCompact
                ? Qt.lighter(ThemeBackend.surface0, hovered ? 1.18 : 1.12)
                : (hovered ? ThemeBackend.surface1 : ThemeBackend.surface0)
            opacity: root.canMinimize ? 1.0 : 0.45

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Item {
                width: root.px(16)
                height: root.px(15)
                anchors.centerIn: parent

                Rectangle {
                    width: root.px(12)
                    height: root.px(8)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: minimizeBtn.hovered ? root.px(5) : root.px(2)
                    color: "transparent"
                    border.width: Math.max(1, root.px(1))
                    border.color: minimizeBtn.hovered ? ThemeBackend.mauve : ThemeBackend.text
                    radius: root.px(1)

                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                Rectangle {
                    width: root.px(14)
                    height: Math.max(1, root.px(2))
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: minimizeBtn.hovered ? ThemeBackend.mauve : ThemeBackend.text
                    radius: height / 2

                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: btnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.canMinimize ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.minimizeActive()
            }
        }

        Repeater {
            id: chips
            model: root.minimizedWindows

            Rectangle {
                id: chip
                required property var modelData
                readonly property bool hovered: chipMouse.containsMouse
                readonly property int iconExtent: root.px(root.isCompact ? 15 : 16)
                readonly property string iconSource: root.windowIcon(modelData)
                readonly property string title: root.windowTitle(modelData)

                width: root.isVertical
                    ? root.px(root.isCompact ? 26 : 28)
                    : Math.min(root.px(180), chipRow.implicitWidth + root.px(root.isCompact ? 12 : 16))
                height: root.isVertical ? width : root.px(root.isCompact ? 26 : 28)
                radius: Math.max(0, ThemeBackend.borderRadius - root.px(2))
                color: hovered ? ThemeBackend.surface1 : ThemeBackend.surface0

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: root.px(6)
                    visible: !root.isVertical

                    Item {
                        width: chip.iconExtent
                        height: chip.iconExtent
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: chip.iconSource
                            sourceSize.width: width * Screen.devicePixelRatio
                            sourceSize.height: height * Screen.devicePixelRatio
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: status === Image.Ready && source.toString() !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready || appIcon.source.toString() === ""
                            text: root.windowInitial(chip.modelData)
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.px(11)
                        }
                    }

                    Text {
                        text: chip.title
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.px(root.isCompact ? 10 : 11)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: chip.iconExtent
                    height: chip.iconExtent
                    visible: root.isVertical

                    Image {
                        id: vertIcon
                        anchors.fill: parent
                        source: chip.iconSource
                        sourceSize.width: width * Screen.devicePixelRatio
                        sourceSize.height: height * Screen.devicePixelRatio
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready && source.toString() !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: vertIcon.status !== Image.Ready || vertIcon.source.toString() === ""
                        text: root.windowInitial(chip.modelData)
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.px(11)
                    }
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.restore(chip.modelData)
                }
            }
        }
    }
}
