import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../data/db/app_database.dart';
import '../workout/workout_providers.dart';

/// Bottom sheet to pick an exercise from the library, or create one.
Future<Exercise?> pickExercise(BuildContext context) => showModalBottomSheet<Exercise>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => const FractionallySizedBox(heightFactor: 0.9, child: ExercisePicker()),
);

class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';
  MuscleGroup? _group;

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exercisesProvider).value ?? const [];
    final filtered = exercises.where((e) {
      final matchesQuery = e.name.toLowerCase().contains(_query.toLowerCase());
      return matchesQuery && (_group == null || e.muscleGroup == _group);
    }).toList();
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: Text('Add exercise', style: theme.textTheme.titleLarge)),
              TextButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search exercises',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final group in [null, ...MuscleGroup.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(group?.label ?? 'All'),
                    selected: _group == group,
                    onSelected: (_) => setState(() => _group = group),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'No exercise found',
                  message: 'Create "$_query" as a custom exercise.',
                  action: FilledButton(onPressed: _create, child: const Text('Create exercise')),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    return ListTile(
                      leading: MuscleBadge(e.muscleGroup),
                      title: Text(e.name),
                      subtitle: Text('${e.muscleGroup.label} · ${_equipmentLabel(e.equipment)}'),
                      onTap: () => Navigator.pop(context, e),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (_) => CreateExerciseDialog(initialName: _query),
    );
    if (created != null && mounted) Navigator.pop(context, created);
  }
}

String _equipmentLabel(Equipment e) => e.name[0].toUpperCase() + e.name.substring(1);

class CreateExerciseDialog extends ConsumerStatefulWidget {
  const CreateExerciseDialog({super.key, this.initialName = ''});

  final String initialName;

  @override
  ConsumerState<CreateExerciseDialog> createState() => _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends ConsumerState<CreateExerciseDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  MuscleGroup _group = MuscleGroup.chest;
  Equipment _equipment = Equipment.barbell;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New exercise'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MuscleGroup>(
            initialValue: _group,
            decoration: const InputDecoration(labelText: 'Muscle group'),
            items: [
              for (final g in MuscleGroup.values) DropdownMenuItem(value: g, child: Text(g.label)),
            ],
            onChanged: (g) => setState(() => _group = g!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Equipment>(
            initialValue: _equipment,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: [
              for (final e in Equipment.values)
                DropdownMenuItem(value: e, child: Text(_equipmentLabel(e))),
            ],
            onChanged: (e) => setState(() => _equipment = e!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: _save,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final repo = ref.read(exerciseRepositoryProvider);
    final id = await repo.create(name: _name.text, muscleGroup: _group, equipment: _equipment);
    final exercise = await repo.watch(id).first;
    if (mounted) Navigator.pop(context, exercise);
  }
}
