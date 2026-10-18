import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/db/demo_data.dart';
import 'package:gym_tracker/features/progress/exercise_detail_screen.dart';

import '../support/harness.dart';

void main() {
  Future<TestApp> withDemoHistory(WidgetTester tester) async {
    final app = TestApp();
    await tester.runAsync(() => insertDemoHistory(app.db, now: app.clock.now, weeks: 6));
    await app.pump(tester);
    return app;
  }

  testWidgets('home shows this week stats and the last workout', (tester) async {
    await withDemoHistory(tester);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('LAST WORKOUT'), findsOneWidget);
    // 18 Oct 2026 is a Sunday: Mon, Wed and Fri sessions happened this week.
    expect(find.text('workouts'), findsOneWidget);
  });

  testWidgets('history lists workouts by month and opens a summary', (tester) async {
    final app = await withDemoHistory(tester);
    await tester.tap(find.text('History'));
    await app.settle(tester);

    expect(find.text('OCTOBER 2026'), findsOneWidget);
    expect(find.text('Legs'), findsWidgets);

    await tester.tap(find.text('Legs').first);
    await app.settle(tester);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('progress shows trained exercises and their records', (tester) async {
    final app = await withDemoHistory(tester);
    await tester.tap(find.text('Progress'));
    await app.settle(tester);

    expect(find.text('TRAINED'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget, reason: 'most recent first');
    final list = find
        .descendant(of: find.byKey(const Key('progress-list')), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('LIBRARY'), 300, scrollable: list);
    expect(find.text('Not trained yet'), findsWidgets);
    await tester.scrollUntilVisible(find.text('TRAINED'), -300, scrollable: list);

    await tester.enterText(find.widgetWithText(TextField, 'Search exercises'), 'bench');
    await app.settle(tester);
    expect(find.text('Back Squat'), findsNothing);

    await tester.tap(find.text('Bench Press'));
    await app.settle(tester);
    expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    expect(find.text('PERSONAL RECORDS'), findsOneWidget);
    expect(find.text('Est. 1RM'), findsWidgets);
    expect(find.byType(LineChart), findsOneWidget);

    await tester.tap(find.text('Volume').last);
    await app.settle(tester);
    expect(find.byType(LineChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('5 RM'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('exercise-detail-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('5 RM'), findsOneWidget);
  });

  testWidgets('create a program, add a day and an exercise', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await tester.tap(find.text('Programs'));
    await app.settle(tester);
    expect(find.text('Push / Pull / Legs'), findsOneWidget);

    await tester.tap(find.text('Program'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextField), 'Upper / Lower');
    await tester.tap(find.text('Create'));
    await app.settle(tester);
    expect(find.text('No training days'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await app.settle(tester);
    await tester.enterText(find.byType(TextField), 'Upper');
    await tester.tap(find.text('Add'));
    await app.settle(tester);
    expect(find.text('Upper'), findsOneWidget);

    await tester.tap(find.text('Add exercise'));
    await app.settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search exercises'), 'press');
    await tester.pump();
    await tester.tap(find.text('Overhead Press'));
    await app.settle(tester);
    expect(find.text('Overhead Press'), findsOneWidget);
    expect(find.text('3 × 8 · 2:00 rest'), findsOneWidget);

    // Edit the targets.
    await tester.tap(find.text('Overhead Press'));
    await app.settle(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first); // sets + 1
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await app.settle(tester);
    expect(find.text('4 × 8 · 2:00 rest'), findsOneWidget);
  });

  testWidgets('settings switch the theme and explain sync availability', (tester) async {
    final app = TestApp();
    await app.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await app.settle(tester);

    expect(find.text('Not configured'), findsOneWidget);
    MaterialApp materialApp() => tester.widget(find.byType(MaterialApp));
    expect(materialApp().themeMode, ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await app.settle(tester);
    expect(materialApp().themeMode, ThemeMode.dark);

    await tester.tap(find.text('Light'));
    await app.settle(tester);
    expect(materialApp().themeMode, ThemeMode.light);
  });

  testWidgets('enabling cloud sync from settings', (tester) async {
    final backend = FakeCloudBackend();
    final app = TestApp(backend: backend);
    await app.pump(tester);
    await tester.tap(find.byTooltip('Settings'));
    await app.settle(tester);

    expect(find.text('Back up and sync your training with Firebase'), findsOneWidget);
    await tester.tap(find.text('Sync with Firebase'));
    await app.settle(tester);

    expect(backend.connections, 1);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.textContaining('Last synced today'), findsOneWidget);
    expect(backend.store.collections['programs'], hasLength(1));
  });
}
