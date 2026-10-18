import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../domain/progression.dart';

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.sessions, required this.metric});

  final List<SessionSummary> sessions;
  final ProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (sessions.length < 2) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'Log this exercise in at least two workouts to see a trend.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final origin = sessions.first.date;
    double x(DateTime d) => d.difference(origin).inHours / 24;
    final spots = [for (final s in sessions) FlSpot(x(s.date), s.value(metric))];
    final values = spots.map((s) => s.y);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.2).clamp(2.5, double.infinity);
    final span = spots.last.x - spots.first.x;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    String fmt(double v) => metric == ProgressMetric.volume
        ? formatVolume(v)
        : metric == ProgressMetric.totalReps
        ? '${v.round()}'
        : formatWeight(v, unit: false);

    return SizedBox(
      height: 220,
      child: LineChart(
        duration: const Duration(milliseconds: 300),
        LineChartData(
          minY: (minY - pad).clamp(0, double.infinity),
          maxY: maxY + pad,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => value == meta.max || value == meta.min
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(fmt(value), style: labelStyle),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: span <= 0 ? 1 : span / 3,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('d MMM').format(origin.add(Duration(hours: (value * 24).round()))),
                    style: labelStyle,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${fmt(s.y)} ${metric == ProgressMetric.volume ? '' : metric.unit}\n',
                    TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                    children: [
                      TextSpan(
                        text: formatDay(sessions[s.spotIndex].date),
                        style: TextStyle(
                          color: scheme.onInverseSurface.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: scheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                getDotPainter: (spot, _, _, i) => FlDotCirclePainter(
                  radius: i == spots.length - 1 ? 5 : 3,
                  color: scheme.primary,
                  strokeWidth: 2,
                  strokeColor: scheme.surfaceContainerLow,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.28),
                    scheme.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny trend line used in lists.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.width = 72, this.height = 28});

  final List<double> values;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    if (values.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final (i, v) in values.indexed) FlSpot(i.toDouble(), v)],
              isCurved: true,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
