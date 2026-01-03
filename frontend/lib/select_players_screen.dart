import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'score_sheet_screen.dart';

class SelectPlayersScreen extends StatefulWidget {
  final DateTime date;
  final String place;
  final int playerCount;
  final bool hasChip;

  const SelectPlayersScreen({
    super.key,
    required this.date,
    required this.place,
    required this.playerCount,
    required this.hasChip,
  });

  @override
  State<SelectPlayersScreen> createState() => _SelectPlayersScreenState();
}

class _SelectPlayersScreenState extends State<SelectPlayersScreen> {
  late List<TextEditingController> _controllers;
  final _formKey = GlobalKey<FormState>();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.playerCount, (index) {
      return TextEditingController(text: index == 0 ? '自分' : '');
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _startSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final newSession = {
        'played_at': widget.date.toIso8601String(),
        'place_name': widget.place,
        'player_count': widget.playerCount,
        'player1_name': _controllers[0].text,
        'player2_name': _controllers[1].text,
        'player3_name': _controllers[2].text,
        'player4_name': widget.playerCount == 4 ? _controllers[3].text : null,
        'has_chip': widget.hasChip ? 1 : 0,
        'is_synced': 0,
      };

      final dbHelper = DatabaseHelper();
      final sessionId = await dbHelper.insertSession(newSession);

      if (!mounted) return;

      List<String> names = [
        _controllers[0].text,
        _controllers[1].text,
        _controllers[2].text,
      ];
      if (widget.playerCount == 4) {
        names.add(_controllers[3].text);
      }

      String dateStr = DateFormat('yyyy/MM/dd').format(widget.date);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ScoreSheetScreen(
            sessionId: sessionId,
            playerCount: widget.playerCount,
            playerNames: names,
            dateStr: dateStr,
            place: widget.place,
            hasChip: widget.hasChip,
          ),
        ),
        (route) => route.isFirst,
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレイヤー選択 (Step 2/3)')),
      body: Stack(
        children: [
          // 背景画像
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/img/jantaku_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // コンテンツ
          Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.76),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      "参加メンバーの名前を入力してください",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: ListView.separated(
                        itemCount: widget.playerCount,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return TextFormField(
                            controller: _controllers[index],
                            maxLength: 10,
                            decoration: InputDecoration(
                              labelText: 'プレイヤー ${index + 1}',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person),
                              counterText: "",
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '名前を入力してください';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _startSession,
                        icon: _isProcessing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Icon(Icons.play_arrow),
                        label: Text(_isProcessing ? '処理中...' : '対局開始（シートへ）', style: const TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}