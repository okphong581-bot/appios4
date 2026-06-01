import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../widgets/glass_card.dart';
import '../services/action_service.dart';

class OptimizationScreen extends ConsumerWidget {
  const OptimizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(optimizationResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết Quả Phân Tích', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: resultAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00E676)),
              SizedBox(height: 20),
              Text('Đang tính toán độ nhạy & hãm phanh...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (result) {
          if (result == null) return const SizedBox();
          final profile = result.recommendedProfile;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Điểm số
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildScoreGauge('Hiệu Năng', result.performanceScore, Colors.blue),
                    _buildScoreGauge('Ổn Định', result.stabilityScore, Colors.orange),
                    _buildScoreGauge('Phản Hồi', result.responseScore, Colors.purple),
                  ],
                ),
                const SizedBox(height: 30),
                const Text('ĐỘ NHẠY ĐỀ XUẤT (Thang 200)', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.profileName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 5),
                      Text(profile.description, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                      const Divider(color: Colors.white24, height: 30),
                      _buildSensRow('Nhìn Xung Quanh', profile.generalSensitivity),
                      _buildSensRow('Red Dot', profile.redDot),
                      _buildSensRow('Ống ngắm 2x', profile.scope2x),
                      _buildSensRow('Ống ngắm 4x', profile.scope4x),
                      _buildSensRow('Ống ngắm AWM', profile.sniperScope),
                      _buildSensRow('Nhìn tự do', profile.freeLook),
                      const Divider(color: Colors.white24, height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Kích Thước Nút Bắn (Hãm phanh)', style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('${profile.recommendedButtonSize}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text('CÔNG CỤ TỐI ƯU', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('CÀI ĐẶT PROFILE KÌM HÃM (.mobileconfig)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => _downloadMobileConfig(context),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('MỞ CÀI ĐẶT CHẠM (ACCESSIBILITY)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => ActionService.openIosSettings('App-Prefs:root=ACCESSIBILITY'),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.gamepad),
                  label: const Text('MỞ FREE FIRE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  onPressed: () async {
                    try {
                      await ActionService.openFreeFire();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreGauge(String title, int score, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                value: score / 100,
                color: color,
                backgroundColor: Colors.white10,
                strokeWidth: 8,
              ),
            ),
            Text('$score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildSensRow(String name, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
          Text('$value', style: const TextStyle(color: Color(0xFF00E676), fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _downloadMobileConfig(BuildContext context) async {
    final String configData = ActionService.generateMobileConfig();
    final bytes = utf8.encode(configData);
    final base64String = base64Encode(bytes);
    
    // Tạo data URI để ép Safari tải file .mobileconfig
    final Uri url = Uri.parse("data:application/x-apple-aspen-config;base64,\$base64String");
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang chuyển hướng để cài đặt Profile...'), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải Profile: \$e'), backgroundColor: Colors.red)
      );
    }
  }
}
