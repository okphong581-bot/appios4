import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisHistory {
  final DateTime timestamp;
  final String deviceModel;
  final int performanceScore;
  final String profileName;

  AnalysisHistory({
    required this.timestamp,
    required this.deviceModel,
    required this.performanceScore,
    required this.profileName,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'deviceModel': deviceModel,
        'performanceScore': performanceScore,
        'profileName': profileName,
      };

  factory AnalysisHistory.fromJson(Map<String, dynamic> json) {
    return AnalysisHistory(
      timestamp: DateTime.parse(json['timestamp']),
      deviceModel: json['deviceModel'],
      performanceScore: json['performanceScore'],
      profileName: json['profileName'],
    );
  }
}

class StorageService {
  static const String _historyKey = 'analysis_history';

  static Future<void> saveHistory(AnalysisHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentList = prefs.getStringList(_historyKey) ?? [];
    currentList.insert(0, jsonEncode(history.toJson())); // Thêm vào đầu
    // Giữ lại 20 lịch sử gần nhất
    if (currentList.length > 20) {
      currentList = currentList.sublist(0, 20);
    }
    await prefs.setStringList(_historyKey, currentList);
  }

  static Future<List<AnalysisHistory>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentList = prefs.getStringList(_historyKey) ?? [];
    return currentList.map((str) => AnalysisHistory.fromJson(jsonDecode(str))).toList();
  }
}
