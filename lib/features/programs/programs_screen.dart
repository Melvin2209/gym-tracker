import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/program_repository.dart';
import '../workout/workout_providers.dart';
import 'program_detail_screen.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-program',
        onPressed: () async {
          final name = await showTextPrompt(
            context,
            title: 'New program',
            hint: 'e.g. Upper / Lower',
            action: 'Create',
          );
          if (name == null) return;
          final id = await ref.read(programRepositoryProvider).createProgram(name);
          if (context.mounted) _open(context, id);
        },
        icon: const Icon(Icons.add),
        label: const Text('Program'),
      ),
      body: programs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (programs) => programs.isEmpty
            ? const EmptyState(
                icon: Icons.calendar_view_week,
                title: 'No programs',
                message: 'Create a program to plan your sessions and start them in one tap.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: programs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ProgramCard(
                  program: programs[i],
                  onTap: () => _open(context, programs[i].program.id),
                ),
              ),
      ),
    );
  }

  void _open(BuildContext context, String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => ProgramDetailScreen(programId: id)),
  );
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, required this.onTap});

  final ProgramDetail program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exerciseCount = program.days.fold(0, (sum, d) => sum + d.exercises.length);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(program.program.name, style: theme.textTheme.titleLarge)),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              if (program.program.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  program.program.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final day in program.days)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${day.day.name} · ${day.exercises.length}'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${program.days.length} day${program.days.length == 1 ? '' : 's'} · $exerciseCount exercises',
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
