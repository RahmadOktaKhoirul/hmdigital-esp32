import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';

class OperationHistoryScreen extends StatefulWidget {
  const OperationHistoryScreen({super.key});

  @override
  State<OperationHistoryScreen> createState() => _OperationHistoryScreenState();
}

class _OperationHistoryScreenState extends State<OperationHistoryScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to   = DateTime.now();

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF75FF9E),
            onPrimary: Color(0xFF003918),
            surface: Color(0xFF2A2A2A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.select<MqttProvider, List<DailyOperationEntry>>(
      (m) => m.getRange(_from, _to),
    );

    final totalHours = data.fold(0.0, (sum, e) => sum + e.hours);
    final maxHours   = data.map((e) => e.hours).fold(0.0, (a, b) => a > b ? a : b);
    final nonZero    = data.where((e) => e.hours > 0).toList();
    final topDay     = nonZero.isNotEmpty ? nonZero.reduce((a, b) => a.hours > b.hours ? a : b) : null;
    final lowDay     = nonZero.length > 1 ? nonZero.reduce((a, b) => a.hours < b.hours ? a : b) : null;
    final avgHours   = nonZero.isNotEmpty ? totalHours / nonZero.length : 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF75FF9E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'OPERATION HISTORY',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.05), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Date range picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _DateButton(label: 'FROM', date: _from, onTap: () => _pickDate(isFrom: true))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, size: 16, color: Color(0xFF859585)),
                ),
                Expanded(child: _DateButton(label: 'TO', date: _to, onTap: () => _pickDate(isFrom: false))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary cards
          Row(
            children: [
              Expanded(child: _SummaryCard(
                label: 'TOTAL HOURS',
                value: '${totalHours.toStringAsFixed(2)} h',
                icon: Icons.timer_outlined,
                color: const Color(0xFF75FF9E),
              )),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(
                label: 'AVG / DAY',
                value: '${avgHours.toStringAsFixed(2)} h',
                icon: Icons.bar_chart,
                color: const Color(0xFFBACBB9),
              )),
            ],
          ),
          const SizedBox(height: 12),
          if (topDay != null)
            Row(
              children: [
                Expanded(child: _SummaryCard(
                  label: 'HIGHEST DAY',
                  value: '${_fmt(topDay.date)}  •  ${topDay.hours.toStringAsFixed(2)} h',
                  icon: Icons.arrow_upward,
                  color: const Color(0xFF75FF9E),
                )),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(
                  label: 'LOWEST DAY',
                  value: lowDay != null ? '${_fmt(lowDay.date)}  •  ${lowDay.hours.toStringAsFixed(2)} h' : '-',
                  icon: Icons.arrow_downward,
                  color: const Color(0xFFFFB6B1),
                )),
              ],
            ),
          const SizedBox(height: 20),

          // Chart — horizontal scroll agar tidak overflow
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B4A3D).withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY BREAKDOWN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF859585)),
                ),
                const SizedBox(height: 16),
                if (data.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No data', style: TextStyle(color: Color(0xFF859585))),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: data.length <= 10
                          ? MediaQuery.of(context).size.width - 80
                          : data.length * 38.0,
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF2A2A2A), strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (val, _) => Text(
                                  val.toStringAsFixed(0),
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF859585)),
                                ),
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget: (val, _) {
                                  final i = val.toInt();
                                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      '${data[i].date.day}/${data[i].date.month}',
                                      style: const TextStyle(fontSize: 9, color: Color(0xFF859585)),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(data.length, (i) {
                            final h     = data[i].hours;
                            final isTop = topDay != null && data[i].date == topDay.date;
                            return BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: h == 0 ? 0.1 : h,
                                  color: h == 0
                                      ? const Color(0xFF2A2A2A)
                                      : isTop
                                          ? const Color(0xFF75FF9E)
                                          : const Color(0xFF75FF9E).withValues(alpha: 0.45),
                                  width: 20,
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
                                      text: '${d.day}/${d.month}/${d.year}',
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
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // List detail
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF859585), letterSpacing: 1.5))),
                      Text('HOURS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF859585), letterSpacing: 1.5)),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 1),
                ...data.reversed.map((e) => _DayRow(
                  entry: e,
                  isTop: topDay?.date == e.date,
                  isLow: lowDay?.date == e.date,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF353534), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF859585), letterSpacing: 1)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: Color(0xFF75FF9E)),
                const SizedBox(width: 6),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF859585), letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DailyOperationEntry entry;
  final bool isTop;
  final bool isLow;
  const _DayRow({required this.entry, required this.isTop, required this.isLow});

  @override
  Widget build(BuildContext context) {
    final d       = entry.date;
    final hasData = entry.hours > 0;
    final color   = isTop
        ? const Color(0xFF75FF9E)
        : isLow
            ? const Color(0xFFFFB6B1)
            : hasData ? Colors.white : const Color(0xFF859585);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                  style: TextStyle(fontSize: 12, color: hasData ? Colors.white : const Color(0xFF859585)),
                ),
                if (isTop) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF75FF9E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('TOP', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF75FF9E), letterSpacing: 1)),
                  ),
                ],
                if (isLow) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB6B1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('LOW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFFFB6B1), letterSpacing: 1)),
                  ),
                ],
              ],
            ),
          ),
          Text(
            hasData ? '${entry.hours.toStringAsFixed(2)} h' : '—',
            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
