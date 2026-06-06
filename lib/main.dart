import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ch = MethodChannel('ha.floating/overlay');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HaNhayApp());
}

class HaNhayApp extends StatelessWidget {
  const HaNhayApp({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
        title: 'Hà Nhạy VIP',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF09070F),
        ),
        home: const HomeScreen(),
      );
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _on = false;
  bool _busy = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final AnimationController _ring = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    _syncState();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ring.dispose();
    super.dispose();
  }

  Future<void> _syncState() async {
    try {
      final v = await _ch.invokeMethod<bool>('getOverlayState') ?? false;
      if (mounted) setState(() => _on = v);
      if (v) _ring.repeat();
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_on) {
        await _ch.invokeMethod('hideOverlay');
        _ring.stop();
        _ring.reset();
      } else {
        await _ch.invokeMethod('showOverlay');
        _ring.repeat();
      }
      setState(() => _on = !_on);
    } on PlatformException catch (e) {
      _snack('❌ ${e.message}', true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, [bool err = false]) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: err ? Colors.red[900] : const Color(0xFF1A1030),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        body: Stack(children: [
          // Background
          _Bg(on: _on),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                const SizedBox(height: 36),
                _Logo(pulse: _pulse, ring: _ring, on: _on),
                const SizedBox(height: 28),
                _StatusChip(on: _on),
                const SizedBox(height: 44),
                _BigButton(on: _on, busy: _busy, onTap: _toggle),
                const SizedBox(height: 20),
                _Hint(on: _on),
                const Spacer(),
                _Footer(on: _on),
                const SizedBox(height: 28),
              ]),
            ),
          ),
        ]),
      );
}

// ─── Background ───────────────────────────────────────────────────────────────
class _Bg extends StatelessWidget {
  final bool on;
  const _Bg({required this.on});
  @override
  Widget build(BuildContext ctx) => AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.3,
            colors: on
                ? [const Color(0xFF1E0A35), const Color(0xFF09070F)]
                : [const Color(0xFF110A22), const Color(0xFF09070F)],
          ),
        ),
      );
}

// ─── Logo / Icon ──────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  final AnimationController pulse, ring;
  final bool on;
  const _Logo({required this.pulse, required this.ring, required this.on});

  @override
  Widget build(BuildContext ctx) => AnimatedBuilder(
        animation: Listenable.merge([pulse, ring]),
        builder: (_, __) {
          final glow = on ? (0.4 + pulse.value * 0.3) : 0.25;
          return Column(children: [
            Stack(alignment: Alignment.center, children: [
              // Outer ring animation
              if (on)
                Transform.scale(
                  scale: 1.0 + ring.value * 0.35,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF9D6AFA)
                            .withOpacity(1.0 - ring.value),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              // Main icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: on
                        ? [const Color(0xFF9D6AFA), const Color(0xFF5A2DE0)]
                        : [const Color(0xFF3D2580), const Color(0xFF1E1240)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9D6AFA).withOpacity(glow),
                      blurRadius: 30,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: Icon(
                  on ? Icons.layers_rounded : Icons.layers_outlined,
                  size: 42,
                  color: Colors.white.withOpacity(on ? 1.0 : 0.5),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Text('Hà Nhạy VIP',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                  shadows: on
                      ? [Shadow(
                          color: const Color(0xFF9D6AFA).withOpacity(0.6),
                          blurRadius: 12)]
                      : null,
                )),
            const SizedBox(height: 5),
            Text('TrollStore Global Overlay',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 0.6,
                )),
          ]);
        },
      );
}

// ─── Status chip ──────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final bool on;
  const _StatusChip({required this.on});
  @override
  Widget build(BuildContext ctx) => AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF110E1F),
          border: Border.all(
            color: on
                ? const Color(0xFF33FF88).withOpacity(0.45)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(children: [
          // Pulsing dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? const Color(0xFF33FF88) : const Color(0xFF404040),
              boxShadow: on
                  ? [BoxShadow(
                      color: const Color(0xFF33FF88).withOpacity(0.7),
                      blurRadius: 7)]
                  : null,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                on ? 'OVERLAY ĐANG HOẠT ĐỘNG' : 'OVERLAY CHƯA BẬT',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: on
                      ? const Color(0xFF33FF88)
                      : Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                on
                    ? '"Hà Nhạy VIP" đang nổi bên trên tất cả app'
                    : 'Nhấn START MOD để kích hoạt overlay',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withOpacity(on ? 0.75 : 0.4),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ─── Big Button ───────────────────────────────────────────────────────────────
class _BigButton extends StatelessWidget {
  final bool on, busy;
  final VoidCallback onTap;
  const _BigButton({required this.on, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: on
                  ? [const Color(0xFF7A0000), const Color(0xFFBB1111)]
                  : [const Color(0xFF3D18AA), const Color(0xFF9D6AFA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (on ? const Color(0xFFBB1111) : const Color(0xFF9D6AFA))
                    .withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      on ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                      size: 34, color: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      on ? 'STOP MOD' : 'START MOD',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ]),
          ),
        ),
      );
}

// ─── Hint text ────────────────────────────────────────────────────────────────
class _Hint extends StatelessWidget {
  final bool on;
  const _Hint({required this.on});
  @override
  Widget build(BuildContext ctx) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: on
            ? Container(
                key: const ValueKey('on'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF0D1D0F),
                  border: Border.all(
                      color: const Color(0xFF33FF88).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF33FF88), size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Thoát app → menu vẫn nổi\nVào lại → nhấn STOP MOD để tắt',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.55,
                      ),
                    ),
                  ),
                ]),
              )
            : Text(
                key: const ValueKey('off'),
                'Nhấn START MOD → "Hà Nhạy VIP" sẽ nổi\nlên trên tất cả ứng dụng khác.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.white.withOpacity(0.35),
                  height: 1.6,
                ),
              ),
      );
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final bool on;
  const _Footer({required this.on});
  @override
  Widget build(BuildContext ctx) => Text(
        on ? '🟢 Overlay active — kéo để di chuyển' : 'Yêu cầu TrollStore · iOS 14+',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          color: on
              ? const Color(0xFF33FF88).withOpacity(0.6)
              : Colors.white.withOpacity(0.18),
        ),
      );
}
