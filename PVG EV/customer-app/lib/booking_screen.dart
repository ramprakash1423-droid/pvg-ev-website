import 'dart:math';
import 'dart:async';
import 'location_picker.dart';
import 'package:flutter/material.dart';
import 'experience.dart';
import 'personal_screens.dart';
import 'api.dart';
import 'booking_detail.dart';
import 'ui.dart';
import 'visit_schedule.dart';
import 'location_validation.dart';

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
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
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
  const BookingScreen({super.key, required this.api, this.prefill});
  final PvgApi api;
  final Map<String, dynamic>? prefill;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final address = TextEditingController(),
      pincode = TextEditingController(),
      notes = TextEditingController();
  String requestKey =
      'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
  List<Map<String, dynamic>> vehicles = [], places = [];
  String? selected, selectedPlace, error;
  DateTime? slot;
  double? latitude, longitude;
  String? get pinError => chargingPinValidationError(latitude, longitude);
  int step = 0;
  bool loading = true, busy = false, locating = false, agreed = false;
  bool submitted = false, draftRestored = false;
  Timer? draftTimer;
  Future<void> draftWrite = Future.value();
  Map<String, dynamic>? availability;
  String? availabilityError;
  bool checkingTime = false;
  VisitSchedule? get schedule => VisitSchedule.from(
    availability?['settings'] ?? widget.api.config?['service'],
  );
  bool get tariffAvailable {
    final tariff = widget.api.config?['tariff'];
    return tariff is Map &&
        ['unit_rate_paise', 'visit_fee_paise', 'tax_basis_points'].every(
          (key) =>
              tariff[key] is num &&
              (tariff[key] as num).isFinite &&
              tariff[key] >= 0,
        );
  }

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
    load();
    for (final controller in [address, pincode, notes]) {
      controller.addListener(queueDraft);
    }
  }

  void queueDraft() {
    if (loading ||
        submitted ||
        busy ||
        widget.api.config?['mode'] != 'supabase') {
      return;
    }
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 600), saveDraft);
  }

  void saveDraft() {
    if (loading ||
        busy ||
        submitted ||
        widget.api.config?['mode'] != 'supabase') {
      return;
    }
    if (pinError != null) return;
    final payload = {
      'vehicle_id': selected,
      'address': address.text,
      'pincode': pincode.text,
      'access_notes': notes.text,
      'latitude': latitude,
      'longitude': longitude,
      'slot': slot?.toUtc().toIso8601String(),
      'request_key': requestKey,
    };
    draftWrite = draftWrite.then((_) async {
      try {
        await widget.api.request('/booking-draft', data: payload);
      } catch (_) {
        /* Keep the in-memory form available when offline. */
      }
    });
  }

  @override
  void dispose() {
    draftTimer?.cancel();
    if (!submitted) saveDraft();
    for (final c in [address, pincode, notes]) {
      c.dispose();
    }
    scroll.dispose();
    super.dispose();
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
      if (!draftRestored &&
          widget.prefill == null &&
          widget.api.config?['mode'] == 'supabase') {
        final d = await widget.api.request('/booking-draft');
        if (d['request_key'] is String) {
          requestKey = d['request_key'];
          address.text = d['address'] ?? '';
          pincode.text = d['pincode'] ?? '';
          notes.text = d['access_notes'] ?? '';
          if (vehicles.any((v) => v['id'] == d['vehicle_id'])) {
            selected = d['vehicle_id'];
          }
          latitude = (d['latitude'] as num?)?.toDouble();
          longitude = (d['longitude'] as num?)?.toDouble();
          slot = DateTime.tryParse(d['slot'] ?? '')?.toUtc();
        }
      }
      draftRestored = true;
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
  void clearPin(String _) {
    setState(() {
      latitude = null;
      longitude = null;
      selectedPlace = null;
      if (error == chennaiPinError) error = null;
    });
    queueDraft();
  }

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
    if (mounted) {
      setState(() => locating = false);
      queueDraft();
    }
  }

  Future<void> chooseTime() async {
    if (schedule == null) {
      try {
        await widget.api.loadConfig();
      } catch (e) {
        if (mounted) setState(() => error = errorText(e));
        return;
      }
    }
    if (!mounted) return;
    if (schedule == null) {
      setState(
        () =>
            error = 'PVG service hours could not be loaded. Please try again.',
      );
      return;
    }
    final now = DateTime.now(), today = indiaCalendarDay(DateTime.now());
    final day = await showDatePicker(
      context: context,
      helpText: 'Choose visit date · India time',
      currentDate: today,
      initialDate: slot != null && slot!.isAfter(now)
          ? indiaCalendarDay(slot!)
          : visitCalendarDayAfter(today, 1),
      firstDate: today,
      lastDate: visitCalendarDayAfter(today, 30),
    );
    if (day == null || !mounted) return;
    if (widget.api.config?['mode'] == 'supabase' &&
        RegExp(r'^600\d{3}$').hasMatch(pincode.text)) {
      setState(() {
        checkingTime = true;
        availabilityError = null;
      });
      try {
        final date =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final data = await widget.api.request(
          '/availability?pincode=${pincode.text}&date=$date',
        );
        if (!mounted) return;
        setState(() => availability = data);
        if (data['state'] == 'outside_area') {
          setState(() => error = data['message']);
          return;
        }
      } catch (e) {
        if (mounted) setState(() => availabilityError = errorText(e));
      } finally {
        if (mounted) setState(() => checkingTime = false);
      }
    }
    if (!mounted) return;
    final hours = schedule!;
    final time = await showTimePicker(
      context: context,
      helpText: 'Visit time · India (IST)',
      initialTime: slot == null ? hours.initialTime : indiaClock(slot!),
    );
    if (time == null || !mounted) return;
    final selectedInstant = indiaVisitInstant(day, time);
    final problem = hours.validate(selectedInstant);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      slot = selectedInstant;
      error = null;
    });
    queueDraft();
  }

  bool validateStep() {
    if (!form.currentState!.validate()) return false;
    if (step == 0 && selected == null) {
      setState(() => error = 'Add an EV to continue.');
      return false;
    }
    if (step == 1) {
      if (pinError != null) {
        setState(() => error = pinError);
        return false;
      }
      final problem =
          schedule?.validate(slot) ??
          (schedule == null
              ? 'PVG service hours could not be loaded. Please try again.'
              : null);
      if (problem != null) {
        setState(() => error = problem);
        return false;
      }
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
    queueDraft();
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> submit() async {
    if (busy || submitted || !agreed || selected == null || !tariffAvailable) {
      return;
    }
    if (pinError != null) {
      go(1);
      setState(() => error = pinError);
      return;
    }
    final timeProblem =
        schedule?.validate(slot) ??
        (schedule == null
            ? 'PVG service hours could not be loaded. Please try again.'
            : null);
    if (timeProblem != null) {
      go(1);
      setState(() => error = timeProblem);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      draftTimer?.cancel();
      await draftWrite;
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

  Widget stepIntro(String title, String description, IconData icon) => Panel(
    color: forest,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: lime, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Kicker('CHARGING AT YOUR DOORSTEP', color: lime),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            height: 1.2,
            letterSpacing: -.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xffcbd8d1),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget sectionLabel(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget nextStep(IconData icon, String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: softLime,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  List<Widget> vehicleStep() => [
    stepIntro(
      'Which EV are we charging?',
      'Choose your vehicle. We’ll bring the charging to you.',
      Icons.electric_car_outlined,
    ),
    const SectionTitle('Your vehicle'),
    if (vehicles.isEmpty)
      const Panel(
        child: Text(
          'Add your EV once to book visits faster. You can choose “Not sure” if you don’t know the connector.',
          style: TextStyle(color: muted, fontSize: 13, height: 1.5),
        ),
      ),
    for (final v in vehicles)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: selected == v['id'] ? softLime : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected == v['id'] ? forest : line),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
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
            onTap: () {
              setState(() => selected = v['id']);
              queueDraft();
            },
          ),
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          if (await showAddEv(context, widget.api) == true) {
            await load(newest: true);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(vehicles.isEmpty ? 'Add your first EV' : 'Add another EV'),
      ),
    ),
    const SectionTitle('Your visit, made simple'),
    Panel(
      child: Column(
        children: [
          nextStep(
            Icons.local_shipping_outlined,
            'Follow your charging vehicle',
            'Once assigned, see your technician, location updates and visit status.',
          ),
          const Divider(height: 16, color: line),
          nextStep(
            Icons.fact_check_outlined,
            'Charge first. Review, then pay.',
            'Your bill uses the actual meter reading. Accept the units before payment.',
          ),
        ],
      ),
    ),
  ];
  List<Widget> placeStep() => [
    stepIntro(
      'Where should we meet you?',
      'Choose a place and preferred time. PVG will confirm availability in the Chennai pilot area.',
      Icons.place_outlined,
    ),
    const SizedBox(height: 16),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(Icons.location_on_outlined, 'Charging address'),
          if (places.isNotEmpty) ...[
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
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: address,
            onChanged: clearPin,
            maxLength: 400,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Full address & landmark',
              counterText: '',
            ),
            validator: (v) =>
                v!.trim().length < 8 ? 'Enter the full charging address' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: pincode,
            onChanged: clearPin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Chennai pincode',
              counterText: '',
            ),
            validator: (v) => !RegExp(r'^600\d{3}$').hasMatch(v!.trim())
                ? 'Use a Chennai pincode (600xxx)'
                : null,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: locating ? null : gps,
              icon: Icon(
                latitude == null
                    ? Icons.my_location
                    : Icons.check_circle_outline,
              ),
              label: Text(
                locating
                    ? 'Finding your location…'
                    : latitude == null
                    ? 'Attach my current location'
                    : 'GPS location attached',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final pin = await pickChargingPin(
                  context,
                  latitude: latitude,
                  longitude: longitude,
                );
                if (pin != null && mounted) {
                  setState(() {
                    latitude = pin.latitude;
                    longitude = pin.longitude;
                  });
                  queueDraft();
                }
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Choose exact pin on map'),
            ),
          ),
          if (latitude != null || longitude != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => clearPin(''),
                child: const Text('Remove GPS location'),
              ),
            ),
          if (pinError != null) const Notice(chennaiPinError, error: true),
          const Text(
            'At this address now? Add GPS to help your technician find you. Otherwise, the address is enough.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(Icons.schedule_outlined, 'Preferred visit time'),
          OutlinedButton.icon(
            onPressed: checkingTime ? null : chooseTime,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(
              slot == null
                  ? 'Choose a date & time'
                  : timeLabel(slot!.toIso8601String()),
            ),
          ),
          const SizedBox(height: 6),
          if (checkingTime) const LinearProgressIndicator(),
          if (availabilityError != null)
            Notice(availabilityError!, error: true),
          if (availability != null) ...[
            Notice(availability!['message']),
            if ((availability!['slots'] as List? ?? []).isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (availability!['slots'] as List)
                    .take(16)
                    .map(
                      (value) => ChoiceChip(
                        label: Text(timeLabel(value)),
                        selected: slot?.toUtc().toIso8601String() == value,
                        onSelected: (_) {
                          setState(() => slot = DateTime.parse(value).toUtc());
                          queueDraft();
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
          Text(
            schedule == null
                ? 'Service hours are loading. Your preferred time will be confirmed by PVG.'
                : 'Service hours: ${schedule!.hoursLabel} IST. Your preferred time is confirmed when PVG assigns the charging team.',
            style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(Icons.notes_outlined, 'Help us find your parking spot'),
          TextFormField(
            controller: notes,
            maxLines: 2,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Parking / access instructions (optional)',
              hintText: 'Gate number, parking level, entry directions…',
              counterText: '',
            ),
          ),
        ],
      ),
    ),
  ];
  List<Widget> reviewStep() {
    final v = vehicles.firstWhere((v) => v['id'] == selected);
    return [
      stepIntro(
        'Ready to request your visit?',
        'Check the details below. You can follow your visit as soon as the request is placed.',
        Icons.checklist_outlined,
      ),
      const SizedBox(height: 16),
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
            const Divider(height: 24),
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
      const SectionTitle('Payment comes after charging'),
      Panel(
        child: nextStep(
          Icons.fact_check_outlined,
          'You review. You approve.',
          'Your technician shares the meter photo and delivered units. The app calculates the final bill for you to accept and pay.',
        ),
      ),
      if (tariffAvailable)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Charging rate: ${money(widget.api.config!['tariff']['unit_rate_paise'])} per kWh · Visit fee: ${money(widget.api.config!['tariff']['visit_fee_paise'])} · ${(widget.api.config!['tariff']['tax_basis_points'] as num) / 100}% tax. No payment is taken when you request a visit.',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        )
      else ...[
        const Notice(
          'The current charging rate could not be loaded. Please reload it before confirming your visit.',
          error: true,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy
                ? null
                : () async {
                    try {
                      await widget.api.loadConfig();
                      if (mounted) {
                        setState(() {
                          error = null;
                          agreed = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) setState(() => error = errorText(e));
                    }
                  },
            child: const Text('Reload charging rate'),
          ),
        ),
      ],
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: agreed,
        onChanged: busy || !tariffAvailable
            ? null
            : (v) => setState(() => agreed = v!),
        title: const Text(
          'I agree to the charging rate and visit fee, and understand that PVG will confirm my visit time.',
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
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
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
                          duration: Duration(
                            milliseconds:
                                MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : 200,
                          ),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i < step
                                ? forest
                                : i == step
                                ? lime
                                : line,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${i + 1}. ${['Your EV', 'Place & time', 'Review'][i]}',
                          style: TextStyle(
                            fontSize: 11,
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
              child: MotionEntrance(
                key: ValueKey(step),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                  children: [
                    if (loading)
                      const LinearProgressIndicator()
                    else
                      ...[vehicleStep, placeStep, reviewStep][step](),
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
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: line)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Step ${step + 1} of 3',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  Flexible(
                    flex: 3,
                    child: PrimaryButton(
                      step == 2 ? 'Request charging visit' : 'Continue',
                      busy: busy,
                      onPressed:
                          loading ||
                              locating ||
                              (step == 2 && (!agreed || !tariffAvailable))
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
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
