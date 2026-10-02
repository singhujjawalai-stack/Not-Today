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

/// The morning nudge's message for the items that resurfaced by [now].
///
/// Names the two that most recently came back, trails "… and N more" past
/// that, and always hands the permission back — the brand is calm, not
/// nagging. Kept pure (no plugin, no clock) so it's unit-testable (public
/// for that reason).
String buildNudgeBody(List<NotTodayItem> items, DateTime now) {
  final parked = items.where((i) => i.isParked).toList();
  final resurfaced = parked
      .where(
        (i) =>
            i.postponedUntil != null &&
            !i.postponedUntil!.isAfter(now),
      )
      .toList()
    ..sort((a, b) => b.postponedUntil!.compareTo(a.postponedUntil!));

  if (resurfaced.isEmpty) {
    return parked.isEmpty
        ? 'Nothing on the list today. Enjoy the quiet.'
        : 'Your parked things are still there. No pressure.';
  }

  final names = resurfaced.take(2).map((i) => i.text).toList();
  final more = resurfaced.length - names.length;
  final tail = more > 0 ? ' … and $more more' : '';
  return 'Back on the list: ${names.join(' and ')}$tail. Or not. No pressure.';
}

/// For manual testing: mimics what tomorrow morning's nudge will look like
/// when the scheduled notification fires.
String buildTestNudgeBody(List<NotTodayItem> items) {
  final parked = items.where((i) => i.isParked).toList();
  if (parked.isEmpty) {
    return 'Nothing on the list today. Enjoy the quiet.';
  }

  // Look for items postponed for tomorrow or already resurfaced.
  final tomorrowMorning = DateTime.now().add(const Duration(days: 1));
  final resurfacedTomorrow = parked
      .where(
        (i) =>
            i.postponedUntil != null &&
            !i.postponedUntil!.isAfter(tomorrowMorning),
      )
      .toList()
    ..sort((a, b) => b.postponedUntil!.compareTo(a.postponedUntil!));

  // If there are postponed items, name those; if none were postponed yet,
  // preview with the active parked items so the user can see real task names.
  final previewItems =
      resurfacedTomorrow.isNotEmpty ? resurfacedTomorrow : parked;
  final names = previewItems.take(2).map((i) => i.text).toList();
  final more = previewItems.length - names.length;
  final tail = more > 0 ? ' … and $more more' : '';
  return 'Back on the list: ${names.join(' and ')}$tail. Or not. No pressure.';
}

/// Schedules (or cancels) a single gentle daily nudge: when parked things
/// come back, "No pressure." The chosen time is stored in SharedPreferences
/// and re-applied on every launch, so a nudge set once keeps working even
/// across reboots (the OS holds the scheduled notification).
///
/// The body names up to two resurfaced items and is rebuilt whenever the
/// park list changes (via [setItems]) so the names stay current.
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

  NotificationDetails get _notificationDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
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
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
        ),
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
        await android.requestNotificationsPermission();
      }

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: false, sound: true);

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
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted != null) return granted;
        return await areNotificationsEnabled();
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
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
  /// Does NOT cancel + re-schedule the notification. On Android with inexact
  /// alarms, rapid cancel-then-reschedule can silently drop the alarm when the
  /// OS batches it. The notification body is baked at schedule time anyway, so
  /// re-scheduling just to refresh item names only risks losing the alarm — a
  /// stale body that still fires is vastly better than silence.
  void setItems(List<NotTodayItem> items) {
    _items = List.of(items);
  }

  Future<void> _apply(ReminderSettings settings) async {
    if (!_initialized) return;
    try {
      // Replace (not stack): cancel any pending nudge, then schedule fresh.
      await _plugin.cancel(id: _notificationId);
      if (!settings.enabled) return;

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
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Not Today',
        body: buildNudgeBody(_items, next),
        scheduledDate: next,
        notificationDetails: _notificationDetails,
        // Inexact, idle-tolerant — no exact-alarm permission needed, and a
        // nudge that's a few minutes late is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
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
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
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
        id: _notificationId + 1, // distinct id so it doesn't cancel the scheduled one
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