import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ui_kit.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Zen Pomodoro Focus Engine  +  Daily Task Board
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
    _ModeConfig('DEEP WORK',  25, Color(0xFF39FF14), '25m'),
    _ModeConfig('BRAIN REST',  5, Color(0xFF00F0FF), '5m'),
    _ModeConfig('LONG BREAK', 15, Color(0xFF00F0FF), '15m'),
  ];

  int _modeIndex = 0;
  _ModeConfig get _mode => _modes[_modeIndex];

  // ── Timer state ────────────────────────────────────────────────────────
  late int _timeLeftSec;
  late int _totalSec;
  bool _isRunning = false;
  Timer? _ticker;

  // ── Animation controllers ──────────────────────────────────────────────
  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  double _ringProgress = 1.0;

  // ── Stats ──────────────────────────────────────────────────────────────
  int _todaySessions = 0;
  int _todayMinutes  = 0;

  // ── Task Board ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _tasks = [];
  final TextEditingController _taskCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _resetTimer(notify: false);
    _loadStats();
    _loadTasks();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

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
    _taskCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Stats persistence ──────────────────────────────────────────────────
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
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  // ── Task persistence ───────────────────────────────────────────────────
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('focus_tasks') ?? '[]';
    final decoded = jsonDecode(raw) as List<dynamic>;
    setState(() {
      _tasks = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('focus_tasks', jsonEncode(_tasks));
  }

  void _addTask(String title) {
    if (title.trim().isEmpty) return;
    setState(() {
      _tasks.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'title': title.trim(),
        'isCompleted': false,
      });
    });
    _taskCtrl.clear();
    _saveTasks();
  }

  void _toggleTask(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _tasks[index]['isCompleted'] = !(_tasks[index]['isCompleted'] as bool);
    });
    _saveTasks();
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((t) => t['id'] == id));
    _saveTasks();
    if (mounted) {
      showToast(context, 'Objective deleted', type: ToastType.error);
    }
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
      });
      _animateRingTo(1.0);
    } else {
      _timeLeftSec  = dur;
      _totalSec     = dur;
      _isRunning    = false;
      _ringProgress = 1.0;
    }
  }

  void _toggleTimer() => _isRunning ? _pauseTimer() : _startTimer();

  void _startTimer() {
    HapticFeedback.heavyImpact();
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeLeftSec > 0) {
          _timeLeftSec--;
          _animateRingTo(_timeLeftSec / _totalSec);
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
    final tween = Tween<double>(begin: _ringProgress, end: target);
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
    if (_mode.label == 'DEEP WORK') _saveSession(completedMin);
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

  int get _completedCount => _tasks.where((t) => t['isCompleted'] == true).length;

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = _mode.accent;

    return Container(
      color: Colors.transparent,
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildTimerSection(accent)),
          SliverToBoxAdapter(child: _buildTaskSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // nav clearance
        ],
      ),
    );
  }

  // ── Timer section (above the fold) ────────────────────────────────────
  Widget _buildTimerSection(Color accent) {
    final screenH = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenH * 0.82,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Mode selector
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

            // Zen ring
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (ctx, constraints) {
                  final size = (constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight) *
                      0.82;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(size, size),
                          painter: _ZenRingPainter(progress: _ringProgress, accent: accent),
                        ),
                        _isRunning
                            ? ScaleTransition(scale: _pulseAnim, child: _centerContent(accent))
                            : _centerContent(accent),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Main CTA
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
                        color: (_isRunning ? Colors.redAccent : accent).withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _isRunning
                          ? '⏸  PAUSE'
                          : (_timeLeftSec == _totalSec ? '⚡  INITIALIZE FOCUS' : '▶  RESUME'),
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

            const SizedBox(height: 10),

            // Reset (conditional)
            if (_timeLeftSec < _totalSec)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SquishCard(
                  onTap: _resetTimer,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Center(
                      child: Text('↺  RESET', style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // Stats card
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                borderRadius: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('🎯', "Today's Focus", _focusHours),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _statItem('✅', 'Sessions', '$_todaySessions'),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _statItem('📋', 'Tasks Done', '$_completedCount/${_tasks.length}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Task Board section ─────────────────────────────────────────────────
  Widget _buildTaskSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              const Text(
                'Daily Objectives 🎯',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (_tasks.isNotEmpty)
                Text(
                  '$_completedCount/${_tasks.length} done',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Input field
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            borderRadius: 16,
            child: Row(
              children: [
                const Icon(Icons.add_task, color: Color(0xFF39FF14), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _taskCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: const Color(0xFF39FF14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Add a new task...',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                    ),
                    onSubmitted: _addTask,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                GestureDetector(
                  onTap: () => _addTask(_taskCtrl.text),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF14).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.5)),
                    ),
                    child: const Text('ADD', style: TextStyle(color: Color(0xFF39FF14), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Task list
          if (_tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const Text('📋', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    const Text(
                      'No objectives yet.\nAdd one above to get started!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white30, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _tasks.length,
              itemBuilder: (context, index) => _buildTaskItem(index),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(int index) {
    final task      = _tasks[index];
    final id        = task['id'] as String;
    final title     = task['title'] as String;
    final completed = task['isCompleted'] as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteTask(id),
        background: _buildDismissBackground(),
        child: SquishCard(
          onTap: () => _toggleTask(index),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: 14,
            child: Row(
              children: [
                // Check / circle icon
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: completed
                      ? const Icon(Icons.check_circle, color: Color(0xFF39FF14), size: 24, key: ValueKey('done'))
                      : Icon(Icons.circle_outlined, color: Colors.white.withValues(alpha: 0.25), size: 24, key: const ValueKey('todo')),
                ),
                const SizedBox(width: 14),

                // Task title with animated strikethrough
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: completed ? Colors.white.withValues(alpha: 0.45) : Colors.white,
                      fontSize: 14,
                      fontWeight: completed ? FontWeight.normal : FontWeight.w500,
                      decoration: completed ? TextDecoration.lineThrough : TextDecoration.none,
                      decorationColor: const Color(0xFF39FF14),
                      decorationThickness: 1.8,
                    ),
                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),

                const SizedBox(width: 8),

                // Swipe hint
                Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.15), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x00FF3333), Color(0xCCFF3333)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF3333).withValues(alpha: 0.6)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Delete', style: TextStyle(color: Color(0xFFFF3333), fontSize: 13, fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Icon(Icons.delete_sweep, color: Color(0xFFFF3333), size: 22),
        ],
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────
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
            shadows: [Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 24)],
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
            style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.5),
          ),
        ),
      ],
    );
  }

  Widget _statItem(String emoji, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
  final double progress;
  final Color accent;

  const _ZenRingPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    const strokeWidth = 14.0;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect, 0, 2 * pi, false,
      Paint()
        ..color = const Color(0xFF1E293B).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0.001) return;

    // Glow
    canvas.drawArc(
      rect, startAngle, sweepAngle, false,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Gradient arc
    canvas.drawArc(
      rect, startAngle, sweepAngle, false,
      Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [accent.withValues(alpha: 0.6), accent],
          tileMode: TileMode.clamp,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Tip glow dot
    final tipAngle = startAngle + sweepAngle;
    final tipX = center.dx + radius * cos(tipAngle);
    final tipY = center.dy + radius * sin(tipAngle);
    canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2 + 3,
        Paint()..color = Colors.white.withValues(alpha: 0.9)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ZenRingPainter old) =>
      old.progress != progress || old.accent != accent;
}
