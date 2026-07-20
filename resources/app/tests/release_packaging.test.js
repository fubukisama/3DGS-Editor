const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const appRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(appRoot, "..", "..");

test("desktop toolchain uses the supported Electron 43 release", () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(appRoot, "package.json"), "utf8"));
  assert.equal(packageJson.devDependencies.electron, "43.1.1");
  assert.equal(packageJson.devDependencies["@electron/packager"], "20.0.3");
  assert.equal(packageJson.engines.node, ">=22.12.0");
  assert.equal(packageJson.scripts.test, "node --test tests/*.test.js");
});

test("release packaging never installs into the live Electron app", () => {
  const script = fs.readFileSync(path.join(repoRoot, "scripts", "package_editor_release.ps1"), "utf8");
  assert.match(script, /desktop-package-/);
  assert.match(script, /Copy-TreeFiltered \$DesktopApp \$stagingApp/);
  assert.match(script, /npm ci --no-audit --no-fund/);
  assert.match(script, /@\("node_modules", "dist"/);
  assert.doesNotMatch(script, /Push-Location \$DesktopApp[\s\S]{0,160}npm (?:install|ci)/);
});
