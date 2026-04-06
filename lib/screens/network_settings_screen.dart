import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import '../widgets/app_ui.dart';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  bool _isLoading = false;
  bool _isScanning = false;
  List<String> _scanResults = [];
  int _scanProgress = 0;

  @override
  void initState() {
    super.initState();
    final mqtt = context.read<MqttProvider>();
    _ipController  = TextEditingController(text: mqtt.ip);
    _portController = TextEditingController(text: mqtt.port);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _scanNetwork() async {
    setState(() {
      _isScanning = true;
      _scanResults = [];
      _scanProgress = 0;
    });

    String? wifiIP;
    try {
      wifiIP = await NetworkInfo().getWifiIP();
    } catch (_) {}

    if (!mounted) return;
    if (wifiIP == null) {
      AppUI.showSnack(context, 'Tidak dapat membaca IP WiFi. Pastikan sudah terhubung ke WiFi.', type: AppSnackType.error);
      setState(() => _isScanning = false);
      return;
    }

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
    final port = int.tryParse(_portController.text.trim()) ?? 1883;
    final found = <String>[];
    const batchSize = 20;
    const total = 254;

    for (int start = 1; start <= total; start += batchSize) {
      if (!mounted) break;
      final end = (start + batchSize - 1).clamp(1, total);
      await Future.wait(
        List.generate(end - start + 1, (i) async {
          final ip = '$subnet.${start + i}';
          try {
            final sock = await Socket.connect(ip, port,
                timeout: const Duration(milliseconds: 300));
            sock.destroy();
            found.add(ip);
          } catch (_) {}
        }),
      );
      if (mounted) setState(() => _scanProgress = end);
    }

    if (mounted) {
      setState(() {
        _scanResults = found;
        _isScanning = false;
      });
      if (found.isEmpty) {
        AppUI.showSnack(context, 'Tidak ada device ditemukan di port $port pada subnet $subnet.x', type: AppSnackType.error);
      }
    }
  }

  Future<void> _saveAndReconnect() async {
    setState(() => _isLoading = true);
    final connected = await context.read<MqttProvider>().connect(
          _ipController.text.trim(),
          _portController.text.trim(),
        );
    setState(() => _isLoading = false);
    if (!mounted) return;

    if (connected) {
      AppUI.showSnack(context, 'Terhubung ke ${_ipController.text.trim()}',
          type: AppSnackType.success);
    } else {
      final retry = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A0A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF93000A)),
          ),
          title: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Color(0xFFFFB6B1), size: 20),
              SizedBox(width: 10),
              Text(
                'Koneksi Gagal',
                style: TextStyle(color: Color(0xFFFFB6B1), fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tidak dapat terhubung ke Microcontroller pada:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_ipController.text.trim()}:${_portController.text.trim()}',
                  style: const TextStyle(color: Color(0xFF75FF9E), fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF93000A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93000A).withValues(alpha: 0.4)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CheckItem(text: 'Perangkat terhubung ke WiFi yang sama dengan ESP32'),
                    _CheckItem(text: 'IP address dan port sudah benar'),
                    _CheckItem(text: 'MQTT broker pada ESP32 sedang aktif'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('TUTUP', style: TextStyle(color: Color(0xFF859585), letterSpacing: 1.2)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('COBA LAGI',
                  style: TextStyle(color: Color(0xFF75FF9E), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          ],
        ),
      );
      if (mounted && retry == true) _saveAndReconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131313),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF75FF9E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'NETWORK SETTINGS',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold, letterSpacing: 1, color: const Color(0xFF00E676),
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
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: connected ? const Color(0xFF75FF9E) : const Color(0xFFD40404),
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
                          color: connected ? const Color(0xFF75FF9E) : const Color(0xFFD40404),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withValues(alpha: 0.05), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // MQTT Broker Configuration
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4, height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF75FF9E),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'MQTT BROKER CONFIGURATION',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold,
                          letterSpacing: 1.5, color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const _NetworkInputLabel(label: 'BROKER IP ADDRESS'),
                  const SizedBox(height: 12),
                  _NetworkTextField(controller: _ipController, hint: '192.168.100.107', icon: Icons.lan_outlined),
                  const SizedBox(height: 24),
                  const _NetworkInputLabel(label: 'PORT'),
                  const SizedBox(height: 12),
                  _NetworkTextField(
                    controller: _portController,
                    hint: '1883',
                    icon: Icons.settings_input_component,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E0E).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF75FF9E).withValues(alpha: 0.1)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF75FF9E), size: 18),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Connects directly to the MQTT broker on the ESP32 network. Topics: factory/machine1/hm/data & factory/machine1/hm/log',
                            style: TextStyle(fontSize: 11, color: Color(0xFFBACBB9), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Network Scan Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                            width: 4, height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF75B8FF),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'NETWORK SCAN',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold,
                              letterSpacing: 1.5, color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _isScanning ? null : _scanNetwork,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2A3A),
                            disabledBackgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: const Color(0xFF75B8FF).withValues(alpha: 0.4),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF75B8FF)),
                                )
                              : const Icon(Icons.radar, size: 14, color: Color(0xFF75B8FF)),
                          label: Text(
                            _isScanning ? 'SCANNING...' : 'SCAN',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              letterSpacing: 1.2, color: Color(0xFF75B8FF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isScanning) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _scanProgress / 254,
                              backgroundColor: const Color(0xFF1A1A1A),
                              color: const Color(0xFF75B8FF),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$_scanProgress/254',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF859585)),
                        ),
                      ],
                    ),
                  ],
                  if (!_isScanning && _scanResults.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${_scanResults.length} DEVICE DITEMUKAN — tap untuk pilih',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF859585), letterSpacing: 1),
                    ),
                    const SizedBox(height: 10),
                    ..._scanResults.map((ip) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          _ipController.text = ip;
                          AppUI.showSnack(context, 'IP $ip dipilih', type: AppSnackType.success);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E0E0E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF75B8FF).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.developer_board, size: 16, color: Color(0xFF75B8FF)),
                              const SizedBox(width: 12),
                              Text(
                                ip,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'TAP TO USE',
                                style: TextStyle(fontSize: 9, color: Color(0xFF75B8FF), letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
                  ],
                  if (!_isScanning && _scanResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Scan jaringan WiFi untuk menemukan ESP32 secara otomatis.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF859585), height: 1.5),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Selector<MqttProvider, bool>(
              selector: (_, m) => m.isConnected,
              builder: (_, connected, __) => connected
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => context.read<MqttProvider>().disconnect(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2A2A2A), width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text(
                            'DISCONNECT',
                            style: TextStyle(color: Color(0xFF859585), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF75FF9E), Color(0xFF00E676)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndReconnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003918)),
                        )
                      : const Text(
                          'SAVE & CONNECT',
                          style: TextStyle(color: Color(0xFF003918), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _NetworkInputLabel extends StatelessWidget {
  final String label;
  const _NetworkInputLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF859585), letterSpacing: 1.2),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF75FF9E), fontSize: 12)),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFBACBB9), fontSize: 11, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _NetworkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _NetworkTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 20),
        filled: true,
        fillColor: const Color(0xFF353534).withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
