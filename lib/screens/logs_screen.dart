import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import '../widgets/log_item.dart';
import 'package:google_fonts/google_fonts.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        elevation: 0,
        title: Text(
          'ACTIVITY HISTORY',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Selector<MqttProvider, (bool, String)>(
              selector: (_, m) => (m.isConnected, m.ip),
              builder: (_, data, __) {
                final (connected, ip) = data;
                return Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: connected
                            ? const Color(0xFF75FF9E)
                            : const Color(0xFFD40404),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected ? ip : 'DISCONNECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: connected
                            ? const Color(0xFF75FF9E)
                            : const Color(0xFFD40404),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: const Color(0xFF0E0E0E),
            child: Row(
              children: [
                Selector<MqttProvider, int>(
                  selector: (_, m) => m.logs.length,
                  builder: (_, count, __) => Text(
                    'SHOWING $count EVENTS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF859585),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Selector<MqttProvider, List<LogEntry>>(
              selector: (_, m) => m.logs,
              builder: (_, logs, __) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No events yet.\nConnect to MQTT broker to receive logs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF859585), height: 1.6),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return LogItem(log: log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
