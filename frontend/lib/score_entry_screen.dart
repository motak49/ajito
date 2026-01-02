import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'yakuman_entry_screen.dart';

class ScoreEntryScreen extends StatefulWidget {
  final int sessionId;
  final int playerCount;
  final List<String> playerNames;
  final int roundNumber;

  const ScoreEntryScreen({
    super.key,
    required this.sessionId,
    required this.playerCount,
    required this.playerNames,
    required this.roundNumber,
  });

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  
  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.playerCount, (index) => TextEditingController(text: ''));
    _focusNodes = List.generate(widget.playerCount, (index) => FocusNode());
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ▼ 追加: 全角数字・記号を半角に変換してintにするヘルパー関数
  int _parseValue(String text) {
    if (text.isEmpty) return 0;
    // 全角マイナスを半角へ
    String s = text.replaceAll('－', '-');
    // 全角数字を半角へ
    s = s.replaceAllMapped(RegExp(r'[０-９]'), (m) => (m.group(0)!.codeUnitAt(0) - 0xFEE0).toString());
    return int.tryParse(s) ?? 0;
  }

  // ■ 自動計算ロジック
  void _calculateLastPlayerScore(int changedIndex) {
    int lastPlayerIndex = widget.playerCount - 1;
    if (changedIndex == lastPlayerIndex) return;

    int sum = 0;
    bool allOthersFilled = true;

    for (int i = 0; i < lastPlayerIndex; i++) {
      String text = _controllers[i].text;
      if (text.isEmpty || text == '-') {
        allOthersFilled = false;
        break;
      }
      sum += _parseValue(text); // 修正: 変換関数を使用
    }

    if (allOthersFilled) {
      int targetVal = 0 - sum;
      // 値が変わる場合のみ更新
      // ここでの比較も変換してから行うとより安全ですが、表示文字列の一致確認とします
      if (_parseValue(_controllers[lastPlayerIndex].text) != targetVal) {
        _controllers[lastPlayerIndex].text = targetVal.toString();
      }
    }
  }

  void _submit() {
    int sum = 0;
    List<int> resultScores = [];
    bool hasEmpty = false;
    
    for (int i = 0; i < widget.playerCount; i++) {
      String text = _controllers[i].text;
      if (text.isEmpty || text == '-') {
        hasEmpty = true;
      }
      int val = _parseValue(text); // 修正: 変換関数を使用
      sum += val;
      resultScores.add(val);
    }

    if (hasEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未入力の項目があります。0点の場合も0と入力してください。')),
      );
      return;
    }

    if (sum != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('合計が0ではありません（現在: $sum）')),
      );
      return;
    }

    Navigator.pop(context, resultScores);
  }

  @override
  Widget build(BuildContext context) {
    int currentSum = 0;
    for (var c in _controllers) {
      currentSum += _parseValue(c.text); // 修正: 変換関数を使用
    }
    bool isZero = currentSum == 0;

    return Scaffold(
      appBar: AppBar(title: Text('第${widget.roundNumber}回戦 スコア入力')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("最後のプレイヤーは自動計算されます", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView.separated(
                itemCount: widget.playerCount,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playerNames[index],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          // 全角入力を許容して、ロジック側で吸収します
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\－\０-９]')), 
                          ],
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(
                            labelText: 'スコア',
                            hintText: '0',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          onChanged: (_) {
                            setState(() {
                              _calculateLastPlayerScore(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text("合計: ", style: TextStyle(fontSize: 18)),
                  Text(
                    "$currentSum",
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: isZero ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YakumanEntryScreen(
                            sessionId: widget.sessionId,
                            roundNumber: widget.roundNumber,
                            playerNames: widget.playerNames,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      side: const BorderSide(color: Colors.indigo),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('役満登録', style: TextStyle(fontSize: 16)),
                  ),
                ),
                
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('入力完了', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}