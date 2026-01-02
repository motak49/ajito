import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// 詳細画面専用のデータモデル
class GolfDetailData {
  final int id;
  final String placeName;
  final DateTime playedAt;
  final int totalScore;
  final List<String> memberNames;
  final List<List<int>> scores;
  final String weather;
  final String wind;

  GolfDetailData({
    required this.id,
    required this.placeName,
    required this.playedAt,
    required this.totalScore,
    required this.memberNames,
    required this.scores,
    required this.weather,
    required this.wind,
  });

  factory GolfDetailData.fromJson(Map<String, dynamic> json) {
    // APIからネストされた golf_data を取得
    final golfJson = json['golf_data'] ?? {};
    
    // スコア配列のパース (JSON配列 -> List<List<int>>)
    var rawScores = golfJson['scores'] as List? ?? [];
    List<List<int>> parsedScores = rawScores.map((holeScores) {
      return (holeScores as List).map((s) => s as int).toList();
    }).toList();

    return GolfDetailData(
      id: json['id'],
      placeName: json['place_name'] ?? '',
      playedAt: DateTime.parse(json['played_at']).toLocal(),
      totalScore: json['primary_score'],
      memberNames: List<String>.from(golfJson['member_names'] ?? []),
      scores: parsedScores,
      weather: golfJson['weather'] ?? '',
      wind: golfJson['wind'] ?? '',
    );
  }
}

class GolfDetailScreen extends StatefulWidget {
  final int activityId; // 一覧画面から渡されるID

  const GolfDetailScreen({super.key, required this.activityId});

  @override
  State<GolfDetailScreen> createState() => _GolfDetailScreenState();
}

class _GolfDetailScreenState extends State<GolfDetailScreen> {
  GolfDetailData? _data;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 画面表示時にデータを取得
    _fetchDetail(widget.activityId);
  }

  Future<void> _fetchDetail(int id) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Go Backendのエンドポイント (GET /api/activities/:id)
    final url = Uri.parse('http://10.0.2.2:8080/api/activities/$id');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(res.body);
        setState(() {
          _data = GolfDetailData.fromJson(jsonMap);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "データ取得エラー (Status: ${res.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "通信エラー: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. ローディング表示
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    // 2. エラー表示
    if (_errorMessage != null || _data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(title: const Text("Error"), backgroundColor: Colors.transparent),
        body: Center(child: Text(_errorMessage ?? "データが見つかりません", style: const TextStyle(color: Colors.white))),
      );
    }

    final data = _data!;
    final formattedDate = DateFormat('yyyy/MM/dd (E)', 'ja_JP').format(data.playedAt);

    // 3. データ表示
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('ROUND RESULT', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2C2C2C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー情報
            _buildHeaderCard(data, formattedDate),
            
            const SizedBox(height: 24),
            
            // スコアカード
            const Text("SCORE CARD", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScoreCard(data),

            const SizedBox(height: 24),
            
            // コンディションなど
            _buildInfoRow("Weather", data.weather),
            const Divider(color: Colors.white24),
            _buildInfoRow("Wind", data.wind),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(GolfDetailData data, String dateStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green[900]!, Colors.green[800]!]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(data.placeName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(dateStr, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text("TOTAL", style: TextStyle(color: Colors.amber, fontSize: 16)),
              const SizedBox(width: 8),
              Text("${data.totalScore}", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(GolfDetailData data) {
    // メンバー名ヘッダー
    List<DataColumn> columns = [
      const DataColumn(label: Text('Hole', style: TextStyle(color: Colors.amber))),
    ];
    for (var name in data.memberNames) {
      columns.add(DataColumn(label: Text(name, style: const TextStyle(color: Colors.white))));
    }

    // 18ホール分の行データ
    List<DataRow> rows = [];
    for (int i = 0; i < 18; i++) {
      if (i >= data.scores.length) break;

      List<DataCell> cells = [
        DataCell(Text('${i + 1}', style: const TextStyle(color: Colors.white70))),
      ];

      for (int pIndex = 0; pIndex < data.memberNames.length; pIndex++) {
        int score = 0;
        if (pIndex < data.scores[i].length) {
          score = data.scores[i][pIndex];
        }
        cells.add(DataCell(Text('$score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
      }
      rows.add(DataRow(cells: cells));
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor: WidgetStateProperty.all(Colors.black12),
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}