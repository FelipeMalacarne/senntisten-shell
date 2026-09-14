import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "desktop"
import "services"

Scope {
    id: desktop
    readonly property bool previewMode: Quickshell.env("SENNTISTEN_PREVIEW") === "1"
    property var targetScreen: Quickshell.screens.length ? Quickshell.screens[0] : null

    function preferredScreen() {
        const monitor = Hyprland.focusedMonitor;
        const match = monitor ? Quickshell.screens.find(screen => screen.name === monitor.name) : null;
        return match || (Quickshell.screens.length ? Quickshell.screens[0] : null);
    }

    function toggleLauncher(screen) {
        const target = screen || preferredScreen();
        if (!target) return;
        const close = launcher.opened && targetScreen === target;
        targetScreen = target;
        if (!close) launcher.resetSearch();
        launcher.opened = !close;
    }

    function toggleSettings(screen) {
        const target = screen || preferredScreen();
        if (!target) return;
        const close = appearance.visible && targetScreen === target;
        targetScreen = target;
        appearance.visible = !close;
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Quickshell.screens.indexOf(desktop.targetScreen) === -1) {
                launcher.opened = false;
                desktop.targetScreen = desktop.preferredScreen();
            }
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
            previewMode: desktop.previewMode
            onLauncherRequested: desktop.toggleLauncher(modelData)
            onAppearanceRequested: desktop.toggleSettings(modelData)
        }
    }

    Launcher {
        id: launcher
        screen: desktop.targetScreen
        opened: false
        onDismissed: launcher.opened = false
    }

    App {
        id: appearance
        standalone: false
        title: "Senntisten · Appearance"
        visible: false
        screen: desktop.targetScreen
    }

    IpcHandler {
        target: "senntisten"
        function launcher(): void { desktop.toggleLauncher(null); }
        function settings(): void { desktop.toggleSettings(null); }
        function theme(id: string): bool { return Theme.selectTheme(id); }
        function quit(): void { Qt.quit(); }
        function status(): string {
            return JSON.stringify({
                mode: "desktop", ready: Theme.ready, preview: desktop.previewMode,
                theme: Theme.settings.theme, saveStatus: Theme.saveStatus,
                message: Theme.message, writable: Theme.writable,
                screenCount: Quickshell.screens.length,
                targetScreen: desktop.targetScreen ? desktop.targetScreen.name : "",
                launcherOpen: launcher.opened, appearanceOpen: appearance.visible
            });
        }
    }
}
