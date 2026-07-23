import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/novel_project.dart';
import '../models/chapter.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'long_novel_gpt.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT DEFAULT '',
            description TEXT DEFAULT '',
            createTime TEXT NOT NULL,
            updateTime TEXT NOT NULL,
            totalChapters INTEGER DEFAULT 0,
            processedChapters INTEGER DEFAULT 0,
            totalWords INTEGER DEFAULT 0,
            enhancedWords INTEGER DEFAULT 0,
            enhanceLevel INTEGER DEFAULT 2,
            enhanceStyle TEXT DEFAULT 'standard'
          )
        ''');
        await db.execute('''
          CREATE TABLE chapters (
            id TEXT PRIMARY KEY,
            projectId TEXT NOT NULL,
            chapterNumber INTEGER NOT NULL,
            title TEXT NOT NULL,
            originalContent TEXT NOT NULL,
            enhancedContent TEXT,
            analysisResult TEXT,
            scenes TEXT DEFAULT '[]',
            selectedScenes TEXT DEFAULT '[]',
            status INTEGER DEFAULT 0,
            createTime TEXT NOT NULL,
            updateTime TEXT NOT NULL,
            wordCount INTEGER DEFAULT 0,
            enhancedWordCount INTEGER DEFAULT 0,
            FOREIGN KEY (projectId) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_chapters_project ON chapters(projectId)');
        await db.execute('CREATE INDEX idx_chapters_status ON chapters(status)');
      },
    );
  }

  // ─── 项目CRUD ───

  Future<int> insertProject(NovelProject project) async {
    final db = await database;
    return db.insert('projects', project.toMap());
  }

  Future<List<NovelProject>> getAllProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'updateTime DESC');
    return maps.map((m) => NovelProject.fromMap(m)).toList();
  }

  Future<NovelProject?> getProjectById(String id) async {
    final db = await database;
    final maps = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return NovelProject.fromMap(maps.first);
  }

  Future<int> updateProject(NovelProject project) async {
    final db = await database;
    return db.update('projects', project.copyWith(updateTime: DateTime.now()).toMap(),
        where: 'id = ?', whereArgs: [project.id]);
  }

  Future<int> deleteProject(String id) async {
    final db = await database;
    await db.delete('chapters', where: 'projectId = ?', whereArgs: [id]);
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ─── 章节CRUD ───

  Future<int> insertChapter(Chapter chapter) async {
    final db = await database;
    return db.insert('chapters', chapter.toMap());
  }

  Future<List<Chapter>> getChaptersByProjectId(String projectId) async {
    final db = await database;
    final maps = await db.query('chapters',
      where: 'projectId = ?', whereArgs: [projectId],
      orderBy: 'chapterNumber ASC');
    return maps.map((m) => Chapter.fromMap(m)).toList();
  }

  Future<Chapter?> getChapterById(String id) async {
    final db = await database;
    final maps = await db.query('chapters', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Chapter.fromMap(maps.first);
  }

  Future<int> updateChapter(Chapter chapter) async {
    final db = await database;
    return db.update('chapters', chapter.copyWith(updateTime: DateTime.now()).toMap(),
        where: 'id = ?', whereArgs: [chapter.id]);
  }

  Future<int> deleteChaptersByProjectId(String projectId) async {
    final db = await database;
    return db.delete('chapters', where: 'projectId = ?', whereArgs: [projectId]);
  }

  Future<int> getProcessedCount(String projectId) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM chapters WHERE projectId = ? AND status >= 3",
      [projectId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
