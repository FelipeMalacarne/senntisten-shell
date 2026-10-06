import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const launcher = fileURLToPath(new URL("../bin/senntisten-shell", import.meta.url));
const desktop = {
  mode: "desktop", ready: true, preview: false, theme: "catppuccin-mocha",
  saveStatus: "default", message: "", writable: true, screenCount: 1,
  targetScreen: "fixture", launcherOpen: false, dashboardOpen: false, appearanceOpen: false,
};

function fixture(t) {
  const root = realpathSync(mkdtempSync(path.join(tmpdir(), "senntisten commands ")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const source = path.join(root, 'source "with" spaces; $(false)');
  mkdirSync(source);
  writeFileSync(path.join(source, "shell.qml"), "// Never run by command dispatch.\n");
  const recorder = path.join(root, "calls.jsonl");
  const quickshell = path.join(root, "fake quickshell");
  writeFileSync(quickshell, `#!${process.execPath}
import { appendFileSync } from "node:fs";
const args = process.argv.slice(2);
appendFileSync(process.env.RECORDER, JSON.stringify(args) + "\\n");
if (args[0] === "list") {
  process.stdout.write(process.env.INSTANCES);
  process.exit(Number(process.env.LIST_EXIT ?? 0));
}
if (args[0] === "ipc") {
  const method = args[args.indexOf("call") + 2];
  process.stdout.write(method === "status" ? process.env.STATUS : process.env.REPLY);
  process.exit(Number(method === "status" ? process.env.STATUS_EXIT ?? 0 : process.env.IPC_EXIT ?? 0));
}
process.stderr.write("Unexpected startup instead of dispatch\\n");
process.exit(90);
`, { mode: 0o755 });
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (/^(SENNTISTEN_|QT_|QSG_|QS_)/.test(key)) delete env[key];
  }
  Object.assign(env, {
    HOME: path.join(root, "uncreated home"),
    XDG_STATE_HOME: path.join(root, "uncreated state"),
    XDG_RUNTIME_DIR: path.join(root, "uncreated runtime"),
    SENNTISTEN_STATE_DIR: path.join(root, "uncreated override"),
    SENNTISTEN_SOURCE_DIR: source, SENNTISTEN_QUICKSHELL: quickshell,
    RECORDER: recorder, STATUS: JSON.stringify(desktop), REPLY: "true\n",
    INSTANCES: JSON.stringify([{ pid: 123, config_path: path.join(source, "shell.qml") }]),
  });
  return {
    root, source, env,
    run(args, overrides = {}) {
      const result = spawnSync(launcher, args, { env: { ...env, ...overrides }, encoding: "utf8" });
      for (const key of ["HOME", "XDG_STATE_HOME", "XDG_RUNTIME_DIR", "SENNTISTEN_STATE_DIR"])
        assert.equal(existsSync(env[key]), false, `Dispatch wrote ${key}`);
      return result;
    },
    calls() { return existsSync(recorder) ? readFileSync(recorder, "utf8").trim().split("\n").map(JSON.parse) : []; },
  };
}

function rejected(result, pattern) {
  assert.notEqual(result.status, 0, result.stdout);
  assert.match(result.stderr, /senntisten-shell:/);
  assert.match(result.stderr, pattern);
}

test("dispatches each supported toggle to a verified PID without starting or writing state", (t) => {
  const f = fixture(t);
  for (const action of ["launcher", "dashboard", "settings"]) {
    const result = f.run([action], { SENNTISTEN_STATE_DIR: "invalid but irrelevant" });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(f.calls().at(-1), ["ipc", "--pid", "123", "call", "senntisten", action]);
  }
  assert.equal(f.calls().filter(args => args[0] === "list").length, 3);
  assert.equal(f.calls().filter(args => args.includes("status")).length, 3);
});

test("default selection uses only the exact config identity, never list order", (t) => {
  const f = fixture(t);
  const entries = [
    { pid: 7, config_path: path.join(f.root, "older-package/shell.qml") },
    { pid: 123, config_path: path.join(f.source, "shell.qml") },
    { pid: 999, config_path: path.join(f.source, "PlaygroundRoot.qml") },
  ];
  for (const instances of [entries, [...entries].reverse()]) {
    const result = f.run(["launcher"], { INSTANCES: JSON.stringify(instances) });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(f.calls().at(-1), ["ipc", "--pid", "123", "call", "senntisten", "launcher"]);
  }
});

test("an explicit PID can target another build or preview without requiring the current source", (t) => {
  const f = fixture(t);
  const result = f.run(["dashboard", "--pid", "456"], {
    SENNTISTEN_SOURCE_DIR: path.join(f.root, "missing current source"),
    INSTANCES: JSON.stringify([{ pid: 456, config_path: path.join(f.root, "old build/shell.qml") }]),
    STATUS: JSON.stringify({ ...desktop, preview: true }),
  });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.calls().at(-1), ["ipc", "--pid", "456", "call", "senntisten", "dashboard"]);
});

test("missing, foreign-identity, and ambiguous defaults fail without IPC or fallback startup", (t) => {
  const f = fixture(t);
  for (const [instances, pattern] of [
    [[], /no.*instance|not running/i],
    [[{ pid: 123, config_path: path.join(f.root, "foreign/shell.qml") }], /no.*instance|not running/i],
    [[{ pid: 123, config_path: path.join(f.source, "shell.qml") },
      { pid: 456, config_path: path.join(f.source, "shell.qml") }], /ambiguous|multiple/i],
  ]) {
    const before = f.calls().length;
    rejected(f.run(["settings"], { INSTANCES: JSON.stringify(instances) }), pattern);
    assert.equal(f.calls().length, before + 1);
    assert.equal(f.calls().at(-1)[0], "list");
  }
  rejected(f.run(["launcher", "--pid", "456"]), /456.*not.*running|no.*456/i);
  assert.equal(f.calls().at(-1)[0], "list");
  rejected(f.run(["launcher"], { INSTANCES: "No running instances.\n" }), /no.*instance|not running/i);
  assert.equal(f.calls().at(-1)[0], "list");
});

test("session and lock are actionable unconfigured errors, even with no Quickshell", (t) => {
  const f = fixture(t);
  for (const action of ["session", "lock"]) {
    rejected(f.run([action, "--pid", "123"], { SENNTISTEN_QUICKSHELL: "/not/installed" }), /unconfigured.*007|007.*unconfigured/i);
  }
  assert.deepEqual(f.calls(), []);
});

test("invalid actions, extra arguments, and malformed PIDs are rejected literally before any process", (t) => {
  const f = fixture(t);
  const marker = path.join(f.root, "injection marker");
  for (const args of [
    ["unknown"], ["quit"], ["launcher", "extra"], ["launcher", "--pid"],
    ["launcher", "--pid", "123", "--pid", "456"], ["launcher", "--newest"],
    ["launcher", "--pid=123"], ["--pid", "123"], ["session", "extra"],
    ...["", "0", "-1", "+1", "1.5", "01", " 123", "123\n", "2147483648", "999999999999999999999",
      `123; touch '${marker}'`, `$(touch '${marker}')`].map(pid => ["launcher", "--pid", pid]),
  ]) {
    const result = f.run(args);
    assert.equal(result.status, 2, `${JSON.stringify(args)}: ${result.stderr}`);
    assert.match(result.stderr, /action|argument|usage|pid/i);
  }
  assert.equal(existsSync(marker), false);
  assert.deepEqual(f.calls(), []);
});

test("foreign and wrong-mode controllers cannot be selected merely because the PID exists", (t) => {
  const f = fixture(t);
  for (const status of [{ ready: true, visible: true }, { mode: "playground", ready: true },
    { mode: "desktop", ready: true, screenCount: 1 }, { ...desktop, ready: false },
    { ...desktop, launcherOpen: "false" }]) {
    rejected(f.run(["launcher", "--pid", "123"], { STATUS: JSON.stringify(status) }), /desktop|controller|ready/i);
    assert.equal(f.calls().at(-1).at(-1), "status");
  }
});

test("unavailable screens and rejected or unexpected IPC success replies are errors", (t) => {
  const f = fixture(t);
  rejected(f.run(["settings"], { STATUS: JSON.stringify({ ...desktop, screenCount: 0 }) }), /screen/i);
  assert.equal(f.calls().at(-1).at(-1), "status");
  for (const reply of ["false\n", "", "null\n", "True\n", "true\nfalse\n", "success\n", " true\n"]) {
    rejected(f.run(["launcher"], { REPLY: reply }), /rejected|reply/i);
  }
  rejected(f.run(["launcher"], { IPC_EXIT: "23", REPLY: "true\n" }), /IPC|dispatch/i);
});

test("malformed discovery and status JSON fail closed without evaluating data", (t) => {
  const f = fixture(t);
  for (const instances of ["not json", "{}", "null", "[]\n[]", "[{}]", '[{"pid":"123","config_path":"x"}]']) {
    rejected(f.run(["launcher"], { INSTANCES: instances }), /instance|discovery|JSON/i);
    assert.equal(f.calls().at(-1)[0], "list");
  }
  rejected(f.run(["launcher"], { LIST_EXIT: "23" }), /list|discover/i);
  for (const status of ["false", "invalid JSON", JSON.stringify(desktop) + "\n{}", "[]"]) {
    rejected(f.run(["launcher"], { STATUS: status }), /status|controller|JSON/i);
    assert.equal(f.calls().at(-1).at(-1), "status");
  }
  rejected(f.run(["launcher"], { STATUS_EXIT: "23" }), /status|controller|IPC/i);
});

test("missing JSON parser is actionable and never falls back to unsafe discovery or startup", (t) => {
  const f = fixture(t);
  const bin = path.join(f.root, "only bash on PATH");
  mkdirSync(bin);
  const bash = spawnSync("bash", ["-c", "command -v bash"], { encoding: "utf8" });
  assert.equal(bash.status, 0, bash.stderr);
  symlinkSync(bash.stdout.trim(), path.join(bin, "bash"));
  const result = f.run(["launcher"], { PATH: bin });
  assert.equal(result.status, 127, result.stderr);
  assert.match(result.stderr, /jq.*required/);
  assert.deepEqual(f.calls(), []);
});
