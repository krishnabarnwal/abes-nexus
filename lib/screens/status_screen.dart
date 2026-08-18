import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final online = await _authService.isInternetActive();
    if (mounted) {
      setState(() {
        _isOnline = online;
        _isLoading = false;
      });
    }
  }

  Future<void> _reconnect() async {
    setState(() => _isLoading = true);
    final online = await _authService.isInternetActive();
    if (!online) {
      await _authService.authenticate();
    }
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ABES Net Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Icon(
                _isOnline ? Icons.check_circle : Icons.wifi_off,
                color: _isOnline ? Colors.green : Colors.red,
                size: 100,
              ),
            const SizedBox(height: 24),
            Text(
              _isOnline ? 'Internet is Active' : 'Captive Portal Detected',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isLoading ? null : _reconnect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Manual Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}
