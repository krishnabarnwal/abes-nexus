import 'dart:io';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class AuthService {
  static const String probeUrl = 'http://www.gstatic.com/generate_204';
  static const String loginUrl = 'https://192.168.1.254:8090/login.xml'; 

  final StorageService _storageService = StorageService();

  /// Probes the network. Returns true if internet is active (204), 
  /// false if it redirects (e.g., 302, captive portal blocking).
  Future<bool> isInternetActive() async {
    try {
      final response = await http.get(Uri.parse(probeUrl));
      if (response.statusCode == 204) {
        return true; // Unrestricted internet access
      }
      return false; // Captured/Redirected
    } catch (e) {
      print('Probe Error: $e');
      return false;
    }
  }

  /// Attempts to authenticate with the captive portal using saved credentials
  Future<bool> authenticate() async {
    final creds = await _storageService.getCredentials();
    final username = creds['username'];
    final password = creds['password'];

    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      print('Credentials not found.');
      return false;
    }

    try {
      // Overriding globally to ignore bad certificates since captive portals often use self-signed certs
      HttpOverrides.global = _MyHttpOverrides();

      final response = await http.post(
        Uri.parse(loginUrl),
        body: {
          'mode': '191',
          'username': username,
          'password': password,
        },
      );
      
      print('Auth Response Status: ${response.statusCode}');
      
      // We can also run the probe again to verify success
      return await isInternetActive();
    } catch (e) {
      print('Auth Error: $e');
      return false;
    }
  }
}

class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
