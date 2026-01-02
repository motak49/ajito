import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'db_helper.dart';
import 'setup_session_screen.dart';
import 'history_screen.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentYearTotal = 0;
  List<ChartData> _chartDataList = [];
  final int _targetYear = DateTime.now().year;

  // アニメーション用コントローラー
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    List<Map<String, dynamic>> summaries = await db.getSessionSummaries(_targetYear);
    
    // 日付昇順（計算用）
    summaries.sort((a, b) => a['played_at'].compareTo(b['played_at']));

    int runningTotal = 0;
    List<ChartData> tempChartData = [];

    for (var s in summaries) {
      List<int> scores = s['score_totals'];
      List<int> chips = s['chip_totals'];
      
      int roundScore = scores.isNotEmpty ? scores[0] : 0;
      int chipScore = chips.isNotEmpty ? chips[0] : 0;
      int myTotalScore = roundScore + chipScore;
      
      runningTotal += myTotalScore;
      
      tempChartData.add(ChartData(
        date: DateTime.parse(s['played_at']),
        score: myTotalScore,
        cumulative: runningTotal,
      ));
    }

    // グラフ用データ：最後の5件を取得
    List<ChartData> recent5 = tempChartData.length > 5 
        ? tempChartData.sublist(tempChartData.length - 5) 
        : tempChartData;

    if (mounted) {
      setState(() {
        _currentYearTotal = runningTotal;
        _chartDataList = recent5;
      });
      _animationController.forward(from: 0);
    }
  }

  void _goToHistoryScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(year: _targetYear),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. 背景画像 (固定) - ここはスクロールの影響を受けません
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/img/top_bg.png'),
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          
          // 2. コンテンツ (スクロール可能にする)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 画面の高さが足りない場合にスクロールできるようにする仕組み
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 120),
                          
                          // グラフエリア
                          GestureDetector(
                            onTap: () => _goToHistoryScreen(context),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              height: 240, 
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.76),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                   const Padding(
                                    padding: EdgeInsets.only(top: 15, bottom: 5),
                                    child: Text(
                                      "直近5試合の推移", 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.black87,
                                        fontSize: 16
                                      )
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                                      child: AnimatedBuilder(
                                        animation: _animation,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: ScoreChartPainter(_chartDataList, _animation.value),
                                            child: Container(),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("> タップして履歴一覧へ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                const Text("今年の結果", style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 5, color: Colors.black)])),
                                Text(
                                  "${_currentYearTotal > 0 ? '+' : ''}$_currentYearTotal",
                                  style: TextStyle(
                                    fontSize: 48, 
                                    fontWeight: FontWeight.bold, 
                                    color: _currentYearTotal < 0 ? const Color(0xFFFF8A80) : Colors.white,
                                    shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Spacerの代わりに Expanded で空き領域を埋める
                          const Expanded(child: SizedBox()),

                          // 闘牌開始ボタン
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupSessionScreen()));
                                _loadData(); 
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.indigo.shade900,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                elevation: 8,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Text("闘牌開始", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 以下、ChartData と ScoreChartPainter は変更なし
class ChartData {
  final DateTime date;
  final int score;
  final int cumulative;
  ChartData({required this.date, required this.score, required this.cumulative});
}

class ScoreChartPainter extends CustomPainter {
  final List<ChartData> data;
  final double animationValue;

  ScoreChartPainter(this.data, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintBar = Paint()..style = PaintingStyle.fill;
    
    final colorPositive = const Color(0xFF64B5F6);
    final colorNegative = const Color(0xFFFF8A65);

    final paintLine = Paint()
      ..color = const Color(0xFF009688)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final paintDotBorder = Paint()
      ..color = const Color(0xFF009688)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    int minVal = 0;
    int maxVal = 0;
    for (var d in data) {
      minVal = math.min(minVal, math.min(d.score, d.cumulative));
      maxVal = math.max(maxVal, math.max(d.score, d.cumulative));
    }
    
    int range = maxVal - minVal;
    if (range == 0) range = 100;
    double paddingY = range * 0.25; 
    double graphMax = maxVal + paddingY;
    double graphMin = minVal - paddingY;
    double graphRange = graphMax - graphMin;

    double getY(int value) {
      return size.height - ((value - graphMin) / graphRange * size.height);
    }

    double zeroY = getY(0);
    double barWidth = 16.0;
    double interval = size.width / (data.length);

    for (int i = 0; i < data.length; i++) {
      ChartData item = data[i];
      double centerX = (interval * i) + (interval / 2);

      double targetY = getY(item.score);
      double animatedY = zeroY + (targetY - zeroY) * animationValue;

      double barTop = animatedY;
      double barBottom = zeroY;

      if (item.score < 0) {
        double temp = barTop;
        barTop = barBottom;
        barBottom = temp;
        paintBar.color = colorNegative;
      } else {
        paintBar.color = colorPositive;
      }

      RRect barRRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(centerX - barWidth / 2, barTop, centerX + barWidth / 2, barBottom),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRRect, paintBar);

      if (animationValue > 0.5) {
        String label = (item.score > 0 ? "+" : "") + item.score.toString();
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: item.score < 0 ? colorNegative : Colors.black54,
            fontSize: 10, 
            fontWeight: FontWeight.bold
          ),
        );
        textPainter.layout();
        
        double textY = (item.score >= 0) ? animatedY - 15 : animatedY + 5;
        textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, textY));
      }

      String dateLabel = DateFormat('M/d').format(item.date);
      textPainter.text = TextSpan(
        text: dateLabel,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, size.height + 4));
    }

    Paint line0 = Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), line0);

    Path linePath = Path();
    List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      double centerX = (interval * i) + (interval / 2);
      double targetY = getY(data[i].cumulative);
      double currentY = zeroY + (targetY - zeroY) * animationValue;
      
      points.add(Offset(centerX, currentY));
      
      if (i == 0) {
        linePath.moveTo(centerX, currentY);
      } else {
        linePath.lineTo(centerX, currentY);
      }
    }

    canvas.drawPath(linePath, paintLine);

    for (var point in points) {
      canvas.drawCircle(point, 4.0, paintDot);
      canvas.drawCircle(point, 4.0, paintDotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant ScoreChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}