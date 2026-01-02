import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // リサイズ用
import 'package:path_provider/path_provider.dart'; // 一時保存用
import '../models/activity.dart';
import '../services/api_service.dart';

class ScoreEntryScreen extends StatefulWidget {
  const ScoreEntryScreen({super.key});

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  final ApiService _apiService = ApiService();
  
  // コントローラー（名前、スコア、チップ）
  final List<TextEditingController> _nameControllers = 
      List.generate(4, (i) => TextEditingController(text: "Player ${i + 1}"));
  final List<TextEditingController> _scoreControllers = 
      List.generate(4, (i) => TextEditingController());
  final List<TextEditingController> _chipControllers = 
      List.generate(4, (i) => TextEditingController(text: "0"));

  // 画像関連
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // スコア入力の変更を監視して自動計算するリスナーを登録
    for (var controller in _scoreControllers) {
      controller.addListener(_autoCalculateScore);
    }
  }

  @override
  void dispose() {
    for (var c in _nameControllers) {
      c.dispose();
    }
    for (var c in _scoreControllers) {
      c.dispose();
    }
    for (var c in _chipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- 🧠 ロジック: 3点入力・1点自動計算 ---
  void _autoCalculateScore() {
    // 編集中のコントローラーを特定するのは難しいため、
    // 「空欄が1つだけある場合」にその空欄を埋めるロジックにします
    
    int emptyCount = 0;
    int emptyIndex = -1;
    int currentSum = 0;

    for (int i = 0; i < 4; i++) {
      String text = _scoreControllers[i].text;
      if (text.isEmpty) {
        emptyCount++;
        emptyIndex = i;
      } else {
        // 数値としてパースできるか確認（マイナス記号などの途中入力対策）
        int? val = int.tryParse(text);
        if (val != null) {
          currentSum += val;
        }
      }
    }

    // 空欄がちょうど1つの時だけ、自動計算を実行
    if (emptyCount == 1 && emptyIndex != -1) {
      // 合計を0にするための値 = (現在の合計 * -1)
      int targetVal = -currentSum;
      
      // リスナーがループしないように一時的に外す（今回は簡易的に値セットのみ）
      // ※カーソル位置の問題などが出ないよう、実際はFocusNode判定がベストですが今回は簡易実装
      _scoreControllers[emptyIndex].text = targetVal.toString();
    }
  }

  // --- 📷 画像処理: 選択とリサイズとアップロード ---
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    // 選択ダイアログ
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() { _isUploading = true; });

      // 1. リサイズ処理 (横幅1024pxに縮小)
      File originalFile = File(pickedFile.path);
      File resizedFile = await _resizeImage(originalFile);

      setState(() { _selectedImage = resizedFile; });

      // 2. サーバーへアップロード
      String? url = await _apiService.uploadImage(resizedFile);
      
      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });

      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像のアップロード完了！')),
        );
      }
    }
  }

  Future<File> _resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    // 横幅が1024を超えていたらリサイズ
    if (image.width > 1024) {
      final resized = img.copyResize(image, width: 1024);
      final tempDir = await getTemporaryDirectory();
      final tempPath = "${tempDir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg";
      return File(tempPath)..writeAsBytesSync(img.encodeJpg(resized, quality: 85));
    }
    return file;
  }

  // --- 💾 保存処理 ---
  Future<void> _saveSession() async {
    // バリデーション: スコアの合計が0か？
    int sum = 0;
    List<int> scores = [];
    List<int> chips = [];
    List<String> names = [];

    try {
      for (int i = 0; i < 4; i++) {
        int s = int.parse(_scoreControllers[i].text);
        int c = int.tryParse(_chipControllers[i].text) ?? 0;
        sum += s;
        scores.add(s);
        chips.add(c);
        names.add(_nameControllers[i].text);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スコアは全て数値で入力してください')),
      );
      return;
    }

    if (sum != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('スコアの合計が0になっていません（現在: $sum）')),
      );
      return;
    }

    // データ作成
    // ※今回は簡易的に「ラウンド数1」として登録します
    MahjongData mahjongData = MahjongData(
      playerCount: 4,
      playerNames: names,
      hasChip: 1,
      chips: chips,
      rounds: [
        MahjongRound(roundNumber: 1, scores: scores)
      ],
      yakumans: _uploadedImageUrl != null ? [
        MahjongYakuman(
          roundNumber: 1, 
          playerIndex: 0, // 仮: 誰があがったかは未指定
          yakumanName: "役満画像あり", 
          imagePath: _uploadedImageUrl!
        )
      ] : [],
    );

    Activity activity = Activity(
      userId: "user_001", // 仮のID
      category: "mahjong",
      playedAt: DateTime.now(),
      placeName: "雀荘（テスト）",
      summaryText: "Flutterからの投稿テスト",
      primaryScore: scores[0], // 自分のスコア（Player1と仮定）
      imageUrls: _uploadedImageUrl != null ? [_uploadedImageUrl!] : [],
      mahjongData: mahjongData,
    );

    // 送信
    bool success = await _apiService.postActivity(activity);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('対局データを保存しました！')),
      );
      // フォームをクリア または 前の画面に戻る
      Navigator.pop(context); 
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存に失敗しました...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('対局結果入力')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ヘッダー
            Row(
              children: const [
                Expanded(flex: 2, child: Text("名前", textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text("スコア", textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text("チップ", textAlign: TextAlign.center)),
              ],
            ),
            const SizedBox(height: 10),
            
            // 4人分の入力行
            ...List.generate(4, (index) => _buildPlayerRow(index)),

            const SizedBox(height: 20),
            const Divider(),

            // 画像アップロードエリア
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('役満・証拠画像の添付'),
              subtitle: _uploadedImageUrl != null 
                  ? const Text("アップロード済み ✅") 
                  : const Text("タップして画像を選択"),
              onTap: _isUploading ? null : _pickAndUploadImage,
              trailing: _selectedImage != null 
                  ? Image.file(_selectedImage!, width: 50, height: 50, fit: BoxFit.cover)
                  : null,
            ),
            if (_isUploading) const LinearProgressIndicator(),

            const SizedBox(height: 30),

            // 保存ボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('対局結果を保存', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // プレイヤー1行分のWidget
  Widget _buildPlayerRow(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // 名前
          Expanded(
            flex: 2,
            child: TextField(
              controller: _nameControllers[index],
              decoration: InputDecoration(
                labelText: 'Player ${index + 1}',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // スコア (数値キーボード)
          Expanded(
            flex: 1,
            child: TextField(
              controller: _scoreControllers[index],
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          // チップ
          Expanded(
            flex: 1,
            child: TextField(
              controller: _chipControllers[index],
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}