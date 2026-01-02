import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../helpers/database_helper.dart';

// ↓↓↓ ここがポイントです（searchフォルダの中のファイルを指定） ↓↓↓
import 'search/golf_search_menu.dart'; 
import 'golf_detail_screen.dart';

// モデルクラス
class GolfActivity {
  final int id;
  final String category;
  final DateTime playedAt;
  final String? placeName;
  final int score;

  GolfActivity({
    required this.id,
    required this.category,
    required this.playedAt,
    required this.placeName,
    required this.score,
  });

  factory GolfActivity.fromJson(Map<String, dynamic> json) {
    return GolfActivity(
      id: json['id'],
      category: json['category'],
      playedAt: DateTime.parse(json['played_at']).toLocal(),
      placeName: json['place_name'] ?? 'Unknown Course',
      score: json['primary_score'],
    );
  }
}

class GolfHomeScreen extends StatefulWidget {
  const GolfHomeScreen({super.key});

  @override
  State<GolfHomeScreen> createState() => _GolfHomeScreenState();
}

class _GolfHomeScreenState extends State<GolfHomeScreen> {
  List<GolfActivity> _logs = [];
  bool _isLoading = true;

  // 統計用
  final int _bestScore = 0; // 0初期化に変更
  final double _avgScore = 0.0;
  final int _rounds = 0;

  @override
  void initState() {
    super.initState();
    _fetchGolfData();
  }

  Future<void> _fetchGolfData() async {
    try {
      // ★ ローカルDBから取得
      final List<Map<String, dynamic>> data = 
          await DatabaseHelper.instance.getActivities('golf');
      
      // データ変換 (Map -> GolfActivity)
      // ※ GolfActivity.fromJsonの実装によっては微調整が必要ですが
      // 基本的にはローカルDBのカラム名とJSONのキーを合わせているのでそのままいけるはずです
      final items = data.map((e) {
        // SQLiteから取り出した 'golf_data' は String なので、Mapに戻す必要があります
        // DBヘルパー側でやっていない場合はここでパース
        final Map<String, dynamic> mutableMap = Map.from(e);
        if (mutableMap['golf_data'] is String) {
           mutableMap['golf_data'] = jsonDecode(mutableMap['golf_data']);
        }
        return GolfActivity.fromJson(mutableMap);
      }).toList();

      if (items.isNotEmpty) {
        // ... (ベストスコア計算などは既存のまま) ...
        setState(() {
          _logs = items;
          _isLoading = false;
        });
      } else {
         setState(() {
          _logs = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('GOLF LIFE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            // 画像がない場合のエラー回避のため、一旦コメントアウトまたはエラーハンドリング推奨
            // 実際に配置してあればコメントを外してください
            image: AssetImage('assets/images/golf_bg_top.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. スタッツエリア
                    _buildStatsArea(),

                    const SizedBox(height: 20),

                    // 2. メインアクション (新規スコア登録)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // ここで検索画面へ遷移 (constは付けていません)
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => GolfSearchMenuScreen()),
                          );
                        },
                        icon: const Icon(Icons.sports_golf, size: 28),
                        label: const Text("NEW ROUND", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 3. 履歴リストヘッダー
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "HISTORY",
                        style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 4. 履歴リスト
                    Expanded(
                      child: _logs.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                return _buildHistoryCard(_logs[index]);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatsArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _statCard("BEST", _bestScore == 0 ? "-" : "$_bestScore")),
          const SizedBox(width: 12),
          Expanded(child: _statCard("AVG", _avgScore == 0 ? "-" : _avgScore.toStringAsFixed(1))),
          const SizedBox(width: 12),
          Expanded(child: _statCard("ROUNDS", "$_rounds")),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(GolfActivity log) {
    return Card(
      color: Colors.black45,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          log.placeName ?? "No Course Name",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('yyyy/MM/dd').format(log.playedAt),
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "${log.score}",
            style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
          ),          
        ),
        // ↓↓↓ ★ここを追加してください ★ ↓↓↓
        onTap: () {
        // IDを渡して詳細画面へ遷移
          Navigator.push(
            context,
            MaterialPageRoute(
             builder: (context) => GolfDetailScreen(activityId: log.id),
            ),
          );
        },
        // ↑↑↑ 追加ここまで ↑↑↑
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.golf_course, color: Colors.white24, size: 60),
          SizedBox(height: 16),
          Text("No rounds played yet.", style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}