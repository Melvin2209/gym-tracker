import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/shell/home_shell.dart';

class GymTrackerApp extends ConsumerWidget {
  const GymTrackerApp({super.key, this.home = const HomeShell()});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(settingsProvider.select((s) => s.value?.themeMode)) ?? ThemeMode.system;
    return MaterialApp(
      title: 'Gym Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: home,
    );
  }
}
