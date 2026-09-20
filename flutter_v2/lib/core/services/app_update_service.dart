import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../models/app_update.dart';

class AppUpdateService {
  AppUpdateService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _ignoredVersionKey = 'ignored_update_tag_v1';

  final http.Client _client;

  Future<AppUpdateCheckResult> check({
    required String currentVersion,
    bool respectIgnored = true,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(AppInfo.latestReleaseApiUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'SchoolSchedule-Flutter-V2',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 404) {
        return const AppUpdateCheckResult(
          status: AppUpdateStatus.noPublishedRelease,
          message: 'لا توجد إصدارات منشورة على GitHub حتى الآن.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateCheckResult(
          status: AppUpdateStatus.unavailable,
          message:
              'تعذر التحقق من التحديثات حاليًا (رمز ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const AppUpdateCheckResult(
          status: AppUpdateStatus.unavailable,
          message: 'تعذر قراءة معلومات الإصدار المنشور.',
        );
      }

      final release = Map<String, dynamic>.from(decoded);
      final tag = release['tag_name']?.toString().trim() ?? '';
      final releaseUrlText = release['html_url']?.toString().trim() ?? '';

      if (tag.isEmpty || releaseUrlText.isEmpty) {
        return const AppUpdateCheckResult(
          status: AppUpdateStatus.unavailable,
          message: 'معلومات الإصدار المنشور غير مكتملة.',
        );
      }

      final latestVersion = _normalizeVersion(tag);
      final current = _normalizeVersion(currentVersion);

      if (_compareVersions(latestVersion, current) <= 0) {
        return AppUpdateCheckResult(
          status: AppUpdateStatus.upToDate,
          message: 'أنت تستخدم أحدث إصدار ($currentVersion).',
        );
      }

      if (respectIgnored) {
        final preferences = await SharedPreferences.getInstance();
        final ignored = preferences.getString(_ignoredVersionKey);
        if (ignored == tag) {
          return AppUpdateCheckResult(
            status: AppUpdateStatus.upToDate,
            message: 'تم تجاهل الإصدار $latestVersion مسبقًا.',
          );
        }
      }

      final assets = release['assets'];
      Uri? apkUrl;

      if (assets is List) {
        for (final item in assets) {
          if (item is! Map) continue;
          final asset = Map<String, dynamic>.from(item);
          final name = asset['name']?.toString().toLowerCase() ?? '';
          final url = asset['browser_download_url']?.toString().trim() ?? '';
          if (name.endsWith('.apk') && url.isNotEmpty) {
            apkUrl = Uri.tryParse(url);
            if (apkUrl != null) break;
          }
        }
      }

      final releaseUrl = Uri.parse(releaseUrlText);
      final info = AppUpdateInfo(
        tag: tag,
        version: latestVersion,
        title: (release['name']?.toString().trim().isNotEmpty ?? false)
            ? release['name'].toString().trim()
            : 'الإصدار $latestVersion',
        notes: release['body']?.toString().trim() ?? '',
        releaseUrl: releaseUrl,
        downloadUrl: apkUrl ?? releaseUrl,
      );

      return AppUpdateCheckResult(
        status: AppUpdateStatus.updateAvailable,
        message: 'يتوفر تحديث جديد: $latestVersion',
        update: info,
      );
    } catch (_) {
      return const AppUpdateCheckResult(
        status: AppUpdateStatus.unavailable,
        message: 'تعذر الاتصال بخدمة التحديثات. تحقق من الإنترنت وحاول لاحقًا.',
      );
    }
  }

  Future<void> ignore(AppUpdateInfo update) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_ignoredVersionKey, update.tag);
  }

  Future<bool> openUpdate(AppUpdateInfo update) async {
    try {
      return await launchUrl(
        update.downloadUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  static String _normalizeVersion(String value) {
    var version = value.trim();
    if (version.toLowerCase().startsWith('v')) {
      version = version.substring(1);
    }

    final match =
        RegExp(r'\d+(?:\.\d+){0,3}(?:\+\d+)?').firstMatch(version);
    return match?.group(0) ?? '0.0.0';
  }

  static int _compareVersions(String left, String right) {
    final a = _parts(left);
    final b = _parts(right);
    final length = a.length > b.length ? a.length : b.length;

    for (var index = 0; index < length; index += 1) {
      final av = index < a.length ? a[index] : 0;
      final bv = index < b.length ? b[index] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static List<int> _parts(String value) {
    return value
        .replaceAll('+', '.')
        .split('.')
        .map((item) => int.tryParse(item) ?? 0)
        .toList(growable: false);
  }
}
