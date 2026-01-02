import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // グラフ描画用
import '../services/api_service.dart';
import 'score_entry_screen.dart'; // 入力画面へ遷移するため

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  
  // サーバーから取得するデータ
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // データを再読み込みする処理
  Future<void> _fetchData() async {
    setState(() { _isLoading = true; });
    final data = await _apiService.fetchDashboardStats();
    if (mounted) {
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★1. ヘッダーを追加（これで自動的に「←」ボタンが出ます）
      appBar: AppBar(
        title: const Text('戦績ダッシュボード'),
        backgroundColor: Colors.transparent, // 背景画像を活かすため透明に
        elevation: 0, // 影を消す
      ),
      // ★2. 背景画像をヘッダーの裏まで広げる設定
      extendBodyBehindAppBar: true,

      // 背景画像の設定（既存コードと同じ）
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/jantaku_bg.png'),
            fit: BoxFit.cover,
            opacity: 0.3,
          ),
          color: const Color(0xFF004D40),
        ),
        // ★3. コンテンツがヘッダーと被らないように少し下げる
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight), // ヘッダーの高さ分下げる
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDashboardContent(),
          ),
        ),
      ),
      
      // 入力画面へのFAB（既存コードと同じ）
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScoreEntryScreen()),
          );
          _fetchData();
        },
        label: const Text('闘牌開始'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildDashboardContent() {
    // データの取り出し（null安全対策）
    final totalScore = _stats?['total_score'] ?? 0;
    final recentGames = _stats?['recent_games'] as List<dynamic>? ?? [];
    final chartData = _stats?['chart_data'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ヘッダー（合計スコア）
            const Text(
              "今年の収支",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              totalScore > 0 ? "+$totalScore" : "$totalScore",
              style: TextStyle(
                color: totalScore >= 0 ? Colors.white : Colors.redAccent, // マイナスは赤
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto', // 数字が見やすいフォント
              ),
            ),
            const SizedBox(height: 24),

            // 2. 年間推移グラフ (折れ線)
            const Text("推移グラフ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildLineChart(chartData),
            ),

            const SizedBox(height: 32),

            // 3. 直近の戦績リスト
            const Text("直近の対局", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (recentGames.isEmpty)
              const Text("データがありません", style: TextStyle(color: Colors.grey)),
            
            ...recentGames.map((game) {
              final score = game['score'] as int;
              return Card(
                color: Colors.white10,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(game['place_name'] ?? '不明な雀荘', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(game['played_at']?.toString().substring(0, 10) ?? '', style: const TextStyle(color: Colors.grey)),
                  trailing: Text(
                    score > 0 ? "+$score" : "$score",
                    style: TextStyle(
                      color: score >= 0 ? Colors.lightGreenAccent : Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 80), // FABとかぶらないように余白
          ],
        ),
      ),
    );
  }

  // 折れ線グラフの構築
  Widget _buildLineChart(List<dynamic> data) {
    if (data.isEmpty) {
      return const Center(child: Text("データ不足", style: TextStyle(color: Colors.white30)));
    }

    // データをFlSpot形式に変換
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['cumulative_score'] as int).toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.white10, strokeWidth: 1);
        }),
        titlesData: FlTitlesData(show: false), // 軸ラベルはシンプル化のため一旦非表示
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent, // 線の色
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }
}