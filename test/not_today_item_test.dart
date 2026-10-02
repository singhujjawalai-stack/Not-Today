import 'package:flutter_test/flutter_test.dart';
import 'package:not_today/models/not_today_item.dart';
import 'package:not_today/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotTodayItem', () {
    test('JSON round-trip preserves all fields', () {
      final item = NotTodayItem(
        id: 'abc',
        text: 'Call the dentist',
        parkedAt: DateTime(2026, 9, 7, 10, 30),
        lastPostponedAt: DateTime(2026, 9, 8, 9),
        postponeCount: 2,
        postponedDates: [DateTime(2026, 9, 8, 9), DateTime(2026, 9, 9, 21)],
        postponedUntil: DateTime(2026, 9, 9),
      );

      final restored = NotTodayItem.fromJson(item.toJson());

      expect(restored.id, item.id);
      expect(restored.text, item.text);
      expect(restored.parkedAt, item.parkedAt);
      expect(restored.lastPostponedAt, item.lastPostponedAt);
      expect(restored.postponeCount, 2);
      expect(restored.postponedDates, item.postponedDates);
      expect(restored.postponedUntil, item.postponedUntil);
      expect(restored.isParked, isTrue);
      expect(restored.releasedAs, isNull);
    });

    test('old JSON without postponedDates loads as an empty history', () {
      final restored = NotTodayItem.fromJson({
        'id': 'abc',
        'text': 'Call the dentist',
        'parkedAt': DateTime(2026, 9, 7, 10, 30).toIso8601String(),
        'postponeCount': 3,
      });

      expect(restored.postponeCount, 3);
      expect(restored.postponedDates, isEmpty);
    });

    test('released items round-trip with kind', () {
      final item = NotTodayItem(
        id: 'abc',
        text: 'Fix the shelf',
        parkedAt: DateTime(2026, 9, 1),
      ).release(ReleaseKind.done, DateTime(2026, 9, 3));

      final restored = NotTodayItem.fromJson(item.toJson());

      expect(restored.releasedAs, ReleaseKind.done);
      expect(restored.releasedAt, DateTime(2026, 9, 3));
      expect(restored.isParked, isFalse);
    });

    test('postpone increments the count and stamps the time', () {
      final item = NotTodayItem(
        id: 'abc',
        text: 'Reorganize the drawer',
        parkedAt: DateTime(2026, 9, 1),
      );

      final postponed = item.postpone(DateTime(2026, 9, 2, 11));

      expect(postponed.postponeCount, 1);
      expect(postponed.lastPostponedAt, DateTime(2026, 9, 2, 11));
      expect(postponed.postponedDates, [DateTime(2026, 9, 2, 11)]);
      expect(postponed.parkedAt, item.parkedAt);
      expect(postponed.isParked, isTrue);

      // A second "not today" keeps watching the pattern unfold.
      final again = postponed.postpone(DateTime(2026, 9, 3, 9));
      expect(again.postponeCount, 2);
      expect(again.postponedDates,
          [DateTime(2026, 9, 2, 11), DateTime(2026, 9, 3, 9)]);
    });

    test('postpone sets the item aside until the next calendar day', () {
      final item = NotTodayItem(
        id: 'abc',
        text: 'Mail the passport',
        parkedAt: DateTime(2026, 9, 1),
      );

      final postponed = item.postpone(DateTime(2026, 9, 2, 21, 30));

      // Hidden the rest of today, visible again from midnight on.
      expect(postponed.postponedUntil, DateTime(2026, 9, 3));
      expect(postponed.isPostponedNow(DateTime(2026, 9, 2, 23, 59)), isTrue);
      expect(postponed.isPostponedNow(DateTime(2026, 9, 3)), isFalse);
    });

    test('bringBack returns a released item to the parked list', () {
      final released = NotTodayItem(
        id: 'abc',
        text: 'Sell the sofa',
        parkedAt: DateTime(2026, 9, 1),
        postponeCount: 2,
      ).release(ReleaseKind.letGo, DateTime(2026, 9, 5));

      final back = released.bringBack();

      expect(back.releasedAs, isNull);
      expect(back.releasedAt, isNull);
      expect(back.isParked, isTrue);
      expect(back.postponeCount, 2);
      expect(back.postponedUntil, isNull);
    });

    test('release sets kind and timestamp; isParked flips to false', () {
      final item = NotTodayItem(
        id: 'abc',
        text: 'Return the library book',
        parkedAt: DateTime(2026, 9, 1),
      );

      final released = item.release(ReleaseKind.letGo, DateTime(2026, 9, 5));

      expect(released.releasedAs, ReleaseKind.letGo);
      expect(released.releasedAt, DateTime(2026, 9, 5));
      expect(released.isParked, isFalse);
    });

    test('postponing a released item keeps it released', () {
      final released = NotTodayItem(
        id: 'abc',
        text: 'Learn French',
        parkedAt: DateTime(2026, 9, 1),
      ).release(ReleaseKind.letGo, DateTime(2026, 9, 4));

      final again = released.postpone(DateTime(2026, 9, 6));

      expect(again.postponeCount, 1);
      expect(again.isParked, isFalse);
      expect(again.releasedAs, ReleaseKind.letGo);
    });
  });

  group('StorageService', () {
    test('save then load returns the same items', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      final items = [
        NotTodayItem(
          id: '1',
          text: 'Write thank-you note',
          parkedAt: DateTime(2026, 9, 7),
          postponeCount: 1,
        ),
        NotTodayItem(
          id: '2',
          text: 'Clean the garage',
          parkedAt: DateTime(2026, 9, 6),
        ).release(ReleaseKind.done, DateTime(2026, 9, 8)),
      ];

      await storage.saveItems(items);
      final loaded = await storage.loadItems();

      expect(loaded.length, 2);
      expect(loaded[0].id, '1');
      expect(loaded[0].postponeCount, 1);
      expect(loaded[1].releasedAs, ReleaseKind.done);
      expect(loaded[1].isParked, isFalse);
    });

    test('load on corrupt JSON clears and returns empty', () async {
      SharedPreferences.setMockInitialValues({'not_today_items': 'nonsense'});
      final storage = StorageService();

      final loaded = await storage.loadItems();

      expect(loaded, isEmpty);

      // Key was cleared so a fresh load is also empty.
      final again = await storage.loadItems();
      expect(again, isEmpty);
    });
  });
}