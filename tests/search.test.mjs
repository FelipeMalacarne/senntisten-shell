import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';

const sourcePath = fileURLToPath(new URL('../shell/lib/ApplicationSearch.js', import.meta.url));
function searchApi() {
  assert.ok(existsSync(sourcePath), 'The shared application search must exist');
  const source = readFileSync(sourcePath, 'utf8').replace(/^\.pragma library\s*\n/, '');
  const context = vm.createContext({});
  vm.runInContext(source, context, { filename: sourcePath });
  assert.equal(typeof context.search, 'function');
  return context;
}
const ids = results => Array.from(results, entry => entry.id);

test('name search is case-insensitive and ranks exact, prefix, then substring', () => {
  const entries = [
    { id: 'substring', name: 'My Terminal' },
    { id: 'prefix', name: 'Terminal Tools' },
    { id: 'other', name: 'Browser' },
    { id: 'exact', name: 'Terminal' },
  ];
  const result = searchApi().search(entries, '  tERMINal  ');
  assert.deepEqual(ids(result), ['exact', 'prefix', 'substring']);
  assert.equal(result[0], entries[3], 'Return native entry references, not cloned launch commands');
  assert.deepEqual(entries.map(entry => entry.id), ['substring', 'prefix', 'other', 'exact']);
});

test('generic names and keywords match below application names with all query words required', () => {
  const entries = [
    { id: 'keyword', name: 'Alpha', keywords: ['WEB', 'internet'] },
    { id: 'generic', name: 'Beta', genericName: 'Web Browser' },
    { id: 'name', name: 'Web' },
    { id: 'partial', name: 'Browser' },
  ];
  const api = searchApi();
  assert.deepEqual(ids(api.search(entries, 'web')), ['name', 'generic', 'keyword']);
  assert.deepEqual(ids(api.search(entries, ' alpha   InTERnet ')), ['keyword']);
  assert.deepEqual(ids(api.search(entries, 'browser web')), ['generic']);
  assert.deepEqual(ids(api.search(entries, 'web absent')), []);
  assert.deepEqual(ids(api.search(entries, '$(touch /tmp/not-a-command)')), []);
});

test('equal scores are deterministic by normalized name then desktop id, including empty searches', () => {
  const entries = [
    { id: 'z', name: 'Terminal' },
    { id: 'a', name: 'terminal' },
    { id: 'beta', name: 'Beta', keywords: ['editor'] },
    { id: 'alpha', name: 'Alpha', keywords: ['editor'] },
  ];
  const api = searchApi();
  for (const order of [entries, [...entries].reverse()]) {
    assert.deepEqual(ids(api.search(order, '')), ['alpha', 'beta', 'a', 'z']);
    assert.deepEqual(ids(api.search(order, 'terminal')), ['a', 'z']);
    assert.deepEqual(ids(api.search(order, 'EDITOR')), ['alpha', 'beta']);
  }
});

test('results are bounded with explicit zero and a hard ceiling for large limits', () => {
  const entries = Array.from({ length: 100 }, (_, i) => ({ id: String(i), name: `App ${String(i).padStart(3, '0')}` }));
  const api = searchApi();
  assert.equal(api.search(entries, '').length, 8);
  assert.deepEqual(ids(api.search(entries, 'app', 3)), ['0', '1', '2']);
  for (const limit of [0, -2]) assert.equal(api.search(entries, '', limit).length, 0);
  assert.equal(api.search(entries, '', 2.7).length, 2);
  assert.equal(api.search(entries, '', 1000).length, 50);
  for (const limit of [NaN, Infinity, '100']) assert.equal(api.search(entries, '', limit).length, 8);
});

test('missing optional metadata is safe and invisible or nameless entries never appear', () => {
  const entries = [null, undefined, {}, { id: 'blank', name: ' ' },
    { id: 'private', name: 'Secret', noDisplay: true },
    { id: 'normal', name: 'Éditeur' }];
  const api = searchApi();
  assert.deepEqual(ids(api.search(entries, null)), ['normal']);
  assert.deepEqual(ids(api.search(entries, 'ÉDIT')), ['normal']);
  for (const source of [null, undefined, []]) assert.deepEqual(ids(api.search(source, 'anything')), []);
});
