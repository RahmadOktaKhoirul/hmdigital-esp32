import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import 'app_ui.dart';

enum ControlModuleType { adjust, speed }

class ControlModule extends StatefulWidget {
  final String id;
  final String title;
  final String label;
  final String hint;
  final String buttonText;
  final IconData icon;
  final bool isPrimary;
  final String? info;
  final ControlModuleType type;

  const ControlModule({
    super.key,
    required this.id,
    required this.title,
    required this.label,
    required this.hint,
    required this.buttonText,
    required this.icon,
    required this.isPrimary,
    required this.type,
    this.info,
  });

  @override
  State<ControlModule> createState() => _ControlModuleState();
}

class _ControlModuleState extends State<ControlModule> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final mqtt = context.read<MqttProvider>();
    if (!mqtt.isConnected) {
      AppUI.showSnack(context, 'Tidak terhubung ke MQTT broker', type: AppSnackType.error);
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.type == ControlModuleType.adjust) {
      final val = double.tryParse(text);
      if (val == null || val < 0) {
        AppUI.showSnack(context, 'Masukkan angka positif yang valid', type: AppSnackType.error);
        return;
      }
      mqtt.sendAdjust(val);
      AppUI.showSnack(context, 'HM disesuaikan ke ${val.toStringAsFixed(2)} jam', type: AppSnackType.success);
    } else {
      final val = int.tryParse(text);
      if (val == null || val < 500 || val > 2000) {
        AppUI.showSnack(context, 'Tick rate harus antara 500 dan 2000 ms', type: AppSnackType.error);
        return;
      }
      mqtt.sendSpeed(val);
      AppUI.showSnack(context, 'Tick rate diatur ke $val ms', type: AppSnackType.success);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            Text(
              'MODULE // ${widget.id}',
              style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold,
                color: Color(0xFF859585), letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: widget.isPrimary ? const Color(0xFF75FF9E) : const Color(0xFFBACBB9),
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info current HM value (hanya untuk type adjust)
              if (widget.type == ControlModuleType.adjust)
                Selector<MqttProvider, (double, double)>(
                  selector: (_, m) => (m.currentHmHours, m.prevHmHours),
                  builder: (_, val, __) {
                    final (current, prev) = val;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF353534),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CURRENT HM', style: TextStyle(fontSize: 9, color: Color(0xFF859585), letterSpacing: 1)),
                              Text(
                                '${current.toStringAsFixed(2)} h',
                                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF75FF9E)),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('PREVIOUS HM', style: TextStyle(fontSize: 9, color: Color(0xFF859585), letterSpacing: 1)),
                              Text(
                                '${prev.toStringAsFixed(2)} h',
                                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF859585)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBACBB9)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: true,
                  fillColor: const Color(0xFF353534),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              if (widget.info != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF859585)),
                    const SizedBox(width: 6),
                    Text(widget.info!, style: const TextStyle(fontSize: 10, color: Color(0xFF859585))),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onSubmit,
                  icon: Icon(widget.icon, size: 18),
                  label: Text(widget.buttonText.toUpperCase()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isPrimary ? const Color(0xFF75FF9E) : Colors.transparent,
                    foregroundColor: widget.isPrimary ? const Color(0xFF003918) : Colors.white,
                    side: widget.isPrimary ? null : const BorderSide(color: Color(0xFF859585)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
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
