import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/source_citation.dart';

class SourceChip extends StatelessWidget {
  const SourceChip({super.key, required this.source});

  final SourceCitation source;

  Future<void> _open(BuildContext context) async {
    if (source.url != null && source.url!.isNotEmpty) {
      final uri = Uri.tryParse(source.url!);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (context.mounted) _showPreview(context);
  }

  void _showPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(source.label),
        content: SingleChildScrollView(
          child: Text(
            source.snippet?.isNotEmpty == true
                ? source.snippet!
                : 'No preview available for this source.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(Icons.description_outlined, size: 16, color: scheme.primary),
      label: Text(source.label, overflow: TextOverflow.ellipsis),
      onPressed: () => _open(context),
      tooltip: source.snippet,
    );
  }
}
