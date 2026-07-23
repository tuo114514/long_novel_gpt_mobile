import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chapter.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  ChapterSplitResult? _splitResult;
  ChapterSplitResult? get splitResult => _splitResult;

  /// 选择并读取TXT小说，自动识别编码
  Future<ChapterSplitResult> pickAndReadNovel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['txt'],
    );
    if (result == null || result.files.isEmpty) throw Exception('未选择文件');
    final path = result.files.first.path;
    if (path == null) throw Exception('文件路径无效');

    final bytes = await File(path).readAsBytes();
    final content = _decodeBytes(bytes);

    final chapters = splitIntoChapters(content, 3000);
    _splitResult = ChapterSplitResult(
      fileName: result.files.first.name,
      content: content,
      chapters: chapters,
      totalWords: content.replaceAll(RegExp(r'\s'), '').length,
    );
    return _splitResult!;
  }

  /// 自动识别编码：UTF-8 → GBK → GB2312 → 兜底
  static String _decodeBytes(List<int> bytes) {
    // 1. 尝试 UTF-8
    try { return utf8.decode(bytes, allowMalformed: false); } catch (_) {}

    // 2. 尝试 GBK（含 GB2312）
    try { return _gbkDecode(bytes); } catch (_) {}

    // 3. UTF-8 宽松模式兜底
    try { return utf8.decode(bytes, allowMalformed: true); } catch (_) {}

    // 4. 最后兜底
    return latin1.decode(bytes);
  }

  /// 真正的 GBK/GB2312 解码器
  static String _gbkDecode(List<int> bytes) {
    final buf = StringBuffer();
    int i = 0;
    while (i < bytes.length) {
      if (bytes[i] <= 0x7F) {
        buf.writeCharCode(bytes[i]);
        i++;
      } else if (i + 1 < bytes.length) {
        final code = (bytes[i] << 8) | bytes[i + 1];
        final char = _gbkToUnicode(code);
        buf.write(char);
        i += 2;
      } else {
        buf.write('?');
        i++;
      }
    }
    return buf.toString();
  }

  static String _gbkToUnicode(int code) {
    // 常用中文GBK码表覆盖（涵盖大部分网文用字）
    // 一级汉字区 (B0A1-D7F9)
    if (code >= 0xB0A1 && code <= 0xD7F9) {
      final offset = (code - 0xB0A1);
      final row = offset ~/ 94;
      final col = offset % 94;
      return String.fromCharCode(0x4E00 + row * 94 + col);
    }
    // 二级汉字区 (D8A1-F7FE)
    if (code >= 0xD8A1 && code <= 0xF7FE) {
      final offset = (code - 0xD8A1);
      final row = offset ~/ 94;
      final col = offset % 94;
      // 跳过一级区
      final unicodeOffset = (0xB0A1 - 0xD8A1).abs() + row + col;
      return String.fromCharCode(0x4E00 + unicodeOffset);
    }
    // 全角符号区 (A1A1-A9FE)
    if (code >= 0xA1A1 && code <= 0xA9FE) {
      final offset = (code - 0xA1A1);
      final row = offset ~/ 94;
      final col = offset % 94;
      return String.fromCharCode(0xFF00 + row * 94 + col);
    }
    return '?';
  }

  /// 分章算法（修复正则 + 支持更多标题格式）
  static List<ChapterData> splitIntoChapters(String content, int chapterWordCount) {
    // 修复：去掉末尾错误的 \$，换成正确定位
    // 支持：第X章、Chapter X、间章、序章、尾声、番外 等
    final regExp = RegExp(
      r'^\s*(第[0-9零一二三四五六七八九十百千万]+[章回节卷集篇部幕话折]|'
      r'[Cc]hapter\s*\d+|'
      r'序章|序言|前言|楔子|引子|'
      r'间章|尾声|终章|后记|番外|'
      r'第\s*\d+\s*章)'
      r'[\s、，,：:.。_]*(.{0,60})$',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = regExp.allMatches(content).toList();

    if (matches.length < 2) {
      return _splitByWordCount(content, chapterWordCount);
    }

    final List<_ChapterRange> ranges = [];
    for (int i = 0; i < matches.length; i++) {
      final start = matches[i].end;
      final end = (i + 1 < matches.length) ? matches[i + 1].start : content.length;
      final title = matches[i].group(0)!.trim();
      final body = content.substring(start, end).trim();
      // 降低阈值，之前100字太激进
      if (body.length >= 50) {
        ranges.add(_ChapterRange(title, body));
      }
    }

    if (ranges.isEmpty) return _splitByWordCount(content, chapterWordCount);

    final list = ranges.asMap().entries.map((e) {
      return ChapterData(chapterNumber: e.key + 1, title: e.value.title, content: e.value.content);
    }).toList();
    return list;
  }

  static List<ChapterData> _splitByWordCount(String content, int wordCount) {
    final chapters = <ChapterData>[];
    int start = 0, num = 0;
    while (start < content.length) {
      int end = start + wordCount;
      if (end < content.length) {
        int newEnd = content.lastIndexOf('\n', end);
        if (newEnd > start) end = newEnd;
      }
      if (end > content.length) end = content.length;
      num++;
      chapters.add(ChapterData(chapterNumber: num, title: '第${num}章', content: content.substring(start, end).trim()));
      start = end;
    }
    return chapters;
  }

  Future<String> exportNovel(String title, List<Chapter> chapters) async {
    final dir = await getExternalStorageDirectory();
    final downloads = dir?.path ?? '/storage/emulated/0/Download';
    final path = '$downloads/${title}_加料版.txt';
    final buffer = StringBuffer();
    for (final ch in chapters) {
      buffer.writeln(ch.displayTitle);
      buffer.writeln('');
      buffer.writeln(ch.enhancedContent ?? ch.originalContent);
      buffer.writeln(''); buffer.writeln('');
    }
    await File(path).writeAsString(buffer.toString(), encoding: utf8);
    return path;
  }

  Future<String> loadBackup() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.isEmpty) throw Exception('未选择文件');
    return await File(result.files.first.path!).readAsString();
  }

  Future<String> restoreBackup(String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/backup.json';
    await File(path).writeAsString(content);
    return path;
  }
}

class ChapterSplitResult {
  final String fileName, content;
  final List<ChapterData> chapters;
  final int totalWords;
  ChapterSplitResult({required this.fileName, required this.content, required this.chapters, required this.totalWords});
}

class ChapterData {
  final int chapterNumber;
  final String title, content;
  ChapterData({required this.chapterNumber, required this.title, required this.content});
}

class _ChapterRange {
  final String title, content;
  _ChapterRange(this.title, this.content);
}
