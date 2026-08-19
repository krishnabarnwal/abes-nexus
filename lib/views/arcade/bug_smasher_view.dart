import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data ────────────────────────────────────────────────────────────────────
class _Bug {
  final int id;
  final IconData icon;
  final String label;
  final Color color;
  bool isAlive;
  Timer? expireTimer;

  _Bug({required this.id, required this.icon, required this.label, required this.color})
      : isAlive = true;
}

// ─── Game View ───────────────────────────────────────────────────────────────
class BugSmasherView extends StatefulWidget {
  const BugSmasherView({super.key});

  @override
  State<BugSmasherView> createState() => _BugSmasherViewState();
}

class _BugSmasherViewState extends State<BugSmasherView>
    with TickerProviderStateMixin {
  // -- Game State --
  bool _isWaiting = true;
  bool _isPlaying = false;
  bool _isGameOver = false;

  // -- Timer --
  static const double _totalTime = 10.0;
  double _timeLeft = _totalTime;
  Timer? _countdownTimer;
  Timer? _spawnTimer;

  // -- Score --
  int _score = 0;
  int _taps = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;

  // -- Grid (3x3, index 0-8) --
  final Map<int, _Bug> _activeBugs = {};
  int _bugIdCounter = 0;
  final Random _random = Random();

  // -- Tile Animation Controllers (9 tiles) --
  final List<AnimationController> _tileControllers = [];
  final List<Animation<double>> _tileScales = [];

  // -- Bug Data --
  static const _bugTypes = [
    (Icons.bug_report, 'NULL_PTR', Color(0xFFFF3333)),
    (Icons.code, '404_ERR', Color(0xFFFF5500)),
    (Icons.warning_amber, 'FATAL', Color(0xFFFF8800)),
    (Icons.error_outline, 'STACK_OVF', Color(0xFFFF3333)),
    (Icons.block, 'SEGFAULT', Color(0xFFFF5500)),
    (Icons.dangerous, 'MEM_LEAK', Color(0xFFFF8800)),
  ];

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    for (int i = 0; i < 9; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
      );
      _tileControllers.add(ctrl);
      _tileScales.add(Tween<double>(begin: 1.0, end: 0.85).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      ));
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _highScore = prefs.getInt('bug_smasher_high_score') ?? 0);
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bug_smasher_high_score', _highScore);
  }

  // ── Game Control ──────────────────────────────────────────────────────────
  void _startGame() {
    setState(() {
      _isWaiting = false;
      _isPlaying = true;
      _isGameOver = false;
      _timeLeft = _totalTime;
      _score = 0;
      _taps = 0;
      _combo = 0;
      _maxCombo = 0;
      _isNewHighScore = false;
      _activeBugs.clear();
    });
    _startCountdown();
    _startSpawner();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() => _timeLeft = (_timeLeft - 0.1).clamp(0.0, _totalTime));
      if (_timeLeft <= 0.001) {
        t.cancel();
        _endGame();
      }
    });
  }

  void _startSpawner() {
    _spawnTimer?.cancel();
    _scheduleNextSpawn();
  }

  void _scheduleNextSpawn() {
    if (!_isPlaying) return;
    final delay = 600 + _random.nextInt(200); // 600–800 ms
    Future.delayed(Duration(milliseconds: delay), () {
      if (!_isPlaying || !mounted) return;
      _spawnBugs();
      _scheduleNextSpawn();
    });
  }

  void _spawnBugs() {
    final count = _random.nextBool() ? 1 : 2;
    final available = List.generate(9, (i) => i).where((i) => !_activeBugs.containsKey(i)).toList()..shuffle();
    final toSpawn = available.take(count);

    for (final idx in toSpawn) {
      final type = _bugTypes[_random.nextInt(_bugTypes.length)];
      final bug = _Bug(id: _bugIdCounter++, icon: type.$1, label: type.$2, color: type.$3);
      setState(() => _activeBugs[idx] = bug);

      // Auto-expire after 1.2s
      bug.expireTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted || !_isPlaying) return;
        if (_activeBugs[idx]?.id == bug.id) {
          setState(() {
            _activeBugs.remove(idx);
            _combo = 0; // missed bug resets combo
          });
        }
      });
    }
  }

  void _endGame() {
    _spawnTimer?.cancel();
    for (final bug in _activeBugs.values) {
      bug.expireTimer?.cancel();
    }
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _activeBugs.clear();
      if (_score > _highScore) {
        _highScore = _score;
        _isNewHighScore = true;
        _saveHighScore();
      }
    });
  }

  // ── Tap Handler ───────────────────────────────────────────────────────────
  Future<void> _onTileTap(int index) async {
    if (!_isPlaying) return;
    _taps++;

    if (_activeBugs.containsKey(index)) {
      // Hit!
      HapticFeedback.mediumImpact();
      _activeBugs[index]!.expireTimer?.cancel();
      _activeBugs.remove(index);

      // Animate tile
      await _tileControllers[index].forward();
      if (mounted) await _tileControllers[index].reverse();

      setState(() {
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _score += _combo >= 3 ? 2 : 1; // bonus for combos
      });
    } else {
      // Miss — reset combo
      HapticFeedback.lightImpact();
      setState(() => _combo = 0);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _spawnTimer?.cancel();
    for (final bug in _activeBugs.values) {
      bug.expireTimer?.cancel();
    }
    for (final ctrl in _tileControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accuracy = _taps == 0 ? 0 : ((_score / _taps) * 100).round();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('🐛 Bug Smasher', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('$_highScore', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildGameBody(),
          if (_isWaiting) _buildStartOverlay(),
          if (_isGameOver) _buildGameOverOverlay(accuracy),
        ],
      ),
    );
  }

  Widget _buildGameBody() {
    final progress = _timeLeft / _totalTime;
    final timeColor = _timeLeft <= 3.0
        ? const Color(0xFFFF3333)
        : _timeLeft <= 6.0
            ? Colors.orange
            : const Color(0xFF39FF14);

    return Column(
      children: [
        // ── HUD ────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              // Timer Text + Score
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timer
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TIME', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                      const SizedBox(height: 2),
                      Text(
                        '${_timeLeft.toStringAsFixed(1)}s',
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          shadows: [Shadow(color: timeColor.withValues(alpha: 0.6), blurRadius: 12)],
                        ),
                      ),
                    ],
                  ),
                  // Score + Combo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text('SCORE ', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                          Text('$_score', style: const TextStyle(color: Color(0xFF39FF14), fontSize: 28, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      if (_combo >= 2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                          ),
                          child: Text('🔥 x$_combo Combo!', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      else
                        const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(timeColor),
                ),
              ),
            ],
          ),
        ),

        // ── Grid ───────────────────────────────────────────────────────────
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) => _buildTile(index),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(int index) {
    final bug = _activeBugs[index];
    final hasBug = bug != null;

    return ScaleTransition(
      scale: _tileScales[index],
      child: GestureDetector(
        onTap: () => _onTileTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: hasBug ? bug.color.withValues(alpha: 0.18) : const Color(0xFF1E293B),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: hasBug ? bug.color.withValues(alpha: 0.7) : const Color(0xFF334155),
              width: hasBug ? 2.0 : 1.0,
            ),
            boxShadow: hasBug
                ? [BoxShadow(color: bug.color.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 2)]
                : const [],
          ),
          child: hasBug
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(bug.icon, color: bug.color, size: 32),
                    const SizedBox(height: 6),
                    Text(
                      bug.label,
                      style: TextStyle(color: bug.color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  // ── Overlays ──────────────────────────────────────────────────────────────
  Widget _buildStartOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xF21E293B),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          border: Border.all(color: const Color(0x40FF3333), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐛', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('10-Second Bug Smasher', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Squash as many compilation errors\nas possible before time runs out!',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0x20FF8800),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Text('💡 Rapid taps build combos for bonus points!', style: TextStyle(color: Colors.orange, fontSize: 11), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x2639FF14),
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  border: Border.all(color: const Color(0xFF39FF14), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x3039FF14), blurRadius: 16)],
                ),
                child: const Text('TAP TO START', style: TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Best: $_highScore bugs', style: const TextStyle(color: Colors.amber, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(int accuracy) {
    final accuracy2 = _taps == 0 ? 0 : ((_score / _taps) * 100).round();
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
            const Text("Time's Up! ⏱️", style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            // Stats Row
            Row(
              children: [
                _statCard('🐛\nSmashed', '$_score', const Color(0xFF39FF14)),
                const SizedBox(width: 8),
                _statCard('🎯\nAccuracy', '$accuracy2%', Colors.blueAccent),
                const SizedBox(width: 8),
                _statCard('🔥\nMax Combo', 'x$_maxCombo', Colors.orange),
              ],
            ),
            if (_isNewHighScore) ...[
              const SizedBox(height: 16),
              _NewRecordBanner(),
            ],
            const SizedBox(height: 8),
            Text('Best: $_highScore bugs', style: const TextStyle(color: Colors.amber, fontSize: 13)),
            const SizedBox(height: 20),
            // Play Again button
            GestureDetector(
              onTap: _startGame,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x2639FF14),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  border: Border.all(color: const Color(0xFF39FF14), width: 1.5),
                ),
                child: const Center(child: Text('⟳  Play Again', style: TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.w900, fontSize: 16))),
              ),
            ),
            const SizedBox(height: 10),
            // Back button
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

  Widget _statCard(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// ─── Flashing New Record Banner ───────────────────────────────────────────────
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
        margin: const EdgeInsets.only(top: 4, bottom: 4),
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
