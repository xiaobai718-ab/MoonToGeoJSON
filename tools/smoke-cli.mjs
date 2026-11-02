import assert from 'node:assert/strict';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const moonRoot = process.env.MOONTOGEOJSON_MOON_ROOT || root;
const moon = process.platform === 'win32' ? 'moon.exe' : 'moon';

function run(args) {
  const result = spawnSync(moon, ['-C', moonRoot, 'run', 'cmd/convert', '--target', 'native', '--', ...args], {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024,
  });
  if (result.error) throw result.error;
  return result;
}

for (const [file, count, geometry] of [
  ['examples/places.kml', 2, 'Point'],
  ['examples/route.gpx', 2, 'LineString'],
  ['examples/activity.tcx', 1, 'LineString'],
]) {
  const result = run([file]);
  assert.equal(result.status, 0, `${file}: ${result.stderr}`);
  const output = JSON.parse(result.stdout);
  assert.equal(output.type, 'FeatureCollection');
  assert.equal(output.features.length, count);
  assert.equal(output.features[0].geometry.type, geometry);
}

const folders = run(['kml-folders', 'examples/places.kml']);
assert.equal(folders.status, 0, folders.stderr);
assert.equal(JSON.parse(folders.stdout).children[0].type, 'folder');

for (const [args, message] of [
  [['invalid', 'examples/route.gpx'], 'Unknown format'],
  [['gpx', 'examples/does-not-exist.gpx'], 'Could not read input file'],
  [['examples/unknown.xyz'], 'Cannot infer format'],
]) {
  const result = run(args);
  assert.notEqual(result.status, 0, `${args.join(' ')} unexpectedly succeeded`);
  assert.equal(result.stdout.trim(), '');
  assert.ok(result.stderr.includes(message), result.stderr);
}

console.log('CLI smoke tests passed (3 formats, KML folders, 3 error paths)');
