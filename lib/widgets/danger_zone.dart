import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import 'app_ui.dart';

class DangerZone extends StatelessWidget {
  const DangerZone({super.key});

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await AppUI.showConfirmDialog(
      context,
      title: 'Konfirmasi Reset',
      subtitle: 'Tindakan ini akan menghapus secara permanen semua jam operasional kumulatif:',
      highlight: 'Machine 1 — Hour Meter → 0.00 h',
      warningText: 'Tindakan ini tidak dapat dibatalkan. Pastikan Anda telah mencatat data sebelumnya.',
      confirmLabel: 'YA, RESET',
    );

    if (!confirmed || !context.mounted) return;

    final mqtt = context.read<MqttProvider>();
    if (!mqtt.isConnected) {
      AppUI.showSnack(context, 'Tidak terhubung ke MQTT broker', type: AppSnackType.error);
      return;
    }
    mqtt.sendReset();
    AppUI.showSnack(context, 'Perintah RESET dikirim ke ESP32', type: AppSnackType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB6B1), size: 20),
            SizedBox(width: 8),
            Text(
              'DANGER ZONE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFB6B1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFB6B1).withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              const Text(
                'Critical System Override: Tindakan ini akan menghapus permanen semua jam operasional kumulatif Machine 1. Tidak dapat dibatalkan.',
                style: TextStyle(fontSize: 12, color: Color(0xFFFFB6B1), height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmReset(context),
                  icon: const Icon(Icons.dangerous),
                  label: const Text('RESET HOUR METER TO ZERO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF93000A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
