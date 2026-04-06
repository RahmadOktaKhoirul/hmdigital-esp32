import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'network_settings_screen.dart';
import '../providers/mqtt_provider.dart';
import '../widgets/connection_status_chip.dart';
import '../widgets/main_hour_meter_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/weekly_operation_chart.dart';
import '../widgets/system_integrity_card.dart';
import '../widgets/hm_compare_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        elevation: 0,
        leading: const Icon(
          Icons.precision_manufacturing,
          color: Color(0xFF75FF9E),
        ),
        title: Text(
          'HM DIGITAL',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: const Color(0xFF75FF9E),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NetworkSettingsScreen()),
            ),
            icon: const Icon(Icons.settings, color: Color(0xFF75FF9E)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            color: const Color(0xFF75FF9E).withValues(alpha: 0.2),
            height: 2,
          ),
        ),
      ),
      body: Column(
        children: [
          Consumer<MqttProvider>(
            builder: (context, mqtt, _) {
              if (mqtt.isConnected) return const SizedBox.shrink();
              return Material(
                color: const Color(0xFF1A0A0A),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NetworkSettingsScreen(),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF93000A), width: 1),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          color: Color(0xFFFFB6B1),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TIDAK DAPAT TERHUBUNG KE MICROCONTROLLER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFB6B1),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pastikan perangkat terhubung ke jaringan yang sama dengan ESP32. Ketuk untuk mengatur koneksi.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF859585),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: Color(0xFF859585),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const ConnectionStatusChip(),
                  const SizedBox(height: 24),
                  const MainHourMeterCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: MetricCard(
                          label: 'LOAD FACTOR',
                          value: '84%',
                          progress: 0.84,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: MetricCard(
                          label: 'NEXT SERVICE',
                          value: '149h',
                          progress: 0.6,
                          color: const Color(0xFFFFB6B1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const HmCompareCard(),
                  const SizedBox(height: 16),
                  const WeeklyOperationChart(),
                  const SizedBox(height: 20),
                  const SystemIntegrityCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
