import 'package:workmanager/workmanager.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    
    final authService = AuthService();
    
    // Check connectivity
    final isOnline = await authService.isInternetActive();
    
    if (!isOnline) {
      print("Internet not active. Attempting authentication...");
      await authService.authenticate();
    } else {
      print("Internet is active. No action needed.");
    }
    
    // Re-enqueue the one-off task to keep probing on connectivity changes
    if (task == BackgroundService.networkTriggeredTask) {
      BackgroundService.registerNetworkTriggeredTask();
    }
    
    return Future.value(true);
  });
}

class BackgroundService {
  static const String periodicTask = "com.abesnet.periodicTask";
  static const String networkTriggeredTask = "com.abesnet.networkTriggeredTask";

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Enables notifications for debugging
    );
    
    // Register the 15-minute periodic task
    await Workmanager().registerPeriodicTask(
      "1",
      periodicTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when connected to a network (WiFi/Cellular)
      ),
    );
    
    // Register the initial network triggered task
    registerNetworkTriggeredTask();
  }
  
  static void registerNetworkTriggeredTask() {
    Workmanager().registerOneOffTask(
      "2",
      networkTriggeredTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
