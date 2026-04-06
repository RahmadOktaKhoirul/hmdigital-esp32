import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import '../screens/operation_history_screen.dart';

class WeeklyOperationChart extends StatelessWidget {
  const WeeklyOperationChart({super.key});

  static const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _daysFull  = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  @override
  Widget build(BuildContext context) {
    final data = context.select<MqttProvider, List<DailyOperationEntry>>(
      (m) => m.last7Days,
    );

    final maxHours = data.map((e) => e.hours).fold(0.0, (a, b) => a > b ? a : b);
    final totalHours = data.fold(0.0, (sum, e) => sum + e.hours);

    DailyOperationEntry? topDay;
    DailyOperationEntry? lowDay;
    final nonZero = data.where((e) => e.hours > 0).toList();
    if (nonZero.isNotEmpty) {
      topDay = nonZero.reduce((a, b) => a.hours > b.hours ? a : b);
      lowDay = nonZero.reduce((a, b) => a.hours < b.hours ? a : b);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B4A3D).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4, height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF75FF9E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WEEKLY OPERATION',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        'Total: ${totalHours.toStringAsFixed(1)} h this week',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF859585)),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OperationHistoryScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF75FF9E).withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Text('SEE MORE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF75FF9E), letterSpacing: 1)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 10, color: Color(0xFF75FF9E)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar chart
          SizedBox(
            height: 130,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, _) {
                        final i = val.toInt();
                        if (i < 0 || i >= 7) return const SizedBox.shrink();
                        final d = data[i].date;
                        final now = DateTime.now();
                        final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            children: [
                              Text(
                                _dayLabels[d.weekday - 1],
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isToday ? const Color(0xFF75FF9E) : const Color(0xFF859585),
                                ),
                              ),
                              Text(
                                '${d.day}/${d.month}',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: isToday
                                      ? const Color(0xFF75FF9E).withValues(alpha: 0.7)
                                      : const Color(0xFF859585).withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (i) {
                  final h = data[i].hours;
                  final isTop = topDay != null && data[i].date == topDay.date;
                  final isEmpty = h == 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: isEmpty ? 0.15 : h,
                        color: isEmpty
                            ? const Color(0xFF2A2A2A)
                            : isTop
                                ? const Color(0xFF75FF9E)
                                : const Color(0xFF75FF9E).withValues(alpha: 0.4),
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                      ),
                    ],
                  );
                }),
                maxY: maxHours > 0 ? maxHours * 1.3 : 1,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2A2A2A),
                    getTooltipItem: (group, _, rod, __) {
                      final h = data[group.x].hours;
                      if (h == 0) return null;
                      final d = data[group.x].date;
                      return BarTooltipItem(
                        '${h.toStringAsFixed(2)} h\n',
                        GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF75FF9E),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: '${_daysFull[d.weekday - 1]}, ${d.day}/${d.month}',
                            style: const TextStyle(color: Color(0xFF859585), fontSize: 10),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top day & Low day — wrap agar tidak overflow
          if (topDay != null) ...[
            const Divider(color: Color(0xFF2A2A2A)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _StatRow(
                  icon: Icons.arrow_upward,
                  iconColor: const Color(0xFF75FF9E),
                  label: 'HIGHEST',
                  day: '${_dayLabels[topDay.date.weekday - 1]}, ${topDay.date.day}/${topDay.date.month}',
                  hours: topDay.hours,
                ),
                if (lowDay != null && lowDay.date != topDay.date)
                  _StatRow(
                    icon: Icons.arrow_downward,
                    iconColor: const Color(0xFFFFB6B1),
                    label: 'LOWEST',
                    day: '${_dayLabels[lowDay.date.weekday - 1]}, ${lowDay.date.day}/${lowDay.date.month}',
                    hours: lowDay.hours,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String day;
  final double hours;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.day,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF859585), letterSpacing: 1)),
              Text(
                '$day  •  ${hours.toStringAsFixed(2)} h',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
