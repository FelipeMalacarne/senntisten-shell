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
    property var launcherScreen: targetScreen
    property var settingsScreen: targetScreen
    property var settingsReturnBar: null

    function barForScreen(screen) {
        for (const bar of bars.instances) {
            if (bar.screen === screen)
                return bar;
        }
        return null;
    }

    function closeDashboards() {
        for (const bar of bars.instances)
            bar.closeDashboard();
    }

    function toggleDashboard(screen) {
        const target = screen || preferredScreen();
        const bar = barForScreen(target);
        if (!bar)
            return false;
        const close = bar.dashboardOpen;
        settingsReturnBar = null;
        closeDashboards();
        launcher.opened = false;
        targetScreen = target;
        if (!close)
            bar.openDashboard(false);
        return true;
    }

    function preferredScreen() {
        const monitor = Hyprland.focusedMonitor;
        const match = monitor ? Quickshell.screens.find(screen => screen.name === monitor.name) : null;
        return match || (Quickshell.screens.length ? Quickshell.screens[0] : null);
    }

    function toggleLauncher(screen) {
        const target = screen || preferredScreen();
        if (!target)
            return false;
        const close = launcher.opened && launcherScreen === target;
        settingsReturnBar = null;
        closeDashboards();
        targetScreen = target;
        launcherScreen = target;
        if (!close)
            launcher.resetSearch();
        launcher.opened = !close;
        return true;
    }

    function toggleSettings(screen, returnBar) {
        const target = screen || preferredScreen();
        if (!target)
            return false;
        const close = appearance.visible && settingsScreen === target;
        targetScreen = target;
        settingsScreen = target;
        if (!close) {
            settingsReturnBar = returnBar || null;
            closeDashboards();
            launcher.opened = false;
        }
        appearance.visible = !close;
        return true;
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Quickshell.screens.indexOf(desktop.launcherScreen) === -1) {
                launcher.opened = false;
                desktop.launcherScreen = desktop.preferredScreen();
            }
            if (Quickshell.screens.indexOf(desktop.settingsScreen) === -1) {
                desktop.settingsReturnBar = null;
                appearance.visible = false;
                desktop.settingsScreen = desktop.preferredScreen();
            }
            if (Quickshell.screens.indexOf(desktop.targetScreen) === -1)
                desktop.targetScreen = desktop.preferredScreen();
        }
    }

    Variants {
        id: bars
        model: Quickshell.screens
        Bar {
            id: bar
            required property var modelData
            screen: modelData
            previewMode: desktop.previewMode
            onLauncherRequested: desktop.toggleLauncher(modelData)
            onAppearanceRequested: desktop.toggleSettings(modelData)
            onDashboardRequested: desktop.toggleDashboard(modelData)
            onSettingsRequested: desktop.toggleSettings(modelData, bar)
        }
    }

    Launcher {
        id: launcher
        screen: desktop.launcherScreen
        opened: false
        onDismissed: launcher.opened = false
    }

    App {
        id: appearance
        standalone: false
        title: "Senntisten · Settings"
        visible: false
        screen: desktop.settingsScreen
        onVisibleChanged: {
            if (!visible && desktop.settingsReturnBar) {
                const bar = desktop.settingsReturnBar;
                desktop.settingsReturnBar = null;
                if (desktop.barForScreen(bar.screen) === bar)
                    bar.openDashboard(true);
            }
        }
        // FloatingWindow may become visible while its native Wayland surface is
        // first connected. Desktop settings are always opt-in.
        Component.onCompleted: visible = false
    }

    IpcHandler {
        target: "senntisten"
        function launcher(): bool {
            return desktop.toggleLauncher(null);
        }
        function dashboard(): bool {
            return desktop.toggleDashboard(null);
        }
        function settings(): bool {
            return desktop.toggleSettings(null);
        }
        function theme(id: string): bool {
            return Theme.selectTheme(id);
        }
        function quit(): void {
            Qt.quit();
        }
        function status(): string {
            return JSON.stringify({
                mode: "desktop",
                ready: Theme.ready,
                preview: desktop.previewMode,
                theme: Theme.settings.theme,
                saveStatus: Theme.saveStatus,
                message: Theme.message,
                writable: Theme.writable,
                screenCount: Quickshell.screens.length,
                targetScreen: desktop.targetScreen ? desktop.targetScreen.name : "",
                launcherOpen: launcher.opened,
                dashboardOpen: bars.instances.some(bar => bar.dashboardOpen),
                appearanceOpen: appearance.visible
            });
        }
    }
}
