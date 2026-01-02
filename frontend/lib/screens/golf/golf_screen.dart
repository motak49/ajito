import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// データモデル（既存のものを流用可能ですが、念のため記載）
class Activity {
  final int id;
  final String category;
  final DateTime playedAt;
  final String? placeName;
  final int primaryScore;

  Activity({
    required this.id,
    required this.category,
    required this.playedAt,
    required this.placeName,
    required this.primaryScore,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      category: json['category'],
      playedAt: DateTime.parse(json['played_at']).toLocal(), // 表示用にLocal変換
      placeName: json['place_name'],
      primaryScore: json['primary_score'],
    );
  }
}

class GolfScreen extends StatefulWidget {
  const GolfScreen({super.key});

  @override
  State<GolfScreen> createState() => _GolfScreenState();
}

class _GolfScreenState extends State<GolfScreen> {
  List<Activity> _golfLogs = [];
  bool _isLoading = true;
  
  // 統計データ
  int _bestScore = 0;
  double _avgScore = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchGolfData();
  }

  Future<void> _fetchGolfData() async {
    // Android Emulator用のLocalhost指定
    final url = Uri.parse('http://10.0.2.2:8080/activities?category=golf');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final logs = data.map((json) => Activity.fromJson(json)).toList();

        setState(() {
          _golfLogs = logs;
          _calculateStats();
          _isLoading = false;
        });
      } else {
        // エラーハンドリング
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching golf data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    if (_golfLogs.isEmpty) return;

    // ベストスコア（ゴルフは低い方が良い）
    int best = _golfLogs[0].primaryScore;
    double total = 0;

    for (var log in _golfLogs) {
      if (log.primaryScore < best) {
        best = log.primaryScore;
      }
      total += log.primaryScore;
    }

    _bestScore = best;
    _avgScore = total / _golfLogs.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('GOLF LIFE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. 背景画像
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/golf_bg_top.png'), // 画像を用意してください
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken), // 暗くして文字を見やすく
              ),
            ),
          ),
          
          // 2. コンテンツ
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                    
                    // サマリーエリア
                    _buildSummaryCards(),

                    const SizedBox(height: 20),
                    
                    // 履歴リスト見出し
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Round History",
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    
                    // 履歴リスト
                    Expanded(
                      child: _golfLogs.isEmpty
                          ? const Center(child: Text("No rounds yet.", style: TextStyle(color: Colors.white)))
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 10, bottom: 80),
                              itemCount: _golfLogs.length,
                              itemBuilder: (context, index) {
                                final log = _golfLogs[index];
                                return _buildHistoryCard(log);
                              },
                            ),
                    ),
                  ],
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 次のステップで実装する登録画面へ
          // Navigator.push(...) 
        },
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.add, color: Colors.black87),
      ),
    );
  }

  // サマリーカード（ベストスコア・平均）
  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          _statCard("BEST SCORE", _golfLogs.isEmpty ? "-" : "$_bestScore", Colors.amber),
          const SizedBox(width: 12),
          _statCard("AVG SCORE", _golfLogs.isEmpty ? "-" : _avgScore.toStringAsFixed(1), Colors.lightBlueAccent),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: accentColor, fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 履歴リストアイテム
  Widget _buildHistoryCard(Activity log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sports_golf, color: Colors.greenAccent),
        ),
        title: Text(
          log.placeName ?? "Unknown Course",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          DateFormat('yyyy/MM/dd').format(log.playedAt),
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Text(
          "${log.primaryScore}",
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}