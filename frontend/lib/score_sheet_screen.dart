import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db_helper.dart';
import 'score_entry_screen.dart';
import 'yakuman_entry_screen.dart';

class ScoreSheetScreen extends StatefulWidget {
  final int sessionId;
  final int playerCount;
  final List<String> playerNames;
  final String dateStr; 
  final String place;
  final bool hasChip;
  final bool isReadOnly;

  const ScoreSheetScreen({
    super.key,
    required this.sessionId,
    required this.playerCount,
    required this.playerNames,
    required this.dateStr,
    required this.place,
    required this.hasChip,
    this.isReadOnly = false,
  });

  @override
  State<ScoreSheetScreen> createState() => _ScoreSheetScreenState();
}

class _ScoreSheetScreenState extends State<ScoreSheetScreen> {
  List<Map<String, dynamic>> _rounds = [];
  List<int> _totalScores = [];
  List<int> _chipScores = [];
  List<Map<String, dynamic>> _rankingInfo = [];

  String _truncate(String text, int limit) {
    if (text.length <= limit) {
      return text;
    }
    return '${text.substring(0, limit)}…';
  }
  
  int _parseValue(String text) {
    if (text.isEmpty) return 0;
    String s = text.replaceAll('－', '-').replaceAll('−', '-');
    s = s.replaceAllMapped(RegExp(r'[０-９]'), (m) => (m.group(0)!.codeUnitAt(0) - 0xFEE0).toString());
    return int.tryParse(s) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _totalScores = List.filled(widget.playerCount, 0);
    _chipScores = List.filled(widget.playerCount, 0);
    _calculateRanking(); 
    _loadData();
  }

  Future<void> _loadData() async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    
    final List<Map<String, dynamic>> logs = await db.query(
      'local_rounds',
      where: 'session_id = ?',
      orderBy: 'round_number ASC',
      whereArgs: [widget.sessionId],
    );

    final sessionData = await dbHelper.getSession(widget.sessionId);
    List<int> chips = List.filled(widget.playerCount, 0);
    if (sessionData != null) {
      chips[0] = sessionData['chip_p1'] as int? ?? 0;
      chips[1] = sessionData['chip_p2'] as int? ?? 0;
      chips[2] = sessionData['chip_p3'] as int? ?? 0;
      if (widget.playerCount == 4) {
        chips[3] = sessionData['chip_p4'] as int? ?? 0;
      }
    }

    List<int> totals = List.filled(widget.playerCount, 0);
    for (var log in logs) {
      totals[0] += log['score_p1'] as int;
      totals[1] += log['score_p2'] as int;
      totals[2] += log['score_p3'] as int;
      if (widget.playerCount == 4) {
        totals[3] += log['score_p4'] as int;
      }
    }
    
    for (int i = 0; i < widget.playerCount; i++) {
      totals[i] += chips[i];
    }

    setState(() {
      _rounds = logs;
      _chipScores = chips;
      _totalScores = totals;
      _calculateRanking();
    });
  }

  void _calculateRanking() {
    List<Map<String, dynamic>> temp = [];
    for (int i = 0; i < widget.playerCount; i++) {
      temp.add({
        'index': i,
        'score': _totalScores[i],
        'rank': 0,
        'diff': 0,
        'isTop': false,
      });
    }
    temp.sort((a, b) => b['score'].compareTo(a['score']));

    for (int i = 0; i < temp.length; i++) {
      temp[i]['rank'] = i + 1;
      if (i == 0) {
        temp[i]['isTop'] = true;
      } else {
        temp[i]['diff'] = temp[i-1]['score'] - temp[i]['score'];
      }
    }

    _rankingInfo = List.generate(widget.playerCount, (idx) {
      return temp.firstWhere((e) => e['index'] == idx);
    });
  }

  Future<void> _goToEntry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScoreEntryScreen(
          sessionId: widget.sessionId,
          playerCount: widget.playerCount,
          playerNames: widget.playerNames,
          roundNumber: _rounds.length + 1,
        ),
      ),
    );

    if (result != null && result is List<int>) {
      _registerRound(result);
    }
  }

  Future<void> _registerRound(List<int> scores) async {
    final dbHelper = DatabaseHelper();
    Map<String, dynamic> row = {
      'session_id': widget.sessionId,
      'round_number': _rounds.length + 1,
      'score_p1': scores[0],
      'score_p2': scores[1],
      'score_p3': scores[2],
      'score_p4': widget.playerCount == 4 ? scores[3] : 0,
    };
    
    await dbHelper.insertRound(row);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("記録しました")));
    _loadData(); 
  }

  Future<void> _showChipInputModal() async {
    List<TextEditingController> controllers = List.generate(
      widget.playerCount, 
      (i) {
        int val = _chipScores[i];
        return TextEditingController(text: val == 0 ? '' : val.toString());
      }
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void calculateChipLastPlayer(int changedIndex) {
              int lastIdx = widget.playerCount - 1;
              if (changedIndex == lastIdx) return;

              int sum = 0;
              bool allOthersFilled = true;
              
              for (int i = 0; i < lastIdx; i++) {
                String text = controllers[i].text;
                if (text.isEmpty || text == '-') {
                  allOthersFilled = false;
                  break;
                }
                sum += _parseValue(text); 
              }

              if (allOthersFilled) {
                int target = 0 - sum;
                if (_parseValue(controllers[lastIdx].text) != target) {
                  controllers[lastIdx].text = target.toString();
                }
              }
            }

            return AlertDialog(
              title: const Text("最終チップ結果入力"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.playerCount, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2, 
                            child: Text(widget.playerNames[index], style: const TextStyle(fontWeight: FontWeight.bold))
                          ),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: controllers[index],
                              keyboardType: const TextInputType.numberWithOptions(signed: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\－\−\０-９]'))],
                              textAlign: TextAlign.end,
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                              ),
                              onChanged: (_) {
                                calculateChipLastPlayer(index);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("キャンセル"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    List<int> newChips = [];
                    int sum = 0;
                    for (var c in controllers) {
                      int val = _parseValue(c.text);
                      newChips.add(val);
                      sum += val;
                    }

                    if (sum != 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('チップ合計が0ではありません: $sum')),
                      );
                      return; 
                    }

                    await DatabaseHelper().updateSessionChips(widget.sessionId, newChips);
                    if (mounted) Navigator.pop(context);
                    _loadData(); 
                  },
                  child: const Text("入力完了"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showFinishConfirmation() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("終了しますか？"),
        content: const Text("対局を終了してホームに戻ります。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("いいえ"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text("はい"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("削除しますか？"),
        content: const Text("この対局データを削除します。\n削除すると元に戻せません。\n紐づく役満データも削除されます。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("いいえ"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await DatabaseHelper().deleteSession(widget.sessionId);
              if (mounted) {
                Navigator.pop(context); 
                Navigator.pop(context); 
              }
            },
            child: const Text("はい"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double firstColWidth = 30.0;
    const double columnSpacing = 10.0;
    const double horizontalMargin = 10.0;
    final double playerColWidth = (screenWidth - firstColWidth - (horizontalMargin * 2) - (columnSpacing * widget.playerCount)) / widget.playerCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('対局状況'),
        actions: [
          if (!widget.isReadOnly)
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => YakumanEntryScreen(
                  sessionId: widget.sessionId,
                  roundNumber: _rounds.length + 1,
                  playerNames: widget.playerNames
                )));
                _loadData();
              }, 
              child: const Text("役満登録", style: TextStyle(color: Colors.white))
            )
        ],
      ),
      body: Stack(
        children: [
          // 1. 背景画像 (lib/img/jantaku_bg.png を指定)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/img/jantaku_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. コンテンツ
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                color: Colors.white.withOpacity(0.9), // 半透明
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("● プレー日 : ${widget.dateStr}", style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text("● 場所 : ${_truncate(widget.place, 20)}", style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              Expanded(
                child: Container(
                  color: Colors.white.withOpacity(0.85), // テーブル部分も見やすく半透明
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: columnSpacing,
                            horizontalMargin: horizontalMargin,
                            columns: [
                              const DataColumn(label: Text('')),
                              ...widget.playerNames.map((n) => DataColumn(
                                label: SizedBox(
                                  width: playerColWidth,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Text(n, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              )),
                            ],
                            rows: [
                              // ▼ 変更箇所: ラウンドごとのスコア (マイナスは赤字)
                              ..._rounds.map((r) => DataRow(cells: [
                                DataCell(Text("${r['round_number']}")),
                                ...List.generate(widget.playerCount, (i) {
                                  int score = r['score_p${i+1}'] as int;
                                  return DataCell(
                                    SizedBox(
                                      width: playerColWidth,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          "$score",
                                          style: TextStyle(
                                            color: score < 0 ? Colors.red : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                              ])),

                              // ▼ 変更箇所: チップ (マイナスは赤字)
                              if (widget.hasChip)
                                DataRow(
                                  cells: [
                                    const DataCell(Text("チップ", style: TextStyle(fontSize: 12))),
                                    ..._chipScores.map((s) => DataCell(
                                      SizedBox(
                                        width: playerColWidth,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            "$s",
                                            style: TextStyle(
                                              color: s < 0 ? Colors.red : const Color.fromARGB(255, 61, 57, 57),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ))
                                  ]
                                ),
                              
                              // 合計行
                              DataRow(
                                color: WidgetStateProperty.all(Colors.indigo.shade50.withOpacity(0.5)),
                                cells: [
                                  const DataCell(Text("合計")),
                                  ..._totalScores.map((s) => DataCell(
                                    SizedBox(
                                      width: playerColWidth,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          "$s",
                                          style: TextStyle(
                                            color: s >= 0 ? Colors.black : Colors.red,
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                    ),
                                  ))
                                ]
                              ),
                              DataRow(cells: [
                                const DataCell(Text("順位")), 
                                ..._rankingInfo.map((i) => DataCell(
                                  SizedBox(
                                    width: playerColWidth,
                                    child: Center(
                                      child: i['isTop'] 
                                        ? const Icon(Icons.star, color: Colors.orange, size: 18) 
                                        : Text("${i['rank']}"),
                                    ),
                                  ),
                                ))
                              ]),
                              DataRow(cells: [
                                const DataCell(Text("差")), 
                                ..._rankingInfo.map((i) => DataCell(
                                  SizedBox(
                                    width: playerColWidth,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: i['isTop'] 
                                        ? const Text("-") 
                                        : Text("▲${i['diff']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ),
                                  ),
                                ))
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              Container(
                color: Colors.white.withOpacity(0.9),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (!widget.isReadOnly) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: _goToEntry,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.indigo),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text('スコア登録', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (widget.hasChip) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: OutlinedButton(
                            onPressed: _showChipInputModal,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.indigo),
                              backgroundColor: Colors.white,
                            ),
                            child: const Text('(最終) チップ入力', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton(
                          onPressed: _showFinishConfirmation,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black54),
                            backgroundColor: Colors.white,
                          ),
                          child: const Text('闘牌終了', style: TextStyle(color: Colors.black87)),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: _confirmDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent, 
                            foregroundColor: Colors.white
                          ),
                          child: const Text('この対局を削除する', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}