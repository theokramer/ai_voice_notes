import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Singleton service for optimized audio recording
/// Pre-warms system resources to eliminate first-tap delays
class RecordingService {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  // Cached resources
  String? _tempDirectoryPath;
  PermissionStatus? _cachedPermissionStatus;
  bool _isInitialized = false;

  /// Pre-warm the recording system during app initialization
  /// This eliminates delays on first recording
  Future<void> preWarm() async {
    if (_isInitialized) return;

    try {
      // Cache temp directory path (expensive I/O operation)
      final tempDir = await getTemporaryDirectory();
      _tempDirectoryPath = tempDir.path;

      // Cache permission status (no dialog shown, just checks)
      _cachedPermissionStatus = await Permission.microphone.status;

      _isInitialized = true;
      if (kDebugMode) {
        print('RecordingService pre-warmed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('RecordingService pre-warm failed: $e');
      }
      // Non-critical failure, continue anyway
    }
  }

  /// Start recording with optimized path
  /// Returns the recording path and whether recording actually started
  Future<RecordingStartResult> startRecording(AudioRecorder recorder) async {
    // Quick permission check using cache
    PermissionStatus status = _cachedPermissionStatus ?? PermissionStatus.denied;
    
    // If not granted, request (will show dialog if needed)
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      _cachedPermissionStatus = status; // Update cache
    }

    if (status != PermissionStatus.granted) {
      return RecordingStartResult(
        success: false,
        errorType: status.isPermanentlyDenied 
            ? RecordingErrorType.permissionDeniedPermanently
            : RecordingErrorType.permissionDenied,
      );
    }

    try {
      // Use cached temp directory or fetch if not available
      final tempPath = _tempDirectoryPath ?? (await getTemporaryDirectory()).path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final recordingPath = '$tempPath/recording_$timestamp.m4a';

      await recorder.start(
        const RecordConfig(),
        path: recordingPath,
      );

      return RecordingStartResult(
        success: true,
        recordingPath: recordingPath,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Recording start failed: $e');
      }
      return RecordingStartResult(
        success: false,
        errorType: RecordingErrorType.recordingFailed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stop recording
  Future<String?> stopRecording(AudioRecorder recorder) async {
    try {
      return await recorder.stop();
    } catch (e) {
      if (kDebugMode) {
        print('Recording stop failed: $e');
      }
      return null;
    }
  }

  /// Check if microphone permission is granted (uses cache)
  bool get hasPermission => _cachedPermissionStatus?.isGranted ?? false;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}

/// Result of starting a recording
class RecordingStartResult {
  final bool success;
  final String? recordingPath;
  final RecordingErrorType? errorType;
  final String? errorMessage;

  RecordingStartResult({
    required this.success,
    this.recordingPath,
    this.errorType,
    this.errorMessage,
  });
}

/// Types of recording errors
enum RecordingErrorType {
  permissionDenied,
  permissionDeniedPermanently,
  recordingFailed,
}

