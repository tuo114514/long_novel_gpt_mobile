import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/chapter.dart';
import '../services/database_service.dart';
import 'compare_page.dart';

class QuickReviewPage extends StatefulWidget {
  final String projectId;
  const QuickReviewPage({super.key, required this.projectId});

  @override
  State<QuickReviewPage> createState() => _QuickReviewPageState();
}

class _QuickReviewPageState extends State<QuickReviewPage> {
  List<Chapter> _enhancedChapters = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseService().getChaptersByProjectId(widget.projectId);
    _enhancedChapters = all.where((c) => c.enhancedContent != null && c.enhancedContent!.isNotEmpty).toList();
    if (mounted) setState(() {});
  }

  Future<void> _accept(Chapter ch) async {
    await DatabaseService().updateChapter(ch.copyWith(status: ChapterStatus.reviewed));
    context.read<ProjectProvider>().loadChapters(ch.projectId);
    _load();
  }

  Future<void> _acceptAll() async {
    for (final ch in _enhancedChapters) {
      if (ch.status != ChapterStatus.reviewed) {
        await DatabaseService().updateChapter(ch.copyWith(status: ChapterStatus.reviewed));
      }
    }
    context.read<ProjectProvider>().loadChapters(widget.projectId);
    _load();
    _snack('已全部接受');
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final pending = _enhancedChapters.where((c) => c.status != ChapterStatus.reviewed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('快速审阅'),
        actions: [if (pending.isNotEmpty) TextButton(onPressed: _acceptAll, child: const Text('全部接受', style: TextStyle(color: Colors.white)))]),
      body: _enhancedChapters.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 64, color: Colors.grey), SizedBox(height: 12), Text('没有已加料章节', style: TextStyle(color: Colors.grey))]))
        : ListView(padding: const EdgeInsets.all(12), children: _enhancedChapters.map((ch) => _reviewTile(ch, ch.status != ChapterStatus.reviewed)).toList()),
    );
  }

  Widget _reviewTile(Chapter ch, bool showActions) {
    final growth = ch.wordCount > 0 ? ((ch.enhancedWordCount - ch.wordCount) / ch.wordCount * 100).toStringAsFixed(0) : '0';
    final preview = ch.enhancedContent != null && ch.enhancedContent!.length > 80 ? '${ch.enhancedContent!.substring(0, 80).replaceAll('\n', ' ')}...' : (ch.enhancedContent ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(ch.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Text('${ch.wordCount}字 → ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text('${ch.enhancedWordCount}字', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(' (+$growth%)', style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Text(preview, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (showActions) ...[const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => _accept(ch), child: const Text('✓ 接受')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComparePage(chapterId: ch.id))), child: const Text('对比')),
        ])],
      ])),
    );
  }
}
