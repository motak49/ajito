import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'select_players_screen.dart';

class SetupSessionScreen extends StatefulWidget {
  const SetupSessionScreen({super.key});

  @override
  State<SetupSessionScreen> createState() => _SetupSessionScreenState();
}

class _SetupSessionScreenState extends State<SetupSessionScreen> {
  final TextEditingController _placeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int _playerCount = 4;
  bool _hasChip = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ja_JP');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ja'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onNextPressed() {
    if (_placeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('場所を入力してください')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectPlayersScreen(
          date: _selectedDate,
          place: _placeController.text,
          playerCount: _playerCount,
          hasChip: _hasChip,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy/MM/dd (E)', 'ja_JP').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('対局の設定 (Step 1/3)')),
      body: Stack(
        children: [
          // 1. 背景画像
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/img/jantaku_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // 2. コンテンツ (視認性のため半透明カードに乗せる)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.76), // 半透明の白
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 中身のサイズに合わせる
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("対局日", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 10),
                          Text(formattedDate, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("場所", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _placeController,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      hintText: '例: 雀荘Z, 自宅',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                      counterText: "",
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("人数", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<int>(
                          title: const Text('4人打ち'),
                          value: 4,
                          groupValue: _playerCount,
                          onChanged: (val) => setState(() => _playerCount = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<int>(
                          title: const Text('3人打ち'),
                          value: 3,
                          groupValue: _playerCount,
                          onChanged: (val) => setState(() => _playerCount = val!),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('チップあり'),
                    value: _hasChip,
                    onChanged: (bool value) {
                      setState(() {
                        _hasChip = value;
                      });
                    },
                  ),
                  
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('次へ（プレイヤー選択）', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}