import 'package:flutter/material.dart';
import 'package:frontend/screens/golf/round_setting_screen.dart';

// --- ダミーデータ ---
const Map<String, List<String>> _regionData = {
  '北海道・東北': ['北海道', '青森', '岩手', '宮城', '秋田', '山形', '福島'],
  '関東・甲信越': ['東京', '神奈川', '埼玉', '千葉', '茨城', '栃木', '群馬', '山梨', '長野', '新潟'],
  '中部': ['愛知', '岐阜', '三重', '静岡', '富山', '石川', '福井'],
  '近畿': ['大阪', '兵庫', '京都', '滋賀', '奈良', '和歌山'],
  '中国・四国': ['鳥取', '島根', '岡山', '広島', '山口', '徳島', '香川', '愛媛', '高知'],
  '九州・沖縄': ['福岡', '佐賀', '長崎', '熊本', '大分', '宮崎', '鹿児島', '沖縄'],
};

// 選択された県に応じたダミーゴルフ場リスト
List<String> _getDummyCourses(String prefecture) {
  if (prefecture == '愛知') {
    return ['愛知カンツリー倶楽部', '葵カントリークラブ', '秋葉ゴルフ倶楽部', '稲武カントリークラブ', '犬山カンツリー倶楽部', 'ウッドフレンズ森林公園ゴルフ場'];
  } else if (prefecture == '岐阜') {
    return ['岐阜関カントリー倶楽部', '各務原カントリー倶楽部', '富士カントリー可児クラブ'];
  }
  return ['$prefecture カントリークラブ', '$prefecture パブリックコース', '国際 $prefecture ゴルフ倶楽部'];
}

// -----------------------------------------
// 1. エリア選択画面
// -----------------------------------------
class RegionSelectScreen extends StatelessWidget {
  const RegionSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('エリア選択', style: TextStyle(color: Colors.black87)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black87)),
      body: ListView(
        children: _regionData.keys.map((region) {
          return ListTile(
            title: Text(region),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PrefectureSelectScreen(region: region)),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------
// 2. 都道府県選択画面
// -----------------------------------------
class PrefectureSelectScreen extends StatelessWidget {
  final String region;
  const PrefectureSelectScreen({super.key, required this.region});

  @override
  Widget build(BuildContext context) {
    final prefs = _regionData[region] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('都道府県選択', style: TextStyle(color: Colors.black87)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black87)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            width: double.infinity,
            child: Text(region, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: prefs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(prefs[index]),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => GolfCourseListScreen(prefecture: prefs[index])),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------
// 3. ゴルフ場一覧画面 (最終選択)
// -----------------------------------------
class GolfCourseListScreen extends StatelessWidget {
  final String prefecture;
  const GolfCourseListScreen({super.key, required this.prefecture});

  @override
  Widget build(BuildContext context) {
    final courses = _getDummyCourses(prefecture);

    return Scaffold(
      appBar: AppBar(title: const Text('ゴルフ場選択', style: TextStyle(color: Colors.black87)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black87)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ゴルフ場名を入力してください',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            width: double.infinity,
            child: Text('$prefectureのゴルフ場', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: courses.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(courses[index]),
                  trailing: const Icon(Icons.check_circle_outline, color: Colors.green), // 選択可能であることを示唆
                  onTap: () {
                    // ここで次のステップ（ラウンド設定画面）へ遷移しますが、
                    // 今回のスコープは「遷移確認」までなのでダイアログで止めます。
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(courses[index]),
                        content: const Text("このゴルフ場でラウンドを開始しますか？\n（次はラウンド設定画面へ進みます）"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("キャンセル")),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // ダイアログ閉じる
                              // ★追加: ラウンド設定画面へ遷移
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GolfRoundSettingScreen(
                                    courseName: courses[index], // 選択したコース名を渡す
                                  ),
                                ),
                              );
                            },
                            child: const Text("決定"),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}