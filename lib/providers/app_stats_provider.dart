import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/stats_api_service.dart';

class AppStatsProvider extends ChangeNotifier {
  AppStatsProvider({required StatsApiService api}) : _api = api;
  final StatsApiService _api;

  BackendStats _stats = BackendStats.empty;
  HealthInfo _health = HealthInfo.offline;
  bool _loading = false;
  String? _error;
  Timer? _poll;

  BackendStats get stats => _stats;
  HealthInfo get health => _health;
  bool get loading => _loading;
  String? get error => _error;
  bool get backendOnline => _health.ok;

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // health first (fast, never throws)
      _health = await _api.health();
      if (_health.ok) {
        _stats = await _api.fetchStats();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 20)}) {
    _poll?.cancel();
    _poll = Timer.periodic(interval, (_) => refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
