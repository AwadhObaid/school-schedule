# Stable Release Infrastructure

يستخدم Flutter V2 نفس مستودع GitHub للكود ولتوزيع النسخ المستقرة.

Repository:
AwadhObaid/school-schedule

Releases:
https://github.com/AwadhObaid/school-schedule/releases

الرابط الدائم لأحدث APK بعد نشر أول إصدار مستقر:
https://github.com/AwadhObaid/school-schedule/releases/latest/download/SchoolSchedule.apk

## بوابة النشر

السكربت tools/release/publish_stable.ps1 يرفض النشر ما لم تتحقق جميع الشروط التالية:

1. إصدار Flutter بصيغة x.y.z+build.
2. versionCode أكبر من النسخة القديمة 7.
3. متغيرات توقيع Release موجودة.
4. بناء APK Release ينجح.
5. package داخل APK يساوي com.salaheddine.schedule بالضبط.
6. versionName وversionCode داخل APK يطابقان pubspec.yaml.
7. بصمة شهادة التوقيع SHA-256 تطابق التطبيق القديم:
3845c92da5d39caa76006cfdda25fa2331bfd3542f20d5527cf9e3945524a576
8. لا يتم الكتابة فوق Release موجود مسبقًا.

## الملفات المنشورة

- SchoolSchedule.apk
- SchoolSchedule.sha256

## الأمان

لا تضع keystore أو كلمات المرور في GitHub. السكربت يقرأها محليًا من:
- RELEASE_KEYSTORE_PATH
- RELEASE_KEYSTORE_PASSWORD
- RELEASE_KEY_ALIAS
- RELEASE_KEY_PASSWORD

ولا يطبع كلمات المرور.

## طريقة العمل

شغّل السكربت أولًا بدون Publish. سيبني ويفحص APK فقط ولن ينشر شيئًا.

بعد نجاح اختبار التحديث الفعلي فوق التطبيق القديم بنفس التوقيع، شغله مع Publish وملف ملاحظات الإصدار المعتمد.
