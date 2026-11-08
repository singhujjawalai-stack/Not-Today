import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/not_today_item.dart';

/// The quiet shelf under the header: items set aside with "Not today",
/// resting until tomorrow. Collapsed by default; one tap reveals them, and
/// any of them can come back early.
class RestingPanel extends StatefulWidget {
  const RestingPanel({super.key, required this.items, required this.onBringBack});

  final List<NotTodayItem> items;
  final ValueChanged<NotTodayItem> onBringBack;

  @override
  State<RestingPanel> createState() => _RestingPanelState();
}

class _RestingPanelState extends State<RestingPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outline, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.snooze_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Resting until tomorrow',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.items.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_open) ...[
              Divider(height: 1, thickness: 1, color: colors.outline),
              for (final (index, item) in widget.items.indexed) ...[
                if (index > 0)
                  Divider(height: 1, thickness: 1, color: colors.outline),
                _RestingRow(
                  item: item,
                  onBringBack: () => widget.onBringBack(item),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RestingRow extends StatelessWidget {
  const _RestingRow({required this.item, required this.onBringBack});

  final NotTodayItem item;
  final VoidCallback onBringBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.text, style: textTheme.bodyMedium),
                const SizedBox(height: 3),
                Text(
                  _returnLabel(item),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onBringBack,
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('Bring back'),
          ),
        ],
      ),
    );
  }

  /// Postpone always sets the return to the start of tomorrow, but a future
  /// date format costs one line — so anything further out gets a real date.
  String _returnLabel(NotTodayItem item) {
    final until = item.postponedUntil;
    if (until == null) return 'Resting';
    final now = DateTime.now();
    final dayAfterTomorrow = DateTime(now.year, now.month, now.day + 2);
    if (until.isBefore(dayAfterTomorrow)) return 'Back tomorrow';
    return 'Back ${DateFormat('EEE, MMM d').format(until)}';
  }
}
