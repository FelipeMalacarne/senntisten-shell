import QtQuick
import QtQuick.Layouts
import "../services"

Surface {
    padding: 14
    ColumnLayout {
        width: parent.width
        spacing: 4
        ShellLabel {
            Layout.fillWidth: true
            text: Theme.message || (Theme.saveStatus === "saved" ? "Appearance saved locally" : Theme.saveStatus === "saving" ? "Saving appearance…" : "Local preview · No system changes")
            color: Theme.message ? Theme.colors.warning : Theme.colors.muted
            font.pixelSize: 12
        }
        ShellLabel {
            Layout.fillWidth: true
            text: Theme.statePath
            color: Theme.colors.muted
            font.pixelSize: 11
            elide: Text.ElideMiddle
            wrapMode: Text.NoWrap
        }
    }
}
