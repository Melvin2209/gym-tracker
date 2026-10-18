import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'rest_timer_controller.dart';

/// Rest countdown docked at the bottom of the active workout.
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(restTimerProvider);
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: view.isActive ? _Panel(view: view) : const SizedBox(width: double.infinity),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.view});

  final RestTimerView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(restTimerProvider.notifier);
    final paused = view.timer.isPaused;

    return Material(
      key: const Key('rest-timer'),
      color: scheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1 - view.progress,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    ),
                    Icon(paused ? Icons.pause : Icons.timer_outlined, color: scheme.primary),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatClock(view.remaining),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontFeatures: tabular,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      view.nextUp == null ? 'Rest' : 'Next: ${view.nextUp}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _RoundButton(
                label: '-15',
                onTap: () => controller.adjust(const Duration(seconds: -15)),
              ),
              _RoundButton(
                label: '+15',
                onTap: () => controller.adjust(const Duration(seconds: 15)),
              ),
              IconButton(
                tooltip: paused ? 'Resume' : 'Pause',
                onPressed: controller.togglePause,
                icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              ),
              IconButton.filled(
                tooltip: 'Skip rest',
                onPressed: controller.skip,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ),
    );
  }
}
