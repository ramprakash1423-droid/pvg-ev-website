import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ui.dart';
import 'location_validation.dart';

/// No customer GPS is requested here. This shows the assigned technician's feed.
class VisitTracking extends StatefulWidget {
  const VisitTracking({
    super.key,
    required this.booking,
    this.connectionLost = false,
    this.tileProvider,
    this.onRefresh,
    this.prominent = false,
    this.embedded = false,
    this.showIdentity = true,
  });
  final Map<String, dynamic> booking;
  final bool connectionLost, prominent, embedded, showIdentity;
  final TileProvider? tileProvider;
  final VoidCallback? onRefresh;
  @override
  State<VisitTracking> createState() => _VisitTrackingState();
}

class _VisitTrackingState extends State<VisitTracking> {
  final map = MapController();
  final snapshotAge = Stopwatch();
  final tileReset = StreamController<void>.broadcast();
  final failedTileImages = <ImageProvider>{};
  Timer? ageTimer;
  bool ready = false, follow = true, tileError = false;
  bool retryingMap = false;
  int tileGeneration = 0;
  @override
  void initState() {
    super.initState();
    snapshotAge.start();
    ageTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && position != null) setState(() {});
    });
  }

  Map<String, dynamic> get tracking =>
      Map<String, dynamic>.from(widget.booking['tracking'] ?? {});
  Map<String, dynamic>? get position {
    final p = tracking['position'];
    return p is Map ? Map<String, dynamic>.from(p) : null;
  }

  LatLng? get vehicle => position == null
      ? null
      : LatLng(
          (position!['latitude'] as num).toDouble(),
          (position!['longitude'] as num).toDouble(),
        );
  bool get invalidDestination {
    final lat = widget.booking['latitude'], lon = widget.booking['longitude'];
    return (lat != null || lon != null) &&
        (lat is! num || lon is! num || !isChennaiPin(lat, lon));
  }

  LatLng? get destination =>
      invalidDestination ||
          widget.booking['latitude'] == null ||
          widget.booking['longitude'] == null
      ? null
      : LatLng(
          (widget.booking['latitude'] as num).toDouble(),
          (widget.booking['longitude'] as num).toDouble(),
        );
  Duration get readingAge {
    final captured = DateTime.tryParse(position?['captured_at'] ?? '');
    if (captured == null) return const Duration(days: 1);
    final serverTime = DateTime.tryParse(tracking['server_time'] ?? '');
    // Use the server's snapshot time plus monotonic elapsed time, not the phone clock.
    final age = serverTime == null
        ? DateTime.now().difference(captured)
        : serverTime.difference(captured) + snapshotAge.elapsed;
    return age.isNegative ? Duration.zero : age;
  }

  String get ageLabel {
    final seconds = readingAge.inSeconds;
    if (seconds < 10) return 'just now';
    if (seconds < 60) return '$seconds seconds ago';
    final minutes = seconds ~/ 60;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }

  bool get outdated {
    return widget.connectionLost ||
        tracking['state'] != 'live' ||
        position == null ||
        readingAge.inSeconds > 90;
  }

  void recenter() {
    if (!ready || (vehicle == null && destination == null)) return;
    if (vehicle == null) {
      map.move(destination!, 14);
      return;
    }
    if (destination != null) {
      map.fitCamera(
        CameraFit.coordinates(
          coordinates: [vehicle!, destination!],
          padding: const EdgeInsets.all(55),
          maxZoom: 15,
        ),
      );
    } else {
      map.move(vehicle!, 14);
    }
  }

  @override
  void didUpdateWidget(covariant VisitTracking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking['tracking']?['server_time'] !=
        tracking['server_time']) {
      snapshotAge.reset();
    }
    final oldLat = oldWidget.booking['latitude'],
        oldLon = oldWidget.booking['longitude'];
    final oldHadMap =
        oldWidget.booking['tracking']?['position'] != null ||
        (oldLat is num && oldLon is num && isChennaiPin(oldLat, oldLon));
    if (oldWidget.booking['id'] != widget.booking['id'] ||
        oldWidget.tileProvider != widget.tileProvider ||
        oldHadMap != (vehicle != null || destination != null)) {
      tileGeneration++;
      tileError = false;
      retryingMap = false;
      failedTileImages.clear();
    }
    if (vehicle == null && destination == null) ready = false;
    if (follow && ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) recenter();
      });
    }
  }

  @override
  void dispose() {
    tileGeneration++;
    ageTimer?.cancel();
    snapshotAge.stop();
    unawaited(tileReset.close());
    failedTileImages.clear();
    map.dispose();
    super.dispose();
  }

  Future<void> retryMap() async {
    if (!mounted || retryingMap || (vehicle == null && destination == null)) {
      return;
    }
    final failures = failedTileImages.toList();
    failedTileImages.clear();
    final generation = ++tileGeneration;
    setState(() {
      retryingMap = true;
      tileError = false;
    });
    // Rebuild the callback with this attempt's generation before resetting tiles.
    await WidgetsBinding.instance.endOfFrame;
    // Finish evicting failed cached images before the layer creates new streams.
    await Future.wait(
      failures.map((image) async {
        try {
          await image.evict();
        } catch (_) {
          // The layer reset still retries providers which do not cache images.
        }
      }),
    );
    if (!mounted || generation != tileGeneration || tileReset.isClosed) return;
    tileReset.add(null);
    await Future<void>.delayed(Duration.zero);
    if (mounted && generation == tileGeneration) {
      setState(() => retryingMap = false);
    }
  }

  Future<void> openMap() async {
    final p = vehicle;
    if (p == null) return;
    final opened = await launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${p.latitude},${p.longitude}',
      }),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      showMessage(context, 'Could not open Maps. Please try again.');
    }
  }

  Widget pin(IconData icon, String label, Color color) => Semantics(
    label: label,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 7)],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final t = tracking,
        p = position,
        v = vehicle,
        d = destination,
        sample = t['source'] == 'sample';
    final generation = tileGeneration;
    final title = sample
        ? 'Sample GPS preview'
        : widget.connectionLost
        ? 'Location connection lost'
        : p != null
        ? (outdated ? 'Last known location' : 'Live vehicle location')
        : 'Track your charging vehicle';
    final message = widget.connectionLost
        ? (p == null
              ? 'Could not refresh GPS. Try again when your connection returns.'
              : 'Could not refresh GPS. This is the last received position.')
        : {
                'awaiting_assignment':
                    'Your vehicle’s location will appear here after assignment and technician sharing.',
                'not_sharing':
                    'Your technician is assigned. Their location appears when they enable GPS sharing.',
                'waiting':
                    'Your technician has enabled sharing. Waiting for the first reliable GPS reading.',
                'expired':
                    'No recent GPS updates. Waiting for your technician to restart sharing.',
                'ended': 'Location sharing has ended for this visit.',
              }[t['state']] ??
              (outdated
                  ? 'No recent GPS updates. This pin may no longer be current.'
                  : 'Updates automatically while your technician shares their location.');
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              color: forest,
              size: widget.prominent ? 18 : 24,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: widget.prominent ? 13 : 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (widget.showIdentity && widget.booking['fleet_name'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${widget.booking['fleet_name']} · ${widget.booking['technician']?['name'] ?? 'PVG technician'}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 10),
        if (p != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Last GPS update · $ageLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: outdated ? const Color(0xff9a5918) : forest,
              ),
            ),
          ),
        if (widget.connectionLost && widget.onRefresh != null)
          TextButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry location update'),
          ),
        if (sample)
          const Notice(
            'Sample location only. No real vehicle or phone is being tracked.',
          ),
        if (invalidDestination) const Notice(chennaiPinError, error: true),
        if (v == null && d == null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(widget.prominent ? 12 : 20),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.prominent
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        t['state'] == 'awaiting_assignment'
                            ? Icons.assignment_outlined
                            : Icons.location_searching,
                        color: muted,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(
                        t['state'] == 'awaiting_assignment'
                            ? Icons.assignment_outlined
                            : Icons.location_searching,
                        color: muted,
                        size: 32,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
          )
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: widget.prominent ? 300 : 240,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: map,
                    options: MapOptions(
                      initialCenter: v ?? d!,
                      initialZoom: 14,
                      minZoom: 3,
                      maxZoom: 18,
                      onMapReady: () {
                        ready = true;
                        recenter();
                      },
                      onPositionChanged: (_, gesture) {
                        if (gesture && follow) setState(() => follow = false);
                      },
                      interactionOptions: const InteractionOptions(
                        flags:
                            InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        reset: tileReset.stream,
                        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                        tileDisplay: MediaQuery.disableAnimationsOf(context)
                            ? const TileDisplay.instantaneous()
                            : const TileDisplay.fadeIn(),
                        tileProvider: widget.tileProvider,
                        urlTemplate: const String.fromEnvironment(
                          'PVG_MAP_TILES',
                          defaultValue:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        userAgentPackageName: 'com.pvgev.customer',
                        panBuffer: 0,
                        errorTileCallback: (tile, error, stack) {
                          if (!mounted || generation != tileGeneration) return;
                          failedTileImages.add(tile.imageProvider);
                          if (!tileError) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && generation == tileGeneration) {
                                setState(() => tileError = true);
                              }
                            });
                          }
                        },
                      ),
                      MarkerLayer(
                        markers: [
                          if (v != null)
                            Marker(
                              point: v,
                              width: 44,
                              height: 44,
                              child: pin(
                                Icons.local_shipping,
                                outdated
                                    ? 'Last reported vehicle position'
                                    : 'Charging vehicle position',
                                outdated ? muted : forest,
                              ),
                            ),
                          if (d != null)
                            Marker(
                              point: d,
                              width: 38,
                              height: 38,
                              child: pin(
                                Icons.home,
                                'Your charging address',
                                const Color(0xff426e9b),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      elevation: 2,
                      child: IconButton(
                        tooltip: v == null
                            ? 'Show charging address'
                            : 'Follow vehicle',
                        onPressed: () {
                          setState(() => follow = true);
                          recenter();
                        },
                        icon: Icon(
                          follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                          color: forest,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ColoredBox(
                      color: const Color(0xeeffffff),
                      child: InkWell(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Text(
                            '© OpenStreetMap contributors',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10, color: forest),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: outdated ? const Color(0xff9a5918) : muted,
            ),
          ),
          if (widget.prominent && (p != null || d == null))
            ExpansionTile(
              key: const Key('location-details'),
              title: const Text(
                'Location details',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              dense: true,
              expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                  ? AnimationStyle.noAnimation
                  : null,
              shape: const Border(),
              collapsedShape: const Border(),
              children: locationDetails(p, v, d),
            )
          else if (!widget.prominent)
            ...locationDetails(p, v, d),
          if (tileError || retryingMap)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      retryingMap
                          ? 'Retrying map tiles…'
                          : 'Some map tiles could not load. GPS updates are separate.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: retryingMap ? null : retryMap,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(retryingMap ? 'Retrying…' : 'Retry map'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
    final padding = EdgeInsets.all(widget.prominent ? 12 : 16);
    return widget.embedded
        ? Padding(padding: padding, child: content)
        : Panel(padding: padding, child: content);
  }

  List<Widget> locationDetails(
    Map<String, dynamic>? p,
    LatLng? v,
    LatLng? d,
  ) => [
    if (p != null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Captured ${timeLabel(p['captured_at'])} · GPS accuracy ±${(p['accuracy'] as num).round()} m',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ),
    if (d != null && v != null)
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${const Distance().as(LengthUnit.Kilometer, v, d).toStringAsFixed(1)} km straight-line distance · not a road ETA',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ),
    if (d == null)
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          invalidDestination
              ? 'Your parking pin needs correction. The map shows the vehicle only.'
              : 'Your address has no GPS pin. The map shows the vehicle only.',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
      ),
    if (v != null)
      TextButton.icon(
        onPressed: openMap,
        icon: const Icon(Icons.open_in_new, size: 17),
        label: const Text('Open latest location in Maps'),
      ),
  ];
}
