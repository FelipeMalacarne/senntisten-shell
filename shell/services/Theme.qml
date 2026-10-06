pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import "../lib/ThemeCatalog.js" as Catalog

Singleton {
    id: root

    property var settings: Catalog.decodeState("").settings
    readonly property var colors: Catalog.paletteFor(settings.theme)
    readonly property var presets: Catalog.listThemes()
    readonly property var metrics: ({
            barHeight: 44,
            panelRadius: 21,
            panelPadding: 24,
            controlRadius: 11,
            resultHeight: 56
        })
    readonly property var typography: ({
            sans: "DejaVu Sans",
            serif: "DejaVu Serif",
            mono: "DejaVu Sans Mono"
        })
    readonly property int animationDuration: settings.reducedMotion ? 0 : 140
    readonly property string name: presets.filter(entry => entry.id === settings.theme)[0].name
    readonly property string stateDirectory: Quickshell.env("SENNTISTEN_STATE_DIR") || ((Quickshell.env("XDG_STATE_HOME").startsWith("/") ? Quickshell.env("XDG_STATE_HOME") : Quickshell.env("HOME") + "/.local/state") + "/senntisten-shell")
    readonly property string statePath: stateDirectory + "/appearance.json"
    property bool ready: false
    property bool writable: true
    property string saveStatus: "loading"
    property string message: ""
    property string lastSavedText: ""
    property string queuedText: ""
    property var activeWriter: null

    function selectTheme(id) {
        if (!ready || !writable || !Catalog.isKnownTheme(id))
            return false;
        return save({
            theme: id,
            reducedMotion: settings.reducedMotion
        });
    }

    function cycleTheme() {
        const index = presets.findIndex(entry => entry.id === settings.theme);
        return selectTheme(presets[(index + 1) % presets.length].id);
    }

    function setReducedMotion(enabled) {
        if (typeof enabled !== "boolean")
            return false;
        return save({
            theme: settings.theme,
            reducedMotion: enabled
        });
    }

    function save(next) {
        if (!ready || !writable)
            return false;
        settings = next;
        const text = Catalog.encodeState(next);
        if (!activeWriter && lastSavedText === text) {
            saveStatus = "saved";
            message = "";
            return true;
        }
        saveStatus = "saving";
        message = "";
        queuedText = text;
        startWrite();
        return true;
    }

    function startWrite() {
        if (activeWriter || !queuedText)
            return;
        const text = queuedText;
        queuedText = "";
        activeWriter = writeOperation.createObject(root, {
            contents: text
        });
        activeWriter.setText(text);
    }

    function finishWrite(writer, succeeded, error) {
        if (succeeded)
            lastSavedText = writer.contents;
        activeWriter = null;
        writer.destroy();
        if (queuedText && queuedText !== lastSavedText) {
            startWrite();
            return;
        }
        queuedText = "";
        const currentIsSaved = lastSavedText === Catalog.encodeState(settings);
        saveStatus = currentIsSaved ? "saved" : "error";
        message = currentIsSaved ? "" : "Could not save appearance: " + error;
    }

    // A fresh writer avoids FileView 0.2.1 caching failed bytes as a no-op on retry.
    // Serialize transactions and coalesce rapid changes to the latest requested state.
    Component {
        id: writeOperation
        FileView {
            property string contents
            path: root.statePath
            preload: false
            atomicWrites: true
            printErrors: false
            onSaved: root.finishWrite(this, true, "")
            onSaveFailed: error => root.finishWrite(this, false, FileViewError.toString(error))
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        atomicWrites: true
        printErrors: false

        onLoaded: {
            const decoded = Catalog.decodeState(stateFile.text());
            root.settings = decoded.settings;
            root.lastSavedText = decoded.status === "saved" ? Catalog.encodeState(decoded.settings) : "";
            root.saveStatus = decoded.status;
            root.message = decoded.message;
            root.writable = decoded.writable;
            root.ready = true;
        }
        onLoadFailed: error => {
            root.ready = true;
            root.writable = error === FileViewError.FileNotFound;
            root.saveStatus = root.writable ? "default" : "error";
            root.message = root.writable ? "" : "Cannot read appearance state: " + FileViewError.toString(error);
        }
    }
}
