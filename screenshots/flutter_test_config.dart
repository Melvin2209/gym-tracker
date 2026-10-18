import 'dart:async';

import '../test/flutter_test_config.dart' as base;

Future<void> testExecutable(FutureOr<void> Function() testMain) => base.testExecutable(testMain);
