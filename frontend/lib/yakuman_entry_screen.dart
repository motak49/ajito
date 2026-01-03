import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 画像選択用
import 'db_helper.dart';

class YakumanEntryScreen extends StatefulWidget {
  final int sessionId;
  final int roundNumber;
  final List<String> playerNames;

  const YakumanEntryScreen({
    super.key,
    required this.sessionId,
    required this.roundNumber,
    required this.playerNames,
  });

  @override
  State<YakumanEntryScreen> createState() => _YakumanEntryScreenState();
}

class _YakumanEntryScreenState extends State<YakumanEntryScreen> {
  // 選択されたプレイヤーのインデックス（初期値は0:一人目）
  int _selectedPlayerIndex = 0;
  
  // 役満リスト
  final List<String> _yakumanList = [
    '国士無双', '四暗刻', '大三元', '字一色', '緑一色', 
    '小四喜', '大四喜', '清老頭', '九蓮宝燈', '四槓子', 
    '天和', '地和', '数え役満'
  ];
  String _selectedYakuman = '国士無双'; // 初期値

  // 画像関連
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // ■ カメラ/ギャラリーから画像を取得
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("画像選択エラー: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の取得に失敗しました')),
      );
    }
  }

  // ■ 保存処理
  Future<void> _saveYakuman() async {
    // DBへ保存
    final dbHelper = DatabaseHelper();
    Map<String, dynamic> row = {
      'session_id': widget.sessionId,
      'round_number': widget.roundNumber,
      'player_index': _selectedPlayerIndex,
      'yakuman_name': _selectedYakuman,
      'image_path': _imageFile?.path ?? '', // 画像がない場合は空文字
      'is_synced': 0,
    };

    await dbHelper.insertYakuman(row);

    if (!mounted) return;
    
    // 完了メッセージを出して戻る
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('祝！役満を登録しました！')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('役満登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("誰がアガりましたか？", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // プレイヤー選択ドロップダウン
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedPlayerIndex,
                  isExpanded: true,
                  items: List.generate(widget.playerNames.length, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(widget.playerNames[index]),
                    );
                  }),
                  onChanged: (val) => setState(() => _selectedPlayerIndex = val!),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text("役満の種類", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // 役満選択ドロップダウン
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedYakuman,
                  isExpanded: true,
                  items: _yakumanList.map((y) {
                    return DropdownMenuItem(
                      value: y,
                      child: Text(y),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedYakuman = val!),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text("証拠写真 (任意)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // 画像プレビューエリア
            Center(
              child: GestureDetector(
                onTap: () => _showImageSourceDialog(), // タップでも選択可
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                            Text("写真を撮る / 選ぶ", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // カメラ・ギャラリーボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("カメラ"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("アルバム"),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // 登録ボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveYakuman,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800, // 役満っぽい赤色
                  foregroundColor: Colors.white,
                ),
                child: const Text('この内容で登録する', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // カメラかギャラリーか選ぶダイアログ
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('カメラで撮影'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('アルバムから選択'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}