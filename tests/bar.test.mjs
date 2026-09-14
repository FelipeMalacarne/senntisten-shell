import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = (name) => readFileSync(new URL(`../shell/desktop/${name}`, import.meta.url), "utf8");

test("native bar reserves only its top edge; preview never reserves space", () => {
    const bar = source("Bar.qml");
    assert.match(bar, /PanelWindow\s*\{/);
    assert.match(bar, /property bool previewMode:\s*false/);
    assert.match(bar, /top:\s*!root\.previewMode/);
    assert.match(bar, /bottom:\s*root\.previewMode/);
    assert.match(bar, /left:\s*true/);
    assert.match(bar, /right:\s*true/);
    assert.match(bar, /exclusiveZone:\s*root\.previewMode\s*\?\s*0\s*:\s*implicitHeight/);
    assert.match(bar, /WlrLayershell\.namespace:\s*"senntisten-bar"/);
    assert.match(bar, /WlrLayershell\.layer:\s*WlrLayer\.Top/);
    assert.match(bar, /WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None/);
    assert.match(bar, /signal launcherRequested/);
    assert.match(bar, /signal appearanceRequested/);
    assert.match(bar, /PopupWindow\s*\{/);
    assert.match(bar, /grabFocus:\s*true/);
});
