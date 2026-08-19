import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'packet_jumper_view.dart';
import 'bug_smasher_view.dart';
import 'server_ping_view.dart';

class GamesHubView extends StatefulWidget {
  const GamesHubView({super.key});

  @override
  State<GamesHubView> createState() => _GamesHubViewState();
}

class _GamesHubViewState extends State<GamesHubView> {
  int _packetJumperHighScore = 0;
  int _bugSmasherHighScore = 0;
  int _serverPingHighScore = 0;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _packetJumperHighScore = prefs.getInt('packet_jumper_high_score') ?? 0;
      _bugSmasherHighScore = prefs.getInt('bug_smasher_high_score') ?? 0;
      _serverPingHighScore = prefs.getInt('server_ping_high_score') ?? 0;
    });
  }

  Future<void> _refreshScores() async {
    await _loadScores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: CustomScrollView(
        slivers: [
          // --- Glassmorphism Header ---
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E293B).withValues(alpha: 0.95),
                    const Color(0xFF0F172A).withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF39FF14).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.4)),
                    ),
                    child: const Text('??', style: TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Campus Arcade',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No Wi-Fi? No Problem.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // --- Section Header ---
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('AVAILABLE GAMES', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.5)),
            ),
          ),

          // --- Wi-Fi Packet Jumper Card ---
          SliverToBoxAdapter(
            child: _GameCard(
              title: 'Wi-Fi Packet Jumper',
              subtitle: 'Dodge 404 errors and loading spinners. How far can your packet travel?',
              emoji: '??',
              accentColor: const Color(0xFF0EA5E9),
              highScore: _packetJumperHighScore,
              onPlay: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PacketJumperView()));
                _refreshScores();
              },
            ),
          ),

          // --- Bug Smasher Card (now active) ---
          SliverToBoxAdapter(
            child: _GameCard(
              title: '10-Second Bug Smasher',
              subtitle: 'Squash NULL_PTR, FATAL, and 404 errors before time runs out!',
              emoji: '🐛',
              accentColor: const Color(0xFFFF3333),
              highScore: _bugSmasherHighScore,
              onPlay: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const BugSmasherView()));
                _refreshScores();
              },
            ),
          ),

          // --- Server Ping Card (now active) ---
          SliverToBoxAdapter(
            child: _GameCard(
              title: 'Server Ping',
              subtitle: 'Watch the radar sweep — tap PING the instant it hits the cyan sector!',
              emoji: '📡',
              accentColor: const Color(0xFF00F0FF),
              highScore: _serverPingHighScore,
              onPlay: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerPingView()));
                _refreshScores();
              },
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// -- Active Game Card ----------------------------------------------------------
class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final Color accentColor;
  final int highScore;
  final VoidCallback onPlay;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.accentColor,
    required this.highScore,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // High Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                      const SizedBox(width: 5),
                      Text('Best: $highScore', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                // Play Button
                ElevatedButton(
                  onPressed: onPlay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF39FF14),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    elevation: 0,
                    shadowColor: const Color(0xFF39FF14),
                  ),
                  child: const Text('PLAY NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
