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
import 'services/failed_recordings_service.dart';
import 'services/superwall_event_delegate.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables with error handling
  String? envError;
  try {
    await dotenv.load(fileName: ".env");
    
    // Validate that required keys are present
    final openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    final superwallKey = dotenv.env['SUPERWALL_API_KEY'] ?? '';
    
    if (openAIKey.isEmpty || openAIKey == 'your_openai_api_key_here') {
      envError = 'OpenAI API key is missing or not configured.\n\nPlease create a .env file with your API keys.\nSee ENV_TEMPLATE.md for instructions.';
    } else if (superwallKey.isEmpty || superwallKey == 'your_superwall_api_key_here') {
      envError = 'Superwall API key is missing or not configured.\n\nPlease create a .env file with your API keys.\nSee ENV_TEMPLATE.md for instructions.';
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error loading .env file: $e');
    }
    envError = '.env file not found.\n\nPlease create a .env file in the project root with your API keys.\nSee ENV_TEMPLATE.md for instructions.';
  }

  // Configure Superwall if no errors
  if (envError == null) {
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

  // Initialize services
  if (envError == null) {
    await FailedRecordingsService().initialize();
  }

  runApp(MainApp(envError: envError));
}

class MainApp extends StatelessWidget {
  final String? envError;
  
  const MainApp({super.key, this.envError});

  @override
  Widget build(BuildContext context) {
    // If there's an environment error, show error screen
    if (envError != null) {
      return MaterialApp(
        title: 'Notie AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: _EnvironmentErrorScreen(error: envError!),
      );
    }

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
          create: (context) => FailedRecordingsService(),
        ),
        ChangeNotifierProvider(
          create: (context) => ConnectivityService(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Notie AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildTheme(settingsProvider.settings.themePreset),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class _EnvironmentErrorScreen extends StatelessWidget {
  final String error;

  const _EnvironmentErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 80,
                  color: Colors.amber,
                ),
                const SizedBox(height: AppTheme.spacing24),
                const Text(
                  'Configuration Required',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing16),
                Text(
                  error,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacing32),
                const Text(
                  'Steps to fix:',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                const Text(
                  '1. Copy .env.example to .env\n'
                  '2. Add your OpenAI API key\n'
                  '3. Add your Superwall API key\n'
                  '4. Restart the app',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
