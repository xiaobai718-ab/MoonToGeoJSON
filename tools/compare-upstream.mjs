// Compare MoonBit output with the upstream Vitest snapshots.
// Requires the ignored .upstream checkout at @tmcw/togeojson v7.1.3.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const snapshots = fs.readFileSync(path.join(root, '.upstream/lib/__snapshots__/index.test.ts.snap'), 'utf8');
const fixtureDir = path.join(root, '.upstream/test/data');
const binary = process.platform === 'win32' ? 'convert.exe' : 'convert';
const converter = path.join(root, '_build/native/debug/build/cmd/convert', binary);
const pattern = /exports\[`toGeoJSON > ([^`]+) ([123])`\] = `\r?\n([\s\S]*?)\r?\n`;/g;
const expected = new Map();
function parseSnapshot(raw) {
  let result = '';
  let quoted = false;
  let escaped = false;
  for (let i = 0; i < raw.length; i++) {
    const char = raw[i];
    if (char === '\\' && !escaped) {
      escaped = true;
      result += char;
      continue;
    }
    if (char === '"' && !escaped) quoted = !quoted;
    if (char === '\r' && raw[i + 1] === '\n') continue;
    result += char === '\n' && quoted ? '\\n' : char;
    escaped = false;
  }
  return vm.runInNewContext('(' + result + ')');
}
for (const match of snapshots.matchAll(pattern)) {
  if (match[1].match(/\.(kml|gpx|tcx)$/)) {
    try {
      expected.set(`${match[1]}#${match[2]}`, parseSnapshot(match[3]));
    } catch (error) {
      console.error('Snapshot parse failed:', match[1], error.message);
      process.exit(2);
    }
  }
}

function differences(left, right, location = '$', output = []) {
  if (output.length >= 8) return output;
  if (left === right) return output;
  if (left && right && typeof left === 'object' && typeof right === 'object') {
    const keys = new Set([...Object.keys(left), ...Object.keys(right)]);
    for (const key of keys) differences(left[key], right[key], `${location}.${key}`, output);
  } else {
    output.push(`${location}: expected ${JSON.stringify(left)}; got ${JSON.stringify(right)}`);
  }
  return output;
}

let matches = 0;
const failures = [];
for (const name of fs.readdirSync(fixtureDir).filter(file => /\.(kml|gpx|tcx)$/.test(file)).sort()) {
  const cases = path.extname(name) === '.kml'
    ? [['1', 'kml'], ['2', 'kml-folders'], ['3', 'kml-folders-skip']]
    : [['1', path.extname(name).slice(1)]];
  for (const [index, kind] of cases) {
    const oracle = expected.get(`${name}#${index}`);
    if (!oracle) {
      failures.push(`${name}#${index}: no snapshot`);
      continue;
    }
    let actual;
    try {
      const raw = execFileSync(converter, [kind, path.join(fixtureDir, name)], { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });
      actual = JSON.parse(raw);
    } catch (error) {
      failures.push(`${name}#${index}: converter failed: ${error.message}`);
      continue;
    }
    const diff = differences(oracle, actual);
    if (diff.length) failures.push(`${name}#${index}:\n  ${diff.join('\n  ')}`);
    else matches++;
  }
}

console.log(`${matches}/${expected.size} upstream GeoJSON snapshots match`);
for (const failure of failures) console.log(failure);
if (failures.length) process.exitCode = 1;
