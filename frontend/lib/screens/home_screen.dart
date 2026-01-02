import 'package:flutter/material.dart';
import 'package:frontend/screens/golf/golf_home_screen.dart'; // import
import 'dashboard_screen.dart'; // 麻雀の画面をインポート


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ユーザー名（仮）
    const String userName = "Player1";

    return Scaffold(
      appBar: AppBar(
        title: const Text('AJITO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 会員情報編集への入り口（アイコン）
          IconButton(
            icon: const Icon(Icons.account_circle, size: 32),
            onPressed: () {
              // TODO: 会員情報編集画面へ遷移
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('会員機能は準備中です')),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      // 全体の背景色（少しリッチなグラデーションにしてもカッコいいです）
      backgroundColor: const Color(0xFF121212),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome back, $userName",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              "MENU",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // メニューパネルのグリッド表示
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, // 2列
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1, // パネルの縦横比
                children: [
                  // 1. 麻雀 (実装済み)
                  _buildMenuCard(
                    context,
                    title: 'MAHJONG',
                    icon: Icons.apps, // 適切なアイコンがあれば画像に変更可
                    color: Colors.green.shade800,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DashboardScreen()),
                      );
                    },
                  ),
                  // 2. ゴルフ (未実装)
                  _buildMenuCard(
                    context,
                    title: 'GOLF',
                    icon: Icons.golf_course,
                    color: Colors.blueGrey.shade800,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GolfHomeScreen()),
                      );
                    },
                  ),
                  // 3. パチンコ (未実装)
                  _buildMenuCard(
                    context,
                    title: 'PACHINKO',
                    icon: Icons.casino, // スロットっぽいアイコン
                    color: Colors.purple.shade900,
                    onTap: () {
                      _showComingSoon(context);
                    },
                  ),
                  // 4. 釣り (未実装)
                  _buildMenuCard(
                    context,
                    title: 'FISHING',
                    icon: Icons.phishing,
                    color: Colors.blue.shade900,
                    onTap: () {
                      _showComingSoon(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // パネルを作成するウィジェット
  Widget _buildMenuCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      color: color.withValues(alpha: 0.8), // 少し透けさせる
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('この機能は開発中です 🚧'), duration: Duration(milliseconds: 800)),
    );
  }
}