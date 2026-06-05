import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client-side MethodChannel bridge giao tiếp với iOS native.
/// Channel name phải khớp với AppDelegate.swift.
class OverlayService {
  // ──────────────────────────────────────────────
  // Singleton
  // ──────────────────────────────────────────────
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  // ──────────────────────────────────────────────
  // MethodChannel
  // ──────────────────────────────────────────────
  static const MethodChannel _channel = MethodChannel('ha.floating/overlay');

  // ──────────────────────────────────────────────
  // SharedPreferences key
  // ──────────────────────────────────────────────
  static const String _kOverlayEnabled = 'overlay_enabled';

  // ──────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────

  /// Hiển thị overlay.
  /// Trả về [OverlayResult] với success/error.
  Future<OverlayResult> showOverlay() async {
    try {
      final result = await _channel.invokeMethod<String>('showOverlay');
      await _saveState(true);
      return OverlayResult.success(result ?? 'shown');
    } on PlatformException catch (e) {
      return OverlayResult.error(
        code: e.code,
        message: e.message ?? 'Không thể hiển thị overlay',
        details: e.details?.toString(),
      );
    } on MissingPluginException {
      return OverlayResult.error(
        code: 'MISSING_PLUGIN',
        message: 'Native plugin chưa được khởi tạo. Hãy chạy trên thiết bị iOS thật.',
      );
    } catch (e) {
      return OverlayResult.error(
        code: 'UNKNOWN',
        message: e.toString(),
      );
    }
  }

  /// Ẩn overlay.
  Future<OverlayResult> hideOverlay() async {
    try {
      final result = await _channel.invokeMethod<String>('hideOverlay');
      await _saveState(false);
      return OverlayResult.success(result ?? 'hidden');
    } on PlatformException catch (e) {
      return OverlayResult.error(
        code: e.code,
        message: e.message ?? 'Không thể ẩn overlay',
      );
    } on MissingPluginException {
      return OverlayResult.error(
        code: 'MISSING_PLUGIN',
        message: 'Native plugin chưa được khởi tạo.',
      );
    } catch (e) {
      return OverlayResult.error(
        code: 'UNKNOWN',
        message: e.toString(),
      );
    }
  }

  /// Toggle ẩn/hiện overlay.
  /// Trả về trạng thái mới (true = đang hiện).
  Future<OverlayToggleResult> toggleOverlay() async {
    try {
      final isVisible = await _channel.invokeMethod<bool>('toggleOverlay');
      final newState = isVisible ?? false;
      await _saveState(newState);
      return OverlayToggleResult.success(newState);
    } on PlatformException catch (e) {
      return OverlayToggleResult.error(
        code: e.code,
        message: e.message ?? 'Toggle thất bại',
      );
    } on MissingPluginException {
      return OverlayToggleResult.error(
        code: 'MISSING_PLUGIN',
        message: 'Native plugin chưa được khởi tạo.',
      );
    } catch (e) {
      return OverlayToggleResult.error(
        code: 'UNKNOWN',
        message: e.toString(),
      );
    }
  }

  /// Lấy trạng thái hiện tại của overlay từ native.
  Future<bool> getOverlayState() async {
    try {
      final isVisible = await _channel.invokeMethod<bool>('getOverlayState');
      return isVisible ?? false;
    } catch (_) {
      // Fallback về SharedPreferences nếu native không khả dụng
      return await _loadState();
    }
  }

  /// Lấy trạng thái đã lưu trong SharedPreferences.
  Future<bool> getSavedState() async {
    return await _loadState();
  }

  // ──────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────

  Future<void> _saveState(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOverlayEnabled, enabled);
    } catch (_) {
      // Bỏ qua lỗi persistence — không critical
    }
  }

  Future<bool> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kOverlayEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }
}

// ──────────────────────────────────────────────
// Result types
// ──────────────────────────────────────────────

class OverlayResult {
  final bool isSuccess;
  final String message;
  final String? errorCode;
  final String? errorDetails;

  const OverlayResult._({
    required this.isSuccess,
    required this.message,
    this.errorCode,
    this.errorDetails,
  });

  factory OverlayResult.success(String message) => OverlayResult._(
        isSuccess: true,
        message: message,
      );

  factory OverlayResult.error({
    required String code,
    required String message,
    String? details,
  }) =>
      OverlayResult._(
        isSuccess: false,
        message: message,
        errorCode: code,
        errorDetails: details,
      );
}

class OverlayToggleResult {
  final bool isSuccess;
  final bool? isVisible;
  final String? errorCode;
  final String? errorMessage;

  const OverlayToggleResult._({
    required this.isSuccess,
    this.isVisible,
    this.errorCode,
    this.errorMessage,
  });

  factory OverlayToggleResult.success(bool isVisible) => OverlayToggleResult._(
        isSuccess: true,
        isVisible: isVisible,
      );

  factory OverlayToggleResult.error({
    required String code,
    required String message,
  }) =>
      OverlayToggleResult._(
        isSuccess: false,
        errorCode: code,
        errorMessage: message,
      );
}
