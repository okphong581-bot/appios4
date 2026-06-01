import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_info_model.dart';
import '../services/device_service.dart';
import '../services/storage_service.dart';

final deviceHardwareProvider = FutureProvider<DeviceHardwareInfo>((ref) async {
  return await DeviceService.getHardwareInfo();
});

final optimizationResultProvider = FutureProvider<OptimizationResult?>((ref) async {
  final hardwareAsyncValue = ref.watch(deviceHardwareProvider);
  if (hardwareAsyncValue.hasValue) {
    final result = await DeviceService.analyzeDevice(hardwareAsyncValue.value!);
    // Lưu lịch sử sau khi phân tích thành công
    await StorageService.saveHistory(AnalysisHistory(
      timestamp: DateTime.now(),
      deviceModel: hardwareAsyncValue.value!.modelName,
      performanceScore: result.performanceScore,
      profileName: result.recommendedProfile.profileName,
    ));
    return result;
  }
  return null;
});
