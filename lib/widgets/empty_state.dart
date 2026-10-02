import 'package:flutter/material.dart';

/// Shown when nothing is parked. The whole design leans on this moment —
/// it should feel like a clear head, not a blank list.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.postponedCount = 0});

  /// Items currently set aside with "Not today". When > 0 the view isn't
  /// empty, it's resting — the headline and copy change to say so.
  final int postponedCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_outlined,
                size: 44,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 26),
            Text(
              postponedCount > 0 ? 'Nothing waiting today.' : 'Nothing waiting.',
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              postponedCount > 0
                  ? postponedCount == 1
                      ? 'One thing you said "not today" to comes back tomorrow — no rush.'
                      : '$postponedCount things you said "not today" to come back tomorrow — no rush.'
                  : "When something can't happen today, park it here — "
                      "it won't get lost, and it won't nag you.",
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}