import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'experience.dart';
import 'ui.dart';
import 'update_presentation.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key, required this.api, required this.onOpen});
  final PvgApi api;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> items = [];
  String? readAt, error;
  bool loading = true, marking = false, fetching = false, reloadPending = false;
  bool showAllActivity = false;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? refreshTimer;
  String? owner;

  @override
  void initState() {
    super.initState();
    owner = widget.api.user?['id'];
    if (!widget.api.signedIn) {
      loading = false;
      error = 'Sign in again to see your updates.';
    }
    widget.api.addListener(sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    subscription = widget.api.changes.listen((event) {
      if (!['booking_tracking', 'connection_lost'].contains(event['kind'])) {
        load();
      }
    });
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        load();
      }
    });
    load();
  }

  @override
  void dispose() {
    widget.api.removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  void sessionChanged() {
    final nextOwner = widget.api.signedIn
        ? (widget.api.user?['id'] as String?)
        : null;
    if (owner == nextOwner || !mounted) return;
    setState(() {
      owner = nextOwner;
      items = [];
      readAt = null;
      loading = nextOwner != null;
      error = nextOwner == null
          ? 'Your session has ended. Sign in again to see your updates.'
          : null;
    });
    if (nextOwner != null) load();
  }

  Future<void> load() async {
    if (!widget.api.signedIn || owner == null) return;
    if (fetching) {
      reloadPending = true;
      return;
    }
    fetching = true;
    final requestOwner = owner;
    try {
      final results = await Future.wait<dynamic>([
        widget.api.bookings(),
        widget.api.request('/preferences'),
      ]);
      final next = <Map<String, dynamic>>[];
      for (final b in results[0]) {
        for (final e in b['events'] as List? ?? []) {
          next.add({...Map<String, dynamic>.from(e), 'booking': b});
        }
      }
      next.sort(
        (a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String),
      );
      if (!mounted || !widget.api.signedIn || owner != requestOwner) return;
      items = next;
      readAt = results[1]['updates_read_at'];
      error = null;
    } catch (e) {
      if (mounted && widget.api.signedIn && owner == requestOwner) {
        error = errorText(e);
      }
    } finally {
      fetching = false;
      if (mounted) {
        setState(() => loading = false);
        if (reloadPending) {
          reloadPending = false;
          load();
        }
      }
    }
  }

  Future<void> mark() async {
    setState(() => marking = true);
    try {
      await widget.api.request('/updates/read', data: {});
      await load();
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
    if (mounted) setState(() => marking = false);
  }

  bool isUnread(Map<String, dynamic> e) =>
      readAt == null ||
      DateTime.parse(e['created_at']).isAfter(DateTime.parse(readAt!));

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where((e) => showAllActivity || isCustomerUpdate(e))
        .toList();
    final attention = <String, Map<String, dynamic>>{};
    for (final e in items) {
      final b = Map<String, dynamic>.from(e['booking']);
      if (visitNeedsAttention(b)) attention[b['id']] = b;
    }
    String? lastDay;
    return Scaffold(
      appBar: AppBar(title: const Text('Your updates')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const Text(
              'Everything for your visit.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: forest,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'In-app updates refresh here automatically.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (attention.isNotEmpty) ...[
              Panel(
                color: softLime,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Needs your attention', color: forest),
                    for (final b in attention.values)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.fact_check_outlined,
                          size: 21,
                        ),
                        title: Text(visitActionLabel(b)),
                        subtitle: Text(b['reference']),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          await widget.onOpen(b);
                          await load();
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Updates'),
                  selectedColor: lime,
                  selected: !showAllActivity,
                  onSelected: (_) => setState(() => showAllActivity = false),
                ),
                ChoiceChip(
                  label: const Text('All activity'),
                  selectedColor: lime,
                  selected: showAllActivity,
                  onSelected: (_) => setState(() => showAllActivity = true),
                ),
                TextButton(
                  onPressed: marking || !items.any(isUnread) ? null : mark,
                  child: Text(marking ? 'Marking…' : 'Mark all read'),
                ),
              ],
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Notice(error!, error: true),
            if (!loading && visible.isEmpty && error == null)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'All quiet for now.',
                text:
                    'Your booking progress and messages from PVG will appear here.',
              ),
            for (final e in visible) ...[
              if (updateDayLabel(e['created_at']) != lastDay)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                  child: Kicker(lastDay = updateDayLabel(e['created_at'])),
                ),
              updateRow(e),
            ],
            const SizedBox(height: 12),
            const Text(
              'These are in-app updates. Notifications outside the app are not enabled yet.',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget updateRow(Map<String, dynamic> e) {
    final unread = isUnread(e);
    final note = customerUpdateNote(e);
    final b = Map<String, dynamic>.from(e['booking']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: unread ? const Color(0xfff0f6e5) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await widget.onOpen(b);
            await load();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: unread ? const Color(0xffe0ecce) : canvas,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(updateIcon(e['action']), size: 17, color: forest),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventLabel(e['action']),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${b['reference']} · ${timeLabel(e['created_at'])}',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: forest,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  children: [
                    if (unread)
                      const Padding(
                        padding: EdgeInsets.only(top: 5, bottom: 8),
                        child: Badge(backgroundColor: forest, smallSize: 6),
                      ),
                    const Icon(Icons.chevron_right, size: 17, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
