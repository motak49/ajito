import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ajito_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // PostgreSQLのactivitiesテーブルに近い構造を作成
    // JSONBデータの代わりに TEXT 型で JSON文字列を保存します
    // is_synced: 0=未同期, 1=同期済み
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        played_at TEXT NOT NULL,
        place_name TEXT,
        summary_text TEXT,
        primary_score INTEGER NOT NULL,
        image_urls TEXT,
        mahjong_data TEXT,
        golf_data TEXT,
        is_synced INTEGER DEFAULT 0, 
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  // --- CRUD操作 ---

  // 1. 新規作成 (Create)
  Future<int> createActivity(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('activities', row);
  }

  // 2. 全件取得 (Read List) - カテゴリ指定可
  Future<List<Map<String, dynamic>>> getActivities(String category) async {
    final db = await instance.database;
    // 日付の新しい順に取得
    return await db.query(
      'activities',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'played_at DESC',
    );
  }

  // 3. ID指定取得 (Read Detail)
  Future<Map<String, dynamic>?> getActivity(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  // 4. 更新 (Update) - 同期フラグ更新などで使用
  Future<int> updateActivity(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'activities',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 5. 削除 (Delete)
  Future<int> deleteActivity(int id) async {
    final db = await instance.database;
    return await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}