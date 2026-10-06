import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "."
import "desktop"
import "services"

ShellRoot {
    id: root
    readonly property string scene: Quickshell.env("SENNTISTEN_INSPECT_SCENE")
    readonly property var actions: JSON.parse(Quickshell.env("SENNTISTEN_INSPECT_ACTIONS"))
    readonly property var host: scene === "settings" ? settings : window
    readonly property var view: scene === "settings" ? settings.settingsView : loader.item
    property var events: ({
            launcher: 0,
            settings: 0,
            audio: 0,
            dismissed: 0,
            workspace: -1
        })
    property int poisonExit: -1
    Process {
        id: poisonState
        command: [Quickshell.env("SENNTISTEN_TEST_PYTHON"), Quickshell.env("SENNTISTEN_INSPECT_POISON")]
        onExited: (exitCode, exitStatus) => root.poisonExit = exitCode
    }

    // Fixtures replace only provider boundaries. No live workspace/audio mutation.
    QtObject {
        id: fixtures
        property bool audioAvailable: Quickshell.env("SENNTISTEN_INSPECT_UNAVAILABLE") !== "1"
        property real volume: 0.42
        readonly property int volumePercent: Math.round(volume * 100)
        property bool muted: false
        property string outputName: "Isolated fixture output"
        readonly property string audioStatus: audioAvailable ? "" : "PipeWire unavailable"
        property bool compositorAvailable: audioAvailable
        property var activeToplevel: ({
                title: "Fixture editor",
                monitor: {
                    name: "TEST-1"
                }
            })
        property var workspaces: compositorAvailable ? Array.from({
            length: 12
        }, (_, index) => ({
                    id: index + 1,
                    name: String(index + 1),
                    monitor: {
                        name: "TEST-1"
                    },
                    active: index === 0,
                    urgent: false,
                    activate: function () {
                        root.events.workspace = index + 1;
                    }
                })) : []
        property var trayItems: []
        function setVolume(value) {
            if (!audioAvailable)
                return false;
            volume = Math.max(0, Math.min(1, value));
            return true;
        }
        function toggleMute() {
            if (!audioAvailable)
                return false;
            muted = !muted;
            return true;
        }
    }

    App {
        id: settings
        standalone: false
        visible: root.scene === "settings"
    }
    FloatingWindow {
        id: window
        visible: root.scene !== "settings"
        color: Theme.colors.background
        Loader {
            id: loader
            x: root.scene === "controls" ? 20 : 0
            y: root.scene === "controls" ? 20 : 0
            width: root.scene === "controls" && item ? Math.min(item.implicitWidth, parent.width - x * 2) : parent.width - x * 2
            height: root.scene === "controls" && item ? Math.min(item.implicitHeight, parent.height - y * 2) : parent.height
            active: root.scene !== "settings"
            Component.onCompleted: {
                if (root.scene === "bar")
                    setSource("desktop/BarContent.qml", {
                        services: fixtures,
                        screenName: "TEST-1",
                        hostWindow: window
                    });
                else if (root.scene === "controls")
                    setSource("desktop/AudioPanel.qml", {
                        services: fixtures
                    });
                else if (root.scene === "launcher")
                    setSource("desktop/LauncherContent.qml");
            }
        }
    }
    Connections {
        target: root.view
        ignoreUnknownSignals: true
        function onLauncherRequested() {
            root.events.launcher++;
        }
        function onAppearanceRequested() {
            root.events.settings++;
        }
        function onSettingsRequested() {
            root.events.settings++;
        }
        function onAudioRequested() {
            root.events.audio++;
        }
        function onDismissed() {
            root.events.dismissed++;
        }
        function onCloseRequested() {
            root.events.dismissed++;
        }
    }

    TestCase {
        id: driver
        parent: root.host.contentItem
        name: "SenntistenInspection"
        when: Theme.ready && root.view !== null
        property string currentArtifact: "000-initial"
        property var currentAction: ({
                op: "initial"
            })
        property bool recorded: false

        function require(condition, message) {
            if (!condition)
                throw new Error(message);
        }
        function descendants(item) {
            let result = [item];
            for (const child of item.children || [])
                result = result.concat(descendants(child));
            return result;
        }
        function resolve(target) {
            if (target === "$view")
                return root.view;
            const all = descendants(root.view);
            let matches = all.filter(item => item.objectName === target);
            if (!matches.length)
                matches = all.filter(item => item.Accessible.name === target && !item.Accessible.ignored);
            require(matches.length === 1, matches.length ? "Ambiguous target: " + target : "Unknown target: " + target);
            return matches[0];
        }
        function geometry(item) {
            const point = item.mapToItem(root.host.contentItem, 0, 0);
            return {
                x: point.x,
                y: point.y,
                width: item.width,
                height: item.height
            };
        }
        function visibleGeometry(item) {
            const box = geometry(item);
            let left = Math.max(0, box.x);
            let top = Math.max(0, box.y);
            let right = Math.min(root.host.contentItem.width, box.x + box.width);
            let bottom = Math.min(root.host.contentItem.height, box.y + box.height);
            for (let parent = item.parent; parent && parent !== root.host.contentItem; parent = parent.parent) {
                if (parent.clip) {
                    const clip = geometry(parent);
                    left = Math.max(left, clip.x);
                    top = Math.max(top, clip.y);
                    right = Math.min(right, clip.x + clip.width);
                    bottom = Math.min(bottom, clip.y + clip.height);
                }
            }
            return {
                x: left,
                y: top,
                width: Math.max(0, right - left),
                height: Math.max(0, bottom - top)
            };
        }
        function pointer(item, x, y) {
            require(root.host.visible && item.visible && item.opacity > 0, "Target is hidden");
            for (let parent = item.parent; parent; parent = parent.parent)
                require(parent.opacity > 0, "Target is hidden by its parent");
            require(item.enabled, "Target is disabled");
            const point = item.mapToItem(root.host.contentItem, x, y);
            const visible = visibleGeometry(item);
            require(visible.width > 0 && visible.height > 0 && point.x >= visible.x && point.x < visible.x + visible.width && point.y >= visible.y && point.y < visible.y + visible.height, "Target is clipped; scroll or navigate focus before clicking");
            return point;
        }
        function resize(width, height) {
            const native = root.host.contentItem.Window.window;
            native.width = width;
            native.height = height;
            tryCompare(root.host.contentItem, "width", width);
            tryCompare(root.host.contentItem, "height", height);
        }
        function snapshot(error) {
            recorded = true;
            const controls = descendants(root.view).filter(item => item.objectName || item.activeFocus || (item.Accessible.name && !item.Accessible.ignored)).map(item => {
                const box = geometry(item);
                const visible = visibleGeometry(item);
                const result = {
                    objectName: item.objectName,
                    accessibleName: item.Accessible.name,
                    enabled: item.enabled,
                    visible: item.visible,
                    activeFocus: item.activeFocus,
                    geometry: box,
                    visibleGeometry: visible,
                    inViewport: item.visible && visible.width > 0 && visible.height > 0 && visible.width >= box.width - 0.5 && visible.height >= box.height - 0.5
                };
                for (const property of ["text", "selected", "checked", "value", "hovered", "down", "contentX", "contentY", "contentWidth", "contentHeight", "currentIndex"])
                    if (property in item)
                        result[property] = item[property];
                return result;
            });
            let image = null;
            if (root.host.visible) {
                image = currentArtifact + ".png";
                grabImage(root.host.contentItem).save(Quickshell.env("SENNTISTEN_CAPTURE_DIR") + "/" + image);
            }
            console.log("SENNTISTEN_INSPECT_STEP " + JSON.stringify({
                artifact: currentArtifact,
                image: image,
                action: currentAction,
                error: error,
                scene: root.scene,
                theme: Theme.settings.theme,
                reducedMotion: Theme.settings.reducedMotion,
                saveStatus: Theme.saveStatus,
                message: Theme.message,
                writable: Theme.writable,
                visible: root.host.visible,
                viewport: {
                    width: root.host.contentItem.width,
                    height: root.host.contentItem.height
                },
                events: root.events,
                controls: controls
            }));
        }
        function act(action) {
            if (action.op === "wait") {
                wait(action.ms === undefined ? 200 : action.ms);
                return;
            }
            if (action.op === "resize") {
                resize(action.width, action.height);
                return;
            }
            if (action.op === "reset") {
                root.host.visible = true;
                if (root.scene === "launcher")
                    root.view.resetSearch();
                else if (root.view.focusInitial)
                    root.view.focusInitial(false);
                return;
            }
            if (action.op === "key") {
                const key = Qt["Key_" + action.key];
                require(key !== undefined, "Unknown Qt key: " + action.key);
                let modifiers = Qt.NoModifier;
                for (const name of action.modifiers || []) {
                    require(["Control", "Shift", "Alt", "Meta"].includes(name), "Unknown modifier: " + name);
                    modifiers |= Qt[name + "Modifier"];
                }
                keyClick(key, modifiers);
                return;
            }
            const item = resolve(action.target);
            if (action.op === "expect") {
                require(action.property in item, "Unknown property: " + action.property);
                for (let elapsed = 0; elapsed < 1500 && JSON.stringify(item[action.property]) !== JSON.stringify(action.value); elapsed += 25)
                    wait(25);
                require(JSON.stringify(item[action.property]) === JSON.stringify(action.value), "Expectation failed: " + action.target + "." + action.property + " = " + JSON.stringify(item[action.property]) + ", wanted " + JSON.stringify(action.value));
                return;
            }
            if (action.op === "focus") {
                require(item.enabled && item.visible, "Cannot focus a disabled or hidden target");
                item.forceActiveFocus();
                return;
            }
            if (action.op === "type") {
                require("text" in item, "Target has no text input");
                const point = pointer(item, item.width / 2, item.height / 2);
                mouseClick(root.host.contentItem, point.x, point.y);
                require(item.activeFocus, "Target is not a focused text input");
                if (action.replace !== false) {
                    keyClick(Qt.Key_A, Qt.ControlModifier);
                    keyClick(Qt.Key_Backspace);
                }
                for (const character of action.text)
                    keyClick(character);
                return;
            }
            const x = (action.x === undefined ? 0.5 : action.x) * item.width;
            const y = (action.y === undefined ? 0.5 : action.y) * item.height;
            const point = pointer(item, x, y);
            if (action.op === "click") {
                const button = action.button || "Left";
                require(["Left", "Right", "Middle"].includes(button), "Unknown pointer button");
                mouseClick(root.host.contentItem, point.x, point.y, Qt[button + "Button"]);
            } else if (action.op === "hover") {
                mouseMove(root.host.contentItem, point.x, point.y);
            } else if (action.op === "wheel") {
                mouseWheel(root.host.contentItem, point.x, point.y, action.dx || 0, action.dy || 0);
            } else if (action.op === "drag") {
                const start = pointer(item, (action.fromX === undefined ? 0.2 : action.fromX) * item.width, (action.fromY === undefined ? 0.5 : action.fromY) * item.height);
                const end = pointer(item, (action.toX === undefined ? 0.8 : action.toX) * item.width, (action.toY === undefined ? 0.5 : action.toY) * item.height);
                mousePress(root.host.contentItem, start.x, start.y);
                for (let step = 1; step <= 10; step++)
                    mouseMove(root.host.contentItem, start.x + (end.x - start.x) * step / 10, start.y + (end.y - start.y) * step / 10, 15, Qt.LeftButton);
                mouseRelease(root.host.contentItem, end.x, end.y);
            }
        }
        function test_replay() {
            try {
                resize(Number(Quickshell.env("SENNTISTEN_INSPECT_WIDTH")), Number(Quickshell.env("SENNTISTEN_INSPECT_HEIGHT")));
                if (root.scene === "launcher") {
                    const expected = Quickshell.env("SENNTISTEN_INSPECT_EMPTY") === "1" ? 0 : 13;
                    tryVerify(() => DesktopEntries.applications.values.length === expected);
                    root.view.resetSearch();
                } else if (root.view.focusInitial) {
                    root.view.focusInitial(false);
                }
                wait(200);
                if (Quickshell.env("SENNTISTEN_INSPECT_POISON")) {
                    poisonState.running = true;
                    tryCompare(root, "poisonExit", 0);
                }
                snapshot("");
                for (let index = 0; index < root.actions.length; index++) {
                    currentAction = root.actions[index];
                    currentArtifact = String(index + 1).padStart(3, "0") + "-" + currentAction.op;
                    recorded = false;
                    act(currentAction);
                    wait(200);
                    snapshot("");
                }
            } catch (error) {
                if (!recorded)
                    snapshot(String(error));
                fail(String(error));
            }
        }
        function cleanup() {
            if (qtest_results.failed && !recorded)
                snapshot("QtTest input or rendering failed");
        }
        onCompletedChanged: if (completed) {
            console.log("SENNTISTEN_INSPECT_RESULT " + JSON.stringify({
                passed: qtest_results.passCount,
                failed: qtest_results.failCount,
                skipped: qtest_results.skipCount
            }));
        }
    }
}
