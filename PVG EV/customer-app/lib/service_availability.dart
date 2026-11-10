import 'package:flutter/material.dart';
import 'api.dart';
import 'ui.dart';

class ServiceAvailability extends StatefulWidget {
  const ServiceAvailability({
    super.key,
    required this.api,
    required this.onBook,
  });
  final PvgApi api;
  final VoidCallback onBook;
  @override
  State<ServiceAvailability> createState() => _ServiceAvailabilityState();
}

class _ServiceAvailabilityState extends State<ServiceAvailability> {
  final pin = TextEditingController();
  Map<String, dynamic>? result;
  String? error;
  bool busy = false, expanded = false;
  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> check() async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin.text.trim())) {
      setState(() => error = 'Enter a six-digit pincode.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final value = await widget.api.request(
        '/availability?pincode=${pin.text.trim()}',
      );
      if (mounted) setState(() => result = value);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Panel(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_outlined, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '6:00 AM – 11:00 PM',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(expanded ? 'Close' : 'Check area'),
            ),
          ],
        ),
        const Text(
          'Chennai doorstep visits · time confirmed by PVG',
          style: TextStyle(fontSize: 12, color: muted),
        ),
        if (expanded) ...[
          const SizedBox(height: 14),
          TextField(
            controller: pin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Your charging pincode',
              counterText: '',
            ),
            onSubmitted: (_) => check(),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            'Check availability',
            busy: busy,
            onPressed: check,
            icon: Icons.search,
          ),
          if (error != null) Notice(error!, error: true),
          if (result != null) Notice(result!['message'] as String),
        ],
      ],
    ),
  );
}
