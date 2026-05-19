import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/document_item.dart';
import '../providers/documents_provider.dart';
import '../theme/app_theme.dart';

const _allowedExt = {'pdf', 'docx', 'txt', 'md'};

bool _isAllowed(String name) {
  final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
  return _allowedExt.contains(ext);
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool _hovering = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'txt', 'md'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final docs = context.read<DocumentsProvider>();
    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue; // web is not supported for upload here
      docs.uploadFile(name: f.name, sizeBytes: f.size, localPath: path);
    }
  }

  Future<void> _onDrop(List<XFile> files) async {
    if (files.isEmpty) return;
    final docs = context.read<DocumentsProvider>();
    final rejected = <String>[];
    for (final xf in files) {
      if (!_isAllowed(xf.name)) {
        rejected.add(xf.name);
        continue;
      }
      int size = 0;
      try {
        size = await xf.length();
      } catch (_) {}
      // On desktop XFile.path is a real fs path; on web it's blob://
      final path = xf.path;
      if (path.isEmpty || (!kIsWeb && !await File(path).exists())) continue;
      docs.uploadFile(name: xf.name, sizeBytes: size, localPath: path);
    }
    if (rejected.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped unsupported file(s): ${rejected.join(', ')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Manager'),
        actions: [
          Consumer<DocumentsProvider>(
            builder: (_, docs, __) => IconButton(
              tooltip: 'Sync with backend',
              icon: docs.refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              onPressed: docs.refreshing ? null : docs.refresh,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropTarget(
                  onDragEntered: (_) => setState(() => _hovering = true),
                  onDragExited: (_) => setState(() => _hovering = false),
                  onDragDone: (detail) async {
                    setState(() => _hovering = false);
                    await _onDrop(detail.files);
                  },
                  child: _DropZone(
                    onPick: _pickFiles,
                    hovering: _hovering,
                  ),
                ),
                const SizedBox(height: 24),
                const _DocsTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onPick, this.hovering = false});
  final VoidCallback onPick;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: hovering
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: hovering
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPick,
        child: DottedBorderBox(
          color: scheme.primary,
          radius: 20,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            child: Column(
              children: [
                AnimatedScale(
                  scale: hovering ? 1.08 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hovering
                          ? Icons.download_rounded
                          : Icons.cloud_upload_rounded,
                      color: scheme.primary,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hovering ? 'Release to upload' : 'Drag & drop files here',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'or click to browse — PDF, DOCX, TXT, MD up to 50 MB',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Browse Files'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    for (final m in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        dashed.addPath(m.extractPath(dist, dist + 7), Offset.zero);
        dist += 13;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _DocsTable extends StatelessWidget {
  const _DocsTable();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer<DocumentsProvider>(
      builder: (_, docs, __) {
        return Card(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Text('Indexed Files',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${docs.documents.length} total',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (docs.documents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No documents yet.',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.documents.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _DocRow(doc: docs.documents[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});
  final DocumentItem doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final docs = context.read<DocumentsProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.picture_as_pdf_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${doc.sizeLabel} • added ${DateFormat('dd MMM, HH:mm').format(doc.addedAt)}',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _StatusCell(doc: doc)),
          const SizedBox(width: 8),
          if (doc.status == IndexStatus.failed)
            IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => docs.retry(doc.id),
            ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: () => docs.remove(doc.id),
          ),
        ],
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.doc});
  final DocumentItem doc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (doc.status) {
      case IndexStatus.success:
        return _Pill(
          icon: Icons.check_circle_rounded,
          color: AppColors.cyan,
          label: 'Success',
        );
      case IndexStatus.failed:
        return _Pill(
          icon: Icons.error_rounded,
          color: AppColors.danger,
          label: 'Failed',
        );
      case IndexStatus.queued:
      case IndexStatus.uploading:
      case IndexStatus.indexing:
        final label = switch (doc.status) {
          IndexStatus.queued => 'Queued',
          IndexStatus.uploading => 'Uploading…',
          IndexStatus.indexing => 'Indexing…',
          _ => '',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: doc.progress > 0 ? doc.progress : null,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHigh,
                color: scheme.primary,
              ),
            ),
          ],
        );
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
