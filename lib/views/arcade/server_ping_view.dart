import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Server Ping View ────────────────────────────────────────────────────────
class ServerPingView extends StatefulWidget {
  const ServerPingView({super.key});

  @override
  State<ServerPingView> createState() => _ServerPingViewState();
}

class _ServerPingViewState extends State<ServerPingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  // ── Game state
  bool _isWaiting = true;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // ── Score
  int _streak = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;

  // ── Difficulty
  double _sectorDeg = 60.0;   // width of target arc in degrees
  double _speedFactor = 1.0;  // multiplier for speed

  static const double _baseDurationMs = 3000.0;
  static const double _minSectorDeg = 18.0;
  static const double _minDurationMs = 800.0;

  // ── Target sector (radians)
  double _sectorStart = 0.0;
  double _sectorEnd = 0.0;

  // ── Hit flash
  bool _showHitFlash = false;
  bool _showMissFlash = false;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _sweepController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _baseDurationMs.toInt()),
    )..addStatusListener(_onSweepLoop);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt('server_ping_high_score') ?? 0);
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('server_ping_high_score', _highScore);
  }

  // Detect when sweep completes a full rotation without a tap → game over
  void _onSweepLoop(AnimationStatus status) {
    if (!_isPlaying) return;
    if (status == AnimationStatus.completed) {
      // Full rotation without hitting → miss
      _triggerGameOver();
    }
  }

  // ── Start
  void _startGame() {
    _streak = 0;
    _sectorDeg = 60.0;
    _speedFactor = 1.0;
    _isNewHighScore = false;
    _placeSector();
    _sweepController.duration = Duration(milliseconds: _baseDurationMs.toInt());
    setState(() {
      _isWaiting = false;
      _isPlaying = true;
      _isGameOver = false;
      _showHitFlash = false;
      _showMissFlash = false;
    });
    _sweepController.repeat();
  }

  void _placeSector() {
    final start = _random.nextDouble() * 2 * pi;
    final widthRad = (_sectorDeg * pi) / 180.0;
    _sectorStart = start;
    _sectorEnd = start + widthRad;
  }

  // ── Ping (tap)
  void _onPing() {
    if (!_isPlaying) return;

    final sweepAngle = _sweepController.value * 2 * pi;
    final sectorEnd = _sectorEnd % (2 * pi);
    final sectorStart = _sectorStart % (2 * pi);
    final normalised = sweepAngle % (2 * pi);

    bool isHit;
    if (sectorEnd > sectorStart) {
      isHit = normalised >= sectorStart && normalised <= sectorEnd;
    } else {
      // wraps around 0
      isHit = normalised >= sectorStart || normalised <= sectorEnd;
    }

    if (isHit) {
      _onHit();
    } else {
      _triggerGameOver();
    }
  }

  void _onHit() {
    HapticFeedback.heavyImpact();
    setState(() {
      _streak++;
      _showHitFlash = true;
      _showMissFlash = false;
    });

    // Difficulty ramp
    _sectorDeg = (_sectorDeg - 3.0).clamp(_minSectorDeg, 60.0);
    _speedFactor += 0.12;
    final newDur = (_baseDurationMs / _speedFactor).clamp(_minDurationMs, _baseDurationMs);
    _sweepController.duration = Duration(milliseconds: newDur.toInt());

    // Reset rotation and place new sector
    _sweepController.repeat();
    _placeSector();

    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _showHitFlash = false);
    });
  }

  void _triggerGameOver() {
    if (!_isPlaying) return;
    HapticFeedback.vibrate();
    _sweepController.stop();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _showMissFlash = true;
      if (_streak > _highScore) {
        _highScore = _streak;
        _isNewHighScore = true;
        _saveHighScore();
      }
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showMissFlash = false);
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📡 Server Ping', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_tethering, color: Color(0xFF00F0FF), size: 15),
                  const SizedBox(width: 4),
                  Text('$_streak', style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 15),
                  const SizedBox(width: 4),
                  Text('$_highScore', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildGameBody(),
          if (_showHitFlash) _buildFlash(const Color(0x5000F0FF)),
          if (_showMissFlash) _buildFlash(const Color(0x50FF3333)),
          if (_isWaiting) _buildStartOverlay(),
          if (_isGameOver) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  Widget _buildGameBody() {
    return Column(
      children: [
        // ── Streak HUD strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          color: const Color(0xFF0F172A),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_tethering, color: Color(0xFF00F0FF), size: 18),
              const SizedBox(width: 8),
              Text(
                'Streak: $_streak',
                style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              if (_streak >= 3) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.5)),
                  ),
                  child: Text('LVL ${(_streak ~/ 3) + 1}', style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),

        // ── Radar
        Expanded(
          child: AnimatedBuilder(
            animation: _sweepController,
            builder: (context, child) {
              return CustomPaint(
                painter: _RadarPainter(
                  sweepValue: _isPlaying || _isGameOver ? _sweepController.value : 0.0,
                  sectorStart: _sectorStart,
                  sectorEnd: _sectorEnd,
                  sectorDeg: _sectorDeg,
                  isPlaying: _isPlaying,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),

        // ── PING Button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: GestureDetector(
            onTap: _onPing,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0x1500F0FF),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(
                  color: _isPlaying ? const Color(0xFF00F0FF) : const Color(0xFF334155),
                  width: 1.5,
                ),
                boxShadow: _isPlaying
                    ? const [BoxShadow(color: Color(0x4000F0FF), blurRadius: 20, spreadRadius: 2)]
                    : const [],
              ),
              child: Center(
                child: Text(
                  'PING ⚡',
                  style: TextStyle(
                    color: _isPlaying ? const Color(0xFF00F0FF) : const Color(0xFF334155),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlash(Color color) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _showHitFlash || _showMissFlash ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(color: color),
      ),
    );
  }

  Widget _buildStartOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xF21E293B),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: Border.all(color: const Color(0x4000F0FF), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📡', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('Server Ping', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Watch the radar sweep. When the line\nenters the glowing cyan sector — PING it!',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0x1500F0FF),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Text('⚠️ Miss or let it pass — Game Over!', style: TextStyle(color: Color(0xFF00F0FF), fontSize: 11), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x1500F0FF),
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x3000F0FF), blurRadius: 16)],
                ),
                child: const Text('LAUNCH RADAR', style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Best streak: $_highScore', style: const TextStyle(color: Colors.amber, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xF71E293B),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: Border.all(color: const Color(0x60FF3333), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 40)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Connection Dropped 🔌', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: [
                  const Text('MAX PING STREAK', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(
                    '$_streak',
                    style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 52, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            if (_isNewHighScore) ...[
              const SizedBox(height: 16),
              _NewRecordBanner(),
            ],
            const SizedBox(height: 8),
            Text('Best: $_highScore pings', style: const TextStyle(color: Colors.amber, fontSize: 13)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x1500F0FF),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
                ),
                child: const Center(child: Text('⟳  Reboot Server', style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.w900, fontSize: 16))),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                ),
                child: const Center(child: Text('Back to Arcade', style: TextStyle(color: Colors.white54, fontSize: 14))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Radar CustomPainter ──────────────────────────────────────────────────────
class _RadarPainter extends CustomPainter {
  final double sweepValue;  // 0.0 – 1.0
  final double sectorStart;
  final double sectorEnd;
  final double sectorDeg;
  final bool isPlaying;

  const _RadarPainter({
    required this.sweepValue,
    required this.sectorStart,
    required this.sectorEnd,
    required this.sectorDeg,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) * 0.42;

    // ── Background circle
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1E293B));

    // ── Concentric rings
    final ringPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, ringPaint);
    }

    // ── Cross-hair lines
    final crossPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    if (isPlaying) {
      // ── Target sector glow
      final sectorWidthRad = (sectorDeg * pi) / 180.0;
      final sectorGlowPaint = Paint()
        ..color = const Color(0x3000F0FF)
        ..style = PaintingStyle.fill;
      final sectorBorderPaint = Paint()
        ..color = const Color(0xCC00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final sectorRect = Rect.fromCircle(center: center, radius: radius);
      // Adjust: our sector is measured clockwise from top (like clock), not from right like math
      final drawStart = sectorStart - pi / 2;
      canvas.drawArc(sectorRect, drawStart, sectorWidthRad, true, sectorGlowPaint);
      canvas.drawArc(sectorRect, drawStart, sectorWidthRad, true, sectorBorderPaint);

      // Outer arc highlight
      final outerRect = Rect.fromCircle(center: center, radius: radius + 4);
      final arcHighlight = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(outerRect, drawStart, sectorWidthRad, false, arcHighlight);
    }

    // ── Sweep line trail (fading)
    final sweepAngle = sweepValue * 2 * pi - pi / 2; // start from top
    const trailCount = 24;
    for (int i = 0; i < trailCount; i++) {
      final frac = i / trailCount;
      final trailAngle = sweepAngle - frac * (pi / 2.5);
      final alpha = ((1.0 - frac) * 0.45).clamp(0.0, 1.0);
      final trailPaint = Paint()
        ..color = Color.fromRGBO(0, 240, 255, alpha)
        ..strokeWidth = 2.0;
      final dx = center.dx + radius * cos(trailAngle);
      final dy = center.dy + radius * sin(trailAngle);
      canvas.drawLine(center, Offset(dx, dy), trailPaint);
    }

    // ── Sweep line (main)
    final sweepPaint = Paint()
      ..color = const Color(0xFF00F0FF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final sweepDx = center.dx + radius * cos(sweepAngle);
    final sweepDy = center.dy + radius * sin(sweepAngle);
    canvas.drawLine(center, Offset(sweepDx, sweepDy), sweepPaint);

    // ── Center dot
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF00F0FF));
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);

    // ── Outer circle border
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweepValue != sweepValue ||
      old.sectorStart != sectorStart ||
      old.sectorEnd != sectorEnd ||
      old.isPlaying != isPlaying;
}

// ─── Flashing Record Banner ───────────────────────────────────────────────────
class _NewRecordBanner extends StatefulWidget {
  @override
  State<_NewRecordBanner> createState() => _NewRecordBannerState();
}

class _NewRecordBannerState extends State<_NewRecordBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0x26FFD700),
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.fromBorderSide(BorderSide(color: Colors.amber, width: 1.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Text('NEW RECORD!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
            SizedBox(width: 8),
            Text('🏆', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
