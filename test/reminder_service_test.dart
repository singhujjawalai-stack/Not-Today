import 'package:flutter_test/flutter_test.dart';
import 'package:not_today/models/not_today_item.dart';
import 'package:not_today/services/reminder_service.dart';

/// Unit tests for the nudge copy — pure string building, no plugin involved.
void main() {
  group('buildNudgeBody', () {
    final now = DateTime(2026, 9, 14, 9, 0);

    /// An item that was postponed and whose return time has arrived.
    NotTodayItem resurfaced(String id, String text, DateTime returnedOn) =>
        NotTodayItem(
          id: id,
          text: text,
          parkedAt: returnedOn.subtract(const Duration(days: 1)),
          postponedUntil: returnedOn,
        );

    test('empty list gets the honest quiet line', () {
      expect(
        buildNudgeBody(const [], now),
        'Nothing on the list today. Enjoy the quiet.',
      );
    });

    test('parked-but-never-postponed items are not named', () {
      final items = [
        NotTodayItem(id: 'a', text: 'Water the plants', parkedAt: now),
      ];
      expect(
        buildNudgeBody(items, now),
        'Your parked things are still there. No pressure.',
      );
    });

    test('a still-hidden (not yet returned) item is not named', () {
      final items = [
        resurfaced('a', 'Water the plants', now.add(const Duration(days: 1))),
      ];
      expect(
        buildNudgeBody(items, now),
        'Your parked things are still there. No pressure.',
      );
    });

    test('one return gets named and the permission stays', () {
      final items = [resurfaced('a', 'Water the plants', now)];
      expect(
        buildNudgeBody(items, now),
        'Back on the list: Water the plants. Or not. No pressure.',
      );
    });

    test('two returns get both names', () {
      final items = [
        resurfaced('a', 'Water the plants', now),
        resurfaced(
          'b',
          'Call the dentist',
          now.subtract(const Duration(days: 1)),
        ),
      ];
      expect(
        buildNudgeBody(items, now),
        'Back on the list: Water the plants and Call the dentist. '
        'Or not. No pressure.',
      );
    });

    test('more than two get the newest two plus the tail', () {
      final items = [
        resurfaced('a', 'Alpha', now),
        resurfaced('b', 'Beta', now.subtract(const Duration(days: 1))),
        resurfaced('c', 'Gamma', now.subtract(const Duration(days: 2))),
        resurfaced('d', 'Delta', now.subtract(const Duration(days: 3))),
      ];
      expect(
        buildNudgeBody(items, now),
        'Back on the list: Alpha and Beta … and 2 more. Or not. No pressure.',
      );
    });

    test('released items are not named', () {
      final items = [
        resurfaced('a', 'Water the plants', now)
            .release(ReleaseKind.letGo, now),
      ];
      expect(
        buildNudgeBody(items, now),
        'Nothing on the list today. Enjoy the quiet.',
      );
    });
  });

  group('buildTestNudgeBody', () {
    test('empty list gets quiet message', () {
      expect(
        buildTestNudgeBody(const []),
        'Nothing on the list today. Enjoy the quiet.',
      );
    });

    test('parked items preview dynamic naming format for manual testing', () {
      final items = [
        NotTodayItem(
          id: 'a',
          text: 'Water the plants',
          parkedAt: DateTime.now(),
        ),
        NotTodayItem(
          id: 'b',
          text: 'Fix the faucet',
          parkedAt: DateTime.now(),
        ),
      ];
      expect(
        buildTestNudgeBody(items),
        'Back on the list: Water the plants and Fix the faucet. Or not. No pressure.',
      );
    });

    test('postponed items take precedence in test preview', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final items = [
        NotTodayItem(
          id: 'a',
          text: 'Water the plants',
          parkedAt: DateTime.now(),
          postponedUntil: tomorrow,
        ),
      ];
      expect(
        buildTestNudgeBody(items),
        'Back on the list: Water the plants. Or not. No pressure.',
      );
    });
  });
}