import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 日付フォーマット用
import 'screens/home_screen.dart'; // インポート先を変更

void main() async {
  // Flutterエンジンの初期化待ち
  WidgetsFlutterBinding.ensureInitialized();
  
  // 日付フォーマット（日本語）の初期化
  await initializeDateFormatting('ja_JP', null);

  runApp(const AjitoApp());
}

class AjitoApp extends StatelessWidget {
  const AjitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ajito',
      debugShowCheckedModeBanner: false,
      
      // アプリ全体のテーマ設定
      theme: ThemeData(
        brightness: Brightness.dark, 
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        
        // カードのデザイン設定
        // ★最新版Flutterに合わせて修正しました
        cardTheme: CardThemeData( // ← CardThemeData に変更
          color: Colors.white.withValues(alpha: 0.1), // ← withValues(alpha: 0.1) に変更
          elevation: 0,
        ),
      ),
      
      // ホーム画面をダッシュボードに設定
      home: const HomeScreen(),
    );
  }
}