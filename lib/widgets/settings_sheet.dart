import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../services/reminder_service.dart';

/// Settings: the morning nudge, plus a quiet place to keep a copy of the
/// list. Everything saves the moment it changes.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.reminder,
    required this.onExport,
    required this.onImport,
  });

  final ReminderService reminder;
  final Future<void> Function() onExport;
  final Future<void> Function() onImport;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.reminder.load();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
    });
  }

  Future<void> _save() async {
    await widget.reminder.update(
      ReminderSettings(
        enabled: _enabled,
        hour: _time.hour,
        minute: _time.minute,
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
    await _save();
  }

  void _runDataAction(Future<void> Function() action) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle.
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Settings', style: textTheme.headlineSmall),
                const SizedBox(height: 2),

                const _SectionLabel('Morning nudge'),
                Text(
                  'A quiet check-in when parked things come back. '
                  'No pressure to act.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // A Material of its own so the tile's ink splash paints above
                // the sheet's rounded DecoratedBox background, not hidden
                // underneath it.
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: (value) {
                      setState(() => _enabled = value);
                      _save();
                      if (value) {
                        final messenger = ScaffoldMessenger.of(context);
                        widget.reminder.requestPermission().then((granted) {
                          if (!mounted) return;
                          if (!granted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enable notification permission for morning nudges.',
                                ),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        });
                      }
                    },
                    title: const Text('Gentle nudge'),
                    subtitle: Text(
                      _enabled
                          ? _time.format(context)
                          : 'Off — the app stays silent.',
                    ),
                    activeThumbColor: colors.primary,
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: _pickTime,
                    icon: Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    label: Text(
                      'Change the time',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const _SectionLabel('Your data'),
                Text(
                  'Everything lives on this phone. A backup is one small '
                  'file you can keep anywhere.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      _DataAction(
                        icon: Icons.ios_share_rounded,
                        tint: colors.primary,
                        label: 'Save a backup',
                        onTap: () => _runDataAction(widget.onExport),
                      ),
                      _DataAction(
                        icon: Icons.restore_rounded,
                        tint: colors.onSurfaceVariant,
                        label: 'Restore a backup',
                        onTap: () => _runDataAction(widget.onImport),
                      ),
                    ],
                  ),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final sent = await widget.reminder.fireNow();
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? 'Test notification sent. Check your status bar.'
                                : 'Could not send notification. Please enable notification permission in Settings.',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bug_report_rounded, size: 18),
                    label: const Text('Test notification now'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A row in the app's shared visual language: a tinted circle, then the
/// label. Same shape the parked card uses for its exits.
class _DataAction extends StatelessWidget {
  const _DataAction({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
