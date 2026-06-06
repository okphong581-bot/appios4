import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MethodChannel bridge đến iOS native
// ─────────────────────────────────────────────────────────────────────────────
const _channel = MethodChannel('ha.floating/overlay');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HaNhayApp());
}

class HaNhayApp extends StatelessWidget {
  const HaNhayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hà Nhạy VIP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0812),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9D6AFA),
          secondary: Color(0xFF33FF88),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isOverlayActive = false;
  bool _isLoading = false;
  String _statusMsg = 'Overlay chưa được kích hoạt';
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _syncState();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // Lấy trạng thái thực từ native
  Future<void> _syncState() async {
    try {
      final bool state =
          await _channel.invokeMethod('getOverlayState') as bool? ?? false;
      if (mounted) {
        setState(() {
          _isOverlayActive = state;
          _statusMsg = state ? '✅ Overlay đang nổi bên ngoài app' : 'Overlay chưa được kích hoạt';
        });
      }
    } catch (_) {}
  }

  // Bật overlay
  Future<void> _startMod() async {
    setState(() { _isLoading = true; });
    try {
      await _channel.invokeMethod('showOverlay');
      if (mounted) {
        setState(() {
          _isOverlayActive = true;
          _statusMsg = '✅ Overlay đang nổi bên ngoài app';
        });
        _showSnack('🚀 Overlay đã bật! Thoát ra ngoài app để thấy menu nổi.');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnack('❌ Lỗi: ${e.message}', isError: true);
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Tắt overlay
  Future<void> _stopMod() async {
    setState(() { _isLoading = true; });
    try {
      await _channel.invokeMethod('hideOverlay');
      if (mounted) {
        setState(() {
          _isOverlayActive = false;
          _statusMsg = 'Overlay đã tắt hoàn toàn';
        });
        _showSnack('⛔ Overlay đã dừng.');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        _showSnack('❌ Lỗi: ${e.message}', isError: true);
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red[800] : const Color(0xFF1E1133),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.4),
                radius: 1.2,
                colors: [Color(0xFF1A0E2E), Color(0xFF0A0812)],
              ),
            ),
          ),

          // Decorative blobs
          Positioned(top: -60, right: -60,
            child: _GlowBlob(color: const Color(0xFF9D6AFA), size: 220)),
          Positioned(bottom: -80, left: -60,
            child: _GlowBlob(color: const Color(0xFF33CCFF), size: 200)),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  // ── Header ──
                  _buildHeader(),
                  const SizedBox(height: 32),
                  // ── Status Card ──
                  _buildStatusCard(),
                  const SizedBox(height: 40),
                  // ── Main Button ──
                  _buildMainButton(),
                  const SizedBox(height: 20),
                  // ── Info text ──
                  _buildInfoText(),
                  const Spacer(),
                  // ── Footer ──
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────── Widgets ──────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon với glow
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _isOverlayActive ? _pulseAnim.value : 1.0,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF9D6AFA), Color(0xFF6A3DE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9D6AFA)
                        .withOpacity(_isOverlayActive ? 0.6 : 0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.layers_rounded,
                  size: 44, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hà Nhạy VIP',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'TrollStore Overlay Manager',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.45),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    final isOn = _isOverlayActive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF130E22),
        border: Border.all(
          color: isOn
              ? const Color(0xFF33FF88).withOpacity(0.5)
              : const Color(0xFF9D6AFA).withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn
                ? const Color(0xFF33FF88).withOpacity(0.08)
                : Colors.transparent,
            blurRadius: 20,
          )
        ],
      ),
      child: Row(
        children: [
          // Status dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? const Color(0xFF33FF88) : const Color(0xFF555555),
              boxShadow: isOn
                  ? [BoxShadow(
                      color: const Color(0xFF33FF88).withOpacity(0.7),
                      blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOn ? 'ĐANG HOẠT ĐỘNG' : 'CHƯA KÍCH HOẠT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: isOn
                        ? const Color(0xFF33FF88)
                        : Colors.white.withOpacity(0.35),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMsg,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    final isOn = _isOverlayActive;

    return GestureDetector(
      onTap: _isLoading ? null : (isOn ? _stopMod : _startMod),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isOn
                ? [const Color(0xFF8B0000), const Color(0xFFCC2222)]
                : [const Color(0xFF4A1FB8), const Color(0xFF9D6AFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isOn
                  ? const Color(0xFFCC2222).withOpacity(0.4)
                  : const Color(0xFF9D6AFA).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOn ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isOn ? 'STOP MOD' : 'START MOD',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInfoText() {
    if (!_isOverlayActive) {
      return Text(
        'Nhấn START MOD để hiển thị "Hà Nhạy VIP"\nnổi bên trên tất cả ứng dụng khác.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withOpacity(0.4),
          height: 1.6,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0F1D10),
        border: Border.all(color: const Color(0xFF33FF88).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF33FF88), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Thoát ra ngoài app để thấy menu nổi.\nVào lại app rồi nhấn STOP MOD để tắt.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withOpacity(0.65),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Yêu cầu TrollStore • iOS 14.0+',
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withOpacity(0.2),
        letterSpacing: 0.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decorative Glow Blob
// ─────────────────────────────────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.07),
      ),
    );
  }
}
