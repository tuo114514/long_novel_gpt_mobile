import '../models/chapter.dart';
import '../models/template_model.dart';
import 'api_service.dart';
import 'database_service.dart';

class EnhanceService {
  static final EnhanceService _instance = EnhanceService._internal();
  factory EnhanceService() => _instance;
  EnhanceService._internal();

  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService();

  // ═══════════════════════════════════════
  //  窗口合并加料
  // ═══════════════════════════════════════

  Future<Chapter> enhanceChapter(
    Chapter chapter,
    TemplateModel template,
    List<int> sceneIndices, {
    void Function(int current, int total)? onProgress,
    String? previousChapterEnding,
    String? previousChapterSummary,
  }) async {
    if (sceneIndices.isEmpty) return chapter;

    // 1. 收集锚点位置
    final anchors = <_Anchor>[];
    for (final idx in sceneIndices) {
      if (idx < 0 || idx >= chapter.scenes.length) continue;
      final s = chapter.scenes[idx] as Map<String, dynamic>;
      final anchorText = s['anchor_text']?.toString() ?? '';
      if (anchorText.isEmpty) continue;
      final pos = _findPosition(chapter.originalContent, anchorText);
      if (pos < 0) continue;
      anchors.add(_Anchor(idx: idx, pos: pos, scene: s));
    }
    anchors.sort((a, b) => a.pos.compareTo(b.pos));

    // 2. 合并成窗口
    final windows = _mergeWindows(anchors, chapter.originalContent.length);

    // 3. 按窗口反向替换（从后往前，避免位置偏移）
    String enhancedContent = chapter.originalContent;
    final processedSceneIndices = <int>[];

    for (int wi = 0; wi < windows.length; wi++) {
      final w = windows[wi];
      onProgress?.call(wi + 1, windows.length);

      // 构造窗口内容
      final sceneIds = <String>[];
      String labeledText = _buildLabeledText(enhancedContent, w, anchors, sceneIds);

      // 如果是第一个窗口，且有前章上下文，注入衔接信息
      if (wi == 0 && (previousChapterEnding != null || previousChapterSummary != null)) {
        final buf = StringBuffer();
        buf.writeln('[前章上下文 —— 请确保本章加料与上一章的情节自然衔接，不重复、不冲突]');
        if (previousChapterSummary != null && previousChapterSummary.isNotEmpty) {
          buf.writeln('上一章加料摘要：$previousChapterSummary');
        }
        if (previousChapterEnding != null && previousChapterEnding.isNotEmpty) {
          final tail = previousChapterEnding.length > 500
              ? previousChapterEnding.substring(previousChapterEnding.length - 500)
              : previousChapterEnding;
          buf.writeln('上一章结尾原文：$tail');
        }
        buf.writeln('[前章上下文结束]\n');
        labeledText = '${buf.toString()}\n$labeledText';
      }

      // 获取该组场景的 specific 规则
      final fullRewriteRules = template.getFullRewriteRule(sceneIds);

      // 调用 API
      final result = await _api.enhanceWindow(
        breakArmor: template.breakArmor,
        rewriteRules: fullRewriteRules,
        windowContent: labeledText,
        sceneCount: w.anchorCount,
      );

      // 替换窗口区域
      enhancedContent = _replaceRange(enhancedContent, w.start, w.end, result);
      processedSceneIndices.addAll(w.anchorIndices);
    }

    // 清理：去掉标注标记（万一 AI 没去干净）
    enhancedContent = enhancedContent.replaceAll(RegExp(r'\[★[^]]*\]'), '');

    return chapter.copyWith(
      enhancedContent: enhancedContent,
      enhancedWordCount: _countCh(enhancedContent),
      status: ChapterStatus.enhanced,
      selectedScenes: processedSceneIndices,
    );
  }

  // ═══════════════════════════════════════
  //  合并逻辑
  // ═══════════════════════════════════════

  List<_Window> _mergeWindows(List<_Anchor> anchors, int totalLen) {
    if (anchors.isEmpty) return [];

    // 按 2000字间距分组合并
    final groups = <List<_Anchor>>[];
    var current = <_Anchor>[anchors.first];
    for (int i = 1; i < anchors.length; i++) {
      if (anchors[i].pos - anchors[i - 1].pos <= 2000) {
        current.add(anchors[i]);
      } else {
        groups.add(current);
        current = [anchors[i]];
      }
    }
    groups.add(current);

    // 每组生成窗口
    final windows = <_Window>[];
    for (final group in groups) {
      int start = (group.first.pos - 1500).clamp(0, totalLen);
      int end = (group.last.pos + 1500).clamp(0, totalLen);

      // 窗口过大则拆分
      if (end - start > 4000) {
        final mid = (start + end) ~/ 2;
        windows.add(_Window(start: start, end: mid, anchorCount: 0, anchorIndices: []));
        windows.add(_Window(start: mid, end: end, anchorCount: 0, anchorIndices: []));
        // 重新分配锚点到合适的窗口
        for (final a in group) {
          if (a.pos < mid) {
            windows[windows.length - 2].anchorIndices.add(a.idx);
            windows[windows.length - 2].anchorCount++;
          } else {
            windows[windows.length - 1].anchorIndices.add(a.idx);
            windows[windows.length - 1].anchorCount++;
          }
        }
      } else {
        windows.add(_Window(
          start: start, end: end,
          anchorCount: group.length,
          anchorIndices: group.map((a) => a.idx).toList(),
        ));
      }
    }
    return windows;
  }

  // ═══════════════════════════════════════
  //  标注原文：锚点嵌入在正文里
  // ═══════════════════════════════════════

  String _buildLabeledText(String content, _Window window, List<_Anchor> allAnchors, List<String> outSceneIds) {
    // 取窗口内容
    final windowText = content.substring(window.start, window.end);

    // 找出窗口内的锚点
    final windowAnchors = allAnchors.where((a) => a.pos >= window.start && a.pos <= window.end).toList();

    if (windowAnchors.isEmpty) return windowText;

    // 在锚点位置插入标注（从后往前插入，避免位置偏移）
    final buf = windowText.split('');
    final sortedDesc = List<_Anchor>.from(windowAnchors)
      ..sort((a, b) => b.pos.compareTo(a.pos));

    for (final a in sortedDesc) {
      final localPos = a.pos - window.start;
      final scene = a.scene;
      final type = scene['type']?.toString() ?? '';
      final suggestion = scene['suggestion']?.toString() ?? '';
      final desc = scene['description']?.toString() ?? '';

      outSceneIds.add(type);

      final marker = '\n[★${type}|${suggestion}|${desc}]\n';
      if (localPos >= 0 && localPos <= buf.length) {
        buf.insertAll(localPos, marker.codeUnits.map((c) => String.fromCharCode(c)));
      }
    }

    return buf.join();
  }

  // ═══════════════════════════════════════
  //  批量加料
  // ═══════════════════════════════════════

  Future<int> batchEnhance(
    List<Chapter> chapters,
    TemplateModel template, {
    void Function(int current, int total, String status)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    int success = 0;

    for (int i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      if (shouldCancel != null && shouldCancel()) { onProgress?.call(i, chapters.length, '已取消'); break; }
      if (ch.scenes.isEmpty) { onProgress?.call(i + 1, chapters.length, '跳过（无场景）'); continue; }

      final autoSelected = <int>[];
      for (int j = 0; j < ch.scenes.length; j++) {
        if (((ch.scenes[j] as Map)['priority'] as int? ?? 3) >= 3) autoSelected.add(j);
      }
      if (autoSelected.isEmpty) { onProgress?.call(i + 1, chapters.length, '跳过'); continue; }

      try {
        onProgress?.call(i + 1, chapters.length, '加料中...');
        // 拿上一章的上下文传给本章
        String? prevEnding, prevSummary;
        if (i > 0) {
          final prev = await _db.getChapterById(chapters[i - 1].id!);
          if (prev != null) {
            if (prev.enhancedContent != null && prev.enhancedContent!.isNotEmpty) {
              prevEnding = prev.enhancedContent;
            }
            if (prev.analysisResult != null) {
              final ar = prev.analysisResult!;
              final scenes = (ar['scenes'] as List?)?.join('、') ?? '';
              final summary = ar['summary']?.toString() ?? '';
              prevSummary = '场景：$scenes。摘要：$summary';
            }
          }
        }
        final enhanced = await enhanceChapter(ch, template, autoSelected,
          previousChapterEnding: prevEnding,
          previousChapterSummary: prevSummary,
        );
        await _db.updateChapter(enhanced);
        success++;
      } catch (e) {
        onProgress?.call(i + 1, chapters.length, '失败');
      }
    }
    return success;
  }

  // ═══════════════════════════════════════
  //  工具方法
  // ═══════════════════════════════════════

  int _findPosition(String content, String anchor) {
    // 精确匹配
    int pos = content.indexOf(anchor);
    if (pos >= 0) return pos;
    // 模糊：取前 8 个字匹配
    if (anchor.length > 8) {
      pos = content.indexOf(anchor.substring(0, 8));
      if (pos >= 0) return pos;
    }
    // 模糊：取后 8 个字匹配
    if (anchor.length > 8) {
      pos = content.indexOf(anchor.substring(anchor.length - 8));
      if (pos >= 0) return pos;
    }
    return -1;
  }

  String _replaceRange(String content, int start, int end, String replacement) {
    if (start < 0 || end > content.length || start >= end) return content;
    return content.substring(0, start) + replacement + content.substring(end);
  }

  static int _countCh(String text) {
    int c = 0;
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text[i])) c++;
    }
    return c;
  }
}

class _Anchor {
  final int idx, pos;
  final Map<String, dynamic> scene;
  _Anchor({required this.idx, required this.pos, required this.scene});
}

class _Window {
  final int start, end;
  int anchorCount;
  final List<int> anchorIndices;
  _Window({required this.start, required this.end, required this.anchorCount, required this.anchorIndices});
}
