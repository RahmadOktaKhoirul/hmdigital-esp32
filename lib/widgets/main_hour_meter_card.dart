import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';

class MainHourMeterCard extends StatelessWidget {
  const MainHourMeterCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mqtt = context.watch<MqttProvider>();
    final hours = mqtt.hmHours;
    final running = mqtt.engineRunning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF75FF9E), width: 4)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(Icons.history, size: 100, color: Colors.white.withValues(alpha: 0.05)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTAL OPERATION TIME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Color(0xFF859585),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    hours.toStringAsFixed(2),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'HOURS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      color: const Color(0xFF75FF9E).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: running ? const Color(0xFF00E676) : const Color(0xFF353534),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: running
                      ? [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.2), blurRadius: 20)]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      running ? Icons.bolt : Icons.pause_circle_outline,
                      color: running ? const Color(0xFF003918) : const Color(0xFF859585),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      running ? 'ENGINE RUNNING' : 'ENGINE STOPPED',
                      style: TextStyle(
                        color: running ? const Color(0xFF003918) : const Color(0xFF859585),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
