import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'providers/notes_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/folders_provider.dart';
import 'services/connectivity_service.dart';
import 'services/recording_queue_service.dart';
import 'services/superwall_event_delegate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Configure Superwall
  final superwallApiKey = dotenv.env['SUPERWALL_API_KEY'] ?? '';
  if (kDebugMode) {
    debugPrint('🔑 Superwall API Key loaded: ${superwallApiKey.isEmpty ? "EMPTY" : "Present (${superwallApiKey.length} chars)"}');
  }

  if (superwallApiKey.isNotEmpty) {
    if (kDebugMode) {
      debugPrint('⚙️ Configuring Superwall...');
    }
    
    Superwall.configure(superwallApiKey);
    
    // Set up event delegate for payment cancellation detection
    Superwall.shared.setDelegate(SuperwallEventDelegate.instance);
    
    if (kDebugMode) {
      debugPrint('✅ Superwall configured with SuperwallEventDelegate');
      debugPrint('📋 Payment cancellation detection active');
      debugPrint('   Events being monitored:');
      debugPrint('   - transactionAborted (payment cancelled)');
      debugPrint('   - transactionFail (payment failed)');
      debugPrint('   - paywallDecline (paywall declined)');
      debugPrint('   When user cancels Apple Payment Sheet → Second paywall appears');
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
  } else {
    if (kDebugMode) {
      debugPrint('❌ Warning: SUPERWALL_API_KEY not found in environment variables');
    }
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => NotesProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => FoldersProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => RecordingQueueService(),
        ),
        ChangeNotifierProvider(
          create: (context) => ConnectivityService(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Nota AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildTheme(settingsProvider.settings.themePreset),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
