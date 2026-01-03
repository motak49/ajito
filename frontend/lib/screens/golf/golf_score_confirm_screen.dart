import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../helpers/database_helper.dart';

class GolfScoreConfirmScreen extends StatefulWidget {
  final String courseName;
  final DateTime date;
  final List<String> rawScores; // 文字列のまま（例: "□", "+3"）
  final List<int> pars;         // Par情報
  final List<int> putts;        // パット数
  final File sourceImage;       // 元画像

  const GolfScoreConfirmScreen({
    super.key,
    required this.courseName,
    required this.date,
    required this.rawScores,
    required this.pars,
    required this.putts,
    required this.sourceImage,
  });

  @override
  State<GolfScoreConfirmScreen> createState() => _GolfScoreConfirmScreenState();
}

class _GolfScoreConfirmScreenState extends State<GolfScoreConfirmScreen> {
  bool _isSaving = false;
  
  // 編集用データ
  late List<String> _currentScores;
  late List<int> _currentPars; // Parも修正できるようにする
  late List<int> _currentPutts;

  @override
  void initState() {
    super.initState();
    _currentScores = List.from(widget.rawScores);
    _currentPars = List.from(widget.pars);
    _currentPutts = List.from(widget.putts);
  }

  // --- 修正ダイアログ ---
  void _showEditDialog(int holeIndex) {
    int holeNum = holeIndex + 1;
    
    TextEditingController scoreCtrl = TextEditingController(text: _currentScores[holeIndex]);
    TextEditingController parCtrl = TextEditingController(text: _currentPars[holeIndex].toString());
    TextEditingController puttCtrl = TextEditingController(text: _currentPutts[holeIndex].toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: Text("HOLE $holeNum の修正", style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Par修正
                TextField(
                  controller: parCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "PAR (規定打数)",
                    labelStyle: TextStyle(color: Colors.greenAccent),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 16),
                // スコア修正
                TextField(
                  controller: scoreCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "スコア (記号可: △, □, +3)",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ["◎", "○", "-", "△", "□", "+3"].map((symbol) {
                    return ChoiceChip(
                      label: Text(symbol),
                      selected: false,
                      onSelected: (_) => scoreCtrl.text = symbol,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // パット修正
                TextField(
                  controller: puttCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "パット数",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("キャンセル", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentScores[holeIndex] = scoreCtrl.text;
                  _currentPars[holeIndex] = int.tryParse(parCtrl.text) ?? 4;
                  _currentPutts[holeIndex] = int.tryParse(puttCtrl.text) ?? 0;
                });
                Navigator.pop(ctx);
              },
              child: const Text("決定", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- 文字列スコア → 数値変換ロジック ---
  int _parseScoreString(String input, int par) {
    String s = input.trim();
    // 数字ならそのまま
    if (int.tryParse(s) != null) return int.parse(s);

    // 記号計算
    switch (s) {
      case '◎': case 'Double Circle': return par - 2;
      case '○': case 'O': case 'Circle': return par - 1;
      case '-': case '－': case 'Par': return par;
      case '△': case 'Triangle': return par + 1;
      case '□': case 'Square': return par + 2;
      case '■': return par + 3;
    }
    // "+3" などの相対表記
    if (s.startsWith('+')) {
      int? diff = int.tryParse(s.substring(1));
      if (diff != null) return par + diff;
    }
    // どれでもなければPar扱い
    return par; 
  }

  // --- 保存処理 ---
  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      // 最終計算
      List<int> finalScores = [];
      for (int i = 0; i < 18; i++) {
        finalScores.add(_parseScoreString(_currentScores[i], _currentPars[i]));
      }
      int totalScore = finalScores.reduce((a, b) => a + b);

      List<Map<String, int>> myStats = List.generate(18, (i) {
        return {'putt': _currentPutts[i], 'ob': 0, 'bunker': 0};
      });

      final Map<String, dynamic> golfDataObj = {
        'member_names': ['Me'], 
        'scores': [finalScores], // 数値化済み
        'my_stats': myStats,
        'weather': 'sunny',
        'wind': 'medium',
        'pars': _currentPars, // Par情報も保存しておくと良いでしょう（DB構造による）
      };

      final Map<String, dynamic> activityData = {
        'category': 'golf',
        'played_at': widget.date.toUtc().toIso8601String(),
        'place_name': widget.courseName,
        'summary_text': 'Round at ${widget.courseName}',
        'primary_score': totalScore,
        'image_urls': jsonEncode([]), 
        'golf_data': json.encode(golfDataObj),
      };

      await DatabaseHelper.instance.createActivity(activityData);

      if (!mounted) return;
      _showCompletionDialog();

    } catch (e) {
      debugPrint("Save Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
              SizedBox(height: 16),
              Text("登録完了", style: TextStyle(color: Colors.white, fontSize: 20)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); 
                Navigator.of(context).pop(true);
              },
              child: const Text("ホームへ戻る", style: TextStyle(color: Colors.greenAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // リアルタイム集計
    int outTotal = 0, inTotal = 0;
    int outParTotal = 0, inParTotal = 0;
    int outPuttTotal = 0, inPuttTotal = 0;
    bool hasPutts = _currentPutts.any((p) => p > 0);

    for (int i = 0; i < 18; i++) {
      int par = _currentPars[i];
      int val = _parseScoreString(_currentScores[i], par); // リアルタイム変換
      int putt = _currentPutts[i];

      if (i < 9) {
        outTotal += val; outParTotal += par; outPuttTotal += putt;
      } else {
        inTotal += val; inParTotal += par; inPuttTotal += putt;
      }
    }
    int total = outTotal + inTotal;
    int parTotal = outParTotal + inParTotal;
    int totalPutts = outPuttTotal + inPuttTotal;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text("内容確認・修正", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 基本情報
            _buildInfoCard(total, parTotal, hasPutts ? totalPutts : null),
            const SizedBox(height: 24),
            
            // OUT
            const Text("OUT (1-9)", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScoreTable(startHole: 1, endHole: 9, total: outTotal, parTotal: outParTotal, puttTotal: hasPutts ? outPuttTotal : null),

            const SizedBox(height: 24),

            // IN
            const Text("IN (10-18)", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScoreTable(startHole: 10, endHole: 18, total: inTotal, parTotal: inParTotal, puttTotal: hasPutts ? inPuttTotal : null),

            const SizedBox(height: 30),
            
            // ★元画像の表示
            const Text("読み取り元画像", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black45,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.file(widget.sourceImage, fit: BoxFit.contain),
                ),
              ),
            ),
            const Center(child: Text("※ピンチ操作で拡大して確認できます", style: TextStyle(color: Colors.white30, fontSize: 10))),

            const SizedBox(height: 30),

            // 登録ボタン
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.black87)
                  : const Text("この内容で登録する", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(int total, int parTotal, int? puttTotal) {
    int diff = total - parTotal;
    String diffStr = diff > 0 ? "+$diff" : (diff == 0 ? "E" : "$diff");
    Color diffColor = diff > 0 ? Colors.white : (diff < 0 ? Colors.redAccent : Colors.white);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(widget.courseName, 
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(DateFormat('yyyy/MM/dd (E)', 'ja').format(widget.date), style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$total", style: const TextStyle(color: Colors.greenAccent, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text("($diffStr)", style: TextStyle(color: diffColor, fontSize: 20, fontWeight: FontWeight.bold)),
              if (puttTotal != null) ...[
                 const SizedBox(width: 16),
                 Text("($puttTotal putts)", style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ]
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreTable({required int startHole, required int endHole, required int total, required int parTotal, int? puttTotal}) {
    List<TableRow> rows = [];
    
    // Header
    rows.add(TableRow(children: [
      _buildCell("HOLE", isHeader: true),
      for (int i = startHole; i <= endHole; i++) _buildCell("$i", isHeader: true),
      _buildCell("TTL", isHeader: true),
    ]));

    // Par
    rows.add(TableRow(children: [
      _buildCell("PAR", color: Colors.white54),
      for (int i = startHole - 1; i < endHole; i++) 
        _buildCell("${_currentPars[i]}", color: Colors.white54), // 現在のParを表示
      _buildCell("$parTotal", color: Colors.white54, isBold: true),
    ]));

    // Score (タップ可能)
    rows.add(TableRow(children: [
      _buildCell("SCORE", isBold: true),
      for (int i = startHole - 1; i < endHole; i++) 
        _buildEditableScoreCell(i),
      
      // 合計セル
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$total", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            if (puttTotal != null)
              Text("($puttTotal)", style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
      )
    ]));

    return Table(
      border: TableBorder.all(color: Colors.white12),
      columnWidths: const {
        0: FixedColumnWidth(60),
        10: FixedColumnWidth(50),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isBold = false, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      color: isHeader ? Colors.white10 : null,
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? (isHeader ? Colors.white70 : Colors.white),
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 14,
        ),
      ),
    );
  }

  Widget _buildEditableScoreCell(int holeIndex) {
    int par = _currentPars[holeIndex]; // 最新のParを使う
    String rawScore = _currentScores[holeIndex];
    int scoreVal = _parseScoreString(rawScore, par);
    int diff = scoreVal - par;
    int putt = _currentPutts[holeIndex];

    Color? bgColor;
    Color textColor = Colors.white;

    if (diff <= -2) { bgColor = Colors.amber; textColor = Colors.black; }
    else if (diff == -1) bgColor = Colors.blueAccent;
    else if (diff == 0) bgColor = null;
    else if (diff == 1) bgColor = Colors.redAccent.withOpacity(0.2);
    else bgColor = Colors.redAccent.withOpacity(0.5);

    return InkWell(
      onTap: () => _showEditDialog(holeIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: BoxDecoration(color: bgColor),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(rawScore, 
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            if (putt > 0)
               Text("($putt)", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}