import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:workmanager/workmanager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'views/arcade/games_hub_view.dart';
import 'views/focus_engine_view.dart';
import 'widgets/ui_kit.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.mobile)) {
        return false;
      }

      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final savedId = await storage.read(key: 'abes_id');
      final savedPassword = await storage.read(key: 'abes_password');

      if (savedId == null || savedPassword == null) {
        return false;
      }

      final httpClient = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final ioClient = IOClient(httpClient);

      final payload = 'mode=191&username=${Uri.encodeComponent(savedId)}&password=${Uri.encodeComponent(savedPassword)}';

      final response = await ioClient.post(
        Uri.parse('https://192.168.1.254:8090/login.xml'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      ).timeout(const Duration(seconds: 7));

      if (response.body.contains('<message><![CDATA[You have successfully logged in]]></message>')) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher);
  runApp(const AbesNetApp());
}

class AbesNetApp extends StatelessWidget {
  const AbesNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ABES Nexus',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF1E293B),
        fontFamily: 'Roboto',
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _bgCtrl;
  late Animation<Color?> _bgColor1;
  late Animation<Color?> _bgColor2;

  final List<Widget> _views = [
    const VaultView(),
    const DashboardView(),
    const SpeedTestView(),
    const GamesHubView(),
    const FocusEngineView(),
  ];

  static const _navItems = [
    (Icons.home_rounded, 'Vault'),
    (Icons.grid_view_rounded, 'Campus'),
    (Icons.speed_rounded, 'Network'),
    (Icons.videogame_asset_rounded, 'Arcade'),
    (Icons.center_focus_strong_rounded, 'Focus'),
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _bgColor1 = ColorTween(
      begin: const Color(0xFF0F172A),
      end: const Color(0xFF0B101E),
    ).animate(_bgCtrl);
    _bgColor2 = ColorTween(
      begin: const Color(0xFF0B101E),
      end: const Color(0xFF162238),
    ).animate(_bgCtrl);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          appBar: AppBar(
            title: const Text(
              'ABES Nexus',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.9),
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_bgColor1.value!, _bgColor2.value!],
              ),
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: _views,
            ),
          ),
          bottomNavigationBar: _buildFloatingNav(),
        );
      },
    );
  }

  Widget _buildFloatingNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                _navItems.length,
                (i) => _NavItem(
                  icon: _navItems[i].$1,
                  label: _navItems[i].$2,
                  isSelected: _currentIndex == i,
                  onTap: () => setState(() => _currentIndex = i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Floating Nav Item ────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF39FF14);
    const inactive = Color(0xFF64748B);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              transform: isSelected
                  ? (Matrix4.diagonal3Values(1.2, 1.2, 1.0))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              child: Icon(icon, color: isSelected ? active : inactive, size: 26),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? active : inactive,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 6 : 0,
              height: isSelected ? 6 : 0,
              decoration: const BoxDecoration(
                color: active,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x8039FF14), blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VaultView extends StatefulWidget {
  const VaultView({super.key});

  @override
  State<VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends State<VaultView> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String _statusMessage = 'Awaiting Credentials';
  int _totalLogins = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalLogins = prefs.getInt('total_logins') ?? 0;
    });

    try {
      final savedId = await _storage.read(key: 'abes_id');
      final savedPassword = await _storage.read(key: 'abes_password');

      if (savedId != null && savedPassword != null) {
        setState(() {
          _idController.text = savedId;
          _passwordController.text = savedPassword;
          _statusMessage = 'Credentials Loaded Securely';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Ready for setup';
      });
    }
  }

  Future<void> _loginToAbesWifi() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      if (mounted) {
        showToast(context, 'Timeout: Ensure Mobile Data is OFF and you are connected to the network.', type: ToastType.error);
      }
      return;
    }

    final savedId = await _storage.read(key: 'abes_id');
    final savedPassword = await _storage.read(key: 'abes_password');

    if (savedId == null || savedPassword == null) {
      if (mounted) {
        showToast(context, 'Please save credentials first', type: ToastType.error);
      }
      return;
    }

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final ioClient = IOClient(httpClient);

      final payload = 'mode=191&username=${Uri.encodeComponent(savedId)}&password=${Uri.encodeComponent(savedPassword)}';

      final response = await ioClient.post(
        Uri.parse('https://192.168.1.254:8090/login.xml'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      ).timeout(const Duration(seconds: 7));

      if (response.body.contains('<message><![CDATA[You have successfully logged in]]></message>')) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _totalLogins++;
          _statusMessage = 'Status: Logged In';
        });
        await prefs.setInt('total_logins', _totalLogins);
        
        if (mounted) {
          showToast(context, 'Wi-Fi Login Successful!', type: ToastType.success);
        }
      } else {
        setState(() {
          _statusMessage = 'Status: Failed / Max Logins Reached';
        });
        if (mounted) {
          showToast(context, 'Login Failed: Check credentials or network state.', type: ToastType.error);
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: Connection Timeout';
      });
      if (mounted) {
        showToast(context, 'Timeout: Ensure Mobile Data is OFF and you are connected to the network.', type: ToastType.error);
      }
    }
  }

  Future<void> _saveCredentials() async {
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both ID and Password';
      });
      return;
    }

    await _storage.write(key: 'abes_id', value: id);
    await _storage.write(key: 'abes_password', value: password);

    setState(() {
      _statusMessage = 'Credentials Saved Securely!';
    });

    if (mounted) {
      showToast(context, 'Credentials securely saved to Vault.', type: ToastType.success);
    }
  }

  Future<void> _launchLinkedIn() async {
    final url = Uri.parse('https://www.linkedin.com/in/krishna-kumar-barnwal-a90456390/');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _launchEmail() async {
    final url = Uri.parse('mailto:krishnaaaaa005@gmail.com');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Tracking row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('Total Logins', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('$_totalLogins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('Time Saved', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('${(_totalLogins * 0.5).toInt()} mins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Credentials Form
          TextField(
            controller: _idController,
            decoration: const InputDecoration(
              labelText: 'College ID / Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Save to Secure Vault', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loginToAbesWifi,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Test Wi-Fi Login', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Workmanager().registerPeriodicTask(
                'abes_wifi_task',
                'loginTask',
                constraints: Constraints(networkType: NetworkType.unmetered),
                frequency: const Duration(minutes: 15),
              );
              setState(() {
                _statusMessage = 'Background worker is active';
              });
              if (mounted) {
          showToast(context, 'Background engine enabled. Waiting for ABES network...', type: ToastType.info);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Enable Background Auto-Login', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 32),

          // Share Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Share ABES Nexus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: QrImageView(
                    data: 'https://github.com/krishnabarnwal/abes-nexus',
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Share App', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(text: 'Download ABES Nexus: https://github.com/krishnabarnwal/abes-nexus'));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Engineered by Krishna Kumar Barnwal',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.email, color: Colors.white),
                      onPressed: _launchEmail,
                      tooltip: 'Email',
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.white),
                      onPressed: _launchLinkedIn,
                      tooltip: 'LinkedIn',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final List<_CardData> _cards = const [
    _CardData('ABES ERP', Icons.school, 'https://erp.abes.ac.in/Login.aspx', Colors.blueAccent),
    _CardData('LMS', Icons.menu_book, 'https://ai-edunova.abes.ac.in/#/insync/dashboard/home', Colors.purpleAccent),
    _CardData('Student Portal', Icons.person_outline, 'https://ai-edunova.abes.ac.in/#/insync/dashboard/home', Colors.tealAccent),
    _CardData('ABES Official', Icons.account_balance, 'https://www.abes.ac.in/', Colors.orangeAccent),
    _CardData('ABES Quiz', Icons.quiz, 'https://abesquiz.netlify.app/', Color(0xFF39FF14)),
    _CardData('Official Email', Icons.email, 'mailto:info@abes.ac.in', Colors.redAccent),
  ];

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    final mode = urlString.startsWith('http')
        ? LaunchMode.inAppWebView
        : LaunchMode.externalApplication;
    if (!await launchUrl(url, mode: mode)) {
      debugPrint('Could not launch \$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, i) {
          final card = _cards[i];
          return StaggeredItem(
            index: i,
            delayMs: 70,
            child: SquishCard(
              onTap: () => _launchUrl(card.url),
              child: GlassCard(
                padding: EdgeInsets.zero,
                borderRadius: 18,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        card.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(card.icon, size: 32, color: card.accent),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        card.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardData {
  final String title;
  final IconData icon;
  final String url;
  final Color accent;
  const _CardData(this.title, this.icon, this.url, this.accent);
}

class SpeedTestView extends StatefulWidget {
  const SpeedTestView({super.key});

  @override
  State<SpeedTestView> createState() => _SpeedTestViewState();
}

class _SpeedTestViewState extends State<SpeedTestView> {
  String _downloadSpeed = '0.00';
  String _uploadSpeed = '0.00';
  String _latency = '0';
  bool _isTesting = false;
  double _progress = 0.0;

  Future<void> _startTest() async {
    setState(() {
      _isTesting = true;
      _downloadSpeed = '0.00';
      _uploadSpeed = '0.00';
      _latency = '0';
      _progress = 0.0;
    });

    final client = http.Client();
    try {
      // 1. Measure ping latency
      final stopwatch = Stopwatch()..start();
      await client.head(Uri.parse('https://www.google.com/generate_204'));
      stopwatch.stop();
      setState(() {
        _latency = stopwatch.elapsedMilliseconds.toString();
      });

      // 2. Measure download speed
      final request = http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=5000000'));
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 5000000;
      
      int bytesTransferred = 0;
      stopwatch.reset();
      stopwatch.start();

      await for (final chunk in response.stream) {
        bytesTransferred += chunk.length;
        final elapsed = stopwatch.elapsedMilliseconds;
        
        setState(() {
          _progress = (bytesTransferred / totalBytes).clamp(0.0, 1.0);
          if (elapsed > 0) {
            final secondsElapsed = elapsed / 1000.0;
            final mbps = (bytesTransferred * 8) / (secondsElapsed * 1000000);
            _downloadSpeed = mbps.toStringAsFixed(2);
          }
        });
      }
      stopwatch.stop();

      // 3. Measure upload speed
      setState(() {
        _progress = 0.5; // Indicate transition to upload phase
      });
      final payload = Uint8List(1000000); // 1MB payload
      stopwatch.reset();
      stopwatch.start();
      await http.post(
        Uri.parse('https://httpbin.org/post'),
        body: payload,
      );
      stopwatch.stop();
      final uploadElapsed = stopwatch.elapsedMilliseconds;
      if (uploadElapsed > 0) {
        final uploadSeconds = uploadElapsed / 1000.0;
        final uploadMbps = (1000000 * 8) / (uploadSeconds * 1000000);
        setState(() {
          _uploadSpeed = uploadMbps.toStringAsFixed(2);
        });
      }

    } catch (e) {
      debugPrint('Speed test error: $e');
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isTesting = false;
          _progress = 1.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Latency', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('$_latency ms', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('Download (Mbps)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(_downloadSpeed, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text('Upload (Mbps)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 8),
                        Text(_uploadSpeed, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: const Color(0xFF0F172A),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: _isTesting ? null : _startTest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                _isTesting ? 'Testing...' : 'Run Speed Test',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}