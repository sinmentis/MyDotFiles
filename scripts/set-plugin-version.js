#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');

const version = process.argv[2];
const semver = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

if (!version || !semver.test(version)) {
  process.stderr.write('Usage: node scripts/set-plugin-version.js <semantic-version>\n');
  process.exit(2);
}

const root = path.resolve(__dirname, '..');
const pluginPath = path.join(root, 'plugin.json');
const marketplacePath = path.join(root, '.github', 'plugin', 'marketplace.json');

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

const plugin = readJson(pluginPath);
const marketplace = readJson(marketplacePath);
const marketplacePlugin = marketplace.plugins.find((entry) => entry.name === plugin.name);

if (!marketplacePlugin) {
  throw new Error(`Marketplace entry not found for ${plugin.name}`);
}

plugin.version = version;
marketplace.metadata = marketplace.metadata || {};
marketplace.metadata.version = version;
marketplacePlugin.version = version;

writeJson(pluginPath, plugin);
writeJson(marketplacePath, marketplace);
process.stdout.write(`Set ${plugin.name} and ${marketplace.name} to ${version}\n`);
