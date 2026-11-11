import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:url_launcher/url_launcher.dart';
import 'ui.dart';
import 'experience.dart' show eventLabel;
import 'visit_tracking.dart';
import 'update_presentation.dart' show customerUpdateNote;

const travellingStatuses = {
  'requested',
  'assigned',
  'on_the_way',
  'arrived',
  'charging',
};

/// Built from the authorised visit. Unavailable people and GPS stay unconfigured.
class TrackingExperience extends StatelessWidget {
  const TrackingExperience({
    super.key,
    this.booking,
    this.onDetails,
    this.onBook,
    this.onRefresh,
    this.connectionLost = false,
    this.tileProvider,
  });
  final Map<String, dynamic>? booking;
  final VoidCallback? onDetails, onBook, onRefresh;
  final bool connectionLost;
  final TileProvider? tileProvider;

  Future<void> call(BuildContext context, String phone) async {
    final safe = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(safe)) {
      return;
    }
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: safe)) && context.mounted) {
        showMessage(context, 'Could not open your phone app. Call $safe.');
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not open your phone app. Call $safe.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking, status = b?['status'] as String?;
    final travelling = b != null && travellingStatuses.contains(status);
    final title = switch (status) {
      'requested' => 'We’ve received your request.',
      'assigned' => 'Your charging team is assigned.',
      'on_the_way' => 'Your charging vehicle is on the way.',
      'arrived' => 'Your charging team has arrived.',
      'charging' => 'Your EV is being charged.',
      'awaiting_acceptance' => 'Your charge is ready to review.',
      'awaiting_payment' => 'Your bill is ready to pay.',
      'disputed' => 'We’re checking your concern.',
      'paid' => 'Your charging visit is complete.',
      'cancelled' => 'This visit was cancelled.',
      _ => 'Your next charging visit.',
    };
    final copy = switch (status) {
      'requested' => 'PVG will confirm your time and charging team.',
      'assigned' => 'Follow their shared location below.',
      'on_the_way' => 'Keep your parking space accessible.',
      'arrived' => 'Your technician will check access and compatibility.',
      'charging' => 'Meter evidence follows when charging is complete.',
      'awaiting_acceptance' => 'Review the meter photo, units and final bill.',
      'awaiting_payment' => 'Your accepted bill is ready for payment.',
      'disputed' => 'PVG will respond before you accept a corrected bill.',
      'paid' => 'Your receipt and visit record are available.',
      'cancelled' => 'The record of this visit stays in your history.',
      _ => 'Book a visit to follow your real charging team here.',
    };
    final action = switch (status) {
      'requested' => 'Manage request',
      'assigned' => 'Manage visit',
      'awaiting_acceptance' => 'Review units & bill',
      'awaiting_payment' => 'Continue to payment',
      'disputed' => 'View your concern',
      'paid' => 'View receipt',
      _ => 'View booking details',
    };
    final tech = b?['technician'] as Map?;
    final phone = tech?['phone'] as String?;
    final events = (b?['events'] as List? ?? [])
        .where((e) => !['gps_started', 'gps_stopped'].contains(e['action']))
        .toList()
        .reversed
        .take(3)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const Key('tracking-status'),
                padding: const EdgeInsets.all(12),
                color: forest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          b?['reference'] ?? 'DOORSTEP CHARGING',
                          style: const TextStyle(
                            color: lime,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                        if (b?['slot'] != null)
                          Text(
                            '${status == 'requested' ? 'Preferred' : 'Visit'} · ${timeLabel(b!['slot'])} IST',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xffd3e2da),
                            ),
                          ),
                        if (connectionLost)
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    MotionEntrance(
                      key: ValueKey(status ?? 'no-visit'),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (!travelling || status == 'requested') ...[
                      const SizedBox(height: 4),
                      Text(
                        copy,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xffd3e2da),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (travelling)
                VisitTracking(
                  key: ValueKey('visit-map-${b['id']}'),
                  booking: b,
                  connectionLost: connectionLost,
                  onRefresh: onRefresh,
                  prominent: true,
                  embedded: true,
                  showIdentity: false,
                  tileProvider: tileProvider,
                )
              else if (b == null)
                const _WaitingMap(),
            ],
          ),
        ),
        if (onDetails != null) ...[
          const SizedBox(height: 10),
          Align(
            key: const Key('visit-next-action'),
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              action,
              onPressed: onDetails,
              icon: {'awaiting_acceptance', 'awaiting_payment'}.contains(status)
                  ? Icons.receipt_long_outlined
                  : Icons.arrow_forward_rounded,
            ),
          ),
        ],
        if (b == null && onBook != null) ...[
          const SizedBox(height: 10),
          PrimaryButton(
            'Book doorstep charging',
            onPressed: onBook,
            icon: Icons.bolt_rounded,
          ),
        ],
        const SizedBox(height: 10),
        Panel(
          key: const Key('visit-team'),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xffedf5dc),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      tech == null
                          ? Icons.person_search_outlined
                          : Icons.person_outline,
                      color: forest,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tech?['name'] ?? 'Technician not assigned',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tech == null
                              ? 'Waiting for PVG confirmation'
                              : 'Your PVG charging team',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (phone != null && phone.isNotEmpty)
                    IconButton(
                      tooltip: 'Call technician',
                      onPressed: () => call(context, phone),
                      icon: const Icon(Icons.call_outlined, size: 19),
                    ),
                  IconButton(
                    tooltip: 'PVG support',
                    onPressed: () => call(context, '+919751083000'),
                    icon: const Icon(Icons.support_agent, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    color: muted,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      children: [
                        Text(
                          b?['fleet_name'] ?? 'Charging vehicle not assigned',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (b?['fleet_registration'] != null)
                          Text(
                            b!['fleet_registration'],
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (b != null) ...[
                const Divider(height: 20, color: line),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b['address'] ?? '',
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
                if ((b['access_notes'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 25),
                    child: Text(
                      b['access_notes'],
                      style: const TextStyle(
                        fontSize: 11,
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (b != null) ...[
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Kicker('VISIT PROGRESS'),
                const SizedBox(height: 12),
                _VisitMilestones(status: status ?? ''),
                const SizedBox(height: 12),
                if (events.isEmpty)
                  const Text(
                    'Your next update will appear here.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                for (var i = 0; i < events.length; i++)
                  _event(events[i], latest: i == 0),
                if (connectionLost && !travelling)
                  const Notice(
                    'Connection interrupted. Showing the last received update; reconnecting.',
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'Location is shared by your technician. Visit status is reported by the team.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 10, height: 1.4),
        ),
      ],
    );
  }

  Widget _event(dynamic event, {required bool latest}) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            latest ? Icons.radio_button_checked : Icons.check_circle_outline,
            color: latest ? forest : muted,
            size: 15,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventLabel(event['action']),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: latest ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (customerUpdateNote(
                Map<String, dynamic>.from(event),
              ).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    customerUpdateNote(Map<String, dynamic>.from(event)),
                    style: const TextStyle(
                      fontSize: 12,
                      color: muted,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                timeLabel(event['created_at']),
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VisitMilestones extends StatelessWidget {
  const _VisitMilestones({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const Text(
        'Visit cancelled',
        style: TextStyle(fontSize: 12, color: muted),
      );
    }
    final step = switch (status) {
      'requested' => 0,
      'assigned' || 'on_the_way' || 'arrived' => 1,
      'charging' => 2,
      'awaiting_acceptance' || 'awaiting_payment' || 'disputed' => 3,
      'paid' => 4,
      _ => -1,
    };
    const labels = ['Request', 'Visit', 'Charge', 'Review'];
    final duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
    );
    return Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
            child: Semantics(
              label:
                  '${labels[i]}: ${i < step
                      ? 'complete'
                      : i == step
                      ? 'current'
                      : 'pending'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < step
                          ? forest
                          : i == step
                          ? lime
                          : line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      color: i <= step ? forest : muted,
                      fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const statusLabels = {
  'requested': 'Booking requested',
  'assigned': 'Vehicle & technician assigned',
  'on_the_way': 'On the way',
  'arrived': 'Arrived at your location',
  'charging': 'Charging started',
  'reading_submitted': 'Units & meter photo ready',
  'awaiting_acceptance': 'Ready for your review',
  'customer_accepted': 'You accepted the bill',
  'awaiting_payment': 'Ready for payment',
  'customer_reported_issue': 'Your concern was received',
  'disputed': 'PVG is reviewing your concern',
  'payment_verified': 'Payment verified',
  'cancelled': 'Visit cancelled',
};

class _WaitingMap extends StatelessWidget {
  const _WaitingMap();
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 190),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xffe7eee8),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.location_searching_rounded, color: forest, size: 30),
        SizedBox(height: 16),
        Text(
          'Your live map starts with a booking.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8),
        Text(
          'No active booking yet. We’ll show your actual destination and shared vehicle location here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: muted, height: 1.5),
        ),
      ],
    ),
  );
}

class EmptyTrackingScreen extends StatelessWidget {
  const EmptyTrackingScreen({super.key, required this.onBook});
  final VoidCallback onBook;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Track my charging vehicle')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [TrackingExperience(onBook: onBook)],
    ),
  );
}
