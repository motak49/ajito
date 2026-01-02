import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

class VoiceInputHelper {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;

  // 初期化
  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (val) => print('Voice Error: $val'),
      onStatus: (val) => print('Voice Status: $val'),
    );
    return _isAvailable;
  }

  // 録音開始
  void listen({
    required Function(String) onResult,
  }) {
    if (!_isAvailable) return;

    _speech.listen(
      onResult: (val) {
        if (val.recognizedWords.isNotEmpty) {
          onResult(val.recognizedWords);
        }
      },
      localeId: 'ja_JP',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 60),
      onSoundLevelChange: (level) {},
    );
  }

  void stop() {
    _speech.stop();
  }

  // --- 解析ロジック ---

  int? parseScore(String text, int currentPar) {
    List<int> results = parseScoreList(text, currentPar);
    return results.isNotEmpty ? results.first : null;
  }

  // 連続解析 (一括入力用)
  List<int> parseScoreList(String text, int currentPar) {
    // デバッグ用: 生のテキストをコンソールに出力
    print("Raw Voice Input: $text");

    // ★変更点: 全ての空白を削除するのではなく、区切り文字をスペースに統一する
    // これにより "5 5 2 1" が "5521" に結合されるのを防ぐ
    String cleanText = text
        .replaceAll('、', ' ')
        .replaceAll(',', ' ')
        .replaceAll('.', ' '); 

    List<int> results = [];

    // 解析用正規表現パターン
    final RegExp regex = RegExp(
      r'(ホールインワン|アルバトロス|イーグル|バーディ|パー|トリプルボギー|ダブルボギー|ダボ|ボギー)|' // 用語
      r'([0-9]+)|' // 半角数字
      r'([１-９]+)|' // 全角数字
      r'(一|二|三|四|五|六|七|八|九|十|十一|十二)' // 漢数字
    );

    final matches = regex.allMatches(cleanText);

    for (final match in matches) {
      String word = match.group(0)!;
      int? val;

      // 1. ゴルフ用語
      if (word.contains('ホールインワン')) {
        val = 1;
      } else if (word.contains('アルバトロス')) val = currentPar - 3;
      else if (word.contains('イーグル')) val = currentPar - 2;
      else if (word.contains('バーディ')) val = currentPar - 1;
      else if (word.contains('パー')) val = currentPar;
      else if (word.contains('トリプルボギー')) val = currentPar + 3;
      else if (word.contains('ダブルボギー') || word.contains('ダボ')) val = currentPar + 2;
      else if (word.contains('ボギー')) val = currentPar + 1;
      
      // 2. 数字変換
      else {
        val = _parseNumber(word);
        
        // ★桁分解ロジック
        // エンジンが "5521" (空白なし) で返してきた場合の対策
        if (val != null && val > 18) {
           String digits = val.toString();
           for (int i = 0; i < digits.length; i++) {
             int? digitVal = int.tryParse(digits[i]);
             if (digitVal != null) {
               results.add(digitVal);
             }
           }
           // 分解して追加したので、元の大きな数字(5521)は追加しないようにnullにする
           val = null; 
        }
      }

      // 通常のスコア（または用語変換後）を追加
      if (val != null) {
        results.add(val);
      }
    }
    
    print("Parsed Scores: $results"); // デバッグ出力
    return results;
  }

  int? _parseNumber(String text) {
    const map = {
      '１': '1', '一': '1', '壱': '1',
      '２': '2', '二': '2', '弐': '2',
      '３': '3', '三': '3', '参': '3',
      '４': '4', '四': '4',
      '５': '5', '五': '5',
      '６': '6', '六': '6',
      '７': '7', '七': '7',
      '８': '8', '八': '8',
      '９': '9', '九': '9',
      '１０': '10', '十': '10',
      '１１': '11', '十一': '11',
      '１２': '12', '十二': '12',
      '１３': '13', '十三': '13',
      '１４': '14', '十四': '14',
      '１５': '15', '十五': '15',
    };
    
    String s = text;
    map.forEach((k, v) => s = s.replaceAll(k, v));
    return int.tryParse(s);
  }
}