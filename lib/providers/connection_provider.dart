import 'package:flutter/material.dart';

class ConnectionProvider extends ChangeNotifier {
  bool _isConnected = false;
  String _ip = '192.168.100.107';
  String _port = '1883';

  bool get isConnected => _isConnected;
  String get ip => _ip;
  String get port => _port;

  void setConnected(bool value, String ip, {String port = '1883'}) {
    _isConnected = value;
    _ip = ip;
    _port = port;
    notifyListeners();
  }

  void disconnect() {
    _isConnected = false;
    notifyListeners();
  }
}
