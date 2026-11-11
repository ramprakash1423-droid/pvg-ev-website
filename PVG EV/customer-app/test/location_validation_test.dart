import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/booking_screen.dart';
import 'package:pvg_customer/location_picker.dart';
import 'package:pvg_customer/location_validation.dart';
import 'package:pvg_customer/personal_screens.dart';
import 'package:pvg_customer/visit_tracking.dart';
import 'tracking_test.dart' show OfflineTiles;

class FixedPosition extends GeolocatorPlatform {
  FixedPosition(this.latitude, this.longitude);
  final double latitude, longitude;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2030),
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  test(
    'pin sanity check permits optional/nearby locations and rejects obvious mismatches',
    () {
      expect(chargingPinValidationError(null, null), isNull);
      expect(isChennaiPin(13.0827, 80.2707), isTrue);
      expect(isChennaiPin(12.92, 80.12), isTrue);
      expect(isChennaiPin(37.33, -122.03), isFalse);
      expect(isChennaiPin(12.97, 77.59), isFalse);
      expect(isChennaiPin(double.nan, 80.27), isFalse);
      expect(isChennaiPin(13.08, double.infinity), isFalse);
      expect(chargingPinValidationError(13.08, null), chennaiPinError);
    },
  );

  test(
    'customer GPS rejects a far fix and returns a nearby fix without altering it',
    () async {
      final original = GeolocatorPlatform.instance;
      addTearDown(() => GeolocatorPlatform.instance = original);
      GeolocatorPlatform.instance = FixedPosition(37.33, -122.03);
      await expectLater(
        locateCustomer(),
        throwsA(predicate((e) => e.toString().contains(chennaiPinError))),
      );
      GeolocatorPlatform.instance = FixedPosition(13.01, 80.22);
      final position = await locateCustomer();
      expect(position.latitude, 13.01);
      expect(position.longitude, 80.22);
    },
  );

  testWidgets(
    'a far existing map pin opens Chennai without selecting a replacement',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => pickChargingPin(
                  context,
                  latitude: 37.33,
                  longitude: -122.03,
                  tileProvider: OfflineTiles(),
                ),
                child: const Text('Edit pin'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit pin'));
      await tester.pumpAndSettle();
      expect(find.text(chennaiPinError), findsOneWidget);
      expect(find.byType(MarkerLayer), findsNothing);
      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.initialCenter.latitude, chennaiMapLatitude);
      expect(options.initialCenter.longitude, chennaiMapLongitude);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use this pin'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tracking hides only the mismatched destination and retains actual vehicle GPS',
    (tester) async {
      final booking = <String, dynamic>{
        'latitude': 37.33,
        'longitude': -122.03,
        'tracking': {'state': 'not_sharing', 'position': null},
      };
      Widget screen() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisitTracking(
              booking: booking,
              tileProvider: OfflineTiles(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text(chennaiPinError), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      booking['tracking'] = {
        'state': 'live',
        'source': 'device',
        'server_time': DateTime.now().toIso8601String(),
        'position': {
          'latitude': 37.34,
          'longitude': -122.04,
          'accuracy': 8,
          'captured_at': DateTime.now().toIso8601String(),
        },
      };
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.length, 1);
      expect(markers.single.point.latitude, 37.34);
      expect(markers.single.point.longitude, -122.04);
      expect(booking['latitude'], 37.33);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saved-place correction removes only the mismatched pin and preserves the address',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? submitted;
      final api = PvgApi(
        client: MockClient((r) async {
          submitted = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PlaceEditor(
            api: api,
            place: const {
              'id': 'owned-place',
              'label': 'Home',
              'address': 'Unchanged Chennai parking address',
              'pincode': '600020',
              'access_notes': 'Keep gate details',
              'latitude': 37.33,
              'longitude': -122.03,
            },
          ),
        ),
      );
      await tester.tap(find.text('Save place'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      await tester.tap(find.text('Remove GPS location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save place'));
      await tester.pumpAndSettle();
      expect(submitted, {
        'label': 'Home',
        'address': 'Unchanged Chennai parking address',
        'pincode': '600020',
        'access_notes': 'Keep gate details',
        'latitude': null,
        'longitude': null,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a restored booking draft cannot advance with a far pin or silently replace its address',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final api = PvgApi(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            writes.add(jsonDecode(r.body) as Map<String, dynamic>);
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode(switch (r.url.path) {
              '/api/evs' => {
                'vehicles': [
                  {
                    'id': 'owned-ev',
                    'model': 'Test EV',
                    'registration': 'UNIT TEST',
                    'connector': 'CCS2',
                  },
                ],
              },
              '/api/places' => {'places': []},
              '/api/booking-draft' => {
                'request_key': 'isolated-draft',
                'vehicle_id': 'owned-ev',
                'address': 'Unchanged Chennai parking address',
                'pincode': '600020',
                'latitude': 37.33,
                'longitude': -122.03,
              },
              _ => {},
            }),
            200,
          );
        }),
      );
      api.config = {
        'mode': 'supabase',
        'service': {'open_minutes': 360, 'close_minutes': 1380},
      };
      addTearDown(api.dispose);
      await tester.pumpWidget(MaterialApp(home: BookingScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text(chennaiPinError), findsWidgets);
      expect(writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
