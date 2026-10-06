import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';

const sourcePath = fileURLToPath(new URL('../shell/lib/ThemeCatalog.js', import.meta.url));
function catalog() {
  assert.ok(existsSync(sourcePath), 'The shared theme catalog must exist');
  const source = readFileSync(sourcePath, 'utf8').replace(/^\.pragma library\s*\n/, '');
  const context = vm.createContext({});
  vm.runInContext(source, context, { filename: sourcePath });
  return context;
}
const plain = value => JSON.parse(JSON.stringify(value));

test('appearance selection round-trips through versioned JSON', () => {
  const api = catalog();
  assert.equal(typeof api.encodeState, 'function', 'State serialization must exist');
  for (const theme of ['catppuccin-mocha', 'gruvbox']) {
    for (const reducedMotion of [false, true]) {
      const settings = { theme, reducedMotion };
      const encoded = api.encodeState(settings);
      assert.deepEqual(JSON.parse(encoded), { schemaVersion: 1, ...settings });
      const decoded = plain(api.decodeState(encoded));
      assert.deepEqual(decoded.settings, settings);
      assert.equal(decoded.status, 'saved');
      assert.equal(decoded.writable, true);
    }
  }
});

test('invalid or unknown saved settings recover to defaults with a visible message', () => {
  const api = catalog();
  for (const value of ['broken {', 'null', '[]', '42', '{}',
    JSON.stringify({ schemaVersion: 1, theme: '__proto__', reducedMotion: false }),
    JSON.stringify({ schemaVersion: 1, theme: 'gruvbox', reducedMotion: 'yes' })]) {
    let result;
    assert.doesNotThrow(() => { result = plain(api.decodeState(value)); }, value);
    assert.deepEqual(result.settings, { theme: 'catppuccin-mocha', reducedMotion: false });
    assert.equal(result.status, 'recovered');
    assert.equal(result.writable, true);
    assert.ok(result.message.length > 0);
  }
});

test('newer schema versions are read-only and must not be silently downgraded', () => {
  const api = catalog();
  const result = plain(api.decodeState(JSON.stringify({ schemaVersion: 2, theme: 'gruvbox', reducedMotion: true })));
  assert.equal(result.writable, false);
  assert.equal(result.status, 'blocked');
  assert.match(result.message, /newer|unsupported/i);
});

test('invalid settings cannot be serialized into persistent state', () => {
  const api = catalog();
  for (const settings of [null, {}, { theme: 'other', reducedMotion: false },
    { theme: '__proto__', reducedMotion: false }, { theme: 'gruvbox', reducedMotion: 'false' }]) {
    assert.throws(() => api.encodeState(settings), /invalid appearance/i);
  }
});

test('normal text and primary controls meet readable contrast targets', () => {
  const api = catalog();
  const luminance = hex => {
    const values = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722;
  };
  const contrast = (a, b) => {
    const first = luminance(a), second = luminance(b);
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
  };
  for (const { id } of api.listThemes()) {
    const colors = api.paletteFor(id);
    for (const text of ['text', 'muted']) {
      for (const surface of ['background', 'surface', 'elevated']) {
        assert.ok(contrast(colors[text], colors[surface]) >= 4.5, `${id}: ${text} on ${surface}`);
      }
    }
    assert.ok(contrast(colors.accentText, colors.accent) >= 4.5, `${id}: primary button`);
  }
});

const tokenNames = [
  'background', 'surface', 'elevated', 'overlay', 'border', 'text', 'muted',
  'subtle', 'accent', 'accentText', 'success', 'warning', 'error'
];

test('both built-in presets provide the same complete semantic color contract', () => {
  const api = catalog();
  const presets = plain(api.listThemes());
  assert.deepEqual(presets.map(p => p.id), ['catppuccin-mocha', 'gruvbox']);
  assert.deepEqual(presets.map(p => p.name), ['Catppuccin Mocha', 'Gruvbox']);
  for (const preset of presets) {
    const palette = plain(api.paletteFor(preset.id));
    assert.deepEqual(Object.keys(palette).sort(), [...tokenNames].sort());
    for (const color of Object.values(palette)) assert.match(color, /^#[a-fA-F0-9]{6}$/);
  }
  assert.notDeepEqual(plain(api.paletteFor(presets[0].id)), plain(api.paletteFor(presets[1].id)));
});

test('an existing empty state file is recovered visibly', () => {
  const api = catalog();
  assert.equal(typeof api.decodeState, 'function', 'The appearance-state decoder must exist');
  for (const text of ['', '  \n\t']) assert.deepEqual(plain(api.decodeState(text)), {
    settings: { theme: 'catppuccin-mocha', reducedMotion: false },
    status: 'recovered', message: 'Invalid appearance state. Defaults are in use.', writable: true
  });
});

test('pressed primary controls keep readable foreground contrast', () => {
  const api = catalog();
  const luminance = hex => {
    const values = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722;
  };
  const contrast = (a, b) => {
    const first = luminance(a), second = luminance(b);
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
  };
  for (const { id } of api.listThemes()) {
    const colors = api.paletteFor(id);
    assert.ok(contrast(colors.text, colors.overlay) >= 4.5, `${id}: pressed primary control`);
  }
});
