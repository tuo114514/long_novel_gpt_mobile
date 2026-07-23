import 'package:flutter/material.dart';

class SceneCard extends StatelessWidget {
  final Map<String, dynamic> scene;
  final bool isSelected;
  final ValueChanged<bool> onChanged;

  const SceneCard({super.key, required this.scene, required this.isSelected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final type = scene['type']?.toString() ?? '';
    final desc = scene['description']?.toString() ?? '';
    final suggestion = scene['suggestion']?.toString() ?? '';
    final priority = (scene['priority'] as int?) ?? 3;
    final anchor = scene['anchor_text']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _typeChip(type),
          const Spacer(),
          Row(children: List.generate(priority, (_) => const Icon(Icons.star, color: Colors.amber, size: 16))),
          Checkbox(value: isSelected, onChanged: (v) => onChanged(v ?? false), visualDensity: VisualDensity.compact),
        ]),
        if (desc.isNotEmpty) ...[const SizedBox(height: 6), Text(desc, style: const TextStyle(fontSize: 13))],
        if (anchor.isNotEmpty) ...[const SizedBox(height: 2), Text('📍 $anchor', style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)],
        if (suggestion.isNotEmpty) ...[const SizedBox(height: 2), Text('💡 $suggestion', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)],
      ])),
    );
  }

  Widget _typeChip(String type) {
    Color bg;
    if (type.contains('乱伦') || type.contains('NTL')) bg = Colors.deepPurple.shade100;
    else if (type.contains('亲吻') || type.contains('暧昧')) bg = Colors.pink.shade100;
    else if (type.contains('战斗') || type.contains('敌对')) bg = Colors.red.shade100;
    else if (type.contains('公开') || type.contains('隐秘')) bg = Colors.cyan.shade100;
    else if (type.contains('洗澡') || type.contains('换装')) bg = Colors.orange.shade100;
    else if (type.contains('多女') || type.contains('群交')) bg = Colors.purple.shade100;
    else bg = Colors.grey.shade100;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Text(type, style: const TextStyle(fontSize: 11)));
  }
}
