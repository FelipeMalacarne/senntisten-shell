import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../services"
import "../components"
import "../lib/ApplicationSearch.js" as ApplicationSearch

FocusScope {
    id: root
    readonly property var entries: DesktopEntries.applications.values
    readonly property var results: ApplicationSearch.search(entries, searchField.text, 8)
    readonly property int resultCount: results.length
    property int currentIndex: resultCount > 0 ? 0 : -1
    signal dismissed

    onResultsChanged: currentIndex = results.length > 0 ? 0 : -1

    function resetSearch() {
        searchField.text = "";
        currentIndex = resultCount > 0 ? 0 : -1;
        searchField.forceActiveFocus();
    }

    function launchSelected() {
        if (currentIndex < 0 || currentIndex >= resultCount)
            return;
        // Native Quickshell 0.3: no shell, reparsing of Exec, or query execution.
        results[currentIndex].execute();
        dismissed();
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            dismissed();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
            if (resultCount > 0)
                currentIndex = (currentIndex + (event.key === Qt.Key_Down ? 1 : -1) + resultCount) % resultCount;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!event.isAutoRepeat)
                launchSelected();
            event.accepted = true;
        }
    }

    Keys.onPressed: event => handleKey(event)

    Rectangle {
        objectName: "launcherBackdrop"
        anchors.fill: parent
        color: Theme.colors.background
        opacity: 0.72
    }
    MouseArea {
        anchors.fill: parent
        onClicked: event => {
            if (event.x < panel.x || event.x >= panel.x + panel.width || event.y < panel.y || event.y >= panel.y + panel.height)
                root.dismissed();
        }
    }

    Surface {
        id: panel
        objectName: "launcherPanel"
        anchors.centerIn: parent
        width: Math.max(0, Math.min(560, parent.width - 32))
        height: Math.max(0, Math.min(parent.height - 32, body.implicitHeight + padding * 2))
        padding: Theme.metrics.panelPadding
        background: Rectangle {
            radius: Theme.metrics.panelRadius
            color: Theme.colors.surface
            border.color: Theme.colors.border
            Behavior on color {
                ColorAnimation {
                    duration: Theme.animationDuration
                }
            }
        }

        ColumnLayout {
            id: body
            anchors.fill: parent
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                DistroMark {
                    objectName: "launcherBrand"
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Accessible.ignored: true
                }
                ShellLabel {
                    Layout.fillWidth: true
                    text: "Applications"
                    color: Theme.colors.muted
                    font.family: Theme.typography.sans
                    font.pixelSize: 11
                    font.letterSpacing: 0.8
                }
                ShellButton {
                    id: closeButton
                    objectName: "launcherClose"
                    text: "Close"
                    Accessible.name: "Close application launcher"
                    compact: true
                    implicitWidth: 32
                    implicitHeight: 32
                    padding: 6
                    leftPadding: padding
                    rightPadding: padding
                    topPadding: padding
                    bottomPadding: padding
                    contentItem: ShellIcon {
                        objectName: "launcherCloseIcon"
                        name: "close"
                    }
                    background: Rectangle {
                        radius: Theme.metrics.controlRadius
                        color: closeButton.down || closeButton.hovered || closeButton.activeFocus ? Theme.colors.overlay : Qt.rgba(0, 0, 0, 0)
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Close launcher"
                    onClicked: root.dismissed()
                    KeyNavigation.tab: searchField
                    KeyNavigation.backtab: list.currentItem || searchField
                    Keys.onReturnPressed: root.dismissed()
                    Keys.onEnterPressed: root.dismissed()
                }
            }
            TextField {
                id: searchField
                objectName: "launcherSearch"
                Layout.fillWidth: true
                implicitHeight: Theme.metrics.resultHeight
                Layout.preferredHeight: implicitHeight
                placeholderText: "Find an application"
                Accessible.name: "Search applications"
                font.family: Theme.typography.sans
                font.pixelSize: 19
                leftPadding: 56
                rightPadding: 40
                color: Theme.colors.text
                placeholderTextColor: Theme.colors.muted
                selectionColor: Theme.colors.accent
                selectedTextColor: Theme.colors.accentText
                background: Rectangle {
                    radius: Theme.metrics.controlRadius
                    color: Theme.colors.background
                    border.color: searchField.activeFocus ? Theme.colors.accent : Theme.colors.border
                    border.width: searchField.activeFocus ? 2 : 1
                }
                Keys.onPressed: event => root.handleKey(event)
                KeyNavigation.tab: list.currentItem || closeButton
                KeyNavigation.backtab: closeButton
                ShellIcon {
                    objectName: "launcherSearchIcon"
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    name: "search"
                    color: searchField.activeFocus ? Theme.colors.accent : Theme.colors.muted
                    enabled: false
                }
                ShellIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow"
                    color: Theme.colors.accent
                    enabled: false
                }
            }
            RowLayout {
                Layout.fillWidth: true
                ShellLabel {
                    Layout.fillWidth: true
                    text: "Installed applications"
                    color: Theme.colors.subtle
                    font.family: Theme.typography.sans
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }
                ShellLabel {
                    objectName: "launcherCount"
                    text: root.resultCount + (root.resultCount === 1 ? " match" : " matches")
                    color: Theme.colors.subtle
                    font.family: Theme.typography.mono
                    font.pixelSize: 10
                    wrapMode: Text.NoWrap
                }
            }
            ListView {
                id: list
                objectName: "launcherResults"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                implicitHeight: root.resultCount * Theme.metrics.resultHeight + Math.max(0, root.resultCount - 1) * spacing
                visible: root.resultCount > 0
                clip: true
                spacing: 4
                model: root.results
                currentIndex: root.currentIndex
                highlightMoveDuration: Theme.animationDuration
                highlightResizeDuration: Theme.animationDuration
                highlightMoveVelocity: -1
                highlightResizeVelocity: -1
                ScrollBar.vertical: ScrollBar {
                    objectName: "launcherScrollbar"
                    policy: list.contentHeight > list.height + 0.5 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.colors.subtle
                    }
                    background: Rectangle {
                        color: Qt.rgba(0, 0, 0, 0)
                    }
                }
                delegate: ShellButton {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: Theme.metrics.resultHeight
                    padding: 12
                    leftPadding: padding
                    rightPadding: padding
                    topPadding: 10
                    bottomPadding: 10
                    text: modelData.name
                    selected: index === root.currentIndex
                    quiet: true
                    quietSelection: true
                    selectedBackground: Theme.colors.elevated
                    selectedForeground: Theme.colors.text
                    Accessible.name: modelData.name + (modelData.genericName ? ", " + modelData.genericName : "")
                    Accessible.selected: selected
                    background: Rectangle {
                        radius: Theme.metrics.controlRadius
                        color: row.down || row.activeFocus ? Theme.colors.overlay : row.selected || row.hovered ? Theme.colors.elevated : Qt.rgba(0, 0, 0, 0)
                        border.color: row.visualFocus ? Theme.colors.accent : row.selected ? Theme.colors.border : Qt.rgba(0, 0, 0, 0)
                        border.width: row.visualFocus ? 2 : 1
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animationDuration
                            }
                        }
                    }
                    KeyNavigation.tab: closeButton
                    KeyNavigation.backtab: searchField
                    Keys.onPressed: event => root.handleKey(event)
                    onClicked: {
                        root.currentIndex = index;
                        root.launchSelected();
                    }
                    contentItem: RowLayout {
                        spacing: 12
                        Image {
                            objectName: "launcherResultIcon"
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            sourceSize: Qt.size(32, 32)
                            source: Quickshell.iconPath(row.modelData.icon, true)
                            fillMode: Image.PreserveAspectFit
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            ShellLabel {
                                objectName: "launcherResultName"
                                Layout.fillWidth: true
                                text: row.modelData.name
                                font.family: Theme.typography.sans
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                            ShellLabel {
                                objectName: "launcherResultGeneric"
                                Layout.fillWidth: true
                                text: row.modelData.genericName
                                visible: text !== ""
                                font.family: Theme.typography.sans
                                font.pixelSize: 11
                                color: Theme.colors.muted
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }
                        ShellIcon {
                            objectName: "launcherResultAction"
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            name: "arrow"
                            color: Theme.colors.accent
                            opacity: row.selected ? 1 : 0
                        }
                    }
                    Rectangle {
                        objectName: "launcherSelectionMarker"
                        anchors.left: parent.left
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 20
                        radius: 2
                        color: Theme.colors.accent
                        visible: row.selected
                    }
                }
            }
            ShellLabel {
                objectName: "launcherEmpty"
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                visible: root.resultCount === 0
                text: root.entries.length === 0 ? "No applications found" : "No matching applications"
                color: Theme.colors.muted
                font.family: Theme.typography.sans
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.colors.border
                opacity: 0.6
            }
            ShellLabel {
                objectName: "launcherHint"
                Layout.fillWidth: true
                text: "Up / Down navigate   Enter open   Tab focus   Esc close\nUp to 8 matches | Search to narrow results"
                font.family: Theme.typography.sans
                font.pixelSize: 10
                color: Theme.colors.muted
            }
        }
    }
}
