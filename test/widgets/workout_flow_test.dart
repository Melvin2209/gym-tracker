import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/workout/active_workout_screen.dart';

import '../support/harness.dart';

void main() {
  testWidgets('start a program day, log a set, rest, and finish', (tester) async {
    final app = TestApp();
    await app.pump(tester);

    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Push / Pull / Legs'), findsOneWidget);

    // Start "Push" from the home screen.
    await tester.tap(find.byKey(const Key('start-day-day-starter-push')));
    await app.settle(tester);
    expect(find.byType(ActiveWorkoutScreen), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('0/4 sets · 6 reps · 3:00 rest'), findsOneWidget);

    // The finish button is disabled until a set is logged.
    final finish = find.byKey(const Key('finish-workout'));
    expect(tester.widget<FilledButton>(finish).onPressed, isNull);

    // Quick entry: reps are prefilled from the target, type a weight.
    final weight = find.byKey(const Key('weight-field')).first;
    await tester.enterText(weight, '80');
    await tester.tap(find.text('+2.5').first);
    await tester.pump();
    expect(find.widgetWithText(TextField, '82.5'), findsOneWidget);

    await tester.tap(find.byKey(const Key('log-set')).first);
    await app.settle(tester);

    expect(find.text('82.5 × 6'), findsOneWidget);
    expect(find.text('1/4 sets · 6 reps · 3:00 rest'), findsOneWidget);
    // Next set is prefilled with the same numbers.
    expect(find.widgetWithText(TextField, '82.5'), findsOneWidget);

    // The rest timer starts with the exercise's rest and schedules an alert.
    expect(find.byKey(const Key('rest-timer')), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('Next: Bench Press · set 2'), findsOneWidget);
    expect(app.alarm.scheduled, [const Duration(minutes: 3)]);

    app.clock.advance(const Duration(seconds: 70));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1:50'), findsOneWidget);

    await tester.tap(find.text('+15'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2:05'), findsOneWidget);

    await tester.tap(find.byTooltip('Skip rest'));
    await app.settle(tester);
    expect(find.byKey(const Key('rest-timer')), findsNothing);

    // Finish and see the summary.
    app.clock.advance(const Duration(minutes: 40));
    await tester.tap(finish);
    await app.settle(tester);
    expect(find.text('Finish workout?'), findsOneWidget);
    expect(find.textContaining('4 exercises without sets will be skipped'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish').last);
    await app.settle(tester);

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Session saved. Consistency builds strength.'), findsOneWidget);
    expect(find.text('41m'), findsOneWidget);
    expect(find.text('495 kg'), findsWidgets);

    await tester.tap(find.text('Done'));
    await app.settle(tester);
    expect(find.text('LAST WORKOUT'), findsOneWidget);
    expect(find.text('Push'), findsWidgets);
  });

  testWidgets('empty workout: add an exercise and edit a set', (tester) async {
    final app = TestApp();
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('start-empty')));
    await app.settle(tester);
    expect(find.text('Empty workout'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-exercise')));
    await app.settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search exercises'), 'dead');
    await tester.pump();
    expect(find.text('Romanian Deadlift'), findsOneWidget);
    await tester.tap(find.text('Deadlift'));
    await app.settle(tester);

    await tester.enterText(find.byKey(const Key('weight-field')), '140');
    await tester.enterText(find.byKey(const Key('reps-field')), '5');
    await tester.tap(find.byKey(const Key('rpe-button')));
    await app.settle(tester);
    await tester.tap(find.textContaining('RPE 8.5').last);
    await app.settle(tester);
    await tester.tap(find.byKey(const Key('log-set')));
    await app.settle(tester);
    expect(find.text('140 × 5'), findsOneWidget);
    expect(find.text('8.5'), findsWidgets);

    // Edit the logged set.
    await tester.tap(find.text('140 × 5'));
    await app.settle(tester);
    expect(find.text('Edit set'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '5').last, '4');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await app.settle(tester);
    expect(find.text('140 × 4'), findsOneWidget);

    // Discard the workout.
    await tester.tap(
      find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)),
    );
    await app.settle(tester);
    await tester.tap(find.text('Discard workout'));
    await app.settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await app.settle(tester);
    expect(find.byType(ActiveWorkoutScreen), findsNothing);
    expect(find.byKey(const Key('start-empty')), findsOneWidget);
  });
}
