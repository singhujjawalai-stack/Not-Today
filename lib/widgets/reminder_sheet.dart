import 'package:flutter/material.dart';
import '../services/reminder_service.dart';

/// One quiet decision: a gentle check-in when parked things come back.
/// A toggle and, when it's on, a time. Saved the moment it changes.
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({super.key, required this.reminder});

  final ReminderService reminder;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
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
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked == null) return;
    setState(() => _time = picked);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
              Text('Morning nudge', style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'A quiet check-in when parked things come back. '
                'No pressure to act.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
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
              // ── DEBUG: manual trigger — remove after testing ──
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
              // ── END DEBUG ──
            ],
          ),
        ),
      ),
    );
  }
}