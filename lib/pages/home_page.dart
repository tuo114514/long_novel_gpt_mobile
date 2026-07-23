import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../models/novel_project.dart';
import 'chapters_page.dart';
import 'import_novel_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Long Novel GPT'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())))],
      ),
      body: Consumer<ProjectProvider>(
        builder: (ctx, p, _) {
          if (p.projects.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('还没有小说项目', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const Text('点击右下角按钮导入第一本小说', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ]),
            );
          }
          return ListView(padding: const EdgeInsets.all(16), children: p.projects.map((proj) => _ProjectCard(project: proj, onTap: () async { await p.setCurrentProject(proj); if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const ChaptersPage())); }, onDelete: () => p.deleteProject(proj.id))).toList());
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportNovelPage())),
        tooltip: '导入小说',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final NovelProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ProjectCard({required this.project, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final progress = project.progress;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(project.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              PopupMenuButton<String>(
                onSelected: (v) { if (v == 'delete') onDelete(); },
                itemBuilder: (_) => [const PopupMenuItem(value: 'delete', child: Text('删除项目', style: TextStyle(color: Colors.red)))],
              ),
            ]),
            if (project.author.isNotEmpty) Text(project.author, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey.shade200)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${project.processedChapters}/${project.totalChapters}章', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Spacer(),
              Text('最后更新：${project.updateTime.month}/${project.updateTime.day}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
          ]),
        ),
      ),
    );
  }
}
