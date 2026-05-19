import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/document_item.dart';
import '../services/documents_api_service.dart';

/// Shared state for documents + indexing progress (consumed by Dashboard,
/// Documents screen, and the navigation rail badge).
class DocumentsProvider extends ChangeNotifier {
  DocumentsProvider({required DocumentsApiService api}) : _api = api;

  final DocumentsApiService _api;
  final _uuid = const Uuid();
  final List<DocumentItem> _docs = [];

  DateTime? _lastSync;

  List<DocumentItem> get documents => List.unmodifiable(_docs);
  int get totalIndexed =>
      _docs.where((d) => d.status == IndexStatus.success).length;
  int get inProgressCount => _docs
      .where((d) =>
          d.status == IndexStatus.uploading ||
          d.status == IndexStatus.indexing ||
          d.status == IndexStatus.queued)
      .length;
  bool get isBusy => inProgressCount > 0;
  DateTime? get lastSync => _lastSync;
  bool _refreshing = false;
  bool get refreshing => _refreshing;

  /// Loads the list of documents already indexed on the backend.
  /// Local in-progress uploads are preserved at the top.
  Future<void> refresh() async {
    _refreshing = true;
    notifyListeners();
    try {
      final remote = await _api.listRemote();
      // Keep in-progress local uploads; replace the synced (success) set with remote truth.
      final localPending = _docs
          .where((d) =>
              d.status == IndexStatus.uploading ||
              d.status == IndexStatus.indexing ||
              d.status == IndexStatus.queued ||
              d.status == IndexStatus.failed)
          .toList();
      _docs
        ..clear()
        ..addAll(localPending)
        ..addAll(remote.map((r) => DocumentItem(
              id: r.id,
              name: r.fileName,
              sizeBytes: r.sizeBytes,
              addedAt: r.createdAt,
              status: IndexStatus.success,
              progress: 1,
              remoteId: r.id,
            )));
      _lastSync = DateTime.now();
    } catch (_) {
      // backend offline – silent fail, UI still shows local items
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Queues a real upload to FastAPI `/upload`. [localPath] must be a
  /// readable file path on the current platform (desktop, Android, iOS).
  void uploadFile({
    required String name,
    required int sizeBytes,
    required String localPath,
  }) {
    final doc = DocumentItem(
      id: _uuid.v4(),
      name: name,
      sizeBytes: sizeBytes,
      addedAt: DateTime.now(),
      status: IndexStatus.queued,
      localPath: localPath,
    );
    _docs.insert(0, doc);
    notifyListeners();
    unawaited(_runUpload(doc.id));
  }

  Future<void> remove(String id) async {
    final d = _findOrNull(id);
    if (d == null) return;
    _docs.removeWhere((d) => d.id == id);
    notifyListeners();
    if (d.remoteId != null) {
      try {
        await _api.deleteRemote(d.remoteId!);
      } catch (_) {/* best-effort */}
    }
  }

  void retry(String id) {
    final d = _findOrNull(id);
    if (d == null || d.localPath == null) return;
    d.status = IndexStatus.queued;
    d.progress = 0;
    d.error = null;
    notifyListeners();
    unawaited(_runUpload(id));
  }

  Future<void> _runUpload(String id) async {
    final doc = _findOrNull(id);
    if (doc == null || doc.localPath == null) return;

    // 1. Uploading: stream bytes to /upload, reflect progress 0..1
    doc.status = IndexStatus.uploading;
    doc.progress = 0;
    notifyListeners();

    try {
      final result = await _api.uploadFile(
        filePath: doc.localPath!,
        fileName: doc.name,
        onProgress: (p) {
          final cur = _findOrNull(id);
          if (cur == null) return;
          // Cap upload phase at 0.85 so we still show indexing tail.
          cur.progress = (p * 0.85).clamp(0.0, 0.85);
          if (p >= 1.0 && cur.status == IndexStatus.uploading) {
            cur.status = IndexStatus.indexing;
          }
          notifyListeners();
        },
      );

      // 2. Server returned: indexing finished.
      final cur = _findOrNull(id);
      if (cur == null) return;
      cur.status = IndexStatus.success;
      cur.progress = 1;
      cur.remoteId = result.remoteId;
      _lastSync = DateTime.now();
      notifyListeners();
    } catch (e) {
      final cur = _findOrNull(id);
      if (cur == null) return;
      cur.status = IndexStatus.failed;
      cur.error = e.toString();
      notifyListeners();
    }
  }

  DocumentItem? _findOrNull(String id) {
    for (final d in _docs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Wipes all in-memory state so the next user starts fresh after logout.
  void clearLocal() {
    _docs.clear();
    _lastSync = null;
    _refreshing = false;
    notifyListeners();
  }
}
