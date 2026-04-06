import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class FuelConsumptionChart extends StatelessWidget {
  const FuelConsumptionChart({super.key});

  // Pre-computed — never changes, no need to rebuild every frame
  static final List<BarChartGroupData> _bars = List.generate(
    15,
    (i) => BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: (i % 5 + 3).toDouble(),
          color: const Color(0xFF75FF9E).withValues(alpha: 0.2 + (i / 15) * 0.6),
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(2),
          ),
        ),
      ],
    ),
  );

  static final _chartData = BarChartData(
    gridData: const FlGridData(show: false),
    titlesData: const FlTitlesData(show: false),
    borderData: FlBorderData(show: false),
    barGroups: _bars,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B4A3D).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FUEL LEVEL CONSUMPTION',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        'Real-time analysis active',
                        style: TextStyle(fontSize: 10, color: Color(0xFF859585)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF353534),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE STREAM',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF75FF9E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 120, child: BarChart(_chartData)),
        ],
      ),
    );
  }
}
