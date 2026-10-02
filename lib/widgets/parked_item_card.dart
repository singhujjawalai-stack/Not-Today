import 'package:flutter/material.dart';
import '../models/not_today_item.dart';

/// A parked item. Tapping it gently expands it in place to reveal the three
/// quiet exits: "Not today", "I did it", and "Let it go".
class ParkedItemCard extends StatefulWidget {
  const ParkedItemCard({
    super.key,
    required this.item,
    required this.onPostpone,
    required this.onDone,
    required this.onLetGo,
  });

  final NotTodayItem item;
  final VoidCallback onPostpone;
  final VoidCallback onDone;
  final VoidCallback onLetGo;

  @override
  State<ParkedItemCard> createState() => _ParkedItemCardState();
}

class _ParkedItemCardState extends State<ParkedItemCard> {
  bool _expanded = false;

  /// After this many "Not today"s the card stops trying to quiet the item and
  /// starts asking what you actually want to do with it.
  static const _mirrorThreshold = 5;

  bool get _atMirror => widget.item.postponeCount >= _mirrorThreshold;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colors.outline, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, _expanded ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.text,
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _meta(),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, thickness: 1, color: colors.outline),
                  const SizedBox(height: 2),
                  if (!_atMirror)
                    _ActionRow(
                      icon: Icons.snooze_rounded,
                      label: 'Not today',
                      tint: colors.onSurfaceVariant,
                      labelColor: colors.onSurfaceVariant,
                      onTap: () {
                        setState(() => _expanded = false);
                        widget.onPostpone();
                      },
                    ),
                  _ActionRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: "I did it",
                    tint: colors.primary,
                    labelColor: colors.onSurface,
                    onTap: widget.onDone,
                  ),
                  _ActionRow(
                    icon: Icons.remove_rounded,
                    label: 'Let it go',
                    tint: colors.onSurfaceVariant,
                    labelColor: colors.onSurfaceVariant,
                    onTap: widget.onLetGo,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta() {
    final count = widget.item.postponeCount;
    if (_atMirror) {
      // The mirror: a number becomes an observation.
      return "You've set this aside $count times.";
    }
    final parts = <String>[relativeParkedLabel(widget.item.parkedAt)];
    if (count > 0) {
      parts.add('postponed $count×');
    }
    return parts.join(' · ');
  }
}

String relativeParkedLabel(DateTime then) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(then.year, then.month, then.day);
  final diff = today.difference(day).inDays;

  if (diff <= 0) return 'Parked today';
  if (diff == 1) return 'Parked yesterday';
  return 'Parked $diff days ago';
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.tint,
    required this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}