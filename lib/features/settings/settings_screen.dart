import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/db/demo_data.dart';
import '../../services/sync/sync_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final repo = ref.read(settingsRepositoryProvider);
    final theme = Theme.of(context);
    if (settings == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('Appearance'),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => repo.setThemeMode(s.first),
          ),
          const SectionHeader('Rest timer'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Default rest'),
                  subtitle: const Text('For exercises added outside a program'),
                  trailing: DropdownButton<int>(
                    value: settings.defaultRestSeconds,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in const [30, 45, 60, 90, 120, 150, 180, 240, 300])
                        DropdownMenuItem(
                          value: s,
                          child: Text(formatClock(Duration(seconds: s))),
                        ),
                    ],
                    onChanged: (v) => repo.setDefaultRest(v!),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Notify when rest is over'),
                  subtitle: const Text('Works with the screen off'),
                  value: settings.restNotifications,
                  onChanged: repo.setRestNotifications,
                ),
              ],
            ),
          ),
          const SectionHeader('Cloud sync'),
          const _SyncCard(),
          const SectionHeader('About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Offline first'),
                  subtitle: Text(
                    'Everything is stored on this device in a local SQLite database. '
                    'Cloud sync is optional.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Load demo data'),
                  subtitle: Text(
                    'Adds 10 weeks of sample workouts to explore charts and records',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Load demo data?',
                      message: 'Sample workouts are added to your history.',
                      action: 'Load',
                    );
                    if (!ok) return;
                    await insertDemoHistory(
                      ref.read(databaseProvider),
                      now: ref.read(clockProvider)(),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Demo workouts added')));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final controller = ref.read(syncControllerProvider.notifier);
    final theme = Theme.of(context);

    if (status.phase == SyncPhase.unavailable) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Not configured'),
          subtitle: Text(
            'This build has no Firebase project. See the README to enable sync with '
            '--dart-define-from-file.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    final enabled = status.phase != SyncPhase.disabled;
    final subtitle = switch (status.phase) {
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.error => 'Sync failed: ${status.message}',
      _ when status.lastSyncedAt != null =>
        'Last synced ${formatRelativeDay(status.lastSyncedAt!).toLowerCase()} at '
            '${TimeOfDay.fromDateTime(status.lastSyncedAt!).format(context)}',
      _ => 'Back up and sync your training with Firebase',
    };

    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Sync with Firebase'),
            subtitle: Text(subtitle),
            value: enabled,
            onChanged: controller.setEnabled,
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: status.phase == SyncPhase.syncing ? null : controller.syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
