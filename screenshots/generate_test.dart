// Renders the real app with demo data and saves README screenshots and GIF
// frames. Run with:  ./tool/screenshots.sh
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/app.dart';
import 'package:gym_tracker/data/db/demo_data.dart';
import 'package:gym_tracker/data/repositories/settings_repository.dart';

import '../test/support/harness.dart';

const _out = 'build/screenshots';
final _boundary = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 400));
  final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<TestApp> _launch(WidgetTester tester, ThemeMode mode) async {
  final app = TestApp(now: DateTime(2026, 10, 18, 9, 30));
  await tester.runAsync(() async {
    await insertDemoHistory(app.db, now: app.clock.now, weeks: 10);
    await SettingsRepository(app.db).setThemeMode(mode);
  });
  // Touch devices never show keyboard focus rings.
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: app.overrides,
      child: RepaintBoundary(key: _boundary, child: const GymTrackerApp()),
    ),
  );
  await app.settle(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(app.db.close);
  });
  return app;
}

Future<void> _type(WidgetTester tester, TestApp app, Finder field, String text) async {
  await tester.enterText(field, text);
  FocusManager.instance.primaryFocus?.unfocus();
  await app.settle(tester);
}

Future<void> _logSet(WidgetTester tester, TestApp app, String weight, String reps) async {
  await _type(tester, app, find.byKey(const Key('weight-field')).first, weight);
  await _type(tester, app, find.byKey(const Key('reps-field')).first, reps);
  await tester.tap(find.byKey(const Key('log-set')).first);
  await app.settle(tester);
}

void main() {
  testWidgets('dark screenshots and logging GIF', (tester) async {
    final app = await _launch(tester, ThemeMode.dark);
    await _capture(tester, 'train_dark');

    // Start today's Push session.
    await tester.tap(find.byKey(const Key('start-day-day-starter-push')));
    await app.settle(tester);
    await _capture(tester, 'gif_00');

    // Frames for the GIF: adjust weight with the bump buttons, log, rest.
    var frame = 1;
    Future<void> gifFrame() => _capture(tester, 'gif_${(frame++).toString().padLeft(2, '0')}');
    for (final bump in ['+2.5', '+2.5']) {
      await tester.tap(find.text(bump).first);
      await tester.pump();
      await gifFrame();
    }
    await tester.tap(find.byKey(const Key('rpe-button')).first);
    await app.settle(tester);
    await gifFrame();
    await tester.tap(find.textContaining('RPE 8 ').last);
    await app.settle(tester);
    await gifFrame();
    await tester.tap(find.byKey(const Key('log-set')).first);
    await app.settle(tester);
    await gifFrame();
    for (var i = 0; i < 4; i++) {
      app.clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await gifFrame();
    }
    await tester.tap(find.text('+15'));
    await tester.pump(const Duration(milliseconds: 300));
    await gifFrame();
    app.clock.advance(const Duration(minutes: 2));
    await tester.tap(find.byTooltip('Skip rest'));
    await app.settle(tester);
    await gifFrame();

    // Build up a realistic session for the still screenshot.
    await _logSet(tester, app, '85', '5');
    await tester.tap(find.byTooltip('Skip rest'));
    await app.settle(tester);
    await _logSet(tester, app, '85', '5');
    app.clock.advance(const Duration(seconds: 47));
    await tester.pump(const Duration(milliseconds: 300));
    await _capture(tester, 'workout_dark');

    // Progress of the bench press.
    await tester.pageBack();
    await app.settle(tester);
    await tester.tap(find.text('Progress'));
    await app.settle(tester);
    await _capture(tester, 'progress_list_dark');
    await tester.enterText(find.widgetWithText(TextField, 'Search exercises'), 'Bench');
    await app.settle(tester);
    await tester.tap(find.text('Bench Press'));
    await app.settle(tester);
    await _capture(tester, 'exercise_dark');
  });

  testWidgets('light screenshots', (tester) async {
    final app = await _launch(tester, ThemeMode.light);
    await _capture(tester, 'train_light');

    await tester.tap(find.text('Programs'));
    await app.settle(tester);
    await _capture(tester, 'programs_light');

    await tester.tap(find.text('History'));
    await app.settle(tester);
    await _capture(tester, 'history_light');

    // A finished workout with new records.
    await tester.tap(find.text('Train'));
    await app.settle(tester);
    await tester.tap(find.byKey(const Key('start-day-day-starter-legs')));
    await app.settle(tester);
    await _logSet(tester, app, '115', '7');
    await _logSet(tester, app, '115', '6');
    await _logSet(tester, app, '117.5', '5');
    await tester.tap(find.byTooltip('Skip rest'));
    await app.settle(tester);
    app.clock.advance(const Duration(minutes: 54));
    await tester.tap(find.byKey(const Key('finish-workout')));
    await app.settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish').last);
    await app.settle(tester);
    await _capture(tester, 'summary_light');

    await tester.tap(find.text('Done'));
    await app.settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await app.settle(tester);
    await _capture(tester, 'settings_light');
  });

  testWidgets('app icon', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(116),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A50), Color(0xFFE5532A)],
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.fitness_center,
            size: 300,
            color: Colors.white,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/icon.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
