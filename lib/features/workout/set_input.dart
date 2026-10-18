import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';

const rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];

/// Column widths shared by the set rows and their header.
abstract final class SetColumns {
  static const index = 28.0;
  static const rpe = 46.0;
  static const action = 44.0;
}

double? parseWeight(String text) {
  final value = double.tryParse(text.replaceAll(',', '.').trim());
  return value == null || value < 0 ? null : value;
}

/// Quick entry row for the next set: weight, reps, RPE and a log button,
/// with one-tap increments underneath.
class SetInputRow extends StatefulWidget {
  const SetInputRow({
    super.key,
    required this.setNumber,
    required this.onLog,
    this.initialWeight,
    this.initialReps,
    this.initialRpe,
    this.hint,
  });

  final int setNumber;
  final double? initialWeight;
  final int? initialReps;
  final double? initialRpe;
  final String? hint;
  final void Function(double weight, int reps, double? rpe) onLog;

  @override
  State<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends State<SetInputRow> {
  late final _weight = TextEditingController(
    text: widget.initialWeight == null ? '' : formatWeight(widget.initialWeight!, unit: false),
  );
  late final _reps = TextEditingController(text: widget.initialReps?.toString() ?? '');
  late double? _rpe = widget.initialRpe;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  bool get _valid => parseWeight(_weight.text) != null && (int.tryParse(_reps.text) ?? 0) > 0;

  void _bumpWeight(double delta) {
    final current = parseWeight(_weight.text) ?? 0;
    final next = (current + delta).clamp(0, 9999).toDouble();
    setState(() => _weight.text = formatWeight(next, unit: false));
  }

  void _bumpReps(int delta) {
    final current = int.tryParse(_reps.text) ?? 0;
    setState(() => _reps.text = '${(current + delta).clamp(0, 999)}');
  }

  void _submit() {
    if (!_valid) return;
    HapticFeedback.mediumImpact();
    widget.onLog(parseWeight(_weight.text)!, int.parse(_reps.text), _rpe);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: SetColumns.index,
                child: Text(
                  '${widget.setNumber}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 5,
                child: _NumberField(
                  key: const Key('weight-field'),
                  controller: _weight,
                  label: 'kg',
                  hint: widget.hint,
                  decimal: true,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 4,
                child: _NumberField(
                  key: const Key('reps-field'),
                  controller: _reps,
                  label: 'reps',
                  onChanged: () => setState(() {}),
                  onSubmitted: _submit,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: SetColumns.rpe,
                child: _RpeButton(value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: SetColumns.action,
                height: 48,
                child: IconButton.filled(
                  key: const Key('log-set'),
                  tooltip: 'Log set',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _valid ? _submit : null,
                  icon: const Icon(Icons.check_rounded),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: SetColumns.index + 6, top: 2),
            child: Row(
              children: [
                _Bump('−2.5', () => _bumpWeight(-2.5)),
                _Bump('+2.5', () => _bumpWeight(2.5)),
                _Bump('+5', () => _bumpWeight(5)),
                const Spacer(),
                _Bump('−1', () => _bumpReps(-1)),
                _Bump('+1', () => _bumpReps(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
    this.decimal = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool decimal;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
        LengthLimitingTextInputFormatter(6),
      ],
      style: theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint ?? label,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      ),
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

class _RpeButton extends StatelessWidget {
  const _RpeButton({required this.value, required this.onChanged});

  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopupMenuButton<double>(
      key: const Key('rpe-button'),
      tooltip: 'RPE',
      initialValue: value,
      onSelected: (v) => onChanged(v < 0 ? null : v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: -1, child: Text('No RPE')),
        for (final v in rpeValues.reversed)
          PopupMenuItem(value: v, child: Text('RPE ${formatRpe(v)}  ·  ${_rirLabel(v)}')),
      ],
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value == null ? '–' : formatRpe(value),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: tabular,
                color: value == null ? scheme.onSurfaceVariant : null,
              ),
            ),
            Text(
              'RPE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rirLabel(double rpe) {
    final rir = 10 - rpe;
    if (rir == 0) return 'max effort';
    return '${formatRpe(rir)} rep${rir == 1 ? '' : 's'} left';
  }
}

class _Bump extends StatelessWidget {
  const _Bump(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(36, 32),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13),
      ),
      child: Text(label),
    );
  }
}
