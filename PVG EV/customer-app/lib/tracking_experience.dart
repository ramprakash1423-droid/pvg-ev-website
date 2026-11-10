import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui.dart';
import 'visit_tracking.dart';

const travellingStatuses = {
  'requested',
  'assigned',
  'on_the_way',
  'arrived',
  'charging',
};

/// Built entirely from an authorised booking. Missing data stays explicitly missing.
class TrackingExperience extends StatelessWidget {
  const TrackingExperience({
    super.key,
    this.booking,
    this.onDetails,
    this.onBook,
    this.onRefresh,
    this.connectionLost = false,
  });
  final Map<String, dynamic>? booking;
  final VoidCallback? onDetails, onBook, onRefresh;
  final bool connectionLost;

  Future<void> call(BuildContext context, String phone) async {
    final safe = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(safe)) return;
    if (!await launchUrl(Uri(scheme: 'tel', path: safe)) && context.mounted) {
      showMessage(context, 'Could not open your phone app. Call $safe.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = booking, status = b?['status'];
    final title = switch (status) {
      'requested' => 'We’ve received your request.',
      'assigned' => 'Your charging team is assigned.',
      'on_the_way' => 'Your energy is on its way.',
      'arrived' => 'Your charging team has arrived.',
      'charging' => 'Your EV is being charged.',
      'awaiting_acceptance' => 'Your charge is ready to review.',
      'awaiting_payment' => 'Your bill is ready to pay.',
      'disputed' => 'We’re checking your concern.',
      _ => 'Your next charge. Every step in view.',
    };
    final copy = switch (status) {
      'requested' =>
        'PVG will confirm your time and assign a charging vehicle. No vehicle has been dispatched yet.',
      'assigned' =>
        'Your confirmed visit is below. The map updates when your technician shares their location.',
      'on_the_way' =>
        'Follow the latest position shared by your assigned technician. We’ll show when they arrive.',
      'arrived' =>
        'Your technician will check parking access and connector compatibility before charging.',
      'charging' =>
        'Your technician will send the delivered units and meter photo when charging finishes.',
      'awaiting_acceptance' =>
        'Check the meter evidence, units and final charges. Payment follows your acceptance.',
      'awaiting_payment' =>
        'You accepted the reading and charges. Open your bill to complete payment.',
      'disputed' =>
        'PVG has received your concern. You’ll review any corrected reading before paying.',
      _ =>
        'Book a doorstep visit to see your assigned team, charging vehicle and live location here.',
    };
    final tech = b?['technician'] as Map?;
    final phone = tech?['phone'] as String?;
    final events = (b?['events'] as List? ?? [])
        .where((e) => statusLabels.containsKey(e['action']))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route_rounded, color: lime, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b?['reference'] ?? 'TRACK MY CHARGING VEHICLE',
                      style: const TextStyle(
                        color: lime,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  if (connectionLost)
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              MotionEntrance(
                key: ValueKey(status ?? 'no-booking'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      copy,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: Color(0xffd3e2da),
                      ),
                    ),
                  ],
                ),
              ),
              if (b != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(
                      statusLabels[status] ?? status ?? '',
                      Icons.circle_outlined,
                    ),
                    if (b['slot'] != null)
                      _tag(
                        '${status == 'requested' ? 'Requested' : 'Visit'} · ${timeLabel(b['slot'])}',
                        Icons.schedule,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (b != null && travellingStatuses.contains(status))
          VisitTracking(
            booking: b,
            connectionLost: connectionLost,
            onRefresh: onRefresh,
            prominent: true,
          )
        else if (b == null)
          const _WaitingMap(),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('YOUR CHARGING TEAM'),
              const SizedBox(height: 15),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xffedf5dc),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      tech == null
                          ? Icons.person_search_outlined
                          : Icons.person_outline,
                      color: forest,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tech?['name'] ?? 'Technician not assigned',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tech == null
                              ? 'Details appear after PVG confirms your visit.'
                              : 'Your assigned PVG technician',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 22, color: line),
              _detail(
                Icons.local_shipping_outlined,
                b?['fleet_name'] ?? 'Charging vehicle not assigned',
                b?['fleet_registration'] ??
                    'Registration appears after assignment',
              ),
              if (b != null) ...[
                const SizedBox(height: 17),
                _detail(
                  Icons.location_on_outlined,
                  'Charging at your address',
                  b['address'] ?? '',
                ),
                if ((b['access_notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    b['access_notes'],
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (phone != null && phone.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => call(context, phone),
                      icon: const Icon(Icons.call_outlined, size: 17),
                      label: const Text('Call technician'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => call(context, '+919751083000'),
                    icon: const Icon(Icons.support_agent, size: 17),
                    label: const Text('PVG support'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Kicker('VISIT UPDATES'),
              const SizedBox(height: 12),
              if (events.isEmpty)
                Text(
                  b == null
                      ? 'Your confirmed visit updates will appear here.'
                      : 'Your request is saved. Waiting for the next update from PVG.',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              for (final e in events.reversed.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: forest,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusLabels[e['action']]!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              timeLabel(e['created_at']),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (connectionLost)
                const Notice(
                  'Connection interrupted. Showing the last received update; reconnecting.',
                ),
            ],
          ),
        ),
        if (onDetails != null) ...[
          const SizedBox(height: 14),
          PrimaryButton(
            {
                  'awaiting_acceptance',
                  'awaiting_payment',
                  'disputed',
                }.contains(status)
                ? 'Open units & bill'
                : 'View booking details',
            onPressed: onDetails,
            icon: Icons.arrow_forward_rounded,
          ),
        ],
        if (b == null && onBook != null) ...[
          const SizedBox(height: 14),
          PrimaryButton(
            'Book doorstep charging',
            onPressed: onBook,
            icon: Icons.bolt_rounded,
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Vehicle location is shared by the assigned technician. Visit and charging status are reported by the team.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 10, height: 1.5),
        ),
      ],
    );
  }

  Widget _tag(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xff2c4b3d),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: lime),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
      ],
    ),
  );
  Widget _detail(IconData icon, String title, String detail) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: muted, size: 20),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
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
