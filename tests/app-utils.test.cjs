const test = require('node:test');
const assert = require('node:assert/strict');
const {
  escapeHtml,
  timeToMinutes,
  formatTime24,
  validateScheduleState,
  createBackupPayload,
  parseBackupText
} = require('../www/app-utils.js');

function validState() {
  return {
    ramadanMode: false,
    pin: '0000',
    soundEnabled: false,
    notificationsEnabled: true,
    weekdayMap: { 0: 'normal', 1: 'normal', 2: 'normal', 3: 'normal', 4: 'normal', 5: 'off', 6: 'off' },
    schedules: {
      normal: {
        name: 'الدوام العادي',
        periods: [
          { name: 'الحصة الثانية', start: '08:30', duration: 30 },
          { name: 'الحصة الأولى', start: '08:00', duration: 30 }
        ]
      }
    }
  };
}

test('time helpers reject invalid values and format valid values', () => {
  assert.equal(timeToMinutes('08:15'), 495);
  assert.equal(Number.isNaN(timeToMinutes('25:00')), true);
  assert.equal(formatTime24(495), '08:15');
  assert.equal(formatTime24(1440), null);
});

test('HTML escaping protects user-entered schedule names', () => {
  assert.equal(escapeHtml('<img src=x onerror="1">'), '&lt;img src=x onerror=&quot;1&quot;&gt;');
});

test('valid schedules are normalized and sorted by start time', () => {
  const result = validateScheduleState(validState());
  assert.equal(result.valid, true, result.errors.join('\n'));
  assert.deepEqual(result.state.schedules.normal.periods.map(period => period.start), ['08:00', '08:30']);
});

test('overlapping periods are rejected', () => {
  const state = validState();
  state.schedules.normal.periods[0].start = '08:20';
  const result = validateScheduleState(state);
  assert.equal(result.valid, false);
  assert.match(result.errors.join('\n'), /تداخل/);
});

test('invalid times and duplicate schedule names are rejected', () => {
  const state = validState();
  state.schedules.normal.periods[0].start = '28:00';
  state.schedules.second = { name: 'الدوام العادي', periods: [{ name: 'حصة', start: '09:00', duration: 30 }] };
  const result = validateScheduleState(state);
  assert.equal(result.valid, false);
  assert.match(result.errors.join('\n'), /غير صالح/);
  assert.match(result.errors.join('\n'), /مكرر/);
});

test('backup round-trip preserves a valid state', () => {
  const state = validateScheduleState(validState()).state;
  const payload = createBackupPayload(state, '1.3.0');
  const imported = parseBackupText(JSON.stringify(payload));
  assert.equal(imported.valid, true, imported.errors.join('\n'));
  assert.deepEqual(imported.state, state);
});

test('foreign and malformed backup files are rejected', () => {
  assert.equal(parseBackupText('{bad').valid, false);
  assert.equal(parseBackupText(JSON.stringify({ format: 'another-app', state: {} })).valid, false);
});
