// frontend/lib/services/gemini_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // ★セキュリティ: 本番環境ではAPIキーをバックエンド等で管理してください
  static const String _apiKey = 'AIzaSyD2wd2BkkD0TGS3am_n-ODHa7AMGG5TP2w';

  final GenerativeModel _model;

  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  Future<Map<String, dynamic>?> analyzeScoreCard(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      
      // ★プロンプト修正: 記号を維持するように指示
      final prompt = Content.multi([
        TextPart('''
          このゴルフスコアカード画像を解析し、以下のJSON形式で出力してください。
          
          【重要: スコアの読み取りについて】
          - 数字が書かれている場合はその数字を出力してください。
          - 記号（△, □, ○, ◎, -, +3 など）が書かれている場合は、その記号を「文字列としてそのまま」出力してください。無理に数字に変換しないでください。
          - 空欄は "0" または "-" としてください。

          【出力フォーマット】
          {
            "play_date": "YYYY-MM-DD",  // 不明なら今日
            "place_name": "ゴルフ場名",
            "player_names": ["プレイヤー1", "プレイヤー2", ...],
            "pars": [4, 4, 3, ...], // もし読み取れれば各ホールのPar数（18ホール分）。読み取れなければ空配列。
            "scores": [
              ["4", "△", "□", "5", ...], // ★数字と記号が混在する文字列配列のリスト
              ["-", "○", "4", "4", ...]
            ]
          }
        '''),
        DataPart('image/jpeg', imageBytes),
      ]);

      final response = await _model.generateContent([prompt]);
      
      print('Gemini Response: ${response.text}'); // デバッグ用

      if (response.text != null) {
        return jsonDecode(response.text!);
      }
    } catch (e) {
      print('Gemini Error: $e');
    }
    return null;
  }
}