import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:workmanager/workmanager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
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

      await ioClient.post(
        Uri.parse('https://192.168.1.254:8090/login.xml'),
        body: {
          'username': savedId,
          'password': savedPassword,
        },
      );
      return true;
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
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white54,
        ),
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

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const VaultView(),
    const DashboardView(),
    const SpeedTestView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABES Nexus'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _views,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Vault',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'Campus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Network',
          ),
        ],
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
    final savedId = await _storage.read(key: 'abes_id');
    final savedPassword = await _storage.read(key: 'abes_password');

    if (savedId == null || savedPassword == null) {
      return;
    }

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
      final ioClient = IOClient(httpClient);

      final response = await ioClient.post(
        Uri.parse('https://192.168.1.254:8090/login.xml'),
        body: {
          'username': savedId,
          'password': savedPassword,
        },
      );

      setState(() {
        _statusMessage = 'Status: ${response.statusCode}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to encrypted storage')),
      );
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
                  child: const Column(
                    children: [
                      Text('Total Logins', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('42', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  child: const Column(
                    children: [
                      Text('Time Saved', style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('21 mins', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                    data: 'https://github.com/placeholder/abes_nexus',
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
                    Share.share('Download ABES Nexus: https://github.com/placeholder/abes_nexus');
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
        ],
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildCard('ABES ERP', Icons.school, 'https://ai-edunova.abes.ac.in/#/insync/dashboard/home'),
          _buildCard('LMS', Icons.menu_book, 'https://ai-edunova.abes.ac.in/#/insync/dashboard/home'),
          _buildCard('Student Portal', Icons.person_outline, 'https://ai-edunova.abes.ac.in/#/insync/dashboard/home'),
        ],
      ),
    );
  }

  Widget _buildCard(String title, IconData icon, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class SpeedTestView extends StatefulWidget {
  const SpeedTestView({super.key});

  @override
  State<SpeedTestView> createState() => _SpeedTestViewState();
}

class _SpeedTestViewState extends State<SpeedTestView> {
  String _downloadSpeed = '0.00';
  String _latency = '0';
  bool _isTesting = false;
  double _progress = 0.0;

  Future<void> _startTest() async {
    setState(() {
      _isTesting = true;
      _downloadSpeed = '0.00';
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Download Speed', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('$_downloadSpeed Mbps', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: const Color(0xFF0F172A),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
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