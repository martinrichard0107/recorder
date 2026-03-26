import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:system_recorder/providers/match_provider.dart';
import 'package:system_recorder/screens/starting_lineup_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MatchProvider()),
      ],
      child: MaterialApp(
        title: '排球紀錄系統',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, 
            brightness: Brightness.dark
          ),
          useMaterial3: true,
        ),
        // ★ 第二步：把啟動頁面改為 StartingLineupScreen
        home: const StartingLineupScreen(), 
      ),
    );
  }
}