import 'dart:convert';

/// Model representing a recording that failed transcription
class FailedRecording {
  final String id;
  final String audioPath; // Permanent path in app documents directory
  final DateTime timestamp;
  final String? errorMessage;
  final String? folderContext; // Folder user was viewing when recording
  final Duration? recordingDuration; // Original recording duration

  FailedRecording({
    required this.id,
    required this.audioPath,
    required this.timestamp,
    this.errorMessage,
    this.folderContext,
    this.recordingDuration,
  });

  /// Create a copy with updated fields
  FailedRecording copyWith({
    String? id,
    String? audioPath,
    DateTime? timestamp,
    String? errorMessage,
    String? folderContext,
    Duration? recordingDuration,
  }) {
    return FailedRecording(
      id: id ?? this.id,
      audioPath: audioPath ?? this.audioPath,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
      folderContext: folderContext ?? this.folderContext,
      recordingDuration: recordingDuration ?? this.recordingDuration,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audioPath': audioPath,
      'timestamp': timestamp.toIso8601String(),
      'errorMessage': errorMessage,
      'folderContext': folderContext,
      'recordingDuration': recordingDuration?.inMilliseconds,
    };
  }

  /// Create from JSON
  factory FailedRecording.fromJson(Map<String, dynamic> json) {
    return FailedRecording(
      id: json['id'] as String,
      audioPath: json['audioPath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      errorMessage: json['errorMessage'] as String?,
      folderContext: json['folderContext'] as String?,
      recordingDuration: json['recordingDuration'] != null
          ? Duration(milliseconds: json['recordingDuration'] as int)
          : null,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory FailedRecording.fromJsonString(String jsonString) =>
      FailedRecording.fromJson(jsonDecode(jsonString));

  /// Get a formatted timestamp string
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get a formatted duration string
  String get formattedDuration {
    if (recordingDuration == null) return 'Unknown duration';
    
    final minutes = recordingDuration!.inMinutes;
    final seconds = recordingDuration!.inSeconds % 60;
    
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${seconds}s';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FailedRecording && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
