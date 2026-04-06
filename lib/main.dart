import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/mqtt_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/controls_screen.dart';
import 'screens/logs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mqtt = MqttProvider();
  await mqtt.init();
  runApp(
    ChangeNotifierProvider.value(value: mqtt, child: const IndustrialHMApp()),
  );
}

class IndustrialHMApp extends StatelessWidget {
  const IndustrialHMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HourMeter Digital',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131313),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF75FF9E),
          onPrimary: Color(0xFF003918),
          primaryContainer: Color(0xFF00E676),
          surface: Color(0xFF131313),
          surfaceContainerHighest: Color(0xFF2A2A2A),
          onSurface: Color(0xFFE5E2E1),
          onSurfaceVariant: Color(0xFFBACBB9),
          error: Color(0xFF93000A),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ControlsScreen(),
    const LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color(0xFF0E0E0E),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF75FF9E),
          unselectedItemColor: const Color(0xFF859585),
          selectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'DASHBOARD',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_input_component),
              label: 'CONTROLS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_rounded),
              label: 'LOGS',
            ),
          ],
        ),
      ),
    );
  }
}
