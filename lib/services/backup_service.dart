import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/not_today_item.dart';

/// What a backup file held after parsing: the readable items and how many
/// entries were skipped as unreadable.
class BackupContents {
  const BackupContents({required this.items, required this.skipped});

  final List<NotTodayItem> items;
  final int skipped;
}

/// Export and restore the whole list as one small JSON file.
///
/// The format is versioned on purpose:
/// `{"app":"not-today","version":1,"exportedAt":…,"items":[…]}`
/// Bare arrays (the on-device storage format) restore fine too.
class BackupService {
  static const _version = 1;

  /// Save through the system dialog — the OS writes the bytes itself, so no
  /// storage permission is needed. Returns the saved file's Uri, or null if
  /// the user backed out.
  Future<Uri?> export(List<NotTodayItem> items) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}';
    final payload = jsonEncode({
      'app': 'not-today',
      'version': _version,
      'exportedAt': now.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    });
    return FilePicker.saveFile(
      fileName: 'not-today-backup-$stamp.json',
      bytes: Uint8List.fromList(utf8.encode(payload)),
      mimeType: 'application/json',
    );
  }

  /// Pick and parse a backup. Null means the user cancelled.
  /// Throws [FormatException] if the file isn't a backup at all.
  Future<BackupContents?> import() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null) return null;
    return parse(utf8.decode(await picked.readAsBytes()));
  }

  /// Pure: turn backup text into items, skipping unreadable records.
  static BackupContents parse(String source) {
    final decoded = jsonDecode(source);
    final List<dynamic> entries;
    if (decoded is List) {
      entries = decoded;
    } else if (decoded is Map && decoded['items'] is List) {
      entries = decoded['items'] as List<dynamic>;
    } else {
      throw const FormatException('Not a Not Today backup');
    }

    final items = <NotTodayItem>[];
    var skipped = 0;
    for (final entry in entries) {
      try {
        items.add(NotTodayItem.fromJson(entry as Map<String, dynamic>));
      } catch (_) {
        skipped++;
      }
    }
    return BackupContents(items: items, skipped: skipped);
  }

  /// Pure: fold a backup into the live list. Incoming wins on a shared id —
  /// it is what the user chose to restore — while purely local items keep
  /// their place and purely imported ones join at the end.
  static List<NotTodayItem> merge(
    List<NotTodayItem> existing,
    List<NotTodayItem> incoming,
  ) {
    final incomingById = {for (final item in incoming) item.id: item};
    final merged =
        existing.map((item) => incomingById[item.id] ?? item).toList();
    final knownIds = existing.map((i) => i.id).toSet();
    for (final item in incoming) {
      if (!knownIds.contains(item.id)) merged.add(item);
    }
    return merged;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
