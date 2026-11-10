import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'ui.dart';
import 'experience.dart';

Future<Position> locateCustomer() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception(
      'Turn on location services, or enter your address manually.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception(
      'Location permission was not granted. You can still enter an address.',
    );
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

Future<bool?> editPlace(
  BuildContext context,
  PvgApi api, [
  Map<String, dynamic>? place,
]) => Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => PlaceEditor(api: api, place: place),
  ),
);

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key, required this.api});
  final PvgApi api;
  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<Map<String, dynamic>> places = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.api.request('/places');
      places = (result['places'] as List)
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      error = null;
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> edit([Map<String, dynamic>? place]) async {
    if (await editPlace(context, widget.api, place) == true) await load();
  }

  Future<void> remove(Map<String, dynamic> p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${p['label']}?'),
        content: const Text('Existing visits keep their original address.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep place'),
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
      await widget.api.request('/places/${p['id']}/delete', data: {});
      await load();
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved places')),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Kicker('A SHORTCUT TO YOUR EVERYDAY'),
          const SizedBox(height: 12),
          const Text(
            'Your places.\nYour convenience.',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Save home, work or a regular parking spot. Your access instructions come along too.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Notice(error!, error: true),
          for (final p in places)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p['label'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit ${p['label']}',
                          onPressed: () => edit(p),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remove ${p['label']}',
                          onPressed: () => remove(p),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    Text(
                      '${p['address']}\n${p['pincode']}',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    if ((p['access_notes'] as String).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          p['access_notes'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!loading && places.isEmpty)
            const EmptyState(
              icon: Icons.add_location_alt_outlined,
              title: 'One less thing to type.',
              text: 'Add your first charging address to use it again in a tap.',
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            'Add a place',
            onPressed: () => edit(),
            icon: Icons.add,
          ),
        ],
      ),
    ),
  );
}

class PlaceEditor extends StatefulWidget {
  const PlaceEditor({super.key, required this.api, this.place});
  final PvgApi api;
  final Map<String, dynamic>? place;
  @override
  State<PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<PlaceEditor> {
  final form = GlobalKey<FormState>();
  final label = TextEditingController(),
      address = TextEditingController(),
      pin = TextEditingController(),
      notes = TextEditingController();
  double? latitude, longitude;
  bool busy = false, locating = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.place;
    label.text = p?['label'] ?? '';
    address.text = p?['address'] ?? '';
    pin.text = p?['pincode'] ?? '';
    notes.text = p?['access_notes'] ?? '';
    latitude = (p?['latitude'] as num?)?.toDouble();
    longitude = (p?['longitude'] as num?)?.toDouble();
  }

  @override
  void dispose() {
    for (final c in [label, address, pin, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void clearCoordinates(String _) => setState(() {
    latitude = null;
    longitude = null;
  });
  Future<void> gps() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      final p = await locateCustomer();
      latitude = p.latitude;
      longitude = p.longitude;
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => locating = false);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
        widget.place == null ? '/places' : '/places/${widget.place!['id']}',
        data: {
          'label': label.text.trim(),
          'address': address.text.trim(),
          'pincode': pin.text.trim(),
          'access_notes': notes.text.trim(),
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.place == null ? 'Add a place' : 'Edit place'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Wrap(
            spacing: 8,
            children: ['Home', 'Work', 'Other']
                .map(
                  (s) => ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => label.text = s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: label,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Place name'),
            validator: (v) =>
                v!.trim().length < 2 ? 'Give this place a name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: address,
            onChanged: clearCoordinates,
            maxLength: 400,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Full address & landmark',
            ),
            validator: (v) =>
                v!.trim().length < 8 ? 'Enter a complete address' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: pin,
            onChanged: clearCoordinates,
            maxLength: 6,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Chennai pincode'),
            validator: (v) => !RegExp(r'^600\d{3}$').hasMatch(v!.trim())
                ? 'Use a Chennai pincode (600xxx)'
                : null,
          ),
          TextFormField(
            controller: notes,
            maxLines: 2,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Parking / access instructions (optional)',
            ),
          ),
          OutlinedButton.icon(
            onPressed: locating ? null : gps,
            icon: Icon(
              latitude == null ? Icons.my_location : Icons.check_circle_outline,
            ),
            label: Text(
              locating
                  ? 'Finding your location…'
                  : latitude == null
                  ? 'Attach my current GPS location'
                  : 'GPS attached · update',
            ),
          ),
          if (latitude != null)
            TextButton(
              onPressed: () => clearCoordinates(''),
              child: const Text('Remove GPS location'),
            ),
          const Notice(
            'GPS is optional. Attach it only when you are at this address. Editing the address clears the pin so it cannot point to an old location.',
          ),
          if (error != null) Notice(error!, error: true),
          PrimaryButton(
            'Save place',
            onPressed: locating ? null : save,
            busy: busy,
          ),
        ],
      ),
    ),
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  Future<void> contact(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception(
          'Could not open this option. Contact PVG on +91 97510 83000.',
        );
      }
    } catch (e) {
      if (context.mounted) showMessage(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Here to help')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Panel(
          color: forest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.support_agent, color: lime, size: 36),
              const SizedBox(height: 18),
              const Text(
                'A little guidance.\nA smoother charge.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Questions about your vehicle or a visit? Talk to the PVG team.',
                style: TextStyle(color: Color(0xffb7cdbf)),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                'Call PVG',
                onPressed: () =>
                    contact(context, Uri.parse('tel:+919751083000')),
                icon: Icons.call_outlined,
              ),
              TextButton(
                onPressed: () => contact(
                  context,
                  Uri.https('wa.me', '919751083000', {
                    'text': 'Hello PVG, I need help with mobile EV charging.',
                  }),
                ),
                child: const Text(
                  'Open WhatsApp',
                  style: TextStyle(color: lime),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('Before your visit'),
        for (final item in [
          (
            Icons.local_parking_outlined,
            'Choose accessible parking',
            'Leave room for the charging vehicle. Share gates, floor levels and parking restrictions in your booking.',
          ),
          (
            Icons.electric_car_outlined,
            'Check your connector',
            'Find the connector in your vehicle manual. Choose “Not sure” if needed; PVG confirms compatibility before the visit.',
          ),
          (
            Icons.fact_check_outlined,
            'You check the final reading',
            'Inspect the meter photo and delivered kWh. Accept the itemized bill, or report a mismatch before paying.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$1),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.$3,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SectionTitle('Good questions'),
        for (final qa in [
          (
            'What does kWh mean?',
            'kWh is the energy delivered to your battery. kW is the speed at which energy is supplied. Your final energy charge uses the delivered kWh shown in the technician’s evidence.',
          ),
          (
            'When is my bill calculated?',
            'After charging, your technician submits the meter photo and delivered units. Your bill is calculated automatically using the agreed charging rate, visit fee and tax. Review and accept the units before paying.',
          ),
          (
            'Can I see the charging van on a map?',
            'Not yet. Visit stages are updated by your technician. The app does not currently receive vehicle GPS or live charger telemetry from Setrans.',
          ),
          (
            'Can I change or cancel a visit?',
            'You can cancel a requested or confirmed visit before departure from the visit details. For a time change or a job already in progress, contact PVG with your visit reference.',
          ),
          (
            'What if my reading looks wrong?',
            'Choose “Report a mismatch” in the visit details before accepting. The technician can correct the evidence. There is no automatic admin approval step before your payment.',
          ),
          (
            'How does test payment work?',
            'After you accept the units and bill, Razorpay Test checkout opens. No real money is collected. The app marks a bill paid only after the server verifies payment. Return to the visit and tap “Check payment status” if needed.',
          ),
        ])
          Card(
            elevation: 0,
            color: Colors.white,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                qa.$1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: [
                Text(qa.$2, style: const TextStyle(color: muted, fontSize: 13)),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    ),
  );
}
