import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/detection_model.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/utils/widgets.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(detectionStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(detectionStatsProvider),
          ),
        ],
      ),
      body: stats.when(
        data: (s) => _StatsBody(stats: s),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => EmptyState(
          icon: Icons.bar_chart_outlined,
          title: 'Failed to load statistics',
          subtitle: e.toString(),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final DetectionStats stats;
  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) {
      return const EmptyState(
        icon: Icons.bar_chart_outlined,
        title: 'No data yet',
        subtitle: 'Statistics will appear after detections are saved.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top numbers ──
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total Detections',
                  value: '${stats.total}',
                  icon: Icons.radar_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Critical (STOP)',
                  value: '${stats.byAlertLevel[AlertLevel.stop] ?? 0}',
                  icon: Icons.cancel_rounded,
                  color: AppColors.stop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Warnings',
                  value: '${stats.byAlertLevel[AlertLevel.notify] ?? 0}',
                  icon: Icons.warning_rounded,
                  color: AppColors.notify,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Healthy',
                  value: '${stats.byAlertLevel[AlertLevel.ok] ?? 0}',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.ok,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Last 7 days chart ──
          const SectionHeader(title: 'DETECTIONS — LAST 7 DAYS'),
          const SizedBox(height: 16),
          InfoCard(
            padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
            child: SizedBox(
              height: 180,
              child: _BarChart(days: stats.last7Days),
            ),
          ),
          const SizedBox(height: 28),

          // ── By class pie chart ──
          if (stats.byClass.isNotEmpty) ...[
            const SectionHeader(title: 'BY DEFECT CLASS'),
            const SizedBox(height: 16),
            InfoCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: _PieChart(byClass: stats.byClass),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PieLegend(byClass: stats.byClass),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Alert level breakdown ──
          const SectionHeader(title: 'ALERT LEVEL BREAKDOWN'),
          const SizedBox(height: 16),
          InfoCard(
            child: _AlertBreakdown(
              byAlert: stats.byAlertLevel,
              total: stats.total,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Bar chart ──────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<DayCount> days;
  const _BarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final maxY = days.fold<int>(0, (m, d) => d.count > m ? d.count : m) + 1;

    return BarChart(
      BarChartData(
        maxY: maxY.toDouble(),
        barGroups: days.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.count.toDouble(),
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 20,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY.toDouble(),
                  color: AppColors.surfaceLight,
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= days.length) return const SizedBox();
                return Text(
                  DateFormat('E').format(days[idx].date),
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (val, _) => Text(
                val.toInt().toString(),
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.divider,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.surfaceLight,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${rod.toY.toInt()} detection${rod.toY != 1 ? 's' : ''}',
              const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pie chart ──────────────────────────────────

class _PieChart extends StatelessWidget {
  final Map<String, int> byClass;
  const _PieChart({required this.byClass});

  @override
  Widget build(BuildContext context) {
    final total = byClass.values.fold(0, (a, b) => a + b);
    final sections = byClass.entries.map((e) {
      final pct = e.value / total;
      return PieChartSectionData(
        value: pct * 100,
        color: DefectInfo.color(e.key),
        radius: 50,
        title: '${(pct * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 36,
        sectionsSpace: 3,
      ),
    );
  }
}

class _PieLegend extends StatelessWidget {
  final Map<String, int> byClass;
  const _PieLegend({required this.byClass});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: byClass.entries.map((e) {
        final color = DefectInfo.color(e.key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key.replaceAll('_', ' '),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${e.value} detection${e.value != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Alert breakdown ────────────────────────────

class _AlertBreakdown extends StatelessWidget {
  final Map<String, int> byAlert;
  final int total;

  const _AlertBreakdown({required this.byAlert, required this.total});

  @override
  Widget build(BuildContext context) {
    final levels = [AlertLevel.stop, AlertLevel.notify, AlertLevel.ok];
    final labels = ['STOP — Critical', 'NOTIFY — Warning', 'CONTINUE — OK'];

    return Column(
      children: List.generate(levels.length, (i) {
        final count = byAlert[levels[i]] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        final color = AlertLevel.color(levels[i]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$count (${(pct * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceLight,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
