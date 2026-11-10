import 'dart:math';
import 'package:flutter/material.dart';
import 'experience.dart';
import 'personal_screens.dart';
import 'api.dart';
import 'booking_detail.dart';
import 'ui.dart';

Future<bool?> showAddEv(
  BuildContext context,
  PvgApi api, {
  Map<String, dynamic>? ev,
}) => Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => _AddEv(api: api, ev: ev),
  ),
);

class _AddEv extends StatefulWidget {
  const _AddEv({required this.api, this.ev});
  final Map<String, dynamic>? ev;
  final PvgApi api;
  @override
  State<_AddEv> createState() => _AddEvState();
}

class _AddEvState extends State<_AddEv> {
  final form = GlobalKey<FormState>();
  final model = TextEditingController(), registration = TextEditingController();
  String connector = 'Not sure';
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    model.text = widget.ev?['model'] ?? '';
    registration.text = widget.ev?['registration'] ?? '';
    connector = widget.ev?['connector'] ?? 'Not sure';
  }

  @override
  void dispose() {
    model.dispose();
    registration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request(
        widget.ev == null ? '/evs' : '/evs/${widget.ev!['id']}',
        data: {
          'model': model.text.trim(),
          'registration': registration.text.trim(),
          'connector': connector,
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
      title: Text(widget.ev == null ? 'Add your EV' : 'Edit your EV'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Kicker('YOUR GARAGE'),
          const SizedBox(height: 16),
          const Text(
            'Make it yours.',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: model,
            decoration: const InputDecoration(
              labelText: 'Make & model',
              hintText: 'e.g. Tata Nexon EV',
            ),
            maxLength: 99,
            validator: (v) =>
                v!.trim().length < 2 ? 'Enter the make and model' : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: registration,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Registration number'),
            maxLength: 99,
            validator: (v) =>
                v!.trim().length < 2 ? 'Enter the registration number' : null,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: connector,
            decoration: const InputDecoration(labelText: 'Charging connector'),
            items: const [
              'Not sure',
              'CCS2',
              'Type 2',
              'CHAdeMO',
              'GB/T',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => connector = v!),
          ),
          const Notice(
            'Unsure about your connector? Choose “Not sure”. PVG will check compatibility before confirming your visit.',
          ),
          if (error != null) Notice(error!, error: true),
          PrimaryButton('Save EV', busy: busy, onPressed: save),
        ],
      ),
    ),
  );
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.api,
    this.prefill,
    this.initialEnergy,
  });
  final PvgApi api;
  final Map<String, dynamic>? prefill;
  final double? initialEnergy;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final address = TextEditingController(),
      pincode = TextEditingController(),
      units = TextEditingController(text: '15'),
      notes = TextEditingController();
  final requestKey =
      'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  List<Map<String, dynamic>> vehicles = [], places = [];
  String? selected, selectedPlace, error;
  DateTime? slot;
  double? latitude, longitude;
  int step = 0;
  bool loading = true, busy = false, locating = false, agreed = false;
  bool submitted = false;
  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    selectedPlace = p?['saved_place_id'];
    address.text = p?['address'] ?? '';
    pincode.text = p?['pincode'] ?? '';
    notes.text = p?['access_notes'] ?? '';
    latitude = (p?['latitude'] as num?)?.toDouble();
    longitude = (p?['longitude'] as num?)?.toDouble();
    units.text =
        (widget.initialEnergy ??
                ((p?['estimate']?['energy_milli'] as num?)?.toDouble() ??
                        15000) /
                    1000)
            .toString();
    units.addListener(update);
    load();
  }

  @override
  void dispose() {
    for (final c in [address, pincode, units, notes]) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  void update() {
    if (mounted) setState(() {});
  }

  Future<void> load({bool newest = false}) async {
    try {
      final results = await Future.wait<dynamic>([
        widget.api.vehicles(),
        widget.api.request('/places'),
        widget.api.request('/preferences'),
      ]);
      vehicles = results[0];
      places = (results[1]['places'] as List)
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
      final want = newest && vehicles.isNotEmpty
          ? vehicles.last['id']
          : (selected ??
                widget.prefill?['ev']?['id'] ??
                results[2]['default_vehicle_id']);
      selected = vehicles.any((v) => v['id'] == want)
          ? want
          : vehicles.firstOrNull?['id'];
      error = null;
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  void choosePlace(Map<String, dynamic> p) => setState(() {
    selectedPlace = p['id'];
    address.text = p['address'];
    pincode.text = p['pincode'];
    notes.text = p['access_notes'];
    latitude = (p['latitude'] as num?)?.toDouble();
    longitude = (p['longitude'] as num?)?.toDouble();
  });
  void clearPin(String _) => setState(() {
    latitude = null;
    longitude = null;
    selectedPlace = null;
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

  Future<void> chooseTime() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: slot != null && slot!.isAfter(now)
          ? slot!
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: slot == null
          ? const TimeOfDay(hour: 10, minute: 0)
          : TimeOfDay.fromDateTime(slot!),
    );
    if (time == null || !mounted) return;
    setState(() {
      slot = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      error = null;
    });
  }

  Map<String, dynamic> get bill => estimateBill(
    widget.api.config?['tariff'],
    (double.tryParse(units.text) ?? 0).clamp(0, 200),
  );
  bool validateStep() {
    if (!form.currentState!.validate()) return false;
    if (step == 0 && selected == null) {
      setState(() => error = 'Add an EV to continue.');
      return false;
    }
    if (step == 1 &&
        (slot == null ||
            !slot!.isAfter(DateTime.now()) ||
            slot!.isAfter(DateTime.now().add(const Duration(days: 31))))) {
      setState(() => error = 'Choose a future visit time within 30 days.');
      return false;
    }
    return true;
  }

  void go(int next) {
    FocusScope.of(context).unfocus();
    setState(() {
      step = next;
      error = null;
      agreed = false;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> submit() async {
    if (busy || submitted || !agreed || selected == null) return;
    if (slot == null || !slot!.isAfter(DateTime.now())) {
      go(1);
      setState(
        () =>
            error = 'Your selected time has passed. Please choose a new time.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final b = await widget.api.request(
        '/bookings',
        data: {
          'request_key': requestKey,
          'vehicle_id': selected,
          'address': address.text.trim(),
          'pincode': pincode.text.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'slot': slot!.toUtc().toIso8601String(),
          'estimated_kwh': units.text.trim(),
          'access_notes': notes.text.trim(),
        },
      );
      submitted = true;
      if (mounted) {
        setState(() => busy = false);
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetail(api: widget.api, bookingId: b['id']),
          ),
        );
      }
    } catch (e) {
      error = errorText(e);
    }
    if (mounted) setState(() => busy = false);
  }

  List<Widget> energyStep() => [
    const Kicker('01 / YOUR CHARGE'),
    const SizedBox(height: 12),
    const Text(
      'Set up your charge',
      style: TextStyle(
        fontSize: 26,
        height: 1.1,
        letterSpacing: -1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'Choose an EV and roughly how much energy you need. You only pay for the delivered units.',
      style: TextStyle(color: muted, fontSize: 13),
    ),
    const SectionTitle('Your vehicle'),
    for (final v in vehicles)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected == v['id'] ? softLime : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 7,
            ),
            leading: Icon(
              selected == v['id']
                  ? Icons.check_circle
                  : Icons.electric_car_outlined,
            ),
            title: Text(
              v['model'],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${v['registration']} · ${v['connector']}',
              style: const TextStyle(fontSize: 12),
            ),
            selected: selected == v['id'],
            onTap: () => setState(() => selected = v['id']),
          ),
        ),
      ),
    TextButton.icon(
      onPressed: () async {
        if (await showAddEv(context, widget.api) == true) {
          await load(newest: true);
        }
      },
      icon: const Icon(Icons.add),
      label: Text(vehicles.isEmpty ? 'Add your first EV' : 'Add another EV'),
    ),
    const SectionTitle('Energy required'),
    Wrap(
      spacing: 8,
      children: [10, 15, 25, 40]
          .map(
            (n) => ChoiceChip(
              label: Text('$n kWh'),
              selected: double.tryParse(units.text) == n,
              selectedColor: lime,
              onSelected: (_) => units.text = n.toString(),
            ),
          )
          .toList(),
    ),
    const SizedBox(height: 16),
    TextFormField(
      controller: units,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Or enter your energy need',
        suffixText: 'kWh',
      ),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        return !RegExp(r'^\d{1,4}(\.\d{1,3})?$').hasMatch(v ?? '') ||
                n == null ||
                n <= 0 ||
                n > 200
            ? 'Enter 0.001–200 kWh (up to 3 decimals)'
            : null;
      },
    ),
    const Notice(
      'Not sure? Start with an estimate. Actual charging depends on your battery, connector and the charging vehicle. PVG checks compatibility before confirmation.',
    ),
    Panel(
      color: forest,
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker('SAMPLE ESTIMATE', color: lime),
                SizedBox(height: 7),
                Text(
                  'Includes visit fee',
                  style: TextStyle(color: Color(0xffb7cdbf), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            money(bill['total_paise']),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  ];
  List<Widget> placeStep() => [
    const Kicker('02 / PLACE & TIME'),
    const SizedBox(height: 12),
    const Text(
      'Choose place & time',
      style: TextStyle(
        fontSize: 26,
        height: 1.1,
        letterSpacing: -1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 12),
    const Text(
      'Chennai pilot area · visit time subject to confirmation.',
      style: TextStyle(color: muted, fontSize: 13),
    ),
    if (places.isNotEmpty) ...[
      const SectionTitle('Use a saved place'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: places
            .map(
              (p) => ChoiceChip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                selected: selectedPlace == p['id'],
                selectedColor: lime,
                label: Text(p['label']),
                onSelected: (_) => choosePlace(p),
              ),
            )
            .toList(),
      ),
    ],
    const SectionTitle('Charging address'),
    TextFormField(
      controller: address,
      onChanged: clearPin,
      maxLength: 400,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Full address & landmark'),
      validator: (v) =>
          v!.trim().length < 8 ? 'Enter the full charging address' : null,
    ),
    const SizedBox(height: 10),
    TextFormField(
      controller: pincode,
      onChanged: clearPin,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(labelText: 'Chennai pincode'),
      validator: (v) => !RegExp(r'^600\d{3}$').hasMatch(v!.trim())
          ? 'Use a Chennai pincode (600xxx)'
          : null,
    ),
    OutlinedButton.icon(
      onPressed: locating ? null : gps,
      icon: Icon(
        latitude == null ? Icons.my_location : Icons.check_circle_outline,
      ),
      label: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          locating
              ? 'Finding your location…'
              : latitude == null
              ? 'Attach my current location'
              : 'GPS location attached',
        ),
      ),
    ),
    if (latitude != null)
      TextButton(
        onPressed: () => clearPin(''),
        child: const Text('Remove GPS location'),
      ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Optional: attach GPS only when you are at this address. You can book from somewhere else using the address alone.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
    ),
    const SectionTitle('When works for you?'),
    OutlinedButton.icon(
      onPressed: chooseTime,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          slot == null
              ? 'Choose a date & time'
              : timeLabel(slot!.toIso8601String()),
        ),
      ),
    ),
    const SizedBox(height: 18),
    TextFormField(
      controller: notes,
      maxLines: 2,
      maxLength: 1000,
      decoration: const InputDecoration(
        labelText: 'Parking / access instructions (optional)',
        hintText: 'Gate number, parking level, entry directions…',
      ),
    ),
  ];
  List<Widget> reviewStep() {
    final v = vehicles.firstWhere((v) => v['id'] == selected);
    return [
      const Kicker('03 / REVIEW & REQUEST'),
      const SizedBox(height: 12),
      const Text(
        'Review your visit',
        style: TextStyle(
          fontSize: 26,
          height: 1.1,
          letterSpacing: -1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 18),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.electric_car_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${v['model']}\n${v['registration']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(onPressed: () => go(0), child: const Text('Edit')),
              ],
            ),
            const Divider(height: 30),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${address.text.trim()}\n${pincode.text}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                TextButton(onPressed: () => go(1), child: const Text('Edit')),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.schedule),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    timeLabel(slot!.toIso8601String()),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            if (notes.text.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                notes.text.trim(),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      const SectionTitle('Your estimated bill'),
      Panel(child: BillLines(bill, estimated: true)),
      Notice(
        widget.api.isPreview
            ? 'Sample tariff only. Your final bill uses actual delivered energy and the agreed tariff. You review the meter evidence and accept the final bill before payment. Live rates and tax setup are pending.'
            : 'Your final bill uses the actual energy delivered and this agreed tariff. Review the meter photo and accept the units and final total before paying.',
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: agreed,
        onChanged: busy ? null : (v) => setState(() => agreed = v!),
        title: const Text(
          'I accept this tariff and understand that PVG must confirm my visit time.',
          style: TextStyle(fontSize: 13),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        widget.api.isPreview
            ? 'Local preview only. This will appear in the local PVG dashboard and will not dispatch a real vehicle.'
            : 'PVG will review availability and confirm your visit by assigning a charging vehicle.',
        style: TextStyle(fontSize: 11, color: muted),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Book charging'),
        leading: IconButton(
          tooltip: step == 0 ? 'Close booking' : 'Previous step',
          onPressed: busy
              ? null
              : () {
                  if (step > 0) {
                    go(step - 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= step ? forest : line,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ['EV & energy', 'Place & time', 'Review'][i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: i == step ? forest : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Form(
              key: form,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                children: [
                  if (loading)
                    const LinearProgressIndicator()
                  else
                    ...[energyStep, placeStep, reviewStep][step](),
                  if (error != null) Notice(error!, error: true),
                  if (error != null && loading == false && vehicles.isEmpty)
                    TextButton(
                      onPressed: load,
                      child: const Text('Reload vehicles'),
                    ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: line)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                step == 2 ? 'Request charging visit' : 'Continue',
                busy: busy,
                onPressed: loading || locating || (step == 2 && !agreed)
                    ? null
                    : () {
                        if (step == 2) {
                          submit();
                        } else if (validateStep()) {
                          go(step + 1);
                        }
                      },
                icon: step == 2 ? Icons.bolt : Icons.arrow_forward,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
