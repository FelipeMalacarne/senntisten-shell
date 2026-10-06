import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
// Copied beside App.qml so Quickshell scans the real local modules.
import "."
import "services"

ShellRoot {
    App {
        id: app
        standalone: false

        TestCase {
            name: "SenntistenSettings"
            when: Theme.ready && app.visible
            property var executed: []
            property string checkpoint: ""

            SignalSpy {
                id: closeSpy
                target: app.settingsView || null
                signalName: "closeRequested"
            }
            FileView {
                id: readback
                path: Theme.statePath
                preload: false
                printErrors: false
            }

            function init() {
                executed = executed.concat([qtest_results.functionName]);
                checkpoint = "setup";
                app.visible = true;
                resize(860, 650);
                closeSpy.clear();
            }
            function cleanup() {
                console.log("SENNTISTEN_SETTINGS_CASE " + JSON.stringify({
                    name: qtest_results.functionName,
                    passed: !qtest_results.failed,
                    failed: qtest_results.failed,
                    checkpoint: checkpoint,
                    theme: Theme.settings.theme,
                    saveStatus: Theme.saveStatus
                }));
                app.visible = true;
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_SETTINGS_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }

            function item(name) {
                checkpoint = name;
                const result = findChild(settings(), name);
                verify(result !== null, "Settings must expose " + name);
                return result;
            }
            function settings() {
                verify(app.settingsView !== undefined, "App must expose its dedicated settingsView");
                return app.settingsView;
            }
            function fits(control, viewport) {
                const p = control.mapToItem(viewport, 0, 0);
                return p.x >= -1 && p.y >= -1 && p.x + control.width <= viewport.width + 1 && p.y + control.height <= viewport.height + 1;
            }
            function resize(width, height) {
                checkpoint = "resize " + width + "x" + height;
                const window = app.contentItem.Window.window;
                verify(window !== null);
                window.width = width;
                window.height = height;
                tryCompare(app.contentItem, "width", width);
                tryCompare(app.contentItem, "height", height);
            }
            function capture(name) {
                const output = Quickshell.env("SENNTISTEN_CAPTURE_DIR");
                const image = grabImage(settings());
                compare(image.width, settings().width);
                compare(image.height, settings().height);
                if (output)
                    image.save(output + "/settings-" + name + ".png");
                return image;
            }

            function test_00_normal_window_is_roomy_and_distinct_from_playground() {
                compare(app.implicitWidth, 860);
                compare(app.implicitHeight, 650);
                compare(app.minimumSize.width, 320);
                compare(app.minimumSize.height, 360);
                verify(app.title.indexOf("Settings") >= 0);
                verify(app.view === null || !app.view.visible);
                verify(settings().visible);
                const heading = item("settingsHeading");
                compare(heading.text, "Appearance");
                compare(heading.font.family, "DejaVu Serif");
                verify(heading.font.pixelSize >= 28);
            }

            function test_sidebar_and_planned_preferences_are_explicitly_disabled() {
                const appearance = item("settingsAppearance");
                verify(appearance.enabled && appearance.selected);
                compare(appearance.Accessible.name, "Appearance");
                for (const name of ["settingsDesktop", "settingsLauncher", "settings-wallpaper", "settings-font", "settings-density"]) {
                    const planned = item(name);
                    verify(!planned.enabled, name + " must not imply implemented behavior");
                    verify(planned.Accessible.name.indexOf("Planned") >= 0);
                    verify(planned.text.indexOf("Planned") >= 0);
                }
                const sidebar = item("settingsSidebar");
                const heading = item("settingsHeading");
                verify(sidebar.mapToItem(settings(), 0, 0).x + sidebar.width <= heading.mapToItem(settings(), 0, 0).x);
            }

            function test_responsive_breakpoint_keeps_controls_within_the_window() {
                for (const width of [320, 480, 639, 640, 860]) {
                    resize(width, 360);
                    const scroll = item("settingsScroll");
                    tryCompare(settings(), "wide", width >= 640);
                    tryVerify(() => scroll.contentItem.contentWidth <= scroll.contentItem.width + 1);
                    for (const name of ["themeClose", "themeSaveStatus", "settingsAppearance", "settingsDesktop", "settingsLauncher"])
                        tryVerify(() => fits(item(name), settings()), 1000, name + " must fit at " + width);
                    for (const name of ["theme-catppuccin-mocha", "theme-gruvbox", "reducedMotionSwitch", "settings-wallpaper", "settings-font", "settings-density"]) {
                        const control = item(name);
                        tryVerify(() => {
                            const p = control.mapToItem(settings(), 0, 0);
                            return p.x >= 0 && p.x + control.width <= width + 1;
                        }, 1000, name + " must not overflow at " + width);
                    }
                }
            }

            function test_palette_cards_render_both_palettes_wide_and_narrow() {
                for (const id of ["catppuccin-mocha", "gruvbox"]) {
                    verify(Theme.selectTheme(id));
                    tryCompare(Theme, "saveStatus", "saved");
                    for (const width of [860, 320]) {
                        resize(width, width === 860 ? 650 : 360);
                        const scroll = item("settingsScroll");
                        scroll.contentItem.contentY = 0;
                        tryVerify(() => settings().width === width && item("theme-" + id).width > 0);
                        const option = item("theme-" + id);
                        compare(option.selected, true);
                        verify(option.height >= 84, "Settings palettes need roomy cards, not compact playground rows");
                        settings().focusInitial();
                        tryVerify(() => fits(option, scroll.contentItem));
                        tryCompare(item("settingsSurface"), "color", Theme.colors.surface);
                        tryCompare(item("settingsHeading"), "color", Theme.colors.text);
                        tryCompare(item("themeOptionLabel"), "color", Theme.colors.text);
                        tryVerify(() => fits(item("themeClose"), settings()) && fits(item("themeSaveStatus"), settings()));
                        const image = capture(id + (width === 860 ? "-wide" : "-narrow"));
                        compare(image.pixel(0, 0), Theme.colors.surface);
                    }
                }
            }

            function test_narrow_scroll_reveals_keyboard_preferences_without_horizontal_overflow() {
                resize(320, 360);
                const scroll = item("settingsScroll");
                const viewport = scroll.contentItem;
                tryVerify(() => viewport.contentHeight > viewport.height);
                verify(item("settingsScrollbar").visible);
                verify(viewport.contentWidth <= viewport.width + 1);
                scroll.contentItem.contentY = 0;
                const mocha = item("theme-catppuccin-mocha");
                const gruvbox = item("theme-gruvbox");
                const motion = item("reducedMotionSwitch");
                mocha.forceActiveFocus();
                checkpoint = "narrow Tab to Gruvbox";
                keyClick(Qt.Key_Tab);
                compare(gruvbox.activeFocus, true);
                checkpoint = "narrow reveal Gruvbox";
                tryVerify(() => fits(gruvbox, viewport));
                checkpoint = "narrow Tab to motion";
                keyClick(Qt.Key_Tab);
                compare(motion.activeFocus, true);
                checkpoint = "narrow reveal motion";
                tryVerify(() => fits(motion, viewport));
                verify(viewport.contentY > 0);
                checkpoint = "narrow Shift+Tab to Gruvbox";
                keyClick(Qt.Key_Tab, Qt.ShiftModifier);
                compare(gruvbox.activeFocus, true);
                tryVerify(() => fits(gruvbox, viewport));
                viewport.contentY = viewport.contentHeight - viewport.height;
                tryVerify(() => fits(item("settings-density"), viewport));
                capture("narrow-scrolled");
            }

            function test_keyboard_palette_selection_saves_real_state() {
                for (const id of ["catppuccin-mocha", "gruvbox"]) {
                    const option = item("theme-" + id);
                    option.forceActiveFocus();
                    keyClick(Qt.Key_Space);
                    tryCompare(Theme, "saveStatus", "saved");
                    compare(Theme.settings.theme, id);
                    readback.reload();
                    tryVerify(() => {
                        try {
                            return JSON.parse(readback.text()).theme === id;
                        } catch (error) {
                            return false;
                        }
                    });
                    compare(item("themeSaveStatus").text, "Appearance saved.");
                }
                mouseClick(item("theme-catppuccin-mocha"));
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.theme, "catppuccin-mocha");
            }

            function test_reduced_motion_keyboard_changes_and_persists() {
                const motion = item("reducedMotionSwitch");
                verify(Theme.setReducedMotion(false));
                tryCompare(Theme, "saveStatus", "saved");
                motion.forceActiveFocus();
                keyClick(Qt.Key_Space);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.reducedMotion, true);
                compare(Theme.animationDuration, 0);
                readback.reload();
                tryVerify(() => {
                    try {
                        return JSON.parse(readback.text()).reducedMotion === true;
                    } catch (error) {
                        return false;
                    }
                });
                keyClick(Qt.Key_Space);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.reducedMotion, false);
                verify(Theme.animationDuration > 0);
            }

            function test_loading_and_saving_feedback_are_visible_and_controls_are_gated() {
                const ready = Theme.ready;
                const status = Theme.saveStatus;
                const message = Theme.message;
                try {
                    Theme.ready = false;
                    Theme.saveStatus = "loading";
                    Theme.message = "";
                    const feedback = item("themeSaveStatus");
                    verify(feedback.visible);
                    verify(feedback.text.indexOf("Loading") >= 0);
                    verify(!item("theme-gruvbox").enabled && !item("reducedMotionSwitch").enabled);
                    Theme.ready = true;
                    Theme.saveStatus = "saving";
                    verify(feedback.text.indexOf("Saving") >= 0);
                    verify(feedback.text.indexOf("saved") < 0);
                    compare(feedback.wrapMode, Text.Wrap);
                    compare(feedback.elide, Text.ElideNone);
                } finally {
                    Theme.ready = ready;
                    Theme.saveStatus = status;
                    Theme.message = message;
                }
            }

            function test_opening_and_reopening_focuses_the_current_palette() {
                verify(Theme.selectTheme("gruvbox"));
                tryCompare(Theme, "saveStatus", "saved");
                settings().focusInitial();
                tryCompare(item("theme-gruvbox"), "activeFocus", true);
                app.visible = false;
                verify(Theme.selectTheme("catppuccin-mocha"));
                tryCompare(Theme, "saveStatus", "saved");
                app.visible = true;
                tryCompare(item("theme-catppuccin-mocha"), "activeFocus", true);
            }

            function test_close_button_and_escape_emit_without_quitting_the_host() {
                settings();
                mouseClick(item("themeClose"));
                compare(closeSpy.count, 1);
                compare(app.visible, false);
                app.visible = true;
                tryVerify(() => item("theme-" + Theme.settings.theme).activeFocus);
                checkpoint = "palette Escape closes Settings";
                keyClick(Qt.Key_Escape);
                compare(closeSpy.count, 2);
                compare(app.visible, false);
                app.visible = true;
                item("reducedMotionSwitch").forceActiveFocus();
                checkpoint = "motion Escape closes Settings";
                keyClick(Qt.Key_Escape);
                compare(closeSpy.count, 3);
                compare(app.visible, false);
                app.visible = true;
            }
        }
    }
}
