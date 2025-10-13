import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../models/folder.dart';

/// Service for exporting user data in various formats
class ExportService {
  /// Export all notes as JSON
  static Future<String> exportAsJSON({
    required List<Note> notes,
    required List<Folder> folders,
  }) async {
    final exportData = {
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'notes': notes.map((note) => note.toJson()).toList(),
      'folders': folders.map((folder) => folder.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Export notes as plain text (Markdown format)
  static Future<String> exportAsMarkdown({
    required List<Note> notes,
    required List<Folder> folders,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('# Nota AI - Notes Export');
    buffer.writeln('');
    buffer.writeln('Export Date: ${DateTime.now().toString()}');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');

    // Group notes by folder
    final folderMap = <String?, List<Note>>{};
    for (final note in notes) {
      if (!folderMap.containsKey(note.folderId)) {
        folderMap[note.folderId] = [];
      }
      folderMap[note.folderId]!.add(note);
    }

    // Export notes by folder
    for (final entry in folderMap.entries) {
      final folderId = entry.key;
      final folderNotes = entry.value;

      // Get folder info
      final folder = folderId != null
          ? folders.firstWhere((f) => f.id == folderId,
              orElse: () => Folder(
                    id: 'unknown',
                    name: 'Unorganized',
                    icon: '📂',
                    isSystem: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ))
          : Folder(
              id: 'unorganized',
              name: 'Unorganized',
              icon: '📂',
              isSystem: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

      buffer.writeln('## ${folder.icon} ${folder.name}');
      buffer.writeln('');

      for (final note in folderNotes) {
        buffer.writeln('### ${note.icon} ${note.name}');
        buffer.writeln('');
        buffer.writeln('**Created:** ${note.createdAt.toString()}');
        buffer.writeln('**Updated:** ${note.updatedAt.toString()}');

        if (note.tags.isNotEmpty) {
          buffer.writeln('**Tags:** ${note.tags.join(", ")}');
        }

        buffer.writeln('');
        buffer.writeln(_extractPlainText(note.content));
        buffer.writeln('');
        buffer.writeln('---');
        buffer.writeln('');
      }
    }

    return buffer.toString();
  }

  /// Export as CSV for spreadsheet apps
  static Future<String> exportAsCSV({
    required List<Note> notes,
    required List<Folder> folders,
  }) async {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('ID,Name,Icon,Folder,Content Preview,Tags,Created,Modified');

    // Rows
    for (final note in notes) {
      final folder = note.folderId != null
          ? folders.firstWhere((f) => f.id == note.folderId,
              orElse: () => Folder(
                    id: 'unknown',
                    name: 'Unorganized',
                    icon: '📂',
                    isSystem: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ))
          : null;

      final contentPreview = _extractPlainText(note.content)
          .replaceAll('\n', ' ')
          .replaceAll('"', '""');

      final row = [
        note.id,
        _escapeCSV(note.name),
        note.icon,
        folder?.name ?? 'Unorganized',
        _escapeCSV(contentPreview.substring(
            0, contentPreview.length > 200 ? 200 : contentPreview.length)),
        _escapeCSV(note.tags.join(', ')),
        note.createdAt.toIso8601String(),
        note.updatedAt.toIso8601String(),
      ].join(',');

      buffer.writeln(row);
    }

    return buffer.toString();
  }

  /// Helper to extract plain text from note content (handles Quill format)
  static String _extractPlainText(String content) {
    if (content.isEmpty) return '';

    try {
      // Try to parse as Quill Delta JSON
      final json = jsonDecode(content);
      if (json is List) {
        final buffer = StringBuffer();
        for (final op in json) {
          if (op is Map && op.containsKey('insert')) {
            final data = op['insert'];
            if (data is String) {
              buffer.write(data);
            }
          }
        }
        return buffer.toString();
      }
    } catch (e) {
      // Not JSON, return as-is
    }

    return content;
  }

  /// Escape CSV field
  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Share exported data
  static Future<void> shareExport({
    required String content,
    required String filename,
    required String mimeType,
    Rect? sharePositionOrigin,
  }) async {
    try {
      // Create temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);

      // Share the file with proper positioning for iPad
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: 'Nota AI - Data Export',
        text: 'Exported from Nota AI',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing export: $e');
      }
      rethrow;
    }
  }
  
  /// Export a single note as Markdown (human-readable)
  static Future<String> exportNoteAsMarkdown({
    required Note note,
    String? folderName,
  }) async {
    final buffer = StringBuffer();
    
    // Title
    buffer.writeln('# ${note.icon} ${note.name}');
    buffer.writeln('');
    
    // Metadata
    if (folderName != null) {
      buffer.writeln('**Folder:** $folderName');
    }
    buffer.writeln('**Created:** ${note.createdAt.toString().split('.')[0]}');
    buffer.writeln('**Updated:** ${note.updatedAt.toString().split('.')[0]}');
    
    if (note.tags.isNotEmpty) {
      buffer.writeln('**Tags:** ${note.tags.join(", ")}');
    }
    
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');
    
    // Content
    buffer.writeln(_extractPlainText(note.content));
    buffer.writeln('');
    
    return buffer.toString();
  }

  /// Save export to device
  static Future<File> saveExport({
    required String content,
    required String filename,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);
      return file;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving export: $e');
      }
      rethrow;
    }
  }
}

