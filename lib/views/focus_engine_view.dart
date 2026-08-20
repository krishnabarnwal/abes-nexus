import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ui_kit.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Zen Pomodoro Focus Engine
// ═══════════════════════════════════════════════════════════════════════════

class FocusEngineView extends StatefulWidget {
  const FocusEngineView({super.key});

  @override
  State<FocusEngineView> createState() => _FocusEngineViewState();
}

class _FocusEngineViewState extends State<FocusEngineView>
    with TickerProviderStateMixin {

  // ── Mode config ────────────────────────────────────────────────────────
  static const _modes = [
    _ModeConfig('DEEP WORK',   25, Color(0xFF39FF14), '25m'),
    _ModeConfig('BRAIN REST',   5, Color(0xFF00F0FF), '5m'),
    _ModeConfig('LONG BREAK',  15, Color(0xFF00F0FF), '15m'),
  ];

  int _modeIndex = 0;
  _ModeConfig get _mode => _modes[_modeIndex];

  // ── Timer state ────────────────────────────────────────────────────────
  late int _timeLeftSec;
  late int _totalSec;
  bool _isRunning = false;
  Timer? _ticker;

  // ── Animation controllers ──────────────────────────────────────────────
  late AnimationController _ringCtrl;   // smooth ring interpolation (60fps)
  late AnimationController _pulseCtrl;  // breathing heartbeat
  late Animation<double> _pulseAnim;
  double _ringProgress = 1.0;           // 1.0 = full, 0.0 = empty
  double _ringTarget  = 1.0;

  // ── Stats ──────────────────────────────────────────────────────────────
  int _todaySessions   = 0;
  int _todayMinutes    = 0;

  @override
  void initState() {
    super.initState();
    _resetTimer(notify: false);
    _loadStats();

    // 60fps ring animation
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..addListener(() {
        setState(() {
          _ringProgress = _ringCtrl.value;
        });
      });

    // Breathing pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────
  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    setState(() {
      _todaySessions = prefs.getInt('focus_sessions_$today') ?? 0;
      _todayMinutes  = prefs.getInt('focus_minutes_$today')  ?? 0;
    });
  }

  Future<void> _saveSession(int minutesCompleted) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    _todaySessions++;
    _todayMinutes += minutesCompleted;
    await prefs.setInt('focus_sessions_$today', _todaySessions);
    await prefs.setInt('focus_minutes_$today',  _todayMinutes);
    setState(() {});
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
  }

  // ── Timer logic ────────────────────────────────────────────────────────
  void _resetTimer({bool notify = true}) {
    _ticker?.cancel();
    final dur = _modes[_modeIndex].durationMin * 60;
    if (notify) {
      setState(() {
        _timeLeftSec = dur;
        _totalSec    = dur;
        _isRunning   = false;
        _ringTarget  = 1.0;
      });
      _animateRingTo(1.0);
    } else {
      _timeLeftSec = dur;
      _totalSec    = dur;
      _isRunning   = false;
      _ringTarget  = 1.0;
      _ringProgress = 1.0;
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    HapticFeedback.heavyImpact();
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeLeftSec > 0) {
          _timeLeftSec--;
          final newProgress = _timeLeftSec / _totalSec;
          _animateRingTo(newProgress);
        } else {
          _onComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _animateRingTo(double target) {
    _ringCtrl.stop();
    _ringCtrl.value = _ringProgress;
    _ringTarget = target;
    // Tween from current to target in 950ms
    final tween = Tween<double>(begin: _ringProgress, end: target);
    _ringCtrl.value = 0.0;
    late AnimationController temp;
    temp = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
    final anim = tween.animate(CurvedAnimation(parent: temp, curve: Curves.easeInOut));
    anim.addListener(() {
      if (mounted) setState(() => _ringProgress = anim.value);
    });
    temp.forward().then((_) => temp.dispose());
  }

  void _onComplete() {
    _ticker?.cancel();
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.vibrate());
    Future.delayed(const Duration(milliseconds: 300), () => HapticFeedback.heavyImpact());

    final completedMin = _mode.durationMin;
    setState(() => _isRunning = false);

    if (_mode.label == 'DEEP WORK') {
      _saveSession(completedMin);
    }

    if (mounted) {
      showToast(
        context,
        _mode.label == 'DEEP WORK'
            ? '🎯 Focus session complete! Take a break.'
            : '⚡ Break over! Ready to focus?',
        type: _mode.label == 'DEEP WORK' ? ToastType.success : ToastType.cyan,
      );
    }

    _resetTimer();
  }

  // ── Mode switch ────────────────────────────────────────────────────────
  void _switchMode(int index) {
    if (_isRunning) return;
    setState(() => _modeIndex = index);
    _resetTimer();
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  String get _timeString {
    final m = _timeLeftSec ~/ 60;
    final s = _timeLeftSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _focusHours {
    if (_todayMinutes < 60) return '$_todayMinutes min';
    final h = _todayMinutes ~/ 60;
    final m = _todayMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = _mode.accent;

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Mode selector row ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: List.generate(_modes.length, (i) {
                  final selected = _modeIndex == i;
                  final mAccent = _modes[i].accent;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                      child: SquishCard(
                        onTap: () => _switchMode(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? mAccent.withValues(alpha: 0.15)
                                : const Color(0xFF1E293B).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? mAccent.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.08),
                              width: selected ? 1.5 : 1.0,
                            ),
                            boxShadow: selected
                                ? [BoxShadow(color: mAccent.withValues(alpha: 0.3), blurRadius: 12)]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              _modes[i].tag,
                              style: TextStyle(
                                color: selected ? mAccent : Colors.white38,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Zen Ring ────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (ctx, constraints) {
                  final size = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth * 0.82
                      : constraints.maxHeight * 0.82;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ring painter
                        CustomPaint(
                          size: Size(size, size),
                          painter: _ZenRingPainter(
                            progress: _ringProgress,
                            accent: accent,
                          ),
                        ),
                        // Center text with pulse
                        _isRunning
                            ? ScaleTransition(
                                scale: _pulseAnim,
                                child: _centerContent(accent),
                              )
                            : _centerContent(accent),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // ── Main action button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SquishCard(
                onTap: _toggleTimer,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: _isRunning
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isRunning ? Colors.redAccent : accent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRunning ? Colors.redAccent : accent)
                            .withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _isRunning ? '⏸  PAUSE' : (_timeLeftSec == _totalSec ? '⚡  INITIALIZE FOCUS' : '▶  RESUME'),
                      style: TextStyle(
                        color: _isRunning ? Colors.redAccent : accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Reset button ─────────────────────────────────────────────
            if (_timeLeftSec < _totalSec)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SquishCard(
                  onTap: _resetTimer,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Center(
                      child: Text('↺  RESET', style: TextStyle(color: Colors.white38, fontSize: 14, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Stats card ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                borderRadius: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('🎯', 'Today\'s Focus', _focusHours),
                    Container(width: 1, height: 36, color: Colors.white12),
                    _statItem('✅', 'Sessions', '$_todaySessions'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerContent(Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _timeString,
          style: TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            shadows: [
              Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 24),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Text(
            _mode.label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String emoji, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Mode Config
// ═══════════════════════════════════════════════════════════════════════════
class _ModeConfig {
  final String label;
  final int durationMin;
  final Color accent;
  final String tag;
  const _ModeConfig(this.label, this.durationMin, this.accent, this.tag);
}

// ═══════════════════════════════════════════════════════════════════════════
// Zen Ring CustomPainter
// ═══════════════════════════════════════════════════════════════════════════
class _ZenRingPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final Color accent;

  const _ZenRingPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const strokeWidth = 14.0;
    const startAngle = -pi / 2; // top
    final sweepAngle = 2 * pi * progress;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── 1. Track background ─────────────────────────────────────────────
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = const Color(0xFF1E293B).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0.001) return;

    // ── 2. Glow shadow arc ──────────────────────────────────────────────
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

    // ── 3. Gradient progress arc ────────────────────────────────────────
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        accent.withValues(alpha: 0.6),
        accent,
      ],
      tileMode: TileMode.clamp,
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);

    // ── 4. Leading tip glow dot ─────────────────────────────────────────
    final tipAngle = startAngle + sweepAngle;
    final tipX = center.dx + radius * cos(tipAngle);
    final tipY = center.dy + radius * sin(tipAngle);

    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth / 2 + 3,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      Offset(tipX, tipY),
      strokeWidth / 2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ZenRingPainter old) =>
      old.progress != progress || old.accent != accent;
}
