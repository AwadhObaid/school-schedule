import 'package:flutter/material.dart';

import '../../../core/app_controller.dart';
import '../../../core/models/app_update.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppController controller,
  required AppUpdateInfo update,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final notes = update.notes.trim();

      return AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded),
        title: Text('يتوفر تحديث ${update.version}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  update.title,
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'ما الجديد',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  notes.isEmpty
                      ? 'يتوفر إصدار أحدث من التطبيق.'
                      : notes,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لاحقًا'),
          ),
          TextButton(
            onPressed: () async {
              await controller.ignoreUpdate(update);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('تجاهل هذا الإصدار'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final opened = await controller.openUpdate(update);
              if (!dialogContext.mounted) return;

              if (opened) {
                Navigator.pop(dialogContext);
                return;
              }

              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('تعذر فتح رابط التحديث.'),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('تحديث الآن'),
          ),
        ],
      );
    },
  );
}
