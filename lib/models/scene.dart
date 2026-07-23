class SceneModel {
  final String type;
  final String anchorText;
  final String description;
  final int priority;
  final String suggestion;
  String? enhancedContent;

  SceneModel({
    required this.type,
    required this.anchorText,
    required this.description,
    required this.priority,
    required this.suggestion,
    this.enhancedContent,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'anchor_text': anchorText,
      'description': description,
      'priority': priority,
      'suggestion': suggestion,
      if (enhancedContent != null) 'enhancedContent': enhancedContent,
    };
  }

  factory SceneModel.fromMap(Map<String, dynamic> map) {
    return SceneModel(
      type: map['type'] as String? ?? '',
      anchorText: map['anchor_text'] as String? ?? '',
      description: map['description'] as String? ?? '',
      priority: map['priority'] as int? ?? 3,
      suggestion: map['suggestion'] as String? ?? '',
      enhancedContent: map['enhancedContent'] as String?,
    );
  }

  SceneModel copyWith({
    String? type,
    String? anchorText,
    String? description,
    int? priority,
    String? suggestion,
    String? enhancedContent,
  }) {
    return SceneModel(
      type: type ?? this.type,
      anchorText: anchorText ?? this.anchorText,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      suggestion: suggestion ?? this.suggestion,
      enhancedContent: enhancedContent ?? this.enhancedContent,
    );
  }
}
