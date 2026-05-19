import 'package:flutter/foundation.dart';

import '../services/conversations_api_service.dart';

class ConversationsProvider extends ChangeNotifier {
  ConversationsProvider({required ConversationsApiService api}) : _api = api;
  final ConversationsApiService _api;

  List<ConversationSummary> _items = const [];
  bool _loading = false;
  String? _error;
  String? _activeId;

  List<ConversationSummary> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  String? get activeId => _activeId;

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _api.list();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<ConversationDetail?> fetch(String id) async {
    try {
      final detail = await _api.get(id);
      _activeId = id;
      notifyListeners();
      return detail;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void setActive(String? id) {
    _activeId = id;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    try {
      await _api.delete(id);
      _items = _items.where((c) => c.id != id).toList();
      if (_activeId == id) _activeId = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearLocal() {
    _items = const [];
    _activeId = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
