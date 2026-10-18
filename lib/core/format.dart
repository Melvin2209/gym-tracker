import 'package:intl/intl.dart';

String formatWeight(double kg, {bool unit = true}) {
  final text = kg.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return unit ? '$text kg' : text;
}

/// Estimates are not that precise: one decimal is plenty.
String formatEstimate(double kg) => formatWeight((kg * 10).round() / 10);

String formatVolume(double kg) {
  if (kg >= 10000) return '${(kg / 1000).toStringAsFixed(1)} t';
  return '${NumberFormat.decimalPattern().format(kg.round())} kg';
}

String formatRpe(double? rpe) {
  if (rpe == null) return '';
  return rpe == rpe.roundToDouble() ? rpe.toStringAsFixed(0) : rpe.toStringAsFixed(1);
}

/// 90s -> "1:30", 3725s -> "1:02:05".
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// 4500s -> "1h 15m", 600s -> "10m".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${d.inMinutes}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String formatDay(DateTime date) => DateFormat('EEE d MMM').format(date);

String formatRelativeDay(DateTime date, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final day = _dateOnly(date);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEEE').format(date);
  return formatDay(date);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
