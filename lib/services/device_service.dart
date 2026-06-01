import 'dart:io';
import 'dart:ui';
import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/device_info_model.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Battery _battery = Battery();

  static Future<DeviceHardwareInfo> getHardwareInfo() async {
    String modelName = 'Unknown';
    String osVersion = 'Unknown';
    int estimatedRam = 4; // Default fallback in GB
    int estimatedRefreshRate = 60; // Default fallback in Hz

    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      modelName = iosInfo.utsname.machine;
      osVersion = iosInfo.systemVersion;
      
      // Estimate RAM and Refresh Rate based on iOS device model (machine name)
      // Reference mappings (simplified for brevity)
      if (modelName.contains('iPhone14') || modelName.contains('iPhone15')) {
        // iPhone 13 Pro / 14 Pro
        estimatedRam = 6;
        estimatedRefreshRate = modelName.contains('Pro') ? 120 : 60;
      } else if (modelName.contains('iPhone16')) {
        // iPhone 15 Pro
        estimatedRam = 8;
        estimatedRefreshRate = 120;
      } else if (modelName.contains('iPhone12') || modelName.contains('iPhone13')) {
        // iPhone 11 / 12
        estimatedRam = 4;
      } else if (modelName.contains('iPhone10') || modelName.contains('iPhone11')) {
        // iPhone X / XS / XR
        estimatedRam = 3;
      }
    }

    int batteryLevel = 100;
    bool isCharging = false;
    try {
      batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      isCharging = (batteryState == BatteryState.charging || batteryState == BatteryState.connectedNotCharging);
    } catch (e) {
      // Ignored if battery API fails
    }

    // Screen info
    FlutterView view = PlatformDispatcher.instance.views.first;
    double pixelRatio = view.devicePixelRatio;
    Size screenSize = view.physicalSize / pixelRatio;

    return DeviceHardwareInfo(
      modelName: modelName,
      osVersion: osVersion,
      totalDiskSpace: 128, // iOS API does not easily expose this without native code
      freeDiskSpace: 32,   // Mocked as iOS does not expose disk space via basic API
      estimatedRam: estimatedRam,
      estimatedRefreshRate: estimatedRefreshRate,
      batteryLevel: batteryLevel,
      isCharging: isCharging,
      screenWidth: screenSize.width,
      screenHeight: screenSize.height,
      pixelRatio: pixelRatio,
    );
  }

  static Future<OptimizationResult> analyzeDevice(DeviceHardwareInfo info) async {
    // Thuật toán tính toán độ nhạy phù hợp với thiết bị, thang 0-200
    // Các máy đời mới màn hình mượt (120Hz), cấu hình cao (RAM 6GB+) -> độ nhạy nên thấp hơn một chút để giữ tâm chuẩn
    // Máy đời cũ (60Hz) -> độ nhạy cần kéo lên cao để bù đắp sự chậm trễ cảm ứng

    int baseSensitivity = 100;
    int baseButtonSize = 65; // Kích thước nút bắn chuẩn (giúp hãm phanh)

    if (info.estimatedRefreshRate == 120) {
      baseSensitivity = 140; 
      baseButtonSize = 60; // Màn mượt, nút bắn nhỏ lại chút để tap chính xác
    } else if (info.estimatedRam >= 4) {
      baseSensitivity = 175;
      baseButtonSize = 55;
    } else {
      baseSensitivity = 200; // Máy cũ cần độ trượt tối đa
      baseButtonSize = 50;   // Kéo dễ hơn
    }

    int perfScore = (info.estimatedRam * 10).clamp(40, 95) + (info.batteryLevel > 20 ? 5 : 0);
    int stabScore = (info.estimatedRefreshRate == 120 ? 98 : 85);
    int responseScore = (info.pixelRatio > 2.0 ? 90 : 75);

    return OptimizationResult(
      performanceScore: perfScore,
      stabilityScore: stabScore,
      responseScore: responseScore,
      recommendedProfile: SensitivityProfile(
        profileName: 'HoangHa Cân Bằng VIP',
        description: 'Tối ưu độ nhạy mức tối đa 200 giúp vuốt mượt, hãm phanh tâm chuẩn xác.',
        generalSensitivity: baseSensitivity,
        redDot: (baseSensitivity * 0.95).round().clamp(0, 200),
        scope2x: (baseSensitivity * 0.90).round().clamp(0, 200),
        scope4x: (baseSensitivity * 0.85).round().clamp(0, 200),
        sniperScope: (baseSensitivity * 0.60).round().clamp(0, 200),
        freeLook: 100,
        recommendedButtonSize: baseButtonSize,
      ),
    );
  }
}
