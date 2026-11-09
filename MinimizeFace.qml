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

    property string orientation: activeTarget && activeTarget.orientation !== undefined
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

    property bool showLayout: false
    Timer {
        running: root.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    readonly property var minimizedWindows: {
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
    readonly property bool canMinimize: activeWindow !== null && activeWindow.workspace && activeWindow.workspace.name !== shelfWorkspace

    function minimizeActive() {
        if (!activeWindow) return
        let addr = activeWindow.address ? String(activeWindow.address) : ""
        if (!addr) return
        if (addr.indexOf("0x") !== 0) addr = "0x" + addr
        Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace " + shelfWorkspace + ",address:" + addr])
    }

    function restore(t) {
        if (!t || !t.address) return
        let addr = String(t.address)
        if (addr.indexOf("0x") !== 0) addr = "0x" + addr
        let ws = (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace.name : "1"
        Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace " + ws + ",address:" + addr])
    }

    function windowTitle(t) {
        let title = String(t && t.title ? t.title : "Window").trim()
        if (title.length > 18) title = title.substring(0, 15) + "..."
        return title
    }

    function windowIcon(t) {
        if (!t) return ""
        let ipc = t.lastIpcObject || null
        let cls = ipc && ipc.class ? ipc.class : ""
        if (!cls) return ""
        if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
            let resolved = Quickshell.iconPath(cls, true)
            if (resolved && resolved.length > 0) return resolved.startsWith("/") ? "file://" + resolved : resolved
        }
        return "image://icon/" + cls
    }

    property real targetLength: {
        if (!root.moduleActive || !root.showLayout) return 0
        let len = root.isVertical ? content.implicitHeight : content.implicitWidth
        return len + root.px(root.isVertical ? 8 : 10)
    }

    readonly property bool isFaceVisible: root.showLayout && root.targetLength > 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)
    opacity: root.showLayout ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: 450
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
            id: minimizeButton
            readonly property bool hovered: minimizeMouse.containsMouse
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
                    x: Math.round((parent.width - width) / 2)
                    y: minimizeButton.hovered ? root.px(6) : root.px(2)
                    color: "transparent"
                    border.width: Math.max(1, root.px(1))
                    border.color: minimizeButton.hovered ? ThemeBackend.mauve : ThemeBackend.text
                    radius: root.px(1)
                }

                Rectangle {
                    width: root.px(16)
                    height: Math.max(1, root.px(2))
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    color: minimizeButton.hovered ? ThemeBackend.mauve : ThemeBackend.text
                    radius: height / 2
                }
            }

            MouseArea {
                id: minimizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.canMinimize ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.minimizeActive()
            }
        }

        Repeater {
            model: root.minimizedWindows

            Rectangle {
                id: chip
                required property var modelData
                readonly property bool hovered: chipMouse.containsMouse
                readonly property int iconExtent: root.px(root.isCompact ? 15 : 16)
                readonly property string iconSource: root.windowIcon(modelData)
                readonly property string title: root.windowTitle(modelData)

                width: root.isVertical ? root.px(root.isCompact ? 26 : 28)
                    : Math.min(root.px(180), chipRow.implicitWidth + root.px(root.isCompact ? 14 : 16))
                height: root.isVertical ? width : root.px(root.isCompact ? 26 : 28)
                radius: Math.max(0, ThemeBackend.borderRadius - root.px(2))
                color: hovered ? ThemeBackend.surface1 : ThemeBackend.surface0

                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: root.px(6)
                    visible: !root.isVertical

                    Image {
                        id: appIcon
                        width: chip.iconExtent
                        height: chip.iconExtent
                        anchors.verticalCenter: parent.verticalCenter
                        source: chip.iconSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status !== Image.Error && source.toString() !== ""
                    }

                    Text {
                        text: chip.title
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.px(root.isCompact ? 10 : 11)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: chip.iconExtent
                    height: chip.iconExtent
                    source: chip.iconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: root.isVertical && status !== Image.Error && source.toString() !== ""
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
