import 'dart:convert';

enum ChapterStatus {
  pending,
  analyzed,
  scenesSelected,
  enhanced,
  reviewed;

  String get statusText {
    switch (this) {
      case ChapterStatus.pending: return '待处理';
      case ChapterStatus.analyzed: return '已分析';
      case ChapterStatus.scenesSelected: return '已选场景';
      case ChapterStatus.enhanced: return '已加料';
      case ChapterStatus.reviewed: return '已审阅';
    }
  }
}

class Chapter {
  final String id;
  final String projectId;
  final int chapterNumber;
  final String title;
  final String originalContent;
  String? enhancedContent;
  Map<String, dynamic>? analysisResult;
  List<dynamic> scenes;
  List<int> selectedScenes;
  ChapterStatus status;
  final DateTime createTime;
  DateTime updateTime;
  final int wordCount;
  int enhancedWordCount;

  Chapter({
    String? id,
    required this.projectId,
    required this.chapterNumber,
    required this.title,
    required this.originalContent,
    this.enhancedContent,
    this.analysisResult,
    List<dynamic>? scenes,
    List<int>? selectedScenes,
    this.status = ChapterStatus.pending,
    DateTime? createTime,
    DateTime? updateTime,
    int? wordCount,
    this.enhancedWordCount = 0,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        scenes = scenes ?? [],
        selectedScenes = selectedScenes ?? [],
        createTime = createTime ?? DateTime.now(),
        updateTime = updateTime ?? DateTime.now(),
        wordCount = wordCount ?? _countChineseChars(originalContent);

  static int _countChineseChars(String text) {
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'[一-鿿㐀-䶿]').hasMatch(text[i])) count++;
    }
    return count;
  }

  String get displayTitle => title.isNotEmpty ? title : '第${chapterNumber}章';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'chapterNumber': chapterNumber,
      'title': title,
      'originalContent': originalContent,
      'enhancedContent': enhancedContent,
      'analysisResult': analysisResult != null ? jsonEncode(analysisResult) : null,
      'scenes': jsonEncode(scenes),
      'selectedScenes': jsonEncode(selectedScenes),
      'status': status.index,
      'createTime': createTime.toIso8601String(),
      'updateTime': updateTime.toIso8601String(),
      'wordCount': wordCount,
      'enhancedWordCount': enhancedWordCount,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      chapterNumber: map['chapterNumber'] as int,
      title: map['title'] as String,
      originalContent: map['originalContent'] as String,
      enhancedContent: map['enhancedContent'] as String?,
      analysisResult: _parseJsonMap(map['analysisResult']),
      scenes: _parseJsonList(map['scenes']),
      selectedScenes: _parseJsonIntList(map['selectedScenes']),
      status: ChapterStatus.values[map['status'] as int? ?? 0],
      createTime: DateTime.parse(map['createTime'] as String),
      updateTime: DateTime.parse(map['updateTime'] as String),
      wordCount: map['wordCount'] as int? ?? 0,
      enhancedWordCount: map['enhancedWordCount'] as int? ?? 0,
    );
  }

  static Map<String, dynamic>? _parseJsonMap(String? json) {
    if (json == null || json.isEmpty) return null;
    try { return jsonDecode(json) as Map<String, dynamic>; } catch (_) { return null; }
  }

  static List<dynamic> _parseJsonList(String? json) {
    if (json == null || json.isEmpty) return [];
    try { return jsonDecode(json) as List<dynamic>; } catch (_) { return []; }
  }

  static List<int> _parseJsonIntList(String? json) {
    final list = _parseJsonList(json);
    return list.map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? -1).where((e) => e >= 0).toList();
  }

  Chapter copyWith({
    String? id,
    String? projectId,
    int? chapterNumber,
    String? title,
    String? originalContent,
    String? enhancedContent,
    Map<String, dynamic>? analysisResult,
    List<dynamic>? scenes,
    List<int>? selectedScenes,
    ChapterStatus? status,
    DateTime? createTime,
    DateTime? updateTime,
    int? wordCount,
    int? enhancedWordCount,
  }) {
    return Chapter(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      title: title ?? this.title,
      originalContent: originalContent ?? this.originalContent,
      enhancedContent: enhancedContent ?? this.enhancedContent,
      analysisResult: analysisResult ?? this.analysisResult,
      scenes: scenes ?? this.scenes,
      selectedScenes: selectedScenes ?? this.selectedScenes,
      status: status ?? this.status,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      wordCount: wordCount ?? this.wordCount,
      enhancedWordCount: enhancedWordCount ?? this.enhancedWordCount,
    );
  }
}
