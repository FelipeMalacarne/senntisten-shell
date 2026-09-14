import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
// Copied inside the selected config root by launcher_integration.py.
import "services"
import "desktop"

ShellRoot {
    FloatingWindow {
        id: window
        implicitWidth: 900
        implicitHeight: 720
        visible: true
        color: Theme.colors.background

        Loader {
            id: launcher
            anchors.fill: parent
            source: "desktop/LauncherContent.qml"
        }

        TestCase {
            id: tests
            name: "SenntistenLauncher"
            when: window.visible && Theme.ready
            property var executed: []
            property string checkpoint: ""
            function cleanup() {
                console.log("SENNTISTEN_LAUNCHER_CASE " + JSON.stringify({
                    name: qtest_results.functionName, failed: qtest_results.failed, checkpoint: checkpoint,
                    index: launcher.item ? launcher.item.currentIndex : null,
                    focus: launcher.item ? findChild(launcher.item, "launcherSearch").activeFocus : false
                }));
            }
            SignalSpy {
                id: dismissal
                target: launcher.item
                signalName: "dismissed"
            }
            Process {
                id: clearEntries
                command: [Quickshell.env("SENNTISTEN_TEST_PYTHON"), Quickshell.env("SENNTISTEN_TEST_CLEAR_ENTRIES")]
            }
            FileView {
                id: marker
                path: Quickshell.env("SENNTISTEN_LAUNCHER_MARKER")
                preload: false
                printErrors: false
            }
            function markerCount(identifier) {
                marker.reload();
                const text = marker.text().trim();
                return text ? text.split("\n").map(line => JSON.parse(line)).filter(entry => entry.id === identifier).length : 0;
            }
            function init() {
                executed = executed.concat([qtest_results.functionName]);
                checkpoint = "setup";
                tryCompare(launcher, "status", Loader.Ready);
                tryVerify(() => DesktopEntries.applications.values.length === 13);
                if (typeof launcher.item.resetSearch === "function")
                    launcher.item.resetSearch();
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_LAUNCHER_UI_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }
            function typeQuery(text) {
                const field = findChild(launcher.item, "launcherSearch");
                verify(field !== null, "Search must expose a text field");
                field.forceActiveFocus();
                keyClick(Qt.Key_A, Qt.ControlModifier);
                keyClick(Qt.Key_Backspace);
                for (const character of text)
                    keyClick(character);
            }
            function test_dismissal_escape_outside_and_close_button() {
                dismissal.clear();
                keyClick(Qt.Key_Escape);
                compare(dismissal.count, 1);
                const backdrop = findChild(launcher.item, "launcherBackdrop");
                verify(backdrop !== null && backdrop.opacity > 0 && backdrop.opacity < 1);
                const panel = findChild(launcher.item, "launcherPanel");
                mouseClick(panel, 4, 4);
                compare(dismissal.count, 1, "Clicking blank panel space must not dismiss");
                mouseClick(launcher.item, 4, 4);
                compare(dismissal.count, 2);
                const close = findChild(launcher.item, "launcherClose");
                verify(close !== null);
                mouseClick(close);
                compare(dismissal.count, 3);
            }
            function test_empty_search_is_safe_and_explained() {
                typeQuery("$(not-a-command)");
                tryCompare(launcher.item, "resultCount", 0);
                compare(launcher.item.currentIndex, -1);
                const empty = findChild(launcher.item, "launcherEmpty");
                verify(empty !== null && empty.visible);
                compare(empty.text, "No matching applications");
                dismissal.clear();
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Up);
                keyClick(Qt.Key_Return);
                compare(launcher.item.currentIndex, -1);
                compare(dismissal.count, 0, "Unmatched text must never execute as a command");
                launcher.item.resetSearch();
                tryCompare(launcher.item, "resultCount", 8);
                compare(empty.visible, false);
            }
            function test_keyboard_selection_and_native_execute() {
                tryVerify(() => DesktopEntries.applications.values.length === 13);
                verify(typeof launcher.item.resetSearch === "function", "Opening must reset and focus search");
                launcher.item.resetSearch();
                const field = findChild(launcher.item, "launcherSearch");
                checkpoint = "reset focus";
                tryCompare(field, "activeFocus", true);
                checkpoint = "navigation";
                compare(launcher.item.currentIndex, 0);
                keyClick(Qt.Key_Up);
                compare(launcher.item.currentIndex, 7);
                keyClick(Qt.Key_Down);
                compare(launcher.item.currentIndex, 0);
                keyClick(Qt.Key_Down);
                compare(launcher.item.currentIndex, 1);
                typeQuery("journal");
                checkpoint = "query reset";
                compare(launcher.item.currentIndex, 0);
                dismissal.clear();
                keyClick(Qt.Key_Return);
                checkpoint = "dismissal";
                tryCompare(dismissal, "count", 1);
                checkpoint = "native marker";
                tryVerify(() => markerCount("beta") === 1, 3000);
            }
            function test_mouse_result_uses_native_icon_and_execute() {
                typeQuery("Alpha");
                const panel = findChild(launcher.item, "launcherPanel");
                checkpoint = "panel geometry";
                verify(panel !== null, "Results belong in a compact centered panel");
                verify(panel.width <= 560 && panel.width < launcher.item.width);
                compare(panel.x, (launcher.item.width - panel.width) / 2);
                const list = findChild(launcher.item, "launcherResults");
                checkpoint = "row";
                verify(list !== null);
                tryVerify(() => list.itemAtIndex(0) !== null);
                const row = list.itemAtIndex(0);
                compare(row.text, "Alpha Browser");
                const icon = findChild(row, "launcherResultIcon");
                checkpoint = "icon source";
                verify(icon !== null);
                compare(icon.source.toString(), Quickshell.iconPath(Quickshell.env("SENNTISTEN_LAUNCHER_ICON"), true));
                tryCompare(icon, "status", Image.Ready);
                waitForRendering(icon);
                // Software QtTest snapshots of nested items can crop at the window origin.
                // Sample the complete window using the icon's mapped coordinates instead.
                const image = grabImage(launcher.item);
                const point = icon.mapToItem(launcher.item, icon.width / 2, icon.height / 2);
                checkpoint = "rendered native icon";
                compare(image.pixel(Math.floor(point.x), Math.floor(point.y)), "#00aa77");
                checkpoint = "mouse launch";
                dismissal.clear();
                mouseClick(row);
                tryCompare(dismissal, "count", 1);
                tryVerify(() => markerCount("alpha") === 1, 3000);
            }
            function test_narrow_layout_scrolls_selection_and_keeps_hints_visible() {
                const oldWidth = window.contentItem.width;
                const oldHeight = window.contentItem.height;
                try {
                    window.contentItem.width = 360;
                    window.contentItem.height = 360;
                    const panel = findChild(launcher.item, "launcherPanel");
                    const list = findChild(launcher.item, "launcherResults");
                    const hint = findChild(launcher.item, "launcherHint");
                    verify(hint !== null, "Navigation and result-limit hints must be visible");
                    tryVerify(() => panel.width <= 328 && panel.height <= 328);
                    tryVerify(() => {
                        const point = hint.mapToItem(launcher.item, 0, 0);
                        return point.y >= panel.y && point.y + hint.height <= panel.y + panel.height;
                    });
                    verify(list.contentHeight > list.height);
                    const scrollbar = findChild(launcher.item, "launcherScrollbar");
                    verify(scrollbar !== null && scrollbar.visible);
                    Theme.setReducedMotion(true);
                    compare(list.highlightMoveDuration, 0);
                    keyClick(Qt.Key_Up);
                    compare(launcher.item.currentIndex, 7);
                    tryVerify(() => {
                        const row = list.itemAtIndex(7);
                        if (!row) return false;
                        const point = row.mapToItem(list, 0, 0);
                        return point.y >= 0 && point.y + row.height <= list.height;
                    });
                    typeQuery("Alpha");
                    compare(launcher.item.currentIndex, 0);
                    waitForRendering(launcher.item);
                    const rendered = grabImage(launcher.item);
                    compare(rendered.width, 360);
                    compare(rendered.height, 360);
                } finally {
                    window.contentItem.width = oldWidth;
                    window.contentItem.height = oldHeight;
                    Theme.setReducedMotion(false);
                }
            }
            function test_tab_focus_follows_selection_and_close_is_keyboard_accessible() {
                const field = findChild(launcher.item, "launcherSearch");
                const close = findChild(launcher.item, "launcherClose");
                const list = findChild(launcher.item, "launcherResults");
                keyClick(Qt.Key_Down);
                keyClick(Qt.Key_Down);
                compare(launcher.item.currentIndex, 2);
                keyClick(Qt.Key_Tab);
                checkpoint = "tab selected row";
                tryVerify(() => list.itemAtIndex(2) && list.itemAtIndex(2).activeFocus);
                compare(list.itemAtIndex(2).text, "Gamma Console");
                keyClick(Qt.Key_Backtab);
                tryCompare(field, "activeFocus", true);
                keyClick(Qt.Key_Tab);
                keyClick(Qt.Key_Tab);
                checkpoint = "tab close";
                tryCompare(close, "activeFocus", true);
                dismissal.clear();
                keyClick(Qt.Key_Return);
                compare(dismissal.count, 1, "Enter on Close must dismiss, never launch a result");
                keyClick(Qt.Key_Tab);
                tryCompare(field, "activeFocus", true);
                keyClick(Qt.Key_Tab);
                keyClick(Qt.Key_Enter);
                tryVerify(() => markerCount("gamma") === 1, 3000);
                typeQuery("no such app");
                keyClick(Qt.Key_Tab);
                tryCompare(close, "activeFocus", true);
                keyClick(Qt.Key_Backtab);
                tryCompare(field, "activeFocus", true);
            }
            function test_theme_recolors_rendered_launcher_without_reopening() {
                const field = findChild(launcher.item, "launcherSearch");
                const panel = findChild(launcher.item, "launcherPanel");
                typeQuery("Alpha");
                Theme.setReducedMotion(true);
                for (const id of ["gruvbox", "catppuccin-mocha"]) {
                    Theme.selectTheme(id);
                    tryCompare(Theme, "saveStatus", "saved");
                    checkpoint = id + " input colors";
                    compare(field.color.toString(), Theme.colors.text);
                    compare(field.placeholderTextColor.toString(), Theme.colors.muted);
                    compare(field.selectionColor.toString(), Theme.colors.accent);
                    compare(field.selectedTextColor.toString(), Theme.colors.accentText);
                    compare(field.background.color.toString(), Theme.colors.background);
                    compare(field.background.border.color.toString(), Theme.colors.accent);
                    tryCompare(panel.background, "color", Theme.colors.surface);
                    const row = findChild(launcher.item, "launcherResults").itemAtIndex(0);
                    compare(row.background.border.color.toString(), Theme.colors.accent);
                    compare(findChild(row, "launcherResultName").color.toString(), Theme.colors.text);
                    compare(findChild(row, "launcherResultGeneric").color.toString(), Theme.colors.muted);
                    waitForRendering(launcher.item);
                    const image = grabImage(launcher.item);
                    const point = field.mapToItem(launcher.item, field.width - 12, field.height / 2);
                    compare(image.pixel(Math.floor(point.x), Math.floor(point.y)), Theme.colors.background);
                    compare(image.pixel(Math.floor(panel.x + panel.width / 2), Math.floor(panel.y + 4)), Theme.colors.surface);
                    compare(field.text, "Alpha", "Theme changes must preserve the current search");
                }
                Theme.setReducedMotion(false);
                tryCompare(Theme, "saveStatus", "saved");
            }
            function test_z_catalog_removal_updates_empty_state_live() {
                // QtTest orders functions by name: remove disposable fixtures last.
                clearEntries.running = true;
                tryVerify(() => DesktopEntries.applications.values.length === 0);
                tryCompare(launcher.item, "resultCount", 0);
                compare(launcher.item.currentIndex, -1);
                const empty = findChild(launcher.item, "launcherEmpty");
                verify(empty.visible);
                compare(empty.text, "No applications found");
                dismissal.clear();
                keyClick(Qt.Key_Enter);
                compare(dismissal.count, 0);
                keyClick(Qt.Key_Tab);
                tryCompare(findChild(launcher.item, "launcherClose"), "activeFocus", true);
                keyClick(Qt.Key_Escape);
                compare(dismissal.count, 1);
            }
            function test_real_desktop_entries_are_discovered_and_searched() {
                tryVerify(() => DesktopEntries.applications.values.length === 13);
                verify(DesktopEntries.applications.values.every(entry => entry.id.startsWith("senntisten-test-")),
                    "Only temporary fixtures may be discovered; never use personal applications");
                tryCompare(launcher.item, "resultCount", 8);
                typeQuery("web");
                tryCompare(launcher.item, "resultCount", 1);
                compare(launcher.item.results[0].id, "senntisten-test-alpha");
                typeQuery("journal");
                tryCompare(launcher.item, "resultCount", 1);
                compare(launcher.item.results[0].id, "senntisten-test-beta");
                typeQuery("GAMMA");
                tryCompare(launcher.item, "resultCount", 1);
                compare(launcher.item.results[0].id, "senntisten-test-gamma");
            }
        }
    }
}
