import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:not_today/main.dart';

void main() {
  testWidgets('empty state renders and an item can be parked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NotTodayApp());
    await tester.pumpAndSettle();

    // Calm, empty first impression.
    expect(find.text('Nothing waiting.'), findsOneWidget);
    expect(find.text("Nothing parked — that's fine too."), findsOneWidget);

    // Park something.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('What can wait until another day?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Call the dentist');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Park it'));
    await tester.pumpAndSettle();

    // It appears on the list, and the empty state is gone.
    expect(find.text('Call the dentist'), findsOneWidget);
    expect(find.text('Nothing waiting.'), findsNothing);
    expect(find.text('1 thing parked · no rush'), findsOneWidget);
  });

  testWidgets('card expands and releasing as done removes it quietly',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NotTodayApp());
    await tester.pumpAndSettle();

    // Seed one item by parking it.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fix the shelf');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Park it'));
    await tester.pumpAndSettle();

    // Tap the card to expand the three quiet exits.
    await tester.tap(find.text('Fix the shelf'));
    await tester.pumpAndSettle();
    expect(find.text('Not today'), findsOneWidget);
    expect(find.text('I did it'), findsOneWidget);
    expect(find.text('Let it go'), findsOneWidget);

    // "I did it" removes it with a quiet nod.
    await tester.tap(find.text('I did it'));
    await tester.pumpAndSettle();
    expect(find.text('Fix the shelf'), findsNothing);
    expect(find.text('Done. Off your mind. 🎉'), findsOneWidget);

    // Back to the clear-head empty state.
    expect(find.text('Nothing waiting.'), findsOneWidget);
  });

  testWidgets('"Not today" puts the item aside until tomorrow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NotTodayApp());
    await tester.pumpAndSettle();

    // Park one item.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Water the plants');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Park it'));
    await tester.pumpAndSettle();

    // Expand and say not today.
    await tester.tap(find.text('Water the plants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not today'));
    await tester.pumpAndSettle();

    // Gone from the view for now — with an honest, quiet nod.
    expect(find.text('Water the plants'), findsNothing);
    expect(find.text('Back tomorrow.'), findsOneWidget);
    expect(find.text('1 postponed · back tomorrow'), findsOneWidget);
    expect(find.text('Nothing waiting today.'), findsOneWidget);
  });
}