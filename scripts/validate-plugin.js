#!/usr/bin/env node

'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const pluginPath = path.join(root, 'plugin.json');
const marketplacePath = path.join(root, '.github', 'plugin', 'marketplace.json');
const skillsDir = path.join(root, 'skills');

function fail(message) {
  process.stderr.write(`Plugin validation failed: ${message}\n`);
  process.exit(1);
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`${path.relative(root, file)} is not valid JSON: ${error.message}`);
  }
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function frontmatterField(content, field) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return null;
  const line = match[1].split(/\r?\n/).find((entry) => entry.startsWith(`${field}:`));
  return line ? line.slice(field.length + 1).trim() : null;
}

const plugin = readJson(pluginPath);
const marketplace = readJson(marketplacePath);
const marketplacePlugin = marketplace.plugins?.find((entry) => entry.name === plugin.name);

assert(/^[a-z0-9-]+$/.test(plugin.name), 'plugin.json name must be kebab-case');
assert(plugin.version, 'plugin.json version is required');
assert(plugin.skills === 'skills/', 'plugin.json must point skills to skills/');
assert(marketplace.name === 'sinmentis-marketplace', 'unexpected marketplace name');
assert(marketplacePlugin, `marketplace entry missing for ${plugin.name}`);
assert(marketplacePlugin.source === '.', 'marketplace plugin source must be the repository root');
assert(marketplacePlugin.version === plugin.version, 'plugin and marketplace versions differ');
assert(marketplace.metadata?.version === plugin.version, 'marketplace metadata version differs');
assert(fs.existsSync(skillsDir), 'skills/ directory is missing');
assert(!fs.existsSync(path.join(root, 'Linux', 'copilot', 'skills')), 'legacy Linux/copilot/skills directory still exists');

const skillFolders = fs.readdirSync(skillsDir, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.'))
  .map((entry) => entry.name)
  .sort();

assert(skillFolders.length > 0, 'no skills found');

const skillNames = new Set();
for (const folder of skillFolders) {
  const skillFile = path.join(skillsDir, folder, 'SKILL.md');
  assert(fs.existsSync(skillFile), `${folder} is missing SKILL.md`);
  const content = fs.readFileSync(skillFile, 'utf8');
  const name = frontmatterField(content, 'name');
  const description = frontmatterField(content, 'description');
  assert(name === folder, `${folder}/SKILL.md name must equal its directory`);
  assert(description, `${folder}/SKILL.md description is required`);
  assert(!skillNames.has(name), `duplicate skill name: ${name}`);
  skillNames.add(name);
}

process.stdout.write(
  `Validated ${plugin.name}@${plugin.version}: ${skillFolders.length} skills (${skillFolders.join(', ')})\n`
);
