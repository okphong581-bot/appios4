import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VIP Hack',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const platform = MethodChannel('com.mod.menu/hack');

  Future<void> _startHack() async {
    try {
      await platform.invokeMethod('showMenu');
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('TrollStore VIP Mod', style: TextStyle(color: Colors.green)),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 100, color: Colors.green),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _startHack,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('BẬT MENU NỔI', style: TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const Text('Bấm nút trên để cấp quyền Root\nvà hiển thị Menu Nổi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
