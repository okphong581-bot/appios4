import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In-App Mod Menu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ModMenuOverlay(
        child: MainAppScreen(),
      ),
    );
  }
}

class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Ứng dụng chính', style: TextStyle(color: Colors.green)),
        backgroundColor: Colors.grey[900],
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.gamepad, size: 100, color: Colors.white54),
            SizedBox(height: 20),
            Text(
              'Đây là ứng dụng bình thường.\nMenu  đã được gắn chết bên trong App!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class ModMenuOverlay extends StatefulWidget {
  final Widget child;
  const ModMenuOverlay({super.key, required this.child});

  @override
  State<ModMenuOverlay> createState() => _ModMenuOverlayState();
}

class _ModMenuOverlayState extends State<ModMenuOverlay> {
  Offset position = const Offset(20, 150);
  bool isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                position += details.delta;
              });
            },
            child: Material(
              color: Colors.transparent,
              child: isMenuOpen ? _buildExpandedMenu() : _buildFloatingButton(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isMenuOpen = true;
        });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: const Center(
          child: Text('', style: TextStyle(fontSize: 30, color: Colors.black)),
        ),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mod Menu VIP', style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() {
                    isMenuOpen = false;
                  });
                },
              )
            ],
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.security, color: Colors.blue),
            title: const Text('Bật Hack VIP', style: TextStyle(color: Colors.white, fontSize: 14)),
            trailing: Switch(value: true, activeColor: Colors.green, onChanged: (v){}),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            leading: const Icon(Icons.speed, color: Colors.orange),
            title: const Text('Tốc Độ x2', style: TextStyle(color: Colors.white, fontSize: 14)),
            trailing: Switch(value: false, activeColor: Colors.green, onChanged: (v){}),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
