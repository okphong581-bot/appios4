class DeviceHardwareInfo {
  final String modelName;
  final String osVersion;
  final int totalDiskSpace;
  final int freeDiskSpace;
  final int estimatedRam;
  final int estimatedRefreshRate;
  final int batteryLevel;
  final bool isCharging;
  final double screenWidth;
  final double screenHeight;
  final double pixelRatio;

  DeviceHardwareInfo({
    required this.modelName,
    required this.osVersion,
    required this.totalDiskSpace,
    required this.freeDiskSpace,
    required this.estimatedRam,
    required this.estimatedRefreshRate,
    required this.batteryLevel,
    required this.isCharging,
    required this.screenWidth,
    required this.screenHeight,
    required this.pixelRatio,
  });
}

class OptimizationResult {
  final int performanceScore;
  final int stabilityScore;
  final int responseScore;
  final SensitivityProfile recommendedProfile;

  OptimizationResult({
    required this.performanceScore,
    required this.stabilityScore,
    required this.responseScore,
    required this.recommendedProfile,
  });
}

class SensitivityProfile {
  final String profileName;
  final String description;
  final int generalSensitivity;
  final int redDot;
  final int scope2x;
  final int scope4x;
  final int sniperScope;
  final int freeLook;
  final int recommendedButtonSize;

  SensitivityProfile({
    required this.profileName,
    required this.description,
    required this.generalSensitivity,
    required this.redDot,
    required this.scope2x,
    required this.scope4x,
    required this.sniperScope,
    required this.freeLook,
    required this.recommendedButtonSize,
  });
}
