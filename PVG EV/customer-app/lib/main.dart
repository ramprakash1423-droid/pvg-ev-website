import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';
import 'experience.dart';
import 'charge_widgets.dart';
import 'personal_screens.dart';
import 'auth_screen.dart';
import 'booking_screen.dart';
import 'booking_detail.dart';
import 'tracking_experience.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) WidgetsBinding.instance.ensureSemantics();
  runApp(PvgCustomerApp(api: PvgApi()));
}

class PvgCustomerApp extends StatefulWidget {
  const PvgCustomerApp({super.key, required this.api});
  final PvgApi api;
  @override
  State<PvgCustomerApp> createState() => _PvgCustomerAppState();
}

class _PvgCustomerAppState extends State<PvgCustomerApp> {
  bool reducedMotion = false;
  void updateMotion(bool value) {
    if (mounted && value != reducedMotion) {
      setState(() => reducedMotion = value);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'PVG EV · Energy on your terms',
    theme: pvgTheme(),
    builder: (context, child) => ColoredBox(
      color: const Color(0xffe4e9ec),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  reducedMotion || MediaQuery.disableAnimationsOf(context),
            ),
            child: child!,
          ),
        ),
      ),
    ),
    home: CustomerHome(api: widget.api, onMotionChanged: updateMotion),
  );
}

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key, required this.api, this.onMotionChanged});
  final PvgApi api;
  final ValueChanged<bool>? onMotionChanged;
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome>
    with WidgetsBindingObserver {
  int tab = 0;
  bool loading = true, refreshing = false, trackingDisconnected = false;
  String? error;
  String filter = 'Active', search = '';
  String? homePlaceId, homeEvId;
  List<Map<String, dynamic>> bookings = [], vehicles = [], places = [];
  Map<String, dynamic> prefs = {};
  Timer? timer;
  StreamSubscription<Map<String, dynamic>>? liveUpdates;
  PvgApi get api => widget.api;
  bool get reduceMotion =>
      prefs['reduced_motion'] == true ||
      MediaQuery.disableAnimationsOf(context);
  bool active(Map<String, dynamic> b) =>
      !['paid', 'cancelled'].contains(b['status']);
  bool needsAction(Map<String, dynamic> b) => [
    'awaiting_acceptance',
    'awaiting_payment',
    'disputed',
  ].contains(b['status']);
  List<Map<String, dynamic>> get updates {
    final result = <Map<String, dynamic>>[];
    for (final b in bookings) {
      for (final e in (b['events'] as List? ?? [])) {
        result.add({
          ...Map<String, dynamic>.from(e),
          'booking_id': b['id'],
          'reference': b['reference'],
        });
      }
    }
    result.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return result;
  }

  int get unread => updates
      .where(
        (e) =>
            prefs['updates_read_at'] == null ||
            DateTime.parse(
              e['created_at'],
            ).isAfter(DateTime.parse(prefs['updates_read_at'])),
      )
      .length;
  @override
  void initState() {
    super.initState();
    api.addListener(changed);
    liveUpdates = api.changes.listen((event) {
      if (event['kind'] == 'connection_lost') {
        setState(() => trackingDisconnected = true);
        return;
      }
      if (['connected', 'reconnected'].contains(event['kind'])) {
        setState(() => trackingDisconnected = false);
      }
      if (event['kind'] == 'booking_tracking') {
        refreshHomeTracking(event['booking_id']);
        return;
      }
      if (event['kind'] != 'booking_tracking' &&
          event['kind'] != 'connection_lost' &&
          mounted) {
        load(silent: true);
      }
    });
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          api.signedIn &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed) &&
          ModalRoute.of(context)?.isCurrent == true) {
        load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    liveUpdates?.cancel();
    api.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      api.startLiveUpdates();
      load(silent: true);
    }
  }

  void changed() {
    if (!mounted) return;
    setState(() {
      if (!api.signedIn) {
        bookings = [];
        vehicles = [];
        places = [];
        prefs = {};
        widget.onMotionChanged?.call(false);
        homePlaceId = null;
        homeEvId = null;
      }
    });
  }

  Future<void> load({bool silent = false}) async {
    if (refreshing) return;
    refreshing = true;
    final owner = api.user?['id'];
    try {
      if (api.config == null) await api.loadConfig();
      if (api.signedIn) {
        final data = await Future.wait<dynamic>([
          api.bookings(),
          api.vehicles(),
          api.request('/places'),
          api.request('/preferences'),
        ]);
        if (mounted && api.signedIn && api.user?['id'] == owner) {
          bookings = data[0];
          vehicles = data[1];
          places = (data[2]['places'] as List)
              .map((p) => Map<String, dynamic>.from(p))
              .toList();
          prefs = data[3];
          widget.onMotionChanged?.call(prefs['reduced_motion'] == true);
        }
      }
      error = null;
    } catch (e) {
      error = errorText(e);
    }
    refreshing = false;
    if (mounted) setState(() => loading = false);
  }

  Future<bool> signIn() async {
    if (api.signedIn) return true;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SignInScreen(api: api)),
    );
    if (result == true) {
      await load();
      return true;
    }
    return false;
  }

  Future<void> book({Map<String, dynamic>? prefill}) async {
    if (!await signIn() || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(api: api, prefill: prefill),
      ),
    );
    await load();
  }

  Future<void> open(Map<String, dynamic> b) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetail(api: api, bookingId: b['id']),
      ),
    );
    await load();
  }

  Future<void> refreshHomeTracking(String? id) async {
    if (id == null || !bookings.any((b) => b['id'] == id)) return;
    try {
      final tracking = await api.request('/bookings/$id/tracking');
      if (mounted && api.signedIn) {
        setState(() {
          bookings = bookings
              .map((b) => b['id'] == id ? {...b, 'tracking': tracking} : b)
              .toList();
          trackingDisconnected = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => trackingDisconnected = true);
    }
  }

  Future<void> previewTracking() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EmptyTrackingScreen(
          onBook: () {
            Navigator.pop(ctx);
            bookHome();
          },
        ),
      ),
    );
  }

  Future<void> savedPlaces() async {
    if (!await signIn() || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlacesScreen(api: api)),
    );
    await load();
  }

  void help() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const HelpScreen()),
  );
  Future<void> editEv([Map<String, dynamic>? ev]) async {
    if (!await signIn() || !mounted) return;
    if (await showAddEv(context, api, ev: ev) == true) await load();
  }

  Future<void> preference(Map<String, dynamic> data) async {
    try {
      final p = await api.request('/preferences', data: data);
      if (mounted) {
        setState(() => prefs = p);
        widget.onMotionChanged?.call(prefs['reduced_motion'] == true);
      }
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> archive(Map<String, dynamic> v) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${v['model']}?'),
        content: const Text(
          'Your past and upcoming visits keep their vehicle details. You can add this EV again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep EV'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await api.request('/evs/${v['id']}/archive', data: {});
      await load();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> editName() async {
    var draftName = api.user?['name'] as String? ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What should we call you?'),
        content: TextFormField(
          initialValue: draftName,
          onChanged: (value) => draftName = value,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, draftName.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return;
    try {
      await api.updateProfile(name);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> notifications() async {
    if (!await signIn() || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdatesScreen(api: api, onOpen: open),
      ),
    );
    await load();
  }

  Map<String, dynamic>? get homePlace =>
      places.where((p) => p['id'] == homePlaceId).firstOrNull ??
      places.firstOrNull;
  Map<String, dynamic>? get homeVehicle =>
      vehicles
          .where((v) => v['id'] == (homeEvId ?? prefs['default_vehicle_id']))
          .firstOrNull ??
      vehicles.firstOrNull;
  Future<void> bookHome() => book(
    prefill: {
      ...?homePlace,
      if (homePlace != null) 'saved_place_id': homePlace!['id'],
      if (homeVehicle != null) 'ev': homeVehicle,
    },
  );

  Future<void> pickHomePlace() async {
    if (!await signIn() || !mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Where should we charge?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose an address or save a new place.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (final place in places)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    place['label'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    place['address'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: homePlace?['id'] == place['id']
                      ? const Icon(Icons.check_circle, color: forest)
                      : null,
                  onTap: () => Navigator.pop(ctx, place['id']),
                ),
              const SizedBox(height: 12),
              PrimaryButton(
                'Add an address',
                onPressed: () => Navigator.pop(ctx, 'add'),
                icon: Icons.add_location_alt_outlined,
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == 'add') {
      if (await editPlace(context, api) == true) {
        await load();
        if (mounted) setState(() => homePlaceId = places.firstOrNull?['id']);
      }
    } else {
      setState(() => homePlaceId = chosen);
    }
  }

  Future<void> pickHomeEv() async {
    if (!await signIn() || !mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 540),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Choose your EV',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your connector helps PVG plan the visit.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (final ev in vehicles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.electric_car_outlined),
                  title: Text(
                    ev['model'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${ev['registration']} · ${ev['connector']}'),
                  trailing: homeVehicle?['id'] == ev['id']
                      ? const Icon(Icons.check_circle, color: forest)
                      : null,
                  onTap: () => Navigator.pop(ctx, ev['id']),
                ),
              const SizedBox(height: 12),
              PrimaryButton(
                'Add an EV',
                onPressed: () => Navigator.pop(ctx, 'add'),
                icon: Icons.add,
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == 'add') {
      if (await showAddEv(context, api) == true) {
        await load();
        if (mounted) setState(() => homeEvId = vehicles.lastOrNull?['id']);
      }
    } else {
      setState(() => homeEvId = chosen);
    }
  }

  Widget heading(String kicker, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.7,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );
  Widget jobCard(Map<String, dynamic> b, {bool prominent = false}) =>
      CompactVisitCard(
        booking: b,
        onOpen: () => open(b),
        onAgain: () => book(prefill: b),
        highlight: prominent,
      );
  List<Widget> home() {
    final pending = bookings.where(needsAction).toList();
    final current = bookings.where(active).toList();
    final focus = pending.firstOrNull ?? current.firstOrNull;
    if (focus != null) {
      return [
        SectionTitle(
          'Track my charging vehicle',
          action: 'All visits',
          onTap: () => setState(() => tab = 1),
        ),
        TrackingExperience(
          booking: focus,
          connectionLost: trackingDisconnected,
          onRefresh: () => load(silent: true),
          onDetails: () => open(focus),
        ),
      ];
    }
    return [
      ServiceBanner(reducedMotion: reduceMotion),
      TextButton.icon(
        onPressed: previewTracking,
        icon: const Icon(Icons.route_outlined, size: 18),
        label: const Text('Track my charging vehicle'),
      ),
      const SizedBox(height: 4),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Book doorstep charging',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
                Icon(Icons.bolt_rounded, color: forest, size: 22),
              ],
            ),
            const SizedBox(height: 5),
            SelectionRow(
              icon: Icons.location_on_outlined,
              label: 'CHARGING LOCATION',
              value: homePlace?['label'] ?? 'Choose your charging address',
              detail: homePlace?['address'],
              onTap: pickHomePlace,
            ),
            const Divider(height: 1, color: line, indent: 52),
            SelectionRow(
              icon: Icons.electric_car_outlined,
              label: 'YOUR EV',
              value: homeVehicle?['model'] ?? 'Select or add your EV',
              detail: homeVehicle == null
                  ? null
                  : '${homeVehicle!['registration']} · ${homeVehicle!['connector']}',
              onTap: pickHomeEv,
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule_outlined, size: 16, color: muted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Choose your preferred visit time next. We’ll bring the charger to you.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              'Continue to booking',
              onPressed: bookHome,
              icon: Icons.arrow_forward_rounded,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuickAction(
            icon: Icons.bookmark_border,
            label: 'Places',
            onTap: savedPlaces,
          ),
          QuickAction(
            icon: Icons.receipt_long_outlined,
            label: 'History',
            onTap: () => setState(() {
              tab = 1;
              filter = 'History';
            }),
          ),
          QuickAction(
            icon: Icons.notifications_none_rounded,
            label: 'Updates',
            onTap: notifications,
          ),
          QuickAction(
            icon: Icons.support_agent_outlined,
            label: 'Help',
            onTap: help,
          ),
        ],
      ),
      const SizedBox(height: 18),
      ChargingJourney(onHelp: help),
      const SizedBox(height: 14),
      Material(
        color: const Color(0xffeef3ef),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 2,
          ),
          leading: const Icon(Icons.verified_user_outlined, size: 24),
          title: const Text(
            'You’re in control of the bill',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Review the units. Accept the bill. Then pay.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: help,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        api.isPreview
            ? 'Local preview · no real vehicle is dispatched.'
            : 'Chennai doorstep charging · Your visit is confirmed after assignment.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: muted),
      ),
    ];
  }

  List<Widget> visits() {
    final visible = bookings
        .where(
          (b) =>
              (filter == 'All' ||
                  filter == 'Active' && active(b) ||
                  filter == 'History' && !active(b) ||
                  filter == 'To do' && needsAction(b)) &&
              '${b['reference']} ${b['ev']['model']} ${b['address']}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return [
      heading(
        'YOUR CHARGING JOURNEY',
        'My visits',
        'Follow progress, review units and find your receipts.',
      ),
      if (!api.signedIn)
        EmptyState(
          icon: Icons.route_outlined,
          title: 'Your journey starts here.',
          text: 'Sign in to see your visits and charging updates.',
          action: 'Sign in',
          onTap: signIn,
        )
      else ...[
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search reference, EV or address',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['Active', 'To do', 'History', 'All']
              .map(
                (s) => ChoiceChip(
                  label: Text(s),
                  selected: filter == s,
                  selectedColor: lime,
                  onSelected: (_) => setState(() => filter = s),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          EmptyState(
            icon: Icons.event_available_outlined,
            title: search.isNotEmpty
                ? 'No matching visits.'
                : 'Nothing here yet.',
            text: search.isNotEmpty
                ? 'Try a different reference, model or location.'
                : 'Your visits will appear here as you book and complete them.',
            action: 'Book a charging visit',
            onTap: () => book(),
          ),
        ...visible.map(jobCard),
      ],
    ];
  }

  List<Widget> garage() => [
    heading(
      'THE ELECTRIC LIFE',
      'My garage',
      'Save your vehicles once. Pick your favourite for faster bookings.',
    ),
    if (!api.signedIn)
      EmptyState(
        icon: Icons.electric_car_outlined,
        title: 'A home for your EVs.',
        text: 'Sign in to save vehicles and connector details.',
        action: 'Sign in',
        onTap: signIn,
      )
    else ...[
      if (vehicles.isEmpty)
        const EmptyState(
          icon: Icons.electric_car_outlined,
          title: 'Meet your new garage.',
          text: 'Add your first EV to get started.',
        ),
      for (final v in vehicles)
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Panel(
            color: prefs['default_vehicle_id'] == v['id']
                ? softLime
                : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: forest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.electric_car_rounded,
                        color: lime,
                        size: 32,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Edit ${v['model']}',
                      onPressed: () => editEv(v),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove ${v['model']}',
                      onPressed: () => archive(v),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                Text(
                  v['model'],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                  ),
                ),
                Text(
                  v['registration'],
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.ev_station_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${v['connector']} connector',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => preference({'default_vehicle_id': v['id']}),
                  icon: Icon(
                    prefs['default_vehicle_id'] == v['id']
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                  ),
                  label: Text(
                    prefs['default_vehicle_id'] == v['id']
                        ? 'Preferred EV'
                        : 'Make preferred',
                  ),
                ),
                PrimaryButton(
                  'Charge this EV',
                  onPressed: () => book(prefill: {'ev': v}),
                  icon: Icons.bolt,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => editEv(),
        icon: const Icon(Icons.add),
        label: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('Add another EV'),
        ),
      ),
    ],
    const Notice(
      'Saved connector details help plan the visit. PVG confirms compatibility before assigning a charging vehicle.',
    ),
    TextButton(
      onPressed: help,
      child: const Text('Not sure about your connector?'),
    ),
  ];
  List<Widget> account() => [
    heading(
      'MADE PERSONAL',
      api.signedIn ? 'My account' : 'Welcome to PVG',
      'Your preferences, places and support.',
    ),
    if (!api.signedIn)
      PrimaryButton('Sign in to PVG', onPressed: signIn)
    else ...[
      Panel(
        color: forest,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: lime,
              child: Text(
                (api.user?['name'] as String? ?? 'P')
                    .substring(0, 1)
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: forest,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    api.user?['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '+91 ${api.user?['phone']}',
                    style: const TextStyle(
                      color: Color(0xffb7cdbf),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit name',
              onPressed: editName,
              icon: const Icon(Icons.edit_outlined, color: lime),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: const Text('Saved places'),
              subtitle: Text('${places.length} saved addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: savedPlaces,
            ),
            const Divider(height: 1, indent: 18, endIndent: 18),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Visit updates'),
              subtitle: const Text('Your activity, here in the app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: notifications,
            ),
            const Divider(height: 1, indent: 18, endIndent: 18),
            SwitchListTile(
              value: prefs['reduced_motion'] == true,
              onChanged: (v) => preference({'reduced_motion': v}),
              secondary: const Icon(Icons.animation),
              title: const Text('Reduce motion'),
              subtitle: const Text('A calmer visual experience'),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 16),
    Panel(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.support_agent),
        title: const Text('Help & charging guide'),
        subtitle: const Text('Get ready for a smoother visit'),
        trailing: const Icon(Icons.chevron_right),
        onTap: help,
      ),
    ),
    if (api.signedIn)
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: OutlinedButton(
          onPressed: () async {
            await api.signOut();
            if (mounted) setState(() => tab = 0);
          },
          child: const Text('Sign out'),
        ),
      ),
    const SizedBox(height: 20),
    Notice(
      api.isPreview
          ? 'Local pilot · sample visits and prices. Payments use Razorpay Test. Updates are technician-reported, not live charger telemetry. This preview does not dispatch a real charging vehicle.'
          : 'Your bookings are saved securely. Vehicle location comes from your assigned technician. Payments currently use Razorpay Test; no money is collected.',
    ),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 54,
      titleSpacing: 18,
      title: Row(
        children: [
          Image.asset(
            'assets/pvg-logo.webp',
            width: 42,
            height: 34,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PVG EV',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Doorstep EV charging',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Visit updates',
          onPressed: notifications,
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: forest,
            label: Text(
              unread > 9 ? '9+' : '$unread',
              style: const TextStyle(color: lime),
            ),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: MotionEntrance(
        key: ValueKey(tab),
        disabled: reduceMotion,
        child: ListView(
          key: PageStorageKey('customer-tab-$tab'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Notice(error!, error: true),
              TextButton(onPressed: load, child: const Text('Try again')),
            ],
            ...[home, visits, garage, account][tab](),
            if (tab != 0) ...[
              const SizedBox(height: 18),
              Center(
                child: Text(
                  api.isPreview
                      ? 'PVG EV · Local preview'
                      : 'PVG EV · Energy at your doorstep',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      height: 62,
      selectedIndex: tab < 2 ? tab : tab + 1,
      onDestinationSelected: (i) {
        if (i == 2) {
          bookHome();
        } else {
          setState(() => tab = i < 2 ? i : i - 1);
        }
      },
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'My visits',
        ),
        NavigationDestination(
          icon: Container(
            width: 36,
            height: 32,
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: forest, size: 21),
          ),
          label: 'Book',
        ),
        NavigationDestination(
          icon: Icon(Icons.electric_car_outlined),
          selectedIcon: Icon(Icons.electric_car),
          label: 'Garage',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'You',
        ),
      ],
    ),
  );
}

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key, required this.api, required this.onOpen});
  final PvgApi api;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  List<Map<String, dynamic>> items = [];
  String? readAt, error;
  bool loading = true, marking = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait<dynamic>([
        widget.api.bookings(),
        widget.api.request('/preferences'),
      ]);
      final next = <Map<String, dynamic>>[];
      for (final b in results[0]) {
        for (final e in b['events']) {
          next.add({...Map<String, dynamic>.from(e), 'booking': b});
        }
      }
      next.sort(
        (a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String),
      );
      items = next;
      readAt = results[1]['updates_read_at'];
      error = null;
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> mark() async {
    setState(() => marking = true);
    try {
      await widget.api.request('/updates/read', data: {});
      await load();
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => marking = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your updates')),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Kicker('STAY IN THE LOOP'),
          const SizedBox(height: 10),
          const Text(
            'A clear picture.\nEvery step.',
            style: TextStyle(
              fontSize: 23,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Visit activity appears here when you refresh. These are in-app updates, not push notifications.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: marking ? null : mark,
              child: const Text('Mark all as read'),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Notice(error!, error: true),
          if (!loading && items.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none,
              title: 'All quiet for now.',
              text: 'Your first booking will start your activity timeline.',
            ),
          for (final e in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color:
                    readAt == null ||
                        DateTime.parse(
                          e['created_at'],
                        ).isAfter(DateTime.parse(readAt!))
                    ? softLime
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: const Icon(Icons.bolt_outlined),
                  title: Text(
                    eventLabel(e['action']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${e['booking']['reference']} · ${timeLabel(e['created_at'])}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await widget.onOpen(e['booking']);
                    await load();
                  },
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
