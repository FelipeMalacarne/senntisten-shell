pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../components"
import "../services"

ColumnLayout {
    id: root
    required property var service
    spacing: 6
    ShellLabel {
        text: "Media"
        font.weight: Font.DemiBold
        Layout.fillWidth: true
    }
    Repeater {
        model: root.service.players.length > 1 ? root.service.players : []
        ShellButton {
            required property var modelData
            required property int index
            objectName: "mediaPlayer-" + index
            text: modelData.identity || modelData.dbusName
            selected: root.service.player === modelData
            compact: true
            quiet: true
            quietSelection: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Accessible.name: "Use media player " + text
            Accessible.role: Accessible.RadioButton
            Accessible.checkable: true
            Accessible.checked: selected
            onClicked: root.service.selectPlayer(modelData)
        }
    }
    RowLayout {
        visible: root.service.available
        Layout.fillWidth: true
        spacing: 8
        Image {
            id: art
            objectName: "mediaArtwork"
            source: root.service.artwork
            visible: source.toString().length > 0 && status === Image.Ready
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            sourceSize.width: 80
            sourceSize.height: 80
            fillMode: Image.PreserveAspectCrop
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3
            ShellLabel {
                objectName: "mediaTitle"
                text: root.service.title || "No track metadata"
                font.pixelSize: 12
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            ShellLabel {
                objectName: "mediaArtist"
                text: [root.service.artist, root.service.album].filter(value => value.length > 0).join(" / ")
                visible: text.length > 0
                color: Theme.colors.muted
                font.pixelSize: 10
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            ShellLabel {
                objectName: "mediaPlayerName"
                text: root.service.playerName + (root.service.playing ? " / Playing" : " / Not playing")
                color: Theme.colors.subtle
                font.pixelSize: 10
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }
    ShellLabel {
        objectName: "mediaStatus"
        text: root.service.status || (art.status === Image.Error ? "Artwork unavailable" : "")
        visible: text.length > 0
        color: Theme.colors.warning
        font.pixelSize: 11
        Layout.fillWidth: true
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        ShellButton {
            objectName: "mediaPrevious"
            text: "Prev"
            Accessible.name: "Previous track"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            enabled: root.service.canPrevious
            onClicked: root.service.previous()
        }
        ShellButton {
            objectName: "mediaToggle"
            text: root.service.playing ? "Pause" : "Play"
            Accessible.name: root.service.playing ? "Pause playback" : "Play media"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            enabled: root.service.canTogglePlaying
            onClicked: root.service.togglePlaying()
        }
        ShellButton {
            objectName: "mediaNext"
            text: "Next"
            Accessible.name: "Next track"
            compact: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            enabled: root.service.canNext
            onClicked: root.service.next()
        }
    }
}
