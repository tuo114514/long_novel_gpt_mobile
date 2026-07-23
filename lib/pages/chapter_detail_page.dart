import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/chapter.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/enhance_service.dart';
import '../widgets/scene_card.dart';
import 'compare_page.dart';

class ChapterDetailPage extends StatefulWidget {
  final String chapterId;
  const ChapterDetailPage({super.key, required this.chapterId});

  @override
  State<ChapterDetailPage> createState() => _ChapterDetailPageState();
}

class _ChapterDetailPageState extends State<ChapterDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Chapter? _ch;
  final _selectedScenes = <int>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    _ch = await DatabaseService().getChapterById(widget.chapterId);
    if (_ch != null && mounted) {
      setState(() {});
      if (_ch!.selectedScenes.isNotEmpty) _selectedScenes.addAll(_ch!.selectedScenes);
    }
  }

  Future<void> _analyze() async {
    final p = context.read<ProjectProvider>();
    if (p.template == null || _ch == null) return;
    setState(() => _busy = true);
    try {
      final result = await ApiService().analyzeChapter(_ch!.originalContent, p.template!.summaryPrompt);
      _ch = _ch!.copyWith(analysisResult: result, status: ChapterStatus.analyzed);
      await DatabaseService().updateChapter(_ch!);
      p.loadChapters(_ch!.projectId);
      _tabCtrl.animateTo(1);
    } catch (e) { _snack('分析失败: $e'); }
    setState(() => _busy = false);
  }

  Future<void> _detectScenes() async {
    final p = context.read<ProjectProvider>();
    if (p.template == null || _ch == null) return;
    setState(() => _busy = true);
    try {
      final rulesText = p.template!.getRecognitionRulesText();
      final scenes = await ApiService().detectScenes(_ch!.originalContent, rulesText);
      // 按 priority 降序排列
      scenes.sort((a, b) => (b['priority'] as int? ?? 3).compareTo(a['priority'] as int? ?? 3));
      _ch = _ch!.copyWith(scenes: scenes, status: ChapterStatus.scenesSelected);
      await DatabaseService().updateChapter(_ch!);
      p.loadChapters(_ch!.projectId);
      // 自动勾选 priority >= 3
      _selectedScenes.clear();
      for (int i = 0; i < scenes.length; i++) { if ((scenes[i]['priority'] as int? ?? 3) >= 3) _selectedScenes.add(i); }
      _tabCtrl.animateTo(2);
    } catch (e) { _snack('识别失败: $e'); }
    setState(() => _busy = false);
  }

  Future<void> _enhance() async {
    final p = context.read<ProjectProvider>();
    if (p.template == null || _ch == null || _selectedScenes.isEmpty) return;
    setState(() => _busy = true);
    try {
      final enhanced = await EnhanceService().enhanceChapter(_ch!, p.template!, _selectedScenes.toList());
      await DatabaseService().updateChapter(enhanced);
      p.loadChapters(enhanced.projectId);
      _ch = enhanced;
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ComparePage(chapterId: _ch!.id)));
    } catch (e) { _snack('加料失败: $e'); }
    setState(() => _busy = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_ch == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final ch = _ch!;
    final p = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(ch.displayTitle), actions: [
        if (ch.status.index >= ChapterStatus.scenesSelected.index)
          IconButton(icon: const Icon(Icons.auto_awesome), tooltip: '加料', onPressed: _busy ? null : _enhance),
        PopupMenuButton<String>(onSelected: (v) { if (v == 're') _analyze(); else if (v == 'redetect') _detectScenes(); },
          itemBuilder: (_) => [const PopupMenuItem(value: 're', child: Text('重新分析')), const PopupMenuItem(value: 'redetect', child: Text('重新识别'))]),
      ]),
      body: Column(children: [
        TabBar(controller: _tabCtrl, tabs: const [Tab(text: '原文'), Tab(text: '分析'), Tab(text: '场景')]),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [_originalTab(ch), _analysisTab(ch), _scenesTab(ch, p)]),),
      ]),
    );
  }

  Widget _originalTab(Chapter ch) {
    if (ch.enhancedContent != null) {
      return Column(children: [
        MaterialBanner(content: const Text('已加料，可查看对比'), backgroundColor: Colors.blue.shade50, actions: [TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComparePage(chapterId: ch.id))), child: const Text('查看对比'))]),
        Expanded(child: _textView(ch.originalContent)),
      ]);
    }
    return _textView(ch.originalContent);
  }

  Widget _analysisTab(Chapter ch) {
    if (ch.analysisResult == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _analyze, icon: const Icon(Icons.auto_fix_high), label: const Text('分析本章内容')),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      ]));
    }
    final a = ch.analysisResult!;
    return ListView(padding: const EdgeInsets.all(12), children: [
      _card('📋 内容摘要', a['summary']?.toString() ?? '-'),
      if (a['characters'] != null && (a['characters'] as List).isNotEmpty) _card('👤 出场人物', (a['characters'] as List).join('、')),
      if (a['scenes'] != null && (a['scenes'] as List).isNotEmpty) _card('🎬 场景类型', (a['scenes'] as List).join('、')),
      if (a['plot_points'] != null && (a['plot_points'] as List).isNotEmpty) _card('📌 关键情节', (a['plot_points'] as List).map((p) => '• $p').join('\n')),
      if (a['emotion'] != null) _card('💭 情感基调', a['emotion'].toString()),
      if (a['nsfw_potential'] != null) _card('🔥 加料潜力', a['nsfw_potential'].toString()),
    ]);
  }

  Widget _scenesTab(Chapter ch, ProjectProvider p) {
    if (ch.scenes.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _detectScenes, icon: const Icon(Icons.search), label: const Text('识别可加料场景')),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
      ]));
    }

    return Column(children: [
      Padding(padding: const EdgeInsets.all(8), child: Row(children: [
        Text('共${ch.scenes.length}个场景，已选${_selectedScenes.length}', style: const TextStyle(fontSize: 13)),
        const Spacer(),
        TextButton(onPressed: () => setState(() { if (_selectedScenes.length == ch.scenes.length) _selectedScenes.clear(); else _selectedScenes.addAll(List.generate(ch.scenes.length, (i) => i)); }), child: Text(_selectedScenes.length == ch.scenes.length ? '取消全选' : '全选')),
      ])),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(4), itemCount: ch.scenes.length, itemBuilder: (_, i) {
        final s = Map<String, dynamic>.from(ch.scenes[i]);
        return SceneCard(scene: s, isSelected: _selectedScenes.contains(i), onChanged: (v) => setState(() { if (v) _selectedScenes.add(i); else _selectedScenes.remove(i); }));
      })),
      SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: FilledButton.icon(
        onPressed: (_busy || _selectedScenes.isEmpty) ? null : _enhance,
        icon: const Icon(Icons.auto_awesome),
        label: Text('开始加料 (${_selectedScenes.length}个场景)'),
      ))),
    ]);
  }

  Widget _card(String title, String content) {
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 6),
      SelectableText(content, style: const TextStyle(fontSize: 14, height: 1.5)),
    ])));
  }

  Widget _textView(String text) => SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.7)));
}
