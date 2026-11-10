import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/main.dart';
import 'package:pvg_customer/tracking_experience.dart';
import 'package:pvg_customer/visit_tracking.dart';
import 'tracking_test.dart' show OfflineTiles;

void main() {
  testWidgets(
    'empty tracker has no invented vehicle, pin or arrival estimate on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(home: EmptyTrackingScreen(onBook: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Technician not assigned'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Call technician'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -380));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'known destination appears before vehicle GPS without inventing a vehicle pin',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisitTracking(
                prominent: true,
                tileProvider: OfflineTiles(),
                booking: {
                  'latitude': 13.01,
                  'longitude': 80.22,
                  'tracking': {'state': 'not_sharing', 'position': null},
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        1,
      );
      expect(find.textContaining('enable GPS sharing'), findsOneWidget);
      expect(find.textContaining('straight-line'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'signed-in active visit becomes Home instead of the marketing hero',
    (tester) async {
      final b = {
        'id': 'owned-booking',
        'reference': 'PVG-TEST',
        'status': 'assigned',
        'slot': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'address': 'Unit test address',
        'technician': {'name': 'Assigned technician', 'phone': '9000000001'},
        'fleet_name': 'Assigned vehicle',
        'fleet_registration': 'TEST REG',
        'events': [],
        'tracking': {'state': 'not_sharing', 'position': null},
      };
      final api = PvgApi(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(switch (r.url.path) {
              '/api/auth/verify' => {
                'token': 'unit-test',
                'user': {'id': 'customer', 'name': 'Test', 'role': 'customer'},
                'expires_in': 3600,
              },
              '/api/config' => {
                'mode': 'supabase',
                'realtime': false,
                'tariff': {},
              },
              '/api/bookings' => {
                'bookings': [b],
              },
              '/api/evs' => {'vehicles': []},
              '/api/places' => {'places': []},
              _ => {},
            }),
            200,
          ),
        ),
      );
      await api.verifyOtp('test', '123456');
      await tester.pumpWidget(PvgCustomerApp(api: api));
      await tester.pumpAndSettle();
      expect(find.byType(TrackingExperience), findsOneWidget);
      expect(find.text('Your day. Fully charged.'), findsNothing);
      expect(find.text('Your charging team is assigned.'), findsOneWidget);
      expect(find.text('TEST REG'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
