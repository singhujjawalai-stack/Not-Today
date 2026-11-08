import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/not_today_item.dart';

class StorageService {
  static const _key = 'not_today_items';

  /// Released items older than 60 days are dropped on every save to keep
  /// prefs compact. That's far more history than the weekly review needs.
  static final _trimAge = const Duration(days: 60);

  Future<List<NotTodayItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(jsonString) as List<dynamic>;
    } catch (_) {
      // The payload itself is unreadable — clear it and start fresh.
      await prefs.remove(_key);
      return [];
    }

    // Recover per item: one bad record must not discard the whole list.
    final items = <NotTodayItem>[];
    for (final entry in decoded) {
      try {
        items.add(NotTodayItem.fromJson(entry as Map<String, dynamic>));
      } catch (e) {
        debugPrint('StorageService: skipping unreadable item: $e');
      }
    }
    return items;
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
