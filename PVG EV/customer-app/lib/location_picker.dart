import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'personal_screens.dart';
import 'ui.dart';
import 'location_validation.dart';

Future<LatLng?> pickChargingPin(
  BuildContext context, {
  double? latitude,
  double? longitude,
  TileProvider? tileProvider,
}) => Navigator.push<LatLng>(
  context,
  MaterialPageRoute(
    builder: (_) => _LocationPicker(
      initial:
          latitude != null &&
              longitude != null &&
              isChennaiPin(latitude, longitude)
          ? LatLng(latitude, longitude)
          : null,
      initialError: chargingPinValidationError(latitude, longitude),
      tileProvider: tileProvider,
    ),
  ),
);

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({this.initial, this.initialError, this.tileProvider});
  final LatLng? initial;
  final String? initialError;
  final TileProvider? tileProvider;
  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final map = MapController();
  LatLng? point;
  bool locating = false, tilesFailed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    point = widget.initial;
    error = widget.initialError;
  }

  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }

  Future<void> gps() async {
    setState(() => locating = true);
    try {
      final p = await locateCustomer();
      if (mounted) {
        setState(() {
          point = LatLng(p.latitude, p.longitude);
          error = null;
        });
        map.move(point!, 17);
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
    if (mounted) setState(() => locating = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pin your parking entrance')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Move around the map and tap the exact place to meet. Add your building and gate details in the address.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter:
                      point ??
                      const LatLng(chennaiMapLatitude, chennaiMapLongitude),
                  initialZoom: point == null ? 11 : 16,
                  onTap: (_, position) => setState(() {
                    final valid = isChennaiPin(
                      position.latitude,
                      position.longitude,
                    );
                    point = valid ? position : null;
                    error = valid ? null : chennaiPinError;
                  }),
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    tileProvider: widget.tileProvider,
                    urlTemplate: const String.fromEnvironment(
                      'PVG_MAP_TILES',
                      defaultValue:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    userAgentPackageName: 'com.pvgev.customer',
                    panBuffer: 0,
                    errorTileCallback: (_, e, s) {
                      if (!tilesFailed) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => tilesFailed = true);
                        });
                      }
                    },
                  ),
                  if (point != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point!,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_pin,
                            size: 42,
                            color: forest,
                          ),
                        ),
                      ],
                    ),
                  const SimpleAttributionWidget(
                    source: Text('© OpenStreetMap contributors'),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                right: 12,
                child: FilledButton.tonalIcon(
                  onPressed: locating ? null : gps,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(locating ? 'Locating…' : 'Use my GPS'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null) Notice(error!, error: true),
              if (tilesFailed)
                const Text(
                  'Map tiles could not load. You can use your current GPS or go back and enter the address.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              Text(
                point == null
                    ? 'No location selected yet. Tap the map or use GPS.'
                    : 'Parking pin selected. Confirm it matches your charging address.',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 8),
              SafeArea(
                top: false,
                child: PrimaryButton(
                  'Use this pin',
                  onPressed: point == null
                      ? null
                      : () => Navigator.pop(context, point),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
