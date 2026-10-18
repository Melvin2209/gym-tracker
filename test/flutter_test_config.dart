import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real app font and Material icons so that widget tests (and the
/// screenshot generator) lay out text exactly like on a device.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  await testMain();
}

Future<void> loadAppFonts() async {
  final inter = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await inter.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (flutterRoot != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}
