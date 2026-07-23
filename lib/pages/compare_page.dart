import 'package:flutter/material.dart';
import '../models/chapter.dart';
import '../services/database_service.dart';

class ComparePage extends StatefulWidget {
  final String chapterId;
  const ComparePage({super.key, required this.chapterId});

  @override
  State<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  Chapter? _ch;
  bool _showMarkers = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ch = await DatabaseService().getChapterById(widget.chapterId);
    if (ch != null && mounted) setState(() => _ch = ch);
  }

  Future<void> _accept() async {
    if (_ch == null) return;
    await DatabaseService().updateChapter(_ch!.copyWith(status: ChapterStatus.reviewed));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ch == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final content = _ch!.enhancedContent ?? _ch!.originalContent;
    final growth = _ch!.wordCount > 0 ? ((_ch!.enhancedWordCount - _ch!.wordCount) / _ch!.wordCount * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      appBar: AppBar(
        title: Text('加料结果 - ${_ch!.displayTitle}'),
        actions: [
          Center(child: Text('${_ch!.wordCount}→${_ch!.enhancedWordCount}字 +$growth%', style: const TextStyle(fontSize: 13, color: Colors.white70))),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          content,
          style: const TextStyle(fontSize: 16, height: 1.8),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), child: const Text('拒绝'))),
            const SizedBox(width: 16),
            Expanded(child: FilledButton(onPressed: _accept, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2196F3)), child: const Text('接受修改'))),
          ]),
        ),
      ),
    );
  }
}
