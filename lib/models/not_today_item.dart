/// How an item left the list.
enum ReleaseKind { done, letGo }

/// A single parked item.
///
/// Parked items have a null [releasedAs] (they're still waiting, and their
/// [releasedAt] is null). Releasing one sets both, and the item becomes part
/// of history for the weekly review.
class NotTodayItem {
  const NotTodayItem({
    required this.id,
    required this.text,
    required this.parkedAt,
    this.lastPostponedAt,
    this.postponeCount = 0,
    this.postponedDates = const [],
    this.postponedUntil,
    this.releasedAs,
    this.releasedAt,
  });

  final String id;
  final String text;
  final DateTime parkedAt;

  /// When "Not today" was last said. Null until the first postponement.
  final DateTime? lastPostponedAt;

  /// How many times "Not today" has been said.
  final int postponeCount;

  /// When each "Not today" was said, oldest first. The review uses these
  /// (not [postponeCount]) to spot a *this-week* postponement pattern.
  final List<DateTime> postponedDates;

  /// When the item is allowed to appear back in the main view. Set to the
  /// start of tomorrow by [postpone]; after that instant the item is visible
  /// again. Null for items that have never been set aside "until tomorrow".
  final DateTime? postponedUntil;

  /// How the item left the list. Null while still parked.
  final ReleaseKind? releasedAs;
  final DateTime? releasedAt;

  /// Whether this item is still parked (not yet released).
  bool get isParked => releasedAs == null;

  /// Whether "Not today" was said and the return time hasn't arrived yet —
  /// i.e. the item is hidden from the main view at [now].
  bool isPostponedNow(DateTime now) =>
      postponedUntil != null && postponedUntil!.isAfter(now);

  /// Say "not today" again. Bumps the count and sets the item aside until the
  /// next calendar day.
  NotTodayItem postpone(DateTime when) => NotTodayItem(
        id: id,
        text: text,
        parkedAt: parkedAt,
        lastPostponedAt: when,
        postponeCount: postponeCount + 1,
        postponedDates: [...postponedDates, when],
        postponedUntil: DateTime(when.year, when.month, when.day + 1),
        releasedAs: releasedAs,
        releasedAt: releasedAt,
      );

  /// Retract a release and put the item back on the parked list. Used from
  /// the weekly review ("bring it back") for things that were let go.
  NotTodayItem bringBack() => NotTodayItem(
        id: id,
        text: text,
        parkedAt: parkedAt,
        lastPostponedAt: lastPostponedAt,
        postponeCount: postponeCount,
        postponedDates: postponedDates,
        postponedUntil: null,
        releasedAs: null,
        releasedAt: null,
      );

  /// Move the item off the list. Returns a copy marked as released.
  NotTodayItem release(ReleaseKind kind, DateTime when) => NotTodayItem(
        id: id,
        text: text,
        parkedAt: parkedAt,
        lastPostponedAt: lastPostponedAt,
        postponeCount: postponeCount,
        postponedDates: postponedDates,
        releasedAs: kind,
        releasedAt: when,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'parkedAt': parkedAt.toIso8601String(),
        'lastPostponedAt': lastPostponedAt?.toIso8601String(),
        'postponeCount': postponeCount,
        'postponedDates':
            postponedDates.map((d) => d.toIso8601String()).toList(),
        'postponedUntil': postponedUntil?.toIso8601String(),
        'releasedAs': releasedAs?.name,
        'releasedAt': releasedAt?.toIso8601String(),
      };

  factory NotTodayItem.fromJson(Map<String, dynamic> json) {
    final releasedAs = json['releasedAs'] as String?;
    return NotTodayItem(
      id: json['id'] as String,
      text: json['text'] as String,
      parkedAt: DateTime.parse(json['parkedAt'] as String),
      lastPostponedAt: json['lastPostponedAt'] == null
          ? null
          : DateTime.parse(json['lastPostponedAt'] as String),
      postponeCount: (json['postponeCount'] as num?)?.toInt() ?? 0,
      postponedDates: (json['postponedDates'] as List<dynamic>? ?? const [])
          .map((d) => DateTime.parse(d as String))
          .toList(),
      releasedAs: releasedAs == null
          ? null
          : ReleaseKind.values.firstWhere(
              (kind) => kind.name == releasedAs,
              orElse: () => ReleaseKind.letGo,
            ),
      releasedAt: json['releasedAt'] == null
          ? null
          : DateTime.parse(json['releasedAt'] as String),
      postponedUntil: json['postponedUntil'] == null
          ? null
          : DateTime.parse(json['postponedUntil'] as String),
    );
  }
}