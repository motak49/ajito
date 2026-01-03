import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utils/voice_input_helper.dart';
import '../../helpers/database_helper.dart';
// ★追加: 完了画面への遷移用
import 'golf_completion_screen.dart'; 

class GolfScoreInputScreen extends StatefulWidget {
  final String courseName;
  final Map<String, dynamic> settings;
  final List<String> memberNames;
  
  // ★追加: AI解析済みのスコアデータ（任意）
  final List<List<int>>? initialScores;

  const GolfScoreInputScreen({
    super.key,
    required this.courseName,
    required this.settings,
    required this.memberNames,
    this.initialScores, // ★追加
  });

  @override
  State<GolfScoreInputScreen> createState() => _GolfScoreInputScreenState();
}

class _GolfScoreInputScreenState extends State<GolfScoreInputScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VoiceInputHelper _voiceHelper = VoiceInputHelper();

  int _currentHoleIndex = 0;
  // 仮のホールデータ (パー数)
  final List<int> _pars = [4, 4, 3, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 5, 4, 4, 3, 5]; 

  late List<List<int>> _scores;
  late List<Map<String, int>> _myStats;

  // 音声認識状態
  bool _isListening = false;
  bool _isListeningAll = false; // 一括入力モードか
  int _listeningPlayerIndex = -1; 
  String _tempRecognizedText = ""; // 認識中のテキスト一時保存

  // カラー定義
  final Color _bgColor = const Color(0xFF1A1A1A);
  final Color _cardColor = const Color(0xFF2C2C2C);
  final Color _accentGreen = const Color(0xFF4CAF50);
  final Color _accentAmber = const Color(0xFFFFC107);
  final Color _textWhite = Colors.white;
  final Color _textGrey = Colors.white70;

  @override
  void initState() {
    super.initState();
    _initData();
    _initVoice();
  }

  void _initData() {
    // MyStatsの初期化 (パット数など)
    _myStats = List.generate(18, (index) => {'putt': 2, 'ob': 0, 'bunker': 0});
    
    // スコアの初期化
    // ★修正: AI解析データ(initialScores)があればそれをセット、なければParで埋める
    if (widget.initialScores != null && widget.initialScores!.isNotEmpty) {
      _scores = List.generate(18, (holeIdx) {
        return List.generate(widget.memberNames.length, (playerIdx) {
          // データが存在する範囲ならその値、なければPar
          if (playerIdx < widget.initialScores!.length && holeIdx < widget.initialScores![playerIdx].length) {
            final val = widget.initialScores![playerIdx][holeIdx];
            // 0や極端な値が入っている場合はParに戻すなど、必要に応じて調整
            return val > 0 ? val : _pars[holeIdx];
          }
          return _pars[holeIdx];
        });
      });
    } else {
      // 通常の初期化（全てPar）
      _scores = List.generate(
        18, (holeIdx) => List.generate(widget.memberNames.length, (playerIdx) => _pars[holeIdx])
      );
    }
    
    _tabController = TabController(length: 18, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentHoleIndex = _tabController.index);
      }
    });
  }

  Future<void> _initVoice() async {
    await _voiceHelper.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _voiceHelper.stop();
    super.dispose();
  }

  // --- 音声処理 (Push-to-Talk) ---

  // 1. 一括入力: 押した時
  void _startListeningAll() {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _isListeningAll = true;
      _listeningPlayerIndex = -1;
      _tempRecognizedText = "";
    });

    _voiceHelper.listen(
      onResult: (text) {
        setState(() {
          _tempRecognizedText = text;
        });
      },
    );
  }

  // 1. 一括入力: 離した時（停止＆解析）
  void _stopAndFinalizeAll() {
    _voiceHelper.stop();
    
    // 確定ラグを考慮
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _finalizeAllInput();
    });
  }

  void _finalizeAllInput() {
    if (_tempRecognizedText.isEmpty) {
      _resetState();
      return;
    }

    // 解析実行 (Helper側で分解処理が入るため、[5, 5, 3, 2] のようなリストが返ってくる)
    List<int> newScores = _voiceHelper.parseScoreList(_tempRecognizedText, _pars[_currentHoleIndex]);
    
    if (newScores.isNotEmpty) {
      int count = 0;
      // メンバー順にスコアを割り当て
      for (int i = 0; i < widget.memberNames.length; i++) {
        if (i < newScores.length) {
          _updateScore(i, newScores[i], absolute: true);
          count++;
        }
      }
      _showSnackBar('$count人分のスコアを入力: $newScores');
    } else {
      _showSnackBar('数値を認識できませんでした', isError: true);
    }
    _resetState();
  }

  // 2. 個別入力: 押した時
  void _startListeningIndividual(int index) {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _listeningPlayerIndex = index;
      _isListeningAll = false;
      _tempRecognizedText = "";
    });

    _voiceHelper.listen(
      onResult: (text) => setState(() => _tempRecognizedText = text),
    );
  }

  // 2. 個別入力: 離した時
  void _stopAndFinalizeIndividual(int index) {
    _voiceHelper.stop();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _finalizeIndividualInput(index);
    });
  }

  void _finalizeIndividualInput(int index) {
    if (_tempRecognizedText.isEmpty) {
      _resetState();
      return;
    }

    int? newScore = _voiceHelper.parseScore(_tempRecognizedText, _pars[_currentHoleIndex]);
    if (newScore != null) {
      _updateScore(index, newScore, absolute: true);
      _showSnackBar('"$newScore" を入力しました');
    } else {
      _showSnackBar('認識できませんでした', isError: true);
    }
    _resetState();
  }

  void _cancelListening() {
    _voiceHelper.stop();
    _resetState();
  }

  void _resetState() {
    setState(() {
      _isListening = false;
      _isListeningAll = false;
      _listeningPlayerIndex = -1;
      _tempRecognizedText = "";
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _accentGreen,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- スコア更新 ---
  void _updateScore(int playerIndex, int value, {bool absolute = false}) {
    setState(() {
      if (absolute) {
        _scores[_currentHoleIndex][playerIndex] = value < 1 ? 1 : value;
      } else {
        int newVal = _scores[_currentHoleIndex][playerIndex] + value;
        _scores[_currentHoleIndex][playerIndex] = newVal < 1 ? 1 : newVal;
      }
    });
  }

  void _updateMyStat(String key, int delta) {
    setState(() {
      int newVal = _myStats[_currentHoleIndex][key]! + delta;
      if (newVal < 0) newVal = 0;
      _myStats[_currentHoleIndex][key] = newVal;
    });
  }

  // --- DB保存 ---
  Future<void> _saveToLocalDB() async {
    int totalScore = 0;
    // 自分のスコア合計（0番目が自分と仮定）
    for (var s in _scores) {
      totalScore += s[0];
    }

    final Map<String, dynamic> golfDataObj = {
      'member_names': widget.memberNames,
      'scores': _scores,
      'my_stats': _myStats,
      'weather': widget.settings['weather'] ?? 'sunny',
      'wind': widget.settings['wind'] ?? 'medium',
    };

    final Map<String, dynamic> activityData = {
      'user_id': 'user_001',
      'category': 'golf',
      'played_at': (widget.settings['date'] as DateTime).toUtc().toIso8601String(),
      'place_name': widget.courseName,
      'summary_text': 'Round at ${widget.courseName}',
      'primary_score': totalScore,
      'image_urls': [],
      'golf_data': json.encode(golfDataObj),
    };

    try {
      await DatabaseHelper.instance.createActivity(activityData);
      
      // ★修正: 保存成功後は完了画面へ遷移
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GolfCompletionScreen()),
        );
      }
    } catch (e) {
      debugPrint('DB Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- UI構築 ---
  @override
  Widget build(BuildContext context) {
    int currentPar = _pars[_currentHoleIndex];

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            Text(widget.courseName, style: const TextStyle(fontSize: 16, color: Colors.white)),
            Text(
              widget.settings['date'].toString().split(' ')[0],
              style: TextStyle(fontSize: 10, color: _textGrey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveToLocalDB,
            icon: Icon(Icons.save_alt, color: _accentGreen, size: 20),
            label: Text("保存", style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold)),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF222222),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: _accentGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _accentGreen,
              tabs: List.generate(18, (index) => Tab(text: "${index + 1}H")),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ホール情報バー
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: Colors.black38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("HOLE ${_currentHoleIndex + 1}", 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _accentGreen)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("PAR $currentPar", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // プレイヤーリスト
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: widget.memberNames.length,
              itemBuilder: (context, index) {
                return _buildPlayerCard(index, currentPar);
              },
            ),
          ),
        ],
      ),
      
      // 画面下部の一括操作エリア
      bottomSheet: Container(
        color: const Color(0xFF222222),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // PREV
              TextButton(
                onPressed: _currentHoleIndex > 0 
                  ? () => _tabController.animateTo(_currentHoleIndex - 1) 
                  : null,
                child: Text("PREV", style: TextStyle(color: _currentHoleIndex > 0 ? Colors.grey : Colors.black)),
              ),

              // Push-to-Talk 一括入力マイクボタン
              GestureDetector(
                onTapDown: (_) => _startListeningAll(),
                onTapUp: (_) => _stopAndFinalizeAll(),
                onTapCancel: _cancelListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: _isListeningAll ? Colors.redAccent : _accentGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListeningAll ? Colors.redAccent : _accentGreen).withOpacity(0.4),
                        blurRadius: _isListeningAll ? 20 : 15,
                        spreadRadius: _isListeningAll ? 4 : 2,
                      )
                    ],
                  ),
                  child: Icon(
                    _isListeningAll ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),

              // NEXT
              TextButton(
                onPressed: _currentHoleIndex < 17 
                  ? () => _tabController.animateTo(_currentHoleIndex + 1) 
                  : null,
                child: Text("NEXT", style: TextStyle(color: _currentHoleIndex < 17 ? Colors.white : Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(int index, int par) {
    final playerName = widget.memberNames[index];
    final isMe = (index == 0);
    final score = _scores[_currentHoleIndex][index];
    // 個別聞き取り中か判定
    final isListeningMe = _isListening && !_isListeningAll && _listeningPlayerIndex == index;

    Color scoreColor = Colors.white;
    if (score < par) {
      scoreColor = _accentAmber;
    } else if (score > par) scoreColor = Colors.blueAccent;
    
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isListeningMe ? const BorderSide(color: Colors.redAccent, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isMe ? _accentGreen : Colors.grey[700],
                  radius: 18,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(playerName, 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textWhite)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _circleBtn(Icons.remove, () => _updateScore(index, -1)),
                      
                      // 個別 Push-to-Talk
                      GestureDetector(
                        onTapDown: (_) => _startListeningIndividual(index),
                        onTapUp: (_) => _stopAndFinalizeIndividual(index),
                        onTapCancel: _cancelListening,
                        child: Container(
                          width: 60,
                          alignment: Alignment.center,
                          child: isListeningMe
                              ? const Icon(Icons.mic, color: Colors.redAccent, size: 30)
                              : Text("$score", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scoreColor)),
                        ),
                      ),
                      
                      _circleBtn(Icons.add, () => _updateScore(index, 1)),
                    ],
                  ),
                ),
              ],
            ),
            
            // 認識中のテキスト表示
            if (isListeningMe && _tempRecognizedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_tempRecognizedText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),

            if (isMe) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCtrl("PUTT", "putt", Colors.green[300]!),
                  _buildStatCtrl("OB", "ob", Colors.orange[300]!),
                  _buildStatCtrl("Bunker", "bunker", Colors.brown[300]!),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white54, size: 20),
      onPressed: onTap,
      splashRadius: 24,
    );
  }

  Widget _buildStatCtrl(String label, String key, Color color) {
    int val = _myStats[_currentHoleIndex][key]!;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _updateMyStat(key, -1),
                child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.remove, size: 12, color: color)),
              ),
              Text("$val", style: TextStyle(color: _textWhite, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => _updateMyStat(key, 1),
                child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.add, size: 12, color: color)),
              ),
            ],
          ),
        )
      ],
    );
  }
}