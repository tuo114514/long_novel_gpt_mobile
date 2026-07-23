import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/novel_project.dart';
import '../models/chapter.dart';
import '../models/api_config.dart';
import '../models/template_model.dart';
import '../services/database_service.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/file_service.dart';
import '../services/enhance_service.dart';

class ProjectProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ConfigService _config = ConfigService();
  final FileService _file = FileService();
  final ApiService _api = ApiService();
  final EnhanceService _enhance = EnhanceService();

  List<NovelProject> projects = [];
  NovelProject? currentProject;
  List<Chapter> currentChapters = [];
  ApiConfig apiConfig = ApiConfig();
  TemplateModel? template;
  String? templatePath;

  bool isLoading = false;
  String? loadingMessage;
  String? errorMessage;
  bool _cancelRequested = false;

  int get processedCount => currentChapters.where((c) => c.status.index >= ChapterStatus.enhanced.index).length;
  double get progress => currentChapters.isNotEmpty ? processedCount / currentChapters.length : 0;

  Future<void> loadProjects() async { projects = await _db.getAllProjects(); notifyListeners(); }
  Future<void> loadConfig() async { apiConfig = await _config.loadConfig(); notifyListeners(); }
  Future<void> saveConfig(ApiConfig config) async { await _config.saveConfig(config); apiConfig = config; notifyListeners(); }

  // ═══════════════════════════════════════
  //  模板加载
  // ═══════════════════════════════════════

  Future<void> loadTemplate(String path) async {
    final file = File(path);
    final json = await file.readAsString();
    template = TemplateModel.fromJsonFile(json);
    templatePath = path;
    notifyListeners();
  }

  void clearTemplate() { template = null; templatePath = null; notifyListeners(); }

  // ═══════════════════════════════════════
  //  创建项目（导入小说）
  // ═══════════════════════════════════════

  Future<NovelProject> createProject(String title, {String author = '', String desc = ''}) async {
    final splitResult = _file.splitResult;
    if (splitResult == null) throw Exception('请先选择文件');
    final project = NovelProject(
      title: title, author: author, description: desc,
      totalChapters: splitResult.chapters.length, totalWords: splitResult.totalWords,
    );
    await _db.insertProject(project);
    for (final cd in splitResult.chapters) {
      await _db.insertChapter(Chapter(
        projectId: project.id, chapterNumber: cd.chapterNumber,
        title: cd.title, originalContent: cd.content,
      ));
    }
    await loadProjects();
    return project;
  }

  // ═══════════════════════════════════════
  //  章节操作
  // ═══════════════════════════════════════

  Future<void> loadChapters(String projectId) async { currentChapters = await _db.getChaptersByProjectId(projectId); notifyListeners(); }
  Future<void> updateChapter(Chapter chapter) async {
    await _db.updateChapter(chapter);
    final idx = currentChapters.indexWhere((c) => c.id == chapter.id);
    if (idx >= 0) currentChapters[idx] = chapter;
    if (currentProject != null) {
      final processed = await _db.getProcessedCount(currentProject!.id);
      currentProject = currentProject!.copyWith(processedChapters: processed, updateTime: DateTime.now());
      await _db.updateProject(currentProject!);
    }
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    await _db.deleteProject(id);
    if (currentProject?.id == id) { currentProject = null; currentChapters = []; }
    await loadProjects();
    notifyListeners();
  }

  Future<void> setCurrentProject(NovelProject? project) async {
    currentProject = project;
    currentChapters = project != null ? await _db.getChaptersByProjectId(project.id) : [];
    notifyListeners();
  }

  // ═══════════════════════════════════════
  //  批量内容分析
  // ═══════════════════════════════════════

  Future<int> batchAnalyze(List<String> chapterIds, {void Function(int c, int t, String s)? onProgress}) async {
    if (template == null) throw Exception('请先加载模板');
    int success = 0; _cancelRequested = false;

    for (int i = 0; i < chapterIds.length; i++) {
      if (_cancelRequested) { onProgress?.call(i, chapterIds.length, '已取消'); break; }
      onProgress?.call(i + 1, chapterIds.length, '分析中...');
      try {
        final ch = await _db.getChapterById(chapterIds[i]);
        if (ch == null) continue;
        final result = await _api.analyzeChapter(ch.originalContent, template!.summaryPrompt);
        await _db.updateChapter(ch.copyWith(analysisResult: result, status: ChapterStatus.analyzed));
        success++;
        onProgress?.call(i + 1, chapterIds.length, '完成');
      } catch (e) {
        onProgress?.call(i + 1, chapterIds.length, '失败: $e');
      }
    }
    if (currentProject != null) {
      currentChapters = await _db.getChaptersByProjectId(currentProject!.id);
      notifyListeners();
    }
    return success;
  }

  // ═══════════════════════════════════════
  //  批量场景识别
  // ═══════════════════════════════════════

  Future<int> batchDetectScenes(List<String> chapterIds, {void Function(int c, int t, String s)? onProgress}) async {
    if (template == null) throw Exception('请先加载模板');
    int success = 0; _cancelRequested = false;
    final rulesText = template!.getRecognitionRulesText();

    for (int i = 0; i < chapterIds.length; i++) {
      if (_cancelRequested) { onProgress?.call(i, chapterIds.length, '已取消'); break; }
      onProgress?.call(i + 1, chapterIds.length, '识别中...');
      try {
        final ch = await _db.getChapterById(chapterIds[i]);
        if (ch == null) continue;
        final scenes = await _api.detectScenes(ch.originalContent, rulesText);
        await _db.updateChapter(ch.copyWith(scenes: scenes, status: ChapterStatus.scenesSelected));
        success++;
        onProgress?.call(i + 1, chapterIds.length, '完成');
      } catch (e) {
        onProgress?.call(i + 1, chapterIds.length, '失败: $e');
      }
    }
    if (currentProject != null) {
      currentChapters = await _db.getChaptersByProjectId(currentProject!.id);
      notifyListeners();
    }
    return success;
  }

  // ═══════════════════════════════════════
  //  批量加料
  // ═══════════════════════════════════════

  Future<int> batchEnhance(List<String> chapterIds, {void Function(int c, int t, String s)? onProgress}) async {
    if (template == null) throw Exception('请先加载模板');
    _cancelRequested = false;

    final chapters = <Chapter>[];
    for (final id in chapterIds) {
      final ch = await _db.getChapterById(id);
      if (ch != null) chapters.add(ch);
    }

    final result = await _enhance.batchEnhance(
      chapters, template!,
      onProgress: onProgress,
      shouldCancel: () => _cancelRequested,
    );

    if (currentProject != null) {
      currentChapters = await _db.getChaptersByProjectId(currentProject!.id);
      notifyListeners();
    }
    return result;
  }

  void cancelOperation() { _cancelRequested = true; notifyListeners(); }

  void setLoading(bool v, [String? msg]) { isLoading = v; loadingMessage = msg; errorMessage = null; notifyListeners(); }
  void setError(String err) { errorMessage = err; isLoading = false; notifyListeners(); }
}
