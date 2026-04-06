import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';

class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    final conn = context.watch<MqttProvider>();
    final isConnected = conn.isConnected;
    final ip = conn.ip;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConnected
                ? const Color(0xFF3B4A3D).withValues(alpha: 0.3)
                : const Color(0xFF93000A).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF75FF9E),
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .fadeIn()
                  .fadeOut(delay: 500.ms)
            else
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFD40404),
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isConnected ? 'CONNECTED: $ip' : 'DISCONNECTED',
                key: ValueKey(isConnected),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isConnected
                      ? const Color(0xFFBACBB9)
                      : const Color(0xFFD40404),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
