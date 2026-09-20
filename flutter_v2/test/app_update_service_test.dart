import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schedule/core/models/app_update.dart';
import 'package:schedule/core/services/app_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('detects a newer GitHub release and prefers APK asset', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.10.1',
          'name': 'School Schedule 2.10.1',
          'body': 'إصلاحات وتحسينات',
          'html_url':
              'https://github.com/AwadhObaid/school-schedule/releases/tag/v2.10.1',
          'assets': [
            {
              'name': 'SchoolSchedule.apk',
              'browser_download_url':
                  'https://github.com/AwadhObaid/school-schedule/releases/download/v2.10.1/SchoolSchedule.apk',
            },
          ],
        }),
        200,
        headers: const {
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final service = AppUpdateService(client: client);
    final result = await service.check(currentVersion: '2.10.0+19');

    expect(result.status, AppUpdateStatus.updateAvailable);
    expect(result.update?.version, '2.10.1');
    expect(result.update?.downloadUrl.path, endsWith('SchoolSchedule.apk'));
    expect(result.update?.notes, contains('تحسينات'));
  });

  test('reports current version as up to date', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.10.0',
          'name': 'School Schedule 2.10.0',
          'body': '',
          'html_url':
              'https://github.com/AwadhObaid/school-schedule/releases/tag/v2.10.0',
          'assets': <Object>[],
        }),
        200,
        headers: const {
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final result = await AppUpdateService(client: client).check(
      currentVersion: '2.10.0+19',
    );

    expect(result.status, AppUpdateStatus.upToDate);
    expect(result.hasUpdate, isFalse);
  });

  test('handles repository with no published releases', () async {
    final client = MockClient((request) async {
      return http.Response('{}', 404);
    });

    final result = await AppUpdateService(client: client).check(
      currentVersion: '2.10.0+19',
    );

    expect(result.status, AppUpdateStatus.noPublishedRelease);
    expect(result.hasUpdate, isFalse);
  });

  test('ignored release is not shown by automatic checks', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'tag_name': 'v2.11.0',
          'name': 'School Schedule 2.11.0',
          'body': 'تحديث',
          'html_url':
              'https://github.com/AwadhObaid/school-schedule/releases/tag/v2.11.0',
          'assets': <Object>[],
        }),
        200,
        headers: const {
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });

    final service = AppUpdateService(client: client);
    final first = await service.check(currentVersion: '2.10.0+19');
    expect(first.hasUpdate, isTrue);

    await service.ignore(first.update!);

    final second = await service.check(
      currentVersion: '2.10.0+19',
      respectIgnored: true,
    );

    expect(second.status, AppUpdateStatus.upToDate);
    expect(second.hasUpdate, isFalse);
    expect(second.message, contains('تجاهل'));
  });
}
