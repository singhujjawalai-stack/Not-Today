import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/not_today_item.dart';

class StorageService {
  static const _key = 'not_today_items';

  /// Released items older than this are dropped on every save to keep prefs
  /// compact. Six weeks gives the weekly review enough look-back window.
  static final _trimAge = const Duration(days: 60);

  Future<List<NotTodayItem>> loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString == null) return [];

      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => NotTodayItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt JSON — clear and start fresh.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      return [];
    }
  }

  Future<void> saveItems(List<NotTodayItem> items) async {
    // Trim released history older than _trimAge.
    final now = DateTime.now();
    final trimmed = items.where((item) {
      if (item.isParked) return true;
      if (item.releasedAt == null) return true;
      return now.difference(item.releasedAt!) < _trimAge;
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(trimmed.map((i) => i.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}