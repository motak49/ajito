import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/golf/score_input_screen.dart';

class GolfRoundSettingScreen extends StatefulWidget {
  final String courseName; // 前の画面から受け取るゴルフ場名

  const GolfRoundSettingScreen({super.key, required this.courseName});

  @override
  State<GolfRoundSettingScreen> createState() => _GolfRoundSettingScreenState();
}

class _GolfRoundSettingScreenState extends State<GolfRoundSettingScreen> {
  // --- 入力データ ---
  DateTime _selectedDate = DateTime.now();
  String _selectedWeather = 'sunny';
  String _windStrength = '微風';
  String _frontCourse = 'OUT';
  String _backCourse = 'IN';
  String _teeArea = 'Regular (White)';
  String _greenType = 'ベント';
  bool _usePutterInput = true;

  // メンバー
  final TextEditingController _member2Controller = TextEditingController();
  final TextEditingController _member3Controller = TextEditingController();
  final TextEditingController _member4Controller = TextEditingController();

  // --- ダミー選択肢 ---
  final List<String> _courseHalves = ['OUT', 'IN', 'EAST', 'WEST', 'SOUTH', 'NORTH'];
  final List<String> _windOptions = ['無風', '微風', '普通', '強風'];
  final List<String> _teeOptions = ['Back (Blue)', 'Regular (White)', 'Front (Red)', 'Gold'];
  final List<String> _greenOptions = ['ベント', '高麗', 'バミューダ'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ラウンド情報設定', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ゴルフ場名ヘッダー
              _buildHeaderCard(),
              const SizedBox(height: 16),

              // 2. コンディション
              _buildSectionTitle("コンディション"),
              _buildConditionCard(),
              const SizedBox(height: 16),

              // 3. コース設定
              _buildSectionTitle("コース設定"),
              _buildCourseSettingCard(),
              const SizedBox(height: 16),

              // 4. メンバー設定
              _buildSectionTitle("メンバー"),
              _buildMemberCard(),
              const SizedBox(height: 30),

              // 5. 開始ボタン
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // メンバーリストを作成
                    List<String> members = ["自分"]; // 先頭は固定
                    if (_member2Controller.text.isNotEmpty) members.add(_member2Controller.text);
                    if (_member3Controller.text.isNotEmpty) members.add(_member3Controller.text);
                    if (_member4Controller.text.isNotEmpty) members.add(_member4Controller.text);

                    // 設定値をまとめる
                    Map<String, dynamic> settings = {
                      'date': _selectedDate,
                      'weather': _selectedWeather,
                      'wind': _windStrength,
                      'front': _frontCourse,
                      'back': _backCourse,
                      'tee': _teeArea,
                      'green': _greenType,
                    };
                    // 画面遷移
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GolfScoreInputScreen(
                          courseName: widget.courseName,
                          settings: settings,
                          memberNames: members,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    "スコア入力開始",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.golf_course, color: Colors.green, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.courseName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // 日付選択
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue),
                const SizedBox(width: 12),
                Text(DateFormat('yyyy/MM/dd').format(_selectedDate)),
                const Spacer(),
                const Text("変更", style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          const Divider(height: 24),
          
          // 天気選択
          Row(
            children: [
              const Icon(Icons.wb_sunny, color: Colors.orange),
              const SizedBox(width: 12),
              const Text("天気"),
              const Spacer(),
              _weatherIcon(Icons.wb_sunny, 'sunny', Colors.orange),
              const SizedBox(width: 8),
              _weatherIcon(Icons.cloud, 'cloudy', Colors.grey),
              const SizedBox(width: 8),
              _weatherIcon(Icons.umbrella, 'rain', Colors.blue),
            ],
          ),
          const Divider(height: 24),

          // 風
          Row(
            children: [
              const Icon(Icons.air, color: Colors.teal),
              const SizedBox(width: 12),
              const Text("風"),
              const Spacer(),
              DropdownButton<String>(
                value: _windStrength,
                underline: Container(),
                items: _windOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _windStrength = v!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherIcon(IconData icon, String value, Color color) {
    final isSelected = _selectedWeather == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedWeather = value),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isSelected ? color : Colors.grey),
      ),
    );
  }

  Widget _buildCourseSettingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildDropdownRow("前半コース", _frontCourse, _courseHalves, (v) => setState(() => _frontCourse = v!)),
          const Divider(),
          _buildDropdownRow("後半コース", _backCourse, _courseHalves, (v) => setState(() => _backCourse = v!)),
          const Divider(),
          _buildDropdownRow("ティー", _teeArea, _teeOptions, (v) => setState(() => _teeArea = v!)),
          const Divider(),
          _buildDropdownRow("グリーン", _greenType, _greenOptions, (v) => setState(() => _greenType = v!)),
          const Divider(),
          SwitchListTile(
            title: const Text("パット数入力"),
            value: _usePutterInput,
            activeThumbColor: Colors.green,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _usePutterInput = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        DropdownButton<String>(
          value: value,
          underline: Container(),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ---------------------------------------------------
  // 4. メンバー設定エリア（修正版）
  // ---------------------------------------------------
  Widget _buildMemberCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildMemberRow(const Icon(Icons.person, color: Colors.blue), "自分 (Player1)"),
          const Divider(),
          // キーボードアクションを指定（Next, Done）
          _buildMemberInput("同伴者2", _member2Controller, TextInputAction.next),
          const Divider(),
          _buildMemberInput("同伴者3", _member3Controller, TextInputAction.next),
          const Divider(),
          _buildMemberInput("同伴者4", _member4Controller, TextInputAction.done),
        ],
      ),
    );
  }

  Widget _buildMemberRow(Widget icon, String text) {
    return Row(
      children: [
        CircleAvatar(backgroundColor: Colors.blue.shade50, child: icon),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 入力フィールド（修正版：日本語入力最適化）
  // ここで3つの引数を受け取るように修正されています
  Widget _buildMemberInput(String hint, TextEditingController controller, TextInputAction action) {
    return Row(
      children: [
        const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person_outline, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            // 名前入力モード
            keyboardType: TextInputType.name,
            // キーボードのエンターキーの動作（次へ / 完了）
            textInputAction: action,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }
}