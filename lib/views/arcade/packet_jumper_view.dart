import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PacketJumperView extends StatefulWidget {
  const PacketJumperView({super.key});

  @override
  State<PacketJumperView> createState() => _PacketJumperViewState();
}

class _PacketJumperViewState extends State<PacketJumperView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // --- Physics ---
  static const double gravity = 0.0025;
  static const double jumpStrength = 0.055;
  static const double floorY = 0.0;

  double packetY = 0.0;
  double packetVelocity = 0.0;

  // --- Obstacles ---
  double obstacleX = 1.3;
  static const double obstacleWidth = 0.12;
  static const double obstacleHeight = 0.14;
  int _obstacleType = 0;
  final Random _random = Random();

  // --- Game State ---
  double gameSpeed = 0.008;
  int score = 0;
  int highScore = 0;
  bool isPlaying = false;
  bool isGameOver = false;
  bool isNewHighScore = false;

  static const double packetSize = 0.10;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_gameLoop);
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('packet_jumper_high_score') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('packet_jumper_high_score', highScore);
  }

  void _startGame() {
    setState(() {
      packetY = 0.0;
      packetVelocity = 0.0;
      obstacleX = 1.3;
      score = 0;
      gameSpeed = 0.008;
      isPlaying = true;
      isGameOver = false;
      isNewHighScore = false;
      _obstacleType = _random.nextInt(2);
    });
    _controller.repeat();
  }

  void _jump() {
    if (!isPlaying || isGameOver) return;
    if (packetY <= floorY + 0.005) {
      setState(() {
        packetVelocity = jumpStrength;
      });
    }
  }

  void _gameLoop() {
    if (!isPlaying || isGameOver) return;
    setState(() {
      packetVelocity -= gravity;
      packetY += packetVelocity;
      if (packetY <= floorY) {
        packetY = floorY;
        packetVelocity = 0.0;
      }
      obstacleX -= gameSpeed;
      if (obstacleX < -obstacleWidth - 0.05) {
        obstacleX = 1.3;
        score++;
        _obstacleType = _random.nextInt(2);
        gameSpeed = (0.008 + score * 0.0003).clamp(0.008, 0.026);
      }
      const double packetLeft = 0.12;
      const double packetRight = packetLeft + packetSize;
      final double packetBottom = packetY;
      final double packetTop = packetY + packetSize;
      final double obsLeft = obstacleX + 0.01;
      final double obsRight = obstacleX + obstacleWidth - 0.01;
      const double obsBottom = 0.0;
      const double obsTop = obstacleHeight;
      final bool xOverlap = packetRight > obsLeft && packetLeft < obsRight;
      final bool yOverlap = packetTop > obsBottom && packetBottom < obsTop;
      if (xOverlap && yOverlap) {
        isGameOver = true;
        isPlaying = false;
        _controller.stop();
        if (score > highScore) {
          highScore = score;
          isNewHighScore = true;
          _saveHighScore();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Wi-Fi Packet Jumper', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text('$highScore', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (!isPlaying && !isGameOver) {
            _startGame();
          } else if (isPlaying) {
            _jump();
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final floorPx = h * 0.80;
            final gameAreaH = floorPx;
            final packetLeftPx = w * 0.12;
            final packetSizePx = w * packetSize;
            final packetTopPx = floorPx - packetSizePx - (packetY * gameAreaH);
            final obsLeftPx = obstacleX * w;
            final obsWidthPx = obstacleWidth * w;
            final obsHeightPx = obstacleHeight * gameAreaH;
            final obsTopPx = floorPx - obsHeightPx;
            return Stack(
              children: [
                CustomPaint(size: Size(w, h), painter: _StarfieldPainter()),
                Positioned(
                  top: floorPx,
                  left: 0, right: 0,
                  child: Container(
                    height: h - floorPx,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: floorPx,
                  left: 0, right: 0,
                  child: Container(height: 2, color: const Color(0x990EA5E9)),
                ),
                Positioned(
                  top: 12, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xCC1E293B),
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        border: Border.fromBorderSide(BorderSide(color: Color(0x660EA5E9))),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi, color: Color(0xFF0EA5E9), size: 18),
                          const SizedBox(width: 8),
                          Text('Packets: $score',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isPlaying || isGameOver)
                  Positioned(
                    top: obsTopPx, left: obsLeftPx,
                    width: obsWidthPx, height: obsHeightPx,
                    child: _obstacleType == 0
                      ? Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Color(0x80DC2626), blurRadius: 12)],
                          ),
                          child: const Center(child: Text('404', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16))),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Color(0x80D97706), blurRadius: 12)],
                          ),
                          child: const Center(child: Icon(Icons.hourglass_top, color: Colors.white, size: 28)),
                        ),
                  ),
                if (isPlaying || isGameOver)
                  Positioned(
                    top: packetTopPx, left: packetLeftPx,
                    width: packetSizePx, height: packetSizePx,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Color(0xB30EA5E9), blurRadius: 16, spreadRadius: 2)],
                      ),
                      child: const Center(child: Icon(Icons.wifi, color: Colors.white, size: 22)),
                    ),
                  ),
                if (!isPlaying && !isGameOver) _buildStartOverlay(),
                if (isGameOver) _buildGameOverOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStartOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xF21E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x660EA5E9), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi, color: Color(0xFF0EA5E9), size: 64),
            const SizedBox(height: 16),
            const Text('Wi-Fi Packet Jumper', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Dodge 404s & loading spinners!', style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0x2639FF14),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF39FF14), width: 1.5),
              ),
              child: const Text('TAP TO LAUNCH', style: TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
            ),
            const SizedBox(height: 16),
            Text('Best: $highScore packets', style: const TextStyle(color: Colors.amber, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xF71E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x80DC2626), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.redAccent, size: 56),
            const SizedBox(height: 12),
            const Text('Connection Dropped!', style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  const Text('FINAL SCORE', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text('$score', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (isNewHighScore) ...[
              const SizedBox(height: 16),
              _NewHighScoreBadge(),
            ],
            const SizedBox(height: 8),
            Text('Best: $highScore', style: const TextStyle(color: Colors.amber, fontSize: 13)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x2639FF14),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF39FF14), width: 1.5),
                ),
                child: const Text('?  TAP TO REBOOT', style: TextStyle(color: Color(0xFF39FF14), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewHighScoreBadge extends StatefulWidget {
  @override
  State<_NewHighScoreBadge> createState() => _NewHighScoreBadgeState();
}

class _NewHighScoreBadgeState extends State<_NewHighScoreBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinker;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _blinker = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_blinker);
  }

  @override
  void dispose() {
    _blinker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0x26FFC107), // amber with ~15% alpha baked in
          borderRadius: BorderRadius.all(Radius.circular(20)),
          border: Border.fromBorderSide(BorderSide(color: Colors.amber, width: 1.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 16),
            SizedBox(width: 6),
            Text('NEW HIGH SCORE!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
            SizedBox(width: 6),
            Icon(Icons.star, color: Colors.amber, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x40FFFFFF);
    const stars = [
      Offset(0.05, 0.08), Offset(0.15, 0.22), Offset(0.28, 0.05),
      Offset(0.40, 0.18), Offset(0.55, 0.10), Offset(0.67, 0.27),
      Offset(0.78, 0.06), Offset(0.88, 0.20), Offset(0.93, 0.38),
      Offset(0.10, 0.42), Offset(0.22, 0.55), Offset(0.35, 0.67),
      Offset(0.48, 0.52), Offset(0.60, 0.63), Offset(0.72, 0.48),
      Offset(0.82, 0.70), Offset(0.18, 0.75), Offset(0.42, 0.80),
    ];
    for (final s in stars) {
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height * 0.85), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
