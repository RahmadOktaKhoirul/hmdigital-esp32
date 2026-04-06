import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _topicData      = 'factory/machine1/hm/data';
const _topicLog       = 'factory/machine1/hm/log';
const _topicResetCmd  = 'factory/machine1/cmd/reset';
const _topicAdjustCmd = 'factory/machine1/cmd/adjust';
const _topicSpeedCmd  = 'factory/machine1/cmd/speed';

// SharedPreferences keys
const _kIp           = 'mqtt_ip';
const _kPort         = 'mqtt_port';
const _kPrevHm       = 'prev_hm_hours';
const _kDailyHours   = 'daily_hours_json';
const _kLogs         = 'logs_json';
const _kSnapshotDate = 'last_snapshot_date';

class LogEntry {
  final String event;
  final double prevHmHours;
  final String timestamp;
  final bool isLocal;

  const LogEntry({
    required this.event,
    required this.prevHmHours,
    required this.timestamp,
    this.isLocal = false,
  });

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
    event:       (j['event']          as String?) ?? '',
    prevHmHours: ((j['prev_hm_hours'] as num?)    ?? 0).toDouble(),
    timestamp:   (j['timestamp']      as String?) ?? '',
    isLocal:     (j['is_local']       as bool?)   ?? false,
  );

  Map<String, dynamic> toJson() => {
    'event':         event,
    'prev_hm_hours': prevHmHours,
    'timestamp':     timestamp,
    'is_local':      isLocal,
  };
}

class DailyOperationEntry {
  final DateTime date;
  final double hours;
  const DailyOperationEntry({required this.date, required this.hours});
}

class MqttProvider extends ChangeNotifier {
  MqttServerClient? _client;
  StreamSubscription? _subscription;
  Timer? _ticker;
  Timer? _snapshotTimer;
  SharedPreferences? _prefs;

  bool   _isConnected = false;
  String _ip   = '192.168.100.107';
  String _port = '1883';

  // ── Live data (broker is source of truth) ─────────────────────────────────
  double currentHmHours = 0;
  double prevHmHours    = 0;
  bool   engineRunning  = false;
  int    hmSeconds      = 0;

  // Alias untuk widget yang masih pakai hmHours
  double get hmHours => currentHmHours;

  final List<LogEntry> logs = [];

  // ── Daily tracking ─────────────────────────────────────────────────────────
  final Map<String, double> _dailyHours   = {};
  double _lastHmForDelta = 0;
  String _lastDate       = '';
  String _lastSnapshotDate = '';

  // ── Getters ────────────────────────────────────────────────────────────────
  bool   get isConnected => _isConnected;
  String get ip          => _ip;
  String get port        => _port;

  List<DailyOperationEntry> get last7Days {
    final today  = _dayOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      return DailyOperationEntry(date: day, hours: _dailyHours[_dateKey(day)] ?? 0);
    });
  }

  List<DailyOperationEntry> getRange(DateTime from, DateTime to) {
    final result  = <DailyOperationEntry>[];
    var   current = _dayOnly(from);
    final end     = _dayOnly(to);
    while (!current.isAfter(end)) {
      result.add(DailyOperationEntry(date: current, hours: _dailyHours[_dateKey(current)] ?? 0));
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  // ── Init — load persisted data ─────────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _ip   = _prefs!.getString(_kIp)   ?? _ip;
    _port = _prefs!.getString(_kPort) ?? _port;
    prevHmHours = _prefs!.getDouble(_kPrevHm) ?? 0;
    _lastSnapshotDate = _prefs!.getString(_kSnapshotDate) ?? '';

    // Load daily hours
    final dailyJson = _prefs!.getString(_kDailyHours);
    if (dailyJson != null) {
      final map = jsonDecode(dailyJson) as Map<String, dynamic>;
      map.forEach((k, v) => _dailyHours[k] = (v as num).toDouble());
    }

    // Load logs
    final logsJson = _prefs!.getString(_kLogs);
    if (logsJson != null) {
      final list = jsonDecode(logsJson) as List<dynamic>;
      logs.addAll(list.map((e) => LogEntry.fromJson(e as Map<String, dynamic>)));
    }

    notifyListeners();
  }

  // ── Persist ────────────────────────────────────────────────────────────────
  Future<void> _saveAll() async {
    if (_prefs == null) return;
    await Future.wait([
      _prefs!.setString(_kIp,   _ip),
      _prefs!.setString(_kPort, _port),
      _prefs!.setDouble(_kPrevHm, prevHmHours),
      _prefs!.setString(_kDailyHours, jsonEncode(_dailyHours)),
      _prefs!.setString(_kLogs, jsonEncode(logs.take(100).map((e) => e.toJson()).toList())),
      _prefs!.setString(_kSnapshotDate, _lastSnapshotDate),
    ]);
  }

  // ── Ticker — smooth UI, broker tetap sumber kebenaran ─────────────────────
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isConnected || !engineRunning) return;
      // Hanya increment lokal untuk UI smooth
      // Nilai akan di-overwrite oleh MQTT saat pesan berikutnya datang
      hmSeconds++;
      currentHmHours = hmSeconds / 3600.0;
      _trackDelta(currentHmHours);
      notifyListeners();
    });
  }

  // ── Snapshot jam 05:00 ─────────────────────────────────────────────────────
  void _startSnapshotTimer() {
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now   = DateTime.now();
      final today = _dateKey(_dayOnly(now));
      if (now.hour == 5 && now.minute == 0 && _lastSnapshotDate != today) {
        _lastSnapshotDate = today;
        _saveAll();
        notifyListeners();
      }
    });
  }

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<bool> connect(String ip, String port) async {
    await disconnect();
    _ip   = ip;
    _port = port;
    await _prefs?.setString(_kIp,   ip);
    await _prefs?.setString(_kPort, port);

    final clientId = 'flutter_hm_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(ip, clientId, int.parse(port))
      ..keepAlivePeriod      = 20
      ..connectTimeoutPeriod = 5000
      ..onDisconnected       = _onDisconnected
      ..logging(on: false);

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await _client!.connect().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _client?.disconnect();
          throw TimeoutException('Connection timed out');
        },
      );
    } catch (_) {
      _client?.disconnect();
      return false;
    }

    if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
      return false;
    }

    _isConnected = true;
    // QoS 0 — minimum latency, broker sudah retained message
    _client!.subscribe(_topicData, MqttQos.atMostOnce);
    _client!.subscribe(_topicLog,  MqttQos.atMostOnce);
    _subscription = _client!.updates?.listen(_onMessage);
    _startTicker();
    _startSnapshotTimer();
    notifyListeners();
    return true;
  }

  // ── Message handler — broker adalah sumber kebenaran ──────────────────────
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    bool changed = false;
    for (final msg in messages) {
      final raw = MqttPublishPayload.bytesToStringAsString(
        (msg.payload as MqttPublishMessage).payload.message,
      );
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;

        if (msg.topic == _topicData) {
          final brokerSec     = ((json['hm_sec']      as num?) ?? 0).toInt();
          final brokerPrevSec = ((json['prev_hm_sec'] as num?) ?? 0).toInt();
          final brokerRunning = json['status'] == 'RUNNING';

          // Selalu ikuti nilai dari broker — ini sumber kebenaran
          hmSeconds      = brokerSec;
          currentHmHours = brokerSec / 3600.0;
          engineRunning  = brokerRunning;

          // prevHmHours: ambil dari broker jika lokal belum di-set
          // atau jika broker melaporkan nilai yang lebih besar (lebih akurat)
          final brokerPrevHours = brokerPrevSec / 3600.0;
          if (brokerPrevHours > prevHmHours) {
            prevHmHours = brokerPrevHours;
            _prefs?.setDouble(_kPrevHm, prevHmHours);
          }

          _trackDelta(currentHmHours);
          changed = true;

        } else if (msg.topic == _topicLog) {
          final incoming = LogEntry.fromJson(json);
          // Skip duplikat dengan log lokal (event sama dalam 5 detik)
          final isDup = logs.any((l) =>
              l.isLocal &&
              l.event.startsWith(incoming.event) &&
              _parseTs(incoming.timestamp)
                  .difference(_parseTs(l.timestamp))
                  .inSeconds
                  .abs() < 5);
          if (!isDup) {
            logs.insert(0, incoming);
            if (logs.length > 100) logs.removeLast();
            _saveAll();
          }
          changed = true;
        }
      } catch (_) {}
    }
    if (changed) notifyListeners();
  }

  // ── Delta tracking untuk daily hours ──────────────────────────────────────
  void _trackDelta(double current) {
    final today = _dateKey(_dayOnly(DateTime.now()));
    if (_lastDate.isEmpty) {
      _lastDate       = today;
      _lastHmForDelta = current;
      return;
    }
    final delta = current - _lastHmForDelta;
    // Hanya akumulasi delta positif yang wajar (< 2 detik = max ~0.00056 jam)
    if (delta > 0 && delta < 0.01) {
      _dailyHours[_lastDate] = (_dailyHours[_lastDate] ?? 0) + delta;
    }
    _lastHmForDelta = current;
    _lastDate       = today;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _parseTs(String ts) {
    try { return DateTime.parse(ts.replaceFirst(' ', 'T')); }
    catch (_) { return DateTime.now(); }
  }

  String _nowTs() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')} '
           '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}:${n.second.toString().padLeft(2,'0')}';
  }

  void _addLocalLog(String event, double prevHours) {
    logs.insert(0, LogEntry(event: event, prevHmHours: prevHours, timestamp: _nowTs(), isLocal: true));
    if (logs.length > 100) logs.removeLast();
    _saveAll();
    notifyListeners();
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  void _onDisconnected() {
    _ticker?.cancel();
    _snapshotTimer?.cancel();
    _isConnected = false;
    _saveAll();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _ticker?.cancel();
    _snapshotTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _isConnected = false;
    await _saveAll();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _snapshotTimer?.cancel();
    _subscription?.cancel();
    _client?.disconnect();
    super.dispose();
  }

  // ── Publish ────────────────────────────────────────────────────────────────
  void _publish(String topic, String payload) {
    if (!_isConnected) return;
    _client!.publishMessage(
      topic,
      MqttQos.atMostOnce,
      (MqttClientPayloadBuilder()..addString(payload)).payload!,
    );
  }

  // ── Commands ───────────────────────────────────────────────────────────────
  void sendReset() {
    prevHmHours = currentHmHours;
    _addLocalLog('RESET', currentHmHours);
    _publish(_topicResetCmd, 'RESET');
    // Update lokal langsung, broker akan konfirmasi via retained message
    currentHmHours  = 0;
    hmSeconds       = 0;
    _lastHmForDelta = 0;
    _prefs?.setDouble(_kPrevHm, prevHmHours);
    notifyListeners();
  }

  void sendAdjust(double hours) {
    prevHmHours = currentHmHours;
    _addLocalLog('ADJUST → ${hours.toStringAsFixed(2)} h', currentHmHours);
    _publish(_topicAdjustCmd, hours.toStringAsFixed(2));
    _lastHmForDelta = hours;
    _prefs?.setDouble(_kPrevHm, prevHmHours);
  }

  void sendSpeed(int ms) {
    _addLocalLog('SPEED: ${ms}ms', currentHmHours);
    _publish(_topicSpeedCmd, ms.toString());
  }
}
