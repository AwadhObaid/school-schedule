const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('web manifest and Capacitor configuration are valid JSON', () => {
  JSON.parse(fs.readFileSync(path.join(root, 'www/manifest.json'), 'utf8'));
  JSON.parse(fs.readFileSync(path.join(root, 'capacitor.config.json'), 'utf8'));
  JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
});

test('inline application scripts and service worker compile', () => {
  const html = fs.readFileSync(path.join(root, 'www/index.html'), 'utf8');
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)]
    .map(match => match[1])
    .filter(Boolean);
  assert.ok(scripts.length > 0, 'No inline application script found');
  scripts.forEach(script => new Function(script));
  new Function(fs.readFileSync(path.join(root, 'www/sw.js'), 'utf8'));
});

test('static element IDs are unique and JavaScript references existing elements', () => {
  const html = fs.readFileSync(path.join(root, 'www/index.html'), 'utf8');
  const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map(match => match[1]);
  assert.equal(new Set(ids).size, ids.length, 'Duplicate HTML id detected');
  const referencedIds = [...html.matchAll(/getElementById\(['"]([^'"]+)['"]\)/g)].map(match => match[1]);
  referencedIds.forEach(id => assert.ok(ids.includes(id), `Missing HTML element #${id}`));
});

test('APK downloads are explicitly excluded from service-worker caching', () => {
  const serviceWorker = fs.readFileSync(path.join(root, 'www/sw.js'), 'utf8');
  assert.match(serviceWorker, /app\.apk/);
  assert.match(serviceWorker, /return;/);
});

test('native-only UI rules and backup controls are present', () => {
  const html = fs.readFileSync(path.join(root, 'www/index.html'), 'utf8');
  assert.match(html, /class="controls-grid web-only"/);
  assert.match(html, /id="exportBackupBtn"/);
  assert.match(html, /id="importBackupInput"/);
  assert.match(html, /id="notificationButton"/);
});

test('native notifications use persistent weekly rules instead of a 14-day window', () => {
  const html = fs.readFileSync(path.join(root, 'www/index.html'), 'utf8');
  assert.doesNotMatch(html, /NOTIF_DAYS_AHEAD/);
  assert.match(html, /weekday: dayIndex \+ 1/);
  assert.match(html, /allowWhileIdle: true/);
  assert.match(html, /state\.notificationsEnabled/);
});

test('native backup plugins are registered in the Android project', () => {
  const settings = fs.readFileSync(path.join(root, 'android/capacitor.settings.gradle'), 'utf8');
  assert.match(settings, /capacitor-filesystem/);
  assert.match(settings, /capacitor-share/);
});

test('Android notifications use a dedicated monochrome status icon', () => {
  const config = JSON.parse(fs.readFileSync(path.join(root, 'capacitor.config.json'), 'utf8'));
  assert.equal(config.plugins.LocalNotifications.smallIcon, 'ic_stat_schedule');
  assert.equal(config.plugins.LocalNotifications.iconColor, '#17365D');
  assert.equal(fs.existsSync(path.join(root, 'android/app/src/main/res/drawable/ic_stat_schedule.xml')), true);
});
