import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:not_today/main.dart';
import 'package:not_today/models/not_today_item.dart';
import 'package:not_today/screens/weekly_review_screen.dart';

/// Exercises the five refinements on top of the core flows.
void main() {
  testWidgets('mirror: 5+ postpones swaps the count for an observation and '
      'drops "Not today"', (tester) async {
    final seeded = [
      {
        'id': 'seed-1',
        'text': 'Learn to fly',
        'parkedAt': DateTime.now().toIso8601String(),
        'postponeCount': 5,
        'releasedAs': null,
        'releasedAt': null,
      },
    ];
    SharedPreferences.setMockInitialValues({
      'not_today_items': jsonEncode(seeded),
    });

    await tester.pumpWidget(const NotTodayApp());
    await tester.pumpAndSettle();

    // The observation replaces the parked-ago counter.
    expect(find.text("You've set this aside 5 times."), findsOneWidget);

    // Expand: two exits remain, "Not today" is gone — the mirror doesn't
    // keep postponing, it asks what you actually want.
    await tester.tap(find.text('Learn to fly'));
    await tester.pumpAndSettle();
    expect(find.text('I did it'), findsOneWidget);
    expect(find.text('Let it go'), findsOneWidget);
    expect(find.text('Not today'), findsNothing);
  });

  testWidgets('undo: a release can be taken back within the grace window',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NotTodayApp());
    await tester.pumpAndSettle();

    // Park one item.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Declutter the desk');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Park it'));
    await tester.pumpAndSettle();

    // Release it as let go.
    await tester.tap(find.text('Declutter the desk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let it go'));
    await tester.pumpAndSettle();

    // Gone, with the honest nod and an Undo escape hatch.
    expect(find.text('Declutter the desk'), findsNothing);
    expect(find.text("Let go. That's allowed."), findsOneWidget);

    // Take it back.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Declutter the desk'), findsOneWidget);
    expect(find.text("Let go. That's allowed."), findsNothing);
  });

  testWidgets('review: shows longest-carried, reframes let-go, and brings '
      'an item back', (tester) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    final items = [
      // Parked at day 0 so it is always inside the current week, whatever
      // weekday the test runs on. The released items are stamped at day+1h
      // and day+2h — still inside today, still in-week, but parked after
      // p1 so p1 remains the longest-carried.
      NotTodayItem(
        id: 'p1',
        text: 'Fix the leaking faucet',
        parkedAt: day,
      ),
      NotTodayItem(
        id: 'l1',
        text: 'That ambitious side project',
        parkedAt: day.add(const Duration(hours: 1)),
        releasedAs: ReleaseKind.letGo,
        releasedAt: day.add(const Duration(hours: 1)),
      ),
      NotTodayItem(
        id: 'l2',
        text: 'The old newsletter folder',
        parkedAt: day.add(const Duration(hours: 2)),
        releasedAs: ReleaseKind.letGo,
        releasedAt: day.add(const Duration(hours: 2)),
      ),
    ];

    NotTodayItem? broughtBack;
    await tester.pumpWidget(MaterialApp(
      home: WeeklyReviewScreen(
        allItems: items,
        onRepark: (item) => broughtBack = item,
      ),
    ));
    await tester.pumpAndSettle();

    // Tally row: Parked counts everything parked this week (3, all still
    // in-week), Did 0, Let go 2.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Longest-carried line names the item and when it was parked.
    expect(
      find.textContaining('Carrying the longest: Fix the leaking faucet'),
      findsOneWidget,
    );

    // Letting go is framed as clearing room, not failing.
    expect(find.text('2 things released — room cleared.'), findsOneWidget);
    expect(find.text('This week you let go'), findsOneWidget);

    // Bringing one back calls home and retracts the release.
    await tester.tap(find.text('Bring back').first);
    await tester.pumpAndSettle();
    expect(broughtBack, isNotNull);
    expect(broughtBack!.isParked, isTrue);
    expect(broughtBack!.releasedAs, isNull);
    expect(find.text('Bring back'), findsOneWidget); // only one left
  });

  testWidgets('review: an item postponed 3× this week gets a gentle question',
      (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // A date that is guaranteed to sit inside the current week, even on a
    // Monday when counting back would cross into last week.
    DateTime inThisWeek(int daysBack) {
      final d = today.subtract(Duration(days: daysBack));
      return d.isBefore(monday) ? monday : d;
    }

    final items = [
      // Still parked, "not today" three times this week → the review asks.
      NotTodayItem(
        id: 'p1',
        text: 'Follow up on the grant',
        parkedAt: today,
        postponedDates: [inThisWeek(2), inThisWeek(1), inThisWeek(0)],
      ),
      // Still parked, only twice this week → below the mirror's threshold.
      NotTodayItem(
        id: 'p2',
        text: 'Print the boarding passes',
        parkedAt: today,
        postponedDates: [inThisWeek(1), inThisWeek(0)],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: WeeklyReviewScreen(
        allItems: items,
        onRepark: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    // The offender is named; the twice-postponed item stays unremarkable.
    expect(
      find.textContaining('Follow up on the grant followed you 3× this week'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Is it actually yours to do?'),
      findsOneWidget,
    );
    expect(find.textContaining('followed you 2×'), findsNothing);
  });

  testWidgets('review: the longest-carried line names how many days it has '
      'been carried', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Oldest-possible-in-week item: parked at Monday midnight (start of week).
    // Its age is today − monday = weekday-1 (e.g. 0 on Mon, 6 on Sun).
    final weekAge = today.weekday - 1; // 0 .. 6
    final monday = today.subtract(Duration(days: weekAge));

    await tester.pumpWidget(MaterialApp(
      home: WeeklyReviewScreen(
        allItems: [
          NotTodayItem(
            id: 'old',
            text: 'Water the plants',
            parkedAt: monday,
          ),
        ],
        onRepark: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    // _ageLabel speaks only for items 2+ calendar days old (Monday has none,
    // so the section is absent then — assert exactly what the UI promises).
    if (weekAge >= 2) {
      expect(find.textContaining("That's $weekAge days."), findsOneWidget);
    } else {
      expect(find.textContaining("That's"), findsNothing);
    }

    // A same-day item gets no age note — the "since …" date is enough.
    // A fresh key so the State (which caches _items) is rebuilt.
    await tester.pumpWidget(MaterialApp(
      home: WeeklyReviewScreen(
        key: UniqueKey(),
        allItems: [
          NotTodayItem(
            id: 'fresh',
            text: 'Water the plants',
            parkedAt: today,
          ),
        ],
        onRepark: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining("That's"), findsNothing);
  });

  testWidgets('reminder sheet: gear icon opens sheet, toggle is interactive',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NotTodayApp());
    await tester.pumpAndSettle();

    // Tap the gear icon to open the reminder sheet.
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    // Sheet shows "Morning nudge" title and the toggle label.
    expect(find.text('Morning nudge'), findsOneWidget);
    expect(find.text('Gentle nudge'), findsOneWidget);

    // The switch is off by default, subtitle shows "Off — the app stays silent."
    expect(find.text('Off — the app stays silent.'), findsOneWidget);

    // Toggle it on.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // After toggle: "Off" subtitle gone, "Change the time" button appears.
    expect(find.text('Off — the app stays silent.'), findsNothing);
    expect(find.text('Change the time'), findsOneWidget);
  });
}