import 'package:flutter/material.dart';
import 'golf_region_flow.dart';

class GolfSearchMenuScreen extends StatelessWidget {
  const GolfSearchMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ゴルフ場検索方法', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Container(
        color: Colors.grey[50],
        child: ListView(
          children: [
            const SizedBox(height: 20),
            _buildMenuItem(context, "近くのゴルフ場を探す", Icons.near_me, null),
            _buildMenuItem(context, "ゴルフ場名・地域・都道府県で探す", Icons.map, () {
              // 「地域から探す」フローへ遷移
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegionSelectScreen()),
              );
            }),
            _buildMenuItem(context, "スコア履歴から探す", Icons.history, null),
            _buildMenuItem(context, "GDOゴルフ場予約履歴から探す", Icons.calendar_today, null),
            _buildMenuItem(context, "ゴルフ場名をフリー入力して登録", Icons.edit, null), // とりあえずnull
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("開発中です: 後ほど実装します")),
          );
        },
      ),
    );
  }
}