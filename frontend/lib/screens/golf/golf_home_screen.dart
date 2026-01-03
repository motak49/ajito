import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../helpers/database_helper.dart';
import '../../services/gemini_service.dart';

// 画面遷移先
import 'search/golf_search_menu.dart'; 
import 'golf_detail_screen.dart';
// import 'score_input_screen.dart'; // ← 削除またはコメントアウト
import 'golf_score_confirm_screen.dart'; // ★追加: 新しい確認画面

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
  final int _bestScore = 0; 
  final double _avgScore = 0.0;
  final int _rounds = 0;

  @override
  void initState() {
    super.initState();
    _fetchGolfData();
  }

  Future<void> _fetchGolfData() async {
    try {
      final List<Map<String, dynamic>> data = 
          await DatabaseHelper.instance.getActivities('golf');
      
      final items = data.map((e) {
        final Map<String, dynamic> mutableMap = Map.from(e);
        if (mutableMap['golf_data'] is String) {
           mutableMap['golf_data'] = jsonDecode(mutableMap['golf_data']);
        }
        return GolfActivity.fromJson(mutableMap);
      }).toList();

      if (mounted) {
        setState(() {
          _logs = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★ 画像選択〜解析〜遷移の処理
  // _processImageRegistration メソッドの修正
  Future<void> _processImageRegistration() async {
    // 1. ソース選択ダイアログ (ここが source の定義です)
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("画像の選択"),
        content: const Text("どちらから画像を読み込みますか？"),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text("ギャラリー"),
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("カメラ"),
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source == null) return; // キャンセルされた場合

    // 2. 画像ピッカーの初期化 (ここが picker の定義です)
    final picker = ImagePicker();
    
    // 3. 画像取得実行
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    // 4. ローディング表示
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final File imageFile = File(image.path); // 画像ファイルオブジェクト作成
      
      // 5. Gemini解析
      final result = await GeminiService().analyzeScoreCard(imageFile);
      
      // ローディング消去
      if (mounted) Navigator.pop(context);

      if (result != null) {
        final String placeName = result['place_name'] ?? 'Unknown Course';
        final DateTime date = DateTime.tryParse(result['play_date'] ?? '') ?? DateTime.now();
        
        // Par情報の取得
        List<int> parsedPars = [];
        if (result['pars'] != null) {
           parsedPars = List<int>.from(result['pars']);
        }
        if (parsedPars.length != 18) {
          parsedPars = [4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 5, 4, 4, 3, 5];
        }

        // スコア情報の取得（文字列のまま）
        List<String> rawScores = [];
        if (result['scores'] != null && (result['scores'] as List).isNotEmpty) {
          List<dynamic> src = result['scores'][0];
          for (int i = 0; i < 18; i++) {
            if (i < src.length) {
              rawScores.add(src[i].toString()); // 文字列のまま
            } else {
              rawScores.add("-"); // データなし
            }
          }
        } else {
          rawScores = List.filled(18, "-");
        }

        // パット数の取得
        List<int> rawPutts = [];
        if (result['putts'] != null && (result['putts'] as List).isNotEmpty) {
          List<dynamic> src = result['putts'][0];
          for (int i = 0; i < 18; i++) {
             if (i < src.length && src[i] is int) {
               rawPutts.add(src[i]);
             } else {
               rawPutts.add(0);
             }
          }
        } else {
          rawPutts = List.filled(18, 0);
        }

        // 6. 結果確認画面へ遷移
        if (mounted) {
          final bool? isSaved = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GolfScoreConfirmScreen(
                courseName: placeName,
                date: date,
                rawScores: rawScores, // 文字列リスト
                pars: parsedPars,
                putts: rawPutts,
                sourceImage: imageFile, // 元画像
              ),
            ),
          );
          
          if (isSaved == true) {
            _fetchGolfData();
          }
        }
      } else {
        _showError("解析できませんでした。手入力してください。");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // エラー時もローディングを消す
      _showError("エラーが発生しました: $e");
    }
  }

  // 記号解析ヘルパーメソッド
  int _parseScoreSymbol(dynamic input, int par) {
    if (input is int) return input;
    if (input is! String) return par; // 不明ならPar

    String s = input.trim();
    
    // 1. そのまま数字の場合
    if (int.tryParse(s) != null) {
      return int.parse(s);
    }

    // 2. 記号の場合
    switch (s) {
      case '◎': 
      case 'Double Circle':
        return par - 2; // イーグル
      case '○':
      case 'O':
      case 'Circle':
        return par - 1; // バーディ
      case '-':
      case '－':
      case 'Par':
        return par;     // パー
      case '△':
      case 'Triangle':
        return par + 1; // ボギー
      case '□':
      case 'Square':
        return par + 2; // ダブルボギー
      case '■':
        return par + 3; // トリプルボギー
    }

    // 3. "+3" のような相対表記の場合
    if (s.startsWith('+')) {
      int? diff = int.tryParse(s.substring(1));
      if (diff != null) return par + diff;
    }

    // マッチしなければParを返す（または0）
    return par;
  }
  
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF1A1A1A), 
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => GolfSearchMenuScreen()),
                          ).then((_) => _fetchGolfData());
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

                    // 画像から登録ボタン
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: ElevatedButton.icon(
                        onPressed: _processImageRegistration,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("画像から登録 (BETA)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white30),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
             builder: (context) => GolfDetailScreen(activityId: log.id),
            ),
          );
        },
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