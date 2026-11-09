import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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
    readonly property string peekWorkspace: "special:omarchy-window-peek"

    property var minimizedOrigins: ({})

    readonly property int peekWidth: Math.max(px(320), 960)
    readonly property int peekHeight: Math.max(px(240), 640)
    readonly property int previewFixedX: 1187
    readonly property int previewFixedY: 144

    property var peekToplevel: null
    property var pendingPeekToplevel: null
    property string peekOriginWorkspace: ""
    property bool peekVisible: false
    property bool peekWasFloating: false
    property int peekOriginalFullscreen: 0
    property var peekOriginalSize: null
    property var peekOriginalPosition: null
    property int peekTargetWidth: 0
    property int peekTargetHeight: 0
    property bool previewClosePending: false
    property var pendingCloseToplevel: null
    readonly property bool peekTransitionRunning: peekProcess.running || peekVisibilityProcess.running

    property bool showLayout: true
    Timer {
        id: startupFallbackTimer
        interval: 100
        running: !root.showLayout
        onTriggered: root.showLayout = true
    }
    Component.onCompleted: {
        root.showLayout = true
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
        function onFocusedWorkspaceChanged() {
            root.modelRevision++
            root.handleFocusedWorkspaceChanged()
        }
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
            if (root.isMinimized(t)) {
                out.push(t)
            }
        }
        return out
    }

    readonly property var activeWindow: (typeof Hyprland !== "undefined") ? Hyprland.activeToplevel : null
    readonly property bool canMinimize: activeWindow !== null
        && activeWindow.workspace !== null
        && !isManaged(activeWindow)

    function normalizedAddress(addr) {
        if (!addr) return ""
        let s = String(addr).trim()
        return s.indexOf("0x") === 0 ? s : "0x" + s
    }

    function isMinimized(t) {
        return t !== null && t !== undefined && t.workspace !== null && t.workspace !== undefined
            && t.workspace.name === shelfWorkspace
    }

    function isPeeked(t) {
        return t !== null && t !== undefined && t.workspace !== null && t.workspace !== undefined
            && t.workspace.name === peekWorkspace
    }

    function isManaged(t) {
        return isMinimized(t) || isPeeked(t)
    }

    function moveRequest(t, workspace, follow) {
        let address = normalizedAddress(t ? t.address : "")
        if (!address || !workspace) return ""
        if (typeof Hyprland !== "undefined" && Hyprland.usingLua === false) {
            return (follow ? "movetoworkspace " : "movetoworkspacesilent ") + JSON.stringify(workspace + ",address:" + address)
        }
        return "hl.dsp.window.move({ workspace = " + JSON.stringify(workspace)
            + ", window = " + JSON.stringify("address:" + address)
            + ", follow = " + (follow ? "true" : "false") + " })"
    }

    function floatRequest(t, action) {
        let address = normalizedAddress(t ? t.address : "")
        if (!address) return ""
        if (typeof Hyprland !== "undefined" && Hyprland.usingLua === false)
            return (action === "on" ? "setfloating " : "settiled ") + JSON.stringify("address:" + address)
        return "hl.dsp.window.float({ action = " + JSON.stringify(action)
            + ", window = " + JSON.stringify("address:" + address) + " })"
    }

    function resizeRequest(t, w, h) {
        let address = normalizedAddress(t ? t.address : "")
        if (!address) return ""
        if (typeof Hyprland !== "undefined" && Hyprland.usingLua === false)
            return "resizewindowpixel " + JSON.stringify("exact " + Math.round(w) + " " + Math.round(h) + ",address:" + address)
        return "hl.dsp.window.resize({ x = " + Math.round(w) + ", y = " + Math.round(h)
            + ", window = " + JSON.stringify("address:" + address) + " })"
    }

    function positionRequest(t, x, y) {
        let address = normalizedAddress(t ? t.address : "")
        if (!address) return ""
        let targetX = Math.round(x)
        let targetY = Math.round(y)
        if (typeof Hyprland !== "undefined" && Hyprland.usingLua === false) {
            return "movewindowpixel " + JSON.stringify("exact " + targetX + " " + targetY + ",address:" + address)
        }
        return "hl.dsp.window.move({ x = " + targetX + ", y = " + targetY
            + ", relative = false, window = " + JSON.stringify("address:" + address) + " })"
    }

    function fullscreenRequest(t, mode) {
        let address = normalizedAddress(t ? t.address : "")
        if (!address || mode <= 0) return ""
        if (typeof Hyprland !== "undefined" && Hyprland.usingLua === false)
            return "fullscreenstate " + JSON.stringify(mode + ",address:" + address)
        let kind = mode === 1 ? "maximized" : "fullscreen"
        return "hl.dsp.window.fullscreen({ mode = " + JSON.stringify(kind)
            + ", window = " + JSON.stringify("address:" + address) + " })"
    }

    function moveWindow(t, workspace, follow) {
        let req = moveRequest(t, workspace, follow)
        if (!req) return
        Quickshell.execDetached(["hyprctl", "dispatch", req])
        refreshTimer.restart()
    }

    function minimizeActive() {
        if (!canMinimize) return
        let t = activeWindow
        let addr = normalizedAddress(t.address)
        let workspace = t.workspace ? String(t.workspace.name) : ""
        if (addr && workspace && workspace.indexOf("special:") !== 0) {
            minimizedOrigins[addr] = workspace
            minimizedOrigins = Object.assign({}, minimizedOrigins)
        }
        moveWindow(t, shelfWorkspace, false)
    }

    function restore(t) {
        let workspace = (typeof Hyprland !== "undefined") ? Hyprland.focusedWorkspace : null
        const addr = normalizedAddress(t ? t.address : "")
        let destination = minimizedOrigins[addr] || (workspace && String(workspace.name).indexOf("special:") !== 0
            ? workspace.name : peekOriginWorkspace) || "1"
        if (isMinimized(t)) {
            delete minimizedOrigins[addr]
            minimizedOrigins = Object.assign({}, minimizedOrigins)
        }
        if (peekToplevel === t || isPeeked(t)) {
            if (peekTransitionRunning) return
            peekVisible = false
            runPeekCommand(["hyprctl", "dispatch", moveRequest(t, destination, true)], "restore-move")
        } else {
            moveWindow(t, destination, true)
        }
    }

    function runPeekCommand(command, action) {
        if (peekTransitionRunning || !command || command.length === 0) return false
        peekProcess.action = action
        peekProcess.command = command
        peekProcess.running = true
        refreshTimer.restart()
        return true
    }

    function togglePeek(t) {
        if (!t || peekTransitionRunning) return
        if (peekToplevel === t || isPeeked(t)) {
            closePeek(t)
            return
        }
        if (peekToplevel) {
            pendingPeekToplevel = t
            closePeek(peekToplevel)
            return
        }
        let workspace = (typeof Hyprland !== "undefined") ? Hyprland.focusedWorkspace : null
        if (!workspace || String(workspace.name).indexOf("special:") === 0) return
        peekToplevel = t
        peekOriginWorkspace = workspace.name
        peekVisible = false
        let ipc = t.lastIpcObject || null
        peekWasFloating = !!(ipc && ipc.floating)
        peekOriginalFullscreen = Number(ipc && ipc.fullscreen ? ipc.fullscreen : 0)
        peekOriginalSize = ipc && Array.isArray(ipc.size) ? ipc.size.slice(0, 2) : null
        peekOriginalPosition = ipc && Array.isArray(ipc.at) ? ipc.at.slice(0, 2) : null
        peekTargetWidth = peekWidth
        peekTargetHeight = peekHeight
        runPeekCommand(["hyprctl", "dispatch", moveRequest(t, peekWorkspace, false)], "show-move")
    }

    function closePeek(t) {
        let target = t || peekToplevel
        if (!target) return
        if (peekTransitionRunning) {
            pendingCloseToplevel = target
            return
        }
        pendingCloseToplevel = null
        peekVisible = false
        runPeekCommand(["hyprctl", "dispatch", moveRequest(target, shelfWorkspace, false)], "hide-move")
    }

    function clearPeekState() {
        peekToplevel = null
        peekOriginWorkspace = ""
        peekVisible = false
        peekWasFloating = false
        peekOriginalFullscreen = 0
        peekOriginalSize = null
        peekOriginalPosition = null
        peekTargetWidth = 0
        peekTargetHeight = 0
        pendingCloseToplevel = null
    }

    function runPeekToggle(action) {
        let request = (typeof Hyprland !== "undefined" && Hyprland.usingLua === false)
            ? "togglespecialworkspace omarchy-window-peek"
            : "hl.dsp.workspace.toggle_special(\"omarchy-window-peek\")"
        runPeekCommand(["hyprctl", "dispatch", request], action)
    }

    function runPeekVisibilityCheck(kind) {
        if (peekTransitionRunning) return false
        peekVisibilityProcess.kind = kind
        peekVisibilityProcess.running = true
        return true
    }

    function peekWorkspaceIsVisible(raw) {
        try {
            let monitors = JSON.parse(String(raw || ""))
            for (let i = 0; i < monitors.length; i++) {
                let special = monitors[i] ? monitors[i].specialWorkspace : null
                if (special && special.name === peekWorkspace) return true
            }
        } catch (e) {
            console.warn("minimize: could not inspect peek workspace visibility", e)
        }
        return false
    }

    function finishPeekVisibilityCheck(kind, exitCode, output) {
        if (exitCode === 0 && peekWorkspaceIsVisible(output)) {
            Qt.callLater(function() { root.runPeekToggle(kind + "-toggle") })
        } else {
            finalizePeek()
        }
    }

    function finalizePeek() {
        clearPeekState()
        if (pendingPeekToplevel) {
            let next = pendingPeekToplevel
            pendingPeekToplevel = null
            Qt.callLater(function() { root.togglePeek(next) })
        }
    }

    function completePeekExit(kind) {
        if (peekOriginalFullscreen > 0) {
            runPeekCommand(["hyprctl", "dispatch", fullscreenRequest(peekToplevel, peekOriginalFullscreen)], kind + "-fullscreen")
        } else {
            runPeekVisibilityCheck(kind)
        }
    }

    function finishPeekExit(kind) {
        if (!peekToplevel) {
            clearPeekState()
            return
        }
        if (!peekWasFloating) {
            runPeekCommand(["hyprctl", "dispatch", floatRequest(peekToplevel, "off")], kind + "-float")
        } else if (peekOriginalSize && peekOriginalSize.length === 2) {
            runPeekCommand(["hyprctl", "dispatch", resizeRequest(peekToplevel, peekOriginalSize[0], peekOriginalSize[1])], kind + "-resize")
        } else {
            completePeekExit(kind)
        }
    }

    function finishPeekResize(kind) {
        if (peekOriginalPosition && peekOriginalPosition.length === 2) {
            let request = positionRequest(peekToplevel, peekOriginalPosition[0], peekOriginalPosition[1])
            if (request) {
                runPeekCommand(["hyprctl", "dispatch", request], kind + "-position")
            } else {
                completePeekExit(kind)
            }
        } else {
            completePeekExit(kind)
        }
    }

    function finishPeekCommand(action, exitCode) {
        if (exitCode !== 0) {
            let failedTarget = peekToplevel
            clearPeekState()
            if (failedTarget && action.indexOf("show-") === 0) moveWindow(failedTarget, shelfWorkspace, false)
            return
        }
        if (action === "show-move") {
            Qt.callLater(function() {
                if (root.peekOriginalFullscreen > 0) {
                    root.runPeekCommand(["hyprctl", "dispatch", root.fullscreenRequest(root.peekToplevel, root.peekOriginalFullscreen)], "show-fullscreen")
                } else {
                    root.runPeekCommand(["hyprctl", "dispatch", root.floatRequest(root.peekToplevel, "on")], "show-float")
                }
            })
        } else if (action === "show-fullscreen") {
            Qt.callLater(function() {
                root.runPeekCommand(["hyprctl", "dispatch", root.floatRequest(root.peekToplevel, "on")], "show-float")
            })
        } else if (action === "show-float") {
            Qt.callLater(function() {
                root.runPeekCommand(["hyprctl", "dispatch", root.resizeRequest(root.peekToplevel, root.peekTargetWidth, root.peekTargetHeight)], "show-resize")
            })
        } else if (action === "show-resize") {
            Qt.callLater(function() {
                root.runPeekCommand(["hyprctl", "dispatch", root.positionRequest(root.peekToplevel, root.previewFixedX, root.previewFixedY)], "show-position")
            })
        } else if (action === "show-position") {
            Qt.callLater(function() { root.runPeekToggle("show-toggle") })
        } else if (action === "show-toggle") {
            peekVisible = true
            if (pendingCloseToplevel) {
                let target = pendingCloseToplevel
                pendingCloseToplevel = null
                Qt.callLater(function() { root.closePeek(target) })
            }
        } else if (action === "hide-move" || action === "restore-move") {
            let exitKind = action === "hide-move" ? "hide" : "restore"
            Qt.callLater(function() { root.runPeekToggle(exitKind + "-toggle") })
        } else if (action === "hide-resize" || action === "restore-resize") {
            let resizeKind = action === "hide-resize" ? "hide" : "restore"
            Qt.callLater(function() { root.finishPeekResize(resizeKind) })
        } else if (action === "hide-position" || action === "restore-position"
                || action === "hide-float" || action === "restore-float") {
            let stateKind = action.indexOf("hide-") === 0 ? "hide" : "restore"
            Qt.callLater(function() { root.completePeekExit(stateKind) })
        } else if (action === "hide-fullscreen" || action === "restore-fullscreen") {
            let fullscreenKind = action.indexOf("hide-") === 0 ? "hide" : "restore"
            Qt.callLater(function() { root.runPeekVisibilityCheck(fullscreenKind) })
        } else if (action === "hide-toggle" || action === "restore-toggle") {
            finalizePeek()
        }
    }

    function handleFocusedWorkspaceChanged() {
        if (!peekToplevel || !peekVisible || peekTransitionRunning) return
        let workspace = (typeof Hyprland !== "undefined") ? Hyprland.focusedWorkspace : null
        if (workspace && workspace.name !== peekWorkspace) closePeek(peekToplevel)
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
                readonly property bool peeked: root.isPeeked(modelData)
                readonly property int iconExtent: root.px(root.isCompact ? 15 : 16)
                readonly property string iconSource: root.windowIcon(modelData)
                readonly property string title: root.windowTitle(modelData)

                width: root.isVertical
                    ? root.px(root.isCompact ? 26 : 28)
                    : Math.min(root.px(180), chipRow.implicitWidth + root.px(root.isCompact ? 12 : 16))
                height: root.isVertical ? width : root.px(root.isCompact ? 26 : 28)
                radius: Math.max(0, ThemeBackend.borderRadius - root.px(2))
                color: peeked
                    ? Qt.alpha(ThemeBackend.mauve, root.isCompact ? 0.28 : 0.22)
                    : (hovered ? ThemeBackend.surface1 : ThemeBackend.surface0)

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
                            visible: status !== Image.Error && source.toString() !== ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status === Image.Error || appIcon.source.toString() === ""
                            text: root.windowInitial(chip.modelData)
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.px(11)
                        }
                    }

                    Text {
                        text: chip.title
                        color: chip.peeked ? ThemeBackend.mauve : ThemeBackend.text
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
                        visible: status !== Image.Error && source.toString() !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: vertIcon.status === Image.Error || vertIcon.source.toString() === ""
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.togglePeek(chip.modelData)
                        } else {
                            root.restore(chip.modelData)
                        }
                    }
                }
            }
        }
    }

    Process {
        id: peekProcess
        property string action: ""
        onExited: function(exitCode) {
            let completedAction = action
            action = ""
            root.finishPeekCommand(completedAction, exitCode)
        }
    }

    Process {
        id: peekVisibilityProcess
        property string kind: ""
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            id: peekVisibilityOutput
            waitForEnd: true
        }
        onExited: function(exitCode) {
            let completedKind = kind
            kind = ""
            root.finishPeekVisibilityCheck(completedKind, exitCode, peekVisibilityOutput.text)
        }
    }
}
