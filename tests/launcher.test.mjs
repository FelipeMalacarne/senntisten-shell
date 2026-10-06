import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const projectLauncher = fileURLToPath(new URL("../bin/senntisten-shell", import.meta.url));

function fixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), "senntisten launcher "));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const repo = path.join(root, "repo with spaces");
  const home = path.join(root, "home");
  const source = path.join(repo, "shell");
  const launcher = path.join(repo, "bin", "senntisten-shell");
  const quickshell = path.join(root, "fake quickshell");
  mkdirSync(path.dirname(launcher), { recursive: true });
  mkdirSync(source, { recursive: true });
  mkdirSync(home);
  writeFileSync(path.join(source, "shell.qml"), "// Launcher fixture; never executed as QML.\n");
  writeFileSync(path.join(source, "PlaygroundRoot.qml"), "// Alternate entrypoint fixture.\n");
  if (existsSync(projectLauncher)) copyFileSync(projectLauncher, launcher);
  // Observe the external process boundary without opening a real desktop window.
  writeFileSync(quickshell, `#!${process.execPath}\nconst keys = ["SENNTISTEN_STATE_DIR", "SENNTISTEN_MODE", "SENNTISTEN_PREVIEW", "SENNTISTEN_DISTRO_ID", "QT_QUICK_CONTROLS_STYLE", "QT_QUICK_BACKEND", "QSG_RHI_BACKEND"]; const env = Object.fromEntries(keys.filter(key => process.env[key] !== undefined).map(key => [key, process.env[key]])); console.log(JSON.stringify({ args: process.argv.slice(2), env }));\nprocess.exit(Number(process.env.FAKE_EXIT ?? 0));\n`, { mode: 0o755 });
  const env = { ...process.env };
  for (const key of Object.keys(env)) {
    if (key.startsWith("SENNTISTEN_") || key.startsWith("QT_") || key.startsWith("QSG_")) delete env[key];
  }
  Object.assign(env, {
    HOME: home,
    XDG_STATE_HOME: path.join(home, "state"),
    XDG_CONFIG_HOME: path.join(home, "config"),
    XDG_CACHE_HOME: path.join(home, "cache"),
    XDG_DATA_HOME: path.join(home, "data"),
    XDG_RUNTIME_DIR: path.join(root, "runtime"),
    SENNTISTEN_QUICKSHELL: quickshell,
  });
  return {
    root, repo, home, source, launcher, quickshell, env,
    run(args = [], overrides = {}) {
      const launchEnv = { ...env, ...overrides };
      for (const [key, value] of Object.entries(launchEnv)) if (value === undefined) delete launchEnv[key];
      return spawnSync(launcher, args, { cwd: home, env: launchEnv, encoding: "utf8" });
    },
  };
}

function launched(result) {
  assert.equal(result.status, 0, result.error?.message ?? result.stderr);
  assert.equal(result.stderr, "");
  return JSON.parse(result.stdout);
}

test("process-boundary diagnostics omit unrelated environment values", (t) => {
  const f = fixture(t);
  const result = launched(f.run([], { UNRELATED_PRIVATE_VALUE: "fixture-only" }));
  assert.equal(result.env.UNRELATED_PRIVATE_VALUE, undefined);
});

test("defaults to a real desktop and gives the playground a separate configuration identity", (t) => {
  const f = fixture(t);
  const desktop = launched(f.run());
  assert.equal(desktop.env.SENNTISTEN_MODE, "desktop");
  assert.equal(desktop.env.SENNTISTEN_PREVIEW, "0");
  const playground = launched(f.run(["--playground", "--no-color"]));
  assert.equal(playground.env.SENNTISTEN_MODE, "playground");
  assert.deepEqual(playground.args, ["--path", path.join(f.source, "PlaygroundRoot.qml"), "--no-duplicate", "--no-color"]);
  const preview = launched(f.run(["--preview"]));
  assert.equal(preview.env.SENNTISTEN_MODE, "desktop");
  assert.equal(preview.env.SENNTISTEN_PREVIEW, "1");
  assert.deepEqual(preview.args, ["--path", f.source, "--no-duplicate"]);
});

test("mode help works without Quickshell or filesystem writes", (t) => {
  const f = fixture(t);
  const result = f.run(["--help"], { SENNTISTEN_QUICKSHELL: "/not/installed" });
  assert.equal(result.status, 0);
  assert.match(result.stdout, /Senntisten/);
  assert.match(result.stdout, /--preview/);
  assert.match(result.stdout, /--playground/);
  assert.deepEqual(readdirSync(f.home), []);
});

test("rejects invalid or conflicting mode selections without startup writes", (t) => {
  const f = fixture(t);
  for (const [args, env] of [
    [[], { SENNTISTEN_MODE: "unknown" }],
    [[], { SENNTISTEN_MODE: "" }],
    [[], { SENNTISTEN_PREVIEW: "yes" }],
    [["--desktop", "--playground"], {}],
    [["--preview", "--desktop"], {}],
  ]) {
    const result = f.run(args, env);
    assert.equal(result.status, 2);
    assert.match(result.stderr, /mode|preview/i);
    assert.deepEqual(readdirSync(f.home), []);
  }
});

test("adds duplicate protection without daemonizing", (t) => {
  const f = fixture(t);
  assert.deepEqual(launched(f.run()).args, ["--path", f.source, "--no-duplicate"]);
});

test("distribution branding has an explicit default and preserves an override", (t) => {
  const f = fixture(t);
  assert.equal(launched(f.run()).env.SENNTISTEN_DISTRO_ID, "nixos");
  assert.equal(launched(f.run([], { SENNTISTEN_DISTRO_ID: "other" })).env.SENNTISTEN_DISTRO_ID, "other");
});

test("forwards arguments literally without shell evaluation", (t) => {
  const f = fixture(t);
  const marker = path.join(f.home, "must not exist");
  const args = ["--no-color", "--log-rules", `*.debug=false; touch '${marker}'; $(touch '${marker}')`, "", "a b", '"quoted"', "*"];
  assert.deepEqual(launched(f.run(args)).args, ["--path", f.source, "--no-duplicate", ...args]);
  assert.equal(existsSync(marker), false);
});

test("uses an explicit source directory with spaces", (t) => {
  const f = fixture(t);
  const source = path.join(f.root, "packaged source");
  mkdirSync(source);
  writeFileSync(path.join(source, "shell.qml"), "// Fixture\n");
  assert.deepEqual(launched(f.run([], { SENNTISTEN_SOURCE_DIR: source })).args.slice(0, 2), ["--path", source]);
});

test("requires a readable shell.qml before launch", (t) => {
  const f = fixture(t);
  rmSync(path.join(f.source, "shell.qml"));
  const result = f.run();
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /senntisten-shell:.*shell\.qml/);
  assert.equal(result.stdout, "");
  assert.deepEqual(readdirSync(f.home), []);
});

test("forces Basic controls while preserving rendering choices", (t) => {
  const f = fixture(t);
  const normal = launched(f.run()).env;
  assert.equal(normal.QT_QUICK_CONTROLS_STYLE, "Basic");
  assert.equal(normal.QT_QUICK_BACKEND, undefined);
  assert.equal(normal.QSG_RHI_BACKEND, undefined);
  const custom = launched(f.run([], {
    QT_QUICK_CONTROLS_STYLE: "org.kde.desktop",
    QT_QUICK_BACKEND: "rhi",
    QSG_RHI_BACKEND: "vulkan",
  })).env;
  assert.equal(custom.QT_QUICK_CONTROLS_STYLE, "Basic");
  assert.equal(custom.QT_QUICK_BACKEND, "rhi");
  assert.equal(custom.QSG_RHI_BACKEND, "vulkan");
});

test("reports a missing Quickshell executable without startup writes", (t) => {
  const f = fixture(t);
  const result = f.run([], { SENNTISTEN_QUICKSHELL: path.join(f.root, "not installed") });
  assert.equal(result.status, 127);
  assert.match(result.stderr, /senntisten-shell:.*Quickshell.*not found/);
  assert.match(result.stderr, /nix develop/);
  assert.equal(result.stdout, "");
  assert.deepEqual(readdirSync(f.home), []);
});

test("creates private XDG state directories but leaves appearance to QML", (t) => {
  const f = fixture(t);
  const state = path.join(f.env.XDG_STATE_HOME, "senntisten-shell");
  const homeMode = statSync(f.home).mode;
  assert.equal(launched(f.run()).env.SENNTISTEN_STATE_DIR, state);
  assert.equal(statSync(state).mode & 0o777, 0o700);
  assert.equal(statSync(f.env.XDG_STATE_HOME).mode & 0o777, 0o700);
  assert.equal(statSync(f.home).mode, homeMode);
  assert.deepEqual(readdirSync(state), []);
  assert.deepEqual(readdirSync(f.home), ["state"]);
  assert.equal(existsSync(f.env.XDG_RUNTIME_DIR), false);
  assert.deepEqual(readdirSync(f.repo).sort(), ["bin", "shell"]);
});

test("falls back to HOME when XDG_STATE_HOME is unset, empty, or relative", (t) => {
  const f = fixture(t);
  const state = path.join(f.home, ".local", "state", "senntisten-shell");
  for (const xdg of [undefined, "", "relative state"]) {
    assert.equal(launched(f.run([], { XDG_STATE_HOME: xdg })).env.SENNTISTEN_STATE_DIR, state);
    assert.equal(statSync(state).mode & 0o777, 0o700);
  }
  assert.deepEqual(readdirSync(f.home), [".local"]);
});

test("uses an isolated absolute state override without touching existing modes or data", (t) => {
  const f = fixture(t);
  const state = path.join(f.root, "custom state", "Senntisten");
  const overrides = { SENNTISTEN_STATE_DIR: state };
  assert.equal(launched(f.run([], overrides)).env.SENNTISTEN_STATE_DIR, state);
  assert.equal(statSync(state).mode & 0o777, 0o700);
  assert.deepEqual(readdirSync(f.home), []);
  chmodSync(state, 0o750);
  const appearance = path.join(state, "appearance.json");
  const contents = '{"schemaVersion":999,"untouched":true}\n';
  writeFileSync(appearance, contents);
  chmodSync(appearance, 0o640); // Establish the fixture independent of the test runner umask.
  launched(f.run([], overrides));
  assert.equal(statSync(state).mode & 0o777, 0o750);
  assert.equal(statSync(appearance).mode & 0o777, 0o640);
  assert.equal(readFileSync(appearance, "utf8"), contents);
  assert.deepEqual(readdirSync(state), ["appearance.json"]);
});

test("rejects relative or empty explicit state paths before creating anything", (t) => {
  const f = fixture(t);
  for (const state of ["relative state", ""]) {
    const result = f.run([], { SENNTISTEN_STATE_DIR: state });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /senntisten-shell:.*SENNTISTEN_STATE_DIR.*absolute/);
    assert.equal(result.stdout, "");
    assert.deepEqual(readdirSync(f.home), []);
  }
});

test("requires an absolute HOME only when needed for fallback", (t) => {
  const f = fixture(t);
  for (const home of ["relative home", "", undefined]) {
    const result = f.run([], { HOME: home, XDG_STATE_HOME: undefined });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /senntisten-shell:.*HOME.*absolute/);
    assert.equal(result.stdout, "");
    assert.deepEqual(readdirSync(f.home), []);
  }
  const state = path.join(f.root, "no home required");
  assert.equal(launched(f.run([], { HOME: undefined, XDG_STATE_HOME: undefined, SENNTISTEN_STATE_DIR: state })).env.SENNTISTEN_STATE_DIR, state);
});

test("rejects an existing state directory that is not writable", { skip: process.getuid?.() === 0 }, (t) => {
  const f = fixture(t);
  const state = path.join(f.root, "read only state");
  mkdirSync(state);
  chmodSync(state, 0o500);
  let result;
  let mode;
  try {
    result = f.run([], { SENNTISTEN_STATE_DIR: state });
    mode = statSync(state).mode & 0o777;
  } finally {
    chmodSync(state, 0o700);
  }
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /senntisten-shell:.*state directory.*writable/);
  assert.equal(result.stdout, "");
  assert.equal(mode, 0o500);
  assert.deepEqual(readdirSync(f.home), []);
});

test("reports state directory creation errors without touching other paths", (t) => {
  const f = fixture(t);
  const obstruction = path.join(f.root, "not a directory");
  writeFileSync(obstruction, "leave me alone");
  const result = f.run([], { SENNTISTEN_STATE_DIR: path.join(obstruction, "state") });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /senntisten-shell:.*cannot create state directory/);
  assert.equal(result.stdout, "");
  assert.equal(readFileSync(obstruction, "utf8"), "leave me alone");
  assert.deepEqual(readdirSync(f.home), []);
});

test("rejects a directory as the Quickshell executable before startup writes", (t) => {
  const f = fixture(t);
  const result = f.run([], { SENNTISTEN_QUICKSHELL: f.root });
  assert.equal(result.status, 127);
  assert.match(result.stderr, /senntisten-shell:.*Quickshell.*not found/);
  assert.equal(result.stdout, "");
  assert.deepEqual(readdirSync(f.home), []);
});

test("normalizes relative source paths without CDPATH contaminating --path", (t) => {
  const f = fixture(t);
  const source = path.join(f.home, "relative source");
  mkdirSync(source);
  copyFileSync(path.join(f.source, "shell.qml"), path.join(source, "shell.qml"));
  const result = launched(f.run([], { SENNTISTEN_SOURCE_DIR: "relative source", CDPATH: f.home }));
  assert.deepEqual(result.args.slice(0, 2), ["--path", source]);
});

test("reports a nonexistent source directory before creating state", (t) => {
  const f = fixture(t);
  const result = f.run([], { SENNTISTEN_SOURCE_DIR: path.join(f.root, "missing source") });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /senntisten-shell:.*cannot read source directory/);
  assert.equal(result.stdout, "");
  assert.deepEqual(readdirSync(f.home), []);
});

test("finds Quickshell on PATH when no executable override is set", (t) => {
  const f = fixture(t);
  copyFileSync(f.quickshell, path.join(f.root, "quickshell"));
  const result = launched(f.run([], { SENNTISTEN_QUICKSHELL: undefined, PATH: `${f.root}:${f.env.PATH}` }));
  assert.deepEqual(result.args, ["--path", f.source, "--no-duplicate"]);
});

test("preserves Quickshell's exit status", (t) => {
  const f = fixture(t);
  const result = f.run([], { FAKE_EXIT: "23" });
  assert.equal(result.status, 23);
  assert.equal(result.stderr, "");
});

test("restricts new state permissions even under a permissive caller umask", (t) => {
  const f = fixture(t);
  const result = spawnSync("bash", ["-c", 'umask 022; exec "$@"', "launcher-test", f.launcher], {
    cwd: f.home, env: f.env, encoding: "utf8",
  });
  const state = launched(result).env.SENNTISTEN_STATE_DIR;
  assert.equal(statSync(state).mode & 0o777, 0o700);
  assert.equal(statSync(path.dirname(state)).mode & 0o777, 0o700);
});

test("launches the adjacent shell from an unrelated working directory", (t) => {
  const f = fixture(t);
  const result = launched(f.run());
  assert.deepEqual(result.args.slice(0, 2), ["--path", f.source]);
});
