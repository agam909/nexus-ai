class SourceCitation {
  final String fileName;
  final int? page;
  final String? url;
  final String? snippet;

  const SourceCitation({
    required this.fileName,
    this.page,
    this.url,
    this.snippet,
  });

  factory SourceCitation.fromJson(Map<String, dynamic> json) {
    return SourceCitation(
      fileName: (json['file_name'] ?? json['source'] ?? 'Unknown').toString(),
      page: json['page'] is int
          ? json['page'] as int
          : int.tryParse('${json['page'] ?? ''}'),
      url: json['url']?.toString(),
      snippet: json['snippet']?.toString(),
    );
  }

  String get label =>
      page != null ? '$fileName (Page $page)' : fileName;
}
