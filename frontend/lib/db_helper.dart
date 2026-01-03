import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "mahjong_log_v4.db");
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        place_name TEXT,
        played_at TEXT,
        player_count INTEGER,
        player1_name TEXT,
        player2_name TEXT,
        player3_name TEXT,
        player4_name TEXT,
        has_chip INTEGER DEFAULT 0,
        chip_p1 INTEGER DEFAULT 0,
        chip_p2 INTEGER DEFAULT 0,
        chip_p3 INTEGER DEFAULT 0,
        chip_p4 INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE local_rounds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        round_number INTEGER,
        score_p1 INTEGER,
        score_p2 INTEGER,
        score_p3 INTEGER,
        score_p4 INTEGER,
        FOREIGN KEY(session_id) REFERENCES local_sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE local_yakumans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        round_number INTEGER,
        player_index INTEGER,
        yakuman_name TEXT,
        image_path TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY(session_id) REFERENCES local_sessions(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- データ操作メソッド ---

  Future<int> insertSession(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('local_sessions', row);
  }

  Future<void> updateSessionChips(int sessionId, List<int> chips) async {
    Database db = await database;
    Map<String, dynamic> updateData = {
      'chip_p1': chips[0],
      'chip_p2': chips[1],
      'chip_p3': chips[2],
    };
    if (chips.length > 3) {
      updateData['chip_p4'] = chips[3];
    }
    await db.update(
      'local_sessions',
      updateData,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<Map<String, dynamic>?> getSession(int id) async {
    Database db = await database;
    final res = await db.query('local_sessions', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  Future<int> insertRound(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('local_rounds', row);
  }

  Future<int> insertYakuman(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('local_yakumans', row);
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    Database db = await database;
    return await db.query('local_sessions', orderBy: 'played_at DESC');
  }

  // ▼ 変更: セッション削除時に、紐づくラウンドや役満もまとめて削除する
  Future<void> deleteSession(int id) async {
    Database db = await database;
    await db.transaction((txn) async {
      // 子テーブルから先に削除（FK制約がある場合のため）
      await txn.delete('local_rounds', where: 'session_id = ?', whereArgs: [id]);
      await txn.delete('local_yakumans', where: 'session_id = ?', whereArgs: [id]);
      // 親テーブルを削除
      await txn.delete('local_sessions', where: 'id = ?', whereArgs: [id]);
    });
  }

  // 指定セッションの役満リストを取得
  Future<List<Map<String, dynamic>>> getYakumans(int sessionId) async {
    Database db = await database;
    return await db.query(
      'local_yakumans',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSessionSummaries(int year) async {
    Database db = await database;
    final sessions = await db.query(
      'local_sessions', 
      where: "strftime('%Y', played_at) = ?", 
      whereArgs: [year.toString()],
      orderBy: 'played_at DESC'
    );
    
    List<Map<String, dynamic>> results = [];

    for (var session in sessions) {
      int id = session['id'] as int;
      
      final rounds = await db.query('local_rounds', where: 'session_id = ?', whereArgs: [id]);
      List<int> scoreTotals = [0, 0, 0, 0];
      
      for (var r in rounds) {
        scoreTotals[0] += (r['score_p1'] as int? ?? 0);
        scoreTotals[1] += (r['score_p2'] as int? ?? 0);
        scoreTotals[2] += (r['score_p3'] as int? ?? 0);
        scoreTotals[3] += (r['score_p4'] as int? ?? 0);
      }
      
      List<int> chipTotals = [
        session['chip_p1'] as int? ?? 0,
        session['chip_p2'] as int? ?? 0,
        session['chip_p3'] as int? ?? 0,
        session['chip_p4'] as int? ?? 0,
      ];
      
      final yakumans = await db.query('local_yakumans', where: 'session_id = ?', whereArgs: [id]);
      bool hasYakuman = yakumans.isNotEmpty;

      results.add({
        ...session,
        'score_totals': scoreTotals,
        'chip_totals': chipTotals,
        'has_yakuman': hasYakuman,
      });
    }
    return results;
  }
}