import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/format.dart';

void main() {
  test('formatWeight trims useless decimals', () {
    expect(formatWeight(100), '100 kg');
    expect(formatWeight(82.5), '82.5 kg');
    expect(formatWeight(31.25), '31.25 kg');
    expect(formatWeight(0), '0 kg');
    expect(formatWeight(20.0, unit: false), '20');
  });

  test('formatVolume', () {
    expect(formatVolume(950), '950 kg');
    expect(formatVolume(4250.4), '4,250 kg');
    expect(formatVolume(12500), '12.5 t');
  });

  test('formatRpe', () {
    expect(formatRpe(null), '');
    expect(formatRpe(8), '8');
    expect(formatRpe(7.5), '7.5');
  });

  test('formatClock and formatDuration', () {
    expect(formatClock(const Duration(seconds: 90)), '1:30');
    expect(formatClock(const Duration(seconds: 5)), '0:05');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 5)), '1:02:05');
    expect(formatDuration(const Duration(minutes: 10)), '10m');
    expect(formatDuration(const Duration(minutes: 75)), '1h 15m');
    expect(formatDuration(const Duration(hours: 2)), '2h');
  });

  test('formatRelativeDay', () {
    final now = DateTime(2026, 10, 18, 9); // a Sunday
    expect(formatRelativeDay(DateTime(2026, 10, 18, 7), now: now), 'Today');
    expect(formatRelativeDay(DateTime(2026, 10, 17, 22), now: now), 'Yesterday');
    expect(formatRelativeDay(DateTime(2026, 10, 14), now: now), 'Wednesday');
    expect(formatRelativeDay(DateTime(2026, 9, 1), now: now), 'Tue 1 Sep');
  });
}
