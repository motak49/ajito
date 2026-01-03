import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'score_sheet_screen.dart';

class HistoryScreen extends StatefulWidget {
  final int year; 

  const HistoryScreen({super.key, required this.year});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessionSummaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    final summaries = await db.getSessionSummaries(widget.year);

    if (mounted) {
      setState(() {
        _sessionSummaries = summaries;
        _isLoading = false;
      });
    }
  }

  Future<void> _showYakumanModal(int sessionId) async {
    final db = DatabaseHelper();
    final yakumans = await db.getYakumans(sessionId);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("達成された役満"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: yakumans.map((y) {
                final name = y['yakuman_name'] ?? '';
                final imagePath = y['image_path'] ?? '';
                return Column(
                  children: [
                    Text("★ $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                    const SizedBox(height: 8),
                    if (imagePath.isNotEmpty)
                      Image.file(File(imagePath), height: 150, fit: BoxFit.cover)
                    else
                      const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    const Divider(),
                  ],
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("閉じる"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.year}年の対局履歴"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _sessionSummaries.isEmpty
                  ? Center(child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white.withOpacity(0.76),
                      child: const Text("履歴がありません"),
                    ))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessionSummaries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _sessionSummaries[index];
                        final date = DateTime.parse(item['played_at']);
                        final scores = item['score_totals'] as List<int>;
                        final chips = item['chip_totals'] as List<int>;
                        final hasChip = (item['has_chip'] as int? ?? 0) == 1;
                        final hasYakuman = (item['has_yakuman'] == true);

                        int myResult = scores[0] + (hasChip ? chips[0] : 0);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9), // リストアイテムを見やすく
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${DateFormat('yyyy/MM/dd (E)', 'ja_JP').format(date)}  ${item['place_name']}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasYakuman)
                                  InkWell(
                                    onTap: () => _showYakumanModal(item['id']),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.orange),
                                      ),
                                      child: const Text(
                                        "役満",
                                        style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  "結果: $myResult",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: myResult < 0 ? Colors.red : Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                                if (hasChip)
                                  Text(" (内チップ: ${chips[0]})", style: const TextStyle(fontSize: 12, color: Color.fromARGB(255, 56, 54, 54))),
                                const SizedBox(height: 4),
                                Text(
                                  "対戦: ${item['player2_name']} ${item['player3_name']} ${item['player_count'] == 4 ? item['player4_name'] : ''}",
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScoreSheetScreen(
                                    sessionId: item['id'],
                                    playerCount: item['player_count'],
                                    playerNames: [
                                      item['player1_name'],
                                      item['player2_name'],
                                      item['player3_name'],
                                      if (item['player_count'] == 4) item['player4_name']
                                    ].whereType<String>().toList(),
                                    dateStr: DateFormat('yyyy/MM/dd').format(date),
                                    place: item['place_name'],
                                    hasChip: hasChip,
                                    isReadOnly: true,
                                  ),
                                ),
                              );
                              _loadData();
                            },
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}