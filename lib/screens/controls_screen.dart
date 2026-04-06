import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import '../widgets/control_module.dart';
import '../widgets/danger_zone.dart';

class ControlsScreen extends StatelessWidget {
  const ControlsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        elevation: 0,
        title: Text(
          'HM CONTROLS',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        connected ? ip : 'DISCONNECTED',
                        key: ValueKey(connected),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: connected
                              ? const Color(0xFF75FF9E)
                              : const Color(0xFFD40404),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          ControlModule(
            id: '01',
            title: 'Absolute Calibration',
            label: 'Adjust HM Value (Hours)',
            hint: 'e.g., 1250.50',
            buttonText: 'Apply Value',
            icon: Icons.precision_manufacturing,
            isPrimary: true,
            type: ControlModuleType.adjust,
          ),
          SizedBox(height: 32),
          ControlModule(
            id: '02',
            title: 'Tick Rate Speed',
            label: 'Set Tick Rate (ms)',
            hint: 'e.g., 1000',
            buttonText: 'Update Speed',
            icon: Icons.speed,
            isPrimary: false,
            type: ControlModuleType.speed,
            info: 'Safe range: 500ms - 2000ms',
          ),
          SizedBox(height: 40),
          DangerZone(),
        ],
      ),
    );
  }
}
