import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/chapter.dart';
import '../services/file_service.dart';
import '../widgets/chapter_status_badge.dart';
import 'chapter_detail_page.dart';
import 'quick_review_page.dart';

class ChaptersPage extends StatefulWidget {
  const ChaptersPage({super.key});
  @override
  State<ChaptersPage> createState() => _ChaptersPageState();
}

class _ChaptersPageState extends State<ChaptersPage> {
  final Set<String> _selectedIds = {};
  bool _batchMode = false;
  String _batchProgress = '';

  @override
  void initState() {
    super.initState();
    final p = context.read<ProjectProvider>();
    if (p.currentProject != null) p.loadChapters(p.currentProject!.id);
  }

  Future<void> _runBatch(String operation) async {
    final p = context.read<ProjectProvider>();
    if (p.template == null) { _snack('请先在设置中加载加料模板'); return; }

    final ids = _selectedIds.isNotEmpty ? _selectedIds.toList() : p.currentChapters.map((c) => c.id).toList();
    if (ids.isEmpty) { _snack('没有可处理的章节'); return; }

    setState(() => _batchProgress = '准备中...');
    int success = 0;

    switch (operation) {
      case 'analyze':
        success = await p.batchAnalyze(ids, onProgress: (c, t, s) => setState(() => _batchProgress = '$s ($c/$t)'));
        break;
      case 'detect':
        success = await p.batchDetectScenes(ids, onProgress: (c, t, s) => setState(() => _batchProgress = '$s ($c/$t)'));
        break;
      case 'enhance':
        final enhIds = ids.where((id) {
          final ch = p.currentChapters.firstWhere((c) => c.id == id, orElse: () => p.currentChapters.first);
          return ch.scenes.isNotEmpty;
        }).toList();
        if (enhIds.isEmpty) { _snack('没有已识别场景的章节'); return; }
        success = await p.batchEnhance(enhIds, onProgress: (c, t, s) => setState(() => _batchProgress = '$s ($c/$t)'));
        break;
    }
    setState(() => _batchProgress = '完成: $success/${ids.length}章');
    Future.delayed(const Duration(seconds: 2), () => mounted ? setState(() => _batchProgress = '') : null);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(builder: (ctx, p, _) {
      final proj = p.currentProject;
      if (proj == null) return const Scaffold(body: Center(child: Text('无项目')));

      return Scaffold(
        appBar: AppBar(
          title: Text(proj.title),
          actions: [
            IconButton(icon: Icon(_batchMode ? Icons.close : Icons.checklist), tooltip: '批量模式', onPressed: () => setState(() { _batchMode = !_batchMode; _selectedIds.clear(); })),
            if (p.completedCount > 0) ...[IconButton(icon: const Icon(Icons.rate_review), tooltip: '快速审阅', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickReviewPage(projectId: proj.id))))],
            IconButton(icon: const Icon(Icons.ios_share), tooltip: '导出', onPressed: () async {
              try { final path = await FileService().exportNovel(proj.title, p.currentChapters); _snack('已导出: $path'); } catch (e) { _snack('导出失败: $e'); }
            }),
            IconButton(icon: const Icon(Icons.settings), tooltip: '设置', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
          ],
        ),
        body: Column(children: [
          Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade50, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Text('加料进度', style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${p.processedCount}/${p.currentChapters.length}章')]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: p.progress, minHeight: 6, backgroundColor: Colors.grey.shade200)),
            if (p.template != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('模板: ${p.template!.name}', style: TextStyle(fontSize: 11, color: Colors.blue.shade700))),
          ])),
          if (_batchProgress.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.orange.shade50, child: Text(_batchProgress, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: ListView(padding: const EdgeInsets.all(8), children: p.currentChapters.map((ch) => _buildTile(ch, p)).toList())),
        ]),
        bottomNavigationBar: _batchMode ? _buildBatchBar(p) : null,
      );
    });
  }

  Widget _buildTile(Chapter ch, ProjectProvider p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: _batchMode ? () => setState(() { if (_selectedIds.contains(ch.id)) _selectedIds.remove(ch.id); else _selectedIds.add(ch.id); }) : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChapterDetailPage(chapterId: ch.id))),
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          if (_batchMode) Checkbox(value: _selectedIds.contains(ch.id), onChanged: (_) => setState(() { if (_selectedIds.contains(ch.id)) _selectedIds.remove(ch.id); else _selectedIds.add(ch.id); }), visualDensity: VisualDensity.compact),
          ChapterStatusBadge(status: ch.status),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ch.displayTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text(ch.enhancedWordCount > 0 ? '${ch.wordCount}字 → ${ch.enhancedWordCount}字' : '${ch.wordCount}字', style: TextStyle(fontSize: 12, color: ch.enhancedWordCount > 0 ? Colors.green : Colors.grey)),
          ])),
          Icon(Icons.chevron_right, color: Colors.grey.shade300),
        ])),
      ),
    );
  }

  Widget _buildBatchBar(ProjectProvider p) {
    final hasSelection = _selectedIds.isNotEmpty;
    return SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => _selectedIds.isEmpty ? setState(() => _selectedIds.addAll(p.currentChapters.map((c) => c.id))) : setState(() => _selectedIds.clear()), child: Text(_selectedIds.isEmpty ? '全选 (${p.currentChapters.length})' : '取消全选'))),
      const SizedBox(width: 8),
      Expanded(child: FilledButton.tonal(onPressed: () => _runBatch('analyze'), child: const Text('分析'))),
      const SizedBox(width: 4),
      Expanded(child: FilledButton.tonal(onPressed: () => _runBatch('detect'), child: const Text('识别'))),
      const SizedBox(width: 4),
      Expanded(child: FilledButton(onPressed: () => _runBatch('enhance'), child: const Text('加料'))),
    ])));
  }
}
import 'quick_review_page.dart';
import 'settings_page.dart';