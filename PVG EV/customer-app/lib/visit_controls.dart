import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

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
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    final slot = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!slot.isAfter(now) || time.hour < 6 || time.hour >= 23) {
      setState(
        () => error = 'Choose a future time between 6:00 AM and 11:00 PM.',
      );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (b['service_note'] != null)
          Notice('From your charging team: ${b['service_note']['message']}'),
        if (b['failure_reason'] != null)
          Notice('Visit could not proceed: ${b['failure_reason']}'),
        if (['requested', 'assigned'].contains(b['status']))
          TextButton.icon(
            onPressed: busy ? null : reschedule,
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: const Text('Change visit time'),
          ),
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
