import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'visit_controls.dart';
import 'ui.dart';
import 'experience.dart';
import 'personal_screens.dart';
import 'tracking_experience.dart';

class BookingDetail extends StatefulWidget {
  const BookingDetail({super.key, required this.api, required this.bookingId});
  final PvgApi api;
  final String bookingId;
  @override
  State<BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends State<BookingDetail>
    with WidgetsBindingObserver {
  Map<String, dynamic>? booking;
  String? error;
  bool busy = false, accepted = false, evidenceReady = false;
  bool fetching = false;
  Timer? timer;
  StreamSubscription<Map<String, dynamic>>? liveUpdates;
  bool liveDisconnected = false;
  PvgApi get api => widget.api;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    liveUpdates = api.changes.listen((event) {
      if (!mounted) return;
      if (event['kind'] == 'connection_lost') {
        setState(() => liveDisconnected = true);
        return;
      }
      if (['connected', 'reconnected'].contains(event['kind'])) {
        setState(() => liveDisconnected = false);
        load();
        return;
      }
      if (event['booking_id'] == widget.bookingId) {
        if (event['kind'] == 'booking_tracking') {
          refreshTracking();
        } else if (!busy) {
          load();
        }
      }
    });
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!busy &&
          mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          [
            'requested',
            'assigned',
            'on_the_way',
            'arrived',
            'charging',
            'disputed',
          ].contains(booking?['status'])) {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    liveUpdates?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) load();
  }

  Future<void> load() async {
    if (fetching) return;
    fetching = true;
    try {
      final b = await api.request('/bookings/${widget.bookingId}');
      if (booking?['reading']?['id'] != b['reading']?['id'] ||
          booking?['version'] != b['version']) {
        accepted = false;
      }
      booking = b;
      evidenceReady = false;
      if (b['reading'] != null) {
        for (final data in [
          b['reading']['photo'],
          if (b['reading']['start_photo'] != null) b['reading']['start_photo'],
        ]) {
          final codec = await ui.instantiateImageCodec(
            base64Decode((data as String).split(',').last),
          );
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          codec.dispose();
        }
        evidenceReady = true;
      }
      error = null;
    } catch (e) {
      error = errorText(e);
    }
    fetching = false;
    if (mounted) setState(() {});
  }

  Future<void> refreshTracking() async {
    if (booking == null) return;
    try {
      final tracking = await api.request(
        '/bookings/${widget.bookingId}/tracking',
      );
      if (mounted) {
        setState(() {
          booking = {...booking!, 'tracking': tracking};
          liveDisconnected = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => liveDisconnected = true);
    }
  }

  Future<void> action(String route, Map<String, dynamic> data) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.request('/bookings/${widget.bookingId}/$route', data: data);
      await load();
    } catch (e) {
      error = errorText(e);
      await loadWithoutClearingError();
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> loadWithoutClearingError() async {
    try {
      booking = await api.request('/bookings/${widget.bookingId}');
      accepted = false;
    } catch (_) {}
  }

  Future<void> accept() async {
    final b = booking!;
    await action('accept', {
      'version': b['version'],
      'reading_id': b['reading']['id'],
      'total_paise': b['reading']['bill']['total_paise'],
      'accepted': accepted,
    });
  }

  Future<void> dispute() async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tell us what doesn’t match'),
        content: TextField(
          controller: reason,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Describe the reading or charge you want checked.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reason.text.trim()),
            child: const Text('Send to PVG'),
          ),
        ],
      ),
    );
    if (value != null) {
      await action('dispute', {
        'version': booking!['version'],
        'reason': value,
      });
    }
  }

  Future<void> pay() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final order = await api.request(
        '/bookings/${widget.bookingId}/payment-order',
        data: {},
      );
      if (!mounted) return;
      if (order['checkout_url'] != null) {
        final opened = await launchUrl(
          Uri.parse(order['checkout_url']),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
        if (!opened) throw Exception('Unable to open checkout. Try again.');
        if (mounted) {
          showMessage(
            context,
            'Complete test checkout, then tap Check payment status.',
          );
        }
      } else {
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Local test checkout'),
            content: Text(
              '${money(order['amount_paise'])}\n\nNo money will be collected. Choose a result to test the booking workflow.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'failure'),
                child: const Text('Test failure'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'success'),
                child: const Text('Test success'),
              ),
            ],
          ),
        );
        if (result != null) {
          await api.request(
            '/test-payments/${order['id']}',
            data: {'result': result},
          );
          if (result == 'failure') {
            throw Exception('Test payment failed. You can try again.');
          }
        }
      }
      await load();
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> receipt() async {
    setState(() => busy = true);
    try {
      final bytes = await api.receipt(widget.bookingId);
      await FilePicker.saveFile(
        dialogTitle: 'Save test receipt',
        fileName: '${booking!['reference']}-test-receipt.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: bytes,
      );
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget photo(String data, String caption) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(caption, style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          base64Decode(data.split(',').last),
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, e, s) => const Notice(
            'Photo could not be loaded. Refresh before accepting.',
            error: true,
          ),
        ),
      ),
      const SizedBox(height: 15),
      TextButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (ctx) => Dialog.fullscreen(
            backgroundColor: midnight,
            child: SafeArea(
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      caption,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Pinch or scroll to zoom',
                      style: TextStyle(color: lime),
                    ),
                    trailing: IconButton(
                      tooltip: 'Close photo',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: .7,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          base64Decode(data.split(',').last),
                          semanticLabel: caption,
                          errorBuilder: (_, e, s) => const Notice(
                            'Photo could not be loaded.',
                            error: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        icon: const Icon(Icons.zoom_in),
        label: const Text('Inspect meter photo'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          travellingStatuses.contains(b?['status'])
              ? 'Track my charging vehicle'
              : b?['reference'] ?? 'Your booking',
        ),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh booking',
          ),
        ],
      ),
      body: b == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Notice(error!, error: true),
                    ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
                children: [
                  if (travellingStatuses.contains(b['status'])) ...[
                    TrackingExperience(
                      booking: b,
                      connectionLost: error != null || liveDisconnected,
                      onRefresh: load,
                    ),
                    const SizedBox(height: 18),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(b['status']),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      b['status'] == 'awaiting_acceptance'
                          ? 'Review your charge'
                          : b['status'] == 'paid'
                          ? 'All charged up.'
                          : b['status'] == 'on_the_way'
                          ? 'Your energy is on its way.'
                          : b['status'] == 'requested'
                          ? 'Let’s plan your recharge.'
                          : 'Your doorstep visit',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.6,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      {
                            'requested':
                                'Your request is saved. PVG will confirm availability and assign your charging team.',
                            'assigned':
                                'Your charging team is assigned. Their location appears as soon as they start GPS sharing.',
                            'on_the_way':
                                'Follow your charging vehicle here. Keep your parking space accessible for arrival.',
                            'arrived':
                                'Your technician is at the location. They will check compatibility before starting the charge.',
                            'charging':
                                'Your technician is charging your EV. The delivered units and meter photo will be ready for your review when charging ends.',
                            'awaiting_acceptance':
                                'Check the technician’s photo, delivered units and total. You decide when the bill is ready to pay.',
                            'awaiting_payment':
                                'You’ve accepted these units and charges. Your bill is locked and ready for payment.',
                            'paid':
                                'Test payment verified. Your receipt is ready.',
                            'disputed':
                                'PVG has received your concern. The technician can correct the reading for you to review.',
                          }[b['status']] ??
                          'Pull down to refresh the latest update from your technician.',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    VisitProgress(booking: b),
                    const SizedBox(height: 18),
                  ],
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['ev']['model'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          b['ev']['registration'],
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        const Divider(height: 28),
                        Text(
                          timeLabel(b['slot']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b['address'],
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                        if (b['technician'] != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Your technician: ${b['technician']['name']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (b['reading'] != null)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Kicker(
                            'CHARGING RECORD · REVISION ${b['reading']['revision']}',
                          ),
                          const SizedBox(height: 16),
                          if (b['reading']['start_photo'] != null)
                            photo(
                              b['reading']['start_photo'],
                              'Starting meter',
                            ),
                          photo(
                            b['reading']['photo'],
                            b['reading']['kind'] == 'cumulative'
                                ? 'Ending meter'
                                : 'Session energy delivered',
                          ),
                          if (b['reading']['kind'] == 'cumulative')
                            Text(
                              '${b['reading']['end_milli'] / 1000} − ${b['reading']['start_milli'] / 1000} = ${b['reading']['bill']['energy_milli'] / 1000} kWh',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if ((b['reading']['notes'] ?? '').isNotEmpty)
                            Notice(b['reading']['notes']),
                          BillLines(
                            Map<String, dynamic>.from(b['reading']['bill']),
                          ),
                        ],
                      ),
                    )
                  else
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Kicker('BILLED AFTER CHARGING'),
                          const SizedBox(height: 10),
                          const Text(
                            'Your bill will appear after the technician submits the delivered units and meter photo. Review and accept it before paying.',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                  if (b['status'] == 'awaiting_acceptance') ...[
                    CheckboxListTile(
                      key: const Key('accept-units-checkbox'),
                      value: accepted,
                      onChanged: busy || !evidenceReady
                          ? null
                          : (v) => setState(() => accepted = v!),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'I accept ${b['reading']['bill']['energy_milli'] / 1000} kWh and the total of ${money(b['reading']['bill']['total_paise'])}.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    PrimaryButton(
                      'Accept units & continue',
                      busy: busy,
                      onPressed: accepted && evidenceReady ? accept : null,
                    ),
                    TextButton(
                      onPressed: busy ? null : dispute,
                      child: const Text('Report a mismatch'),
                    ),
                  ],
                  if (b['status'] == 'awaiting_payment') ...[
                    const SizedBox(height: 20),
                    PrimaryButton(
                      'Pay ${money(b['invoice']['bill']['total_paise'])} · test',
                      busy: busy,
                      icon: Icons.lock_outline,
                      onPressed: pay,
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => action('payment-refresh', {}),
                      child: const Text('Check payment status'),
                    ),
                  ],
                  if (b['status'] == 'paid') ...[
                    const SizedBox(height: 20),
                    PrimaryButton(
                      'Download test receipt',
                      busy: busy,
                      icon: Icons.download_outlined,
                      onPressed: receipt,
                    ),
                  ],
                  if (['requested', 'assigned'].contains(b['status']))
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cancel this visit?'),
                                  content: const Text(
                                    'You can make another request whenever you’re ready.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Keep visit'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Cancel visit'),
                                    ),
                                  ],
                                ),
                              );
                              if (yes == true) {
                                await action('cancel', {
                                  'version': b['version'],
                                });
                              }
                            },
                      child: const Text('Cancel visit'),
                    ),
                  if (api.config?['mode'] == 'supabase')
                    VisitControls(api: api, booking: b, onChanged: load),
                  if (b['dispute'] != null)
                    Notice('Your concern: ${b['dispute']}'),
                  if (error != null) Notice(error!, error: true),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    ),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Need help with this visit?'),
                  ),
                  const SizedBox(height: 20),
                  const Kicker('VISIT TIMELINE'),
                  const SizedBox(height: 12),
                  ...((b['events'] as List).reversed.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 17,
                            color: muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_events[e['action']] ?? e['action']}\n${timeLabel(e['created_at'])}',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const Notice(
                    'This is a payment summary, not a tax invoice. Official invoices will be available after PVG’s Zoho Books account is connected.',
                  ),
                ],
              ),
            ),
    );
  }
}

const _events = {
  'requested': 'Visit requested',
  'assigned': 'Visit confirmed',
  'on_the_way': 'Technician on the way',
  'arrived': 'Technician arrived',
  'charging': 'Charging started',
  'reading_submitted': 'Reading submitted',
  'customer_accepted': 'You accepted the units and total',
  'customer_reported_issue': 'Issue reported',
  'payment_verified': 'Test payment verified',
  'cancelled': 'Visit cancelled',
};

class VisitProgress extends StatelessWidget {
  const VisitProgress({super.key, required this.booking});
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context) {
    final status = booking['status'];
    final step =
        {
          'requested': 0,
          'assigned': 1,
          'on_the_way': 1,
          'arrived': 1,
          'charging': 2,
          'awaiting_acceptance': 3,
          'disputed': 3,
          'awaiting_payment': 3,
          'paid': 4,
        }[status] ??
        0;
    if (status == 'cancelled') return const SizedBox.shrink();
    return Panel(
      color: forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Kicker('YOUR VISIT, CONNECTED', color: lime),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              4,
              (i) => Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < step
                            ? lime
                            : i == step
                            ? const Color(0xff46694b)
                            : const Color(0xff224438),
                      ),
                      child: Icon(
                        i < step
                            ? Icons.check_rounded
                            : [
                                Icons.event_available,
                                Icons.local_shipping_outlined,
                                Icons.bolt,
                                Icons.receipt_long_outlined,
                              ][i],
                        color: i < step
                            ? forest
                            : i == step
                            ? lime
                            : const Color(0xff9ab5a4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      ['Request', 'Visit', 'Charge', 'Review & pay'][i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: i <= step
                            ? Colors.white
                            : const Color(0xff9ab5a4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xff385a49)),
          const SizedBox(height: 8),
          Text(
            booking['updated_at'] != null
                ? 'Last update · ${timeLabel(booking['updated_at'])}'
                : 'Updates from your PVG technician',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(height: 5),
          const Text(
            'Visit status reported by your technician',
            style: TextStyle(color: Color(0xffb7cdbf), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
