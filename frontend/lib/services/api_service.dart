import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/activity.dart';

class ApiService {
  // Androidエミュレーター用。実機ならPCのIPアドレス(例: 192.168.1.10)に変更
  static const String baseUrl = 'http://10.0.2.2:8080/api';
  
  // ダッシュボード用データ（集計結果）を取得
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final url = Uri.parse('$baseUrl/dashboard');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Dashboard Error: $e');
      return {}; // エラー時は空を返す
    }
  }

  // 画像をアップロードして、サーバー上のURLパスを受け取る
  Future<String?> uploadImage(File imageFile) async {
    final url = Uri.parse('$baseUrl/upload');
    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url']; // 例: "/uploads/170000_test.jpg"
      } else {
        print('Upload Failed: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  // アクティビティ（対局結果）をJSONで投稿
  Future<bool> postActivity(Activity activity) async {
    final url = Uri.parse('$baseUrl/activities');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(activity.toJson()),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Post Activity Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Post Activity Error: $e');
      return false;
    }
  }
}