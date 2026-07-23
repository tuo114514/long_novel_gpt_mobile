import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../services/file_service.dart';

class ImportNovelPage extends StatefulWidget {
  const ImportNovelPage({super.key});
  @override
  State<ImportNovelPage> createState() => _ImportNovelPageState();
}

class _ImportNovelPageState extends State<ImportNovelPage> {
  final FileService _fileService = FileService();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  ChapterSplitResult? _result;
  bool _loading = false;

  @override
  void dispose() { _titleCtrl.dispose(); _authorCtrl.dispose(); super.dispose(); }

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      _result = await _fileService.pickAndReadNovel();
      _titleCtrl.text = _result!.fileName.replaceAll('.txt', '');
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件选择失败: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _confirmImport() async {
    if (_result == null || _titleCtrl.text.trim().isEmpty) return;
    try {
      final provider = context.read<ProjectProvider>();
      await provider.createProject(_titleCtrl.text.trim(), author: _authorCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('《${_titleCtrl.text.trim()}》导入成功，共${_result!.chapters.length}章')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入小说')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('选择TXT文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
            onPressed: _loading ? null : _pickFile,
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.folder_open),
            label: const Text('选择文件'),
          )),
          if (_result != null) ...[ const SizedBox(height: 12),
            Text('文件名：${_result!.fileName}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            Text('识别章节：${_result!.chapters.length}章', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            Text('总字数：${_result!.totalWords}字', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 12),
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '书名')),
          const SizedBox(height: 12),
          TextFormField(controller: _authorCtrl, decoration: const InputDecoration(labelText: '作者（可选）')),
        ]))),
        if (_result != null && _result!.chapters.isNotEmpty) ...[ const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('章节预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('共${_result!.chapters.length}章', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 12),
            SizedBox(height: 300, child: ListView.builder(itemCount: _result!.chapters.length > 5 ? 5 : _result!.chapters.length, itemBuilder: (ctx, i) {
              final ch = _result!.chapters[i];
              return ListTile(dense: true, leading: CircleAvatar(child: Text('${ch.chapterNumber}')), title: Text(ch.title), subtitle: Text('${ch.content.length}字', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)));
            })),
          ]))),
        ],
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, height: 56, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _result != null ? const Color(0xFF2196F3) : Colors.grey),
          onPressed: _result != null ? _confirmImport : null,
          child: const Text('确认导入'),
        )),
      ])),
    );
  }
}
