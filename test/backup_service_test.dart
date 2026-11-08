import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:not_today/models/not_today_item.dart';
import 'package:not_today/services/backup_service.dart';

void main() {
  group('BackupService.parse', () {
    test('reads the versioned wrapper', () {
      final now = DateTime(2026, 11, 8, 10, 30);
      final source = jsonEncode({
        'app': 'not-today',
        'version': 1,
        'exportedAt': now.toIso8601String(),
        'items': [
          {
            'id': 'a',
            'text': 'Water the fern',
            'parkedAt': now.toIso8601String(),
          },
        ],
      });

      final parsed = BackupService.parse(source);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.single.text, 'Water the fern');
      expect(parsed.skipped, 0);
    });

    test('reads a bare array, the on-device storage format', () {
      final now = DateTime(2026, 11, 8);
      final source = jsonEncode([
        {
          'id': 'a',
          'text': 'Call the dentist',
          'parkedAt': now.toIso8601String(),
        },
      ]);

      final parsed = BackupService.parse(source);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.single.text, 'Call the dentist');
    });

    test('skips unreadable records and keeps the rest', () {
      final now = DateTime(2026, 11, 8);
      final source = jsonEncode([
        {'id': 'good', 'text': 'Ok item', 'parkedAt': now.toIso8601String()},
        {'id': 'bad'}, // no text, no parkedAt — unreadable
      ]);

      final parsed = BackupService.parse(source);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.single.id, 'good');
      expect(parsed.skipped, 1);
    });

    test('rejects a file that is not a backup at all', () {
      expect(
        () => BackupService.parse(jsonEncode({'hello': 'world'})),
        throwsFormatException,
      );
    });

    test('round-trips through toJson', () {
      final now = DateTime(2026, 11, 8, 9, 0);
      final item = NotTodayItem(
        id: 'a',
        text: 'Tune the bicycle',
        parkedAt: now,
        postponeCount: 2,
        postponedDates: [now],
        postponedUntil: DateTime(2026, 11, 9),
      );

      final parsed = BackupService.parse(
        jsonEncode([item.toJson()]),
      );
      final back = parsed.items.single;
      expect(back.id, 'a');
      expect(back.text, 'Tune the bicycle');
      expect(back.parkedAt, now);
      expect(back.postponeCount, 2);
      expect(back.postponedUntil, DateTime(2026, 11, 9));
    });
  });

  group('BackupService.merge', () {
    final a1 = NotTodayItem(id: 'a', text: 'Old wording', parkedAt: DateTime(2026, 11, 1));
    final a2 = NotTodayItem(id: 'a', text: 'New wording', parkedAt: DateTime(2026, 11, 1));
    final b = NotTodayItem(id: 'b', text: 'Local only', parkedAt: DateTime(2026, 11, 2));
    final c = NotTodayItem(id: 'c', text: 'From the backup', parkedAt: DateTime(2026, 11, 3));

    test('incoming wins on a shared id', () {
      final merged = BackupService.merge([a1, b], [a2, c]);
      expect(merged, hasLength(3));
      expect(merged[0].id, 'a');
      expect(merged[0].text, 'New wording');
      expect(merged[1].id, 'b');
    });

    test('purely imported items join at the end', () {
      final merged = BackupService.merge([a1], [c]);
      expect(merged.map((i) => i.id), ['a', 'c']);
    });

    test('an empty backup changes nothing', () {
      final merged = BackupService.merge([a1, b], []);
      expect(merged.map((i) => i.id), ['a', 'b']);
    });
  });
}
