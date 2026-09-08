const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(require('node:path').join(__dirname, '../www/index.html'), 'utf8');
test('choosing a ringtone updates the open settings draft before save and survives reload', async () => {
  const start = html.indexOf("chooseRingtoneBtn.addEventListener('click'");
  const end = html.indexOf("ringtoneFileInput.addEventListener", start);
  let handler;
  let saved;
  const state = { ringtoneUri: 'old', ringtoneName: 'Old', notificationsEnabled: true };
  const draftState = { ...state };
  const context = {
    state, draftState, NATIVE_PLATFORM: true, ringtoneStatus: {}, console,
    chooseRingtoneBtn: { addEventListener: (_, callback) => { handler = callback; } },
    getScheduleAudio: () => ({ pickRingtone: async () => ({ uri: 'content://saved/new', name: 'New' }) }),
    setFieldStatus() {}, applyRingtoneUI() {},
    configureNativeRingtone: async () => {}, scheduleNativeNotifications: async () => {},
    saveState: () => { saved = JSON.stringify(state); }
  };
  vm.runInNewContext(html.slice(start, end), context);
  await handler();
  assert.equal(draftState.ringtoneUri, 'content://saved/new');
  assert.equal(JSON.parse(saved).ringtoneUri, draftState.ringtoneUri);
  assert.equal(JSON.parse(JSON.stringify(draftState)).ringtoneName, 'New');
});
