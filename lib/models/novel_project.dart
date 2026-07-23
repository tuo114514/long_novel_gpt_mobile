import 'dart:convert';

class NovelProject {
  final String id;
  final String title;
  final String author;
  final String description;
  final DateTime createTime;
  final DateTime updateTime;
  final int totalChapters;
  final int processedChapters;
  final int totalWords;
  final int enhancedWords;
  final int enhanceLevel;
  final String enhanceStyle;

  NovelProject({
    String? id,
    required this.title,
    this.author = '',
    this.description = '',
    DateTime? createTime,
    DateTime? updateTime,
    this.totalChapters = 0,
    this.processedChapters = 0,
    this.totalWords = 0,
    this.enhancedWords = 0,
    this.enhanceLevel = 2,
    this.enhanceStyle = 'standard',
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toRadixString(36),
        createTime = createTime ?? DateTime.now(),
        updateTime = updateTime ?? DateTime.now();

  double get progress => totalChapters > 0 ? processedChapters / totalChapters : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'createTime': createTime.toIso8601String(),
      'updateTime': updateTime.toIso8601String(),
      'totalChapters': totalChapters,
      'processedChapters': processedChapters,
      'totalWords': totalWords,
      'enhancedWords': enhancedWords,
      'enhanceLevel': enhanceLevel,
      'enhanceStyle': enhanceStyle,
    };
  }

  factory NovelProject.fromMap(Map<String, dynamic> map) {
    return NovelProject(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createTime: DateTime.parse(map['createTime'] as String),
      updateTime: DateTime.parse(map['updateTime'] as String),
      totalChapters: map['totalChapters'] as int? ?? 0,
      processedChapters: map['processedChapters'] as int? ?? 0,
      totalWords: map['totalWords'] as int? ?? 0,
      enhancedWords: map['enhancedWords'] as int? ?? 0,
      enhanceLevel: map['enhanceLevel'] as int? ?? 2,
      enhanceStyle: map['enhanceStyle'] as String? ?? 'standard',
    );
  }

  NovelProject copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    DateTime? createTime,
    DateTime? updateTime,
    int? totalChapters,
    int? processedChapters,
    int? totalWords,
    int? enhancedWords,
    int? enhanceLevel,
    String? enhanceStyle,
  }) {
    return NovelProject(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      totalChapters: totalChapters ?? this.totalChapters,
      processedChapters: processedChapters ?? this.processedChapters,
      totalWords: totalWords ?? this.totalWords,
      enhancedWords: enhancedWords ?? this.enhancedWords,
      enhanceLevel: enhanceLevel ?? this.enhanceLevel,
      enhanceStyle: enhanceStyle ?? this.enhanceStyle,
    );
  }

  String toJson() => jsonEncode(toMap());
}
