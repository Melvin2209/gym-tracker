import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/theme.dart';
import 'package:gym_tracker/features/workout/set_input.dart';

void main() {
  Future<List<(double, int, double?)>> pump(
    WidgetTester tester, {
    double? weight,
    int? reps,
  }) async {
    final logged = <(double, int, double?)>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 340,
            child: SetInputRow(
              setNumber: 1,
              initialWeight: weight,
              initialReps: reps,
              onLog: (w, r, rpe) => logged.add((w, r, rpe)),
            ),
          ),
        ),
      ),
    );
    return logged;
  }

  IconButton logButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('log-set')));

  testWidgets('log is disabled until weight and reps are valid', (tester) async {
    final logged = await pump(tester);
    expect(logButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('weight-field')), '60');
    await tester.pump();
    expect(logButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('reps-field')), '0');
    await tester.pump();
    expect(logButton(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('reps-field')), '10');
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-set')));
    expect(logged, [(60.0, 10, null)]);
  });

  testWidgets('bump buttons adjust weight and reps', (tester) async {
    final logged = await pump(tester, weight: 100, reps: 5);
    await tester.tap(find.text('+5'));
    await tester.tap(find.text('+2.5'));
    await tester.tap(find.text('−1'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '107.5'), findsOneWidget);
    expect(find.widgetWithText(TextField, '4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rpe-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('RPE 9 ').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('log-set')));
    expect(logged, [(107.5, 4, 9.0)]);
  });

  testWidgets('accepts a comma as decimal separator', (tester) async {
    final logged = await pump(tester, reps: 8);
    await tester.enterText(find.byKey(const Key('weight-field')), '22,5');
    await tester.pump();
    await tester.tap(find.byKey(const Key('log-set')));
    expect(logged.single.$1, 22.5);
  });

  test('parseWeight', () {
    expect(parseWeight('80'), 80);
    expect(parseWeight(' 82,5 '), 82.5);
    expect(parseWeight(''), isNull);
    expect(parseWeight('-5'), isNull);
    expect(parseWeight('abc'), isNull);
  });
}
