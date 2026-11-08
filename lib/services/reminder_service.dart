import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/not_today_item.dart';

/// Where and when the daily nudge fires.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;
}

/// The morning nudge's message for the items due back on [fireAt]'s calendar
/// day.
///
/// Only items whose "Not today" return time falls on that day are named, so
/// the nudge never re-announces something that came back days ago. Names the
/// two with the latest return time, trails "… and N more" past that, and
/// always hands the permission back — the brand is calm, not nagging. Kept
/// pure (no plugin, no clock) so it's unit-testable (public for that reason).
String buildNudgeBody(List<NotTodayItem> items, DateTime fireAt) {
  final parked = items.where((i) => i.isParked).toList();
  final returning = _returningOn(parked, fireAt);

  if (returning.isEmpty) {
    return parked.isEmpty
        ? 'Nothing on the list today. Enjoy the quiet.'
        : 'Your parked things are still there. No pressure.';
  }
  return _nudgeLine(returning);
}

/// For manual testing: mimics what tomorrow morning's nudge will look like
/// when the scheduled notification fires.
String buildTestNudgeBody(List<NotTodayItem> items) {
  final parked = items.where((i) => i.isParked).toList();
  if (parked.isEmpty) {
    return 'Nothing on the list today. Enjoy the quiet.';
  }

  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final returning = _returningOn(parked, tomorrow);

  // If something returns tomorrow, name it; otherwise preview with the active
  // parked items so the user can see real task names.
  return _nudgeLine(returning.isNotEmpty ? returning : parked);
}

/// Parked items whose return time lands on [day]'s calendar day, latest first.
List<NotTodayItem> _returningOn(List<NotTodayItem> parked, DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  return parked.where((i) {
    final until = i.postponedUntil;
    return until != null && !until.isBefore(start) && until.isBefore(end);
  }).toList()..sort((a, b) => b.postponedUntil!.compareTo(a.postponedUntil!));
}

String _nudgeLine(List<NotTodayItem> items) {
  final names = items.take(2).map((i) => i.text).toList();
  final more = items.length - names.length;
  final tail = more > 0 ? ' … and $more more' : '';
  return 'Back on the list: ${names.join(' and ')}$tail. Or not. No pressure.';
}

/// Schedules (or cancels) a single gentle daily nudge: when parked things
/// come back, "No pressure." The chosen time is stored in SharedPreferences
/// and re-applied on every launch, so a nudge set once keeps working even
/// across reboots (the OS holds the scheduled notification).
///
/// The body names up to two items returning on the fire day. Whenever the
/// park list changes, [setItems] re-schedules only if the body or time
/// actually changed, so names stay current without churning the alarm.
///
/// Notification permission is never requested at launch; the reminder sheet
/// asks when the user opts in.
///
/// Every platform call is wrapped in try/catch: on an unsupported platform,
/// in widget tests, or when the OS denies notifications, the app falls back
/// to no-op — parking a thing must never depend on a notification plugin.
class ReminderService {
  static const _enabledKey = 'reminder_enabled';
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';
  static const _notificationId = 42;

  static const String channelId = 'morning_nudge_channel';
  static const String channelName = 'Morning nudge';
  static const String channelDescription =
      'A quiet check-in when parked things come back.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// The live park list, so the nudge can name what actually came back.
  List<NotTodayItem> _items = [];

  /// Time + body of the currently scheduled nudge, so an item change only
  /// re-schedules when the notification would actually read differently.
  String? _lastScheduledKey;

  NotificationDetails get _notificationDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    ),
  );

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    // Timezone setup: safe fallback if local timezone cannot be identified.
    try {
      await _setupTimezone();
    } catch (e) {
      debugPrint('ReminderService timezone setup error: $e');
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          // Permission is requested from the reminder sheet, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await android.createNotificationChannel(channel);
      }

      _initialized = true;
      final settings = await load();
      await _apply(settings);
    } catch (e) {
      debugPrint('ReminderService initialize error: $e');
      // Unsupported platform or no plugin (tests): continue without it.
    }
  }

  /// Check whether notifications are currently allowed by the OS.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return (await android.areNotificationsEnabled()) ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Explicitly request notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      if (!_initialized) await initialize();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted != null) return granted;
        return await areNotificationsEnabled();
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 9,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  Future<void> update(ReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, settings.enabled);
    await prefs.setInt(_hourKey, settings.hour);
    await prefs.setInt(_minuteKey, settings.minute);
    await _apply(settings);
  }

  /// The park list changed — keep the nudge's names in step with it.
  ///
  /// Scheduling with the same notification id replaces the pending alarm, so
  /// no cancel is needed (cancel-then-reschedule can lose an inexact alarm on
  /// Android). Re-scheduling is skipped when the body and time are unchanged.
  Future<void> setItems(List<NotTodayItem> items) async {
    _items = List.of(items);
    if (!_initialized) return;
    await _apply(await load());
  }

  Future<void> _apply(ReminderSettings settings) async {
    if (!_initialized) return;
    try {
      if (!settings.enabled) {
        await _plugin.cancel(id: _notificationId);
        _lastScheduledKey = null;
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        settings.hour,
        settings.minute,
      );
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

      final body = buildNudgeBody(_items, next);
      final key = '${settings.hour}:${settings.minute}|$body';
      if (key == _lastScheduledKey) return;

      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Not Today',
        body: body,
        scheduledDate: next,
        notificationDetails: _notificationDetails,
        // Inexact, idle-tolerant — no exact-alarm permission needed, and a
        // nudge that's a few minutes late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      _lastScheduledKey = key;
    } catch (e) {
      debugPrint('ReminderService _apply error: $e');
      // Same as initialize: never take the app down over a nudge.
    }
  }

  /// Fire the nudge notification immediately — same title, body, and channel
  /// as the scheduled one. For manual testing.
  Future<bool> fireNow() async {
    if (kIsWeb) return false;
    if (!_initialized) {
      await initialize();
    }
    final allowed = await areNotificationsEnabled();
    if (!allowed) {
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('ReminderService: notification permission not granted');
        return false;
      }
    }

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await android.createNotificationChannel(channel);
      }
      await _plugin.show(
        id:
            _notificationId +
            1, // distinct id so it doesn't cancel the scheduled one
        title: 'Not Today',
        body: buildTestNudgeBody(_items),
        notificationDetails: _notificationDetails,
      );
      return true;
    } catch (e) {
      debugPrint('ReminderService fireNow error: $e');
      return false;
    }
  }

  Future<void> _setupTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
  }
}
