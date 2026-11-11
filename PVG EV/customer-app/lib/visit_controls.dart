import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';
import 'visit_schedule.dart';
import 'location_picker.dart';
import 'location_validation.dart';

class VisitControls extends StatefulWidget {
  const VisitControls({
    super.key,
    required this.api,
    required this.booking,
    required this.onChanged,
  });
  final PvgApi api;
  final Map<String, dynamic> booking;
  final Future<void> Function() onChanged;
  @override
  State<VisitControls> createState() => _VisitControlsState();
}

class _VisitControlsState extends State<VisitControls> {
  bool busy = false;
  String? error;
  Future<void> send(String path, Map<String, dynamic> value) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
        '/bookings/${widget.booking['id']}/$path',
        data: {'version': widget.booking['version'], ...value},
      );
      await widget.onChanged();
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> reschedule() async {
    if (VisitSchedule.from(widget.api.config?['service']) == null) {
      try {
        await widget.api.loadConfig();
      } catch (e) {
        if (mounted) setState(() => error = errorText(e));
        return;
      }
    }
    if (!mounted) return;
    final hours = VisitSchedule.from(widget.api.config?['service']);
    if (hours == null) {
      setState(
        () =>
            error = 'PVG service hours could not be loaded. Please try again.',
      );
      return;
    }
    final today = indiaCalendarDay(DateTime.now());
    final day = await showDatePicker(
      context: context,
      helpText: 'Choose visit date · India time',
      currentDate: today,
      firstDate: today,
      lastDate: visitCalendarDayAfter(today, 30),
      initialDate: visitCalendarDayAfter(today, 1),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      helpText: 'Visit time · India (IST)',
      initialTime: hours.initialTime,
    );
    if (time == null || !mounted) return;
    final slot = indiaVisitInstant(day, time);
    final problem = hours.validate(slot);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request a new visit time?'),
        content: Text(
          '${timeLabel(slot.toIso8601String())}\n\nPVG will reconfirm your charging team. Any existing assignment will be released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep current time'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request new time'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await send('reschedule', {'slot': slot.toUtc().toIso8601String()});
    }
  }

  Future<void> updatePin() async {
    final pin = await pickChargingPin(
      context,
      latitude: (widget.booking['latitude'] as num?)?.toDouble(),
      longitude: (widget.booking['longitude'] as num?)?.toDouble(),
    );
    if (pin == null || !mounted) return;
    await send('location', {
      'latitude': pin.latitude,
      'longitude': pin.longitude,
    });
  }

  Future<void> support() async {
    String message = '';
    String category = 'arrival';
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Help with this visit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'What do you need help with?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'arrival',
                      child: Text('Arrival or delay'),
                    ),
                    DropdownMenuItem(
                      value: 'location',
                      child: Text('Address or parking'),
                    ),
                    DropdownMenuItem(
                      value: 'charging',
                      child: Text('Charging visit'),
                    ),
                    DropdownMenuItem(
                      value: 'payment',
                      child: Text('Bill or payment'),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Something else'),
                    ),
                  ],
                  onChanged: (v) => update(() => category = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Tell PVG what happened',
                  ),
                  onChanged: (value) => update(() => message = value),
                ),
                const Text(
                  'Your booking reference is attached automatically.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: message.trim().length < 5
                  ? null
                  : () => Navigator.pop(ctx, {
                      'category': category,
                      'message': message.trim(),
                    }),
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) await send('support', value);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking, ticket = b['support_request'];
    final latitude = b['latitude'] as num?, longitude = b['longitude'] as num?;
    final hasPin = latitude != null || longitude != null;
    final pinNeedsCorrection =
        hasPin &&
        (latitude == null ||
            longitude == null ||
            !isChennaiPin(latitude, longitude));
    final canChangeVisit = ['requested', 'assigned'].contains(b['status']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (b['service_note'] != null)
          Notice('From your charging team: ${b['service_note']['message']}'),
        if (b['failure_reason'] != null)
          Notice('Visit could not proceed: ${b['failure_reason']}'),
        if (pinNeedsCorrection)
          Notice(
            canChangeVisit
                ? 'Your saved parking pin is outside the Chennai area. Update or remove it so your team has the correct destination.'
                : 'Your saved parking pin needs correction. Contact PVG support to confirm your parking entrance.',
            error: true,
          ),
        if (canChangeVisit) ...[
          TextButton.icon(
            onPressed: busy ? null : reschedule,
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('Change visit time'),
          ),
          TextButton.icon(
            onPressed: busy ? null : updatePin,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: Text(hasPin ? 'Update parking pin' : 'Add parking pin'),
          ),
          if (hasPin)
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () =>
                        send('location', {'latitude': null, 'longitude': null}),
              icon: const Icon(Icons.location_off_outlined, size: 18),
              label: const Text('Remove parking pin'),
            ),
        ],
        if (ticket != null)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support · ${ticket['status'] == 'in_progress'
                      ? 'In progress'
                      : ticket['status'] == 'resolved'
                      ? 'Resolved'
                      : 'Request received'}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(ticket['message'], style: const TextStyle(fontSize: 13)),
                if (ticket['response'] != null) ...[
                  const Divider(height: 24),
                  Text(
                    'PVG: ${ticket['response']}',
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ],
            ),
          ),
        if (ticket == null || ticket['status'] == 'resolved')
          TextButton.icon(
            onPressed: busy ? null : support,
            icon: const Icon(Icons.support_agent, size: 18),
            label: const Text('Send a support request'),
          ),
        if (error != null) Notice(error!, error: true),
      ],
    );
  }
}
