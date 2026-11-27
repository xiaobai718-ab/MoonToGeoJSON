import { execFileSync } from 'node:child_process';

const output = execFileSync('moon', ['version', '--all'], { encoding: 'utf8' });
const version = output.match(/^moonc v(\d+)\.(\d+)\.(\d+)(?:-rc(\d+))?(?=[+\s]|$)/m);
if (!version) {
  console.error('Could not determine moonc version');
  process.exit(1);
}

const [, major, minor, patch, rc] = version;
const meetsMinimum = Number(major) > 1 ||
  (Number(major) === 1 && (
    Number(minor) > 0 ||
    Number(patch) > 0 ||
    rc === undefined ||
    Number(rc) >= 1
  ));
if (!meetsMinimum) {
  console.error('moonc 1.0.0-rc1 or newer is required');
  process.exit(1);
}
console.log(`Accepted moonc ${major}.${minor}.${patch}${rc === undefined ? '' : `-rc${rc}`}`);
