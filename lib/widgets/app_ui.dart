import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppSnackType { success, error, info }

class AppUI {
  static void showSnack(
    BuildContext context,
    String message, {
    AppSnackType type = AppSnackType.info,
  }) {
    final colors = switch (type) {
      AppSnackType.success => (bg: const Color(0xFF00E676), fg: const Color(0xFF003918)),
      AppSnackType.error   => (bg: const Color(0xFF1A0A0A), fg: const Color(0xFFFFB6B1)),
      AppSnackType.info    => (bg: const Color(0xFF2A2A2A), fg: const Color(0xFFBACBB9)),
    };
    final icon = switch (type) {
      AppSnackType.success => Icons.check_circle_outline,
      AppSnackType.error   => Icons.wifi_off_rounded,
      AppSnackType.info    => Icons.info_outline,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: colors.bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: type == AppSnackType.error
                ? const Color(0xFF93000A)
                : colors.fg.withValues(alpha: 0.3),
          ),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: colors.fg, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.fg,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String highlight,
    required String warningText,
    required String confirmLabel,
    IconData titleIcon = Icons.warning_amber_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF93000A)),
        ),
        title: Row(
          children: [
            Icon(titleIcon, color: const Color(0xFFFFB6B1), size: 20),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFFFB6B1),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
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
                highlight,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFFFFB6B1),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFFB6B1), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warningText,
                      style: const TextStyle(
                        color: Color(0xFFFFB6B1),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'BATAL',
              style: TextStyle(color: Color(0xFF859585), letterSpacing: 1.2),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                color: Color(0xFFFFB6B1),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
