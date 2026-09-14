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
    signal dismissed()

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
        padding: 18

        ColumnLayout {
            id: body
            anchors.fill: parent
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                ShellLabel {
                    Layout.fillWidth: true
                    text: "Applications"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                ShellButton {
                    id: closeButton
                    objectName: "launcherClose"
                    text: "Esc"
                    Accessible.name: "Close application launcher"
                    compact: true
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
                implicitHeight: 44
                placeholderText: "Search applications…"
                Accessible.name: "Search applications"
                font.family: "Noto Sans"
                font.pixelSize: 14
                leftPadding: 12
                rightPadding: 12
                color: Theme.colors.text
                placeholderTextColor: Theme.colors.muted
                selectionColor: Theme.colors.accent
                selectedTextColor: Theme.colors.accentText
                background: Rectangle {
                    radius: 8
                    color: Theme.colors.background
                    border.color: searchField.activeFocus ? Theme.colors.accent : Theme.colors.border
                    border.width: searchField.activeFocus ? 2 : 1
                }
                Keys.onPressed: event => root.handleKey(event)
                KeyNavigation.tab: list.currentItem || closeButton
                KeyNavigation.backtab: closeButton
            }
            ListView {
                id: list
                objectName: "launcherResults"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                implicitHeight: root.resultCount * 58
                visible: root.resultCount > 0
                clip: true
                spacing: 6
                model: root.results
                currentIndex: root.currentIndex
                highlightMoveDuration: Theme.animationDuration
                highlightResizeDuration: Theme.animationDuration
                highlightMoveVelocity: -1
                highlightResizeVelocity: -1
                ScrollBar.vertical: ScrollBar {
                    objectName: "launcherScrollbar"
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.colors.subtle
                    }
                    background: Rectangle {
                        color: "transparent"
                    }
                }
                delegate: ShellButton {
                    id: row
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 52
                    text: modelData.name
                    selected: index === root.currentIndex
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
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                            ShellLabel {
                                objectName: "launcherResultGeneric"
                                Layout.fillWidth: true
                                text: row.modelData.genericName
                                visible: text !== ""
                                font.pixelSize: 11
                                color: Theme.colors.muted
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }
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
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            ShellLabel {
                objectName: "launcherHint"
                Layout.fillWidth: true
                text: "↑↓ Select · Enter Open · Tab Focus · Esc Close\nUp to 8 matches · Search to narrow results"
                color: Theme.colors.muted
                font.pixelSize: 11
            }
        }
    }
}
