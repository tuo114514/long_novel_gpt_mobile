import 'package:flutter/material.dart';
import '../models/chapter.dart';

class ChapterStatusBadge extends StatelessWidget {
  final ChapterStatus status;
  const ChapterStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status.statusText, style: TextStyle(fontSize: 12, color: _textColor, fontWeight: FontWeight.w500)),
    );
  }

  Color get _color {
    switch (status) {
      case ChapterStatus.pending: return Colors.grey.shade200;
      case ChapterStatus.analyzed: return Colors.blue.shade100;
      case ChapterStatus.scenesSelected: return Colors.orange.shade100;
      case ChapterStatus.enhanced: return Colors.green.shade100;
      case ChapterStatus.reviewed: return Colors.purple.shade100;
    }
  }

  Color get _textColor {
    switch (status) {
      case ChapterStatus.pending: return Colors.grey.shade700;
      case ChapterStatus.analyzed: return Colors.blue.shade800;
      case ChapterStatus.scenesSelected: return Colors.orange.shade800;
      case ChapterStatus.enhanced: return Colors.green.shade800;
      case ChapterStatus.reviewed: return Colors.purple.shade800;
    }
  }
}
