import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/not_today_item.dart';
import '../services/backup_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../widgets/add_item_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/parked_item_card.dart';
import '../widgets/resting_panel.dart';
import '../widgets/settings_sheet.dart';
import 'weekly_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _storageService = StorageService();
  final _reminder = ReminderService();
  final _backup = BackupService();

  /// Recreated whenever the parked list is replaced wholesale (a restore) —
  /// an AnimatedList can only be initialized once.
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  /// True until the first storage read finishes, so the empty state doesn't
  /// flash on every launch.
  bool _loading = true;

  /// Everything the app knows: parked items plus recent history.
  List<NotTodayItem> _allItems = [];

  /// Just the currently-visible parked subset, newest first — what the list
  /// renders. Items hidden by "Not today" are not here until their return time.
  List<NotTodayItem> _parked = [];

  /// Awakes to put "Not today" items back once their return time arrives.
  Timer? _returnTimer;

  /// Number of items that just slid back at midnight; shown briefly in the
  /// count line before it settles into the everyday count.
  int _justReturned = 0;
  Timer? _returnBannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _returnTimer?.cancel();
    _returnBannerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resurfaceDueItems();
  }

  /// Schedule (or clear) a timer so when a postponed item becomes visible
  /// again it slides back into the list automatically — the user doesn't
  /// have to reopen the app; the app notices on its own.
  void _scheduleReturnRefresh() {
    _returnTimer?.cancel();
    final hidden = _allItems.where(
      (i) => i.isParked && i.isPostponedNow(DateTime.now()),
    );
    if (hidden.isEmpty) return;
    final firstReturn = hidden
        .map((i) => i.postponedUntil!)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = firstReturn.difference(DateTime.now());
    if (delay.inMilliseconds <= 0) return; // already due; resurface below
    _returnTimer = Timer(delay, _resurfaceDueItems);
  }

  /// Put back every item whose "Not today" return time has arrived.
  void _resurfaceDueItems() {
    if (!mounted) return;
    final now = DateTime.now();
    final due = _allItems
        .where(
          (i) =>
              i.isParked &&
              i.postponedUntil != null &&
              !i.postponedUntil!.isAfter(now),
        )
        .toList();
    var returned = 0;
    for (final item in due) {
      if (_insertIntoParked(item)) returned++;
    }
    if (returned > 0) _flashReturnBanner(returned);
    _scheduleReturnRefresh();
  }

  /// Show the "back from yesterday" note in the count line for a few seconds.
  void _flashReturnBanner(int count) {
    _returnBannerTimer?.cancel();
    if (!mounted) return;
    setState(() => _justReturned = count);
    _returnBannerTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _justReturned = 0);
    });
  }

  Future<void> _load() async {
    final items = await _storageService.loadItems();
    if (!mounted) return;
    setState(() {
      _allItems = items;
      _parked = items.where(_visibleNow).toList();
      _loading = false;
    });
    _scheduleReturnRefresh();
    // Set the items before initializing: initialize() schedules the nudge and
    // must see the real list, otherwise the first body says "nothing on the
    // list" even when items exist.
    await _reminder.setItems(items);
    await _reminder.initialize();
  }

  /// Items that belong on the main list at [now]: parked and not set aside
  /// by "Not today" past their return time.
  bool _visibleNow(NotTodayItem item) =>
      item.isParked && !item.isPostponedNow(DateTime.now());

  /// How many items are parked but currently hidden by "Not today".
  int get _hiddenCount => _allItems
      .where((i) => i.isParked && i.isPostponedNow(DateTime.now()))
      .length;

  /// The hidden items themselves, for the resting shelf.
  List<NotTodayItem> get _restingItems => _allItems
      .where((i) => i.isParked && i.isPostponedNow(DateTime.now()))
      .toList();

  /// Suddenly there's time today: take a resting item back onto the list.
  /// The postpone still counts in history — it did happen.
  void _bringBackToday(NotTodayItem item) {
    final allIndex = _allItems.indexWhere((i) => i.id == item.id);
    if (allIndex == -1) return;
    final woken = item.unpostpone();
    setState(() => _allItems[allIndex] = woken);
    _insertIntoParked(woken);
    _save();
    _scheduleReturnRefresh();
    _showSnack('Back on the list.');
  }

  Future<void> _save() async {
    await _storageService.saveItems(_allItems);
    await _reminder.setItems(_allItems);
  }

  /// One snackbar shape for the whole app: a quiet message, optionally with
  /// an Undo escape hatch.
  void _showSnack(String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ),
    );
  }

  /// The removal animation shared by postpone, release, and delete.
  Widget _removalTransition(NotTodayItem item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ParkedItemCard(
            item: item,
            onPostpone: () {},
            onDone: () {},
            onLetGo: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemSheet(),
    );
    if (text == null || text.isEmpty) return;

    final item = NotTodayItem(
      id: const Uuid().v4(),
      text: text,
      parkedAt: DateTime.now(),
    );
    setState(() {
      _allItems.insert(0, item);
      _parked.insert(0, item);
    });
    _listKey.currentState?.insertItem(0);
    _save();
  }

  void _postpone(NotTodayItem item) {
    // Keep the pre-postpone state: Undo restores it whole, so the item
    // reappears exactly as it was.
    final previous = item;
    final postponed = item.postpone(DateTime.now());
    final allIndex = _allItems.indexWhere((i) => i.id == item.id);
    if (allIndex != -1) {
      setState(() => _allItems[allIndex] = postponed);
    }

    // "Not today" sets the item aside until tomorrow — it leaves the list
    // with the same gentle motion as releasing.
    final index = _parked.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _removalTransition(item, animation),
        duration: const Duration(milliseconds: 280),
      );
      setState(() => _parked.removeAt(index));
    }

    _save();
    _scheduleReturnRefresh();
    _showSnack('Back tomorrow.', undo: () => _undoPostpone(previous));
  }

  /// Take back a "Not today": the item returns to the list as it was.
  void _undoPostpone(NotTodayItem previous) {
    final allIndex = _allItems.indexWhere((i) => i.id == previous.id);
    if (allIndex == -1) return;
    setState(() => _allItems[allIndex] = previous);
    _insertIntoParked(previous);
    _save();
    _scheduleReturnRefresh();
  }

  /// Reword a parked item in place — no dates move, nothing restarts.
  Future<void> _editItem(NotTodayItem item) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(
        initialText: item.text,
        title: 'Say it a little differently',
        actionLabel: 'Save changes',
        cancelLabel: 'Keep as is',
      ),
    );
    if (text == null || text == item.text) return;

    final edited = item.edit(text);
    final allIndex = _allItems.indexWhere((i) => i.id == item.id);
    final parkedIndex = _parked.indexWhere((i) => i.id == item.id);
    if (allIndex == -1) return;
    setState(() {
      _allItems[allIndex] = edited;
      if (parkedIndex != -1) _parked[parkedIndex] = edited;
    });
    _save();
  }

  /// Remove a parked item outright. Undoable for the usual grace period —
  /// nothing is ever really gone by accident.
  void _deleteItem(NotTodayItem item) {
    final allIndex = _allItems.indexWhere((i) => i.id == item.id);
    final parkedIndex = _parked.indexWhere((i) => i.id == item.id);
    if (allIndex == -1) return;

    if (parkedIndex != -1) {
      _listKey.currentState?.removeItem(
        parkedIndex,
        (context, animation) => _removalTransition(item, animation),
        duration: const Duration(milliseconds: 280),
      );
    }
    setState(() {
      _allItems.removeAt(allIndex);
      if (parkedIndex != -1) _parked.removeAt(parkedIndex);
    });
    _save();

    _showSnack(
      'Removed.',
      undo: () => _undoDelete(item, allIndex, parkedIndex),
    );
  }

  void _undoDelete(NotTodayItem item, int allIndex, int parkedIndex) {
    setState(() {
      _allItems.insert(allIndex.clamp(0, _allItems.length), item);
      if (parkedIndex != -1) {
        final at = parkedIndex.clamp(0, _parked.length);
        _parked.insert(at, item);
        _listKey.currentState?.insertItem(at);
      }
    });
    _save();
  }

  /// Slide an item back into the visible list at its parked-order position.
  /// Falls back to a no-op if the list is already showing it.
  bool _insertIntoParked(NotTodayItem item) {
    if (!_visibleNow(item)) return false;
    if (_parked.any((p) => p.id == item.id)) return false;
    final index = _parked.indexWhere((p) => p.parkedAt.isBefore(item.parkedAt));
    final at = index == -1 ? _parked.length : index;
    setState(() => _parked.insert(at, item));
    _listKey.currentState?.insertItem(at);
    return true;
  }

  void _release(NotTodayItem item, ReleaseKind kind) {
    final released = item.release(kind, DateTime.now());

    final allIndex = _allItems.indexWhere((i) => i.id == item.id);
    if (allIndex != -1) {
      setState(() => _allItems[allIndex] = released);
    }

    final index = _parked.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _removalTransition(item, animation),
        duration: const Duration(milliseconds: 280),
      );
      setState(() => _parked.removeAt(index));
    }

    _save();

    // Grace period: for a few seconds the release can be taken back. Nothing
    // is ever really gone by accident.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    _showSnack(
      kind == ReleaseKind.done ? 'Done. Off your mind. 🎉' : "Let go. That's allowed.",
      undo: () => _repark(released.bringBack()),
    );
  }

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            WeeklyReviewScreen(allItems: _allItems, onRepark: _repark),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(
        reminder: _reminder,
        onExport: _exportBackup,
        onImport: _importBackup,
      ),
    );
  }

  /// Write the whole list (parked + recent history) to a file the user picks
  /// a home for.
  Future<void> _exportBackup() async {
    try {
      final uri = await _backup.export(_allItems);
      if (!mounted) return;
      if (uri != null) _showSnack('Backup saved. Keep it somewhere safe.');
    } catch (e) {
      if (!mounted) return;
      _showSnack("Couldn't save the backup.");
    }
  }

  /// Fold a picked backup into the live list. Imported items override their
  /// old selves; purely imported ones join the end.
  Future<void> _importBackup() async {
    final BackupContents? picked;
    try {
      picked = await _backup.import();
    } on FormatException {
      if (!mounted) return;
      _showSnack("That file didn't look like a Not Today backup.");
      return;
    } catch (e) {
      if (!mounted) return;
      _showSnack("Couldn't read that backup.");
      return;
    }
    if (picked == null) return;
    // A promoted local: closures below can't see the promotion.
    final contents = picked;
    if (contents.items.isEmpty) {
      _showSnack('Nothing readable in that backup.');
      return;
    }

    setState(() {
      _allItems = BackupService.merge(_allItems, contents.items);
      _parked = _allItems.where(_visibleNow).toList();
      _listKey = GlobalKey<AnimatedListState>();
    });
    await _save();
    _scheduleReturnRefresh();

    final skipped = contents.skipped;
    _showSnack(
      skipped > 0
          ? 'Restored ${contents.items.length} · $skipped unreadable skipped.'
          : 'Restored ${contents.items.length} '
              'thing${contents.items.length == 1 ? '' : 's'}.',
    );
  }

  /// Called from the weekly review: an item that was let go is brought back.
  void _repark(NotTodayItem item) {
    final index = _allItems.indexWhere((i) => i.id == item.id);
    if (index == -1) return;
    setState(() => _allItems[index] = item);
    _insertIntoParked(item);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Not Today',
                        style: textTheme.labelLarge?.copyWith(
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _openSettings,
                        tooltip: 'Settings',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      InkWell(
                        onTap: _openReview,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'This week',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _countLine(),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (!_loading && _restingItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: RestingPanel(
                  items: _restingItems,
                  onBringBack: _bringBackToday,
                ),
              ),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : _parked.isEmpty
                  ? EmptyState(postponedCount: _hiddenCount)
                  : AnimatedList(
                      key: _listKey,
                      // Only read at first mount — every later add/remove goes
                      // through insertItem/removeItem. Without this, a list
                      // that mounts already carrying items renders none of them.
                      initialItemCount: _parked.length,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                      itemBuilder: (context, index, animation) {
                        final item = _parked[index];
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(animation),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ParkedItemCard(
                                key: ValueKey(item.id),
                                item: item,
                                onPostpone: () => _postpone(item),
                                onDone: () => _release(item, ReleaseKind.done),
                                onLetGo: () =>
                                    _release(item, ReleaseKind.letGo),
                                onEdit: () => _editItem(item),
                                onDelete: () => _deleteItem(item),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Park something',
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  String _countLine() {
    if (_loading) return '';
    // Momentary note when the new-day resurface puts items back.
    if (_justReturned > 0) {
      final n = _justReturned;
      return '$n back from yesterday · take a look';
    }
    final visible = _parked.length;
    if (visible == 0) {
      final hidden = _hiddenCount;
      if (hidden == 0) return "Nothing parked — that's fine too.";
      return '$hidden postponed · back tomorrow';
    }
    return '$visible thing${visible == 1 ? '' : 's'} parked · no rush';
  }
}
