import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_provider.dart';
import '../widgets/glass_card.dart';
import 'optimization_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hardwareAsync = ref.watch(deviceHardwareProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HoangHa Optimizer', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: hardwareAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (info) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('THÔNG TIN THIẾT BỊ', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                GlassCard(
                  height: 250,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoRow(Icons.phone_iphone, 'Model', info.modelName),
                      _buildInfoRow(Icons.system_update, 'iOS Version', info.osVersion),
                      _buildInfoRow(Icons.memory, 'Estimated RAM', '${info.estimatedRam} GB'),
                      _buildInfoRow(Icons.battery_full, 'Pin', '${info.batteryLevel}% (${info.isCharging ? "Sạc" : "Rút sạc"})'),
                      _buildInfoRow(Icons.hd, 'Màn hình', '${info.screenWidth.toInt()}x${info.screenHeight.toInt()} (${info.estimatedRefreshRate}Hz)'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to Analysis Screen
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OptimizationScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 10,
                    shadowColor: const Color(0xFF00E676).withOpacity(0.5),
                  ),
                  child: const Text('PHÂN TÍCH & TỐI ƯU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF00E676), size: 20),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
