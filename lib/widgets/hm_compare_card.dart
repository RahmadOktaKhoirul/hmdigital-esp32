import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';

class HmCompareCard extends StatelessWidget {
  const HmCompareCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HmCell(
              label: 'PREVIOUS HM',
              sublabel: 'Nilai sebelum reset',
              hours: mqtt.prevHmHours,
              icon: Icons.history_rounded,
              color: const Color(0xFF859585),
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFF353534)),
          Expanded(
            child: _HmCell(
              label: 'CURRENT HM',
              sublabel: 'Nilai berjalan',
              hours: mqtt.currentHmHours,
              icon: Icons.timer_rounded,
              color: const Color(0xFF75FF9E),
            ),
          ),
        ],
      ),
    );
  }
}

class _HmCell extends StatelessWidget {
  final String label;
  final String sublabel;
  final double hours;
  final IconData icon;
  final Color color;

  const _HmCell({
    required this.label,
    required this.sublabel,
    required this.hours,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF353534),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF859585),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(fontSize: 8, color: Color(0xFF859585)),
                ),
                Text(
                  '${hours.toStringAsFixed(2)} h',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
