import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/not_today_item.dart';

/// The quiet summary of the current week: what was parked, done, and let go.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({
    super.key,
    required this.allItems,
    required this.onRepark,
  });

  final List<NotTodayItem> allItems;

  /// Called when an item that was let go is brought back to the parked list.
  final ValueChanged<NotTodayItem> onRepark;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  late final List<NotTodayItem> _items = List.of(widget.allItems);

  void _bringBack(NotTodayItem item) {
    final brought = item.bringBack();
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    setState(() => _items[index] = brought);
    widget.onRepark(brought);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final monday = today.subtract(Duration(days: today.weekday - 1));

    bool inWeek(DateTime when) =>
        !when.isBefore(monday) && when.isBefore(tomorrow);

    final parked = _items.where((i) => inWeek(i.parkedAt)).length;
    final doneThisWeek = _items
        .where((i) =>
            i.releasedAs == ReleaseKind.done &&
            i.releasedAt != null &&
            inWeek(i.releasedAt!))
        .toList()
      ..sort((a, b) => b.releasedAt!.compareTo(a.releasedAt!));
    final letGoThisWeek = _items
        .where((i) =>
            i.releasedAs == ReleaseKind.letGo &&
            i.releasedAt != null &&
            inWeek(i.releasedAt!))
        .toList()
      ..sort((a, b) => b.releasedAt!.compareTo(a.releasedAt!));
    final stillWaiting = _items.where((i) => i.isParked).length;

    // The item parked the longest — the mirror version of the review.
    final parkedItems = _items.where((i) => i.isParked);
    final oldest = parkedItems.isEmpty
        ? null
        : parkedItems.reduce(
            (a, b) => a.parkedAt.isBefore(b.parkedAt) ? a : b,
          );

    // The pattern the review catches: something still parked that "Not
    // today" was said to 3+ times within this week gets a gentle question.
    final followedPattern = _followedPattern(parkedItems, inWeek);

    final hasActivity =
        parked > 0 || doneThisWeek.isNotEmpty || letGoThisWeek.isNotEmpty;

    final headline = doneThisWeek.isNotEmpty && stillWaiting == 0
        ? 'Everything moved.'
        : 'A manageable week.';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'This week',
          style: textTheme.headlineSmall,
        ),
        iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            _rangeLabel(monday, today),
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),

          if (!hasActivity)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_outlined,
                      size: 32,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Not much happened. That\'s okay — '
                    'the list is there when you need it.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            Text(
              headline,
              style: textTheme.headlineSmall?.copyWith(
                color: headline == 'Everything moved.'
                    ? colors.primary
                    : colors.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Parked · Did · Let go
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.outline, width: 1),
              ),
              child: Row(
                children: [
                  _Stat(number: parked, label: 'Parked'),
                  _Stat(number: doneThisWeek.length, label: 'Did'),
                  _Stat(number: letGoThisWeek.length, label: 'Let go'),
                ],
              ),
            ),

            if (stillWaiting > 0) ...[
              const SizedBox(height: 18),
              Text(
                'Still waiting: $stillWaiting — '
                "they're not going anywhere.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],

            if (oldest != null) ...[
              const SizedBox(height: 8),
              Text(
                'Carrying the longest: ${oldest.text}, since '
                '${DateFormat('MMM d').format(oldest.parkedAt)}.'
                '${_ageLabel(oldest, today)}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],

            if (followedPattern != null) ...[
              const SizedBox(height: 8),
              Text(
                '${followedPattern.item.text} followed you '
                '${followedPattern.count}× this week. '
                'Is it actually yours to do?',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],

            // Letting go is a reframe, not a failure.
            if (letGoThisWeek.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                letGoThisWeek.length == 1
                    ? '1 thing released — room cleared.'
                    : '${letGoThisWeek.length} things released — room cleared.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],

            if (doneThisWeek.isNotEmpty) _SectionLabel('This week you did'),
            for (final item in doneThisWeek)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item.text)),
                  ],
                ),
              ),

            if (letGoThisWeek.isNotEmpty) ...[
              if (doneThisWeek.isNotEmpty) const SizedBox(height: 22),
              const _SectionLabel('This week you let go'),
              for (final item in letGoThisWeek)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.remove_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.text)),
                      TextButton(
                        onPressed: () => _bringBack(item),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Bring back'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  /// The still-parked item "Not today" was said to most often within this
  /// week, when that's 3+ times — the review's gentle question. Ties keep
  /// whichever was found first; only the worst offender is named.
  ({NotTodayItem item, int count})? _followedPattern(
    Iterable<NotTodayItem> parked,
    bool Function(DateTime) inWeek,
  ) {
    NotTodayItem? worst;
    var worstCount = 2; // only 3+ within the week qualifies
    for (final item in parked) {
      final count = item.postponedDates.where(inWeek).length;
      if (count > worstCount) {
        worst = item;
        worstCount = count;
      }
    }
    return worst == null ? null : (item: worst, count: worstCount);
  }

  /// For the longest-carried item: once it's been waiting a couple of
  /// calendar days, name it out loud — ". That's 3 days." A same-day or
  /// yesterday item stays silent (the "since …" date already says it).
  String _ageLabel(NotTodayItem item, DateTime today) {
    final parkedDay =
        DateTime(item.parkedAt.year, item.parkedAt.month, item.parkedAt.day);
    final days = today.difference(parkedDay).inDays;
    if (days < 2) return '';
    return " That's $days days.";
  }

  String _rangeLabel(DateTime monday, DateTime today) {
    final start = DateFormat('EEE, MMM d').format(monday);
    if (monday == today) return start;
    final end = today.weekday == DateTime.sunday
        ? DateFormat('EEE, MMM d').format(today)
        : 'today';
    return '$start → $end';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          letterSpacing: 0.4,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Expanded(
      child: Column(
        children: [
          Text(
            '$number',
            style: TextStyle(
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}