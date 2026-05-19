import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'chat_api_service.dart' show HttpException;

class UploadResult {
  final String? remoteId;
  final String fileName;
  final Map<String, dynamic> raw;
  const UploadResult({
    required this.fileName,
    required this.remoteId,
    required this.raw,
  });
}

/// Talks to the FastAPI backend's document endpoints.
///
/// Expected backend contract:
///   POST {baseUrl}/upload   (multipart/form-data, field name: "file")
///   Resp: { "id": "...", "file_name": "...", "chunks": N, ... }
class DocumentsApiService {
  DocumentsApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Uploads [filePath] to `/upload`, streaming bytes and reporting
  /// upload progress (0..1) via [onProgress]. The Future completes once
  /// the backend finishes indexing and returns its JSON response.
  Future<UploadResult> uploadFile({
    required String filePath,
    String? fileName,
    void Function(double progress)? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw HttpException('File not found: $filePath');
    }
    final length = await file.length();
    final name = fileName ?? p.basename(filePath);

    final uri = Uri.parse('$baseUrl/upload');
    final req = http.MultipartRequest('POST', uri);

    final stream = _countingStream(
      file.openRead(),
      length,
      (sent) {
        if (onProgress != null && length > 0) {
          onProgress((sent / length).clamp(0.0, 1.0));
        }
      },
    );

    req.files.add(
      http.MultipartFile('file', stream, length, filename: name),
    );

    final streamed = await _client.send(req).timeout(timeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException(
        'Upload failed (${res.statusCode}): ${res.body}',
      );
    }

    Map<String, dynamic> json = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {/* tolerate non-JSON success bodies */}
    }

    return UploadResult(
      fileName: (json['file_name'] ?? name).toString(),
      remoteId: json['id']?.toString(),
      raw: json,
    );
  }

  Future<List<RemoteDocument>> listRemote({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/documents'))
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw HttpException(
        'List documents failed (${res.statusCode}): ${res.body}',
      );
    }
    final raw = jsonDecode(res.body) as List;
    return raw
        .whereType<Map>()
        .map((m) => RemoteDocument.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> deleteRemote(String remoteId) async {
    final uri = Uri.parse('$baseUrl/documents/$remoteId');
    final res = await _client.delete(uri);
    if (res.statusCode >= 300 && res.statusCode != 404) {
      throw HttpException(
        'Delete failed (${res.statusCode}): ${res.body}',
      );
    }
  }

  void dispose() => _client.close();
}

class RemoteDocument {
  final String id;
  final String fileName;
  final int sizeBytes;
  final int chunks;
  final DateTime createdAt;
  const RemoteDocument({
    required this.id,
    required this.fileName,
    required this.sizeBytes,
    required this.chunks,
    required this.createdAt,
  });
  factory RemoteDocument.fromJson(Map<String, dynamic> j) => RemoteDocument(
        id: j['id'].toString(),
        fileName: (j['file_name'] ?? 'unknown').toString(),
        sizeBytes: (j['size_bytes'] ?? 0) as int,
        chunks: (j['chunks'] ?? 0) as int,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Wraps a byte stream and reports cumulative bytes-sent to [onProgress].
Stream<List<int>> _countingStream(
  Stream<List<int>> source,
  int total,
  void Function(int sent) onProgress,
) async* {
  var sent = 0;
  await for (final chunk in source) {
    sent += chunk.length;
    onProgress(sent);
    yield chunk;
  }
}
