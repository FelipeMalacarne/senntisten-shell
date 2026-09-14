import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
// The integration runner copies this beside shell.qml for Quickshell module scanning.
import "."
import "services"

ShellRoot {
    App {
        id: app
        TestCase {
            name: "SenntistenControls"
            when: Theme.ready && app.visible
            property var executed: []
            FileView {
                id: readback
                path: Theme.statePath
                preload: false
                printErrors: false
            }
            function init() {
                executed = executed.concat([qtest_results.functionName]);
            }
            onCompletedChanged: if (completed) {
                console.log("SENNTISTEN_UI_RESULT " + JSON.stringify({
                    passed: qtest_results.passCount,
                    failed: qtest_results.failCount,
                    skipped: qtest_results.skipCount,
                    executed: executed
                }));
            }

            function test_control_labels_use_the_theme_foreground() {
                const option = findChild(app.contentItem, "theme-gruvbox");
                const optionLabel = findChild(option, "themeOptionLabel");
                const motionLabel = findChild(app.contentItem, "motionLabel");
                verify(optionLabel !== null && motionLabel !== null);
                compare(optionLabel.color.toString(), Theme.colors.text);
                compare(motionLabel.color.toString(), Theme.colors.text);
            }

            function test_keyboard_shortcuts_and_primary_button_share_actions() {
                const appearance = findChild(app.contentItem, "appearanceButton");
                appearance.forceActiveFocus();
                app.view.panelOpen = true;
                keyClick(Qt.Key_Comma, Qt.ControlModifier);
                compare(app.view.panelOpen, false);
                keyClick(Qt.Key_Comma, Qt.ControlModifier);
                compare(app.view.panelOpen, true);
                keyClick(Qt.Key_Escape);
                compare(app.view.panelOpen, false);
                app.view.panelOpen = true;
                const original = Theme.settings.theme;
                keyClick(Qt.Key_T, Qt.ControlModifier);
                tryCompare(Theme, "saveStatus", "saved");
                verify(Theme.settings.theme !== original);
                const cycle = findChild(app.contentItem, "cycleThemeButton");
                verify(cycle !== null);
                mouseClick(cycle);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.theme, original);
            }

            function test_layout_keeps_feedback_visible_at_small_sizes() {
                const oldWidth = app.contentItem.width;
                const oldHeight = app.contentItem.height;
                try {
                    app.contentItem.width = 660;
                    app.contentItem.height = 540;
                    tryCompare(app.view, "wide", false);
                    const footer = findChild(app.contentItem, "stateFooter");
                    verify(footer !== null);
                    tryVerify(() => {
                        const point = footer.mapToItem(app.view, 0, 0);
                        return point.y >= 0 && point.y + footer.height <= app.view.height;
                    });
                    const panel = findChild(app.contentItem, "appearancePanel");
                    verify(panel.width <= app.view.width);
                    const trigger = findChild(app.contentItem, "appearanceButton");
                    const buttonPoint = trigger.mapToItem(app.view, 0, 0);
                    verify(buttonPoint.x >= 0 && buttonPoint.x + trigger.width <= app.view.width);
                    const output = Quickshell.env("SENNTISTEN_CAPTURE_DIR");
                    if (output)
                        grabImage(app.view).save(output + "/compact.png");
                    const scroll = findChild(app.contentItem, "contentScroll");
                    const scrollbar = findChild(app.contentItem, "contentScrollbar");
                    verify(scrollbar !== null && scrollbar.visible, "Overflow needs a visible scrollbar");
                    verify(scroll.contentItem.contentHeight > scroll.contentItem.height);
                    scroll.contentItem.contentY = scroll.contentItem.contentHeight - scroll.contentItem.height;
                    const motion = findChild(app.contentItem, "reducedMotionSwitch");
                    tryVerify(() => {
                        const point = motion.mapToItem(app.view, 0, 0);
                        return point.y > 0 && point.y + motion.height < footer.y;
                    });
                    const previous = Theme.settings.reducedMotion;
                    mouseClick(motion);
                    tryCompare(Theme, "saveStatus", "saved");
                    compare(Theme.settings.reducedMotion, !previous);
                    mouseClick(motion);
                    tryCompare(Theme, "saveStatus", "saved");
                    compare(Theme.settings.reducedMotion, previous);
                    if (output)
                        grabImage(app.view).save(output + "/compact-scrolled.png");
                    scroll.contentItem.contentY = 0;
                } finally {
                    app.contentItem.width = oldWidth;
                    app.contentItem.height = oldHeight;
                }
            }

            function test_rapid_updates_save_the_latest_selection() {
                for (let i = 0; i < 20; i++) {
                    Theme.selectTheme(i % 2 === 0 ? "gruvbox" : "catppuccin-mocha");
                    Theme.setReducedMotion(i % 2 === 0);
                }
                Theme.selectTheme("gruvbox");
                Theme.setReducedMotion(false);
                tryCompare(Theme, "saveStatus", "saved");
                readback.reload();
                tryVerify(() => {
                    try {
                        const saved = JSON.parse(readback.text());
                        return saved.theme === "gruvbox" && saved.reducedMotion === false;
                    } catch (error) {
                        return false;
                    }
                });
            }

            function test_rendered_palettes_match_their_tokens() {
                app.view.panelOpen = true;
                const output = Quickshell.env("SENNTISTEN_CAPTURE_DIR");
                for (const id of ["catppuccin-mocha", "gruvbox"]) {
                    Theme.selectTheme(id);
                    tryCompare(Theme, "saveStatus", "saved");
                    const sample = findChild(app.contentItem, "componentCanvas");
                    tryCompare(sample.background, "color", Theme.colors.surface);
                    const image = grabImage(app.view);
                    compare(image.width, app.view.width);
                    compare(image.height, app.view.height);
                    compare(image.pixel(0, 0), Theme.colors.background);
                    if (output)
                        image.save(output + "/" + id + ".png");
                }
            }

            function test_reduced_motion_switch_is_keyboard_accessible() {
                app.view.panelOpen = true;
                const toggle = findChild(app.contentItem, "reducedMotionSwitch");
                verify(toggle !== null, "Appearance must expose reduced motion");
                toggle.forceActiveFocus();
                keyClick(Qt.Key_Space);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.reducedMotion, true);
                compare(Theme.animationDuration, 0);
                keyClick(Qt.Key_Space);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.reducedMotion, false);
                verify(Theme.animationDuration > 0);
            }

            function test_theme_buttons_recolor_shared_components() {
                app.view.panelOpen = true;
                const gruvbox = findChild(app.contentItem, "theme-gruvbox");
                verify(gruvbox !== null, "Appearance must offer a Gruvbox preset");
                mouseClick(gruvbox);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.theme, "gruvbox");
                compare(app.view.color.toString(), "#1d2021");
                const sample = findChild(app.contentItem, "componentCanvas");
                tryCompare(sample.background, "color", "#282828");
                const title = findChild(app.contentItem, "previewTitle");
                verify(title !== null);
                tryCompare(title, "color", "#ebdbb2");
                const mocha = findChild(app.contentItem, "theme-catppuccin-mocha");
                verify(mocha !== null);
                mocha.forceActiveFocus();
                keyClick(Qt.Key_Space);
                tryCompare(Theme, "saveStatus", "saved");
                compare(Theme.settings.theme, "catppuccin-mocha");
                compare(app.view.color.toString(), "#11111b");
                tryCompare(sample.background, "color", "#1e1e2e");
            }

            function test_appearance_panel_mouse_toggle() {
                const trigger = findChild(app.contentItem, "appearanceButton");
                verify(trigger !== null, "The compact bar must provide an appearance button");
                tryVerify(() => trigger.width > 0 && trigger.height > 0 && trigger.visible);
                verify(app.view.panelOpen);
                mouseClick(trigger);
                compare(app.view.panelOpen, false);
                mouseClick(trigger);
                compare(app.view.panelOpen, true);
            }
        }
    }
}
