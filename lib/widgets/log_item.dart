import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/mqtt_provider.dart';

class LogItem extends StatelessWidget {
  final LogEntry log;

  const LogItem({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(log.event);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cfg.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      log.event,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cfg.color,
                        letterSpacing: 1,
                      ),
                    ),
                    if (log.isLocal) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF353534),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LOCAL',
                          style: TextStyle(fontSize: 8, color: Color(0xFF859585), letterSpacing: 1),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(log.timestamp, style: const TextStyle(fontSize: 11, color: Color(0xFF859585))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${log.prevHmHours.toStringAsFixed(2)} H',
                style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                cfg.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cfg.color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _LogConfig _config(String event) {
    if (event == 'RESET') {
      return _LogConfig(
        icon: Icons.delete_forever,
        color: const Color(0xFFFFB6B1),
        borderColor: const Color(0xFF93000A).withValues(alpha: 0.3),
        status: 'FORCE RESET',
      );
    } else if (event == 'ADJUST') {
      return _LogConfig(
        icon: Icons.tune,
        color: const Color(0xFF75FF9E),
        borderColor: Colors.transparent,
        status: 'CALIBRATED',
      );
    } else if (event.startsWith('SPEED')) {
      return _LogConfig(
        icon: Icons.speed,
        color: const Color(0xFFBACBB9),
        borderColor: Colors.transparent,
        status: 'UPDATED',
      );
    } else if (event == 'BOOT') {
      return _LogConfig(
        icon: Icons.power_settings_new,
        color: const Color(0xFF75FF9E),
        borderColor: Colors.transparent,
        status: 'BOOT',
      );
    }
    return _LogConfig(
      icon: Icons.sync,
      color: const Color(0xFF75FF9E),
      borderColor: Colors.transparent,
      status: 'OK',
    );
  }
}

class _LogConfig {
  final IconData icon;
  final Color color;
  final Color borderColor;
  final String status;
  const _LogConfig({required this.icon, required this.color, required this.borderColor, required this.status});
}
