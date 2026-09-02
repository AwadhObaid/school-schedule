(function (root, factory) {
  const api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  root.ScheduleAppUtils = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const BACKUP_FORMAT = 'school-schedule-backup';
  const BACKUP_VERSION = 1;
  const TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
  const SAFE_ID_PATTERN = /^[A-Za-z0-9_-]{1,80}$/;

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, character => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    })[character]);
  }

  function timeToMinutes(value) {
    if (!TIME_PATTERN.test(String(value || ''))) return NaN;
    const [hours, minutes] = value.split(':').map(Number);
    return hours * 60 + minutes;
  }

  function formatTime24(totalMinutes) {
    if (!Number.isInteger(totalMinutes) || totalMinutes < 0 || totalMinutes >= 1440) return null;
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  }

  function validateScheduleState(candidate) {
    const errors = [];
    if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
      return { valid: false, errors: ['ملف الإعدادات لا يحتوي على بيانات صالحة.'], state: null };
    }

    const sourceSchedules = candidate.schedules;
    if (!sourceSchedules || typeof sourceSchedules !== 'object' || Array.isArray(sourceSchedules)) {
      return { valid: false, errors: ['بيانات الجداول غير موجودة أو غير صالحة.'], state: null };
    }

    const pin = String(candidate.pin ?? '');
    if (!/^\d{4,12}$/.test(pin)) {
      errors.push('رمز الدخول يجب أن يتكوّن من 4 إلى 12 رقمًا.');
    }

    const cleanState = {
      schemaVersion: 3,
      ramadanMode: Boolean(candidate.ramadanMode),
      pin,
      soundEnabled: Boolean(candidate.soundEnabled),
      notificationsEnabled: candidate.notificationsEnabled === undefined
        ? Boolean(candidate.soundEnabled)
        : Boolean(candidate.notificationsEnabled),
      weekdayMap: {},
      schedules: {}
    };

    const scheduleIds = Object.keys(sourceSchedules);
    if (!scheduleIds.length) errors.push('يجب أن يوجد جدول واحد على الأقل.');

    const usedNames = new Set();
    scheduleIds.forEach(id => {
      if (!SAFE_ID_PATTERN.test(id)) {
        errors.push(`معرّف الجدول "${id}" غير صالح.`);
        return;
      }

      const schedule = sourceSchedules[id];
      if (!schedule || typeof schedule !== 'object' || Array.isArray(schedule)) {
        errors.push(`بيانات الجدول "${id}" غير صالحة.`);
        return;
      }

      const scheduleName = String(schedule.name ?? '').trim();
      if (!scheduleName) errors.push(`اسم الجدول "${id}" فارغ.`);
      if (scheduleName.length > 60) errors.push(`اسم الجدول "${scheduleName}" أطول من 60 حرفًا.`);
      const comparableName = scheduleName.toLocaleLowerCase('ar');
      if (usedNames.has(comparableName)) errors.push(`اسم الجدول "${scheduleName}" مكرر.`);
      usedNames.add(comparableName);

      if (!Array.isArray(schedule.periods) || !schedule.periods.length) {
        errors.push(`الجدول "${scheduleName || id}" لا يحتوي على أي فترة.`);
        cleanState.schedules[id] = { name: scheduleName, periods: [] };
        return;
      }
      if (schedule.periods.length > 50) {
        errors.push(`الجدول "${scheduleName || id}" يحتوي على أكثر من 50 فترة.`);
      }

      const cleanPeriods = [];
      schedule.periods.forEach((period, index) => {
        const label = `الفترة رقم ${index + 1} في جدول "${scheduleName || id}"`;
        if (!period || typeof period !== 'object' || Array.isArray(period)) {
          errors.push(`${label} غير صالحة.`);
          return;
        }

        const name = String(period.name ?? '').trim();
        const start = String(period.start ?? '');
        const duration = Number(period.duration);
        if (!name) errors.push(`اسم ${label} فارغ.`);
        if (name.length > 60) errors.push(`اسم ${label} أطول من 60 حرفًا.`);
        if (!TIME_PATTERN.test(start)) errors.push(`وقت بداية ${label} غير صالح.`);
        if (!Number.isInteger(duration) || duration < 1 || duration > 600) {
          errors.push(`مدة ${label} يجب أن تكون بين دقيقة و600 دقيقة.`);
        }
        if (name && name.length <= 60 && TIME_PATTERN.test(start) && Number.isInteger(duration) && duration >= 1 && duration <= 600) {
          cleanPeriods.push({ name, start, duration });
        }
      });

      cleanPeriods.sort((first, second) => timeToMinutes(first.start) - timeToMinutes(second.start));
      cleanPeriods.forEach((period, index) => {
        const start = timeToMinutes(period.start);
        const end = start + period.duration;
        if (end > 1440) {
          errors.push(`الفترة "${period.name}" في جدول "${scheduleName || id}" تتجاوز نهاية اليوم.`);
        }
        const previous = cleanPeriods[index - 1];
        if (previous) {
          const previousEnd = timeToMinutes(previous.start) + previous.duration;
          if (start < previousEnd) {
            errors.push(`يوجد تداخل بين "${previous.name}" و"${period.name}" في جدول "${scheduleName || id}".`);
          }
        }
      });

      cleanState.schedules[id] = { name: scheduleName, periods: cleanPeriods };
    });

    const sourceWeekdayMap = candidate.weekdayMap && typeof candidate.weekdayMap === 'object'
      ? candidate.weekdayMap
      : {};
    for (let day = 0; day < 7; day += 1) {
      const selected = String(sourceWeekdayMap[day] ?? 'off');
      if (selected !== 'off' && !cleanState.schedules[selected]) {
        errors.push(`اختيار الجدول لليوم رقم ${day + 1} يشير إلى جدول غير موجود.`);
        cleanState.weekdayMap[day] = 'off';
      } else {
        cleanState.weekdayMap[day] = selected;
      }
    }

    return { valid: errors.length === 0, errors, state: cleanState };
  }

  function createBackupPayload(state, appVersion) {
    return {
      format: BACKUP_FORMAT,
      backupVersion: BACKUP_VERSION,
      appVersion: String(appVersion || ''),
      exportedAt: new Date().toISOString(),
      state: JSON.parse(JSON.stringify(state))
    };
  }

  function parseBackupText(text) {
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch (error) {
      return { valid: false, errors: ['الملف ليس نسخة احتياطية بصيغة JSON صالحة.'], state: null };
    }

    const candidate = parsed && parsed.format === BACKUP_FORMAT ? parsed.state : parsed;
    if (parsed && parsed.format && parsed.format !== BACKUP_FORMAT) {
      return { valid: false, errors: ['هذا الملف لا يخص تطبيق التوقيت المدرسي.'], state: null };
    }
    if (parsed && parsed.backupVersion && Number(parsed.backupVersion) > BACKUP_VERSION) {
      return { valid: false, errors: ['النسخة الاحتياطية أُنشئت بإصدار أحدث من التطبيق.'], state: null };
    }
    return validateScheduleState(candidate);
  }

  return {
    BACKUP_FORMAT,
    BACKUP_VERSION,
    TIME_PATTERN,
    escapeHtml,
    timeToMinutes,
    formatTime24,
    validateScheduleState,
    createBackupPayload,
    parseBackupText
  };
});
