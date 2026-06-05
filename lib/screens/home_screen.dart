import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/overlay_service.dart';

/// Màn hình chính — quản lý trạng thái floating overlay.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ──────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────
  final OverlayService _overlayService = OverlayService();
  bool _isOverlayActive = false;  // overlay đã được kích hoạt lần đầu
  bool _isOverlayVisible = false; // overlay đang hiện (sau khi activate)
  bool _isLoading = false;

  // Status message cuối cùng
  String? _statusMessage;
  bool _statusIsError = false;

  // ──────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  Future<void> _restoreState() async {
    final saved = await _overlayService.getSavedState();
    if (!mounted) return;
    setState(() {
      _isOverlayActive = saved;
      _isOverlayVisible = saved;
    });

    // Kiểm tra lại trạng thái thực tế từ native (nếu có)
    if (saved) {
      final actual = await _overlayService.getOverlayState();
      if (!mounted) return;
      setState(() {
        _isOverlayVisible = actual;
      });
    }
  }

  // ──────────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────────

  /// Lần đầu tiên kích hoạt overlay
  Future<void> _activateOverlay() async {
    setState(() => _isLoading = true);

    final result = await _overlayService.showOverlay();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _isOverlayActive = true;
        _isOverlayVisible = true;
        _setStatus('✅ Overlay đã được kích hoạt!', isError: false);
      } else {
        _setStatus(
          '❌ ${_friendlyError(result.errorCode, result.message)}',
          isError: true,
        );
      }
    });
  }

  /// Toggle ẩn/hiện overlay
  Future<void> _toggleOverlay() async {
    setState(() => _isLoading = true);

    final result = await _overlayService.toggleOverlay();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _isOverlayVisible = result.isVisible ?? !_isOverlayVisible;
        _setStatus(
          _isOverlayVisible
              ? '👁 Overlay đang hiển thị'
              : '🙈 Overlay đã ẩn',
          isError: false,
        );
      } else {
        _setStatus(
          '❌ ${_friendlyError(result.errorCode, result.errorMessage)}',
          isError: true,
        );
      }
    });
  }

  void _setStatus(String msg, {required bool isError}) {
    _statusMessage = msg;
    _statusIsError = isError;
  }

  /// Dịch mã lỗi sang tiếng Việt thân thiện
  String _friendlyError(String? code, String? message) {
    switch (code) {
      case 'MISSING_PLUGIN':
        return 'Plugin chưa khả dụng. Hãy build và cài qua TrollStore trên thiết bị iOS thật.';
      case 'WINDOW_LEVEL_DENIED':
        return 'Hệ thống không cho phép overlay ở cấp cao nhất trên iOS này. Overlay vẫn hiển thị ở cấp thấp hơn.';
      case 'IOS_VERSION_UNSUPPORTED':
        return 'Tính năng này yêu cầu iOS 14.0 trở lên.';
      case 'PERMISSION_DENIED':
        return 'Không có quyền tạo cửa sổ nổi. Hãy cài qua TrollStore để có entitlements đầy đủ.';
      default:
        return message ?? 'Lỗi không xác định.';
    }
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Nền gradient
          _buildBackground(),

          // Nội dung chính
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildOverlayCard(),
                  const SizedBox(height: 24),
                  if (_isOverlayActive) ...[
                    _buildControlCard(),
                    const SizedBox(height: 24),
                  ],
                  if (_statusMessage != null) ...[
                    _buildStatusBanner(),
                    const SizedBox(height: 24),
                  ],
                  _buildInfoCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Widgets
  // ──────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.5),
          radius: 1.2,
          colors: [
            Color(0xFF2A1550),
            Color(0xFF0D0B16),
            Color(0xFF0D0B16),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App icon badge
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9D6AFA), Color(0xFFFA6AE3)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9D6AFA).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.layers_rounded,
            color: Colors.white,
            size: 32,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: -0.2, end: 0, curve: Curves.easeOut),

        const SizedBox(height: 20),

        Text(
          'Hà Nhạy VIP',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [Color(0xFF9D6AFA), Color(0xFFFA6AE3)],
                  ).createShader(
                    const Rect.fromLTWH(0, 0, 200, 50),
                  ),
              ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms)
            .slideX(begin: -0.1, end: 0),

        const SizedBox(height: 8),

        Text(
          'Floating Overlay • TrollStore',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7A6FA0),
                letterSpacing: 0.5,
              ),
        )
            .animate()
            .fadeIn(delay: 350.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildOverlayCard() {
    final bool activated = _isOverlayActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1730),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: activated
              ? const Color(0xFF9D6AFA).withOpacity(0.4)
              : const Color(0xFF2E2A45),
        ),
        boxShadow: activated
            ? [
                BoxShadow(
                  color: const Color(0xFF9D6AFA).withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(active: activated),
              const SizedBox(width: 12),
              Text(
                activated ? 'Overlay đang hoạt động' : 'Overlay chưa kích hoạt',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: activated
                      ? const Color(0xFF9D6AFA)
                      : const Color(0xFF6B6484),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            activated
                ? 'Cửa sổ nổi "Hà Nhạy VIP" đã được khởi chạy. Bạn có thể kéo thả và ẩn/hiện bất kỳ lúc nào.'
                : 'Nhấn nút bên dưới để kích hoạt cửa sổ nổi hiển thị "Hà Nhạy VIP" trên mọi ứng dụng.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),

          const SizedBox(height: 24),

          if (!activated)
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                onPressed: _isLoading ? null : _activateOverlay,
                isLoading: _isLoading,
                label: 'Kích hoạt Overlay',
                icon: Icons.add_circle_outline_rounded,
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildControlCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1730),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2E2A45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Điều khiển',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _GradientButton(
                  onPressed: _isLoading ? null : _toggleOverlay,
                  isLoading: _isLoading,
                  label: _isOverlayVisible ? 'Ẩn Overlay' : 'Hiện Overlay',
                  icon: _isOverlayVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  secondary: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOverlayPreview(),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 650.ms, duration: 500.ms)
        .slideY(begin: 0.08, end: 0);
  }

  Widget _buildOverlayPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0B16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2540)),
      ),
      child: Column(
        children: [
          Text(
            'Xem trước overlay:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Giả lập overlay widget
          AnimatedOpacity(
            opacity: _isOverlayVisible ? 1.0 : 0.2,
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xCC1E1B2E),
                    Color(0xCC2A1550),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF9D6AFA).withOpacity(0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D6AFA).withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Text(
                'Hà Nhạy VIP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusIsError
            ? const Color(0xFF2E1515)
            : const Color(0xFF152E15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusIsError
              ? const Color(0xFFFA6A6A).withOpacity(0.4)
              : const Color(0xFF6AFA9D).withOpacity(0.4),
        ),
      ),
      child: Text(
        _statusMessage!,
        style: TextStyle(
          fontSize: 14,
          color: _statusIsError
              ? const Color(0xFFFA6A6A)
              : const Color(0xFF6AFA9D),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1730),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E2A45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.4),
              ),
              const SizedBox(width: 8),
              Text(
                'Thông tin',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            icon: Icons.drag_indicator_rounded,
            text: 'Kéo thả overlay đến bất kỳ vị trí nào',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.save_alt_rounded,
            text: 'Vị trí được lưu tự động sau khi kéo',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.layers_rounded,
            text: 'Overlay hiển thị trên mọi ứng dụng',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.security_rounded,
            text: 'Không có chức năng hack, inject, hay đọc bộ nhớ',
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 500.ms);
  }
}

// ──────────────────────────────────────────────
// Helper Widgets
// ──────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? const Color(0xFF6AFA9D) : const Color(0xFF4A4565),
        boxShadow: active
            ? [
                BoxShadow(
                  color: const Color(0xFF6AFA9D).withOpacity(0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final IconData icon;
  final bool secondary;

  const _GradientButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.icon,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: secondary
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF9D6AFA), Color(0xFFFA6AE3)],
                  ),
            color: secondary ? const Color(0xFF2A2545) : null,
            borderRadius: BorderRadius.circular(16),
            border: secondary
                ? Border.all(color: const Color(0xFF9D6AFA).withOpacity(0.4))
                : null,
            boxShadow: secondary
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF9D6AFA).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF9D6AFA).withOpacity(0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A80A8),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
