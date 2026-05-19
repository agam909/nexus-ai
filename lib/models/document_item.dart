enum IndexStatus { queued, uploading, indexing, success, failed }

class DocumentItem {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime addedAt;
  IndexStatus status;
  double progress; // 0..1
  String? error;
  String? localPath;   // path on disk for upload
  String? remoteId;    // id assigned by backend after indexing

  DocumentItem({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.addedAt,
    this.status = IndexStatus.queued,
    this.progress = 0,
    this.error,
    this.localPath,
    this.remoteId,
  });

  String get sizeLabel {
    const units = ['B', 'KB', 'MB', 'GB'];
    var s = sizeBytes.toDouble();
    var i = 0;
    while (s >= 1024 && i < units.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(s >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }
}
