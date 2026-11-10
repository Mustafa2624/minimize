import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../"
import "ScreenLayout.js" as ScreenLayout

Item {
    id: root

    property bool open: false
    property var targetScreen: null
    property var toplevels: []
    property url wallpaperSource: ""
    property var iconSourceFor: function(toplevel) { return "" }
    property var titleFor: function(toplevel) { return "Window" }
    property var initialFor: function(toplevel) { return "W" }
    property var px: function(value) { return value }

    signal closeRequested()
    signal restoreRequested(var toplevel)

    readonly property real labelHeight: px(30)

    LazyLoader {
        active: root.open && root.targetScreen !== null

        PanelWindow {
            id: overview
            screen: root.targetScreen
            visible: true
            focusable: true
            color: "transparent"
            WlrLayershell.namespace: "serpantinum-minimize-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            property int current: -1
            property var gridLayout: ScreenLayout.fit(
                root.toplevels,
                width - root.px(68),
                height - root.px(120),
                root.px(18),
                root.labelHeight
            )

            function close() {
                root.closeRequested()
            }

            function restore(toplevel) {
                close()
                root.restoreRequested(toplevel)
            }

            function move(delta) {
                const count = root.toplevels.length
                if (count < 1) return
                if (current < 0) current = delta > 0 ? 0 : count - 1
                else current = Math.max(0, Math.min(count - 1, current + delta))
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.WindowShortcut
                onActivated: overview.close()
            }

            Image {
                anchors.fill: parent
                source: root.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Rectangle {
                id: scrim
                anchors.fill: parent
                color: "#a6000000"
                focus: true
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                Keys.onPressed: (event) => {
                    const cols = overview.gridLayout.columns
                    if (event.key === Qt.Key_Escape) overview.close()
                    else if (event.key === Qt.Key_Left) overview.move(-1)
                    else if (event.key === Qt.Key_Right) overview.move(1)
                    else if (event.key === Qt.Key_Up) overview.move(-cols)
                    else if (event.key === Qt.Key_Down) overview.move(cols)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (overview.current >= 0) overview.restore(root.toplevels[overview.current])
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const toplevel = root.toplevels[event.key - Qt.Key_1]
                        if (toplevel) overview.restore(toplevel)
                    } else return
                    event.accepted = true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: overview.close()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.px(34)
                    spacing: root.px(12)

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "MINIMIZED WINDOWS"
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.px(16)
                            font.weight: Font.Black
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.toplevels.length + (root.toplevels.length === 1 ? " window" : " windows")
                            color: ThemeBackend.subtext0
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.px(11)
                        }

                        Text {
                            text: "×"
                            color: closeMouse.containsMouse ? ThemeBackend.mauve : ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.px(26)
                            horizontalAlignment: Text.AlignHCenter
                            Layout.preferredWidth: root.px(36)
                            Layout.leftMargin: root.px(12)

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overview.close()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        GridLayout {
                            anchors.centerIn: parent
                            columns: overview.gridLayout.columns
                            rowSpacing: root.px(18)
                            columnSpacing: root.px(18)

                            Repeater {
                                model: root.toplevels

                                delegate: Item {
                                    id: card
                                    required property var modelData
                                    required property int index

                                    readonly property var toplevel: modelData
                                    readonly property real aspect: ScreenLayout.aspectOf(toplevel)
                                    readonly property bool highlighted: overview.current === index
                                    readonly property real thumbWidth: Math.max(1, Math.min(width, Math.max(1, height - root.labelHeight) * aspect))
                                    readonly property real thumbHeight: thumbWidth / aspect

                                    Layout.preferredWidth: overview.gridLayout.cardWidth
                                    Layout.preferredHeight: overview.gridLayout.cardHeight

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: root.px(8)

                                        Item {
                                            width: card.thumbWidth
                                            height: card.thumbHeight
                                            scale: card.highlighted ? 1.03 : 1
                                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: root.px(6)
                                                color: ThemeBackend.surface0
                                            }

                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: card.toplevel.wayland
                                                live: card.highlighted
                                                visible: hasContent
                                                Component.onCompleted: captureFrame()
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: root.px(6)
                                                color: "black"
                                                opacity: overview.current >= 0 && !card.highlighted ? 0.35 : 0
                                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: root.px(6)
                                                color: "transparent"
                                                border.width: root.px(2)
                                                border.color: card.highlighted ? ThemeBackend.mauve : "transparent"
                                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                            }
                                        }

                                        RowLayout {
                                            width: card.thumbWidth
                                            spacing: root.px(8)

                                            Rectangle {
                                                Layout.preferredWidth: root.px(20)
                                                Layout.preferredHeight: root.px(20)
                                                radius: root.px(6)
                                                color: card.highlighted ? ThemeBackend.mauve : ThemeBackend.surface0

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: root.px(14)
                                                    height: width
                                                    source: root.iconSourceFor(card.toplevel)
                                                    visible: status === Image.Ready
                                                }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: parent.children[0].status !== Image.Ready
                                                    text: root.initialFor(card.toplevel)
                                                    color: card.highlighted ? ThemeBackend.base : ThemeBackend.mauve
                                                    font.family: ThemeBackend.fontFamily
                                                    font.pixelSize: root.px(11)
                                                    font.bold: true
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.titleFor(card.toplevel)
                                                elide: Text.ElideRight
                                                color: card.highlighted ? ThemeBackend.text : ThemeBackend.subtext0
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: root.px(12)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: overview.current = card.index
                                        onExited: if (overview.current === card.index) overview.current = -1
                                        onClicked: overview.restore(card.toplevel)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.toplevels.length === 0
                        Layout.alignment: Qt.AlignHCenter
                        text: "No minimized windows"
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.px(12)
                    }
                }
            }
        }
    }
}
