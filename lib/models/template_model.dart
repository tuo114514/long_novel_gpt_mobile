import 'dart:convert';

class TemplateModel {
  final String name;
  final String breakArmor;
  final String summaryPrompt;
  final List<SceneRule> recognitionRules;
  final String rewriteGeneral;
  final Map<String, String> rewriteSpecific;

  TemplateModel({
    required this.name,
    required this.breakArmor,
    required this.summaryPrompt,
    required this.recognitionRules,
    required this.rewriteGeneral,
    required this.rewriteSpecific,
  });

  factory TemplateModel.fromJsonFile(String jsonContent) {
    final data = jsonDecode(jsonContent) as Map<String, dynamic>;
    final name = data['name'] as String? ?? '未命名模板';
    final breakArmor = data['break_armor'] as String? ?? '';
    final summaryPrompt = data['summary_prompt'] as String? ?? '';

    final List<SceneRule> rules = [];
    if (data['recognition_rules'] != null) {
      for (final r in (data['recognition_rules'] as List)) {
        rules.add(SceneRule.fromJson(r as Map<String, dynamic>));
      }
    }

    final rewrite = data['rewrite_rules'] as Map<String, dynamic>?;
    final general = rewrite?['general'] as String? ?? '';
    final Map<String, String> specific = {};
    if (rewrite?['specific'] != null) {
      (rewrite!['specific'] as Map<String, dynamic>).forEach((k, v) {
        specific[k] = v.toString();
      });
    }

    return TemplateModel(
      name: name,
      breakArmor: breakArmor,
      summaryPrompt: summaryPrompt,
      recognitionRules: rules,
      rewriteGeneral: general,
      rewriteSpecific: specific,
    );
  }

  String getFullRewriteRule(List<String> sceneIds) {
    final buf = StringBuffer();
    buf.writeln(rewriteGeneral);
    for (final id in sceneIds) {
      final sp = rewriteSpecific[id];
      if (sp != null && sp.isNotEmpty) {
        buf.writeln('\n--- $id ---\n$sp');
      }
    }
    return buf.toString();
  }

  String getRecognitionRulesText() {
    final buf = StringBuffer();
    for (final r in recognitionRules) {
      buf.writeln('${r.id}: ${r.name} - ${r.description}');
    }
    return buf.toString();
  }
}

class SceneRule {
  final String id;
  final String name;
  final String description;
  final List<String> keywords;

  SceneRule({required this.id, required this.name, required this.description, this.keywords = const []});

  factory SceneRule.fromJson(Map<String, dynamic> json) {
    return SceneRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      keywords: _parseKeywords(json['description'] as String? ?? ''),
    );
  }

  static List<String> _parseKeywords(String desc) {
    final m = RegExp(r'关键词[：:]([^\n]+)').firstMatch(desc);
    if (m == null) return [];
    return m.group(1)!.split(RegExp(r'[、，,；;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
}
